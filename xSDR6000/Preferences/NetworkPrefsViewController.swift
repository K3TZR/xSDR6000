//
//  NetworkPrefsViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 12/18/18.
//  Copyright © 2018 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class NetworkPrefsViewController: NSViewController {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private  properties
  
  @IBOutlet private weak var _ipAddressTextField        : NSTextField!
  @IBOutlet private weak var _macAddressTextField       : NSTextField!
  @IBOutlet private weak var _netMaskTextField          : NSTextField!
  @IBOutlet private weak var _staticIpAddressTextField  : NSTextField!
  @IBOutlet private weak var _staticMaskTextField       : NSTextField!
  @IBOutlet private weak var _staticGatewayTextField    : NSTextField!
  
  @IBOutlet private weak var _enforcePrivateIpCheckbox  : NSButton!
  
  @IBOutlet private weak var _staticRadioButton         : NSButton!
  @IBOutlet private weak var _dhcpRadioButton           : NSButton!

  @IBOutlet private weak var _applyButton               : NSButton!
  
  private var _radio                            : Radio? { return Api.sharedInstance.radio }
  private var _observations                     = [NSKeyValueObservation]()

  // ----------------------------------------------------------------------------
  // MARK: - Overridden  methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    view.translatesAutoresizingMaskIntoConstraints = false
    
    // begin observing properties
    addObservations()
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Action  methods
  
  @IBAction func apply(_ sender: NSButton) {
    
    if _dhcpRadioButton.boolState {
      // DHCP
      changeNetwork(dhcp: true)
      
    } else {
      // Static, are the values valid?
      if _radio!.staticIp.isValidIP4() && _radio!.staticNetmask.isValidIP4() && _radio!.staticGateway.isValidIP4() {
        // YES, make the change
        changeNetwork(dhcp: false)
      } else {
        // NO, warn the user
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "One or more Invalid Static Values"
        alert.informativeText = "Verify that all are valid IPV4 addresses"
        alert.beginSheetModal(for: NSApp.mainWindow!, completionHandler: { (response) in })
      }
    }
  }
  
  @IBAction func networkTabDhcpStatic(_ sender: NSButton) {
    // no action required
    // required for DHCP / STATIC buttons to function as "Radio Buttons"
  }

  /// Change between DHCP and Static
  ///
  /// - Parameter dhcp:               true = DHCP
  ///
  private func changeNetwork(dhcp: Bool) {
    
    if dhcp {
      // DHCP
      _radio?.staticNetParamsReset()
    
    } else {
      _radio?.staticNetParamsSet()
    }
    // reboot the radio
    _radio?.requestReboot()
    
    sleep(1)
    
    // perform an orderly disconnect of all the components
    Api.sharedInstance.disconnect(reason: .normal)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  /// Add observations of various properties used by the view
  ///
  private func addObservations() {
    
    _observations = [
      _radio!.observe(\.ipAddress, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._ipAddressTextField.stringValue = radio.ipAddress },
      
      _radio!.observe(\.macAddress, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._macAddressTextField.stringValue = radio.macAddress },
      
      _radio!.observe(\.netmask, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._netMaskTextField.stringValue = radio.netmask },
      
      _radio!.observe(\.enforcePrivateIpEnabled, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._enforcePrivateIpCheckbox.boolState = radio.enforcePrivateIpEnabled },
      

      _radio!.observe(\.staticIp, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._staticIpAddressTextField.stringValue = radio.staticIp
        if radio.staticIp == "" && radio.staticNetmask == "" && radio.staticGateway == "" {
          self?._dhcpRadioButton.boolState = true
        } else {
          self?._staticRadioButton.boolState = true
        }
      },
      
      _radio!.observe(\.staticNetmask, options: [.initial, .new]) { [weak self] (radio, change) in
        if radio.staticIp == "" && radio.staticNetmask == "" && radio.staticGateway == "" {
          self?._dhcpRadioButton.boolState = true
        } else {
          self?._staticRadioButton.boolState = true
        }
        self?._staticMaskTextField.stringValue = radio.staticNetmask },
      
      _radio!.observe(\.staticGateway, options: [.initial, .new]) { [weak self] (radio, change) in
        if radio.staticIp == "" && radio.staticNetmask == "" && radio.staticGateway == "" {
          self?._dhcpRadioButton.boolState = true
        } else {
          self?._staticRadioButton.boolState = true
        }
        self?._staticGatewayTextField.stringValue = radio.staticGateway }
    ]
  }
  /// Remove observations
  ///
//  func removeObservations() {
//
//    // invalidate each observation
//    _observations.forEach { $0.invalidate() }
//
//    // remove the tokens
//    _observations.removeAll()
//  }
  /// Process observations
  ///
  /// - Parameters:
  ///   - profile:                  the Radio being observed
  ///   - change:                   the change
  ///
//  private func radioHandler(_ radio: Radio, _ change: Any) {
//    
//    DispatchQueue.main.async { [weak self] in
//      self?._ipAddressTextField.stringValue = radio.ipAddress
//      self?._macAddressTextField.stringValue = radio.macAddress
//      self?._netMaskTextField.stringValue = radio.netmask
//      self?._staticIpAddressTextField.stringValue = radio.staticIp
//      self?._staticMaskTextField.stringValue = radio.staticNetmask
//      self?._staticGatewayTextField.stringValue = radio.staticGateway
//
//      self?._enforcePrivateIpCheckbox.boolState = radio.enforcePrivateIpEnabled
//      
//      if radio.staticIp == "" && radio.staticNetmask == "" && radio.staticGateway == "" {
//        self?._dhcpRadioButton.boolState = true
//      } else {
//        self?._staticRadioButton.boolState = true
//      }
//    }
//  }
}
