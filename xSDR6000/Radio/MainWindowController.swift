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

final class MainWindowController                  : NSWindowController, NSWindowDelegate {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _panButton           : NSButton!
  @IBOutlet private weak var _macAudioButton      : NSButton!
  @IBOutlet private weak var _tnfButton           : NSButton!
  @IBOutlet private weak var _markersButton       : NSButton!
  @IBOutlet private weak var _sideButton          : NSButton!
  @IBOutlet private weak var _fdxButton           : NSButton!
  @IBOutlet private weak var _cwxButton           : NSButton!
  @IBOutlet private weak var _lineoutMuteButton   : NSButton!
  @IBOutlet private weak var _headphoneMuteButton : NSButton!
  @IBOutlet private weak var _lineoutGainSlider   : NSSlider!
  @IBOutlet private weak var _headphoneGainSlider : NSSlider!
  
  private let _log          = Logger.sharedInstance
  private var _observations = [NSKeyValueObservation]()
  private var _opusPlayer   : OpusPlayer?

  private var _sideViewController         : SideViewController?
  private var _profilesWindowController     : NSWindowController?
  private var _preferencesWindowController  : NSWindowController?
  private var _temperatureMeterAvailable  = false
  private var _voltageMeterAvailable      = false

  private enum WindowState {
    case open
    case close
  }
  private let kSideStoryboardName           = "Side"
  private let kSideIdentifier               = "Side"
  private let kSideViewDelay                = 2   // seconds
  private let kPreferencesStoryboardName    = "Preferences"
  private let kPreferencesIdentifier        = "Preferences"

  private let kProfilesStoryboardName       = "Profiles"
  private let kProfilesIdentifier           = "Profiles"

  private var _sideStoryboard               : NSStoryboard?
  private var _preferencesStoryboard        : NSStoryboard?
  private var _profilesStoryboard           : NSStoryboard?
  private var _tcpPingFirstResponseReceived = false

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func awakeFromNib() {
    windowFrameAutosaveName = "MainWindow"

    // get the Storyboards
    _sideStoryboard = NSStoryboard(name: kSideStoryboardName, bundle: nil)
    _preferencesStoryboard = NSStoryboard(name: kPreferencesStoryboardName, bundle: nil)
    _profilesStoryboard = NSStoryboard(name: kProfilesStoryboardName, bundle: nil)

    addObservations()
    addNotifications()
  }
  #if XDEBUG
  deinit {
    Swift.print("deinit - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  /// The Preferences or Profiles window is being closed
  ///
  ///   this is called as a result of clicking the window's close button
  ///
  /// - Parameter sender:             the window
  /// - Returns:                      return true to allow
  ///
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    
    // which window?
    if _preferencesWindowController?.window == sender {
      // Preferences
      DispatchQueue.main.async { [weak self] in
        self?._preferencesWindowController = nil
      }
    } else {
      // Profiles
      DispatchQueue.main.async { [weak self] in
        self?._profilesWindowController = nil
      }
    }
    return true
  }

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
    sideView(open: Defaults[.sideViewOpen])
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

  /// Respond to the Pan button
  ///
  /// - Parameter sender:         the Button
  ///
  @IBAction func panButton(_ sender: AnyObject) {
    
    // dimensions are dummy values; when created, will be resized to fit its view
    Api.sharedInstance.radio?.requestPanadapter(CGSize(width: 50, height: 50))
  }
  
  @IBAction func tnfMenu(_ sender: NSMenuItem) {
    Api.sharedInstance.radio!.tnfsEnabled.toggle()
  }
  
  @IBAction func markersMenu(_ sender: NSMenuItem) {
    Defaults[.markersEnabled].toggle()
    _markersButton.boolState = Defaults[.markersEnabled]
  }
  
  @IBAction func sideMenu(_ sender: NSMenuItem) {
    Defaults[.sideViewOpen].toggle()
    _sideButton.boolState = Defaults[.sideViewOpen]
    sideView(open: Defaults[.sideViewOpen])
  }

  @IBAction func panMenu(_ sender: NSMenuItem) {
    panButton(self)
  }

  @IBAction func nextSliceMenu(_ sender: NSMenuItem) {
  
    // FIXME: ???
  }

  /// Respond to the Profiles menu (Command-,)
  ///
  /// - Parameter sender:         the MenuItem
  ///
  @IBAction func preferencesMenu(_ sender: NSMenuItem) {
    preferencesWindow(open: true)
  }
  /// Respond to the Profiles menu (Command-P)
  ///
  /// - Parameter sender:         the MenuItem
  ///
  @IBAction func profilesMenu(_ sender: NSMenuItem) {
    profilesWindow(open: true)
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
        title = "\(radio.discoveryPacket.nickname) v\(radio.version.longString) \(radio.discoveryPacket.isWan ? "SmartLink" : "Local")         \(Logger.kAppName) v\(Logger.sharedInstance.version.string)"

      } else {
        // NO, show App & Api only
        title = "\(Logger.kAppName) v\(Logger.sharedInstance.version.string)"
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
      // OldApi
      Api.sharedInstance.radio!.startStopOpusRxAudioStream(state: start)
      
      if start { usleep(50_000) ; _opusPlayer?.start() } else { _opusPlayer?.stop() }
    }
  }
  /// Open or Close the Side view
  ///
  /// - Parameter state:              the desired state
  ///
  private func sideView(open: Bool) {
        
    if open {
      // OPENING, is there an existing instance?
      if _sideViewController == nil {
        // NO, get an instance of the Side view
        _sideViewController = _sideStoryboard!.instantiateController(withIdentifier: kSideIdentifier) as? SideViewController
        
        _log.logMessage("Side view opened", .info,  #function, #file, #line)
        DispatchQueue.main.async { [weak self] in
          // add it to the split view
          if let vc = self?.contentViewController as? RadioViewController {
            vc.addChild(self!._sideViewController!)
          }
        }
      }
    } else {
      
      DispatchQueue.main.async { [weak self] in
        // CLOSING, is there an instance?
        if self?._sideViewController != nil {
          
          if let vc = self?.contentViewController as? RadioViewController {
            // YES, collapse it first
            vc.splitViewItems[1].isCollapsed = true
            
            // remove it from the split view
            vc.removeChild(at: 1)
          }
          self?._sideViewController = nil

          self?._log.logMessage("Side view closed", .info,  #function, #file, #line)
        }
      }
    }
  }
  /// Open or Close the Preferences window
  ///
  /// - Parameter state:              the desired state
  ///
  private func preferencesWindow(open: Bool) {
    
    if open {
      // OPENING, is there an existing instance?
      if _preferencesWindowController == nil {
        // NO, get one
        _preferencesWindowController = _preferencesStoryboard!.instantiateController(withIdentifier: kPreferencesIdentifier) as? NSWindowController
        _preferencesWindowController?.window?.delegate = self
        
        DispatchQueue.main.async { [weak self] in
          // show the Preferences window
          self?._preferencesWindowController?.showWindow(self!)
        }
      }
      
    } else {
      // CLOSING, is there an instance?
      if _preferencesWindowController != nil {
        // YES, close it
        DispatchQueue.main.async { [weak self] in
          self?._preferencesWindowController?.window?.close()
          self?._preferencesWindowController = nil
        }
      }
    }
  }
  /// Open or Close the Profiles window
  ///
  /// - Parameter state:              the desired state
  ///
  private func profilesWindow(open: Bool) {
  
    if open {
      // OPENING, is there an existing instance?
      if _profilesWindowController == nil {
        // NO, get an instance of the Profiles
        _profilesWindowController = _profilesStoryboard!.instantiateController(withIdentifier: kProfilesIdentifier) as? NSWindowController
        _profilesWindowController?.window?.delegate = self

        DispatchQueue.main.async { [weak self] in
          // show the Profiles window
          self?._profilesWindowController?.showWindow(self!)
        }
      }
    
    } else {
      // CLOSING, is there an instance?
      if _profilesWindowController != nil {
        // YES, close it
        DispatchQueue.main.async { [weak self] in
          self?._profilesWindowController?.close()
          self?._profilesWindowController = nil
        }
      }
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
        self?.updateButtons(object, \.fullDuplexEnabled) },
      Api.sharedInstance.observe(\.radio?.lineoutMute, options: [.initial, .new]) { [weak self] (object, change) in
        self?.updateButtons(object, \.lineoutMute) },
      Api.sharedInstance.observe(\.radio?.headphoneMute, options: [.initial, .new]) { [weak self] (object, change) in
        self?.updateButtons(object, \.headphoneMute) },

      Api.sharedInstance.observe(\.radio?.lineoutGain, options: [.initial, .new]) { [weak self] (object, change) in
        self?.updateSliders(object, \.lineoutGain) },
      Api.sharedInstance.observe(\.radio?.headphoneGain, options: [.initial, .new]) { [weak self] (object, change) in
        self?.updateSliders(object, \.headphoneGain) }
    ]
  }
  /// Respond to observations
  ///
  /// - Parameters:
  ///   - api:                       the object holding the properties
  ///   - change:                    the change
  ///
  private func enableButtons(_ api: Api, _ change: Any) {
    
//    if api.hasPendingDisconnect != .oldApi {
      
      // enable / disable based on state of radio
      DispatchQueue.main.async { [weak self] in
        
        let state = (api.radio != nil)
        
        self?._panButton.isEnabled            = state
        self?._macAudioButton.isEnabled       = state
        self?._tnfButton.isEnabled            = state
        self?._markersButton.isEnabled        = state
        self?._sideButton.isEnabled           = state
        self?._fdxButton.isEnabled            = state
        self?._cwxButton.isEnabled            = state
        self?._lineoutGainSlider.isEnabled    = state
        self?._lineoutMuteButton.isEnabled    = state
        self?._headphoneGainSlider.isEnabled  = state
        self?._headphoneMuteButton.isEnabled  = state
        
        // if enabled, set their states / values
        if state {
          self?._macAudioButton.boolState         = Defaults[.macAudioEnabled]
          self?._tnfButton.boolState              = api.radio!.tnfsEnabled
          self?._markersButton.boolState          = Defaults[.markersEnabled]
          self?._sideButton.boolState             = Defaults[.sideViewOpen]
          self?._fdxButton.boolState              = api.radio!.fullDuplexEnabled
          self?._cwxButton.boolState              = Defaults[.cwxViewOpen]
          self?._lineoutGainSlider.integerValue   = api.radio!.lineoutGain
          self?._lineoutMuteButton.boolState      = api.radio!.lineoutMute
          self?._headphoneGainSlider.integerValue = api.radio!.headphoneGain
          self?._headphoneMuteButton.boolState    = api.radio!.headphoneMute
          
          if Defaults[.macAudioEnabled] { self?.macAudio(start: true)}
        }
      }
//    }
  }
  /// Respond to observations
  ///
  /// - Parameters:
  ///   - api:                       the object holding the properties
  ///   - keypath:                   the changed property
  ///
  private func updateButtons(_ api: Api, _ keypath: KeyPath<Radio, Bool>) {
    
    if let radio = api.radio {
      DispatchQueue.main.async { [weak self] in
        switch keypath {
        case \.tnfsEnabled:         self?._tnfButton.boolState = radio[keyPath: keypath]
        case \.fullDuplexEnabled:   self?._fdxButton.boolState = radio[keyPath: keypath]
        case \.lineoutMute:         self?._lineoutMuteButton.boolState = radio[keyPath: keypath]
        case \.headphoneMute:       self?._headphoneMuteButton.boolState = radio[keyPath: keypath]
          
        default:                    fatalError()
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
  private func updateSliders(_ api: Api, _ keypath: KeyPath<Radio, Int>) {
    
    if let radio = api.radio {

      DispatchQueue.main.async { [weak self] in
        switch keypath {
        case \.lineoutGain:     self?._lineoutGainSlider.integerValue   = radio[keyPath: keypath]
        case \.headphoneGain:   self?._headphoneGainSlider.integerValue = radio[keyPath: keypath]
          
        default:                fatalError()
        }
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

    NC.makeObserver(self, with: #selector(tcpPingFirstResponse(_:)), of: .tcpPingFirstResponse)

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
    
    _log.logMessage("Radio initialized: \(radio.nickname), v\(radio.discoveryPacket.firmwareVersion)", .info,  #function, #file, #line)

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
    if let name = note.object as? String {
      // the Radio class has been removed
      _log.logMessage("Radio has been removed: \(name)", .info, #function, #file, #line)
      
      // update the window title
      title()
    }
  }
  /// Process .tcpPingFirstResponse Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func tcpPingFirstResponse(_ note: Notification) {
    
    // receipt of the first Ping response indicates the Radio is fully initialized
    _tcpPingFirstResponseReceived = true
    
    // delay the opening of the side view (allows Slice(s) to be instantiated, if any)
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds( kSideViewDelay )) { [weak self] in
      // show/hide the Side view
      self?.sideView(open: Defaults[.sideViewOpen])
    }
  }
  /// Process .meterHasBeenAdded Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func meterHasBeenAdded(_ note: Notification) {
    
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
