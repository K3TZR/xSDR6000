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
  
  private var _radio                            : Radio? { Api.sharedInstance.radio }

  // ----------------------------------------------------------------------------
  // MARK: - Overridden  methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.translatesAutoresizingMaskIntoConstraints = false    
    addObservations()
  }

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
  
  private var _observations                     = [NSKeyValueObservation]()

  /// Add observations of various properties used by the view
  ///
  private func addObservations() {
    
    _observations = [
      // ----- Radio Strings -----
      _radio!.observe(\.ipAddress, options: [.initial, .new]) { [weak self] (radio, change) in
        self?.updateRadioStringValues(radio, \.ipAddress) },
      _radio!.observe(\.macAddress, options: [.initial, .new]) { [weak self] (radio, change) in
        self?.updateRadioStringValues(radio, \.macAddress) },
      _radio!.observe(\.netmask, options: [.initial, .new]) { [weak self] (radio, change) in
        self?.updateRadioStringValues(radio, \.netmask) },
      _radio!.observe(\.staticIp, options: [.initial, .new]) { [weak self] (radio, change) in
        self?.updateRadioStringValues(radio, \.staticIp) },
      _radio!.observe(\.staticNetmask, options: [.initial, .new]) { [weak self] (radio, change) in
        self?.updateRadioStringValues(radio, \.staticNetmask) },
      _radio!.observe(\.staticGateway, options: [.initial, .new]) { [weak self] (radio, change) in
        self?.updateRadioStringValues(radio, \.staticGateway) },
      
      // ----- Radio Bools -----
      _radio!.observe(\.enforcePrivateIpEnabled, options: [.initial, .new]) { [weak self] (radio, change) in
        self?.updateRadioBoolValues(radio, \.enforcePrivateIpEnabled)  }
    ]
  }
  /// Respond to observations
  ///
  /// - Parameters:
  ///   - rasio:                    the object holding the properties
  ///   - keypath:                  the changed property
  ///
  private func updateRadioStringValues(_ radio: Radio, _ keypath: KeyPath<Radio, String>) {
    
    DispatchQueue.main.async { [weak self] in
      switch keypath {
      case \.ipAddress:                 self?._ipAddressTextField.stringValue     = radio[keyPath: keypath]
      case \.macAddress:                self?._macAddressTextField.stringValue    = radio[keyPath: keypath]
      case \.netmask:                   self?._netMaskTextField.stringValue       = radio[keyPath: keypath]
      case \.staticIp:
        if radio.staticIp == "" && radio.staticNetmask == "" && radio.staticGateway == "" {
          self?._dhcpRadioButton.boolState = true
        } else {
          self?._staticRadioButton.boolState = true
        }
        self?._staticIpAddressTextField.stringValue = radio[keyPath: keypath]
      case \.staticNetmask:
        if radio.staticIp == "" && radio.staticNetmask == "" && radio.staticGateway == "" {
          self?._dhcpRadioButton.boolState = true
        } else {
          self?._staticRadioButton.boolState = true
        }
        self?._staticMaskTextField.stringValue = radio[keyPath: keypath]
      case \.staticGateway:
        if radio.staticIp == "" && radio.staticNetmask == "" && radio.staticGateway == "" {
          self?._dhcpRadioButton.boolState = true
        } else {
          self?._staticRadioButton.boolState = true
        }
        self?._staticGatewayTextField.stringValue = radio[keyPath: keypath]
        
      default:                          fatalError()
      }
    }
  }
  /// Respond to observations
  ///
  /// - Parameters:
  ///   - radio:                    the object holding the properties
  ///   - keypath:                  the changed property
  ///
  private func updateRadioBoolValues(_ radio: Radio, _ keypath: KeyPath<Radio, Bool>) {
    
    DispatchQueue.main.async { [weak self] in
      switch keypath {
      case \.enforcePrivateIpEnabled:   self?._enforcePrivateIpCheckbox.boolState = radio[keyPath: keypath]
      default:                          fatalError()
      }
    }
  }
}
