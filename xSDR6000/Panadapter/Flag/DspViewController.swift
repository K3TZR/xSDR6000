//
//  DspViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 1/7/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

final class DspViewController: NSViewController {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var _wnbButton     : NSButton!
    @IBOutlet private weak var _nbButton      : NSButton!
    @IBOutlet private weak var _nrButton      : NSButton!
    @IBOutlet private weak var _anfButton     : NSButton!
    @IBOutlet private weak var _wnbSlider     : NSSlider!
    @IBOutlet private weak var _nbSlider      : NSSlider!
    @IBOutlet private weak var _nrSlider      : NSSlider!
    @IBOutlet private weak var _anfSlider     : NSSlider!
    
    @IBOutlet private weak var _wnbTextField  : NSTextField!
    @IBOutlet private weak var _nbTextField   : NSTextField!
    @IBOutlet private weak var _nrTextField   : NSTextField!
    @IBOutlet private weak var _anfTextField  : NSTextField!
    
    private var _slice                        : xLib6000.Slice? {
        return representedObject as? xLib6000.Slice }
    
    private var _observations                 = [NSKeyValueObservation]()
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        if Defaults.flagBorderEnabled {
            view.layer?.borderColor = NSColor.darkGray.cgColor
            view.layer?.borderWidth = 0.5
        }
        // start observing
        addObservations()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // set the background color of the Flag
        view.layer?.backgroundColor = ControlsViewController.kBackgroundColor
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    /// Respond to one of the buttons
    ///
    /// - Parameter sender:         the button
    ///
    @IBAction func buttons(_ sender: NSButton) {
        
        switch sender.identifier!.rawValue {
        case "wnbButton":
            _slice?.wnbEnabled = sender.boolState
        case "nbButton":
            _slice?.nbEnabled = sender.boolState
        case "nrButton":
            _slice?.nrEnabled = sender.boolState
        case "anfButton":
            if _slice?.mode == "USB" || _slice?.mode == "LSB" {
                _slice?.anfEnabled = sender.boolState
            } else if _slice?.mode == "CW" {
                _slice?.apfEnabled = sender.boolState
            }
        default:
            fatalError()
        }
    }
    /// Respond to one of the sliders
    ///
    /// - Parameter sender:         the slider
    ///
    @IBAction func sliders(_ sender: NSSlider) {
        
        switch sender.identifier!.rawValue {
        case "wnbSlider":
            _slice?.wnbLevel = sender.integerValue
        case "nbSlider":
            _slice?.nbLevel = sender.integerValue
        case "nrSlider":
            _slice?.nrLevel = sender.integerValue
        case "anfSlider":
            if _slice?.mode == "USB" || _slice?.mode == "LSB" {
                _slice?.anfLevel = sender.integerValue
            } else if _slice?.mode == "CW" {
                _slice?.apfLevel = sender.integerValue
            }
        default:
            fatalError()
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    /// Add observations of various properties used by the view
    ///
    private func addObservations() {
        if let slice = _slice {
            _observations = [
                slice.observe(\.mode, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change) },
                
                slice.observe(\.wnbEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change) },
                
                slice.observe(\.nbEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change)},
                
                slice.observe(\.nrEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change) },
                
                slice.observe(\.anfEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change) },
                
                slice.observe(\.apfEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change) },
                
                slice.observe(\.wnbLevel, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change) },
                
                slice.observe(\.nbLevel, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change) },
                
                slice.observe(\.nrLevel, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change) },
                
                slice.observe(\.anfLevel, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change) },
                
                slice.observe(\.apfLevel, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change) }
            ]
        }
    }
    /// Process observations
    ///
    /// - Parameters:
    ///   - slice:                    the slice being observed
    ///   - change:                   the change
    ///
    private func changeHandler(_ slice: xLib6000.Slice, _ change: Any) {
        
        DispatchQueue.main.async { [weak self] in
            
            switch slice.mode {
            case "USB", "LSB":
                self?._anfButton.isEnabled = true
                self?._anfSlider.isEnabled = true
                self?._anfButton.title = "ANF"
                self?._anfButton.boolState = slice.anfEnabled
                self?._anfSlider.integerValue = slice.anfLevel
                self?._anfTextField.integerValue = slice.anfLevel
            case "CW":
                self?._anfButton.isEnabled = true
                self?._anfSlider.isEnabled = true
                self?._anfButton.title = "APF"
                self?._anfButton.boolState = slice.apfEnabled
                self?._anfSlider.integerValue = slice.apfLevel
                self?._anfTextField.integerValue = slice.apfLevel
            default:
                self?._anfButton.isEnabled = false
                self?._anfSlider.isEnabled = false
                self?._anfButton.title = "---"
                self?._anfSlider.integerValue = 0
                self?._anfTextField.stringValue = "---"
            }
            self?._wnbButton.boolState = slice.wnbEnabled
            self?._nbButton.boolState = slice.nbEnabled
            self?._nrButton.boolState = slice.nrEnabled
            
            self?._wnbSlider.integerValue = slice.wnbLevel
            self?._nbSlider.integerValue = slice.nbLevel
            self?._nrSlider.integerValue = slice.nrLevel
            
            self?._wnbTextField.integerValue = slice.wnbLevel
            self?._nbTextField.integerValue = slice.nbLevel
            self?._nrTextField.integerValue = slice.nrLevel
        }
    }
}
