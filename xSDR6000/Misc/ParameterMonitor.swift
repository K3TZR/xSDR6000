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
  // MARK: - Private properties
  
  @IBOutlet private var _topField: NSTextField!
  @IBOutlet private var _bottomField: NSTextField!

  private var _fields: [NSTextField]!

  private let _shortNames = [Meter.ShortName.voltageAfterFuse.rawValue, Meter.ShortName.temperaturePa.rawValue]
  private let _units = ["v", "c"]
  private let _formatString = "%0.2f"

  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  override func awakeFromNib() {
    super.awakeFromNib()
    
    _fields = [_topField, _bottomField]
    addNotifications()
  }

  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subscriptions to Notifications
  ///
  private func addNotifications() {
    NCtr.makeObserver(self, with: #selector(radioWillBeRemoved(_:)), of: .radioWillBeRemoved)
    NCtr.makeObserver(self, with: #selector(paramMeterUpdated(_:)), of: .paramMeterUpdated)
  }
  /// Process .radioWillBeRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func radioWillBeRemoved(_ note: Notification) {
    
    DispatchQueue.main.async { [weak self] in
      
      // set the background color
      self?._topField.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.5)
      self?._bottomField.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.5)
      
      // set the field value
      self?._topField.stringValue = "----"
      self?._bottomField.stringValue = "----"
    }
  }
  /// Respond to a change in a Meter
  ///
  /// - Parameters:
  ///   - note:                 a Notification
  ///
  @objc private func paramMeterUpdated(_ note: Notification) {
    
    func updateField(_ field: NSTextField, for meter: Meter, units: String) {
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
        field.stringValue = String(format: self._formatString + " \(units)", meter.value)
      }
    }

    if let meter = note.object as? Meter {
      // update the appropriate field
      switch meter.name {
      case _shortNames[0]:
        updateField(_fields[0], for: meter, units: _units[0])
        
      case _shortNames[1]:
        updateField(_fields[1], for: meter, units: _units[1])
        
      default:
        break
      }
    }
  }
}
