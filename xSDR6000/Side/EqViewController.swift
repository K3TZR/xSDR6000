//
//  EqViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/1/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - Radio View Controller class implementation
// --------------------------------------------------------------------------------

final class EqViewController                : NSViewController {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var onButton       : NSButton!                     // buttons
  @IBOutlet private weak var rxButton       : NSButton!
  @IBOutlet private weak var txButton       : NSButton!
  @IBOutlet private weak var slider0        : NSSlider!                     // sliders
  @IBOutlet private weak var slider1        : NSSlider!
  @IBOutlet private weak var slider2        : NSSlider!
  @IBOutlet private weak var slider3        : NSSlider!
  @IBOutlet private weak var slider4        : NSSlider!
  @IBOutlet private weak var slider5        : NSSlider!
  @IBOutlet private weak var slider6        : NSSlider!
  @IBOutlet private weak var slider7        : NSSlider!
  
  private var _radio                        : Radio? { return Api.sharedInstance.radio }
  
  private var _equalizerRx                  : Equalizer!                    // Rx Equalizer
  private var _equalizerTx                  : Equalizer!                    // Tx Equalizer
  private var _eq                           : Equalizer!                    // Current Equalizer
  
  // ----------------------------------------------------------------------------
  // MARK: - Overriden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    view.translatesAutoresizingMaskIntoConstraints = false
    
    // get a reference to each equalizer
    _equalizerRx = _radio!.equalizers[.rxsc]!
    _equalizerTx = _radio!.equalizers[.txsc]!

    // save a reference to the selected Equalizer
    _eq = (Defaults[.eqRxSelected] ? _equalizerRx : _equalizerTx)

    // begin observing parameters
    addObservations()
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Respond to the buttons
  ///
  /// - Parameter sender:           the button
  ///
  @IBAction func buttons(_ sender: NSButton) {
    
    switch sender.identifier!.rawValue {
      
    case "EqOn":
      // set the displayed Equalizer On / Off
      _eq!.eqEnabled = onButton.boolState

    case "EqRx":
      // select the Rx equalizer
      _eq = _equalizerRx
      Defaults[.eqRxSelected] = sender.boolState

    case "EqTx":
      // select the Tx equalizer
      _eq = _equalizerTx
      Defaults[.eqRxSelected] = !sender.boolState
      
    default:
      fatalError()
    }    
    // populate the controls of the selected Equalizer
    eqChange( _eq, 0)
  }
  /// Respond to changes in a slider value
  ///
  /// - Parameter sender:           the slider
  ///
  @IBAction func sliders(_ sender: NSSlider) {
    
    // tell the Radio to change the Eq setting
    switch sender.identifier!.rawValue {
    case "Level63Hz":
      _eq.level63Hz = sender.integerValue
    case "Level125Hz":
      _eq.level125Hz = sender.integerValue
    case "Level250Hz":
      _eq.level250Hz = sender.integerValue
    case "Level500Hz":
      _eq.level500Hz = sender.integerValue
    case "Level1000Hz":
      _eq.level1000Hz = sender.integerValue
    case "Level2000Hz":
      _eq.level2000Hz = sender.integerValue
    case "Level4000Hz":
      _eq.level4000Hz = sender.integerValue
    case "Level8000Hz":
      _eq.level8000Hz = sender.integerValue
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
    
    if let rx = _equalizerRx {
      
      // Rx Equalizer parameters
      _observations.append( rx.observe(\.level63Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( rx.observe(\.level125Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( rx.observe(\.level250Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( rx.observe(\.level500Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( rx.observe(\.level1000Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( rx.observe(\.level2000Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( rx.observe(\.level4000Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( rx.observe(\.level8000Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( rx.observe(\.eqEnabled, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
    }
    
    if let tx = _equalizerTx {

      // Tx Equalizer parameters
      _observations.append( tx.observe(\.level63Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( tx.observe(\.level125Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( tx.observe(\.level250Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( tx.observe(\.level500Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( tx.observe(\.level1000Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( tx.observe(\.level2000Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( tx.observe(\.level4000Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( tx.observe(\.level8000Hz, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
      _observations.append( tx.observe(\.eqEnabled, options: [.initial, .new]) { [weak self] (eq, change) in
        self?.eqChange(eq, change) })
    }
  }
  /// Respond to changes in parameters
  ///
  /// - Parameters:
  ///   - object:                       an Equalizer
  ///   - change:                       the change
  ///
  private func eqChange(_ eq: Equalizer, _ change: Any) {
    
    // update the Equalizer if currently displayed
    if eq == _eq {
      
      DispatchQueue.main.async { [weak self] in
        
        // enable the appropriate Equalizer
        self?.rxButton.boolState = Defaults[.eqRxSelected]
        self?.txButton.boolState = !Defaults[.eqRxSelected]
        
        // set the ON button state
        self?.onButton.boolState = eq.eqEnabled
        
        // set the slider values
        self?.slider0.integerValue = eq.level63Hz
        self?.slider1.integerValue = eq.level125Hz
        self?.slider2.integerValue = eq.level250Hz
        self?.slider3.integerValue = eq.level500Hz
        self?.slider4.integerValue = eq.level1000Hz
        self?.slider5.integerValue = eq.level2000Hz
        self?.slider6.integerValue = eq.level4000Hz
        self?.slider7.integerValue = eq.level8000Hz
      }
    }
  }
}
