//
//  RadioViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/14/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - RadioPicker Delegate definition
// --------------------------------------------------------------------------------

protocol RadioPickerDelegate: class {
  
  var token: Token? { get set }
  
  /// Open the specified Radio
  ///
  /// - Parameters:
  ///   - radio:          a DiscoveryStruct struct
  ///   - remote:         remote / local
  ///   - handle:         remote handle
  /// - Returns:          success / failure
  ///
  func openRadio(_ radio: DiscoveryStruct?, isWan: Bool, wanHandle: String) -> Radio?
  
  /// Close the active Radio
  ///
  func closeRadio()  
}

// --------------------------------------------------------------------------------
// MARK: - Radio View Controller class implementation
// --------------------------------------------------------------------------------

final class RadioViewController             : NSSplitViewController, RadioPickerDelegate, NSWindowDelegate {

  @objc dynamic var radio                   = Api.sharedInstance.radio
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _log                          = (NSApp.delegate as! AppDelegate).msg
  private var _radios                       : [DiscoveryStruct] {
    return Discovery.sharedInstance.discoveredRadios }
  private var _api                          = Api.sharedInstance
  private var _mainWindowController         : MainWindowController?
  private var _preferencesStoryboard        : NSStoryboard?
  private var _profilesStoryboard           : NSStoryboard?
  private var _radioPickerStoryboard        : NSStoryboard?
  private var _sideStoryboard               : NSStoryboard?
  private var _voltageMeterAvailable        = false
  private var _temperatureMeterAvailable    = false
  private var _versions                     : (api: String, app: String)?
  private var _sideViewController           : SideViewController?
  private var _radioPickerTabViewController : NSTabViewController?
  private var _profilesWindowController     : NSWindowController?
  private var _preferencesWindowController  : NSWindowController?
  private var _tcpPingFirstResponseReceived = false
  private var _clientId                     : UUID!

  private var _activity                     : NSObjectProtocol?

  private var _remoteRxAudioStream          : RemoteRxAudioStream?
  private var _opusPlayer                   : OpusPlayer?
  private var _opusEncode                   : OpusEncode?

  private let kVoltageTemperature           = "VoltageTemp"                 // Identifier of toolbar VoltageTemperature toolbarItem

  private let kPreferencesStoryboardName    = "Preferences"
  private let kPreferencesIdentifier        = "Preferences"

  private let kProfilesStoryboardName       = "Profiles"
  private let kProfilesIdentifier           = "Profiles"

  private let kRadioPickerStoryboardName    = "RadioPicker"
  private let kRadioPickerIdentifier        = "RadioPicker"

  private let kSideStoryboardName           = "Side"
  private let kSideIdentifier               = "Side"

  private let kPcwIdentifier                = "PCW"
  private let kPhoneIdentifier              = "Phone"
  private let kRxIdentifier                 = "Rx"
  private let kEqualizerIdentifier          = "Equalizer"

  private let kConnectFailed                = "Initial Connection failed"   // Error messages
  private let kUdpBindFailed                = "Initial UDP bind failed"
  private let kVersionKey                   = "CFBundleShortVersionString"  // CF constants
  private let kBuildKey                     = "CFBundleVersion"

  private let kLocalTab                     = 0
  private let kRemoteTab                    = 1
  private let kSideViewDelay                = 2   // seconds
  
  private enum WindowState {
    case open
    case close
  }

  // ----------------------------------------------------------------------------
  // MARK: - Overriden methods
  
  /// the View has loaded
  ///
  override func viewDidLoad() {
    super.viewDidLoad()

    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif

    // setup & register Defaults
    defaults(from: "Defaults.plist")

    // give the Api access to our logger
    Log.sharedInstance.delegate = NSApp.delegate as! AppDelegate

    // FIXME: Is this necessary???
    _activity = ProcessInfo().beginActivity(options: [.latencyCritical, .idleSystemSleepDisabled], reason: "Good Reason")

    // log versions (before connected)
    _log( "\(AppDelegate.kName) v\(AppDelegate.kVersion.string), \(Api.kName) v\(Api.kVersion.string)", .info, #function, #file, #line)

    // get/create a Client Id
    _clientId = clientId()
    
    // schedule the start of other apps (if any)
    scheduleSupportingApps()
    
    // get the Storyboards
    _preferencesStoryboard = NSStoryboard(name: kPreferencesStoryboardName, bundle: nil)
    _profilesStoryboard = NSStoryboard(name: kProfilesStoryboardName, bundle: nil)
    _radioPickerStoryboard = NSStoryboard(name: kRadioPickerStoryboardName, bundle: nil)
    _sideStoryboard = NSStoryboard(name: kSideStoryboardName, bundle: nil)

    // add notification subscriptions
    addNotifications()
    
    // limit color pickers to the ColorWheel
    NSColorPanel.setPickerMask(NSColorPanel.Options.wheelModeMask)

    // is the default Radio available?
    if let defaultRadio = defaultRadioFound() {
      
      // YES, open the default radio
      radio = openRadio(defaultRadio)
      if radio == nil {
        _log("Error opening default radio, \(defaultRadio.nickname)", .warning,  #function, #file, #line)

        // open the Radio Picker
        openRadioPicker( self)
      }
      
    } else {
      
      // NO, open the Radio Picker
      openRadioPicker( self)
    }
  }

  override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
    
    // activate the menu selections
    return _tcpPingFirstResponseReceived
  }

  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  @IBAction func quitRadio(_ sender: Any) {
    
    _tcpPingFirstResponseReceived = false
    
    // perform an orderly disconnect of all the components
    _api.disconnect(reason: .normal)
    
    _log("Application closed by user", .info,  #function, #file, #line)
    DispatchQueue.main.async {

      // close the app
      NSApp.terminate(sender)
    }
  }

  // ----- TOOLBAR -----
  
  /// Respond to the Mac Audio button
  ///
  /// - Parameter sender:         the Slider
  ///
  @IBAction func opusRxAudio(_ sender: NSButton) {
    
    // update the default value
    Defaults[.macAudioEnabled] = sender.boolState

    // create / remove the RemoteRxAudioStream
    if sender.boolState {
      // create the Stream
      let _ = radio?.requestRxAudioStream(compression: RemoteRxAudioStream.kOpus)
    } else {
      // remove the Stream (if any)
      let _ = _remoteRxAudioStream?.remove()
    }
  }
  /// Respond to the Headphone Gain slider
  ///
  /// - Parameter sender:         the Slider
  ///
  @IBAction func headphoneGain(_ sender: NSSlider) {
    
    _api.radio?.headphoneGain = sender.integerValue
  }
  /// Respond to the Lineout Gain slider
  ///
  /// - Parameter sender:         the Slider
  ///
  @IBAction func lineoutGain(_ sender: NSSlider) {
    
    _api.radio?.lineoutGain = sender.integerValue
  }
  /// Respond to the Headphone Mute button
  ///
  /// - Parameter sender:         the Button
  ///
  @IBAction func muteHeadphone(_ sender: NSButton) {
    
    _api.radio?.headphoneMute = sender.boolState
  }
  /// Respond to the Lineout Mute button
  ///
  /// - Parameter sender:         the Button
  ///
  @IBAction func muteLineout(_ sender: NSButton) {
    
    _api.radio?.lineoutMute = sender.boolState
  }
  /// Respond to the Pan button
  ///
  /// - Parameter sender:         the Button
  ///
  @IBAction func panButton(_ sender: AnyObject) {
    
    // dimensions are dummy values; when created, will be resized to fit its view
    radio?.requestPanadapter(CGSize(width: 50, height: 50))
  }
  /// Respond to the Side button
  ///
  /// - Parameter sender:         the Button
  ///
  @IBAction func sideButton(_ sender: NSButton) {
    
    // update the default value
    Defaults[.sideViewOpen] = sender.boolState
    
    // Open / Close the side view
    sideView(sender.boolState ? .open : .close)
  }
  /// Respond to the Cwx button
  ///
  /// - Parameter sender:         the Button
  ///
  @IBAction func cwxButton(_ sender: NSButton) {
    
    // open / collapse the Cwx view
    
    // FIXME: Implement the Cwx view
    
    Defaults[.cwxViewOpen] = sender.boolState
  }
  /// Respond to the Markers button
  ///
  /// - Parameter sender:         the Button
  ///
  @IBAction func markerButton(_ sender: Any) {
    
    if let button = sender as? NSButton {
      // enable / disable Markers
      Defaults[.markersEnabled] = button.boolState
    
    } else if let _ = sender as? NSMenuItem {
      Defaults[.markersEnabled].toggle()
    }
  }
  /// Respond to the Tnf button
  ///
  /// - Parameter sender:         the Button
  ///
  @IBAction func tnfButton(_ sender: Any) {
    
    if let button = sender as? NSButton {
      // enable / disable Tnf's
      _api.radio!.tnfsEnabled = button.boolState
    
    } else if let _ = sender as? NSMenuItem {
       _api.radio?.tnfsEnabled.toggle()
    }
    Defaults[.tnfsEnabled] = _api.radio!.tnfsEnabled
  }
  /// Respond to the Full Duplex button
  ///
  /// - Parameter sender:         the Button
  ///
  @IBAction func fullDuplexButton(_ sender: NSButton) {
    
    // enable / disable Full Duplex
    _api.radio?.fullDuplexEnabled = sender.boolState
    Defaults[.fullDuplexEnabled] = sender.boolState
  }

  // ----- MENU -----
  
  /// Respond to the Radio Selection menu, show the RadioPicker as a sheet
  ///
  /// - Parameter sender:         the MenuItem
  ///
  @IBAction func openRadioPicker(_ sender: AnyObject) {
    
    // get an instance of the RadioPicker
    let radioPickerTabViewController = _radioPickerStoryboard!.instantiateController(withIdentifier: kRadioPickerIdentifier) as? NSTabViewController

    // make this View Controller the delegate of the RadioPickers
    radioPickerTabViewController!.tabViewItems[kLocalTab].viewController!.representedObject = self
    radioPickerTabViewController!.tabViewItems[kRemoteTab].viewController!.representedObject = self
    
    // select the last-used tab
    radioPickerTabViewController!.selectedTabViewItemIndex = ( Defaults[.remoteViewOpen] == false ? kLocalTab : kRemoteTab )
    
    DispatchQueue.main.async { [weak self] in
      
      // show the RadioPicker sheet
      self?.presentAsSheet(radioPickerTabViewController!)
    }
  }
  /// Respond to the Preferences menu (Command-,)
  ///
  /// - Parameter sender:         the MenuItem
  ///
  @IBAction func openPreferences(_ sender: NSMenuItem) {
    
    // open the Preferences window (if not already open)
    preferencesWindow(.open)
  }
  /// Respond to the Profiles menu (Command-P)
  ///
  /// - Parameter sender:         the MenuItem
  ///
  @IBAction func openProfiles(_ sender: NSMenuItem) {
  
    // open the Profiles window (if not already open)
    profilesWindow(.open)
  }
  /// Respond to Radio->Next Slice (Option-Tab)
  ///
  /// - Parameter sender:         the Menu item
  ///
  @IBAction func nextSlice(_ sender: AnyObject) {
    
    if let slice = Api.sharedInstance.radio!.findActiveSlice() {
      let slicesOnThisPan = Api.sharedInstance.radio!.slices.values.sorted { $0.frequency < $1.frequency }
      var index = slicesOnThisPan.firstIndex(of: slice)!
      
      index = index + 1
      index = index % slicesOnThisPan.count
      
      slice.active = false
      slicesOnThisPan[index].active = true
    }
  }
  /// Respond to the xSDR6000 Quit menu
  ///
  /// - Parameter sender:         the Menu item
  ///
  @IBAction func terminate(_ sender: AnyObject) {
    
    quitRadio(self)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Produce a Client Id (UUID)
  ///
  /// - Returns:                a UUID
  ///
  private func clientId() -> UUID {
    var uuid : UUID
    if let string = Defaults[.clientId] {
      // use the stored string to create a UUID (if possible) else create a new UUID
      uuid = UUID(uuidString: string) ?? UUID()
    } else {
      // none stored, create a new UUID
      uuid = UUID()
      Defaults[.clientId] = uuid.uuidString
    }
    // store the string for later use
    Defaults[.clientId] = uuid.uuidString
    return uuid
  }
  /// Open or Close the Preferences window
  ///
  /// - Parameter state:              the desired state
  ///
  private func preferencesWindow(_ state: WindowState) {
    
    if state == .open {
      // OPENING, is there an existing instance?
      if _preferencesWindowController == nil {
        // NO, get one
        _preferencesWindowController = _preferencesStoryboard!.instantiateController(withIdentifier: kPreferencesIdentifier) as? NSWindowController
        _preferencesWindowController?.window?.delegate = self
        
        DispatchQueue.main.async { [weak self] in
          // show the Preferences window
          self?._preferencesWindowController?.showWindow(self!)
        }
      }
      
    } else {
      // CLOSING, is there an instance?
      if _preferencesWindowController != nil {
        // YES, close it
        DispatchQueue.main.async { [weak self] in
          self?._preferencesWindowController?.window?.close()
          self?._preferencesWindowController = nil
        }
      }
    }
  }
  /// Open or Close the Profiles window
  ///
  /// - Parameter state:              the desired state
  ///
  private func profilesWindow(_ state: WindowState) {
  
    if state == .open {
      // OPENING, is there an existing instance?
      if _profilesWindowController == nil {
        // NO, get an instance of the Profiles
        _profilesWindowController = _profilesStoryboard!.instantiateController(withIdentifier: kProfilesIdentifier) as? NSWindowController
        _profilesWindowController?.window?.delegate = self

        DispatchQueue.main.async { [weak self] in
          // show the Profiles window
          self?._profilesWindowController?.showWindow(self!)
        }
      }
    
    } else {
      // CLOSING, is there an instance?
      if _profilesWindowController != nil {
        // YES, close it
        DispatchQueue.main.async { [weak self] in
          self?._profilesWindowController?.close()
          self?._profilesWindowController = nil
        }
      }
    }
  }
  //
  /// The Preferences or Profiles window is being closed
  ///
  ///   this is called as a result of clicking the window's close button
  ///
  /// - Parameter sender:             the window
  /// - Returns:                      return true to allow
  ///
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    
    // which window?
    if _preferencesWindowController?.window == sender {
      // Preferences
      DispatchQueue.main.async { [weak self] in
        self?._preferencesWindowController = nil
      }
    } else {
      // Profiles
      DispatchQueue.main.async { [weak self] in
        self?._profilesWindowController = nil
      }
    }
    return true
  }
  /// Open or Close the Side view
  ///
  /// - Parameter state:              the desired state
  ///
  private func sideView(_ state: WindowState) {
        
    if state == .open {
      // OPENING, is there an existing instance?
      if _sideViewController == nil {
        // NO, get an instance of the Side view
        _sideViewController = _sideStoryboard!.instantiateController(withIdentifier: kSideIdentifier) as? SideViewController
        
        _log("Side view opened", .info,  #function, #file, #line)
        DispatchQueue.main.async { [weak self] in
          // add it to the split view
          self?.addChild(self!._sideViewController!)
        }
      }
    } else {
      
      DispatchQueue.main.async { [weak self] in
        // CLOSING, is there an instance?
        if self?._sideViewController != nil {
          
          // YES, collapse it first
          self?.splitViewItems[1].isCollapsed = true
          
          // remove it from the split view
          self?.removeChild(at: 1)
          self?._sideViewController = nil

          self?._log("Side view closed", .info,  #function, #file, #line)
        }
      }
    }
  }
  private func scheduleSupportingApps() {
    
    Defaults[.supportingApps].forEach({

      // if the app is enabled
      if ($0[InfoPrefsViewController.kEnabled] as! Bool) {
        
        // get the App name
        let appName = ($0[InfoPrefsViewController.kAppName] as! String)
        
        // get the startup delay (ms)
        let delay = ($0[InfoPrefsViewController.kDelay] as! Bool) ? $0[InfoPrefsViewController.kInterval] as! Int : 0
        
        // get the Cmd Line parameters
//        let parameters = $0[InfoPrefsViewController.kParameters] as! String
        
        // schedule the launch
        _log("\(appName) launched with delay of \(delay)", .info,  #function, #file, #line)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds( delay )) {
          
          // TODO: Add Parameters
          NSWorkspace.shared.launchApplication(appName)
        }
      }
    })
  }
  /// Set the Window's title. toolbar & side view
  ///
  func updateWindowTitle(_ radio: Radio? = nil) {
    var title = ""
    
    // is there e Radio?
    if let radio = radio {
      
      // format and set the window title
      title = "v\(radio.version.string)     \(radio.nickname) (\(_api.isWan ? "SmartLink" : "Local"))"
    
    }
    DispatchQueue.main.async { [weak self] in
      // Title
      self?.view.window?.title = title
    }
  }
  /// Set the toolbar controls
  ///
  func enableToolbarItems(_ isEnabled: Bool) {
    
    DispatchQueue.main.async { [unowned self] in
      
      // enable / disable the toolbar items
      if let toolbar = self.view.window!.toolbar {
        for item in toolbar.items {
          
          switch item.itemIdentifier.rawValue {
          case "tnfsEnabled":
            item.isEnabled = isEnabled
            if isEnabled { (item.view as! NSButton).boolState = Defaults[.tnfsEnabled] }
          case "markersEnabled":
            item.isEnabled = isEnabled
            if isEnabled { (item.view as! NSButton).boolState = Defaults[.markersEnabled] }
          case "lineoutGain":
            item.isEnabled = isEnabled
            if isEnabled { (item.view as! NSSlider).integerValue = self._api.radio!.lineoutGain }
          case "headphoneGain":
            item.isEnabled = isEnabled
            if isEnabled { (item.view as! NSSlider).integerValue = self._api.radio!.headphoneGain }
          case "macAudioEnabled":
            item.isEnabled = isEnabled
            if isEnabled { (item.view as! NSButton).boolState = Defaults[.macAudioEnabled] }
          case "lineoutMute":
            item.isEnabled = isEnabled
            if isEnabled { (item.view as! NSButton).boolState = self._api.radio!.lineoutMute }
          case "headphoneMute":
            item.isEnabled = isEnabled
            if isEnabled { (item.view as! NSButton).boolState = self._api.radio!.headphoneMute }
          case "fdxEnabled":
            item.isEnabled = isEnabled
            if isEnabled { (item.view as! NSButton).boolState = Defaults[.fullDuplexEnabled] }
          case "cwxEnabled":
            // TODO: CWX ?
            
            //          item.isEnabled = enabled
            //          if enabled { (item.view as! NSButton).boolState = Defaults[.cwxEnabled] }
            break
          case "sideEnabled" :
            item.isEnabled = isEnabled
            if isEnabled { (item.view as! NSButton).boolState = Defaults[.sideViewOpen] }
            
          case "addPan", "VoltageTemp" :
            break
          case "NSToolbarFlexibleSpaceItem", "NSToolbarSpaceItem":
            break
          default:
            Swift.print("\(item.itemIdentifier.rawValue)")
            fatalError()
          }
        }
      }
    }
  }
  /// Check if there is a Default Radio
  ///
  /// - Returns:        a DiscoveryStruct struct or nil
  ///
  private func defaultRadioFound() -> DiscoveryStruct? {
    var defaultRadio: DiscoveryStruct?
    
    // see if there is a valid default Radio
    let defaultSerialNumber = Defaults[.defaultRadioSerialNumber]
    if defaultSerialNumber != "" {
      
      // allow time to hear the UDP broadcasts
      usleep(2_000_000)
      
      // has the default Radio been found?
      if let radio = _radios.first(where: { $0.serialNumber == defaultSerialNumber} ) {
        
        // YES, Save it in case something changed
        Defaults[.defaultRadioSerialNumber] = defaultSerialNumber

        _log("Default radio found, \(radio.nickname) @ \(radio.publicIp), serial \(radio.serialNumber)", .info,  #function, #file, #line)

        defaultRadio = radio
      }
    }
    return defaultRadio
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subscriptions to Notifications
  ///
  private func addNotifications() {
    
    NC.makeObserver(self, with: #selector(guiClientHasBeenAdded(_:)), of: .guiClientHasBeenAdded)

    NC.makeObserver(self, with: #selector(meterHasBeenAdded(_:)), of: .meterHasBeenAdded)
    
    NC.makeObserver(self, with: #selector(radioHasBeenAdded(_:)), of: .radioHasBeenAdded)
    NC.makeObserver(self, with: #selector(radioWillBeRemoved(_:)), of: .radioWillBeRemoved)
    NC.makeObserver(self, with: #selector(radioHasBeenRemoved(_:)), of: .radioHasBeenRemoved)
    
    NC.makeObserver(self, with: #selector(remoteRxAudioStreamHasBeenAdded(_:)), of: .remoteRxAudioStreamHasBeenAdded)
    NC.makeObserver(self, with: #selector(remoteRxAudioStreamWillBeRemoved(_:)), of: .remoteRxAudioStreamWillBeRemoved)

    NC.makeObserver(self, with: #selector(tcpDidDisconnect(_:)), of: .tcpDidDisconnect)

    NC.makeObserver(self, with: #selector(radioDowngrade(_:)), of: .radioDowngrade)
    NC.makeObserver(self, with: #selector(radioUpgrade(_:)), of: .radioUpgrade)
    
    NC.makeObserver(self, with: #selector(tcpPingFirstResponse(_:)), of: .tcpPingFirstResponse)
  }
  /// Process guiClientHasBeenAdded Notification
  ///
  /// - Parameter note:       a Notification instance
  ///
  @objc private func guiClientHasBeenAdded(_ note: Notification) {
    
    if let guiClient = note.object as? GuiClient {
      
      // is it me?
      if guiClient.handle == _api.connectionHandle {
        //YES, persist it
        Defaults[.clientId] = guiClient.clientId
        _log("Gui ClientId persisted:   Id = \(guiClient.clientId ?? "")", .info,  #function, #file, #line)
      }
    }
  }
  /// Process .meterHasBeenAdded Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func meterHasBeenAdded(_ note: Notification) {
    
    let meter = note.object as! Meter
    
    // is it one we need to watch?
    switch meter.name {
    case Meter.ShortName.voltageAfterFuse.rawValue:
      _voltageMeterAvailable = true
      
    case Meter.ShortName.temperaturePa.rawValue:
      _temperatureMeterAvailable = true
      
    default:
      break
    }
    guard _voltageMeterAvailable == true, _temperatureMeterAvailable == true else { return }
    
    DispatchQueue.main.async { [weak self] in
      // start the Voltage/Temperature monitor
      if let toolbar = self?.view.window?.toolbar {
        let monitor = toolbar.items.findElement({  $0.itemIdentifier.rawValue == "VoltageTemp"} ) as! ParameterMonitor
        monitor.activate(radio: self!._api.radio!, shortNames: [.voltageAfterFuse, .temperaturePa], units: ["v", "c"])
      }
    }
  }
  /// Process .radioHasBeenAdded Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func radioHasBeenAdded(_ note: Notification) {
    
    // the Radio class has been initialized
    let radio = note.object as! Radio
    
    _log("Radio initialized: \(radio.nickname)", .info,  #function, #file, #line)

    Defaults[.versionRadio] = radio.discoveryPacket.firmwareVersion
    Defaults[.radioModel] = radio.discoveryPacket.model
    
    // update the title bar
    updateWindowTitle(radio)
  }
  /// Process .radioWillBeRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func radioWillBeRemoved(_ note: Notification) {
    
    // the Radio class is being removed
    if let radio = note.object as? Radio {
      
      _log("Radio will be removed: \(radio.nickname)", .info,  #function, #file, #line)
      
      Defaults[.versionRadio] = ""
      
      // update the toolbar items
      enableToolbarItems(false)
      
      if Defaults[.macAudioEnabled] { self._opusPlayer?.stop() }
      
      // remove all objects on Radio
      radio.removeAll()
    }
  }
  /// Process .radioHasBeenRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func radioHasBeenRemoved(_ note: Notification) {
    
    // the Radio class has been removed
    _log("Radio has been removed", .info, #function, #file, #line)

    // update the window title
    updateWindowTitle()
  }
  /// Process .remoteRxAudioStreamHasBeenAdded Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func remoteRxAudioStreamHasBeenAdded(_ note: Notification) {

    // the RemoteRxAudioStream class has been initialized
    if let remoteRxAudioStream = note.object as? RemoteRxAudioStream {
      _remoteRxAudioStream = remoteRxAudioStream
    
      _log("RemoteRxAudioStream added: StreamId = \(remoteRxAudioStream.id.hex)", .info, #function, #file, #line)

      _opusPlayer = OpusPlayer()
      remoteRxAudioStream.delegate = _opusPlayer
      _opusPlayer?.start()
    }
  }
  /// Process .remoteRxAudioStreamWillBeRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func remoteRxAudioStreamWillBeRemoved(_ note: Notification) {
    
    // the RemoteRxAudioStream is being removed
    if let remoteRxAudioStream = note.object as? RemoteRxAudioStream {
      
      _log("RemoteRxAudioStream will be removed: StreamId = \(remoteRxAudioStream.id.hex)", .info,  #function, #file, #line)

      _opusPlayer?.stop()
      remoteRxAudioStream.delegate = nil
    }
  }
  /// Process .tcpDidDisconnect Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func tcpDidDisconnect(_ note: Notification) {
  
    // get the reason
    let reason = note.object as! Api.DisconnectReason
    
    // TCP connection disconnected
    var explanation: String = ""
    switch reason {
      
    case .normal:
      closeRadio()
      return
      
    case .error(let errorMessage):
      explanation = errorMessage
    }
    // alert if other than normal
    DispatchQueue.main.sync {
      let alert = NSAlert()
      alert.alertStyle = .informational
      alert.messageText = "xSDR6000 has been disconnected."
      alert.informativeText = explanation
      alert.addButton(withTitle: "Ok")
      alert.beginSheetModal(for: self.view.window!, completionHandler: { (response) in })
      self.closeRadio()
    }
  }
  /// Process .radioDowngrade Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func radioDowngrade(_ note: Notification) {
    
    let versions = note.object as! [Version]
    
    // the API & Radio versions are not compatible
    // alert if other than normal
    DispatchQueue.main.async {
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "The Radio's version may not be supported by this version of \(AppDelegate.kName)."
      alert.informativeText = """
      Radio:\t\tv\(versions[1].longString)
      xLib6000:\tv\(versions[0].string)
      
      You can use SmartSDR to DOWNGRADE the Radio
      \t\t\tOR
      Install a newer version of \(AppDelegate.kName)
      """
      alert.addButton(withTitle: "Close")
      alert.addButton(withTitle: "Continue")
      alert.beginSheetModal(for: self.view.window!, completionHandler: { (response) in
        if response == NSApplication.ModalResponse.alertFirstButtonReturn {
          NSApp.terminate(self)
        }
      })
    }
  }
  /// Process .radioUpgrade Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func radioUpgrade(_ note: Notification) {
    
    let versions = note.object as! [Version]
    
    // the API version is later than the Radio version
    DispatchQueue.main.async {
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "The Radio's version may not be supported by this version of \(AppDelegate.kName)."
      alert.informativeText = """
      Radio:\t\tv\(versions[1].longString)
      xLib6000:\tv\(versions[0].string)
      
      You can use SmartSDR to UPGRADE the Radio
      \t\t\tOR
      Install an older version of \(AppDelegate.kName)
      """
      alert.addButton(withTitle: "Close")
      alert.addButton(withTitle: "Continue")
      alert.beginSheetModal(for: self.view.window!, completionHandler: { (response) in
        if response == NSApplication.ModalResponse.alertFirstButtonReturn {
          NSApp.terminate(self)
        }
      })
    }
  }
  /// Process .tcpPingFirstResponse Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func tcpPingFirstResponse(_ note: Notification) {
    
    // receipt of the first Ping response indicates the Radio is fully initialized
    _tcpPingFirstResponseReceived = true
    
    // update the toolbar items
    enableToolbarItems(true)

    // delay the opening of the side view (allows Slice(s) to be instantiated, if any)
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds( kSideViewDelay )) { [weak self] in
      
      // FIXME: Is this a hack?

      // show/hide the Side view
      self?.sideView( Defaults[.sideViewOpen] ? .open : .close)
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - RadioPicker delegate methods
  
  var token: Token?

  /// Connect the selected Radio
  ///
  /// - Parameters:
  ///   - radio:                the DiscoveryStruct
  ///   - isWan:                Local / Wan
  ///   - wanHandle:            Wan handle (if any)
  /// - Returns:                success / failure
  ///
  func openRadio(_ radio: DiscoveryStruct?, isWan: Bool = false, wanHandle: String = "") -> Radio? {
    
    if let _ = _radioPickerTabViewController {
      self._radioPickerTabViewController = nil
    }

    // exit if no Radio selected
    guard let selectedRadio = radio else { return nil }
    
//    _api.isWan = isWan
//    _api.wanConnectionHandle = wanHandle

    // attempt to connect to it
    let station = (Host.current().localizedName ?? "Mac").replacingSpaces(with: "_")
    return _api.connect(selectedRadio,
                        clientStation: station,
                        programName: AppDelegate.kName,
                        clientId: _clientId,
                        isGui: true,
                        isWan: isWan,
                        wanHandle: wanHandle)
  }
  /// Stop the active Radio
  ///
  func closeRadio() {
    // close the Side view (if open)
    sideView(.close)
    
    // close the Profiles window (if open)
    profilesWindow(.close)
    
    // close the Preferences window (if open)
    preferencesWindow(.close)
    
    // turn off the Parameter Monitor
    DispatchQueue.main.async { [weak self] in
      // turn off the Voltage/Temperature monitor
      if let toolbar = self?.view.window?.toolbar {
        let monitor = toolbar.items.findElement({  $0.itemIdentifier.rawValue == "VoltageTemp"} ) as! ParameterMonitor
        monitor.deactivate()
      }
    }
    // perform an orderly disconnect of all the components
    _api.disconnect(reason: .normal)
  }
}
