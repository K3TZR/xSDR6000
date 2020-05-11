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

final class RadioViewController             : NSSplitViewController, RadioPickerDelegate, NSWindowDelegate, WanManagerDelegate, WanServerDelegate {

  @objc dynamic public var tnfsEnabled      : Bool { _api.radio?.tnfsEnabled ?? false }
  
  public private(set) var defaultPacket     : DiscoveryPacket? = nil
  
  @objc dynamic var smartLinkUser  : String = ""
  @objc dynamic var smartLinkCall  : String = ""
  @objc dynamic var smartLinkImage : NSImage? = nil
  public var auth0Email            : String {
    get { Defaults[.smartLinkAuth0Email] }
    set { Defaults[.smartLinkAuth0Email] = newValue }
  }
  public var wasLoggedIn           : Bool {
    get { Defaults[.smartLinkWasLoggedIn] }
    set { Defaults[.smartLinkWasLoggedIn] = newValue }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _log                          = Logger.sharedInstance
  private var _api                          = Api.sharedInstance
  private var _mainWindowController         : MainWindowController?
  private var _radioPickerStoryboard        : NSStoryboard?
  private var _radioPickerViewController    : RadioPickerViewController?
  private var _auth0ViewController          : Auth0ViewController?
  private var _clientId                     : String?
  private var _wanManager                   : WanManager?

  private var _activity                     : NSObjectProtocol?
  private var _tcpPingFirstResponseReceived = false
  private let kVoltageTemperature           = "VoltageTemp"                 // Identifier of toolbar VoltageTemperature toolbarItem


  private let kRadioPickerStoryboardName    = "RadioPicker"
  private let kRadioPickerIdentifier        = "RadioPicker"

  private let kPcwIdentifier                = "PCW"
  private let kPhoneIdentifier              = "Phone"
  private let kRxIdentifier                 = "Rx"
  private let kEqualizerIdentifier          = "Equalizer"

  private let kConnectFailed                = "Initial Connection failed"   // Error messages
  private let kUdpBindFailed                = "Initial UDP bind failed"

  private let kLocalTab                     = 0
  private let kRemoteTab                    = 1

  private let kAvailable                    = "available"
  private let kInUse                        = "in_use"

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
    setupDiscovery()

    // FIXME: Is this necessary???
    _activity = ProcessInfo().beginActivity(options: [.latencyCritical, .idleSystemSleepDisabled], reason: "Good Reason")

    // get my version
    _log.version = Version()

    // get/create a Client Id
    _clientId = clientId()
        
    // schedule the start of other apps (if any)
    scheduleSupportingApps()
    
    // get the Storyboards
    _radioPickerStoryboard = NSStoryboard(name: kRadioPickerStoryboardName, bundle: nil)

    // add notification subscriptions
    addNotifications()
    
    // limit color pickers to the ColorWheel
    NSColorPanel.setPickerMask(NSColorPanel.Options.wheelModeMask)
  }
  
  override func viewDidAppear() {
    super.viewDidAppear()
    
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
    
    // perform an orderly disconnect of all the components
    if _api.apiState != .disconnected { _api.disconnect(reason: .normal) }
    
    _log.logMessage("Application closed by user", .info,  #function, #file, #line)
    DispatchQueue.main.async {

      // close the app
      NSApp.terminate(sender)
    }
  }
    
  /// Respond to the Radio Selection menu, show the RadioPicker as a sheet
  ///
  /// - Parameter sender:         the MenuItem
  ///
  @IBAction func openRadioPicker(_ sender: AnyObject) {
    
    openRadioPicker()
  }
  /// Respond to the Preferences menu (Command-,)
  ///
  /// - Parameter sender:         the MenuItem
  ///
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
  // MARK: - Internal methods
  
  /// Open the Radio Picker as a sheet
  ///
  func openRadioPicker() {
    // get an instance of the RadioPicker
    _radioPickerViewController = _radioPickerStoryboard!.instantiateController(withIdentifier: kRadioPickerIdentifier) as? RadioPickerViewController
    if let picker = _radioPickerViewController {
      // make this View Controller the delegate of the RadioPicker
      picker.representedObject = self
      
      DispatchQueue.main.async { [weak self] in
        // show the RadioPicker sheet
        self?.presentAsSheet(picker)
      }
    }
  }
  /// Open the specified Radio
  /// - Parameter discoveryPacket: a DiscoveryPacket
  ///
  func openRadio(_ discoveryPacket: DiscoveryPacket) {
    
    _log.logMessage("OpenRadio initiated: \(discoveryPacket.nickname)", .debug, #function, #file, #line)

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
      alert.informativeText = "Close the Client?"
      alert.addButton(withTitle: "Close current client")
      alert.addButton(withTitle: "Cancel")

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
      alert.informativeText = "Close the Station . . Or . . Connect using Multiflex . . Or . . use Remote Control"
      alert.addButton(withTitle: "Close \(clients[0].station)")
      alert.addButton(withTitle: "Multiflex Connect")
      alert.addButton(withTitle: "Remote Control")
      alert.addButton(withTitle: "Cancel")

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
        alert.messageText = "Radio is connected to multiple Stations"
        alert.informativeText = "Close one of the Stations . . Or . . use Remote Control"
        alert.addButton(withTitle: "Close \(clients[0].station)")
        alert.addButton(withTitle: "Close \(clients[1].station)")
        alert.addButton(withTitle: "Remote Control")
        alert.addButton(withTitle: "Cancel")

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
    
    _log.logMessage("CloseRadio initiated: \(discoveryPacket.nickname)", .debug, #function, #file, #line)

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
      // am I the client?
      if handles[0] == _api.connectionHandle {
        // YES, disconnect me
        self.disconnectXsdr()
      
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
        alert.beginSheetModal(for: view.window!, completionHandler: { (response) in
          // close the connected Radio if the YES button pressed
          
          switch response {
          case NSApplication.ModalResponse.alertFirstButtonReturn:  self._api.disconnectClient( packet: discoveryPacket, handle: handles[0])
          case NSApplication.ModalResponse.alertSecondButtonReturn: self.disconnectXsdr()
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

  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Start Discovery (Local and Smartlink)
  ///
  private func setupDiscovery() {

    // start Discovery
    let _ = Discovery.sharedInstance

    // is SmartLink enabled, were we previously logged in?
    if Defaults[.smartLinkEnabled] && Defaults[.smartLinkWasLoggedIn] {
      _log.logMessage("SmartLink enabled", .info,  #function, #file, #line)

      // YES, instantiate the WanManager
      _wanManager = WanManager(managerDelegate: self, serverDelegate: self, auth0Email: Defaults[.smartLinkAuth0Email])
    }
    sleep(1)
  }
  /// Connect the selected Radio
  ///
  /// - Parameters:
  ///   - packet:               the DiscoveryPacket for the desired radio
  ///   - pendingDisconnect:    type, if any
  ///
  private func connectRadio(_ packet: DiscoveryPacket?, pendingDisconnect: Api.PendingDisconnect = .none) {
    
//    if let _ = _radioPickerViewController { self._radioPickerViewController = nil }
    
    // exit if no Radio selected
    guard let packet = packet else { return }
    
    // connect to the radio
    if _api.connect(packet,
                    station           : Logger.kAppName,
                    program           : Logger.kAppName,
                    clientId          : _clientId,
                    isGui             : true,
                    wanHandle         : packet.wanHandle,
                    pendingDisconnect : pendingDisconnect) {
       
      
      // FIXME: too may vars
      
      // WAN connect
      if packet.isWan {
        _api.isWan = true
        _api.connectionHandleWan = packet.wanHandle
      } else {
        _api.isWan = false
        _api.connectionHandleWan = ""
      }
    }
  }
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
    // see if there is a valid default Radio
    if let defaultRadio = Defaults[.defaultRadio] {
      
      let components = defaultRadio.split(separator: ".")
      guard components.count == 2 else { return nil }
      
      let isWan = (components[0] == "wan")
      
      // allow time to hear the UDP broadcasts
      usleep(2_000_000)
            
      // has the default Radio been found?
      if let discoveryPacket = Discovery.sharedInstance.discoveredRadios.first(where: { $0.serialNumber == components[1] && $0.isWan == isWan} ) {
        
        _log.logMessage("Default radio found, \(discoveryPacket.nickname) @ \(discoveryPacket.publicIp), serial \(discoveryPacket.serialNumber), isWan = \(isWan)", .info, #function, #file, #line)
        
        return discoveryPacket
      }
    }
    return nil
  }
  /// Disconect
  ///
  private func disconnectXsdr() {
    
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

  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subscriptions to Notifications
  ///
  private func addNotifications() {
    
//    NC.makeObserver(self, with: #selector(guiClientHasBeenAdded(_:)), of: .guiClientHasBeenAdded)

    NC.makeObserver(self, with: #selector(tcpPingFirstResponse(_:)), of: .tcpPingFirstResponse)
    NC.makeObserver(self, with: #selector(tcpDidDisconnect(_:)), of: .tcpDidDisconnect)
    NC.makeObserver(self, with: #selector(radioDowngrade(_:)), of: .radioDowngrade)
    NC.makeObserver(self, with: #selector(xvtrHasBeenAdded(_:)), of: .xvtrHasBeenAdded)
    NC.makeObserver(self, with: #selector(xvtrWillBeRemoved(_:)), of: .xvtrWillBeRemoved)
  }
  /// Process .tcpPingFirstResponse Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func tcpPingFirstResponse(_ note: Notification) {
    
    // receipt of the first Ping response indicates the Radio is fully initialized
    _tcpPingFirstResponseReceived = true
    
//    // delay the opening of the side view (allows Slice(s) to be instantiated, if any)
//    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds( kSideViewDelay )) { [weak self] in
//
//      // FIXME: Is this a hack?
//
//      // show/hide the Side view
//      self?.sideView( Defaults[.sideViewOpen] ? .open : .close)
//    }
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
    
    let versions = note.object as! (apiVersion: String, radioVersion: String)
    
    // the API & Radio versions are not compatible
    // alert if other than normal
    DispatchQueue.main.async {
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "The Radio's version may not be supported by this version of \(Logger.kAppName)."
      alert.informativeText = """
      Radio:\t\tv\(versions.radioVersion)
      xLib6000:\\ttv\(versions.apiVersion)
      
      You can use SmartSDR to DOWNGRADE the Radio
      \t\t\tOR
      Install a newer version of \(Logger.kAppName)
      \t\t\tOR
      CONTINUE to ignore, CLOSE to abort
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

  // ----------------------------------------------------------------------------
  // MARK: - RadioPicker delegate methods
  
  func radioAction(_ packet: DiscoveryPacket, connect: Bool) {
    
    switch (connect, packet.isWan) {
    
    // open Radio
    case (true, true):      _wanManager?.openRadio(packet)
    case (true, false):     openRadio(packet)
    
    // close Radio
    case (false, true):     _wanManager?.closeRadio(packet)
    case (false, false):    closeRadio(packet)
    }
  }
  
  func isActive(_ packet: DiscoveryPacket) -> Bool { _api.radio?.discoveryPacket == packet }
  
  func testConnection(_ packet: DiscoveryPacket) {    
    if packet.isWan { _wanManager?.sendTestConnection(for: packet) }
  }
  
  func setDefault(_ packet: DiscoveryPacket?) {
    if let packet = packet {
      Defaults[.defaultRadio] = (packet.isWan ? "wan" : "local") + "." + packet.serialNumber
    } else {
      Defaults[.defaultRadio] = nil
    }
    defaultPacket = packet
  }
  
  func auth0Action(login: Bool) {
    
    if login {
      _log.logMessage("SmartLink login initiated", .debug, #function, #file, #line)
      
      // YES, instantiate the WanManager
      _wanManager = WanManager(managerDelegate: self, serverDelegate: self, auth0Email: Defaults[.smartLinkAuth0Email])

      // Login to auth0
      // get an instance of Auth0 controller
      let auth0Storyboard = NSStoryboard(name: "RadioPicker", bundle: nil)
      _auth0ViewController = auth0Storyboard.instantiateController(withIdentifier: "Auth0Login") as? Auth0ViewController
      
      // make the Wan Manager the delegate of the Auth0 controller
      _auth0ViewController!.representedObject = _wanManager
      
      // show the Auth0 sheet
      presentAsSheet(_auth0ViewController!)
      
    } else {
      _log.logMessage("SmartLink logout initiated", .debug, #function, #file, #line)
      
      // remember the current state
      Defaults[.smartLinkWasLoggedIn] = false
      
      if Defaults[.smartLinkAuth0Email] != "" {
        // remove the Keychain entry
        Keychain.delete( Logger.kAppName + ".oauth-token", account: Defaults[.smartLinkAuth0Email])
        Defaults[.smartLinkAuth0Email] = ""
      }
      
      _wanManager?.logoutOfSmartLink()
      _wanManager = nil
      smartLinkUser = ""
      smartLinkCall = ""
      smartLinkImage = nil
      
      Discovery.sharedInstance.removeSmartLinkRadios()
      
      openRadioPicker(self)
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - WanServer delegate methods
  
  /// Received User Settings message from WanServer
  /// - Parameters:
  ///   - name:           user name
  ///   - call:           user callsign
  ///
  public func wanUserSettings(name: String, call: String) {
    smartLinkUser = name
    smartLinkCall = call
  }
  /// Received Connect Ready message from WanServer
  /// - Parameters:
  ///   - handle:         the wan handle
  ///   - serial:         the radio serial number
  ///
  public func wanRadioConnectReady(handle: String, serial: String) {
    Swift.print("wanRadioConnectReady")
    
    for packet in Discovery.sharedInstance.discoveredRadios where packet.serialNumber == serial && packet.isWan {
      packet.wanHandle = handle
      openRadio(packet)
    }
  }
  /// Received Wan test results from WanServer
  ///
  /// - Parameter results:  test results
  ///
  public func wanTestResultsReceived(results: WanTestConnectionResults) {
    
    // was it successful?
    let success = (results.forwardTcpPortWorking == true &&
      results.forwardUdpPortWorking == true &&
      results.upnpTcpPortWorking == false &&
      results.upnpUdpPortWorking == false &&
      results.natSupportsHolePunch  == false) ||
      
      (results.forwardTcpPortWorking == false &&
        results.forwardUdpPortWorking == false &&
        results.upnpTcpPortWorking == true &&
        results.upnpUdpPortWorking == true &&
        results.natSupportsHolePunch  == false)
    // Log the result
    Log.sharedInstance.logMessage("SmartLink Test completed \(success ? "successfully" : "with errors")", .info, #function, #file, #line)
    
    DispatchQueue.main.async { [unowned self] in
      
      // set the indicator
      self._radioPickerViewController?.testIndicator.boolState = success
      
      // Alert the user on failure
      if !success {
        
        let alert = NSAlert()
        alert.alertStyle = .critical
        let acc = NSTextField(frame: NSMakeRect(0, 0, 233, 125))
        acc.stringValue = results.string()
        acc.isEditable = false
        acc.drawsBackground = true
        alert.accessoryView = acc
        alert.messageText = "SmartLink Test Failure"
        alert.informativeText = "Check your SmartLink settings"
        
        alert.beginSheetModal(for: self.view.window!, completionHandler: { (response) in
          
          if response == NSApplication.ModalResponse.alertFirstButtonReturn { return }
        })
      }
    }
  }
}
