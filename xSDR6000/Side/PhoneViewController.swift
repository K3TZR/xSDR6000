//
//  PhoneViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/16/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class PhoneViewController                   : NSViewController {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _biasButton          : NSButton!
  @IBOutlet private weak var _dexpButton          : NSButton!
  @IBOutlet private weak var _voxButton           : NSButton!
  @IBOutlet private weak var _metInRxButton       : NSButton!
  @IBOutlet private weak var _20dbButton          : NSButton!

  @IBOutlet private weak var _carrierSlider       : NSSlider!
  @IBOutlet private weak var _voxLevelSlider      : NSSlider!
  @IBOutlet private weak var _voxDelaySlider      : NSSlider!
  @IBOutlet private weak var _dexpSlider          : NSSlider!
  @IBOutlet private weak var _txFilterLow         : NSTextField!
  @IBOutlet private weak var _txFilterLowStepper  : NSStepper!
  
  @IBOutlet private weak var _txFilterHigh        : NSTextField!
  @IBOutlet private weak var _txFilterHighStepper : NSStepper!
  
  private var _radio                        : Radio? { Api.sharedInstance.radio }
  
  // ----------------------------------------------------------------------------
  // MARK: - Overriden methods
    
  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.translatesAutoresizingMaskIntoConstraints = false
    
    // start observing properties
    addObservations()
  }

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Respond to one of the buttons
  ///
  /// - Parameter sender:             the button
  ///
  @IBAction func buttons(_ sender: NSButton) {
    
    switch sender.identifier!.rawValue {
    case "Dexp":
      _radio!.transmit!.companderEnabled = sender.boolState
    case "Vox":
      _radio!.transmit!.voxEnabled = sender.boolState
    case "MicBias":
      _radio!.transmit!.micBiasEnabled = sender.boolState
    case "MicBoost":
      _radio!.transmit!.micBoostEnabled = sender.boolState
    case "MeterInRx":
      _radio!.transmit!.metInRxEnabled = sender.boolState
    default:
      fatalError()
    }
  }
  /// Respond to one of the text fields
  ///
  /// - Parameter sender:             the textField
  ///
  @IBAction func textFields(_ sender: NSTextField) {

    switch sender.identifier!.rawValue {
    case "TxHigh":
      _radio!.transmit!.txFilterHigh = sender.integerValue
    case "TxLow":
      _radio!.transmit!.txFilterLow = sender.integerValue
    default:
      fatalError()
    }
  }
  /// Respond to one of the steppers
  ///
  /// - Parameter sender:             the stepper
  ///
@IBAction func steppers(_ sender: NSStepper) {

    switch sender.identifier!.rawValue {
    case "TxHighStepper":
      _radio!.transmit!.txFilterHigh = sender.integerValue
    case "TxLowStepper":
      _radio!.transmit!.txFilterLow = sender.integerValue
    default:
      fatalError()
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  private var _observations                 = [NSKeyValueObservation]()

  /// Add observations of parameters
  ///
  private func addObservations() {
    
    // Transmit parameters
    _observations = [
      (_radio!.transmit).observe(\.carrierLevel, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      (_radio!.transmit).observe(\.companderEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      (_radio!.transmit).observe(\.companderLevel, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      (_radio!.transmit).observe(\.metInRxEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      (_radio!.transmit).observe(\.micBiasEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      (_radio!.transmit).observe(\.micBoostEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      (_radio!.transmit).observe(\.txFilterHigh, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      (_radio!.transmit).observe(\.txFilterLow, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      (_radio!.transmit).observe(\.voxDelay, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      (_radio!.transmit).observe(\.voxEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      (_radio!.transmit).observe(\.voxLevel, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) }
    ]
  }
 /// Respond to changes in parameters
  ///
  /// - Parameters:
  ///   - object:                       a Transmit
  ///   - change:                       the change
  ///
  /// Update all control values
  ///
  /// - Parameter eq:               the Equalizer
  ///
  private func transmitChange(_ transmit: Transmit, _ change: Any) {
    
    DispatchQueue.main.async { [weak self] in
      // Buttons
      self?._biasButton.state = transmit.micBiasEnabled.state
      self?._dexpButton.state = transmit.companderEnabled.state
      self?._metInRxButton.state = transmit.metInRxEnabled.state
      self?._voxButton.state = transmit.voxEnabled.state
      self?._20dbButton.state = transmit.micBoostEnabled.state
      
      // Sliders
      self?._carrierSlider.integerValue = transmit.carrierLevel
      self?._dexpSlider.integerValue = transmit.companderLevel
      self?._voxDelaySlider.integerValue = transmit.voxDelay
      self?._voxLevelSlider.integerValue = transmit.voxLevel
      
      // Textfields
      self?._txFilterHigh.integerValue = transmit.txFilterHigh
      self?._txFilterLow.integerValue = transmit.txFilterLow

      // Steppers
      self?._txFilterHighStepper.integerValue = transmit.txFilterHigh
      self?._txFilterLowStepper.integerValue = transmit.txFilterLow
    }
  }
}
