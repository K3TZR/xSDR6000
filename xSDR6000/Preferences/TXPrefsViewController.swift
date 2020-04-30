//
//  TXPrefsViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 12/12/18.
//  Copyright © 2018 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class TXPrefsViewController                 : NSViewController {

  @objc dynamic var txProfile               : Profile? { _radio!.profiles[Profile.Group.tx.rawValue] }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private  properties
  
  @IBOutlet private weak var _accTxCheckbox             : NSButton!
  @IBOutlet private weak var _rcaTx1Checkbox            : NSButton!
  @IBOutlet private weak var _rcaTx2Checkbox            : NSButton!
  @IBOutlet private weak var _rcaTx3Checkbox            : NSButton!
  @IBOutlet private weak var _txInhibitCheckbox         : NSButton!

  @IBOutlet private weak var _accTxTextField            : NSTextField!
  @IBOutlet private weak var _rcaTx1TextField           : NSTextField!
  @IBOutlet private weak var _rcaTx2TextField           : NSTextField!
  @IBOutlet private weak var _rcaTx3TextField           : NSTextField!
  @IBOutlet private weak var _txDelayTextField          : NSTextField!
  @IBOutlet private weak var _txTimeoutTextField        : NSTextField!
  @IBOutlet private weak var _maxPowerTextField         : NSTextField!

  @IBOutlet private weak var _txProfilePopUp            : NSPopUpButton!
  @IBOutlet private weak var _rcaInterlockPopup         : NSPopUpButton!
  @IBOutlet private weak var _accInterlockPopup         : NSPopUpButton!
  
  @IBOutlet private weak var _maxPowerSlider            : NSSlider!
  @IBOutlet private weak var _hardWareAlcCheckbox       : NSButton!
  @IBOutlet private weak var _showTxInWaterfallCheckbox : NSButton!
  
  private var _radio                        : Radio? { Api.sharedInstance.radio }
  private var _interlock                    : Interlock? { _radio!.interlock }
  private var _transmit                     : Transmit? { _radio!.transmit }
//  private var _txProfile                    : Profile? { _radio!.profiles[Profile.Group.tx.rawValue] }
  private var _observations                 = [NSKeyValueObservation]()

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
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
  // MARK: - Action methods
  
  /// Respond to the Power slider
  ///
  /// - Parameter sender:             the slider
  ///
  @IBAction func powerSlider(_ sender: NSSlider) {

    _transmit?.maxPowerLevel = sender.integerValue
    _maxPowerTextField.integerValue = sender.integerValue
  }
  /// Respond to a checkbox
  ///
  /// - Parameter sender:             the checkbox
  ///
  @IBAction func checkBoxes(_ sender: NSButton) {
    
    switch sender.identifier?.rawValue {
    case "AccTx":
      _interlock!.accTxEnabled = sender.boolState
    case "RcaTx1":
      _interlock!.tx1Enabled = sender.boolState
    case "RcaTx2":
      _interlock!.tx2Enabled = sender.boolState
    case "RcaTx3":
      _interlock!.tx3Enabled = sender.boolState
    case "TxInhibit":
      _transmit?.inhibit = sender.boolState
    case "HardwareAlc":
      _transmit?.hwAlcEnabled = sender.boolState
    case "TxInWaterfall":
      _transmit?.txInWaterfallEnabled = sender.boolState
    default:
      fatalError()
    }
  }
  /// Respond to a text field
  ///
  /// - Parameter sender:             the textfield
  ///
  @IBAction func textFields(_ sender: NSTextField) {
    
    switch sender.identifier?.rawValue {
    case "AccTxDelay":
      _interlock!.accTxDelay = sender.integerValue
    case "Tx1Delay":
      _interlock!.tx1Delay = sender.integerValue
    case "Tx2Delay":
      _interlock!.tx2Delay = sender.integerValue
    case "Tx3Delay":
      _interlock!.tx3Delay = sender.integerValue
    case "TxDelay":
      _interlock!.txDelay = sender.integerValue
    case "Timeout":
      _interlock!.timeout = sender.integerValue
    default:
      fatalError()
    }
  }
  /// Respond to a popup button
  ///
  /// - Parameter sender:             the button
  ///
  @IBAction func popups(_ sender: NSPopUpButton) {
    
    switch sender.identifier!.rawValue {
    
    case "TxProfile":
      txProfile!.selection = sender.titleOfSelectedItem!
    
    case "RcaInterlocks":
      switch sender.selectedItem?.identifier?.rawValue {
      case "RcaDisabled":
        _interlock!.rcaTxReqEnabled = false
      case "RcaLow":
        _interlock!.rcaTxReqEnabled = true
        _interlock!.rcaTxReqPolarity = false
      case "RcaHigh":
        _interlock!.rcaTxReqEnabled = true
        _interlock!.rcaTxReqPolarity = true
      default:
        fatalError()
      }
    
    case "AccessoryInterlocks":
      switch sender.selectedItem?.identifier?.rawValue {
      case "AccDisabled":
        _interlock!.accTxReqEnabled = false
      case "AccLow":
        _interlock!.accTxReqEnabled = true
        _interlock!.accTxReqPolarity = false
        
      case "AccHigh":
        _interlock!.accTxReqEnabled = true
        _interlock!.accTxReqPolarity = true
      default:
        fatalError()
      }
    default:
      fatalError()
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  /// Add observations of various properties used by the view
  ///
  private func addObservations() {

    _observations = [
      // ----- Profile Strings -----
      txProfile!.observe(\.selection, options: [.initial, .new]) { [weak self] (profile, change) in
        self?.updateProfileStringValues(profile, \.selection) },
      
      // ----- Interlock Bools -----
      _interlock!.observe(\.rcaTxReqEnabled, options: [.initial, .new]) { [weak self] (interlock, change) in
        self?.updateInterlockBoolValues(interlock, \.rcaTxReqEnabled)},
      _interlock!.observe(\.accTxReqEnabled, options: [.initial, .new]) { [weak self] (interlock, change) in
        self?.updateInterlockBoolValues(interlock, \.accTxReqEnabled)},
      _interlock!.observe(\.accTxEnabled, options: [.initial, .new]) { [weak self] (interlock, change) in
        self?.updateInterlockBoolValues(interlock, \.accTxEnabled) },
      _interlock!.observe(\.tx1Enabled, options: [.initial, .new]) { [weak self] (interlock, change) in
        self?.updateInterlockBoolValues(interlock, \.tx1Enabled )},
      _interlock!.observe(\.tx2Enabled, options: [.initial, .new]) { [weak self] (interlock, change) in
        self?.updateInterlockBoolValues(interlock, \.tx2Enabled )},
      _interlock!.observe(\.tx3Enabled, options: [.initial, .new]) { [weak self] (interlock, change) in
        self?.updateInterlockBoolValues(interlock, \.tx3Enabled )},
            
      // ----- Interlock Ints -----
      _interlock!.observe(\.accTxDelay, options: [.initial, .new]) { [weak self] (interlock, change) in
        self?.updateInterlockIntValues(interlock, \.accTxDelay)},
      _interlock!.observe(\.timeout, options: [.initial, .new]) { [weak self] (interlock, change) in
        self?.updateInterlockIntValues(interlock, \.timeout)},
      _interlock!.observe(\.tx1Delay, options: [.initial, .new]) { [weak self] (interlock, change) in
        self?.updateInterlockIntValues(interlock, \.tx1Delay)},
      _interlock!.observe(\.tx2Delay, options: [.initial, .new]) { [weak self] (interlock, change) in
        self?.updateInterlockIntValues(interlock, \.tx2Delay)},
      _interlock!.observe(\.tx3Delay, options: [.initial, .new]) { [weak self] (interlock, change) in
        self?.updateInterlockIntValues(interlock, \.tx3Delay)},
            
      // ----- Transmit Bools -----
      _transmit!.observe(\.inhibit, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.updateTransmitBoolValues(transmit, \.inhibit )},
      _transmit!.observe(\.hwAlcEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.updateTransmitBoolValues(transmit, \.hwAlcEnabled) },
      _transmit!.observe(\.txInWaterfallEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.updateTransmitBoolValues(transmit, \.txInWaterfallEnabled )},
      
      // ----- Transmit Ints -----
      _transmit!.observe(\.maxPowerLevel, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.updateTransmitIntValues(transmit, \.maxPowerLevel) }
    ]
  }
  /// Respond to observations  /// Respond to observations
  ///
  /// - Parameters:
  ///   - profile:                   the object holding the properties
  ///   - keypath:                   the changed property
  ///
  private func updateProfileStringValues(_ profile: Profile, _ keypath: KeyPath<Profile, String>) {
    
    DispatchQueue.main.async { [weak self] in
      switch keypath {
      case \.selection:   self?._txProfilePopUp.selectItem(withTitle: profile[keyPath: keypath])
      default:              fatalError()
      }
    }
  }
  ///
  /// - Parameters:
  ///   - interlock:                 the object holding the properties
  ///   - keypath:                   the changed property
  ///
  private func updateInterlockBoolValues(_ interlock: Interlock, _ keypath: KeyPath<Interlock, Bool>) {
    
    DispatchQueue.main.async { [weak self] in
      switch keypath {
      case \.rcaTxReqEnabled:
        if interlock.rcaTxReqEnabled {
          let selection = interlock.rcaTxReqPolarity ? "Active High" : "Active Low"
          self?._rcaInterlockPopup.selectItem(withTitle: selection)
        } else {
          self?._rcaInterlockPopup.selectItem(withTitle: "Disabled")
        }
      case \.accTxReqEnabled:
        if interlock.accTxReqEnabled {
          let selection = interlock.accTxReqPolarity ? "Active High" : "Active Low"
          self?._accInterlockPopup.selectItem(withTitle: selection)
        } else {
          self?._accInterlockPopup.selectItem(withTitle: "Disabled")
        }
      case \.accTxEnabled:    self?._accTxCheckbox.boolState  = interlock[keyPath: keypath]
      case \.tx1Enabled:      self?._rcaTx1Checkbox.boolState = interlock[keyPath: keypath]
      case \.tx2Enabled:      self?._rcaTx2Checkbox.boolState = interlock[keyPath: keypath]
      case \.tx3Enabled:      self?._rcaTx3Checkbox.boolState = interlock[keyPath: keypath]
      default:              fatalError()
      }
    }
  }
  /// Respond to observations
  ///
  /// - Parameters:
  ///   - interlock:                 the object holding the properties
  ///   - keypath:                   the changed property
  ///
  private func updateInterlockIntValues(_ interlock: Interlock, _ keypath: KeyPath<Interlock, Int>) {
    
    DispatchQueue.main.async { [weak self] in
      switch keypath {
      case \.accTxDelay:  self?._accTxTextField.integerValue    = interlock[keyPath: keypath]
      case \.timeout:     self?._accTxTextField.integerValue    = interlock[keyPath: keypath]
      case \.tx1Delay:    self?._rcaTx1TextField.integerValue   = interlock[keyPath: keypath]
      case \.tx2Delay:    self?._rcaTx2TextField.integerValue   = interlock[keyPath: keypath]
      case \.tx3Delay:    self?._rcaTx3TextField.integerValue   = interlock[keyPath: keypath]
      default:                fatalError()
      }
    }
  }
  /// Respond to observations
  ///
  /// - Parameters:
  ///   - transmit:                  the object holding the properties
  ///   - keypath:                   the changed property
  ///
  private func updateTransmitBoolValues(_ transmit: Transmit, _ keypath: KeyPath<Transmit, Bool>) {
    
    DispatchQueue.main.async { [weak self] in
      switch keypath {
      case \.txInWaterfallEnabled:  self?._showTxInWaterfallCheckbox.boolState  = transmit[keyPath: keypath]
      case \.hwAlcEnabled:          self?._hardWareAlcCheckbox.boolState        = transmit[keyPath: keypath]
      case \.inhibit:               self?._txInhibitCheckbox.boolState          = transmit[keyPath: keypath]
      default:                fatalError()
      }
    }
  }
  /// Respond to observations
  ///
  /// - Parameters:
  ///   - transmit:                  the object holding the properties
  ///   - keypath:                   the changed property
  ///
  private func updateTransmitIntValues(_ transmit: Transmit, _ keypath: KeyPath<Transmit, Int>) {
    
    DispatchQueue.main.async { [weak self] in
      switch keypath {
      case \.maxPowerLevel:
        self?._maxPowerSlider.integerValue    = transmit[keyPath: keypath]
        self?._maxPowerTextField.integerValue = transmit[keyPath: keypath]        
      default:                fatalError()
      }
    }
  }
}
