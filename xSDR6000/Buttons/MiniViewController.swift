//
//  MiniViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 7/15/20.
//  Copyright © 2020 Douglas Adams. All rights reserved.
//
import Cocoa
import xLib6000

final class MiniViewController             : NSViewController, NSPopoverDelegate {

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _miniContainer : NSView!
  @IBOutlet weak var _miniContainerHeight   : NSLayoutConstraint!
  
  private var _inUse                        = true
  private var _isDetached                   = false
  private var _p                            : Params!
  private var _timer                        : DispatchSourceTimer!
  
  private var _flagVc                       : FlagViewController!

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    addObservations()
    startTimer()
    
    if let slice = _p.radio.slices.first?.value {
      
      // create a Flag with this popover as its parent
      _flagVc = FlagViewController.createFlag(for: slice, and: _p.panadapter, on: self)

      // add the Flag to the view hierarchy
      FlagViewController.addFlag(_flagVc!,
                                 to: _miniContainer,
                                 flagPosition: 0,
                                 flagHeight: FlagViewController.kLargeFlagHeight,
                                 flagWidth: FlagViewController.kLargeFlagWidth + 36)
      
      // if selected, make it visible (i.e. height > 0)
      _miniContainerHeight.constant = 90
    }

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
  
  
  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  private var _observations                 = [NSKeyValueObservation]()

  private func addObservations() {
//    _observations = [
//      _p.panadapter.observe(\.daxIqChannel, options: [.initial, .new]) { [weak self] (panadapter, change) in
//        DispatchQueue.main.async { [weak self] in
//          self?._daxIqPopUp.selectItem(at: panadapter.daxIqChannel)
//        }}
//    ]
  }

  //  private func changeHandler(_ panadapter: Panadapter, _ change: Any) {
//
//    DispatchQueue.main.async { [weak self] in
//      self?._daxIqPopUp.selectItem(at: panadapter.daxIqChannel)
//    }
//  }
}
