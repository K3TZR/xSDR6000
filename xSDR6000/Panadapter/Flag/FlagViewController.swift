//
//  FlagViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/22/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - Flag View Controller class implementation
// --------------------------------------------------------------------------------

final class FlagViewController : NSViewController, NSTextFieldDelegate, NSGestureRecognizerDelegate {

  static let maxFrequency : Double = 74.00001
  static let minFrequency : Double = 0.001001

  static let kSliceLetters                  = ["A", "B", "C", "D", "E", "F", "G", "H"]
  static let kFlagOffset                    : CGFloat = 7.5
  static let kFlagMinimumSeparation         : CGFloat = 10
  static let kLargeFlagWidth                : CGFloat = 275
  static let kLargeFlagHeight               : CGFloat = 90
  static let kSmallFlagWidth                : CGFloat = 123
  static let kSmallFlagHeight               : CGFloat = 46
  static let kFlagBorder                    : CGFloat = 20
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties

  var flagTopConstraint                     : NSLayoutConstraint?
  var flagHeightConstraint                  : NSLayoutConstraint?
  var flagWidthConstraint                   : NSLayoutConstraint?
  var flagXPositionConstraint               : NSLayoutConstraint?
  var controlsHeightConstraint              : NSLayoutConstraint?
  var smallFlagDisplayed                    = false
  var isOnLeft                              = true
  var controlsVc                            : ControlsViewController?
  var splitId                               : ObjectId?
  var isaSplit                              = false {
    didSet {DispatchQueue.main.async { [weak self] in self?._splitButton.isEnabled = !self!.isaSplit }}
  }

  @objc dynamic public var slice            : xLib6000.Slice!

    
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _alphaButton   : NSButton!
  @IBOutlet private weak var _filterWidth   : NSTextField!
  @IBOutlet private weak var _rxAntPopUp    : NSPopUpButton!
  @IBOutlet private weak var _txAntPopUp    : NSPopUpButton!
  
  @IBOutlet private weak var _lockButton    : NSButton!
  @IBOutlet private weak var _nbButton      : NSButton!
  @IBOutlet private weak var _nrButton      : NSButton!
  @IBOutlet private weak var _anfButton     : NSButton!
  @IBOutlet private weak var _qskButton     : NSButton!
  @IBOutlet private weak var _splitButton   : NSButton!
  
  @IBOutlet private var _frequencyField     : NSTextField!
  @IBOutlet private var _sMeter             : LevelIndicator!
  @IBOutlet private var _sLevel             : NSTextField!
 
  @IBOutlet private var _audButton          : NSButton!
  @IBOutlet private var _dspButton          : NSButton!
  @IBOutlet private var _modeButton         : NSButton!
  @IBOutlet private var _xritButton         : NSButton!
  @IBOutlet private var _daxButton          : NSButton!
  @IBOutlet private var _txButton           : NSButton!
  
  private weak var _panadapter              : Panadapter?
  private weak var _vc                      : NSViewController?

  private weak var _radio                   = Api.sharedInstance.radio
  private var _center                       : Int {return _panadapter!.center }
  private var _bandwidth                    : Int { return _panadapter!.bandwidth }
  private var _start                        : Int { return _center - (_bandwidth/2) }
  private var _end                          : Int  { return _center + (_bandwidth/2) }
  private var _hzPerUnit                    : CGFloat { return CGFloat(_end - _start) / _panadapter!.xPixels }
  
  private var _previousFrequency            = 0
  private var _beginEditing                 = false
  private var _darkMode                     = false

  private let _log                          = Logger.sharedInstance

  private let kFlagPixelOffset              : CGFloat = 15.0/2.0

  private let kSplitCaption                 = "SPLIT"
  private let kSplitOnAttr                  = [NSAttributedString.Key.foregroundColor : NSColor.systemRed]
  private let kSplitOffAttr                 = [NSAttributedString.Key.foregroundColor : NSColor.lightGray]

  private let kLetterAttr                   = [NSAttributedString.Key.foregroundColor : NSColor.systemYellow]

  private let kTxCaption                    = "TX"
  private let kTxOnAttr                     = [NSAttributedString.Key.foregroundColor : NSColor.systemRed]
  private let kTxOffAttr                    = [NSAttributedString.Key.foregroundColor : NSColor.lightGray]
  
  private let kSplitDistance                = 5_000
  
  // ----------------------------------------------------------------------------
  // MARK: - Class methods
  
  /// Create a Flag for the specified Slice
  ///
  /// - Parameters:
  ///   - slice:                  a Slice
  ///   - pan:                    the Slice's Panadapter
  ///   - viewController:         the parent ViewController
  /// - Returns:                  a FlagViewController
  ///
  class func createFlag(for slice: xLib6000.Slice, and pan: Panadapter, on viewController: NSViewController) -> FlagViewController {
    
    // get the Storyboard containing a Flag View Controller
    let sb = NSStoryboard(name: "Flag", bundle: nil)
    
    // create a Flag View Controller & pass it needed parameters
    let flagVc = sb.instantiateController(withIdentifier: "Flag") as! FlagViewController
    
    // create a Controls View Controller & pass it needed parameters
    let controlsVc = sb.instantiateController(withIdentifier: "Controls") as! ControlsViewController
    
    // pass the FlagVc needed parameters
    flagVc.configure(panadapter: pan, slice: slice, controlsVc: controlsVc, vc: viewController)
    flagVc.smallFlagDisplayed = false
    flagVc.isOnLeft = true
    
    return flagVc
  }
  /// Add a Flag to the specified view
  ///
  /// - Parameters:
  ///   - flagVc:                 a FlagViewController
  ///   - parent:                 the parent View
  ///   - flagPosition:           the Flag's x-position
  ///   - flagHeight:             the Flag's height
  ///   - flagWidth:              the Flag's width
  ///
  class func addFlag(_ flagVc: FlagViewController, to parent: NSView, flagPosition: CGFloat, flagHeight: CGFloat, flagWidth: CGFloat) {
    
    // add the Flag & Controls views
    parent.addSubview(flagVc.view)
    parent.addSubview(flagVc.controlsVc!.view)
        
    // Flag View constraints: height, width & top of the Flag
    flagVc.flagHeightConstraint = flagVc.view.heightAnchor.constraint(equalToConstant: flagHeight)
    flagVc.flagWidthConstraint = flagVc.view.widthAnchor.constraint(equalToConstant: flagWidth)
    flagVc.flagTopConstraint = flagVc.view.topAnchor.constraint(equalTo: parent.topAnchor)
    
    // Flag View constraints: position (will be changed as Flag moves)
    flagVc.flagXPositionConstraint = flagVc.view.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: flagPosition)
    
    // activate Flag View constraints
    NSLayoutConstraint.activate([flagVc.flagHeightConstraint!,
                                 flagVc.flagWidthConstraint!,
                                 flagVc.flagXPositionConstraint!,
                                 flagVc.flagTopConstraint!])
    
    // Controls View constraints: leading, trailing & top of the Controls
    flagVc.controlsVc!.leadingConstraint = flagVc.controlsVc!.view.leadingAnchor.constraint(equalTo: flagVc.view.leadingAnchor)
    flagVc.controlsVc!.trailingConstraint = flagVc.controlsVc!.view.trailingAnchor.constraint(equalTo: flagVc.view.trailingAnchor)
    flagVc.controlsVc!.topConstraint = flagVc.controlsVc!.view.topAnchor.constraint(equalTo: flagVc.view.bottomAnchor)
    
    // activate Controls View constraints
    NSLayoutConstraint.activate([flagVc.controlsVc!.leadingConstraint!,
                                 flagVc.controlsVc!.trailingConstraint!,
                                 flagVc.controlsVc!.topConstraint!])
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    view.translatesAutoresizingMaskIntoConstraints = false

    if Defaults.flagBorderEnabled {
      view.layer?.borderColor = NSColor.darkGray.cgColor
      view.layer?.borderWidth = 0.5
    }
    // populate the choices
    _rxAntPopUp.addItems(withTitles: slice!.rxAntList)
    _txAntPopUp.addItems(withTitles: slice!.txAntList)
    
    _frequencyField.delegate = self
    
    _sMeter.legends = [            // to skip a legend pass "" as the format
        (1, "1", 0.5),
        (3, "3", 0.5),
        (5, "5", 0.5),
        (7, "7", 0.5),
        (9, "9", 0.5),
        (11, "+20", 0.5),
        (13, "+40", 0.5)
    ]
    _sMeter.font = NSFont(name: "Monaco", size: 10.0)
    
    // slice!.sliceLetter is V3 and later, earlier versions use the index calculation
    let letter = slice!.sliceLetter == nil ? FlagViewController.kSliceLetters[Int(slice!.id)] : slice!.sliceLetter!
    _alphaButton.attributedTitle = NSAttributedString(string: letter, attributes: kLetterAttr)
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    
    // set the background color of the Flag
    if _vc is SideViewController {
      // make it opague if a Side view
      view.layer?.backgroundColor = NSColor.black.cgColor
    } else {
      // can be less opague as a Slice flag
      view.layer?.backgroundColor = ControlsViewController.kBackgroundColor
    }
  }

  public func controlTextDidBeginEditing(_ note: Notification) {

    if let field = note.object as? NSTextField, field == _frequencyField {

      _previousFrequency = slice!.frequency
    }
    _beginEditing = true
  }
  
  public func controlTextDidEndEditing(_ note: Notification) {

    if let field = note.object as? NSTextField, field == _frequencyField, _beginEditing {

      if field.doubleValue == FlagViewController.maxFrequency || field.doubleValue == FlagViewController.minFrequency {
        slice!.frequency = _previousFrequency
        field.doubleValue = _previousFrequency.intHzToDoubleMhz
      } else {
        slice!.frequency = field.doubleValue.doubleMhzToIntHz
        
        repositionPanadapter(center: _center, frequency: _previousFrequency, newFrequency: slice!.frequency)
      }
      _beginEditing = false
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Internal methods

  /// Configure a new Flag
  ///
  /// - Parameters:
  ///   - panadapter:               a Panadapter reference
  ///   - slice:                    a Slice reference
  ///
  func configure(panadapter: Panadapter, slice: xLib6000.Slice, controlsVc: ControlsViewController, vc: NSViewController) {
    
    // save the params
    _panadapter = panadapter
    self.slice = slice
    self.controlsVc = controlsVc
    _vc = vc
    
    // pass values to the Controls view controller
    controlsVc.configure(slice: slice)
    
    // create observations of Slice & Panadapter properties
    addObservations(slice: slice, panadapter: _panadapter!)
    
    // start receiving S-Meter notifications
    addNotifications()
  }
  /// Update an existing Flag
  ///
  /// - Parameters:
  ///   - slice:                    the Flag's new Slice
  ///   - panadapter:               the Flag's new panadapter
  ///
  func updateFlag(slice: xLib6000.Slice, panadapter: Panadapter) {
    
    // save the new Slice & Panadapter
    _panadapter = panadapter
    self.slice = slice

    // remove the previous observations
    removeObservations()
    
    // add observations of the new objects
    addObservations(slice: slice, panadapter: panadapter)

    // update the Slice Letter
    _alphaButton.attributedTitle = NSAttributedString(string: FlagViewController.kSliceLetters[Int(slice.id)], attributes: kLetterAttr)
  }
  /// Select one of the Controls views
  ///
  /// - Parameter tag:           a control tag
  ///
  func selectControls(_ tag: Int) {
    
    switch tag {
    case 0:   _audButton.performClick(self)
    case 1:   _dspButton.performClick(self)
    case 2:   _modeButton.performClick(self)
    case 3:   _xritButton.performClick(self)
    case 4:   _daxButton.performClick(self)
    default:  _audButton.performClick(self)
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  @IBAction func buttons(_ sender: NSButton) {
    
    switch sender.identifier!.rawValue {
    case "nb":    slice?.nbEnabled = sender.boolState
    case "nr":    slice?.nrEnabled = sender.boolState
    case "anf":
      if slice?.mode == "USB" || slice?.mode == "LSB" {
        slice?.anfEnabled = sender.boolState
      } else if  slice?.mode == "CW" {
        slice?.apfEnabled = sender.boolState
      }
    case "qsk":   slice?.qskEnabled = sender.boolState
    case "lock":  slice?.locked = sender.boolState
    default:      break
    }
  }
  
  @IBAction func controlsButtons(_ sender: NSButton) {
    // is the button "on"?
    if sender.boolState {
      
      // YES, turn off any other buttons
      if sender.tag != 0 { _audButton.boolState = false}
      if sender.tag != 1 { _dspButton.boolState = false}
      if sender.tag != 2 { _modeButton.boolState = false}
      if sender.tag != 3 { _xritButton.boolState = false}
      if sender.tag != 4 { _daxButton.boolState = false}

      // select the desired tab
      controlsVc?.selectedTabViewItemIndex = sender.tag

      if _vc is SideViewController { (_vc as! SideViewController).setRxHeight(2 * FlagViewController.kLargeFlagHeight) }
      if _vc is MiniViewController { (_vc as! MiniViewController).setMiniHeight(2 * FlagViewController.kLargeFlagHeight) }

      // unhide the controls
      controlsVc!.view.isHidden = false
      
    } else {
      
      // hide the controls
      controlsVc!.view.isHidden = true

      if _vc is SideViewController { (_vc as! SideViewController).setRxHeight( FlagViewController.kLargeFlagHeight) }
      if _vc is MiniViewController { (_vc as! MiniViewController).setMiniHeight( FlagViewController.kLargeFlagHeight) }
    }
  }
  
  @IBAction func popups(_ sender: NSPopUpButton) {
    
    switch sender.identifier!.rawValue {
    case "rxAnt": slice?.rxAnt = sender.titleOfSelectedItem!
    case "txAnt": slice?.txAnt = sender.titleOfSelectedItem!
    default:      break
    }
  }
    
  @IBAction func sliceLetterButton(_ sender: Any) {
   
    // return if this a Side flag (i.e. not on a Slice)
    guard _vc is PanadapterViewController else { return }
      
    var flagPosition: CGFloat = 0
    let constraints = [flagHeightConstraint!, flagWidthConstraint!, flagXPositionConstraint!]
    
    // toggle Flag size
    smallFlagDisplayed.toggle()
    
    // Disable constraints
    NSLayoutConstraint.deactivate(constraints)
    
    // set Flag size
    let width = (smallFlagDisplayed ? FlagViewController.kSmallFlagWidth : FlagViewController.kLargeFlagWidth)
    let height = (smallFlagDisplayed ? FlagViewController.kSmallFlagHeight : FlagViewController.kLargeFlagHeight)
    constraints[0].constant = height
    constraints[1].constant = width
    
    // set Flag position
    let freqPosition = CGFloat(slice!.frequency - _start) / _hzPerUnit
    flagPosition = (isOnLeft ? freqPosition - width - FlagViewController.kFlagOffset : freqPosition + FlagViewController.kFlagOffset)
    constraints[2].constant = flagPosition
    
    // Enable constraints
    NSLayoutConstraint.activate(constraints)
    
    // re-evaluate all flag positions
    (_vc as! PanadapterViewController).positionFlags()
  }

  @IBAction func splitButton(_ sender: NSButton) {
    sender.attributedTitle = NSAttributedString(string: kSplitCaption, attributes: sender.boolState ? kSplitOnAttr : kSplitOffAttr)

    if sender.boolState {
      // Create a split
      _radio?.requestSlice(panadapter: _panadapter!, frequency: slice!.frequency + Defaults.splitDistance, callback: splitCreated)
    
    } else {
      // Remove the Split
      if splitId != nil {
        _radio?.slices[splitId!]?.remove()
      }
    }
  }
  
  @IBAction func txButton(_ sender: NSButton) {

    slice?.txEnabled = !sender.boolState
  }
  
  @IBAction func xButton(_ sender: NSButton) {
    slice!.remove()
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Change a Slice frequency while maintaining its position in the Panadapter display
  ///
  /// - Parameters:
  ///   - center:                   the current Panadapter center frequency
  ///   - frequency:                the current Slice frequency
  ///   - newFrequency:             the new SLice frequency
  ///
  private func repositionPanadapter(center: Int, frequency: Int, newFrequency: Int) {
  
    slice!.frequency = newFrequency
    _panadapter!.center = newFrequency - (frequency - center)
  }
  /// Receive the Reply to a Split Create action
  ///
  /// - Parameters:
  ///   - command:                    the command sent
  ///   - seqNum:                     it's sequence number
  ///   - responseValue:              the response
  ///   - reply:                      the reply (if any)
  ///
  private func splitCreated(_ command: String, _ seqNumber: SequenceNumber, _ responseValue: String, _ reply: String) {
    
    // if success, save the Split's Id
    if responseValue == Api.kNoError {
      splitId = reply.objectId
    }
  }
 
  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  private var _observations = [NSKeyValueObservation]()
  
  /// Add observers for properties used by the Flag
  ///
  private func addObservations(slice: xLib6000.Slice, panadapter: Panadapter ) {
    
    _observations = [
      
      slice.observe(\.active, options: [.initial, .new, .old]) { [weak self] (slice, change) in
        if let old = change.oldValue, let new = change.newValue {
          if old == false && new == true {
            self?._log.logMessage("Slice became active: slice \(slice.id )", .debug, #function, #file, #line)
            NC.post(.sliceBecameActive, object: slice) }
          else {            
          }
        }},
      
      slice.observe(\.mode, options: [.initial, .new]) { [weak self] (slice, change) in
        DispatchQueue.main.async {
          self?._modeButton.title = slice.mode
          switch slice.mode {
          case "USB", "LSB":
            self?._anfButton.isEnabled = true
            self?._anfButton.title = "ANF"
            self?._anfButton.boolState = slice.anfEnabled
          case "CW":
            self?._anfButton.isEnabled = true
            self?._anfButton.title = "APF"
            self?._anfButton.boolState = slice.apfEnabled
          default:
            self?._anfButton.isEnabled = false
            self?._anfButton.title = "---"
          }
        }},
      
      slice.observe(\.txEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
        DispatchQueue.main.async {
          self?._txButton.attributedTitle = NSAttributedString(string: self!.kTxCaption, attributes: (slice.txEnabled ? self!.kTxOnAttr : self!.kTxOffAttr)) }},
      
      slice.observe(\.filterHigh, options: [.initial, .new]) { [weak self] (slice, change) in
        if let panVc = self?._vc as? PanadapterViewController { panVc.redrawFrequencyLegend() }
          DispatchQueue.main.async { self?._filterWidth.stringValue = self!.calcFilterWidth(slice, change) }},
      
      slice.observe(\.filterLow, options: [.initial, .new]) { [weak self] (slice, change) in
        if let panVc = self?._vc as? PanadapterViewController { panVc.redrawFrequencyLegend() }
          DispatchQueue.main.async { self?._filterWidth.stringValue = self!.calcFilterWidth(slice, change) }},
      
      slice.observe(\.frequency, options: [.initial, .new]) { [weak self] (slice, change) in
        if let panVc = self?._vc as? PanadapterViewController { panVc.redrawFrequencyLegend() }
          DispatchQueue.main.async { self?._frequencyField?.doubleValue = slice.frequency.intHzToDoubleMhz }},
      
      panadapter.observe(\.center, options: [.initial, .new]) { [weak self] (panadapter, change) in
        if let panVc = self?._vc as? PanadapterViewController {
            // this is a Slice Flag, move the Flag(s)
            panVc.positionFlags() }},
      
      panadapter.observe(\.bandwidth, options: [.initial, .new]) { [weak self] (panadapter, change) in
        if let panVc = self?._vc as? PanadapterViewController {
            // this is a Slice Flag, move the Flag(s)
            panVc.positionFlags() }},
      
      slice.observe(\.nbEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
        DispatchQueue.main.async { self?._nbButton.boolState = slice.nbEnabled }},
      
      slice.observe(\.nrEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
        DispatchQueue.main.async { self?._nrButton.boolState = slice.nrEnabled }},
      
      slice.observe(\.anfEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
        DispatchQueue.main.async { if slice.mode == "USB" || slice.mode == "LSB" { self?._anfButton.boolState = slice.anfEnabled } }},
      
      slice.observe(\.apfEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
        DispatchQueue.main.async { if slice.mode == "CW" { self?._anfButton.boolState = slice.apfEnabled } }},
      
      slice.observe(\.qskEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
        DispatchQueue.main.async { self?._qskButton.boolState = slice.qskEnabled }},
      
      slice.observe(\.locked, options: [.initial, .new]) { [weak self] (slice, change) in
        DispatchQueue.main.async { self?._lockButton.boolState = slice.locked }},
      
      slice.observe(\.rxAnt, options: [.initial, .new]) { [weak self] (slice, change) in
        DispatchQueue.main.async { self?._rxAntPopUp.selectItem(withTitle: slice.rxAnt) }},
      
      slice.observe(\.txAnt, options: [.initial, .new]) { [weak self] (slice, change) in
        DispatchQueue.main.async { self?._txAntPopUp.selectItem(withTitle: slice.txAnt)}}
    ]
  }

  /// Invalidate observations (optionally remove)
  ///
  /// - Parameters:
  ///   - observations:                 an array of NSKeyValueObservation
  ///   - remove:                       remove all enabled
  ///
  func removeObservations() {
    
    // invalidate each observation
    _observations.forEach { $0.invalidate() }
    
    // remove the tokens
    _observations.removeAll()
  }
  /// Calculate Filter width
  ///
  /// - Parameters:
  ///   - object:               the object that changed
  ///   - change:               the change
  ///
  private func calcFilterWidth(_ slice: xLib6000.Slice, _ change: Any) -> String {
    var formattedWidth = ""
    
    let width = slice.filterHigh - slice.filterLow
    switch width {
    case 1_000...:  formattedWidth = String(format: "%2.1fk", Float(width)/1000.0)
    case 0..<1_000: formattedWidth = String(format: "%3d", width)
    default:        formattedWidth = "0"
    }
    return formattedWidth
  }
  /// Respond to a change in Panadapter or Slice properties
  ///
  /// - Parameters:
  ///   - object:               the object rhat changed
  ///   - change:               the change
  ///
  private func positionChange(_ object: Any, _ change: Any) {
    
    if let panVc = _vc as? PanadapterViewController {
      DispatchQueue.main.async {
        // this is a Slice Flag, move the Flag(s)
        panVc.positionFlags()
      }
    }
  }
  /// Respond to a change in the active Slice
  ///
  /// - Parameters:
  ///   - slice:                the slice that changed
  ///   - change:               the change
  ///
  private func sliceChange(_ slice: xLib6000.Slice, _ change: Any) {
    
    if let panVc = _vc as? PanadapterViewController {
      panVc.redrawFrequencyLegend()
      DispatchQueue.main.async {
        self._frequencyField?.doubleValue = slice.frequency.intHzToDoubleMhz
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subsciptions to Notifications
  ///
  private func addNotifications() {
    
    NC.makeObserver(self, with: #selector(sliceMeterUpdated(_:)), of: .sliceMeterUpdated)
  }
  private var _meterObservations    = [NSKeyValueObservation]()
  
  /// Process Meter Notification
  ///
  /// - Parameter note:       a Notification instance
  ///
  @objc private func sliceMeterUpdated(_ note: Notification) {
    
    // does the Notification contain an S-Meter object for this Slice?
    if let meter = note.object as? Meter, meter.group.objectId == slice?.id, meter.name == Meter.ShortName.signalPassband.rawValue {
      // YES
      var value = CGFloat(meter.value)
      var sLevel = ""
      
      // S-Units above S9 are scaled
      if value > -73 { value = ((value + 73) * 0.6) - 73 }
      
      // set the "S" level
      switch value {
      case ..<(-121):       sLevel = " S0"
      case (-121)..<(-115): sLevel = " S1"
      case (-115)..<(-109): sLevel = " S2"
      case (-109)..<(-103): sLevel = " S3"
      case (-103)..<(-97):  sLevel = " S4"
      case (-103)..<(-97):  sLevel = " S5"
      case (-97)..<(-91):   sLevel = " S6"
      case (-91)..<(-85):   sLevel = " S7"
      case (-85)..<(-79):   sLevel = " S8"
      case (-79)..<(-73):   sLevel = " S9"
      case (-73)..<(-67):   sLevel = "+10"
      case (-67)..<(-61):   sLevel = "+20"
      case (-61)..<(-55):   sLevel = "+30"
      case (-55)..<(-49):   sLevel = "+40"
      case (-49)...:        sLevel = "+++"
      default:              break
      }
      
      DispatchQueue.main.async { [weak self] in
        // set the bargraph & S level
        self?._sMeter.level = value
        self?._sLevel.stringValue = sLevel
      }
    }
  }
}

// --------------------------------------------------------------------------------
// MARK: - Frequency Formatter class implementation
// --------------------------------------------------------------------------------

class FrequencyFormatter : NumberFormatter {
  
  let max = FlagViewController.maxFrequency
  let min = FlagViewController.minFrequency
  
  // assumes that the formatter was added in IB
  override init() {
    fatalError("Init can not be used")
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    
    // set the parameters
    roundingMode = .ceiling
    allowsFloats = true
  }
  
  override func string(for obj: Any?) -> String? {

    // super may provide some functionality
    super.string(for: obj)

    // guard that it's a Double
    guard var value = obj as? Double else { return nil }
    
    // allow 4 or 5 digit Khz entries
    if value >= 1_000.0 && value < 10_000.0 { value = value / 1_000 }
    
    guard value <= max else { return adjustPeriods(String(max)) }
    guard value >= min else { return adjustPeriods(String(min)) }

    // make a String version, format xx.xxxxxx
    var stringValue = String(format: "%.6f", value)

    if stringValue.hasPrefix("0.") { stringValue = String(stringValue.dropFirst(2)) }

    // insert the second ".", format xx.xxx.xxx
    stringValue.insert(".", at: stringValue.index(stringValue.endIndex, offsetBy: -3))
      
    return stringValue
  }
  
  override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, range rangep: UnsafeMutablePointer<NSRange>?) throws {
    
    // return the string to an acceptable Double format (i.e. ##.######)
    let adjustedString = adjustPeriods(string)
    
    // super may provide some functionality
    try super.getObjectValue(obj, for: adjustedString, range: rangep)
    
    // return a Double
    obj?.pointee = (Double(adjustedString) ?? 0.0) as AnyObject
  }

  /// Accept a  String in Frequency field format & convert to Double format
  /// - Parameter string:   the String in the Frequency field
  /// Returns:                                    a String in Double / Float format
  ///
  func adjustPeriods(_ string: String) -> String {
    var adjustedString = String(string)
    
    // find the first & last periods
    //    Note: there will always be at least one period
    let firstIndex = adjustedString.firstIndex(of: ".")
    let lastIndex = adjustedString.lastIndex(of: ".")
    let startIndex = adjustedString.startIndex
    
    // if both are found
    if let first = firstIndex, let last = lastIndex {
      
      // format is xx.xxx.xxx, remove 2nd period
      if first < last { adjustedString.remove(at: last) }
      
      // decide if adjustment required
      if first == last {
        // short-circuited action prevents index out of range issue
        if first == adjustedString.startIndex || first == adjustedString.index(startIndex, offsetBy: 1) || first == adjustedString.index(startIndex, offsetBy: 2) {
          // format is .x  OR x.  OR  xx., do nothing
          
        } else {
          // format is xxx.xxx, adjust
          adjustedString.remove(at: last)
          adjustedString = "." + adjustedString
        }
      }
    }
    return adjustedString
  }
}
//class FrequencyTransformer : ValueTransformer {
//  
//  override class func allowsReverseTransformation() -> Bool {
//    return true
//  }
//  override class func transformedValueClass() -> AnyClass {
//    return NSNumber.self
//  }
//  override func transformedValue(_ value: Any?) -> Any? {
//    return ((value as? Int) ?? 0).intHzToDoubleMhz
//  }
//  override func reverseTransformedValue(_ value: Any?) -> Any? {
//    return ((value as? Double) ?? 0).doubleMhzToIntHz
//  }
//}


