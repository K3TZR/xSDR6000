//
//  DisplayViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 1/7/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

final class DisplayViewController: NSViewController, NSPopoverDelegate {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var _averageSlider           : NSSlider!
    @IBOutlet private weak var _averageTextField        : NSTextField!
    @IBOutlet private weak var _framesSlider            : NSSlider!
    @IBOutlet private weak var _framesTextField         : NSTextField!
    @IBOutlet private weak var _fillSlider              : NSSlider!
    @IBOutlet private weak var _fillTextField           : NSTextField!
    
    @IBOutlet private weak var _weightedAverageCheckbox : NSButton!
    
    @IBOutlet private weak var _colorGainSlider         : NSSlider!
    @IBOutlet private weak var _colorGainTextField      : NSTextField!
    @IBOutlet private weak var _blackLevelSlider        : NSSlider!
    @IBOutlet private weak var _blackLevelTextField     : NSTextField!
    @IBOutlet private weak var _lineDurationSlider      : NSSlider!
    @IBOutlet private weak var _lineDurationTextField   : NSTextField!
    
    @IBOutlet private weak var _autoBlackCheckbox       : NSButton!
    
    @IBOutlet private weak var _gradientPopUp           : NSPopUpButton!
    
    private var _params                                 : Params!
    private var _inUse                                  = false
    private var _isDetached                             = false
    private var _timer                                  : DispatchSourceTimer!
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _gradientPopUp.addItems(withTitles: WaterfallViewController.gradientNames)
        
        _fillSlider.integerValue = Defaults.spectrumFillLevel
        _fillTextField.integerValue = Defaults.spectrumFillLevel
        
        // start observing
        addObservations()
        
        // start the timer
        startTimer()
    }
    
    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        _isDetached = true
        return true
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    func configure(params: Params) {
        _params = params
    }
    
    func startTimer() {
        // create and schedule a timer
        _timer = DispatchSource.makeTimerSource(flags: [])
        _timer.schedule(deadline: DispatchTime.now() + 5, repeating: .seconds(3), leeway: .seconds(1))
        _timer.setEventHandler { [ unowned self] in
            // dismiss if not detached or not in use
            if !self._isDetached {
                if self._inUse {
                    self._inUse = false
                } else {
                    DispatchQueue.main.async { self.dismiss(nil) }
                }
            }
        }
        // start the timer
        _timer.resume()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    @IBAction func gradientPopUp(_ sender: NSPopUpButton) {
        
        _params.waterfall.gradientIndex = sender.indexOfSelectedItem
        _inUse = true
    }
    
    @IBAction func sliders(_ sender: NSSlider) {
        
        switch sender.identifier!.rawValue {
        case "average":
            _params.panadapter.average = sender.integerValue
        case "frames":
            _params.panadapter.fps = sender.integerValue
        case "fill":
            _params.panadapter.fillLevel = sender.integerValue
            Defaults.spectrumFillLevel = sender.integerValue
        case "colorGain":
            _params.waterfall.colorGain = sender.integerValue
        case "blackLevel":
            _params.waterfall.blackLevel = sender.integerValue
        case "lineDuration":
            _params.waterfall.lineDuration = sender.integerValue
        default:
            fatalError()
        }
        _inUse = true
    }
    
    @IBAction func checkBoxes(_ sender: NSButton) {
        
        switch sender.identifier!.rawValue {
        case "weightedAverage":
            _params.panadapter.weightedAverageEnabled = sender.boolState
        case "autoBlack":
            _params.waterfall.autoBlackEnabled = sender.boolState
        default:
            fatalError()
        }
        _inUse = true
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    private var _observations                           = [NSKeyValueObservation]()
    private var _defaultsObservations                   = [DefaultsDisposable]()
    
    private func addObservations() {
        
        _observations = [
            _params.panadapter.observe(\.average, options: [.initial, .new]) { [weak self] (object, change) in
                self?.changeHandler(object, change) },
            _params.panadapter.observe(\.fps, options: [.initial, .new]) { [weak self] (object, change) in
                self?.changeHandler(object, change) },
            _params.panadapter.observe(\.fillLevel, options: [.initial, .new]) { [weak self] (object, change) in
                self?.changeHandler(object, change) },
            _params.panadapter.observe(\.weightedAverageEnabled, options: [.initial, .new]) { [weak self] (object, change) in
                self?.changeHandler(object, change) },
            _params.waterfall.observe(\.colorGain, options: [.initial, .new]) { [weak self] (object, change) in
                self?.changeHandler(object, change) },
            _params.waterfall.observe(\.blackLevel, options: [.initial, .new]) { [weak self] (object, change) in
                self?.changeHandler(object, change) },
            _params.waterfall.observe(\.lineDuration, options: [.initial, .new]) { [weak self] (object, change) in
                self?.changeHandler(object, change) },
            _params.waterfall.observe(\.autoBlackEnabled, options: [.initial, .new]) { [weak self] (object, change) in
                self?.changeHandler(object, change) },      
            _params.waterfall.observe(\.gradientIndex, options: [.initial, .new]) { [weak self] (object, change) in
                self?.changeHandler(object, change) }
        ]
        
        _defaultsObservations = [
            Defaults.observe(\.spectrumFillLevel, options: [.initial, .new]) { [weak self] _ in
                self?.defaultsHandler() }
        ]
        
    }
    /// Process observations
    ///
    /// - Parameters:
    ///   - slice:                    the object being observed
    ///   - change:                   the change
    ///
    private func changeHandler(_ object: Any, _ change: Any) {
        
        DispatchQueue.main.async { [weak self] in
            
            if let panadapter = object as? Panadapter {
                self?._averageSlider.integerValue = panadapter.average
                self?._averageTextField.integerValue = panadapter.average
                
                self?._framesSlider.integerValue = panadapter.fps
                self?._framesTextField.integerValue = panadapter.fps
                
                self?._framesSlider.integerValue = panadapter.fps
                self?._framesTextField.integerValue = panadapter.fps
                
                self?._fillSlider.integerValue = panadapter.fillLevel
                self?._fillTextField.integerValue = panadapter.fillLevel
                
                self?._weightedAverageCheckbox.boolState = panadapter.weightedAverageEnabled
                
            } else if let waterfall = object as? Waterfall {
                
                self?._colorGainSlider.integerValue = waterfall.colorGain
                self?._colorGainTextField.integerValue = waterfall.colorGain
                
                self?._blackLevelSlider.integerValue = waterfall.blackLevel
                self?._blackLevelTextField.integerValue = waterfall.blackLevel
                
                self?._lineDurationSlider.integerValue = waterfall.lineDuration
                self?._lineDurationTextField.integerValue = waterfall.lineDuration
                
                self?._autoBlackCheckbox.boolState = waterfall.autoBlackEnabled
                
                self?._gradientPopUp.selectItem(at: waterfall.gradientIndex)
            }
        }
    }
    /// Process observations
    ///
    /// - Parameters:
    ///   - slice:                    the object being observed
    ///   - change:                   the change
    ///
    private func defaultsHandler() {
        
        DispatchQueue.main.async { [weak self] in
            
            self?._fillSlider.integerValue = Defaults.spectrumFillLevel
            self?._fillTextField.integerValue = Defaults.spectrumFillLevel
        }
    }
}
