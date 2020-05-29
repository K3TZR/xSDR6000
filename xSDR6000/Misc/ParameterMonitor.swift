//
//  ParameterMonitor.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/12/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - Parameter Monitor class implementation
// --------------------------------------------------------------------------------

class ParameterMonitor: NSToolbarItem {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var formatString                   = "%0.2f"
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private var topField    : NSTextField!
  @IBOutlet private var bottomField : NSTextField!

  private let _shortNames           = [Meter.ShortName.voltageAfterFuse.rawValue, Meter.ShortName.temperaturePa.rawValue]
  private let _units                = ["v", "c"]
  
  private var _observations         : [NSKeyValueObservation?] = [nil, nil]
  
  private let kTopValue             = 0
  private let kBottomValue          = 1

  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  override func awakeFromNib() {
    super.awakeFromNib()
    
    addNotifications()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods

  /// Deactivate this Parameter Monitor
  ///
  private func deactivate() {
    
    removeObservations()
    
    DispatchQueue.main.async { [weak self] in
      
      // set the background color
      self?.topField.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.5)
      self?.bottomField.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.5)
      
      // set the field value
      self?.topField.stringValue = "----"
      self?.bottomField.stringValue = "----"
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Observation Methods
  
  /// Remove observations
  ///
  private func removeObservations() {
    
    // invalidate each observation
    if _observations[kTopValue] != nil { _observations[kTopValue]!.invalidate() }
    if _observations[kBottomValue] != nil { _observations[kBottomValue]!.invalidate() }

    // remove the tokens
    _observations[kTopValue] = nil
    _observations[kBottomValue] = nil
  }
  /// Update the value of the ParameterMonitor
  ///
  /// - Parameters:
  ///   - object:             an observed object
  ///   - change:             a change dictionary
  ///
  private func updateValue(_ object: Any, _ change: Any) {
    let kTop = 0
    let kBottom = 1
    
    let meter = object as! Meter

    // which Meter?
    switch meter.name {
    case _shortNames[kTopValue]:
      updateField(topField, for: meter, units: _units[kTop])

    case _shortNames[kBottom]:
      updateField(bottomField, for: meter, units: _units[kBottom])

    default:
      // should never happen
      break
    }
  }
  /// Update a field
  ///
  /// - Parameters:
  ///   - field:              the textfield
  ///   - meter:              a reference to a Meter
  ///   - units:              the units
  ///
  private func updateField(_ field: NSTextField, for meter: Meter, units: String) {
    
    DispatchQueue.main.async { [unowned self] in

      // determine the background color
      switch meter.value {
      case ...meter.low:                                    // < low
        field.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.5)
      case meter.high...:                                   // > high
        field.backgroundColor = NSColor.systemRed.withAlphaComponent(0.5)
      case meter.low...meter.high:                          // between low & high
        field.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.5)
      default:                                              // should never happen
        field.backgroundColor = NSColor.controlBackgroundColor
      }
      // set the field value
      field.stringValue = String(format: self.formatString + " \(units)" , meter.value)
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subscriptions to Notifications
  ///
  private func addNotifications() {
    NC.makeObserver(self, with: #selector(radioHasBeenAdded(_:)), of: .radioHasBeenAdded)
    NC.makeObserver(self, with: #selector(radioWillBeRemoved(_:)), of: .radioWillBeRemoved)
  }
  /// Process .radioHasBeenAdded Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func radioHasBeenAdded(_ note: Notification) {
    NC.makeObserver(self, with: #selector(meterHasBeenAdded(_:)), of: .meterHasBeenAdded)
  }
  /// Process .meterHasBeenAdded Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func meterHasBeenAdded(_ note: Notification) {
    if let meter = note.object as? Meter {
      
      if meter.name == _shortNames[kTopValue] && _observations[kTopValue] == nil {
        // YES, observe it's value
        _observations[kTopValue] = meter.observe(\.value, options: [.initial, .new],changeHandler: updateValue)
      }
      if meter.name == _shortNames[kBottomValue] && _observations[kBottomValue] == nil {
        // YES, observe it's value
        _observations[kBottomValue] = meter.observe(\.value, options: [.initial, .new],changeHandler: updateValue)
      }
    }
    if _observations[kTopValue] != nil && _observations[kBottomValue] != nil {
      NC.deleteObserver(self, of: .meterHasBeenAdded, object: nil)
    }
  }
  /// Process .radioWillBeRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func radioWillBeRemoved(_ note: Notification) {
    removeObservations()
    
    DispatchQueue.main.async { [weak self] in
      
      // set the background color
      self?.topField.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.5)
      self?.bottomField.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.5)
      
      // set the field value
      self?.topField.stringValue = "----"
      self?.bottomField.stringValue = "----"
    }
  }
}
