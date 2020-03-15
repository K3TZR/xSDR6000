//
//  TxViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 8/31/18.
//  Copyright © 2018 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class TxViewController                      : NSViewController {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _tuneButton        : NSButton!
  @IBOutlet private weak var _moxButton         : NSButton!
  @IBOutlet private weak var _atuButton         : NSButton!
  @IBOutlet private weak var _memButton         : NSButton!
  @IBOutlet private weak var _txProfile         : NSPopUpButton!
  @IBOutlet private weak var _atuStatus         : NSTextField!
  @IBOutlet private weak var _tunePowerSlider   : NSSlider!
  @IBOutlet private weak var _tunePowerLevel    : NSTextField!
  @IBOutlet private weak var _rfPowerSlider     : NSSlider!
  @IBOutlet private weak var _rfPowerLevel      : NSTextField!
  @IBOutlet private weak var _rfPowerIndicator  : LevelIndicator!
  @IBOutlet private weak var _swrIndicator      : LevelIndicator!
  
  private var _radio                        : Radio? { Api.sharedInstance.radio }
  private var _observations                 = [NSKeyValueObservation]()
  private var _profileObservations          = [NSKeyValueObservation]()
  private var _meterObservations            = [NSKeyValueObservation]()

  private let kPowerForward                 = Meter.ShortName.powerForward.rawValue
  private let kSwr                          = Meter.ShortName.swr.rawValue


  // ----------------------------------------------------------------------------
  // MARK: - Overriden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    view.translatesAutoresizingMaskIntoConstraints = false    
    
    // setup the RfPower & Swr graphs
    setupBarGraphs()
    
    // start observing properties
    addObservations()
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  @IBAction func profile(_ sender: NSPopUpButton) {

    _radio!.profiles[Profile.Group.tx.rawValue]!.selection = sender.titleOfSelectedItem!
  }
  
  @IBAction func buttons(_ sender: NSButton) {

    switch sender.identifier!.rawValue {
      case "Tune":
        _radio!.transmit.tune = sender.boolState
      case "Mox":
        _radio!.mox = sender.boolState
      case "Atu":
        // initiate a tuning cycle
        _radio!.atu.atuStart()
      case "Mem":
        _radio!.atu.memoriesEnabled = sender.boolState
      case "Save":
        showDialog(sender)
      default:
        fatalError()
    }
  }
  @IBAction func sliders(_ sender: NSSlider) {

    if sender.integerValue <= _radio!.transmit.maxPowerLevel && _radio!.transmit.txRfPowerChanges {
      
      switch sender.identifier!.rawValue {
      case "TunePower":
        _radio!.transmit.tunePower = sender.integerValue
      case "RfPower":
        _radio!.transmit.rfPower = sender.integerValue
      default:
        fatalError()
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Setup graph styles, legends and resting levels
  ///
  private func setupBarGraphs() {
    
    _rfPowerIndicator.legends = [            // to skip a legend pass "" as the format
      (0, "0", 0),
      (4, "40", 0.5),
      (8, "80", 0.5),
      (10, "100", 0.5),
      (12, "120", 1),
      (nil, "RF Pwr", 0)
    ]
    _swrIndicator.legends = [
      (0, "1", 0),
      (2, "1.5", 0.5),
      (6, "2.5", 0.5),
      (8, "3", 1),
      (nil, "SWR", 0)
    ]
    // move the bar graphs off scale
    _rfPowerIndicator.level = -10
    _rfPowerIndicator.peak = -10
    _swrIndicator.level = -10
    _swrIndicator.peak = -10
  }
  /// Show a Save / Delete profile dialog
  ///
  /// - Parameter sender:             a button
  ///
  private func showDialog(_ sender: NSButton) {
    let alert = NSAlert()
    let acc = NSTextField(frame: NSMakeRect(0, 0, 233, 25))
    acc.stringValue = _radio!.profiles[Profile.Group.mic.rawValue]!.selection
    acc.isEditable = true
    acc.drawsBackground = true
    alert.accessoryView = acc
    alert.addButton(withTitle: "Cancel")
    
    // ask the user to confirm
    if sender.title == "Save" {
      // Save a Profile
      alert.messageText = "Save Tx Profile as:"
      alert.addButton(withTitle: "Save")
      
      alert.beginSheetModal(for: NSApp.mainWindow!, completionHandler: { (response) in
        if response == NSApplication.ModalResponse.alertFirstButtonReturn { return }
        
        // save profile
//        Profile.save(Profile.Group.tx.rawValue + "_list", name: acc.stringValue)
      } )
      
    } else {
      // Delete a profile
      alert.messageText = "Delete Tx Profile:"
      alert.addButton(withTitle: "Delete")
      
      alert.beginSheetModal(for: NSApp.mainWindow!, completionHandler: { (response) in
        if response == NSApplication.ModalResponse.alertFirstButtonReturn { return }
        
        // delete profile
//        Profile.delete(Profile.Group.tx.rawValue + "_list", name: acc.stringValue)
        self._txProfile.selectItem(at: 0)
      } )
    }
  }
  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  /// Add observations
  ///
  private func addObservations() {
    
    _observations = [
      // Atu parameters
      _radio!.atu.observe(\.status, options: [.initial, .new]) { [weak self] (atu, change) in
        self?.atuChange(atu, change) },
      _radio!.atu.observe(\.enabled, options: [.initial, .new]) { [weak self] (atu, change) in
        self?.atuChange(atu, change) },
      _radio!.atu.observe(\.memoriesEnabled, options: [.initial, .new]) { [weak self] (atu, change) in
        self?.atuChange(atu, change) },
      
      // Radio parameters
      _radio!.observe(\.mox, options: [.initial, .new]) { [weak self] (radio, change) in
        self?.radioChange(radio, change) },
      
      // Transmit parameters
      _radio!.transmit.observe(\.tune, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      _radio!.transmit.observe(\.tunePower, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      _radio!.transmit.observe(\.rfPower, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },

      // Tx Profile parameters
      _radio!.profiles[Profile.Group.tx.rawValue]!.observe(\.list, options: [.initial, .new]) { [weak self] (profile, change) in
        self?.profileChange(profile, change) },
      _radio!.profiles[Profile.Group.tx.rawValue]!.observe(\.selection, options: [.initial, .new]) { [weak self] (profile, change) in
        self?.profileChange(profile, change) }
    ]

    // Tx Meter parameters
    _radio!.meters.values.filter { $0.name == kPowerForward || $0.name == kSwr}
      .forEach({
        _meterObservations.append( $0.observe(\.value, options: [.initial, .new]) { [weak self] (meter, change) in
          self?.meterChange(meter, change) })
      })
  }
  /// Update all Atu control values
  ///
  /// - Parameter atu:               Atu object
  ///
  private func atuChange(_ atu: Atu, _ change: Any) {
    
    DispatchQueue.main.async { [weak self] in
      self?._atuButton.boolState = atu.enabled
      self?._memButton.boolState = atu.memoriesEnabled
      self?._atuStatus.stringValue = atu.status
    }
  }
  /// Update all Profile control values
  ///
  /// - Parameter profile:               Profile object
  ///
  private func profileChange(_ profile: Profile, _ change: Any) {
    
    DispatchQueue.main.async { [weak self] in
      self?._txProfile.removeAllItems()
      self?._txProfile.addItems(withTitles: profile.list)
      self?._txProfile.selectItem(withTitle: profile.selection)
    }
  }
  /// Update all control values
  ///
  /// - Parameter radio:               Radio object
  ///
  private func radioChange(_ radio: Radio, _ change: Any) {
    
    DispatchQueue.main.async { [weak self] in
      self?._moxButton.boolState = radio.mox
    }
  }
  /// Update all Transmit control values
  ///
  /// - Parameter transmit:               Transmit
  ///
  private func transmitChange(_ transmit: Transmit, _ change: Any) {
    
    DispatchQueue.main.async { [weak self] in
      self?._tuneButton.boolState = transmit.tune
      self?._tunePowerSlider.integerValue = transmit.tunePower
      self?._tunePowerLevel.integerValue = transmit.tunePower
      self?._rfPowerSlider.integerValue = transmit.rfPower
      self?._rfPowerLevel.integerValue = transmit.rfPower
    }
  }
  /// Update a Meter
  ///
  /// - Parameters:
  ///   - object:                       a Meter
  ///   - change:                       the change
  ///
  private func meterChange(_ meter: Meter, _ change: Any) {
    
    switch meter.name {
    case kPowerForward:                     // kPowerForward is in Dbm
      DispatchQueue.main.async { [weak self] in self?._rfPowerIndicator.level = CGFloat(meter.value.powerFromDbm) }
    
    case kSwr:                              // kSwr is actual SWR value
      DispatchQueue.main.async { [weak self] in self?._swrIndicator.level = CGFloat(meter.value)  }
    
    default:
      fatalError()
    }
  }
}

