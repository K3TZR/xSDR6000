//
//  AntennaViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 1/7/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class AntennaViewController: NSViewController, NSPopoverDelegate {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var _rxAntPopUp    : NSPopUpButton!
    @IBOutlet private weak var _loopAButton   : NSButton!
    @IBOutlet private weak var _rfGainSlider  : NSSlider!
    
    private var _inUse                        = false
    private var _isDetached                   = false
    private var _params                       : Params!
    private var _timer                        : DispatchSourceTimer!
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch Api.sharedInstance.radio!.radioType {
        
        case .flex6300:             _rfGainSlider.minValue = 0    ; _rfGainSlider.maxValue = 20 ; _rfGainSlider.numberOfTickMarks = 3
        case .flex6400, .flex6400m: _rfGainSlider.minValue = -8   ; _rfGainSlider.maxValue = 32 ; _rfGainSlider.numberOfTickMarks = 6
        case .flex6500:             _rfGainSlider.minValue = -10  ; _rfGainSlider.maxValue = 20 ; _rfGainSlider.numberOfTickMarks = 4
        case .flex6600, .flex6600m: _rfGainSlider.minValue = -8   ; _rfGainSlider.maxValue = 32 ; _rfGainSlider.numberOfTickMarks = 6
        case .flex6700:             _rfGainSlider.minValue = -10  ; _rfGainSlider.maxValue = 40 ; _rfGainSlider.numberOfTickMarks = 6
        case .none:                 _rfGainSlider.minValue = 0    ; _rfGainSlider.maxValue = 20 ; _rfGainSlider.numberOfTickMarks = 3
        }
        _rxAntPopUp.addItems(withTitles: _params.panadapter.antList)
        
        addObservations()
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
    
    @IBAction func loopAButton(_ sender: NSButton) {
        _params.panadapter.loopAEnabled = sender.boolState
        _inUse = true
    }
    
    @IBAction func rxAntPopUp(_ sender: NSPopUpButton) {
        _params.panadapter.rxAnt = sender.titleOfSelectedItem!
        _inUse = true
    }
    
    @IBAction func rfGainSlider(_ sender: NSSlider) {
        _params.panadapter.rfGain = sender.integerValue
        _inUse = true
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    private var _observations                 = [NSKeyValueObservation]()
    
    /// Add observations of various properties used by the view
    ///
    private func addObservations() {
        
        _observations = [
            _params.panadapter.observe(\.rxAnt, options: [.initial, .new]) { [weak self] (object, change) in
                self?.changeHandler(object, change) },
            
            _params.panadapter.observe(\.loopAEnabled, options: [.initial, .new]) { [weak self] (object, change) in
                self?.changeHandler(object, change) },
            
            _params.panadapter.observe(\.rfGain, options: [.initial, .new]) { [weak self] (object, change) in
                self?.changeHandler(object, change) }
        ]
    }
    /// Process observations
    ///
    /// - Parameters:
    ///   - slice:                    the slice being observed
    ///   - change:                   the change
    ///
    private func changeHandler(_ panadapter: Panadapter, _ change: Any) {
        
        DispatchQueue.main.async { [weak self] in
            self?._rxAntPopUp.selectItem(withTitle: panadapter.rxAnt)
            self?._loopAButton.boolState = panadapter.loopAEnabled
            self?._rfGainSlider.integerValue = panadapter.rfGain
        }
    }
}
