//
//  MainWindowController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 3/1/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

// --------------------------------------------------------------------------------
// MARK: - Main Window Controller class implementation
// --------------------------------------------------------------------------------

final class MainWindowController                  : NSWindowController {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _macAudioButton      : NSButton!
  @IBOutlet private weak var _tnfButton           : NSButton!
  @IBOutlet private weak var _markersButton       : NSButton!
  @IBOutlet private weak var _sideButton          : NSButton!
  @IBOutlet private weak var _fdxButton           : NSButton!
  @IBOutlet private weak var _cwxButton           : NSButton!
  @IBOutlet private weak var _muteLineoutButton   : NSButton!
  @IBOutlet private weak var _muteHeadphoneButton : NSButton!
  @IBOutlet private weak var _lineoutGainSlider   : NSSlider!
  @IBOutlet private weak var _headphoneGainSlider : NSSlider!
  
  private let _log          = Logger.sharedInstance
  private var _observations = [NSKeyValueObservation]()
  private var _opusPlayer   : OpusPlayer?

  private var _temperatureMeterAvailable  = false
  private var _voltageMeterAvailable      = false

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func awakeFromNib() {
    windowFrameAutosaveName = "MainWindow"
    
    addObservations()
    addNotifications()
  }
  #if XDEBUG
  deinit {
    Swift.print("deinit - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif
  
  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  @IBAction func tnfButton(_ sender: NSButton) {
    Api.sharedInstance.radio!.tnfsEnabled = sender.boolState
  }
  
  @IBAction func markersButton(_ sender: NSButton) {
    Defaults[.markersEnabled] = sender.boolState
  }
  
  @IBAction func sideButton(_ sender: NSButton) {
    Defaults[.sideViewOpen] = sender.boolState
  }
  
  @IBAction func fdxButton(_ sender: NSButton) {
    Api.sharedInstance.radio!.fullDuplexEnabled = sender.boolState
  }
  
  @IBAction func cwxButton(_ sender: NSButton) {
    Defaults[.cwxViewOpen] = sender.boolState
  }
    
  /// Respond to the Mac Audio button
  ///
  /// - Parameter sender:         the Button
  ///
  @IBAction func macAudioButton(_ sender: NSButton) {
    
    // update the default value
    Defaults[.macAudioEnabled] = sender.boolState
    
    macAudio(start: sender.boolState)
  }

  @IBAction func muteLineoutButton(_ sender: NSButton) {
    Api.sharedInstance.radio!.lineoutMute = sender.boolState
  }
  
  @IBAction func lineoutGainSlider(_ sender: NSSlider) {
    Api.sharedInstance.radio!.lineoutGain = sender.integerValue
  }
  
  @IBAction func headphoneGainSlider(_ sender: NSSlider) {
    Api.sharedInstance.radio!.headphoneGain = sender.integerValue
  }
  
  @IBAction func muteHeadphoneButton(_ sender: NSButton) {
    Api.sharedInstance.radio!.headphoneMute = sender.boolState
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Set the Window's title
  ///
  private func title() {

    // set the title bar
    DispatchQueue.main.async { [unowned self] in
      var title = ""
      // are we connected?
      if let radio = Api.sharedInstance.radio {
        // YES, format and set the window title
        title = "\(radio.discoveryPacket.nickname) v\(radio.version.longString)         \(Logger.kAppName) v\(Logger.sharedInstance.version.string)       xLib6000 " + versionOf("xLib6000")

      } else {
        // NO, show App & Api only
        title = "\(Logger.kAppName) v\(Logger.sharedInstance.version.string)     \(Api.kName) " + versionOf("xLib6000")
      }
      self.window?.title = title
    }
  }
  /// Start / Stop Mac audio
  /// - Parameter start:      state
  ///
  private func macAudio(start: Bool) {
    // what API version?
    if Api.sharedInstance.radio!.version.isNewApi {
      // NewApi
      if start {
        // add a stream
        Api.sharedInstance.radio!.requestRemoteRxAudioStream()
        
      } else {
        // request the stream removal
        for (_, stream) in Api.sharedInstance.radio!.remoteRxAudioStreams where stream.clientHandle == Api.sharedInstance.connectionHandle {
          stream.remove()
        }
      }
      
    } else {
      
      // FIXME:
      
      
      // OldApi
      //      Api.sharedInstance.radio!.startStopOpusRxAudioStream(state: sender.boolState)
      //
      //      if sender.boolState == true { usleep(50_000) ; _opusPlayer?.start() } else { _opusPlayer?.stop() }
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Observation methods

  /// Add observations of various properties used by the Panadapter
  ///
  private func addObservations() {
    
    _observations = [
      
      Api.sharedInstance.observe(\.radio, options: [.initial, .new]) { [weak self] (object, change) in
        self?.enableButtons(object, change) },
      Api.sharedInstance.observe(\.radio?.tnfsEnabled, options: [.initial, .new]) { [weak self] (object, change) in
        self?.updateButtons(object, \.tnfsEnabled) },
      Api.sharedInstance.observe(\.radio?.fullDuplexEnabled, options: [.initial, .new]) { [weak self] (object, change) in
        self?.updateButtons(object, \.fullDuplexEnabled) }
    ]
  }
  /// Respond to observations
  ///
  /// - Parameters:
  ///   - api:                       the object holding the properties
  ///   - change:                    the change
  ///
  private func enableButtons(_ api: Api, _ change: Any) {
    
    if api.hasPendingDisconnect != .oldApi {
      
      // enable / disable based on state of radio
      DispatchQueue.main.async { [weak self] in
        
        let state = (api.radio != nil)
        
        self?._macAudioButton.isEnabled       = state
        self?._tnfButton.isEnabled            = state
        self?._markersButton.isEnabled        = state
        self?._sideButton.isEnabled           = state
        self?._fdxButton.isEnabled            = state
        self?._cwxButton.isEnabled            = state
        self?._lineoutGainSlider.isEnabled    = state
        self?._muteLineoutButton.isEnabled    = state
        self?._headphoneGainSlider.isEnabled  = state
        self?._muteHeadphoneButton.isEnabled  = state
        
        // if enabled, set their states / values
        if state {
          self?._macAudioButton.boolState         = Defaults[.macAudioEnabled]
          self?._tnfButton.boolState              = api.radio!.tnfsEnabled
          self?._markersButton.boolState          = Defaults[.markersEnabled]
          self?._sideButton.boolState             = Defaults[.sideViewOpen]
          self?._fdxButton.boolState              = api.radio!.fullDuplexEnabled
          self?._cwxButton.boolState              = Defaults[.cwxViewOpen]
          self?._lineoutGainSlider.integerValue   = api.radio!.lineoutGain
          self?._muteLineoutButton.boolState      = api.radio!.lineoutMute
          self?._headphoneGainSlider.integerValue = api.radio!.headphoneGain
          self?._muteHeadphoneButton.boolState    = api.radio!.headphoneMute
          
          if Defaults[.macAudioEnabled] { self?.macAudio(start: true)}
        }
      }
    }
  }
  /// Respond to observations
  ///
  /// - Parameters:
  ///   - api:                       the object holding the properties
  ///   - keypath:                   the changed property
  ///
  private func updateButtons(_ api: Api, _ keypath: KeyPath<Radio, Bool>) {
    
    if let radio = api.radio {
      switch keypath {
      case \.tnfsEnabled:         _tnfButton.boolState = radio[keyPath: keypath]
      case \.fullDuplexEnabled:   _fdxButton.boolState = radio[keyPath: keypath]
      default:                    fatalError()
      }
    }
  }
  
  
  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subscriptions to Notifications
  ///
  private func addNotifications() {
    NC.makeObserver(self, with: #selector(radioHasBeenAdded(_:)), of: .radioHasBeenAdded)
    NC.makeObserver(self, with: #selector(radioWillBeRemoved(_:)), of: .radioWillBeRemoved)
    NC.makeObserver(self, with: #selector(radioHasBeenRemoved(_:)), of: .radioHasBeenRemoved)

    NC.makeObserver(self, with: #selector(meterHasBeenAdded(_:)), of: .meterHasBeenAdded)

    NC.makeObserver(self, with: #selector(opusAudioStreamHasBeenAdded(_:)), of: .opusAudioStreamHasBeenAdded)
    NC.makeObserver(self, with: #selector(opusAudioStreamWillBeRemoved(_:)), of: .opusAudioStreamWillBeRemoved)
    
    NC.makeObserver(self, with: #selector(remoteRxAudioStreamHasBeenAdded(_:)), of: .remoteRxAudioStreamHasBeenAdded)
    NC.makeObserver(self, with: #selector(remoteRxAudioStreamWillBeRemoved(_:)), of: .remoteRxAudioStreamWillBeRemoved)
  }
  /// Process .radioHasBeenAdded Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func radioHasBeenAdded(_ note: Notification) {
    
    // the Radio class has been initialized
    let radio = note.object as! Radio
    
    _log.logMessage("Radio initialized: \(radio.nickname)", .info,  #function, #file, #line)

    Defaults[.versionRadio] = radio.discoveryPacket.firmwareVersion
    Defaults[.radioModel] = radio.discoveryPacket.model
    
    // update the title bar
    title()
  }
  /// Process .radioWillBeRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func radioWillBeRemoved(_ note: Notification) {
    
    // the Radio class is being removed
    if let radio = note.object as? Radio {
      
      _log.logMessage("Radio will be removed: \(radio.nickname)", .info,  #function, #file, #line)
      
      Defaults[.versionRadio] = ""
      
      // remove all objects on Radio
      radio.removeAll()
    }
  }
  /// Process .radioHasBeenRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func radioHasBeenRemoved(_ note: Notification) {
    
    // the Radio class has been removed
    _log.logMessage("Radio has been removed", .info, #function, #file, #line)

    // update the window title
    title()
  }
  /// Process .meterHasBeenAdded Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func meterHasBeenAdded(_ note: Notification) {
    
//    guard Api.sharedInstance.hasPendingDisconnect != .oldApi else { return }
    
    let meter = note.object as! Meter
    
    // is it one we need to watch?
    switch meter.name {
    case Meter.ShortName.voltageAfterFuse.rawValue:
      _voltageMeterAvailable = true
      
    case Meter.ShortName.temperaturePa.rawValue:
      _temperatureMeterAvailable = true
      
    default:
      break
    }
    guard _voltageMeterAvailable == true, _temperatureMeterAvailable == true else { return }
    
    DispatchQueue.main.async { [weak self] in
      // start the Voltage/Temperature monitor
      if let toolbar = self?.window?.toolbar {
        let monitor = toolbar.items.findElement({  $0.itemIdentifier.rawValue == "VoltageTemp"} ) as! ParameterMonitor
        monitor.activate(radio: Api.sharedInstance.radio!, shortNames: [.voltageAfterFuse, .temperaturePa], units: ["v", "c"])
      }
    }
  }
  /// Process .opusAudioStreamHasBeenAdded Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func opusAudioStreamHasBeenAdded(_ note: Notification) {

    // the OpusAudioStream has been added
    if let opusAudioStream = note.object as? OpusAudioStream {

      _log.logMessage("OpusAudioStream added: id = \(opusAudioStream.id.hex)", .info, #function, #file, #line)

      _opusPlayer = OpusPlayer()
      if Defaults[.macAudioEnabled] { _opusPlayer!.start() }
      opusAudioStream.delegate = _opusPlayer
    }
  }
  /// Process .opusAudioStreamWillBeRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func opusAudioStreamWillBeRemoved(_ note: Notification) {
    
    // the OpusAudioStream is being removed
    if let opusAudioStream = note.object as? OpusAudioStream {
      
      _log.logMessage("OpusAudioStream will be removed: id = \(opusAudioStream.id.hex)", .info,  #function, #file, #line)

      opusAudioStream.delegate = nil
      _opusPlayer?.stop()
      _opusPlayer = nil
    }
  }
  /// Process .remoteRxAudioStreamHasBeenAdded Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func remoteRxAudioStreamHasBeenAdded(_ note: Notification) {

    // the RemoteRxAudioStream class has been initialized
    if let remoteRxAudioStream = note.object as? RemoteRxAudioStream {
    
      _log.logMessage("RemoteRxAudioStream added: id = \(remoteRxAudioStream.id.hex)", .info, #function, #file, #line)

      _opusPlayer = OpusPlayer()
      _opusPlayer?.start()
      remoteRxAudioStream.delegate = _opusPlayer
    }
  }
  /// Process .remoteRxAudioStreamWillBeRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func remoteRxAudioStreamWillBeRemoved(_ note: Notification) {
    
    // the RemoteRxAudioStream is being removed
    if let remoteRxAudioStream = note.object as? RemoteRxAudioStream {
      
      _log.logMessage("RemoteRxAudioStream will be removed: id = \(remoteRxAudioStream.id.hex)", .info,  #function, #file, #line)

      remoteRxAudioStream.delegate = nil
      _opusPlayer?.stop()
      _opusPlayer = nil
    }
  }

  
}
