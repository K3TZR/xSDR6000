//
//  ModeViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/9/18.
//  Copyright © 2018 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - Mode View Controller class implementation
// --------------------------------------------------------------------------------

final class ModeViewController       : NSViewController {

  static let filterValues    = [                              // Values of filters (by mode)
    "AM"    : [3_000, 4_000, 5_600, 6_000, 8_000, 10_000, 12_000, 14_000, 16_000, 20_000],
    "SAM"   : [3_000, 4_000, 5_600, 6_000, 8_000, 10_000, 12_000, 14_000, 16_000, 20_000],
    "CW"    : [50, 75, 100, 150, 250, 400, 800, 1_000, 1_500, 3_000],
    "USB"   : [1_200, 1_400, 1_600, 1_800, 2_100, 2_400, 2_700, 2_900, 3_300, 4_000],
    "LSB"   : [1_200, 1_400, 1_600, 1_800, 2_100, 2_400, 2_700, 2_900, 3_300, 4_000],
    "FM"    : [],
    "NFM"   : [],
    "DFM"   : [3_000, 4_000, 6_000, 8_000, 10_000, 12_000, 14_000, 16_000, 18_000, 20_000],
    "DIGU"  : [100, 200, 300, 400, 600, 1_000, 1_500, 2_000, 3_000, 5_000],
    "DIGL"  : [100, 200, 300, 400, 600, 1_000, 1_500, 2_000, 3_000, 5_000],
    "RTTY"  : [250, 300, 350, 400, 450, 500, 750, 1_000, 1_500, 3_000]
  ]

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _modePopUp     : NSPopUpButton!
  @IBOutlet private weak var _quickMode0    : NSButton!
  @IBOutlet private weak var _quickMode1    : NSButton!
  @IBOutlet private weak var _quickMode2    : NSButton!
  @IBOutlet private weak var _quickMode3    : NSButton!

  @IBOutlet private weak var _filter0       : NSButton!
  @IBOutlet private weak var _filter1       : NSButton!
  @IBOutlet private weak var _filter2       : NSButton!
  @IBOutlet private weak var _filter3       : NSButton!
  @IBOutlet private weak var _filter4       : NSButton!
  @IBOutlet private weak var _filter5       : NSButton!
  @IBOutlet private weak var _filter6       : NSButton!
  @IBOutlet private weak var _filter7       : NSButton!
  @IBOutlet private weak var _filter8       : NSButton!
  @IBOutlet private weak var _filter9       : NSButton!
  
  private var _slice                        : xLib6000.Slice {
    return representedObject as! xLib6000.Slice }

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
    _modePopUp.addItems(withTitles: xLib6000.Slice.Mode.allCases.map {$0.rawValue} )
    
    // populate the Quick Mode buttons
    _quickMode0.title = _slice.modeList.contains(Defaults.quickMode0.uppercased()) ? Defaults.quickMode0.uppercased() : "??"
    _quickMode1.title = _slice.modeList.contains(Defaults.quickMode1.uppercased()) ? Defaults.quickMode1.uppercased() : "??"
    _quickMode2.title = _slice.modeList.contains(Defaults.quickMode2.uppercased()) ? Defaults.quickMode2.uppercased() : "??"
    _quickMode3.title = _slice.modeList.contains(Defaults.quickMode3.uppercased()) ? Defaults.quickMode3.uppercased() : "??"

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

  @IBAction func filterButtons(_ sender: NSButton) {
    
    // get the possible filters for the current mode
    guard let filters = ModeViewController.filterValues[ _slice.mode] else { return }
    
    // get the width of the filter
    let filterValue = filters[sender.tag]
    
    // position the filter based on mode
    setFilterWidth(filterValue, forMode: _slice.mode, andSlice: _slice)
  }

  @IBAction func modePopUp(_ sender: NSPopUpButton) {
    _slice.mode = sender.titleOfSelectedItem!
  }

  @IBAction func quickModeButtons(_ sender: NSButton) {
    
    if _slice.modeList.contains(sender.title.uppercased()) {
      _slice.mode = sender.title
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods

  /// Calculate the filter values for a given mode
  /// - Parameters:
  ///   - width: the overall width
  ///   - mode: the mode string
  ///   - slice: a Slice reference
  ///
  private func setFilterWidth(_ width: Int, forMode mode: String, andSlice slice: xLib6000.Slice) {
    
    var hiCut = 0
    var loCut = 0
    
    switch mode {
    case "CW", "CWL", "CWU", "AM", "SAM":
      loCut = -1 * width / 2
      hiCut = +1 * width / 2
    case "LSB":
      hiCut = -100
      loCut = hiCut - width
    case "USB":
      loCut = 100
      hiCut = loCut + width
    case "DIGL":
      let offset = -1 * slice.digitalLowerOffset       // offset value from the slice is a positive value!
      loCut = offset - (width / 2)
      hiCut = offset + (width / 2)
      if hiCut > 0 {
        hiCut = 0
        loCut = -1 * width
      }
    case "DIGU":
      let offset = slice.digitalUpperOffset
      loCut = offset - (width / 2)
      hiCut = offset + (width / 2)
      if loCut < 0 {
        loCut = 0
        hiCut = width
      }
    case "RTTY":
      let shift = slice.rttyShift
      let side = (width - shift) / 2
      hiCut = side
      loCut = -1 * (shift + side)
    default:
      return
    }
    slice.filterLow = loCut
    slice.filterHigh = hiCut
  }
  /// Return a list of Filter Width strings
  ///
  /// - Parameter mode:             a Mode name
  /// - Returns:                    an array of String
  ///
  private func filterStrings( for mode: String) -> [String] {
    var array = [String]()
    
    if let values = ModeViewController.filterValues[mode] {
      var formattedWidth = ""
      
      values.forEach( {
        switch $0 {
        case 1_000...:
          formattedWidth = String(format: "%2.1fk", Float($0)/1000.0)
        case 0..<1_000:
          formattedWidth = String(format: "%3d", $0)
        default:
          formattedWidth = "0"
        }
        array.append(formattedWidth)
      } )
    }
    return array
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  private var _observations         = [NSKeyValueObservation]()
  private var _defaultsObservations = [DefaultsDisposable]()

  /// Add observations of various properties used by the view
  ///
  private func addObservations() {
    
    _observations = [
      _slice.observe(\.mode, options: [.initial, .new]) { [weak self] (slice, change) in
        self?.modeChange(slice, change)
      }
    ]
  }
  /// Process observations
  ///
  /// - Parameters:
  ///   - object:                   the object being observed
  ///   - change:                   the change
  ///
  private func modeChange(_ slice: xLib6000.Slice, _ change: Any) {

    switch slice.mode {
      
    case "FM", "NFM":
      DispatchQueue.main.async { [weak self] in
        self?._filter0.title = ""
        self?._filter1.title = ""
        self?._filter2.title = ""
        self?._filter3.title = ""
        self?._filter4.title = ""
        self?._filter5.title = ""
        self?._filter6.title = ""
        self?._filter7.title = ""
        self?._filter8.title = ""
        self?._filter9.title = ""
      }
    default:
      let filterTitles = filterStrings(for: slice.mode)
      
      DispatchQueue.main.async { [weak self] in
        self?._filter0.title = filterTitles[0]
        self?._filter1.title = filterTitles[1]
        self?._filter2.title = filterTitles[2]
        self?._filter3.title = filterTitles[3]
        self?._filter4.title = filterTitles[4]
        self?._filter5.title = filterTitles[5]
        self?._filter6.title = filterTitles[6]
        self?._filter7.title = filterTitles[7]
        self?._filter8.title = filterTitles[8]
        self?._filter9.title = filterTitles[9]
      }
    }
  }
}
