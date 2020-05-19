//
//  RadioManager.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/14/20.
//  Copyright © 2020 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

//public final class RadioManager : NSObject, WanManagerDelegate, WanServerDelegate, RadioPickerDelegate, ProfilesDelegate {
  public final class RadioManager : NSObject, WanManagerDelegate, WanServerDelegate, RadioPickerDelegate {

  // ----------------------------------------------------------------------------
  // MARK: - Public properties

  @objc dynamic var smartLinkUser   : String = ""
  @objc dynamic var smartLinkCall   : String = ""
 
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _activity                     : NSObjectProtocol?
  private var _api                          = Api.sharedInstance
  private var _auth0ViewController          : Auth0ViewController?
  private var _clientId                     : String?
  private let _log                          = Logger.sharedInstance
  private var _radioPickerViewController    : RadioPickerViewController?
  private var _wanManager                   : WanManager?

  private let kAvailable                    = "available"
  private let kInUse                        = "in_use"
  
  // ----------------------------------------------------------------------------
  // MARK: -Initialization
  
  override init() {
    super.init()
    
    // FIXME: Is this necessary???
    _activity = ProcessInfo().beginActivity(options: [.latencyCritical, .idleSystemSleepDisabled], reason: "Good Reason")

    // give the Api access to our logger
    Log.sharedInstance.delegate = Logger.sharedInstance

    // start Discovery
    setupDiscovery()

    // get/create a Client Id
    _clientId = clientId()
    
    // schedule the start of other apps (if any)
    scheduleSupportingApps()

    addNotifications()
    
    // is the default Radio available?
    findDefaultRadio()
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Start Discovery (Local and Smartlink)
  ///
  private func setupDiscovery() {

    // start Discovery
    let _ = Discovery.sharedInstance

    // is SmartLink enabled, were we previously logged in?
    if Defaults.smartLinkEnabled && Defaults.smartLinkWasLoggedIn {
      _log.logMessage("SmartLink enabled", .info,  #function, #file, #line)

      // YES, instantiate the WanManager
      _wanManager = WanManager(managerDelegate: self, serverDelegate: self, auth0Email: Defaults.smartLinkAuth0Email)
    }
  }
  var pleaseWait: NSAlert!
  
  func closeSheet() {
    NSApplication.shared.mainWindow?.endSheet(self.pleaseWait.window)
  }
  /// Check if there is a Default Radio
  ///
  private func findDefaultRadio() {
    
    // see if there is a valid default Radio
    if let defaultRadio = Defaults.defaultRadio {
      
      pleaseWait = NSAlert()
      pleaseWait.messageText = ""
      pleaseWait.informativeText = "Searching for the Default Radio"
      pleaseWait.alertStyle = .informational
      pleaseWait.addButton(withTitle: "Cancel")
      pleaseWait.addButton(withTitle: "Ok")
      pleaseWait.buttons[1].isHidden = true
      
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds( 2 )) { [weak self] in
        self?.closeSheet()
      }
      
      pleaseWait.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
        if response != NSApplication.ModalResponse.alertFirstButtonReturn {
          let components = defaultRadio.split(separator: ".")
          if components.count == 2 {
            
            let isWan = (components[0] == "wan")
            
            // has the default Radio been found?
            if let packet = Discovery.sharedInstance.discoveredRadios.first(where: { $0.serialNumber == components[1] && $0.isWan == isWan} ) {
              // Default FOUND, open it
              self._log.logMessage("Default radio found, \(packet.nickname) @ \(packet.publicIp), serial \(packet.serialNumber), isWan = \(packet.isWan)", .info, #function, #file, #line)
              self.openRadio(packet)
              
            } else {
              // Default NOT FOUND, open the Radio Picker
              self.openRadioPicker()
            }
          }
        }
      })
    } else {
      // NO Default, open the Radio Picker
      self.openRadioPicker()
    }
  }
  
  private func scheduleSupportingApps() {
    
    Defaults.supportingApps.forEach({
      
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
  /// Connect the selected Radio
  ///
  /// - Parameters:
  ///   - packet:               the DiscoveryPacket for the desired radio
  ///   - pendingDisconnect:    type, if any
  ///
  private func connectRadio(_ packet: DiscoveryPacket?, pendingDisconnect: Api.PendingDisconnect = .none) {
    
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
    
    if Defaults.clientId == nil {
      // none stored, create a new UUID
      Defaults.clientId = UUID().uuidString
    }
    return Defaults.clientId!
  }
  /// Disconect
  ///
  private func disconnectXsdr() {
    
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
  
  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subscriptions to Notifications
  ///
  private func addNotifications() {
    
    NC.makeObserver(self, with: #selector(tcpDidDisconnect(_:)), of: .tcpDidDisconnect)
    NC.makeObserver(self, with: #selector(radioDowngrade(_:)), of: .radioDowngrade)
    NC.makeObserver(self, with: #selector(xvtrHasBeenAdded(_:)), of: .xvtrHasBeenAdded)
    NC.makeObserver(self, with: #selector(xvtrWillBeRemoved(_:)), of: .xvtrWillBeRemoved)
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
      alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in })
      self.closeRadio(_api.radio!.packet)
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
      alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
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

  var defaultRadio  : String? { Defaults.defaultRadio }
  var radios        : [DiscoveryPacket] { Discovery.sharedInstance.discoveredRadios }
  var isLoggedIn    : Bool { smartLinkUser != "" }
  
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
  
  func isActive(_ packet: DiscoveryPacket) -> Bool { _api.radio?.packet == packet }
  
  func testConnection(_ packet: DiscoveryPacket) {
    if packet.isWan { _wanManager?.sendTestConnection(for: packet) }
  }
  
  func setDefault(_ packet: DiscoveryPacket?) {
    if let packet = packet {
      Defaults.defaultRadio = (packet.isWan ? "wan" : "local") + "." + packet.serialNumber
    } else {
      Defaults.defaultRadio = nil
    }
  }
  
  func auth0Action(login: Bool) {
    
    if login {
      _log.logMessage("SmartLink login initiated", .debug, #function, #file, #line)
      
      // YES, instantiate the WanManager
      _wanManager = WanManager(managerDelegate: self, serverDelegate: self, auth0Email: Defaults.smartLinkAuth0Email)

      // Login to auth0
      // get an instance of Auth0 controller
      let auth0Storyboard = NSStoryboard(name: "RadioPicker", bundle: nil)
      if let auth0Vc = auth0Storyboard.instantiateController(withIdentifier: "Auth0Login") as? Auth0ViewController {
        
        // make the Wan Manager the delegate of the Auth0 controller
        auth0Vc.representedObject = _wanManager
        
        // show the Auth0 sheet
        NSApplication.shared.mainWindow!.contentViewController!.presentAsSheet(auth0Vc)
      }

    } else {
      _log.logMessage("SmartLink logout initiated", .debug, #function, #file, #line)
      
      // remember the current state
      Defaults.smartLinkWasLoggedIn = false
      
      if Defaults.smartLinkAuth0Email != "" {
        // remove the Keychain entry
        Keychain.delete( Logger.kAppName + ".oauth-token", account: Defaults.smartLinkAuth0Email)
        Defaults.smartLinkAuth0Email = ""
      }
      
      _wanManager?.logoutOfSmartLink()
      _wanManager = nil
      smartLinkUser = ""
      smartLinkCall = ""
      smartLinkImage = nil
      
      Discovery.sharedInstance.removeSmartLinkRadios()
      
      openRadioPicker()
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
        
        alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
          
          if response == NSApplication.ModalResponse.alertFirstButtonReturn { return }
        })
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - WanManager delegate methods

   @objc dynamic var smartLinkImage  : NSImage? = nil
   public var auth0Email             : String {
     get { Defaults.smartLinkAuth0Email }
     set { Defaults.smartLinkAuth0Email = newValue }
   }
   public var wasLoggedIn            : Bool {
     get { Defaults.smartLinkWasLoggedIn }
     set { Defaults.smartLinkWasLoggedIn = newValue }
   }
  
  /// Open the Radio Picker as a sheet
  ///
  func openRadioPicker() {
    // get an instance of the RadioPicker
    // get the Storyboards
    let radioPickerStoryboard = NSStoryboard(name: "RadioPicker", bundle: nil)
    _radioPickerViewController = radioPickerStoryboard.instantiateController(withIdentifier: "RadioPicker") as? RadioPickerViewController
    if let picker = _radioPickerViewController {
      // make this View Controller the delegate of the RadioPicker
      picker.representedObject = self
      
      DispatchQueue.main.async { 
        // show the RadioPicker sheet
        NSApplication.shared.mainWindow!.contentViewController!.presentAsSheet(picker)
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
      alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
        // close the connected Radio if the YES button pressed
        
        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:
          self.connectRadio(discoveryPacket, pendingDisconnect: .oldApi)
          sleep(1)
          self._api.disconnect()
          sleep(1)
          self.openRadioPicker()
          
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
      alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
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
      alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
        
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
        alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
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
      alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
        
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
  // MARK: - Profiles delegate methods
  
//  var group : Profile.Group {
//    get { Profile.Group(rawValue: Defaults.profilesTabId)! }
//    set { Defaults.profilesTabId = newValue.rawValue }
//  }
//  @objc dynamic var profile : Profile {
//    get { Api.sharedInstance.radio!.profiles[group.rawValue]! }
//  }
////  @objc dynamic var profileSelection : String {
////    get { Api.sharedInstance.radio!.profiles[profileGroup.rawValue]!.selection }
////  }
//
//  func load(_ row: Int) {
//    _log.logMessage("Load profile: \(group.rawValue)->\(profile.list[row])", .debug, #function, #file, #line)
//    Api.sharedInstance.radio!.sendCommand("profile \(group.rawValue) load \"" + "\(profile.list[row])" + "\"")
//  }
//
//  func create(_ name: String) {
//    var cmd = ""
//
//    switch group {
//    case .tx:     cmd = "profile transmit create \"" + "\(name.replacingOccurrences(of: "*", with: ""))" + "\""
//    case .mic:    cmd = "profile \(group.rawValue) create \"" + "\(name.replacingOccurrences(of: "*", with: ""))" + "\""
//    case .global: break
//    }
//    if cmd != "" {
//      _log.logMessage("Create profile: \(group.rawValue)->\(name)", .debug, #function, #file, #line)
//      Api.sharedInstance.radio!.sendCommand(cmd)
//    }
//  }
//  
//  func reset(_ row: Int) {
//    var cmd = ""
//
//    switch group {
//    case .tx:     cmd = "profile transmit reset \"" + "\(profile.list[row].replacingOccurrences(of: "*", with: ""))" + "\""
//    case .mic:    cmd = "profile \(group.rawValue) reset \"" + "\(profile.list[row].replacingOccurrences(of: "*", with: ""))" + "\""
//    case .global: break
//    }
//    if cmd != "" {
//      Api.sharedInstance.radio!.sendCommand(cmd)
//      _log.logMessage("Reset profile: \(group.rawValue)->\(profile.list[row])", .debug, #function, #file, #line)
//    }
//  }
//  
////  func save(_ name: String) {
////    var cmd = ""
////
////    switch profileGroup {
////    case .tx:     cmd = "profile transmit save \"" + "\(name.replacingOccurrences(of: "*", with: ""))" + "\""
////    case .mic:    cmd = "profile \(profileGroup.rawValue) save \"" + "\(name.replacingOccurrences(of: "*", with: ""))" + "\""
////    case .global: cmd = "profile \(profileGroup.rawValue) save \"" + name + "\""
////    }
////    _log.logMessage("Save profile: \(profileGroup.rawValue)->\(name)", .debug, #function, #file, #line)
////    Api.sharedInstance.radio!.sendCommand(cmd)
////  }
//  
//  func delete(_ row: Int) {
//    var cmd = ""
//
//    switch group {
//    case .tx:     cmd = "profile transmit delete \"" + "\(profile.list[row].replacingOccurrences(of: "*", with: ""))" + "\""
//    case .mic:    cmd = "profile \(group.rawValue) delete \"" + "\(profile.list[row].replacingOccurrences(of: "*", with: ""))" + "\""
//    case .global: cmd = "profile \(group.rawValue) delete \"" + profile.list[row] + "\""
//    }
//    _log.logMessage("Delete profile: \(group.rawValue)->\(profile.list[row])", .debug, #function, #file, #line)
//    Api.sharedInstance.radio!.sendCommand(cmd)
//  }
  
  
  // ----------------------------------------------------------------------------
  // MARK: - Preferences delegate methods


  
}
