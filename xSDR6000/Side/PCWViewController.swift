//
//  PCWViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/15/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class PCWViewController                     : NSViewController {

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _compressionIndicator    : LevelIndicator!
  @IBOutlet private weak var _micLevelIndicator       : LevelIndicator!
  @IBOutlet private weak var _micProfilePopUp         : NSPopUpButton!
  @IBOutlet private weak var _micSelectionPopUp       : NSPopUpButton!
  @IBOutlet private weak var _micLevelSlider          : NSSlider!
  @IBOutlet private weak var _accButton               : NSButton!
  @IBOutlet private weak var _procButton              : NSButton!
  @IBOutlet private weak var _processorLevelSlider    : NSSlider!
  @IBOutlet private weak var _daxButton               : NSButton!
  @IBOutlet private weak var _monButton               : NSButton!
  @IBOutlet private weak var _monLevel                : NSSlider!
  @IBOutlet private weak var _saveButton              : NSButton!
  
  private var _radio                        : Radio? { Api.sharedInstance.radio }
  
//  private let kMicrophoneAverage            = Meter.ShortName.microphoneAverage.rawValue
//  private let kMicrophonePeak               = Meter.ShortName.microphonePeak.rawValue
//  private let kCompression                  = Meter.ShortName.postClipper.rawValue

  // ----------------------------------------------------------------------------
  // MARK: - Overriden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.translatesAutoresizingMaskIntoConstraints = false
    
    // setup the MicLevel & Compression graphs
    setupBarGraphs()
    
    // start observations
    addNotifications()
    addObservations()
  }

  // ----------------------------------------------------------------------------
  // MARK: - Action methods

  /// Respond to one of the popups
  ///
  /// - Parameter sender:             the popup
  ///
  @IBAction func popups(_ sender: NSPopUpButton)  {
    
    switch sender.identifier!.rawValue {
    case "MicProfile":    _radio!.profiles[Profile.Group.mic.rawValue]?.selection = sender.selectedItem!.title
    case "MicSelection":  _radio!.transmit?.micSelection = sender.selectedItem!.title
    default:              break
    }
  }
  /// Respond to one of the buttons
  ///
  /// - Parameter sender:             the button
  ///
  @IBAction func buttons(_ sender: NSButton) {
    
    switch sender.identifier!.rawValue {
    case "Acc":     _radio!.transmit!.micAccEnabled = sender.boolState
    case "DaxMic":  _radio!.transmit!.daxEnabled = sender.boolState
    case "Mon":     _radio!.transmit!.txMonitorEnabled = sender.boolState
    case "Proc":    _radio!.transmit!.speechProcessorEnabled = sender.boolState
    case "Save":    showDialog(sender)
    default:        break
    }
  }
  /// Respond to one of the sliders
  ///
  /// - Parameter sender:             the slider
  ///
  @IBAction func sliders(_ sender: NSSlider) {
  
    switch sender.identifier!.rawValue {
    case "MicLevel":              _radio!.transmit!.micLevel = sender.integerValue
    case "SpeechProcessorLevel":  _radio!.transmit!.speechProcessorLevel = sender.integerValue
    case "TxMonitorGainSb":       _radio!.transmit!.txMonitorGainSb = sender.integerValue
    default:                      break
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Setup graph styles, legends and resting levels
  ///
  private func setupBarGraphs() {
    
    _micLevelIndicator.legends = [
      (0, "-40dB", 0),
      (2, "-30", 0.5),
      (6, "-10", 0.5),
      (8, "0", 0.5),
      (nil, "Level", 0.0)
    ]
    _compressionIndicator.legends = [
      (0, "-25dB", 0),
      (5, "0", 1),
      (nil, "Compression", 0)
    ]
    // move the bar graphs off scale
    _micLevelIndicator.level = -40
    _micLevelIndicator.peak = -40
    _compressionIndicator.level = 0
    _compressionIndicator.peak = 0
  }
  /// Show a Save / Delete dialog as a sheet
  ///
  /// - Parameter sender:             a button
  ///
  private func showDialog(_ sender: NSButton) {
    let alert = NSAlert()
    let acc = NSTextField(frame: NSMakeRect(0, 0, 233, 25))
    acc.stringValue = "NewProfile"
    acc.isEditable = true
    acc.formatter = ProfileFormatter()
    
    acc.drawsBackground = true
    alert.accessoryView = acc
    alert.addButton(withTitle: "Cancel")
    
    // ask the user to confirm
    if sender.title == "Save" {
      // Save a Profile
      alert.messageText = "Save Mic Profile \(_radio!.profiles[Profile.Group.mic.rawValue]!.selection) as:"
      alert.addButton(withTitle: "Save")
      
      alert.beginSheetModal(for: NSApp.mainWindow!, completionHandler: { (response) in
        if response == NSApplication.ModalResponse.alertFirstButtonReturn { return }
        if acc.stringValue != "" {
          // save profile
//          Profile.save(Profile.Group.mic.rawValue + "_list", name: acc.stringValue)
        }
      } )
    
    } else {
      // Delete a profile
      alert.messageText = "Delete Mic Profile:"
      alert.addButton(withTitle: "Delete")
      
      alert.beginSheetModal(for: NSApp.mainWindow!, completionHandler: { (response) in
        if response == NSApplication.ModalResponse.alertFirstButtonReturn { return }
        
        // delete profile
//        Profile.delete(Profile.Group.mic.rawValue + "_list", name: acc.stringValue)
      } )
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  private var _observations                 = [NSKeyValueObservation]()

  /// Add observations
  ///
  private func addObservations() {

    _observations = [
      // Transmit parameters
      _radio!.transmit.observe(\.micSelection, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      _radio!.transmit.observe(\.micLevel, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      _radio!.transmit.observe(\.micAccEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      _radio!.transmit.observe(\.companderEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      _radio!.transmit.observe(\.companderLevel, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      _radio!.transmit.observe(\.daxEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      _radio!.transmit.observe(\.txMonitorEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      _radio!.transmit.observe(\.txMonitorGainSb, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      _radio!.transmit.observe(\.speechProcessorEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      _radio!.transmit.observe(\.speechProcessorLevel, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.transmitChange(transmit, change) },
      
      // Mic Profile parameters
      _radio!.profiles[Profile.Group.mic.rawValue]!.observe(\.list, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.profileChange(transmit, change) },
      _radio!.profiles[Profile.Group.mic.rawValue]!.observe(\.selection, options: [.initial, .new]) { [weak self] (transmit, change) in
        self?.profileChange(transmit, change) }
    ]
  }
  /// Update profile value
  ///
  /// - Parameter eq:               the Profile
  ///
  private func profileChange(_ profile: Profile, _ change: Any) {
    
    DispatchQueue.main.async { [weak self] in
      // reload the Mic Profiles
      self?._micProfilePopUp.removeAllItems()
      self?._micProfilePopUp.addItems(withTitles: profile.list)
      self?._micProfilePopUp.selectItem(withTitle: profile.selection)

      if profile.selection != "" {
        if profile.selection.first == "*" {
          
          // a selection has been modified (begins with *)
          self?._saveButton.title = "Save"
          self?._saveButton.isEnabled = true
        } else {
          
          // a normal selection has been made
          self?._saveButton.title = "Del"
          self?._saveButton.isEnabled = true
        }
      }
    }
  }
  /// Update all control values
  ///
  /// - Parameter eq:               the Transmit
  ///
  private func transmitChange(_ transmit: Transmit, _ change: Any) {
    
    DispatchQueue.main.async { [weak self] in
      // reload the Mic Sources
      self?._micSelectionPopUp.removeAllItems()
      self?._micSelectionPopUp.addItems(withTitles: self!._radio!.micList)
      self?._micSelectionPopUp.selectItem(withTitle: transmit.micSelection)
      
      // set the Slider values
      self?._micLevelSlider.integerValue = transmit.micLevel
      self?._processorLevelSlider.integerValue = transmit.speechProcessorLevel
      self?._monLevel.integerValue = transmit.txMonitorGainSb
      
      // set the Button states
      self?._accButton.boolState = transmit.micAccEnabled
      self?._procButton.boolState = transmit.speechProcessorEnabled
      self?._daxButton.boolState = transmit.daxEnabled
      self?._monButton.boolState = transmit.txMonitorEnabled
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subscriptions to Notifications
  ///
  private func addNotifications() {
    NC.makeObserver(self, with: #selector(pcwMeterUpdated(_:)), of: .pcwMeterUpdated)
  }
  /// Respond to a change in a Meter
  ///
  /// - Parameters:
  ///   - note:                 a Notification
  ///
  @objc private func pcwMeterUpdated(_ note: Notification) {
    
    if let meter = note.object as? Meter {
      
      // update the appropriate field
      switch meter.name {
        
      case Meter.ShortName.microphoneAverage.rawValue:
        let value = (_radio?.interlock.state == "TRANSMITTING" || _radio!.transmit.metInRxEnabled ? CGFloat(meter.value) : -50)
        DispatchQueue.main.async { [weak self] in self?._micLevelIndicator.level = value }
        
      case Meter.ShortName.microphonePeak.rawValue:
        let value = (_radio?.interlock.state == "TRANSMITTING" || _radio!.transmit.metInRxEnabled ? CGFloat(meter.value) : -50)
        DispatchQueue.main.async {  [weak self] in self?._micLevelIndicator.peak = value }
        
      case Meter.ShortName.postClipper.rawValue:
        let value = (_radio?.interlock.state == "TRANSMITTING" && meter.value > -30.0 ? CGFloat(meter.value) : 10)
        DispatchQueue.main.async {  [weak self] in self?._compressionIndicator.level = value }
        
      default:
        break
      }
    }
  }
}


class ProfileFormatter : Formatter {
  var unexpectedChars = CharacterSet()
  
  override init() {
    // build the allowed character set
    var expectedChars = CharacterSet.alphanumerics
    expectedChars = expectedChars.union(CharacterSet(charactersIn: " _-"))
    
    // make the inverse
    unexpectedChars = expectedChars.inverted
    
    super.init()
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func string(for obj: Any?) -> String? {
    // the object is a String
    return obj as? String
  }
  
  override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
    // the object is a String
    obj!.pointee = string as AnyObject
    return true
  }
  override func isPartialStringValid(_ partialString: String, newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
    
    // only allow A-Z, a-z, 0-9, "-_ "
    return partialString.rangeOfCharacter(from: unexpectedChars) == nil
  }
}
