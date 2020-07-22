//
//  BandButtonViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/8/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class BandButtonViewController              : NSViewController, NSPopoverDelegate {

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
  private var _p                              : Params!
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
  private let _hfPanel = [
    "160", "80", "60",
    "40", "30", "20",
    "17", "15", "12",
    "10", "6", "4",
    "", "WWV", "GEN",
    "2200", "6300", "XVTR"
  ]
  
  private let _xvtrPanel =
  [
    "", "", "",
    "", "", "",
    "", "", "",
    "", "", "",
    "", "", "",
    "", "", "HF"
  ]

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    var bandTitle = _p.panadapter.band
    switch bandTitle {
    
    case "33":  bandTitle = "WWV"
    case "34":  bandTitle = "GEN"
    default:    break
    }
    // load the button titles
    if _hfPanel.contains(bandTitle) { loadButtons(_hfPanel) }
    if _xvtrPanel.contains(bandTitle) { loadButtons(_xvtrPanel) }
    
    // handle the special cases
    // highlight the current band button
    for button in _buttons {
      button.boolState = (bandTitle == button.title)
    }
    // start the timer
    startTimer()
  }
  
  func popoverShouldDetach(_ popover: NSPopover) -> Bool {
    _isDetached = true
    return true
  }
  
  deinit {
    Swift.print("----->>>>> Deinit")
    _timer.cancel()
    _timer = nil
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  func configure(params: Params) {
    _p = params
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
    var band = sender.title
    
    for button in _buttons {
      button.boolState = (button == sender && sender.boolState)
    }
    
    // handle the special cases
    switch  band {
      
    case "WWV":     band = "33"
    case "GEN":     band = "34"
    case "XVTR":    loadAndSetButtons(_xvtrPanel) ; return
    case "HF":      loadAndSetButtons(_hfPanel) ; return
    case "":        return
    default:        break
    }
    _inUse = true

    // tell the Panadapter
    _p.panadapter.band = band
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  private func close() {
    if !_isDetached || !_inUse {
      _timer.cancel()
      DispatchQueue.main.async{ [weak self] in
        self?.dismiss(nil)
      }
    }
  }
  
  private func loadButtons(_ titles: [String]) {
    
    for(i, button) in _buttons.enumerated() {
      button.title = titles[i]
    }
  }
  private func loadAndSetButtons(_ titles: [String]) {
    
    loadButtons(titles)
    
    for button in _buttons {
      button.boolState = (_p.panadapter.band == button.title)
    }
  }
}
