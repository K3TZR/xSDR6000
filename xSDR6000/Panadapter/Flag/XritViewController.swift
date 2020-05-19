//
//  XritViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 1/7/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

final class XritViewController: NSViewController {

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _ritButton     : NSButton!
  @IBOutlet private weak var _ritZeroButton : NSButton!
  @IBOutlet private weak var _ritTextField  : NSTextField!
  @IBOutlet private weak var _ritStepper    : NSStepper!
  
  @IBOutlet private weak var _xitButton     : NSButton!
  @IBOutlet private weak var _xitZeroButton : NSButton!
  @IBOutlet private weak var _xitTextField  : NSTextField!
  @IBOutlet private weak var _xitStepper    : NSStepper!
  
  @IBOutlet private weak var _stepTextField : NSTextField!
  @IBOutlet private weak var _stepStepper   : NSStepper!
 
  @IBOutlet private weak var _stepLabel     : NSTextField!
  
  private var _slice                        : xLib6000.Slice {
    return representedObject as! xLib6000.Slice }
  
  private var _splitStepMode                = false
  private var _monitor                      : Any?
  
  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    view.translatesAutoresizingMaskIntoConstraints = false
    
    if Defaults.flagBorderEnabled {
      view.layer?.borderColor = NSColor.darkGray.cgColor
      view.layer?.borderWidth = 0.5
    }
    _monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [unowned self] in
      
      if $0.modifierFlags.contains(NSEvent.ModifierFlags.option) {
        self._splitStepMode.toggle()

        DispatchQueue.main.async { [unowned self] in
          if self._splitStepMode {
            self._stepLabel.stringValue = "Split step"
            self._stepTextField.integerValue = Defaults.splitDistance
            self._stepStepper.integerValue = Defaults.splitDistance
          
          } else {
            self._stepLabel.stringValue = "Tuning step"
            self._stepTextField.integerValue = self._slice.step
            self._stepStepper.integerValue = self._slice.step
          }
        }
      }
      return $0
    }
    
    // start observing
    addObservations()
  }
  override func viewWillAppear() {
    super.viewWillAppear()
    
    // set the background color of the Flag
    view.layer?.backgroundColor = ControlsViewController.kBackgroundColor
  }
  
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Respond to one of the buttons
  ///
  /// - Parameter sender:         the button
  ///
  @IBAction func buttons(_ sender: NSButton) {
    
    switch sender.identifier!.rawValue {
    case "ritButton":
      _slice.ritEnabled = sender.boolState
    case "xitButton":
      _slice.xitEnabled = sender.boolState
    case "ritZeroButton":
      _slice.ritOffset = 0
    case "xitZeroButton":
      _slice.xitOffset = 0
    default:
      fatalError()
    }
  }
  /// Respond to one of the Steppers
  ///
  /// - Parameter sender:         the stepper
  ///
  @IBAction func steppers(_ sender: NSStepper) {
    
    switch sender.identifier!.rawValue {
    case "ritStepper":
      _slice.ritOffset = sender.integerValue
    case "xitStepper":
      _slice.xitOffset = sender.integerValue
    case "stepStepper":
      if _splitStepMode {
        Defaults.splitDistance = sender.integerValue
      } else {
        _slice.step = sender.integerValue
      }
    default:
      fatalError()
    }
  }
  /// Respond to one of the TextFields
  ///
  /// - Parameter sender:         the textfield
  ///
  @IBAction func textFields(_ sender: NSTextField) {
    
    switch sender.identifier!.rawValue {
    case "ritOffset":
      _slice.ritOffset = sender.integerValue
    case "xitOffset":
      _slice.ritOffset = sender.integerValue
    case "step":
      if _splitStepMode {
        Defaults.splitDistance = sender.integerValue
      } else {
        _slice.step = sender.integerValue
      }
    default:
      fatalError()
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  private var _observations         = [NSKeyValueObservation]()
  private var _defaultsObservations = [DefaultsDisposable]()

  /// Add observations of various properties used by the view
  ///
  private func addObservations() {
    
    _observations = [
      _slice.observe(\.ritEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
        self?.changeHandler(slice, change) },
      _slice.observe(\.xitEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
        self?.changeHandler(slice, change) },
      _slice.observe(\.ritOffset, options: [.initial, .new]) { [weak self] (slice, change) in
        self?.changeHandler(slice, change) },
      _slice.observe(\.xitOffset, options: [.initial, .new]) { [weak self] (slice, change) in
        self?.changeHandler(slice, change)},
      _slice.observe(\Slice.step, options: [.initial, .new]) { [weak self] (slice, change) in
        self?.stepHandler(slice, change) },
    ]

    _defaultsObservations = [
      Defaults.observe(\.splitDistance, options: [.initial, .new]) { [weak self] update in
        self?.splitHandler(update.newValue!) }
    ]
  }
  /// Process observations
  ///
  /// - Parameters:
  ///   - slice:                    the slice being observed
  ///   - change:                   the change
  ///
  private func changeHandler(_ slice: xLib6000.Slice, _ change: Any) {

    DispatchQueue.main.async { [weak self] in
      self?._ritButton.boolState = slice.ritEnabled
      self?._xitButton.boolState = slice.xitEnabled

      self?._ritTextField.integerValue = slice.ritOffset
      self?._ritStepper.integerValue = slice.ritOffset

      self?._xitTextField.integerValue = slice.xitOffset
      self?._xitStepper.integerValue = slice.xitOffset
    }
  }
  /// Process observations
  ///
  /// - Parameters:
  ///   - defaults:                 the Defaults being observed
  ///   - change:                   the change
  ///
  private func splitHandler(_ value: Int) {

    DispatchQueue.main.async { [weak self] in

      self?._stepTextField.integerValue = value
      self?._stepStepper.integerValue = value
    }
  }
  /// Process observations
  ///
  /// - Parameters:
  ///   - defaults:                 the Defaults being observed
  ///   - change:                   the change
  ///
  private func stepHandler(_ object: AnyObject, _ change: Any) {
    if let slice = object as? xLib6000.Slice {
      DispatchQueue.main.async { [weak self] in
        
        self?._stepTextField.integerValue = slice.step
        self?._stepStepper.integerValue = slice.step
      }
    }
  }
}
