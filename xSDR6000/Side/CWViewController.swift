//
//  CWViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/15/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class CWViewController                          : NSViewController {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties

  @IBOutlet private weak var _alcLevelIndicator       : LevelIndicator!
  
  @IBOutlet private weak var _breakInButton           : NSButton!
  @IBOutlet private weak var _delaySlider             : NSSlider!
  @IBOutlet private weak var _delayTextfield          : NSTextField!
  @IBOutlet private weak var _iambicButton            : NSButton!
  @IBOutlet private weak var _pitchStepper            : NSStepper!
  @IBOutlet private weak var _pitchTextfield          : NSTextField!
  @IBOutlet private weak var _sidetoneButton          : NSButton!
  @IBOutlet private weak var _sidetoneLevelSlider     : NSSlider!
  @IBOutlet private weak var _sidetonePanSlider       : NSSlider!
  @IBOutlet private weak var _sidetoneLevelTextfield  : NSTextField!
  @IBOutlet private weak var _speedSlider             : NSSlider!
  @IBOutlet private weak var _speedTextfield          : NSTextField!

  private var _radio               : Radio? { return Api.sharedInstance.radio }
  private var _observations        = [NSKeyValueObservation]()

  private let kAlcLevel            = Api.MeterShortName.voltageHwAlc.rawValue

  // ----------------------------------------------------------------------------
  // MARK: - Overriden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    view.translatesAutoresizingMaskIntoConstraints = false
    
    // setup the MicLevel & Compression graphs
    setupBarGraphs()
    
    // start observing properties
    addObservations()
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Respond to a text field
  ///
  /// - Parameter sender:             the textfield
  ///
  @IBAction func textFields(_ sender: NSTextField) {
    
    switch sender.identifier?.rawValue {
    case "DelayTextfield":
      _radio!.transmit!.cwBreakInDelay = sender.integerValue
    case "PitchTextfield":
      _radio!.transmit!.cwPitch = sender.integerValue
    case "SidetoneLevelTextfield":
      _radio!.transmit!.txMonitorGainCw = sender.integerValue
    case "SpeedTextField":
      _radio!.transmit!.cwSpeed = sender.integerValue
    default:
      fatalError()
    }
  }
  /// Respond to one of the buttons
  ///
  /// - Parameter sender:             the button
  ///
  @IBAction func buttons(_ sender: NSButton) {
    
    switch sender.identifier!.rawValue {
    case "BreakInButton":
      _radio!.transmit?.cwBreakInEnabled = sender.boolState
    case "IambicButton":
      _radio!.transmit?.cwIambicEnabled = sender.boolState
    case "SidetoneButton":
      _radio!.transmit?.cwSidetoneEnabled = sender.boolState
    default:
      fatalError()
    }
  }
  /// Respond to one of the sliders
  ///
  /// - Parameter sender:             the slider
  ///
  @IBAction func sliders(_ sender: NSSlider) {
    
    switch sender.identifier!.rawValue {
    case "DelaySlider":
      _radio!.transmit!.cwBreakInDelay = sender.integerValue
    case "SidetoneLevelSlider":
      _radio!.transmit?.txMonitorGainCw = sender.integerValue
    case "SidetonePanSlider":
      _radio!.transmit?.txMonitorPanCw = sender.integerValue
    case "SpeedSlider":
      _radio!.transmit?.cwSpeed = sender.integerValue
    default:
      fatalError()
    }
  }
  /// Respond to the Pitch stepper
  ///
  /// - Parameter sender:             the slider
  ///
  @IBAction func steppers(_ sender: NSStepper) {
  
    _radio!.transmit!.cwPitch = sender.integerValue
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Setup graph styles, legends and resting levels
  ///
  private func setupBarGraphs() {
    
    _alcLevelIndicator.legends = [
      (0, "0", 0),
      (5, "100", 1.0),
      (nil, "ALC", 0)
    ]
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  /// Add observations
  ///
  private func addObservations() {
    
    let transmit = _radio!.transmit!
    
    // Transmit observations
    _observations.append( transmit.observe(\.cwBreakInDelay, options: [.initial, .new]) { [weak self] (transmit, change) in
      self?.cwChange(transmit, change) })
    _observations.append( transmit.observe(\.cwBreakInEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
      self?.cwChange(transmit, change) })
    _observations.append( transmit.observe(\.cwIambicEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
      self?.cwChange(transmit, change) })
    _observations.append( transmit.observe(\.cwPitch, options: [.initial, .new]) { [weak self] (transmit, change) in
      self?.cwChange(transmit, change) })
    _observations.append( transmit.observe(\.cwSidetoneEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
      self?.cwChange(transmit, change) })
    _observations.append( transmit.observe(\.cwSpeed, options: [.initial, .new]) { [weak self] (transmit, change) in
      self?.cwChange(transmit, change) })
    _observations.append( transmit.observe(\.txMonitorGainCw, options: [.initial, .new]) { [weak self] (transmit, change) in
      self?.cwChange(transmit, change) })
    _observations.append( transmit.observe(\.txMonitorPanCw, options: [.initial, .new]) { [weak self] (transmit, change) in
      self?.cwChange(transmit, change) })

    // Cw Meter parameters
    _radio!.meters.values.filter { $0.name == kAlcLevel }
      .forEach({
        _observations.append( $0.observe(\.value, options: [.initial, .new]) { [weak self] (meter, change) in
          self?.meterChange(meter, change) })
      })
  }
  /// Update all control values
  ///
  /// - Parameter eq:               the Transmit
  ///
  private func cwChange(_ transmit: Transmit, _ change: Any) {
    
    DispatchQueue.main.async { [weak self] in
      self?._breakInButton.boolState = transmit.cwBreakInEnabled
      self?._delaySlider.integerValue = transmit.cwBreakInDelay
      self?._delayTextfield.integerValue = transmit.cwBreakInDelay
      self?._iambicButton.boolState = transmit.cwIambicEnabled
      self?._pitchStepper.integerValue = transmit.cwPitch
      self?._pitchTextfield.integerValue = transmit.cwPitch
      self?._sidetoneButton.boolState = transmit.cwSidetoneEnabled
      self?._sidetoneLevelSlider.integerValue = transmit.txMonitorGainCw
      self?._sidetonePanSlider.integerValue = transmit.txMonitorPanCw
      self?._sidetoneLevelTextfield.integerValue = transmit.txMonitorGainCw
      self?._speedSlider.integerValue = transmit.cwSpeed
      self?._speedTextfield.integerValue = transmit.cwSpeed
    }
  }
  /// Respond to changes in a Meter
  ///
  /// - Parameters:
  ///   - object:                       a Meter
  ///   - change:                       the change
  ///
  private func meterChange(_ meter: Meter, _ change: Any) {
    
    // which meter?
    switch meter.name {

    case kAlcLevel:
      DispatchQueue.main.async { [weak self] in  self?._alcLevelIndicator.level = CGFloat(meter.value) }
    
    default:
      fatalError()
    }
  }
}
