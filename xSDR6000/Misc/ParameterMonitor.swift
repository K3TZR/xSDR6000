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
  
  @IBOutlet private var topField            : NSTextField!
  @IBOutlet private var bottomField         : NSTextField!

  private weak var _radio                   : Radio?
  private var _id                           : NSToolbarItem.Identifier
  
  private var _q                            = DispatchQueue(label: "objectQ", attributes: [.concurrent])

  var _shortNames : [Meter.ShortName] {
    get { _q.sync { __shortNames } }
    set { _q.sync(flags: .barrier) {__shortNames = newValue }}}
  var _units : [String] {
    get { _q.sync { __units } }
    set { _q.sync(flags: .barrier) {__units = newValue }}}
  private var _observations                 = [NSKeyValueObservation]()
  
  private let kTopValue                     = 0
  private let kBottomValue                  = 1

  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  override init(itemIdentifier: NSToolbarItem.Identifier) {
    _id = itemIdentifier
    
    super.init(itemIdentifier: itemIdentifier)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  /// Activate this Parameter Monitor
  ///
  /// - Parameters:
  ///   - radio:              a reference to the Radio class
  ///   - meterShortNames:    an array of  Meter ShortNames
  ///   - units:              an array of units
  ///
  func activate(radio: Radio, shortNames: [Meter.ShortName], units: [String]) {
    
    _radio = radio
    _shortNames = shortNames
    _units = units
    
    // for the first two short names (others are ignored)
    for shortName in _shortNames {
      
      // is there a Meter by that name?
      if let meter = _radio?.findMeter(shortName: shortName.rawValue) {
        
        // YES, observe it's value
        _observations.append( meter.observe(\.value, options: [.initial, .new],changeHandler: updateValue))
      }
    }
  }
  /// Deactivate this Parameter Monitor
  ///
  func deactivate() {
    
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
  // MARK: - Private methods
  
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
    case _shortNames[kTop].rawValue:
      updateField(topField, for: meter, units: _units[kTop])

    case _shortNames[kBottom].rawValue:
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
  /// Remove observations
  ///
  func removeObservations() {
    
    // invalidate each observation
    _observations.forEach { $0.invalidate() }
    
    // remove the tokens
    _observations.removeAll()
  }
  
  // ----------------------------------------------------------------------------
  // *** Hidden properties (Do NOT use) ***
  
  private var __shortNames  = [Meter.ShortName]()
  private var __units       = [String]()
}
