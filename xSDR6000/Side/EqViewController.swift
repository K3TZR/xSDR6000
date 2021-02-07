//
//  EqViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/1/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - Radio View Controller class implementation
// --------------------------------------------------------------------------------

final class EqViewController: NSViewController {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var onButton       : NSButton!
    @IBOutlet private weak var rxButton       : NSButton!
    @IBOutlet private weak var txButton       : NSButton!
    @IBOutlet private weak var slider0        : NSSlider!
    @IBOutlet private weak var slider1        : NSSlider!
    @IBOutlet private weak var slider2        : NSSlider!
    @IBOutlet private weak var slider3        : NSSlider!
    @IBOutlet private weak var slider4        : NSSlider!
    @IBOutlet private weak var slider5        : NSSlider!
    @IBOutlet private weak var slider6        : NSSlider!
    @IBOutlet private weak var slider7        : NSSlider!
    
    private var _radio                        : Radio? { Api.sharedInstance.radio }
    
    private var _equalizerRx                  : Equalizer?
    private var _equalizerTx                  : Equalizer?
    private var _currentEqualizer             : Equalizer?
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overriden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()        
        view.translatesAutoresizingMaskIntoConstraints = false
                
        // check if a radio is connected
        if let radio = _radio { setupObservations(with: radio) }

        addNotifications()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    /// Respond to the buttons
    ///
    /// - Parameter sender:           the button
    ///
    @IBAction func buttons(_ sender: NSButton) {
        switch sender.identifier!.rawValue {
        
        case "EqOn":    _currentEqualizer?.eqEnabled = onButton.boolState
        case "EqRx":    _currentEqualizer = _equalizerRx ; Defaults.eqRxSelected = sender.boolState
        case "EqTx":    _currentEqualizer = _equalizerTx ; Defaults.eqRxSelected = !sender.boolState
        default:        fatalError()
        }
        // populate the controls of the selected Equalizer
        if _currentEqualizer != nil { eqChange( _currentEqualizer!, 0) }
    }
    /// Respond to changes in a slider value
    ///
    /// - Parameter sender:           the slider
    ///
    @IBAction func sliders(_ sender: NSSlider) {
        if let equ = _currentEqualizer {
            // tell the Radio to change the Eq setting
            switch sender.identifier!.rawValue {
            
            case "Level63Hz":   equ.level63Hz = sender.integerValue
            case "Level125Hz":  equ.level125Hz = sender.integerValue
            case "Level250Hz":  equ.level250Hz = sender.integerValue
            case "Level500Hz":  equ.level500Hz = sender.integerValue
            case "Level1000Hz": equ.level1000Hz = sender.integerValue
            case "Level2000Hz": equ.level2000Hz = sender.integerValue
            case "Level4000Hz": equ.level4000Hz = sender.integerValue
            case "Level8000Hz": equ.level8000Hz = sender.integerValue
            default:            fatalError()
            }
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    private func setStatus(status: Bool) {
        DispatchQueue.main.async { [self] in
            onButton.isEnabled  = status
            rxButton.isEnabled  = status
            txButton.isEnabled  = status
            slider0.isEnabled   = status
            slider1.isEnabled   = status
            slider2.isEnabled   = status
            slider3.isEnabled   = status
            slider4.isEnabled   = status
            slider5.isEnabled   = status
            slider6.isEnabled   = status
            slider7.isEnabled   = status
        }
    }

    private func setupObservations(with radio: Radio) {
        // get a reference to each equalizer
        _equalizerRx = radio.equalizers[.rxsc]!
        _equalizerTx = radio.equalizers[.txsc]!
        
        // save a reference to the selected Equalizer
        _currentEqualizer = (Defaults.eqRxSelected ? _equalizerRx : _equalizerTx)
        addObservations()
        setStatus(status: true)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    private var _observations                 = [NSKeyValueObservation]()
    
    /// Add observations of parameters
    ///
    private func addObservations() {
        if let rxEq = _equalizerRx {
            // Rx Equalizer parameters
            _observations.append( rxEq.observe(\.level63Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( rxEq.observe(\.level125Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( rxEq.observe(\.level250Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( rxEq.observe(\.level500Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( rxEq.observe(\.level1000Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( rxEq.observe(\.level2000Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( rxEq.observe(\.level4000Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( rxEq.observe(\.level8000Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( rxEq.observe(\.eqEnabled, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
        }
        
        if let txEq = _equalizerTx {
            // Tx Equalizer parameters
            _observations.append( txEq.observe(\.level63Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( txEq.observe(\.level125Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( txEq.observe(\.level250Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( txEq.observe(\.level500Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( txEq.observe(\.level1000Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( txEq.observe(\.level2000Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( txEq.observe(\.level4000Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( txEq.observe(\.level8000Hz, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
            _observations.append( txEq.observe(\.eqEnabled, options: [.initial, .new]) { [weak self] (equalizer, change) in
                                    self?.eqChange(equalizer, change) })
        }
    }    
    
    /// Remove oall bservations
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
    ///   - object:                       an Equalizer
    ///   - change:                       the change
    ///
    private func eqChange(_ equalizer: Equalizer, _ change: Any) {
        
        // update the Equalizer if currently displayed
        if equalizer == _currentEqualizer {
            
            DispatchQueue.main.async { [weak self] in
                
                // enable the appropriate Equalizer
                self?.rxButton.boolState = Defaults.eqRxSelected
                self?.txButton.boolState = !Defaults.eqRxSelected
                
                // set the ON button state
                self?.onButton.boolState = equalizer.eqEnabled
                
                // set the slider values
                self?.slider0.integerValue = equalizer.level63Hz
                self?.slider1.integerValue = equalizer.level125Hz
                self?.slider2.integerValue = equalizer.level250Hz
                self?.slider3.integerValue = equalizer.level500Hz
                self?.slider4.integerValue = equalizer.level1000Hz
                self?.slider5.integerValue = equalizer.level2000Hz
                self?.slider6.integerValue = equalizer.level4000Hz
                self?.slider7.integerValue = equalizer.level8000Hz
            }
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
        if let radio = note.object as? Radio {
            setupObservations(with: radio)
        }
    }
    
    @objc private func radioWillBeRemoved(_ note: Notification) {
        removeObservations()
        setStatus(status: false)
    }
}
