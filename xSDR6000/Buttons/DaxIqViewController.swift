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
  
  private var _inUse                        = false
  private var _isDetached                   = false
  private var _p                            : Params!
  private var _timer                        : DispatchSourceTimer!

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    _daxIqPopUp.addItems(withTitles: _p.panadapter.daxIqChoices)
    
    addObservations()
    startTimer()
  }

  func popoverShouldDetach(_ popover: NSPopover) -> Bool {
    _isDetached = true
    return true
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  func configure(params: Params) {
    _p = params
  }
  
  func startTimer() {
    // create and schedule a timer
    _timer = DispatchSource.makeTimerSource(flags: [])
    _timer.schedule(deadline: DispatchTime.now() + 5, repeating: .seconds(3), leeway: .seconds(1))
    _timer.setEventHandler { [ unowned self] in
      // dismiss if not detached or not in use
      if !self._isDetached {
        if self._inUse {
          self._inUse = false
        } else {
          DispatchQueue.main.async { self.dismiss(nil) }
        }
      }
    }
    // start the timer
    _timer.resume()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  @IBAction func daxIqPopUp(_ sender: NSPopUpButton) {
    _p.panadapter.daxIqChannel = sender.indexOfSelectedItem
    _inUse = true
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  private var _observations                 = [NSKeyValueObservation]()

  private func addObservations() {
    _observations = [
      _p.panadapter.observe(\.daxIqChannel, options: [.initial, .new]) { [weak self] (panadapter, change) in
        DispatchQueue.main.async { [weak self] in
          self?._daxIqPopUp.selectItem(at: panadapter.daxIqChannel)
        }}
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

