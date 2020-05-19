//
//  DaxIqViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 1/7/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class DaxIqViewController             : NSViewController, NSPopoverDelegate {

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _daxIqPopUp    : NSPopUpButton!
  
  private var _panadapter                   : Panadapter {
    return representedObject as! Panadapter }

  private var _isDetached                   = false

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    _daxIqPopUp.addItems(withTitles: _panadapter.daxIqChoices)
    
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
  
  /// Respond to the rxAnt popup
  ///
  /// - Parameter sender:         the popup
  ///
  @IBAction func daxIqPopUp(_ sender: NSPopUpButton) {
    
    _panadapter.daxIqChannel = sender.indexOfSelectedItem
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  private var _observations                 = [NSKeyValueObservation]()

  /// Add observations of various properties used by the view
  ///
  private func addObservations() {
    
    _observations = [
      _panadapter.observe(\.daxIqChannel, options: [.initial, .new]) { [weak self] (object, change) in
        self?.changeHandler(object, change) }
    ]
  }
  /// Process observations
  ///
  /// - Parameters:
  ///   - slice:                    the panadapter being observed
  ///   - change:                   the change
  ///
  private func changeHandler(_ panadapter: Panadapter, _ change: Any) {
    
    DispatchQueue.main.async { [weak self] in
      self?._daxIqPopUp.selectItem(at: panadapter.daxIqChannel)
    }
  }
}

