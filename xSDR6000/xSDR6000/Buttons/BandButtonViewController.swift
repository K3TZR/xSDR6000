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

  private var _isDetached                     = false
  private var buttons                         : [NSButton] {
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
  
  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    var bandTitle = (representedObject as! Panadapter).band
    switch bandTitle {
    case "33":
      bandTitle = "WWV"
    case "34":
      bandTitle = "GEN"
    default:
      break
    }
    // load the button titles
    if _hfPanel.contains(bandTitle) { loadButtons(_hfPanel) }
    if _xvtrPanel.contains(bandTitle) { loadButtons(_xvtrPanel) }
    
    // handle the special cases
    // highlight the current band button
    for button in buttons {
      button.boolState = (bandTitle == button.title)
    }
    // start the timer
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(PanafallButtonViewController.kTimeout)) {
      if !self._isDetached { self.dismiss(nil) }
    }
  }
  
  func popoverShouldDetach(_ popover: NSPopover) -> Bool {
    _isDetached = true
    return true
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  @IBAction func buttonPush(_ sender: NSButton) {
    var band = sender.title
    
    for button in buttons {
      button.boolState = (button == sender && sender.boolState)
    }
    
    // handle the special cases
    switch  band {
      
    case "WWV":
      band = "33"
      
    case "GEN":
      band = "34"
      
    case "XVTR":
      loadAndSetButtons(_xvtrPanel)
      return
      
    case "HF":
      loadAndSetButtons(_hfPanel)
      return

    case "":
      return
      
    default:
      break
    }
    // tell the Panadapter
    (representedObject as! Panadapter).band = band
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  private func loadButtons(_ titles: [String]) {
    
    for(i, button) in buttons.enumerated() {
      button.title = titles[i]
    }
  }
  private func loadAndSetButtons(_ titles: [String]) {
    
    loadButtons(titles)
    
    for button in buttons {
      button.boolState = (representedObject as! Panadapter).band == button.title
    }
  }
}
