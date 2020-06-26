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


public final class RadioManager : NSObject {
 
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private weak var _delegate                : WanManagerDelegate!

  private var _activity                     : NSObjectProtocol?
  private var _api                          = Api.sharedInstance
  private var _auth0ViewController          : Auth0ViewController?
  private var _clientId                     : String?
  private let _log                          = Logger.sharedInstance.logMessage
  private var _radioPickerViewController    : RadioPickerViewController?
  private var _wanManager                   : WanManager?

  private lazy var _radioMenu = NSApplication.shared.mainMenu?.item(withTitle: "Radio")

  // ----------------------------------------------------------------------------
  // MARK: Initialization
  
  init(delegate: WanManagerDelegate?) {
    super.init()
    
    _delegate = delegate
    
    // FIXME: Is this necessary???
    _activity = ProcessInfo().beginActivity(options: [.latencyCritical, .idleSystemSleepDisabled], reason: "Performance")

    // give the Api access to our logger
    Log.sharedInstance.delegate = Logger.sharedInstance

    // start Discovery
    let _ = Discovery.sharedInstance
    
    _radioMenu?.item(title: "SmartLink enabled")?.boolState = Defaults.smartLinkEnabled
    if Defaults.smartLinkEnabled {
      // only log in if we were logged in previously
      if Defaults.smartLinkWasLoggedIn {
        smartLinkLogin()
      }
    }
    // get/create a Client Id
    _clientId = clientId()
    
    // schedule the start of other apps (if any)
    scheduleSupportingApps()

    addNotifications()
  }

  // ----------------------------------------------------------------------------
  // MARK: Internal methods
  
  func smartLinkLogin() {
    // instantiate the WanManager
    _wanManager = WanManager(delegate: _delegate)

    // attempt a SmartLink login using the auth0Email
    if _wanManager!.smartLinkLogin(using: Defaults.smartLinkAuth0Email) {
      Defaults.smartLinkWasLoggedIn = true
    } else {
      _wanManager!.validateAuth0Credentials()
    }
  }
  
  func smartLinkLogout() {
    // remember the current state
    Defaults.smartLinkWasLoggedIn = false
    
    if let email = Defaults.smartLinkAuth0Email {
      // remove the Keychain entry
      Keychain.delete( Logger.kAppName + ".oauth-token", account: email)
      Defaults.smartLinkAuth0Email = nil
    }
    Discovery.sharedInstance.removeSmartLinkRadios()

    _wanManager?.smartLinkLogout()
    _wanManager = nil
  }

  func openWanRadio(_ packet: DiscoveryPacket) {
    _wanManager?.openRadio(packet)
  }

  func closeWanRadio(_ packet: DiscoveryPacket) {
    _wanManager?.closeRadio(packet)
  }

  func testWanConnection(_ packet: DiscoveryPacket) {
    _wanManager?.testConnection(packet)
  }
  /// Connect the selected Radio
  ///
  /// - Parameters:
  ///   - packet:               the DiscoveryPacket for the desired radio
  ///   - pendingDisconnect:    type, if any
  /// - Returns:                success / failure
  ///
  func connectRadio(_ packet: DiscoveryPacket, isGui: Bool = true, pendingDisconnect: Api.PendingDisconnect = .none) {
    
    // connect to the radio
    _api.connect(packet,
                 station           : Logger.kAppName,
                 program           : Logger.kAppName,
                 clientId          : _clientId,
                 isGui             : isGui,
                 wanHandle         : packet.wanHandle,
                 pendingDisconnect : pendingDisconnect)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
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
        _log("\(appName) launched with delay of \(delay)", .info,  #function, #file, #line)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds( delay )) {
          
          // TODO: Add Parameters
          NSWorkspace.shared.launchApplication(appName)
        }
      }
    })
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
  
  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subscriptions to Notifications
  ///
  private func addNotifications() {
    
    NC.makeObserver(self, with: #selector(tcpDidDisconnect(_:)), of: .tcpDidDisconnect)
  }
  /// Process .tcpDidDisconnect Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func tcpDidDisconnect(_ note: Notification) {
    
    // get the reason
    let reason = note.object as! String
    
    // TCP connection disconnected
    if reason != "User Initiated" {
      
      // alert if other than normal
      DispatchQueue.main.sync {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "xSDR6000 has been disconnected."
        alert.informativeText = reason
        alert.addButton(withTitle: "Ok")
        alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in })
      }
    }
  }
}
