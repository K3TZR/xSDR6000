//
//  PhoneViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/16/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class PhoneViewController: NSViewController {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var _biasButton          : NSButton!
    @IBOutlet private weak var _dexpButton          : NSButton!
    @IBOutlet private weak var _voxButton           : NSButton!
    @IBOutlet private weak var _metInRxButton       : NSButton!
    @IBOutlet private weak var _micBoostButton      : NSButton!
    
    @IBOutlet private weak var _carrierSlider       : NSSlider!
    @IBOutlet private weak var _voxLevelSlider      : NSSlider!
    @IBOutlet private weak var _voxDelaySlider      : NSSlider!
    @IBOutlet private weak var _dexpSlider          : NSSlider!
    @IBOutlet private weak var _txFilterLow         : NSTextField!
    @IBOutlet private weak var _txFilterLowStepper  : NSStepper!
    
    @IBOutlet private weak var _txFilterHigh        : NSTextField!
    @IBOutlet private weak var _txFilterHighStepper : NSStepper!
    
    private var _radio                        : Radio? { Api.sharedInstance.radio }
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overriden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.translatesAutoresizingMaskIntoConstraints = false        

        // check if a radio is connected
        if let radio = _radio, let transmit = radio.transmit { setupObservations(with: transmit) }

        addNotifications()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    /// Respond to one of the buttons
    ///
    /// - Parameter sender:             the button
    ///
    @IBAction func buttons(_ sender: NSButton) {
        if let radio = _radio {
            switch sender.identifier!.rawValue {
            
            case "Dexp":        radio.transmit?.companderEnabled = sender.boolState
            case "Vox":         radio.transmit?.voxEnabled = sender.boolState
            case "MicBias":     radio.transmit?.micBiasEnabled = sender.boolState
            case "MicBoost":    radio.transmit?.micBoostEnabled = sender.boolState
            case "MeterInRx":   radio.transmit?.metInRxEnabled = sender.boolState
            default:            fatalError()
            }
        }
    }
    /// Respond to one of the text fields
    ///
    /// - Parameter sender:             the textField
    ///
    @IBAction func textFields(_ sender: NSTextField) {
        if let radio = _radio {
            switch sender.identifier!.rawValue {
            
            case "TxHigh":  radio.transmit?.txFilterHigh = sender.integerValue
            case "TxLow":   radio.transmit?.txFilterLow = sender.integerValue
            default:        fatalError()
            }
        }
    }
    /// Respond to one of the steppers
    ///
    /// - Parameter sender:             the stepper
    ///
    @IBAction func steppers(_ sender: NSStepper) {
        if let radio = _radio {
            switch sender.identifier!.rawValue {
            
            case "TxHighStepper":   radio.transmit?.txFilterHigh = sender.integerValue
            case "TxLowStepper":    radio.transmit?.txFilterLow = sender.integerValue
            default:                fatalError()
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    private func setStatus(status: Bool) {
        DispatchQueue.main.async { [self] in
            _biasButton.isEnabled           = status
            _dexpButton.isEnabled           = status
            _voxButton.isEnabled            = status
            _metInRxButton.isEnabled        = status
            _micBoostButton.isEnabled       = status
            
            _carrierSlider.isEnabled        = status
            _voxLevelSlider.isEnabled       = status
            _voxDelaySlider.isEnabled       = status
            _dexpSlider.isEnabled           = status
            _txFilterLow.isEnabled          = status
            _txFilterLowStepper.isEnabled   = status
            
            _txFilterHigh.isEnabled         = status
            _txFilterHighStepper.isEnabled  = status
        }
    }
    
    private func setupObservations(with transmit: Transmit) {
        addObservations(with: transmit)
        setStatus(status: true)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    private var _observations                 = [NSKeyValueObservation]()
    
    /// Add observations of parameters
    ///
    private func addObservations(with transmit: Transmit) {
        // Transmit parameters
        _observations = [
            transmit.observe(\.carrierLevel, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.transmitChange(transmit, change) },
            transmit.observe(\.companderEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.transmitChange(transmit, change) },
            transmit.observe(\.companderLevel, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.transmitChange(transmit, change) },
            transmit.observe(\.metInRxEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.transmitChange(transmit, change) },
            transmit.observe(\.micBiasEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.transmitChange(transmit, change) },
            transmit.observe(\.micBoostEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.transmitChange(transmit, change) },
            transmit.observe(\.txFilterHigh, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.transmitChange(transmit, change) },
            transmit.observe(\.txFilterLow, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.transmitChange(transmit, change) },
            transmit.observe(\.voxDelay, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.transmitChange(transmit, change) },
            transmit.observe(\.voxEnabled, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.transmitChange(transmit, change) },
            transmit.observe(\.voxLevel, options: [.initial, .new]) { [weak self] (transmit, change) in
                self?.transmitChange(transmit, change) }
        ]
    }
    
    /// Remove all bservations
    ///
    func removeObservations() {
        // invalidate Radio observation
        _observations.forEach { $0.invalidate() }
        
        // remove the tokens
        _observations.removeAll()
    }

    /// Respond to changes in parameters
    ///
    /// - Parameters:
    ///   - object:                       a Transmit
    ///   - change:                       the change
    ///
    /// Update all control values
    ///
    /// - Parameter eq:               the Equalizer
    ///
    private func transmitChange(_ transmit: Transmit, _ change: Any) {
        
        DispatchQueue.main.async { [weak self] in
            // Buttons
            self?._biasButton.state = transmit.micBiasEnabled.state
            self?._dexpButton.state = transmit.companderEnabled.state
            self?._metInRxButton.state = transmit.metInRxEnabled.state
            self?._voxButton.state = transmit.voxEnabled.state
            self?._micBoostButton.state = transmit.micBoostEnabled.state
            
            // Sliders
            self?._carrierSlider.integerValue = transmit.carrierLevel
            self?._dexpSlider.integerValue = transmit.companderLevel
            self?._voxDelaySlider.integerValue = transmit.voxDelay
            self?._voxLevelSlider.integerValue = transmit.voxLevel
            
            // Textfields
            self?._txFilterHigh.integerValue = transmit.txFilterHigh
            self?._txFilterLow.integerValue = transmit.txFilterLow
            
            // Steppers
            self?._txFilterHighStepper.integerValue = transmit.txFilterHigh
            self?._txFilterLowStepper.integerValue = transmit.txFilterLow
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    /// Add subsciptions to Notifications
    ///
    private func addNotifications() {
        NCtr.makeObserver(self, with: #selector(radioHasBeenAdded(_:)), of: .radioHasBeenAdded)
        NCtr.makeObserver(self, with: #selector(radioWillBeRemoved(_:)), of: .radioWillBeRemoved)
    }
    
    @objc private func radioHasBeenAdded(_ note: Notification) {
        if let radio = note.object as? Radio, let transmit = radio.transmit { setupObservations(with: transmit) }
    }
    
    @objc private func radioWillBeRemoved(_ note: Notification) {
        removeObservations()
        setStatus(status: false)
    }
}
