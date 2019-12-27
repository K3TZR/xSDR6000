//
//  RadioPrefsViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 12/15/18.
//  Copyright © 2018 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class RadioPrefsViewController: NSViewController {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private  properties
  
  @IBOutlet private weak var _serialNumberTextField       : NSTextField!
  @IBOutlet private weak var _hwVersionTextField          : NSTextField!
  @IBOutlet private weak var _optionsTextField            : NSTextField!
  @IBOutlet private weak var _modelTextField              : NSTextField!
  @IBOutlet private weak var _callsignTextField           : NSTextField!
  @IBOutlet private weak var _nicknameTextField           : NSTextField!
  
  @IBOutlet private weak var _remoteOnEnabledCheckbox     : NSButton!
  @IBOutlet private weak var _flexControlEnabledCheckbox  : NSButton!
  
  @IBOutlet private weak var _modelRadioButton            : NSButton!
  @IBOutlet private weak var _callsignRadioButton         : NSButton!
  @IBOutlet private weak var _nicknameRadioButton         : NSButton!
  
  private var _radio                        : Radio? { return Api.sharedInstance.radio }
  private var _observations                 = [NSKeyValueObservation]()

  // ----------------------------------------------------------------------------
  // MARK: - Overridden  methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    view.translatesAutoresizingMaskIntoConstraints = false
    
    // begin observing properties
    addObservations()
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Action  methods
  
  @IBAction func regionChange(_ sender: NSButton) {
    
    // TODO: add code
    
    notImplemented(sender.title).beginSheetModal(for: NSApp.mainWindow!, completionHandler: { (response) in } )
  }
  
  @IBAction func screensaver(_ sender: NSButton) {
    
    _radio?.radioScreenSaver = sender.identifier!.rawValue
  }
  
  @IBAction func textFields(_ sender: NSTextField) {
    
    switch sender.identifier!.rawValue {
    case "CallsignText":
      _radio?.callsign = sender.stringValue
      
    case "NicknameText":
      _radio?.nickname = sender.stringValue
      
    default:
      fatalError()
    }
  }
  
  @IBAction func checkboxes(_ sender: NSButton) {

    switch sender.identifier!.rawValue {
    case "RemoteOn":
      _radio?.remoteOnEnabled = sender.boolState
      
      // TODO:
      
//    case "FlexControl":
//      _radio?.flexControlEnabled = sender.boolState
      
    default:
      fatalError()
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  /// Add observations of various properties used by the view
  ///
  private func addObservations() {
    
    _observations = [
      _radio!.observe(\.serialNumber, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._serialNumberTextField.stringValue = radio.serialNumber },
      
      _radio!.observe(\.version, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._hwVersionTextField.stringValue = radio.version },
      
      _radio!.observe(\.radioOptions, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._optionsTextField.stringValue = radio.radioOptions },
      
      _radio!.observe(\.radioModel, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._modelTextField.stringValue = radio.radioModel },
      
      _radio!.observe(\.callsign, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._callsignTextField.stringValue = radio.callsign },
      
      _radio!.observe(\.nickname, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._nicknameTextField.stringValue = radio.nickname },
      
      _radio!.observe(\.remoteOnEnabled, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._remoteOnEnabledCheckbox.boolState = radio.remoteOnEnabled},
      
//      _radio!.observe(\.flexControlEnabled, options: [.initial, .new]) { [weak self] (interlock, change) in
//      self?._accTxCheckbox.boolState = interlock.accTxEnabled },

      _radio!.observe(\.radioScreenSaver, options: [.initial, .new]) { [weak self] (radio, change) in
        self?._modelRadioButton.boolState = (radio.radioScreenSaver == "model")
        self?._callsignRadioButton.boolState = (radio.radioScreenSaver == "callsign")
        self?._nicknameRadioButton.boolState = (radio.radioScreenSaver == "nickname") }
    ]
  }
  /// Process observations
  ///
  /// - Parameters:
  ///   - profile:                  the Radio being observed
  ///   - change:                   the change
  ///
//  private func radioHandler(_ radio: Radio, _ change: Any) {
//
//    DispatchQueue.main.async { [weak self] in
//      self?._serialNumberTextField.stringValue = radio.serialNumber
//      self?._hwVersionTextField.stringValue = radio.version
//      self?._optionsTextField.stringValue = radio.radioOptions
//      self?._modelTextField.stringValue = radio.radioModel
//      self?._callsignTextField.stringValue = radio.callsign
//      self?._nicknameTextField.stringValue = radio.nickname
//
//      self?._remoteOnEnabledCheckbox.boolState = radio.remoteOnEnabled
////      self._flexControlEnabledCheckbox = radio.flexControlEnabled
//
//      self?._modelRadioButton.boolState = (radio.radioScreenSaver == "model")
//      self?._callsignRadioButton.boolState = (radio.radioScreenSaver == "callsign")
//      self?._nicknameRadioButton.boolState = (radio.radioScreenSaver == "nickname")
//    }
//  }
}
