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
// MARK: - Radio View Controller class implementation
// --------------------------------------------------------------------------------

final class RadioViewController             : NSSplitViewController, RadioPickerDelegate, NSWindowDelegate {

  @objc dynamic public var tnfsEnabled      : Bool { _api.radio?.tnfsEnabled ?? false }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _log                          = Logger.sharedInstance
  private var _api                          = Api.sharedInstance
  private var _mainWindowController         : MainWindowController?
  private var _preferencesStoryboard        : NSStoryboard?
  private var _profilesStoryboard           : NSStoryboard?
  private var _radioPickerStoryboard        : NSStoryboard?
  private var _sideStoryboard               : NSStoryboard?
//  private var _voltageMeterAvailable        = false
//  private var _temperatureMeterAvailable    = false
  private var _sideViewController           : SideViewController?
  private var _radioPickerViewController    : NSViewController?
  private var _profilesWindowController     : NSWindowController?
  private var _preferencesWindowController  : NSWindowController?
  private var _tcpPingFirstResponseReceived = false
  private var _clientId                     : String?

  private var _activity                     : NSObjectProtocol?

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

  private let kLocalTab                     = 0
  private let kRemoteTab                    = 1
  private let kSideViewDelay                = 2   // seconds

  private let kClose                        = "Close "
  private let kDisconnect                   = "Disconnect "
  private let kCancel                       = "Cancel"
  private let kInactive                     = "---"
  private let kRemoteControl                = "Remote Control"
  private let kMultiflexConnect             = "Multiflex Connect"
  private let kMultipleConnections          = "Radio is connected to multiple Stations"
  private let kSingleConnection             = "Radio is connected to one Station"

  private let kAvailable                    = "available"
  private let kInUse                        = "in_use"

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
    Log.sharedInstance.delegate = Logger.sharedInstance
    
    // start Discovery
    let _ = Discovery.sharedInstance

    // FIXME: Is this necessary???
    _activity = ProcessInfo().beginActivity(options: [.latencyCritical, .idleSystemSleepDisabled], reason: "Good Reason")

    // get my version
    _log.version = Version()
    
    _log.logMessage("\(Api.kName) Version: " + versionOf("xLib6000"), .info, #function, #file, #line)

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
    if let discoveryPacket = defaultRadioFound() {
      
      // YES, open the default radio
      openRadio(discoveryPacket)
      
    } else {
      
      // NO, open the Radio Picker
      openRadioPicker( self)
    }
  }

  override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
    
    // Radio Selection || Quit are enabled
    if item.tag == 2 || item.tag == 7 { return true } // Radio Selection || Quit
    
    // all others, after connection established
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
    
    _log.logMessage("Application closed by user", .info,  #function, #file, #line)
    DispatchQueue.main.async {

      // close the app
      NSApp.terminate(sender)
    }
  }

  // ----- TOOLBAR -----
  
  /// Respond to the Pan button
  ///
  /// - Parameter sender:         the Button
  ///
  @IBAction func panButton(_ sender: AnyObject) {
    
    // dimensions are dummy values; when created, will be resized to fit its view
    _api.radio?.requestPanadapter(CGSize(width: 50, height: 50))
  }

  // ----- MENU -----
  
  /// Respond to the Radio Selection menu, show the RadioPicker as a sheet
  ///
  /// - Parameter sender:         the MenuItem
  ///
  @IBAction func openRadioPicker(_ sender: AnyObject) {
    
    // get an instance of the RadioPicker
    let radioPickerViewController = _radioPickerStoryboard!.instantiateController(withIdentifier: kRadioPickerIdentifier) as? NSViewController

    // make this View Controller the delegate of the RadioPicker
    radioPickerViewController!.representedObject = self
    
    DispatchQueue.main.async { [weak self] in
      
      // show the RadioPicker sheet
      self?.presentAsSheet(radioPickerViewController!)
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
  private func clientId() -> String {
    
    if Defaults[.clientId] == nil {
      // none stored, create a new UUID
      Defaults[.clientId] = UUID().uuidString
    }
    return Defaults[.clientId]!
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
        
        _log.logMessage("Side view opened", .info,  #function, #file, #line)
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

          self?._log.logMessage("Side view closed", .info,  #function, #file, #line)
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
        _log.logMessage("\(appName) launched with delay of \(delay)", .info,  #function, #file, #line)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds( delay )) {
          
          // TODO: Add Parameters
          NSWorkspace.shared.launchApplication(appName)
        }
      }
    })
  }
  /// Check if there is a Default Radio
  ///
  /// - Returns:        a DiscoveryStruct struct or nil
  ///
  private func defaultRadioFound() -> DiscoveryPacket? {
    
    // allow time to hear the UDP broadcasts
    usleep(2_000_000)
    
    // has the default Radio been found?
    if let packet = Discovery.sharedInstance.discoveredRadios.first(where: { $0.serialNumber == Defaults[.defaultRadioSerialNumber]} ) {
      
      _log.logMessage("Default radio found, \(packet.nickname) @ \(packet.publicIp), serial \(packet.serialNumber)", .info,  #function, #file, #line)
      
      return packet
    }
    return nil
  }

  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subscriptions to Notifications
  ///
  private func addNotifications() {
    
//    NC.makeObserver(self, with: #selector(guiClientHasBeenAdded(_:)), of: .guiClientHasBeenAdded)

//    NC.makeObserver(self, with: #selector(meterHasBeenAdded(_:)), of: .meterHasBeenAdded)
    
    NC.makeObserver(self, with: #selector(tcpDidDisconnect(_:)), of: .tcpDidDisconnect)

    NC.makeObserver(self, with: #selector(radioDowngrade(_:)), of: .radioDowngrade)
    
    NC.makeObserver(self, with: #selector(tcpPingFirstResponse(_:)), of: .tcpPingFirstResponse)

    NC.makeObserver(self, with: #selector(xvtrHasBeenAdded(_:)), of: .xvtrHasBeenAdded)
    NC.makeObserver(self, with: #selector(xvtrWillBeRemoved(_:)), of: .xvtrWillBeRemoved)
  }
//  /// Process .meterHasBeenAdded Notification
//  ///
//  /// - Parameter note:         a Notification instance
//  ///
//  @objc private func meterHasBeenAdded(_ note: Notification) {
//    
//    let meter = note.object as! Meter
//    
//    // is it one we need to watch?
//    switch meter.name {
//    case Meter.ShortName.voltageAfterFuse.rawValue:
//      _voltageMeterAvailable = true
//      
//    case Meter.ShortName.temperaturePa.rawValue:
//      _temperatureMeterAvailable = true
//      
//    default:
//      break
//    }
//    guard _voltageMeterAvailable == true, _temperatureMeterAvailable == true else { return }
//    
//    DispatchQueue.main.async { [weak self] in
//      // start the Voltage/Temperature monitor
//      if let toolbar = self?.view.window?.toolbar {
//        let monitor = toolbar.items.findElement({  $0.itemIdentifier.rawValue == "VoltageTemp"} ) as! ParameterMonitor
//        monitor.activate(radio: self!._api.radio!, shortNames: [.voltageAfterFuse, .temperaturePa], units: ["v", "c"])
//      }
//    }
//  }
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

      // FIXME: ????
      
      //      closeRadio(_api.radio!.discoveryPacket)
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
      self.closeRadio(_api.radio!.discoveryPacket)
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
      alert.messageText = "The Radio's version may not be supported by this version of \(Logger.kAppName)."
      alert.informativeText = """
      Radio:\t\tv\(versions[1].longString)
      xLib6000:\tv\(versions[0].string)
      
      You can use SmartSDR to DOWNGRADE the Radio
      \t\t\tOR
      Install a newer version of \(Logger.kAppName)
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
    
    // delay the opening of the side view (allows Slice(s) to be instantiated, if any)
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds( kSideViewDelay )) { [weak self] in
      
      // FIXME: Is this a hack?

      // show/hide the Side view
      self?.sideView( Defaults[.sideViewOpen] ? .open : .close)
    }
  }
  /// Process xvtrHasBeenAdded Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func xvtrHasBeenAdded(_ note: Notification) {
    
    // the Radio class has been initialized
    let xvtr = note.object as! Xvtr
    
    _log.logMessage("Xvtr added: id = \(xvtr.id), Name = \(xvtr.name), Rf Frequency = \(xvtr.rfFrequency.hzToMhz)", .info, #function, #file, #line)
  }
  /// Process xvtrHasBeenRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func xvtrWillBeRemoved(_ note: Notification) {
    
    // the Radio class has been initialized
    let xvtr = note.object as! Xvtr
    
    _log.logMessage("Xvtr will be removed: id = \(xvtr.id)", .info, #function, #file, #line)
  }
  /// Connect the selected Radio
  ///
  /// - Parameters:
  ///   - radio:                the DiscoveryStruct
  ///   - pendingDisconnect:    type, if any
  ///
  func connectRadio(_ discoveredRadio: DiscoveryPacket?, pendingDisconnect: Api.PendingDisconnect = .none) {
    
    if let _ = _radioPickerViewController {
      self._radioPickerViewController = nil
    }
    
    // exit if no Radio selected
    guard let radio = discoveredRadio else { return }
    
    // connect to the radio
    if _api.connect(radio,
                    clientStation: Logger.kAppName,
                    programName: Logger.kAppName,
                    clientId: _clientId,
                    isGui: true,
                    isWan: radio.isWan,
                    wanHandle: radio.wanHandle,
                    pendingDisconnect: pendingDisconnect) {
            
      updateButtonStates()
      
      // WAN connect
      if radio.isWan {
        _api.isWan = true
        _api.connectionHandleWan = radio.wanHandle
      } else {
        _api.isWan = false
        _api.connectionHandleWan = ""
      }
      
    } else {
      updateButtonStates()
    }
  }
  /// Enable / Disable various UI elements
  ///
  private func updateButtonStates() {
    
    DispatchQueue.main.async { [unowned self] in
      if let _ = self._api.radio {

      } else {

      }
    }
  }
  // ----------------------------------------------------------------------------
  // MARK: - RadioPicker delegate methods
  
  var token: Token?

  func openRadio(_ discoveryPacket: DiscoveryPacket) {
    
    let status = discoveryPacket.status.lowercased()
    let guiCount = discoveryPacket.guiClients.count
    let isNewApi = Version(discoveryPacket.firmwareVersion).isNewApi
    
    let handles = [Handle](discoveryPacket.guiClients.keys)
    let clients = [GuiClient](discoveryPacket.guiClients.values)

    // CONNECT, is the selected radio connected to another client?
    switch (isNewApi, status, guiCount) {

    case (false, kAvailable, _):          // oldApi, not connected to another client
      connectRadio(discoveryPacket)
      
    case (false, kInUse, _):              // oldApi, connected to another client
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "Radio is connected to another Client"
      alert.informativeText = kClose + "the Client?"
      alert.addButton(withTitle: kClose + "current client")
      alert.addButton(withTitle: kCancel)

      // ignore if not confirmed by the user
      alert.beginSheetModal(for: view.window!, completionHandler: { (response) in
        // close the connected Radio if the YES button pressed

        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:
          self.connectRadio(discoveryPacket, pendingDisconnect: .oldApi)
          sleep(1)
          self._api.disconnect()
          sleep(1)
          self.openRadioPicker(self)

        default:  break
        }
        
      })

    case (true, kAvailable, 0):           // newApi, not connected to another client
      connectRadio(discoveryPacket)

    case (true, kAvailable, _):           // newApi, connected to another client
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "Radio is connected to Station: \(clients[0].station)"
      alert.informativeText = kClose + "the Station . . Or . . Connect using Multiflex . . Or . . use " + kRemoteControl
      alert.addButton(withTitle: kClose + "\(clients[0].station)")
      alert.addButton(withTitle: kMultiflexConnect)
      alert.addButton(withTitle: kRemoteControl)
      alert.addButton(withTitle: kCancel)

      // FIXME: Remote Control implementation needed
      alert.buttons[2].isEnabled = false

      // ignore if not confirmed by the user
      alert.beginSheetModal(for: view.window!, completionHandler: { (response) in
        // close the connected Radio if the YES button pressed

        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:  self.connectRadio(discoveryPacket, pendingDisconnect: .newApi(handle: handles[0]))
        case NSApplication.ModalResponse.alertSecondButtonReturn: self.connectRadio(discoveryPacket)
        default:  break
        }
      })

    case (true, kInUse, 2):               // newApi, connected to 2 clients
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = kMultipleConnections
        alert.informativeText = kClose + "one of the Stations . . Or . . use " + kRemoteControl
        alert.addButton(withTitle: kClose + "\(clients[0].station)")
        alert.addButton(withTitle: kClose + "\(clients[1].station)")
        alert.addButton(withTitle: kRemoteControl)
        alert.addButton(withTitle: kCancel)

        // FIXME: Remote Control implementation needed
        alert.buttons[2].isEnabled = false

        // ignore if not confirmed by the user
        alert.beginSheetModal(for: view.window!, completionHandler: { (response) in

          switch response {
          case NSApplication.ModalResponse.alertFirstButtonReturn:  self.connectRadio(discoveryPacket, pendingDisconnect: .newApi(handle: handles[0]))
          case NSApplication.ModalResponse.alertSecondButtonReturn: self.connectRadio(discoveryPacket, pendingDisconnect: .newApi(handle: handles[1]))
          default:  break
          }
        })

    default:
      break
    }
  }
  /// Close  a currently active connection
  ///
  func closeRadio(_ discoveryPacket: DiscoveryPacket) {
    
    let status = discoveryPacket.status.lowercased()
    let guiCount = discoveryPacket.guiClients.count
    let isNewApi = Version(discoveryPacket.firmwareVersion).isNewApi

    let handles = [Handle](discoveryPacket.guiClients.keys)
    let clients = [GuiClient](discoveryPacket.guiClients.values)

    // CONNECT, is the selected radio connected to another client?
    switch (isNewApi, status, guiCount) {
      
    case (false, _, _):                   // oldApi
      self.disconnectXsdr()
      
    case (true, kAvailable, 1):           // newApi, 1 client
      let alert = NSAlert()
      alert.alertStyle = .informational
      alert.messageText = kSingleConnection
      alert.informativeText = kClose + "the Station . . Or . . " + kDisconnect + Logger.kAppName
      if clients[0].station != Logger.kAppName {
        alert.addButton(withTitle: kClose + "\(clients[0].station)")
      } else {
        alert.addButton(withTitle: kInactive)
      }
      alert.addButton(withTitle: kDisconnect + Logger.kAppName)
      alert.addButton(withTitle: kCancel)
      
      alert.buttons[0].isEnabled = clients[0].station != Logger.kAppName

      // ignore if not confirmed by the user
      alert.beginSheetModal(for: view.window!, completionHandler: { (response) in
        // close the connected Radio if the YES button pressed
        
        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:  self._api.disconnectClient( packet: discoveryPacket, handle: handles[0])
        case NSApplication.ModalResponse.alertSecondButtonReturn: self.disconnectXsdr()
        default:  break
        }
      })
      
    case (true, kInUse, 2):           // newApi, 2 clients

      let alert = NSAlert()
      alert.alertStyle = .informational
      alert.messageText = kMultipleConnections
      alert.informativeText = kClose + "a Station . . Or . . " + kDisconnect + Logger.kAppName
      if clients[0].station != Logger.kAppName {
        alert.addButton(withTitle: kClose + "\(clients[0].station)")
      } else {
        alert.addButton(withTitle: kInactive)
      }
      if clients[1].station != Logger.kAppName {
        alert.addButton(withTitle: kClose + "\(clients[1].station)")
      } else {
        alert.addButton(withTitle: kInactive)
      }
      alert.addButton(withTitle: kDisconnect + Logger.kAppName)
      alert.addButton(withTitle: kCancel)
      
      alert.buttons[0].isEnabled = clients[0].station != Logger.kAppName
      alert.buttons[1].isEnabled = clients[1].station != Logger.kAppName

      // ignore if not confirmed by the user
      alert.beginSheetModal(for: view.window!, completionHandler: { (response) in
        
        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:  self._api.disconnectClient( packet: discoveryPacket, handle: handles[0])
        case NSApplication.ModalResponse.alertSecondButtonReturn: self._api.disconnectClient( packet: discoveryPacket, handle: handles[1])
        case NSApplication.ModalResponse.alertThirdButtonReturn:  self.disconnectXsdr()
        default:  break
        }
      })

    default:
        self.disconnectXsdr()
    }
  }


  func disconnectXsdr() {
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
