//
//  TxViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 8/31/18.
//  Copyright © 2018 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class TxViewController: NSViewController {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var _tuneButton        : NSButton!
    @IBOutlet private weak var _moxButton         : NSButton!
    @IBOutlet private weak var _atuButton         : NSButton!
    @IBOutlet private weak var _memButton         : NSButton!
    @IBOutlet private weak var _txProfilePopUp    : NSPopUpButton!
    @IBOutlet private weak var _atuStatus         : NSTextField!
    @IBOutlet private weak var _tunePowerSlider   : NSSlider!
    @IBOutlet private weak var _tunePowerLevel    : NSTextField!
    @IBOutlet private weak var _rfPowerSlider     : NSSlider!
    @IBOutlet private weak var _rfPowerLevel      : NSTextField!
    @IBOutlet private weak var _rfPowerIndicator  : LevelIndicator!
    @IBOutlet private weak var _swrIndicator      : LevelIndicator!
    
    private let _log            = Logger.sharedInstance.logMessage
    private var _radio          : Radio? { Api.sharedInstance.radio }
    
    private let kPowerForward   = Meter.ShortName.powerForward.rawValue
    private let kSwr            = Meter.ShortName.swr.rawValue

    private var _rightClick     : NSClickGestureRecognizer!

    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overriden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // setup Right Single Click recognizer
        _rightClick = NSClickGestureRecognizer(target: self, action: #selector(rightSingleClick(_:)))
        _rightClick.buttonMask = 0x02
        _rightClick.numberOfClicksRequired = 1
        view.addGestureRecognizer(_rightClick)

        // check if a radio is connected
        if let radio = _radio { setupRadioObservations(with: radio) }
        if let radio = _radio, let txProfile = radio.profiles["tx"] { setupProfileObservations(with: txProfile) }

        // setup the RfPower & Swr graphs
        setupBarGraphs()
        
        addNotifications()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    @IBAction func profile(_ sender: NSPopUpButton) {
        if let radio = _radio {
            radio.profiles[Profile.Group.tx.rawValue]?.selection = sender.titleOfSelectedItem!
        }
    }
    
    @IBAction func buttons(_ sender: NSButton) {
        if let radio = _radio {
            switch sender.identifier!.rawValue {
            
            case "Tune":    radio.transmit.tune = sender.boolState
            case "Mox":     radio.mox = sender.boolState
            case "Atu":
                if sender.boolState {
                    radio.atu.start()
                } else {
                    radio.atu.bypass()
                    _atuStatus.stringValue = "Byp"
                }
            case "Mem":
                radio.atu.memoriesEnabled = sender.boolState
            case "Save":    showDialog(sender)
            default:        fatalError()
            }
        }
    }
 
    @IBAction func sliders(_ sender: NSSlider) {
        if let radio = _radio {
            if sender.integerValue <= radio.transmit.maxPowerLevel && radio.transmit.txRfPowerChanges {
                switch sender.identifier!.rawValue {
                
                case "TunePower":   radio.transmit.tunePower = sender.integerValue
                case "RfPower":     radio.transmit.rfPower = sender.integerValue
                default:            fatalError()
                }
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Respond to a Right Click gesture
    ///
    /// - Parameter gr: the GestureRecognizer
    ///
    @objc private func rightSingleClick(_ gestureRecognizer: NSClickGestureRecognizer) {
        
        // get the "click" coordinates and convert to this View
        let mouseLocation = gestureRecognizer.location(in: view)
        
        // create and display the popup menu
        let menu = NSMenu()
        menu.addItem(withTitle: "Clear Memories", action: #selector(clearMemories(_:)), keyEquivalent: "").target = self
        menu.popUp(positioning: menu.item(at: 0), at: mouseLocation, in: view)
    }

    /// Clear memories
    ///
    /// - Parameter sender: a MenuItem
    ///
    @objc private func clearMemories(_ sender: NSMenuItem) {
        if let radio = _radio {
            radio.atu.clear()
        }
    }
    
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
        let acc = NSTextField(frame: CGRect(x: 0, y: 0, width: 233, height: 25))
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
            })
            
        } else {
            // Delete a profile
            alert.messageText = "Delete Tx Profile:"
            alert.addButton(withTitle: "Delete")
            
            alert.beginSheetModal(for: NSApp.mainWindow!, completionHandler: { (response) in
                if response == NSApplication.ModalResponse.alertFirstButtonReturn { return }
                
                // delete profile
                //        Profile.delete(Profile.Group.tx.rawValue + "_list", name: acc.stringValue)
                self._txProfilePopUp.selectItem(at: 0)
            })
        }
    }
    
    /// Set the status of UI objects
    /// - Parameter status:     enabled / disabled
    ///
    private func setRadioStatus(status: Bool) {
        DispatchQueue.main.async { [self] in
            _tuneButton.isEnabled       = status
            _moxButton.isEnabled        = status
            _atuButton.isEnabled        = status
            _memButton.isEnabled        = status
            _tunePowerSlider.isEnabled  = status
            _rfPowerSlider.isEnabled    = status
        }
    }
    
    /// Remove  observations
    /// - Parameter obs:        an array of observation tokens
    ///
    func removeObservations(_ obs: inout [NSKeyValueObservation]) {
        // invalidate observation
        obs.forEach { $0.invalidate() }
        
        // remove the tokens
        obs.removeAll()
    }
    
    private func setupRadioObservations(with radio: Radio) {
        addRadioObservations(with: radio)
        setRadioStatus(status: true)
    }

    private func setupProfileObservations(with profile: Profile) {
        addProfileObservations(with: profile)
        DispatchQueue.main.async { self._txProfilePopUp.isEnabled = true }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    private var _radioObservations       = [NSKeyValueObservation]()
    private var _profileObservations     = [NSKeyValueObservation]()

    /// Add observations
    ///
    private func addRadioObservations(with radio: Radio) {
        _radioObservations = [
            // Atu parameters
            radio.atu.observe(\.status, options: [.initial, .new]) { [weak self] (atu, change) in
                self?.atuStatusChange(atu, change) },
//            radio.atu.observe(\.enabled, options: [.initial, .new]) { [weak self] (atu, change) in
//                self?.atuChange(atu, change) },
//            radio.atu.observe(\.memoriesEnabled, options: [.initial, .new]) { [weak self] (atu, change) in
//                self?.atuChange(atu, change) },
            
            // Radio parameters
            radio.observe(\.mox, options: [.initial, .new]) { [weak self] (radio, change) in
                self?.radioChange(radio, change) },
            
            // Transmit parameters
            radio.transmit.observe(\.tune, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.transmitChange(transmit, change) },
            radio.transmit.observe(\.tunePower, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.transmitChange(transmit, change) },
            radio.transmit.observe(\.rfPower, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.transmitChange(transmit, change) }
            
        ]
    }
    
    private func addProfileObservations(with txProfile: Profile) {
        _profileObservations = [
            // Tx Profile parameters
            txProfile.observe(\.list, options: [.initial, .new]) { [weak self] (profile, change) in
                self?.profileChange(profile, change) },
            txProfile.observe(\.selection, options: [.initial, .new]) { [weak self] (profile, change) in
                self?.profileChange(profile, change) }
        ]
    }

    /// Update all Atu control values
    ///
    /// - Parameter atu:               Atu object
    ///
    private func atuStatusChange(_ atu: Atu, _ change: Any) {
        DispatchQueue.main.async { [weak self] in
            if atu.status.lowercased().contains("byp") {
                // turn off both buttons
                self?._atuButton.boolState = false
                self?._memButton.boolState = false
                self?._atuStatus.stringValue = "Byp"
            } else if atu.status.lowercased().contains("success") {
                // leave buttons as-is
                self?._atuStatus.stringValue = "Success\(self?._memButton.boolState ?? false ? " Mem" : "")"
            } else {
                // turn off both buttons
                self?._atuButton.boolState = false
                self?._memButton.boolState = false
                self?._atuStatus.stringValue = atu.status
            }
        }
    }
    
    /// Update all Profile control values
    ///
    /// - Parameter profile:               Profile object
    ///
    private func profileChange(_ profile: Profile, _ change: Any) {
        DispatchQueue.main.async { [weak self] in
            self?._txProfilePopUp.removeAllItems()
            self?._txProfilePopUp.addItems(withTitles: profile.list)
            self?._txProfilePopUp.selectItem(withTitle: profile.selection)
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
            self?._tuneButton.boolState         = transmit.tune
            self?._tunePowerSlider.integerValue = transmit.tunePower
            self?._tunePowerLevel.integerValue  = transmit.tunePower
            self?._rfPowerSlider.integerValue   = transmit.rfPower
            self?._rfPowerLevel.integerValue    = transmit.rfPower
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    /// Add subsciptions to Notifications
    ///
    private func addNotifications() {        
        NCtr.makeObserver(self, with: #selector(txMeterUpdated(_:)), of: .txMeterUpdated)
        NCtr.makeObserver(self, with: #selector(radioHasBeenAdded(_:)), of: .radioHasBeenAdded)
        NCtr.makeObserver(self, with: #selector(radioWillBeRemoved(_:)), of: .radioWillBeRemoved)
        NCtr.makeObserver(self, with: #selector(profileHasBeenAdded(_:)), of: .profileHasBeenAdded)
        NCtr.makeObserver(self, with: #selector(profileWillBeRemoved(_:)), of: .profileWillBeRemoved)
    }
    
    /// Respond to a change in a Meter
    /// - Parameters:
    ///   - note:                 a Notification
    ///
    @objc private func txMeterUpdated(_ note: Notification) {
        if let meter = note.object as? Meter {
            // update the appropriate field
            DispatchQueue.main.async { [weak self] in
                switch meter.name {
                case Meter.ShortName.powerForward.rawValue: self?._rfPowerIndicator.level = CGFloat(meter.value.powerFromDbm)
                case Meter.ShortName.swr.rawValue:          self?._swrIndicator.level = CGFloat(meter.value)
                default:                                    break
                }
            }
        }
    }
    
    @objc private func radioHasBeenAdded(_ note: Notification) {
        if let radio = note.object as? Radio { setupRadioObservations(with: radio)}
    }

    @objc private func radioWillBeRemoved(_ note: Notification) {
        removeObservations(&_radioObservations)
        setRadioStatus(status: false)
    }

    @objc private func profileHasBeenAdded(_ note: Notification) {
        if let profile = note.object as? Profile, profile.id == "tx" { setupProfileObservations(with: profile) }
    }

    @objc private func profileWillBeRemoved(_ note: Notification) {
        if let profile = note.object as? Profile, profile.id == "tx" {
            removeObservations(&_profileObservations)
            DispatchQueue.main.async { self._txProfilePopUp.isEnabled = false }
        }
    }
}
