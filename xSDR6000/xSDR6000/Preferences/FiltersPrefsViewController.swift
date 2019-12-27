//
//  FiltersPrefsViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 12/20/18.
//  Copyright © 2018 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class FiltersPrefsViewController: NSViewController {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _voiceSlider         : NSSlider!
  @IBOutlet private weak var _cwSlider            : NSSlider!
  @IBOutlet private weak var _digitalSlider       : NSSlider!
  @IBOutlet private weak var _voiceAutoCheckbox   : NSButton!
  @IBOutlet private weak var _cwAutoCheckbox      : NSButton!
  @IBOutlet private weak var _digitalAutoCheckbox : NSButton!
  
  private weak var _radio                         : Radio? { return Api.sharedInstance.radio }
  private var _observations                  = [NSKeyValueObservation]()
  
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
  
  /// Respond to one of the sliders
  ///
  /// - Parameter sender:             the slider
  ///
  @IBAction func sliders(_ sender: NSSlider) {
    
    switch sender.identifier?.rawValue {
    case "VoiceSlider":
      _radio!.filterVoiceLevel = sender.integerValue
    case "CwSlider":
      _radio!.filterCwLevel = sender.integerValue
    case "DigitalSlider":
      _radio!.filterDigitalLevel = sender.integerValue
    default:
      fatalError()
    }
  }
  /// Respond to one of the checkboxes
  ///
  /// - Parameter sender:             the checkbox
  ///
  @IBAction func checkBoxes(_ sender: NSButton) {
    
    switch sender.identifier?.rawValue {
    case "VoiceAuto":
      _radio!.filterVoiceAutoEnabled = sender.boolState
    case "CwAuto":
      _radio!.filterCwAutoEnabled = sender.boolState
    case "DigitalAuto":
      _radio!.filterDigitalAutoEnabled = sender.boolState
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
      _radio!.observe(\.filterVoiceLevel, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._voiceSlider.integerValue = radio.filterVoiceLevel },
      
      _radio!.observe(\.filterCwLevel, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._cwSlider.integerValue = radio.filterCwLevel },
     
      _radio!.observe(\.filterDigitalLevel, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._digitalSlider.integerValue = radio.filterDigitalLevel },
      
      _radio!.observe(\.filterVoiceAutoEnabled, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._voiceAutoCheckbox.boolState = radio.filterVoiceAutoEnabled },
      
      _radio!.observe(\.filterCwAutoEnabled, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._cwAutoCheckbox.boolState = radio.filterCwAutoEnabled },
      
      _radio!.observe(\.filterDigitalAutoEnabled, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._digitalAutoCheckbox.boolState = radio.filterDigitalAutoEnabled }
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
//      self?._voiceSlider.integerValue = radio.filterVoiceLevel
//      self?._cwSlider.integerValue = radio.filterCwLevel
//      self?._digitalSlider.integerValue = radio.filterDigitalLevel
//      self?._voiceAutoCheckbox.boolState = radio.filterVoiceAutoEnabled
//      self?._cwAutoCheckbox.boolState = radio.filterCwAutoEnabled
//      self?._digitalAutoCheckbox.boolState = radio.filterDigitalAutoEnabled
//    }
//  }
}
