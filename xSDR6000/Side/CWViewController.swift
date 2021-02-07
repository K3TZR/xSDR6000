//
//  CWViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/15/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class CWViewController: NSViewController {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var _alcLevelIndicator       : LevelIndicator!
    
    @IBOutlet private weak var _breakInButton           : NSButton!
    @IBOutlet private weak var _delaySlider             : NSSlider!
    @IBOutlet private weak var _delayTextfield          : NSTextField!
    @IBOutlet private weak var _iambicButton            : NSButton!
    @IBOutlet private weak var _pitchStepper            : NSStepper!
    @IBOutlet private weak var _pitchTextfield          : NSTextField!
    @IBOutlet private weak var _sidetoneButton          : NSButton!
    @IBOutlet private weak var _sidetoneLevelSlider     : NSSlider!
    @IBOutlet private weak var _sidetonePanSlider       : NSSlider!
    @IBOutlet private weak var _sidetoneLevelTextfield  : NSTextField!
    @IBOutlet private weak var _speedSlider             : NSSlider!
    @IBOutlet private weak var _speedTextfield          : NSTextField!
    
    private var _radio               : Radio? { Api.sharedInstance.radio }
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overriden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // check if a radio is connected
        if let radio = _radio, let transmit = radio.transmit { setupTransmitObservations(with: transmit) }
        
        // setup the MicLevel & Compression graphs
        setupBarGraphs()
        
        addNotifications()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    /// Respond to a text field
    ///
    /// - Parameter sender:             the textfield
    ///
    @IBAction func textFields(_ sender: NSTextField) {
        if let radio = _radio, let transmit = radio.transmit {
            switch sender.identifier?.rawValue {
            
            case "DelayTextfield":          transmit.cwBreakInDelay     = sender.integerValue
            case "PitchTextfield":          transmit.cwPitch            = sender.integerValue
            case "SidetoneLevelTextfield":  transmit.txMonitorGainCw    = sender.integerValue
            case "SpeedTextField":          transmit.cwSpeed            = sender.integerValue
            default:                        break
            }
        }
    }
    /// Respond to one of the buttons
    ///
    /// - Parameter sender:             the button
    ///
    @IBAction func buttons(_ sender: NSButton) {
        if let radio = _radio, let transmit = radio.transmit {
            switch sender.identifier!.rawValue {
            
            case "BreakInButton":   transmit.cwBreakInEnabled   = sender.boolState
            case "IambicButton":    transmit.cwIambicEnabled    = sender.boolState
            case "SidetoneButton":  transmit.cwSidetoneEnabled  = sender.boolState
            default:                break
            }
        }
    }
    /// Respond to one of the sliders
    ///
    /// - Parameter sender:             the slider
    ///
    @IBAction func sliders(_ sender: NSSlider) {
        if let radio = _radio, let transmit = radio.transmit {
            switch sender.identifier!.rawValue {
            
            case "DelaySlider":         transmit.cwBreakInDelay     = sender.integerValue
            case "SidetoneLevelSlider": transmit.txMonitorGainCw    = sender.integerValue
            case "SidetonePanSlider":   transmit.txMonitorPanCw     = sender.integerValue
            case "SpeedSlider":         transmit.cwSpeed            = sender.integerValue
            default:                    break
            }
        }
    }
    /// Respond to the Pitch stepper
    ///
    /// - Parameter sender:             the slider
    ///
    @IBAction func steppers(_ sender: NSStepper) {
        if let radio = _radio, let transmit = radio.transmit {
            transmit.cwPitch = sender.integerValue
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Setup graph styles, legends and resting levels
    ///
    private func setupBarGraphs() {
        
        _alcLevelIndicator.legends = [
            (0, "0", 0),
            (5, "100", 1.0),
            (nil, "ALC", 0)
        ]
    }
    
    private func setTransmitStatus(status: Bool) {
        DispatchQueue.main.async { [self] in
            _breakInButton.isEnabled            = status
            _delaySlider.isEnabled              = status
            _delayTextfield.isEnabled           = status
            _iambicButton.isEnabled             = status
            _pitchStepper.isEnabled             = status
            _pitchTextfield.isEnabled           = status
            _sidetoneButton.isEnabled           = status
            _sidetoneLevelSlider.isEnabled      = status
            _sidetonePanSlider.isEnabled        = status
            _sidetoneLevelTextfield.isEnabled   = status
            _speedSlider.isEnabled              = status
            _speedTextfield.isEnabled           = status
        }
    }
    
    private func setupTransmitObservations(with transmit: Transmit) {
        addTransmitObservations(with: transmit)
        setTransmitStatus(status: true)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    private var _transmitObservations   = [NSKeyValueObservation]()
    
    /// Add observations
    ///
    private func addTransmitObservations(with transmit: Transmit) {
        _transmitObservations = [
            // Transmit observations
            transmit.observe(\.cwBreakInDelay, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.cwChange(transmit, change) },
            transmit.observe(\.cwBreakInEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.cwChange(transmit, change) },
            transmit.observe(\.cwIambicEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.cwChange(transmit, change) },
            transmit.observe(\.cwPitch, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.cwChange(transmit, change) },
            transmit.observe(\.cwSidetoneEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.cwChange(transmit, change) },
            transmit.observe(\.cwSpeed, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.cwChange(transmit, change) },
            transmit.observe(\.txMonitorGainCw, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.cwChange(transmit, change) },
            transmit.observe(\.txMonitorPanCw, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.cwChange(transmit, change) }
        ]
    }
    
    /// Remove all bservations
    ///
    func removeObservations() {
        // invalidate Radio observation
        _transmitObservations.forEach { $0.invalidate() }
        
        // remove the tokens
        _transmitObservations.removeAll()
    }
    
    /// Update all control values
    ///
    /// - Parameter eq:               the Transmit
    ///
    private func cwChange(_ transmit: Transmit, _ change: Any) {
        
        DispatchQueue.main.async { [weak self] in
            self?._breakInButton.boolState = transmit.cwBreakInEnabled
            self?._delaySlider.integerValue = transmit.cwBreakInDelay
            self?._delayTextfield.integerValue = transmit.cwBreakInDelay
            self?._iambicButton.boolState = transmit.cwIambicEnabled
            self?._pitchStepper.integerValue = transmit.cwPitch
            self?._pitchTextfield.integerValue = transmit.cwPitch
            self?._sidetoneButton.boolState = transmit.cwSidetoneEnabled
            self?._sidetoneLevelSlider.integerValue = transmit.txMonitorGainCw
            self?._sidetonePanSlider.integerValue = transmit.txMonitorPanCw
            self?._sidetoneLevelTextfield.integerValue = transmit.txMonitorGainCw
            self?._speedSlider.integerValue = transmit.cwSpeed
            self?._speedTextfield.integerValue = transmit.cwSpeed
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    /// Add subsciptions to Notifications
    ///
    private func addNotifications() {
        NCtr.makeObserver(self, with: #selector(cwMeterUpdated(_:)), of: .cwMeterUpdated)
        NCtr.makeObserver(self, with: #selector(radioHasBeenAdded(_:)), of: .radioHasBeenAdded)
        NCtr.makeObserver(self, with: #selector(radioWillBeRemoved(_:)), of: .radioWillBeRemoved)
    }
    
    /// Respond to a change in a Meter
    ///
    /// - Parameters:
    ///   - note:                 a Notification
    ///
    @objc private func cwMeterUpdated(_ note: Notification) {
        
        if let meter = note.object as? Meter {
            
            DispatchQueue.main.async { [weak self] in
                // update the appropriate field
                switch meter.name {
                
                case Meter.ShortName.voltageHwAlc.rawValue:
                    DispatchQueue.main.async { [weak self] in  self?._alcLevelIndicator.level = CGFloat(meter.value) }
                    
                default:
                    break
                }
            }
        }
    }
    
    @objc private func radioHasBeenAdded(_ note: Notification) {
        if let radio = note.object as? Radio, let transmit = radio.transmit {
            addTransmitObservations(with: transmit)
            setTransmitStatus(status: true)
        }
    }
    
    @objc private func radioWillBeRemoved(_ note: Notification) {
        removeObservations()
        setTransmitStatus(status: false)
    }
}
