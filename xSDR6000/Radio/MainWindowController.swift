//
//  MainWindowController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 3/1/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

// --------------------------------------------------------------------------------
// MARK: - Main Window Controller class implementation
// --------------------------------------------------------------------------------

final class MainWindowController                  : NSWindowController, NSWindowDelegate, RadioPickerDelegate, WanManagerDelegate, WanServerDelegate {
  func wanUserSettings(name: String, call: String) {
    
  }
  
  func wanRadioConnectReady(handle: String, serial: String) {
    
  }
  
  func wanTestResultsReceived(results: WanTestConnectionResults) {
    
  }
  
  
  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  static let kSearchTime            = 2                 // seconds
  static let kSearchIncrements      : UInt32 = 500_000  // microseconds
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _panButton           : NSButton!
  @IBOutlet private weak var _macAudioButton      : NSButton!
  @IBOutlet private weak var _tnfButton           : NSButton!
  @IBOutlet private weak var _markersButton       : NSButton!
  @IBOutlet private weak var _sideButton          : NSButton!
  @IBOutlet private weak var _fdxButton           : NSButton!
  @IBOutlet private weak var _cwxButton           : NSButton!
  @IBOutlet private weak var _lineoutMuteButton   : NSButton!
  @IBOutlet private weak var _headphoneMuteButton : NSButton!
  @IBOutlet private weak var _lineoutGainSlider   : NSSlider!
  @IBOutlet private weak var _headphoneGainSlider : NSSlider!

  private var _radioPickerViewController    : RadioPickerViewController?

  private var _firstPingResponse            = false
  private var _api                          = Api.sharedInstance
  private let _log                          = Logger.sharedInstance.logMessage
  private var _observations                 = [NSKeyValueObservation]()
  private var _opusPlayer                   : OpusPlayer?
  private var _radioManager                 : RadioManager!

  private var _sideViewController           : SideViewController?
  private var _profilesWindowController     : NSWindowController?
  private var _preferencesWindowController  : NSWindowController?
  private var _temperatureMeterAvailable    = false
  private var _voltageMeterAvailable        = false
  private var _pleaseWait                   : NSAlert!

  private enum WindowState {
    case open
    case close
  }
  private let kSideStoryboardName           = "Side"
  private let kSideIdentifier               = "Side"
  private let kSideViewDelay                = 2   // seconds
  private let kAvailable                    = "available"
  private let kInUse                        = "in_use"

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func awakeFromNib() {
    windowFrameAutosaveName = "MainWindow"

    // limit color pickers to the ColorWheel
    NSColorPanel.setPickerMask(NSColorPanel.Options.wheelModeMask)

    // get my version
    Logger.sharedInstance.version = Version()
  }
  
  func windowDidBecomeMain(_ notification: Notification) {
    // create the Radio Manager
    _radioManager = RadioManager(delegate: self)
    
    // find & open the default (if any)
    findDefault(Defaults.defaultRadio)
    
    addObservations()
    addNotifications()
  }
  // -------------------------------------------------------------

  // FIXME: Is this still needed?????
  
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

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  // ----- Buttons -----


  @IBAction func tnfButton(_ sender: NSButton) {
    Api.sharedInstance.radio!.tnfsEnabled = sender.boolState
  }
  
  @IBAction func markersButton(_ sender: NSButton) {
    Defaults.markersEnabled = sender.boolState
  }
  
  @IBAction func sideButton(_ sender: Any) {
    sideMenu(self)
  }
  
  @IBAction func fdxButton(_ sender: NSButton) {
    Api.sharedInstance.radio!.fullDuplexEnabled = sender.boolState
  }
  
  @IBAction func cwxButton(_ sender: NSButton) {
    Defaults.cwxViewOpen = sender.boolState
  }

  @IBAction func macAudioButton(_ sender: NSButton) {
    Defaults.macAudioEnabled = sender.boolState
    macAudioStartStop()
  }

  @IBAction func muteLineoutButton(_ sender: NSButton) {
    Api.sharedInstance.radio!.lineoutMute = sender.boolState
  }
  
  @IBAction func lineoutGainSlider(_ sender: NSSlider) {
    Api.sharedInstance.radio!.lineoutGain = sender.integerValue
  }
  
  @IBAction func headphoneGainSlider(_ sender: NSSlider) {
    Api.sharedInstance.radio!.headphoneGain = sender.integerValue
  }
  
  @IBAction func muteHeadphoneButton(_ sender: NSButton) {
    Api.sharedInstance.radio!.headphoneMute = sender.boolState
  }

  @IBAction func panButton(_ sender: AnyObject) {
    
    // dimensions are dummy values; when created, will be resized to fit its view
    Api.sharedInstance.radio?.requestPanadapter(CGSize(width: 50, height: 50))
  }
  
  // ----- Menus -----

  @IBAction func radioSelectionMenu(_ sender: AnyObject) {
    openRadioPicker()
  }

  @IBAction func smartLinkMenu(_ sender: NSMenuItem) {

    // FIXME: make this happen immediately????

    sender.boolState.toggle()
    Defaults.smartLinkEnabled = sender.boolState
  }

  @IBAction func tnfMenu(_ sender: NSMenuItem) {
    Defaults.tnfsEnabled.toggle()
    Api.sharedInstance.radio!.tnfsEnabled.toggle()
  }
  
  @IBAction func markersMenu(_ sender: NSMenuItem) {
    Defaults.markersEnabled.toggle()
    _markersButton.boolState = Defaults.markersEnabled
  }
  
  @IBAction func sideMenu(_ sender: Any) {
    Defaults.sideViewOpen = _sideButton.boolState

    // toggle the window
    if _sideViewController == nil {
      // NOT OPEN, open it
      let sideStoryboard = NSStoryboard(name: "Side", bundle: nil)
      _sideViewController = sideStoryboard.instantiateController(withIdentifier: kSideIdentifier) as? SideViewController
      
      _log("Side view opened", .debug,  #function, #file, #line)
      DispatchQueue.main.async { [weak self] in
        // add it to the split view
        if let vc = self?.contentViewController {
          vc.addChild(self!._sideViewController!)
        }
      }
    } else {
      // OPEN, close it
      DispatchQueue.main.async { [weak self] in
        // remove it from the split view
        if let vc = self?.contentViewController {          
          // remove it
          vc.removeChild(at: 1)
        }
        self?._sideViewController = nil
        self?._log("Side view closed", .debug,  #function, #file, #line)
      }
    }
  }
  
  @IBAction func panMenu(_ sender: NSMenuItem) {
    panButton(self)
  }
  
  @IBAction func nextSliceMenu(_ sender: NSMenuItem) {
    
    if let slice = Api.sharedInstance.radio!.findActiveSlice() {
      let slicesOnThisPan = Api.sharedInstance.radio!.slices.values.sorted { $0.frequency < $1.frequency }
      var index = slicesOnThisPan.firstIndex(of: slice)!
      
      index = index + 1
      index = index % slicesOnThisPan.count
      
      slice.active = false
      slicesOnThisPan[index].active = true
    }
  }
  
  @IBAction func quitRadio(_ sender: Any) {
    
    // perform an orderly disconnect of all the components
    if Api.sharedInstance.apiState != .disconnected { Api.sharedInstance.disconnect(reason: .normal) }
    
    _log("Application closed by user", .info,  #function, #file, #line)
    DispatchQueue.main.async {

      // close the app
      NSApp.terminate(sender)
    }
  }

  @IBAction func terminate(_ sender: AnyObject) {
    
    quitRadio(self)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Find and Open the Default Radio (if any) else the Radio Picker
  ///
  /// - Parameter defaultRadio:   a String of the form <wan|local>.<serialNumber>
  ///
  private func findDefault( _ defaultRadio: String?) {
    // embedded func to close sheet
    func closeSheet(_ packet: DiscoveryPacket?) {
      window!.endSheet(_pleaseWait.window)
      if let packet = packet {
        openRadio(packet)
      } else {
        openRadioPicker()
      }
    }
    // is there a default?
    if defaultRadio != nil {
      // YES, create & show the "Please Wait" sheet
      _pleaseWait = NSAlert()
      _pleaseWait.messageText = ""
      _pleaseWait.informativeText = "Searching for the Default Radio"
      _pleaseWait.alertStyle = .informational
      _pleaseWait.addButton(withTitle: "Cancel")
      // Open the sheet (closes on Cancel, timeout or default found)
      _pleaseWait.beginSheetModal(for: window!, completionHandler: { (response) in
        if response == NSApplication.ModalResponse.alertFirstButtonReturn { self.openRadioPicker() }
      })
      // try to find the default radio
      DispatchQueue.main.async {
        let components = defaultRadio!.split(separator: ".")
        if components.count == 2 {
          
          let isWan = (components[0] == "wan")
          let start = DispatchTime.now()
          var packet : DiscoveryPacket?
          while DispatchTime.now() < start + .seconds(MainWindowController.kSearchTime) {
            // has the default Radio been found?
            packet = Discovery.sharedInstance.discoveredRadios.first(where: { $0.serialNumber == components[1] && $0.isWan == isWan} )
            if packet != nil {
              self._log("Default radio found, \(packet!.nickname) @ \(packet!.publicIp), serial \(packet!.serialNumber), isWan = \(packet!.isWan)", .info, #function, #file, #line)
              break
            } else {
              usleep(MainWindowController.kSearchIncrements)
            }
          }
          closeSheet(packet)
        }
      }
    } else {
      // NO Default
      openRadioPicker()
    }
  }
  /// Open the Radio Picker as a sheet
  ///
  func openRadioPicker() {
    let radioPickerStoryboard = NSStoryboard(name: "RadioPicker", bundle: nil)
    if let picker = radioPickerStoryboard.instantiateController(withIdentifier: "RadioPicker") as? RadioPickerViewController {
      picker.delegate = self
      
      DispatchQueue.main.async { [weak self] in
        // show the RadioPicker sheet
        self?.window!.contentViewController!.presentAsSheet(picker)
      }
    }
  }
  /// Open the specified Radio
  /// - Parameter discoveryPacket: a DiscoveryPacket
  ///
  func openRadio(_ packet: DiscoveryPacket) {
    
    _log("OpenRadio initiated: \(packet.nickname)", .debug, #function, #file, #line)
    
    let status = packet.status.lowercased()
    let guiCount = packet.guiClients.count
    let isNewApi = Version(packet.firmwareVersion).isNewApi
    
    let handles = [Handle](packet.guiClients.keys)
    let clients = [GuiClient](packet.guiClients.values)
    
    // CONNECT, is the selected radio connected to another client?
    switch (isNewApi, status, guiCount) {
      
    case (false, kAvailable, _):          // oldApi, not connected to another client
      _radioManager.connectRadio(packet)
      
    case (false, kInUse, _):              // oldApi, connected to another client
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "Radio is connected to another Client"
      alert.informativeText = "Close the Client?"
      alert.addButton(withTitle: "Close current client")
      alert.addButton(withTitle: "Cancel")
      
      // ignore if not confirmed by the user
      alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
        // close the connected Radio if the YES button pressed
        
        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:
          self._radioManager.connectRadio(packet, pendingDisconnect: .oldApi)
          sleep(1)
          self._api.disconnect()
          sleep(1)
          self.openRadioPicker()
          
        default:  break
        }
        
      })
      
    case (true, kAvailable, 0):           // newApi, not connected to another client
      _radioManager.connectRadio(packet)
      
    case (true, kAvailable, _):           // newApi, connected to another client
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "Radio is connected to Station: \(clients[0].station)"
      alert.informativeText = "Close the Station . . Or . . Connect using Multiflex . . Or . . use Remote Control"
      alert.addButton(withTitle: "Close \(clients[0].station)")
      alert.addButton(withTitle: "Multiflex Connect")
      alert.addButton(withTitle: "Remote Control")
      alert.addButton(withTitle: "Cancel")
      
      // FIXME: Remote Control implementation needed
      
      alert.buttons[2].isEnabled = false
      
      // ignore if not confirmed by the user
      alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
        // close the connected Radio if the YES button pressed
        
        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:  self._radioManager.connectRadio(packet, pendingDisconnect: .newApi(handle: handles[0]))
        case NSApplication.ModalResponse.alertSecondButtonReturn: self._radioManager.connectRadio(packet)
        default:  break
        }
      })
      
    case (true, kInUse, 2):               // newApi, connected to 2 clients
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "Radio is connected to multiple Stations"
      alert.informativeText = "Close one of the Stations . . Or . . use Remote Control"
      alert.addButton(withTitle: "Close \(clients[0].station)")
      alert.addButton(withTitle: "Close \(clients[1].station)")
      alert.addButton(withTitle: "Remote Control")
      alert.addButton(withTitle: "Cancel")
      
      // FIXME: Remote Control implementation needed
      
      alert.buttons[2].isEnabled = false
      
      // ignore if not confirmed by the user
      alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
        
        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:  self._radioManager.connectRadio(packet, pendingDisconnect: .newApi(handle: handles[0]))
        case NSApplication.ModalResponse.alertSecondButtonReturn: self._radioManager.connectRadio(packet, pendingDisconnect: .newApi(handle: handles[1]))
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
    
    _log("CloseRadio initiated: \(discoveryPacket.nickname)", .debug, #function, #file, #line)
    
    let status = discoveryPacket.status.lowercased()
    let guiCount = discoveryPacket.guiClients.count
    let isNewApi = Version(discoveryPacket.firmwareVersion).isNewApi
    
    let handles = [Handle](discoveryPacket.guiClients.keys)
    let clients = [GuiClient](discoveryPacket.guiClients.values)
    
    // CONNECT, is the selected radio connected to another client?
    switch (isNewApi, status, guiCount) {
      
    case (false, _, _):                   // oldApi
      self.disconnectApplication()
      
    case (true, kAvailable, 1):           // newApi, 1 client
      // am I the client?
      if handles[0] == _api.connectionHandle {
        // YES, disconnect me
        self.disconnectApplication()
        
      } else {
        
        // FIXME: don't think can ever be executed
        
        // NO, let the user choose what to do
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Radio is connected to one Station"
        alert.informativeText = "Close the Station . . Or . . Disconnect " + Logger.kAppName
        alert.addButton(withTitle: "Close \(clients[0].station)")
        alert.addButton(withTitle: "Disconnect " + Logger.kAppName)
        alert.addButton(withTitle: "Cancel")
        
        alert.buttons[0].isEnabled = clients[0].station != Logger.kAppName
        
        // ignore if not confirmed by the user
        alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
          // close the connected Radio if the YES button pressed
          
          switch response {
          case NSApplication.ModalResponse.alertFirstButtonReturn:  self._api.disconnectClient( packet: discoveryPacket, handle: handles[0])
          case NSApplication.ModalResponse.alertSecondButtonReturn: self.disconnectApplication()
          default:  break
          }
        })
      }
      
    case (true, kInUse, 2):           // newApi, 2 clients
      
      let alert = NSAlert()
      alert.alertStyle = .informational
      alert.messageText = "Radio is connected to multiple Stations"
      alert.informativeText = "Close a Station . . Or . . Disconnect "  + Logger.kAppName
      if clients[0].station != Logger.kAppName {
        alert.addButton(withTitle: "Close \(clients[0].station)")
      } else {
        alert.addButton(withTitle: "---")
      }
      if clients[1].station != Logger.kAppName {
        alert.addButton(withTitle: "Close \(clients[1].station)")
      } else {
        alert.addButton(withTitle: "---")
      }
      alert.addButton(withTitle: "Disconnect " + Logger.kAppName)
      alert.addButton(withTitle: "Cancel")
      
      alert.buttons[0].isEnabled = clients[0].station != Logger.kAppName
      alert.buttons[1].isEnabled = clients[1].station != Logger.kAppName
      
      // ignore if not confirmed by the user
      alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
        
        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:  self._api.disconnectClient( packet: discoveryPacket, handle: handles[0])
        case NSApplication.ModalResponse.alertSecondButtonReturn: self._api.disconnectClient( packet: discoveryPacket, handle: handles[1])
        case NSApplication.ModalResponse.alertThirdButtonReturn:  self.disconnectApplication()
        default:  break
        }
      })
      
    default:
      self.disconnectApplication()
    }
  }
  /// Start / Stop Mac Audio
  ///
  private func macAudioStartStop() {
    let start = Defaults.macAudioEnabled
    
    // what API version?
    if _api.radio!.version.isNewApi {
      // NewApi
      if start {
        _api.radio!.requestRemoteRxAudioStream()
      } else {
        _api.radio!.remoteRxAudioStreamRemove(for: _api.connectionHandle!)
      }
    } else {
      // OldApi
      Api.sharedInstance.radio!.startStopOpusRxAudioStream(state: start)
      if start { usleep(50_000) ; _opusPlayer?.start() } else { _opusPlayer?.stop() }
    }
  }
  /// Disconect this Application
  ///
  private func disconnectApplication() {
    
    // turn off the Parameter Monitor
    DispatchQueue.main.async {
      // turn off the Voltage/Temperature monitor
      if let toolbar = NSApplication.shared.mainWindow!.toolbar {
        let monitor = toolbar.items.findElement({  $0.itemIdentifier.rawValue == "VoltageTemp"} ) as! ParameterMonitor
        monitor.deactivate()
      }
    }
    // perform an orderly disconnect of all the components
    _api.disconnect(reason: .normal)
  }
  /// Set the Window's title
  ///
  private func title() {
    
    // set the title bar
    DispatchQueue.main.async { [unowned self] in
      var title = ""
      // are we connected?
      if let radio = Api.sharedInstance.radio {
        // YES, format and set the window title
        title = "\(radio.packet.nickname) v\(radio.version.longString) \(radio.packet.isWan ? "SmartLink" : "Local")         \(Logger.kAppName) v\(Logger.sharedInstance.version.string)"
        
      } else {
        // NO, show App & Api only
        title = "\(Logger.kAppName) v\(Logger.sharedInstance.version.string)"
      }
      self.window?.title = title
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Observation methods

  /// Add observations of various properties used by the Panadapter
  ///
  private func addObservations() {
    
    _observations = [
      
      Api.sharedInstance.observe(\.radio, options: [.initial, .new]) { [weak self] (object, change) in
        self?.enableButtons(object, change) },
      Api.sharedInstance.observe(\.radio?.tnfsEnabled, options: [.initial, .new]) { [weak self] (object, change) in
        self?.updateButtons(object, \.tnfsEnabled) },
      Api.sharedInstance.observe(\.radio?.fullDuplexEnabled, options: [.initial, .new]) { [weak self] (object, change) in
        self?.updateButtons(object, \.fullDuplexEnabled) },
      Api.sharedInstance.observe(\.radio?.lineoutMute, options: [.initial, .new]) { [weak self] (object, change) in
        self?.updateButtons(object, \.lineoutMute) },
      Api.sharedInstance.observe(\.radio?.headphoneMute, options: [.initial, .new]) { [weak self] (object, change) in
        self?.updateButtons(object, \.headphoneMute) },

      Api.sharedInstance.observe(\.radio?.lineoutGain, options: [.initial, .new]) { [weak self] (object, change) in
        self?.updateSliders(object, \.lineoutGain) },
      Api.sharedInstance.observe(\.radio?.headphoneGain, options: [.initial, .new]) { [weak self] (object, change) in
        self?.updateSliders(object, \.headphoneGain) }
    ]
  }
  /// Respond to observations
  ///
  /// - Parameters:
  ///   - api:                       the object holding the properties
  ///   - change:                    the change
  ///
  private func enableButtons(_ api: Api, _ change: Any) {
    
//    if api.hasPendingDisconnect != .oldApi {
      
      // enable / disable based on state of radio
      DispatchQueue.main.async { [weak self] in
        
        let state = (api.radio != nil)
        
        self?._panButton.isEnabled            = state
        self?._macAudioButton.isEnabled       = state
        self?._tnfButton.isEnabled            = state
        self?._markersButton.isEnabled        = state
        self?._sideButton.isEnabled           = state
        self?._fdxButton.isEnabled            = state
        self?._cwxButton.isEnabled            = state
        self?._lineoutGainSlider.isEnabled    = state
        self?._lineoutMuteButton.isEnabled    = state
        self?._headphoneGainSlider.isEnabled  = state
        self?._headphoneMuteButton.isEnabled  = state
        
        // if enabled, set their states / values
        if state {
          self?._macAudioButton.boolState         = Defaults.macAudioEnabled
          self?._tnfButton.boolState              = api.radio!.tnfsEnabled
          self?._markersButton.boolState          = Defaults.markersEnabled
          self?._sideButton.boolState             = Defaults.sideViewOpen
          self?._fdxButton.boolState              = api.radio!.fullDuplexEnabled
          self?._cwxButton.boolState              = Defaults.cwxViewOpen
          self?._lineoutGainSlider.integerValue   = api.radio!.lineoutGain
          self?._lineoutMuteButton.boolState      = api.radio!.lineoutMute
          self?._headphoneGainSlider.integerValue = api.radio!.headphoneGain
          self?._headphoneMuteButton.boolState    = api.radio!.headphoneMute
          
          if Defaults.macAudioEnabled { self?.macAudioStartStop()}
        }
      }
//    }
  }
  /// Respond to observations
  ///
  /// - Parameters:
  ///   - api:                       the object holding the properties
  ///   - keypath:                   the changed property
  ///
  private func updateButtons(_ api: Api, _ keypath: KeyPath<Radio, Bool>) {
    
    if let radio = api.radio {
      DispatchQueue.main.async { [weak self] in
        switch keypath {
        case \.tnfsEnabled:         self?._tnfButton.boolState = radio[keyPath: keypath]
        case \.fullDuplexEnabled:   self?._fdxButton.boolState = radio[keyPath: keypath]
        case \.lineoutMute:         self?._lineoutMuteButton.boolState = radio[keyPath: keypath]
        case \.headphoneMute:       self?._headphoneMuteButton.boolState = radio[keyPath: keypath]
          
        default:                    fatalError()
        }
      }
    }
  }
  /// Respond to observations
  ///
  /// - Parameters:
  ///   - api:                       the object holding the properties
  ///   - keypath:                   the changed property
  ///
  private func updateSliders(_ api: Api, _ keypath: KeyPath<Radio, Int>) {
    
    if let radio = api.radio {

      DispatchQueue.main.async { [weak self] in
        switch keypath {
        case \.lineoutGain:     self?._lineoutGainSlider.integerValue   = radio[keyPath: keypath]
        case \.headphoneGain:   self?._headphoneGainSlider.integerValue = radio[keyPath: keypath]
          
        default:                fatalError()
        }
      }
    }
  }

  private func menuState(enabled state: Bool) {
    
    let xSDR6000Menu = NSApplication.shared.mainMenu?.item(withTitle: "xSDR6000")
    for menuItem in xSDR6000Menu!.submenu!.items {
      
      switch menuItem.title {
      case "Preferences", "Profiles":   menuItem.isEnabled = state
      default:                          break
      }
    }
  }
  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subscriptions to Notifications
  ///
  private func addNotifications() {
    NC.makeObserver(self, with: #selector(radioHasBeenAdded(_:)), of: .radioHasBeenAdded)
    NC.makeObserver(self, with: #selector(radioWillBeRemoved(_:)), of: .radioWillBeRemoved)
    NC.makeObserver(self, with: #selector(radioHasBeenRemoved(_:)), of: .radioHasBeenRemoved)

    NC.makeObserver(self, with: #selector(tcpPingFirstResponse(_:)), of: .tcpPingFirstResponse)

    NC.makeObserver(self, with: #selector(meterHasBeenAdded(_:)), of: .meterHasBeenAdded)

    NC.makeObserver(self, with: #selector(opusAudioStreamHasBeenAdded(_:)), of: .opusAudioStreamHasBeenAdded)
    NC.makeObserver(self, with: #selector(opusAudioStreamWillBeRemoved(_:)), of: .opusAudioStreamWillBeRemoved)
    
    NC.makeObserver(self, with: #selector(remoteRxAudioStreamHasBeenAdded(_:)), of: .remoteRxAudioStreamHasBeenAdded)
    NC.makeObserver(self, with: #selector(remoteRxAudioStreamWillBeRemoved(_:)), of: .remoteRxAudioStreamWillBeRemoved)
  }
  /// Process .radioHasBeenAdded Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func radioHasBeenAdded(_ note: Notification) {
    
    // the Radio class has been initialized
    let radio = note.object as! Radio
    
    _log("Radio initialized: \(radio.nickname), v\(radio.packet.firmwareVersion)", .info,  #function, #file, #line)

    Defaults.versionRadio = radio.packet.firmwareVersion
    Defaults.radioModel = radio.packet.model
    
    // update the title bar
    title()
    
    menuState(enabled: true)
  }
  /// Process .radioWillBeRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func radioWillBeRemoved(_ note: Notification) {
    
    // the Radio class is being removed
    if let radio = note.object as? Radio {
      
      _log("Radio will be removed: \(radio.nickname)", .info,  #function, #file, #line)
      
      Defaults.versionRadio = ""
      menuState(enabled: false)
      _firstPingResponse = false

      // remove all objects on Radio
      radio.removeAll()
    }
  }
  /// Process .radioHasBeenRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func radioHasBeenRemoved(_ note: Notification) {
    if let name = note.object as? String {
      // the Radio class has been removed
      _log("Radio has been removed: \(name)", .info, #function, #file, #line)
      
      // update the window title
      title()
    }
  }
  /// Process .tcpPingFirstResponse Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func tcpPingFirstResponse(_ note: Notification) {
    
    // receipt of the first Ping response indicates the Radio is fully initialized
    _firstPingResponse = true

    // delay the opening of the side view (allows Slice(s) to be instantiated, if any)
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds( kSideViewDelay )) { [weak self] in
      // show/hide the Side view
      if Defaults.sideViewOpen { self?.sideMenu(self as Any) }
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
      if let toolbar = self?.window?.toolbar {
        let monitor = toolbar.items.findElement({  $0.itemIdentifier.rawValue == "VoltageTemp"} ) as! ParameterMonitor
        monitor.activate(radio: Api.sharedInstance.radio!, shortNames: [.voltageAfterFuse, .temperaturePa], units: ["v", "c"])
      }
    }
  }
  /// Process .opusAudioStreamHasBeenAdded Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func opusAudioStreamHasBeenAdded(_ note: Notification) {

    // the OpusAudioStream has been added
    if let opusAudioStream = note.object as? OpusAudioStream {

      _log("OpusAudioStream added: id = \(opusAudioStream.id.hex)", .info, #function, #file, #line)

      _opusPlayer = OpusPlayer()
      if Defaults.macAudioEnabled { _opusPlayer!.start() }
      opusAudioStream.delegate = _opusPlayer
    }
  }
  /// Process .opusAudioStreamWillBeRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func opusAudioStreamWillBeRemoved(_ note: Notification) {
    
    // the OpusAudioStream is being removed
    if let opusAudioStream = note.object as? OpusAudioStream {
      
      _log("OpusAudioStream will be removed: id = \(opusAudioStream.id.hex)", .info,  #function, #file, #line)

      opusAudioStream.delegate = nil
      _opusPlayer?.stop()
      _opusPlayer = nil
    }
  }
  /// Process .remoteRxAudioStreamHasBeenAdded Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func remoteRxAudioStreamHasBeenAdded(_ note: Notification) {

    // the RemoteRxAudioStream class has been initialized
    if let remoteRxAudioStream = note.object as? RemoteRxAudioStream {
    
      _log("RemoteRxAudioStream added: id = \(remoteRxAudioStream.id.hex)", .info, #function, #file, #line)

      _opusPlayer = OpusPlayer()
      _opusPlayer?.start()
      remoteRxAudioStream.delegate = _opusPlayer
    }
  }
  /// Process .remoteRxAudioStreamWillBeRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func remoteRxAudioStreamWillBeRemoved(_ note: Notification) {
    
    // the RemoteRxAudioStream is being removed
    if let remoteRxAudioStream = note.object as? RemoteRxAudioStream {
      
      _log("RemoteRxAudioStream will be removed: id = \(remoteRxAudioStream.id.hex)", .info,  #function, #file, #line)

      remoteRxAudioStream.delegate = nil
      _opusPlayer?.stop()
      _opusPlayer = nil
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - RadioPicker delegate methods

  /// Open / Close a Radio
  /// - Parameters:
  ///   - packet:       a DiscoveryPacket
  ///   - connect:      Connect / Disconnect
  ///
  func openCloseRadio(_ packet: DiscoveryPacket, connect: Bool) {
    
    switch (connect, packet.isWan) {
    
    // FIXME: add wan open/close
      
    // open Radio
    case (true, true):      _radioManager?.openWanRadio(packet)
    case (true, false):     openRadio(packet)
    
    // close Radio
    case (false, true):     _radioManager?.closeWanRadio(packet)
    case (false, false):    closeRadio(packet)
    }
  }

  // FIXME: Add code wan methods

   
  func testConnection(_ packet: DiscoveryPacket ) {
    
  }

  
  
  
  func auth0Action(login: Bool) {
    
//    if login {
//      _log("SmartLink login initiated", .debug, #function, #file, #line)
//
//      // YES, instantiate the WanManager
//      _wanManager = WanManager(managerDelegate: self, serverDelegate: self, auth0Email: Defaults.smartLinkAuth0Email)
//
//      // Login to auth0
//      // get an instance of Auth0 controller
//      let auth0Storyboard = NSStoryboard(name: "RadioPicker", bundle: nil)
//      if let auth0Vc = auth0Storyboard.instantiateController(withIdentifier: "Auth0Login") as? Auth0ViewController {
//
//        // make the Wan Manager the delegate of the Auth0 controller
//        auth0Vc.representedObject = _wanManager
//
//        // show the Auth0 sheet
//        NSApplication.shared.mainWindow!.contentViewController!.presentAsSheet(auth0Vc)
//      }
//
//    } else {
//      _log("SmartLink logout initiated", .debug, #function, #file, #line)
//
//      // remember the current state
//      Defaults.smartLinkWasLoggedIn = false
//
//      if Defaults.smartLinkAuth0Email != "" {
//        // remove the Keychain entry
//        Keychain.delete( Logger.kAppName + ".oauth-token", account: Defaults.smartLinkAuth0Email)
//        Defaults.smartLinkAuth0Email = ""
//      }
//
//      _wanManager?.logoutOfSmartLink()
//      _wanManager = nil
//      smartLinkUser = ""
//      smartLinkCall = ""
//      smartLinkImage = nil
//      
//      Discovery.sharedInstance.removeSmartLinkRadios()
//
//      // FIXME: ????
//
//      //      openRadioPicker()
//    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - WanManager delegate methods

  var smartLinkImage: NSImage?
  var auth0Email: String?
  var wasLoggedIn: Bool = false
}
