//
//  BandButtonViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/8/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class BandButtonViewController: NSViewController, NSPopoverDelegate {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    // unfortunately, macOS does not support IBOutletCollection
    @IBOutlet private weak var _button0         : NSButton!
    @IBOutlet private weak var _button1         : NSButton!
    @IBOutlet private weak var _button2         : NSButton!
    @IBOutlet private weak var _button3         : NSButton!
    @IBOutlet private weak var _button4         : NSButton!
    @IBOutlet private weak var _button5         : NSButton!
    @IBOutlet private weak var _button6         : NSButton!
    @IBOutlet private weak var _button7         : NSButton!
    @IBOutlet private weak var _button8         : NSButton!
    @IBOutlet private weak var _button9         : NSButton!
    @IBOutlet private weak var _button10        : NSButton!
    @IBOutlet private weak var _button11        : NSButton!
    @IBOutlet private weak var _button12        : NSButton!
    @IBOutlet private weak var _button13        : NSButton!
    @IBOutlet private weak var _button14        : NSButton!
    @IBOutlet private weak var _button15        : NSButton!
    @IBOutlet private weak var _button16        : NSButton!
    @IBOutlet private weak var _button17        : NSButton!
    
    private var _inUse                          = false
    private var _isDetached                     = false
    private var _params                         : Params!
    private var _timer                          : DispatchSourceTimer!
    
    private var _buttons                        : [NSButton] {
        return
            [
                _button0, _button1, _button2,
                _button3, _button4, _button5,
                _button6, _button7, _button8,
                _button9, _button10, _button11,
                _button12, _button13, _button14,
                _button15, _button16, _button17
            ]
    }
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // load the button titles
        loadButtons( Band.hfList )
        
        // highlight the current band button
        for button in _buttons {
            button.boolState = (Int(_params.panadapter.band) == button.tag)
        }
        // start the timer
        startTimer()
    }
    
    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        _isDetached = true
        return true
    }
    
    deinit {
        
        _timer.cancel()
        _timer = nil
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
        _timer.setEventHandler { [ weak self] in
            // dismiss if not detached or not in use
            self?.close()
        }
        // start the timer
        _timer.resume()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    @IBAction func buttonPush(_ sender: NSButton) {
        if sender.tag == 0 {
            sender.boolState = false
            return
        }
        _inUse = true
        
        // handle the special cases
        switch  sender.tag {
        
        case -1:  loadAndSetButtons(Band.xvtrList) ; return
        case -2:  loadAndSetButtons(Band.hfList) ; return
        default:  break
        }
        
        // un-highlight the previous band button
        for button in _buttons {
            button.boolState = (sender.tag == button.tag)
        }
        
        // tell the Panadapter
        _params.panadapter.band = String(sender.tag, radix: 10)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    private func close() {
        if !_isDetached || !_inUse {
            _timer.cancel()
            DispatchQueue.main.async { [weak self] in
                self?.dismiss(nil)
            }
        }
    }
    
    private func loadButtons(_ bands: [(number: Int, title: String)] ) {
        
        for(i, button) in _buttons.enumerated() {
            button.title = bands[i].title
            button.tag = bands[i].number
        }
    }
    private func loadAndSetButtons(_  bands: [(number: Int, title: String)] ) {
        
        loadButtons(bands)
        
        for button in _buttons {
            button.boolState = (_params.panadapter.band == button.title)
        }
    }
}
