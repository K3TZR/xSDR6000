//
//  RxPrefsViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 12/13/18.
//  Copyright © 2018 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class RxPrefsViewController: NSViewController {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _calibrateButton: NSButton!
  @IBOutlet private weak var _calFreqTextField        : NSTextField!
  @IBOutlet private weak var _calOffsetTextField      : NSTextField!  
  @IBOutlet private weak var _snapTuneCheckbox        : NSButton!
  @IBOutlet private weak var _singleClickCheckbox     : NSButton!
  @IBOutlet private weak var _startSliceMinCheckbox   : NSButton!
  @IBOutlet private weak var _muteLocalAudioCheckbox  : NSButton!
  @IBOutlet private weak var _binauralAudioCheckbox   : NSButton!
  
  private var _radio                        : Radio? { return Api.sharedInstance.radio }
  private var _observations                 = [NSKeyValueObservation]()
  
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
  
  /// Respond to the Calibrate buttons
  ///
  /// - Parameter sender:             the button
  ///
  @IBAction func calibrate(_ sender: NSButton) {

    _radio?.startCalibration = true
  }
  /// Respond to one of the check boxes
  ///
  /// - Parameter sender:             the button
  ///
  @IBAction func checkBoxes(_ sender: NSButton) {
    
    switch sender.identifier?.rawValue {
    case "SnapTune":
      // TODO:
      break
    case "ClickTune":
      // TODO:
      break
    case "StartMinized":
      // TODO:
      break
    case "MuteLocalAudio":
      _radio!.muteLocalAudio = sender.boolState
    case "BinauralAudio":
      _radio!.binauralRxEnabled = sender.boolState
    default:
      fatalError()
    }
  }
  /// Respond to one of text fields
  ///
  /// - Parameter sender:             the textfield
  ///
  @IBAction func textFields(_ sender: NSTextField) {
    
    switch sender.identifier?.rawValue {
    case "CalFreq":
      _radio!.calFreq = sender.integerValue
    case "Offset":
      _radio!.freqErrorPpb = sender.integerValue
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
      _radio!.observe(\.calFreq, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._calFreqTextField.integerValue = radio.calFreq },
      
      _radio!.observe(\.freqErrorPpb, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._calOffsetTextField.integerValue = radio.freqErrorPpb },
      
      _radio!.observe(\.snapTuneEnabled, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._snapTuneCheckbox.boolState = radio.snapTuneEnabled },
      
      _radio!.observe(\.muteLocalAudio, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._muteLocalAudioCheckbox.boolState = radio.muteLocalAudio },
      
      _radio!.observe(\.binauralRxEnabled, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._binauralAudioCheckbox.boolState = radio.binauralRxEnabled },
    ]
  }
  /// Process observations
  ///
  /// - Parameters:
  ///   - slice:                    the panadapter being observed
  ///   - change:                   the change
  ///
//  private func changeHandler(_ radio: Radio, _ change: Any) {
//
//    DispatchQueue.main.async { [weak self] in
//      self?._calFreqTextField.integerValue = radio.calFreq
//      self?._calOffsetTextField.integerValue = radio.freqErrorPpb
//      self?._snapTuneCheckbox.boolState = radio.snapTuneEnabled
//      self?._muteLocalAudioCheckbox.boolState = radio.muteLocalAudio
//      self?._binauralAudioCheckbox.boolState = radio.binauralRxEnabled
//    }
//  }
}
