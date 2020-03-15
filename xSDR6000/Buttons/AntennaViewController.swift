//
//  AntennaViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 1/7/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class AntennaViewController           : NSViewController, NSPopoverDelegate {

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _rxAntPopUp    : NSPopUpButton!
  @IBOutlet private weak var _loopAButton   : NSButton!
  @IBOutlet private weak var _rfGainSlider  : NSSlider!

  private var _panadapter                   : Panadapter { representedObject as! Panadapter }
  
  private var _observations                 = [NSKeyValueObservation]()
  private var _isDetached                   = false

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    _rxAntPopUp.addItems(withTitles: _panadapter.antList)
    
    // start observing
    addObservations()

    // start the timer
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(PanafallButtonViewController.kTimeout)) {
      if !self._isDetached { self.dismiss(nil) }
    }
  }
  
  func popoverShouldDetach(_ popover: NSPopover) -> Bool {
    _isDetached = true
    return true
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Respond to the LoopA button
  ///
  /// - Parameter sender:         the button
  ///
  @IBAction func loopAButton(_ sender: NSButton) {
    
    _panadapter.loopAEnabled = sender.boolState
  }
  /// Respond to the rxAnt popup
  ///
  /// - Parameter sender:         the popup
  ///
  @IBAction func rxAntPopUp(_ sender: NSPopUpButton) {
  
      _panadapter.rxAnt = sender.titleOfSelectedItem!
  }
  /// Respond to the rfGain slider
  ///
  /// - Parameter sender:         the slider
  ///
  @IBAction func rfGainSlider(_ sender: NSSlider) {
    
    _panadapter.rfGain = sender.integerValue
  }

  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  /// Add observations of various properties used by the view
  ///
  private func addObservations() {
    
    _observations = [
      _panadapter.observe(\.rxAnt, options: [.initial, .new]) { [weak self] (object, change) in
        self?.changeHandler(object, change) },
      
      _panadapter.observe(\.loopAEnabled, options: [.initial, .new]) { [weak self] (object, change) in
        self?.changeHandler(object, change) },
      
      _panadapter.observe(\.rfGain, options: [.initial, .new]) { [weak self] (object, change) in
        self?.changeHandler(object, change) }
    ]
  }
  /// Process observations
  ///
  /// - Parameters:
  ///   - slice:                    the slice being observed
  ///   - change:                   the change
  ///
  private func changeHandler(_ panadapter: Panadapter, _ change: Any) {
    
    DispatchQueue.main.async { [weak self] in
      self?._rxAntPopUp.selectItem(withTitle: panadapter.rxAnt)
      self?._loopAButton.boolState = panadapter.loopAEnabled
      self?._rfGainSlider.integerValue = panadapter.rfGain
    }
  }
}
