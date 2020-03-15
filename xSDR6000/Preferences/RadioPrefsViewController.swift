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
  
  private var _radio                        : Radio? { Api.sharedInstance.radio }

  // ----------------------------------------------------------------------------
  // MARK: - Overridden  methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    view.translatesAutoresizingMaskIntoConstraints = false
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    
    loadFields()
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
  // MARK: - Private  methods
  
  /// Load the screen's fields
  ///
  private func loadFields() {
    
    _serialNumberTextField.stringValue = _radio!.serialNumber
    _hwVersionTextField.stringValue = _radio!.version.longString
    _optionsTextField.stringValue = _radio!.radioOptions
    _modelTextField.stringValue = _radio!.radioModel
    _callsignTextField.stringValue = _radio!.callsign
    _nicknameTextField.stringValue = _radio!.nickname
    _remoteOnEnabledCheckbox.boolState = _radio!.remoteOnEnabled
    //      _accTxCheckbox.boolState = interlock.accTxEnabled
    _modelRadioButton.boolState = _radio!.radioScreenSaver == "model"
    _callsignRadioButton.boolState = _radio!.radioScreenSaver == "callsign"
    _nicknameRadioButton.boolState = _radio!.radioScreenSaver == "nickname"
  }
}
