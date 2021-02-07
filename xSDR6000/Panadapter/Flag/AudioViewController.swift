//
//  AudioViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 1/7/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

final class AudioViewController: NSViewController {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var _audioMuteButton       : NSButton!
    @IBOutlet private weak var _agcModePopUp          : NSPopUpButton!
    @IBOutlet private weak var _audioGainSlider       : NSSlider!
    @IBOutlet private weak var _audioPanSlider        : NSSlider!
    @IBOutlet private weak var _agcThresholdSlider    : NSSlider!
    
    @IBOutlet private weak var _audioGainTextField    : NSTextField!
    @IBOutlet private weak var _agcThresholdTextField : NSTextField!
    
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
        // populate the choices
        _agcModePopUp.addItems(withTitles: xLib6000.Slice.AgcMode.allCases.map {$0.rawValue})
        
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
    
    /// Respond to the Mute button
    ///
    /// - Parameter sender:         the button
    ///
    @IBAction func audioMuteButton(_ sender: NSButton) {
        _slice?.audioMute = sender.boolState
    }
    
    /// Respond to the AGC Mode popup
    ///
    /// - Parameter sender:         the popup
    ///
    @IBAction func agcModeButton(_ sender: NSPopUpButton) {
        _slice?.agcMode = sender.titleOfSelectedItem!
    }
    
    /// Respond to one of the sliders
    ///
    /// - Parameter sender:         the slider
    ///
    @IBAction func sliders(_ sender: NSSlider) {
        
        switch sender.identifier!.rawValue {
        
        case "audioGain":   _slice?.audioGain = sender.integerValue
        case "audioPan":    _slice?.audioPan = sender.integerValue
        case "agcThreshold":
            if _slice?.agcMode.lowercased() == "off" {
                _slice?.agcOffLevel = sender.integerValue
            } else {
                _slice?.agcThreshold = sender.integerValue
            }
        default: fatalError()
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    /// Add observations of various properties used by the view
    ///
    private func addObservations() {
        if let slice = _slice {
            _observations = [
                slice.observe(\.audioGain, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change) },
                slice.observe(\.audioPan, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change) },
                slice.observe(\.agcThreshold, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change) },
                slice.observe(\.agcOffLevel, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change) },
                slice.observe(\.audioMute, options: [.initial, .new]) { [weak self] (slice, change) in
                    self?.changeHandler(slice, change) },
                slice.observe(\.agcMode, options: [.initial, .new]) { [weak self] (slice, change) in
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
            self?._audioMuteButton.boolState = slice.audioMute
            self?._audioGainSlider.integerValue = slice.audioGain
            self?._audioGainTextField.integerValue = slice.audioGain
            self?._audioPanSlider.integerValue = slice.audioPan
            self?._agcModePopUp.selectItem(withTitle: slice.agcMode)
            if slice.agcMode.lowercased() == "off" {
                self?._agcThresholdSlider.integerValue = slice.agcOffLevel
                self?._agcThresholdTextField.integerValue = slice.agcOffLevel
            } else {
                self?._agcThresholdSlider.integerValue = slice.agcThreshold
                self?._agcThresholdTextField.integerValue = slice.agcThreshold
            }
        }
    }
}
