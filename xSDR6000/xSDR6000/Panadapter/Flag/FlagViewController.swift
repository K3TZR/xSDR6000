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

final class FlagViewController       : NSViewController, NSTextFieldDelegate, NSGestureRecognizerDelegate {
  
  static let kSliceLetters : [String]       = ["A", "B", "C", "D", "E", "F", "G", "H"]
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

  @objc dynamic var slice                   : xLib6000.Slice?

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
  
  private var _observations                 = [NSKeyValueObservation]()
  
  private var _previousFrequency            = 0
  private var _beginEditing                 = false
  private var _darkMode                     = false

  private let _log                          = NSApp.delegate as! AppDelegate

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
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    view.translatesAutoresizingMaskIntoConstraints = false

    if Defaults[.flagBorderEnabled] {
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

      repositionPanadapter(center: _center, frequency: _previousFrequency, newFrequency: _frequencyField.integerValue)
      _beginEditing = false
    }
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

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
    
    // find the S-Meter feed (if any, it may alreaady exist or it may come later as a sliceMeterAdded Notification)
    findSMeter(for: slice)
    
    // start receiving Notifications
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

    // find the s-meter feed for the new Slice
    findSMeter(for: slice)
    
    // update the Slice Letter
    _alphaButton.attributedTitle = NSAttributedString(string: FlagViewController.kSliceLetters[Int(slice.id)], attributes: kLetterAttr)
  }
  /// Select one of the Controls views
  ///
  /// - Parameter id:                   an identifier String
  ///
  func selectControls(_ tag: Int) {
    
    switch tag {
    case 0:
      _audButton.performClick(self)
    case 1:
      _dspButton.performClick(self)
    case 2:
      _modeButton.performClick(self)
    case 3:
      _xritButton.performClick(self)
    case 4:
      _daxButton.performClick(self)
    default:
      _audButton.performClick(self)
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Respond to the Slice Letter button
  ///
  /// - Parameter sender:             the button
  ///
  @IBAction func alphaButton(_ sender: Any) {
   
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
  /// Respond to the TX button
  ///
  /// - Parameter sender:             the button
  ///
  @IBAction func txButton(_ sender: NSButton) {

    slice?.txEnabled = !sender.boolState
  }
  /// Respond to the SPLIT button
  ///
  /// - Parameter sender:             the button
  ///
  @IBAction func splitButton(_ sender: NSButton) {
    sender.attributedTitle = NSAttributedString(string: kSplitCaption, attributes: sender.boolState ? kSplitOnAttr : kSplitOffAttr)

    if sender.boolState {
      // Create a split
      _radio?.createSlice(panadapter: _panadapter!, frequency: slice!.frequency + Defaults[.splitDistance], callback: splitCreated)
    
    } else {
      // Remove the Split
      if splitId != nil {
        _radio?.slices[splitId!]?.remove()
      }
    }
  }
  /// Respond to the Close button
  ///
  /// - Parameter sender:         the button
  ///
  @IBAction func closeButton(_ sender: NSButton) {
    slice!.remove()
  }
  /// One of the "tab" view buttons has been clicked
  ///
  /// - Parameter sender:         the button
  ///
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

      // unhide the controls
      controlsVc!.view.isHidden = false
      
    } else {
      
      // hide the controls
      controlsVc!.view.isHidden = true

      if _vc is SideViewController { (_vc as! SideViewController).setRxHeight( FlagViewController.kLargeFlagHeight) }
    }
  }
  /// One of the popups has been clicked
  ///
  /// - Parameter sender:         the popup
  ///
  @IBAction func popups(_ sender: NSPopUpButton) {
    
    switch sender.identifier!.rawValue {
    case "rxAnt":
      slice?.rxAnt = sender.titleOfSelectedItem!
    case "txAnt":
      slice?.txAnt = sender.titleOfSelectedItem!
    default:
      fatalError()
    }
  }
  /// One of the buttons has been clicked
  ///
  /// - Parameter sender:         the button
  ///
  @IBAction func buttons(_ sender: NSButton) {
    
    switch sender.identifier!.rawValue {
    case "nb":
      slice?.nbEnabled = sender.boolState
    case "nr":
      slice?.nrEnabled = sender.boolState
    case "anf":
      slice?.anfEnabled = sender.boolState
    case "qsk":
      slice?.qskEnabled = sender.boolState
    default:
      fatalError()
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
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
  /// Find the S-Meter for this Slice (if any)
  ///
  private func findSMeter(for slice: xLib6000.Slice) {
    
    if let item = Api.sharedInstance.radio!.meters.first(where: {
      $0.value.source == "slc" &&
        $0.value.group.objectId == slice.id &&
      $0.value.name == Api.MeterShortName.signalPassband.rawValue} ) {
      
      addMeterObservation( item.value)
    }
  }
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
 
  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  /// Add observers for properties used by the Flag
  ///
  private func addObservations(slice: xLib6000.Slice, panadapter: Panadapter ) {
    
    _observations.append( slice.observe(\.active, options: [.initial, .new]) { [weak self] (slice, change) in
      self?.sliceChange(slice, change) })
    
    _observations.append( slice.observe(\.mode, options: [.initial, .new]) { [weak self] (slice, change) in
      self?.sliceChange(slice, change) })
    
    _observations.append(  slice.observe(\.txEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
      self?.txChange(slice, change) })
    
    _observations.append( slice.observe(\.filterHigh, options: [.initial, .new]) { [weak self] (slice, change) in
      self?.filterChange(slice, change) })
    
    _observations.append( slice.observe(\.filterLow, options: [.initial, .new]) { [weak self] (slice, change) in
      self?.filterChange(slice, change) })
    
    _observations.append( slice.observe(\.frequency, options: [.initial, .new]) { [weak self] (slice, change) in
      self?.positionChange(slice, change) })
    
    _observations.append(  panadapter.observe(\.center, options: [.initial, .new]) { [weak self] (panadapter, change) in
      self?.positionChange(panadapter, change) })
    
    _observations.append( panadapter.observe(\.bandwidth, options: [.initial, .new]) { [weak self] (panadapter, change) in
      self?.positionChange(panadapter, change) })
    
    _observations.append( slice.observe(\.nbEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
      self?.buttonsChange(slice, change) })
    
    _observations.append( slice.observe(\.nrEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
      self?.buttonsChange(slice, change) })
    
    _observations.append( slice.observe(\.anfEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
      self?.buttonsChange(slice, change) })
    
    _observations.append( slice.observe(\.qskEnabled, options: [.initial, .new]) { [weak self] (slice, change) in
      self?.buttonsChange(slice, change) })
    
    _observations.append( slice.observe(\.locked, options: [.initial, .new]) { [weak self] (slice, change) in
      self?.buttonsChange(slice, change) })
    
    _observations.append( slice.observe(\.rxAnt, options: [.initial, .new]) { [weak self] (slice, change) in
      self?.antennaChange(slice, change) })
    
    _observations.append( slice.observe(\.txAnt, options: [.initial, .new]) { [weak self] (slice, change) in
      self?.antennaChange(slice, change) })
  }
  /// Add Observation of the S-Meter feed
  ///
  ///     Note: meters may not be available at Slice creation.
  ///     If not, the .sliceMeterHasBeenAdded notification will identify the S-Meter
  ///
  func addMeterObservation(_ meter: Meter) {
    
    // YES, log the event
    _log.msg("Slice Meter found: slice \(meter.group ), meter \"\(meter.desc)\"", level: .debug, function: #function, file: #file, line: #line)

    // add the observation
    _observations.append( meter.observe(\.value, options: [.initial, .new]) { [weak self] (meter, change) in
      self?.meterChange(meter, change) })
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
  /// Respond to a change in Slice Tx state
  ///
  /// - Parameters:
  ///   - object:               the object that changed
  ///   - change:               the change
  ///
  private func txChange(_ slice: xLib6000.Slice, _ change: Any) {

    DispatchQueue.main.async {
      self._txButton.attributedTitle = NSAttributedString(string: self.kTxCaption, attributes: (slice.txEnabled ? self.kTxOnAttr : self.kTxOffAttr))
    }
  }
  /// Respond to a change in Slice Filter width
  ///
  /// - Parameters:
  ///   - object:               the object that changed
  ///   - change:               the change
  ///
  private func filterChange(_ slice: xLib6000.Slice, _ change: Any) {
    var formattedWidth = ""
    
    let width = slice.filterHigh - slice.filterLow
    switch width {
    case 1_000...:
      formattedWidth = String(format: "%2.1fk", Float(width)/1000.0)
    case 0..<1_000:
      formattedWidth = String(format: "%3d", width)
    default:
      formattedWidth = "0"
    }
    DispatchQueue.main.async { [weak self] in
      self?._filterWidth.stringValue = formattedWidth

      // update the filter outline
      (self?.parent as? PanadapterViewController)?.redrawFrequencyLegend()
    }
  }
  /// Respond to a change in buttons
  ///
  /// - Parameters:
  ///   - slice:                the slice that changed
  ///   - change:               the change
  ///
  private func buttonsChange(_ slice: xLib6000.Slice, _ change: Any) {

    DispatchQueue.main.async {
      self._lockButton.boolState = slice.locked
      self._nbButton.boolState = slice.nbEnabled
      self._nrButton.boolState = slice.nrEnabled
      self._anfButton.boolState = slice.anfEnabled
      self._qskButton.boolState = slice.qskEnabled
    }
  }
  /// Respond to a change in Antennas
  ///
  /// - Parameters:
  ///   - slice:                the slice that changed
  ///   - change:               the change
  ///
  private func antennaChange(_ slice: xLib6000.Slice, _ change: Any) {

    DispatchQueue.main.async {
      self._rxAntPopUp.selectItem(withTitle: slice.rxAnt)
      self._txAntPopUp.selectItem(withTitle: slice.txAnt)
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
      
      DispatchQueue.main.async {
        self._modeButton.title = slice.mode
      }
     // this is a Slice Flag, redraw
      panVc.redrawFrequencyLegend()
    }
  }
  /// Respond to a change in Panadapter or Slice properties
  ///
  /// - Parameters:
  ///   - object:               the object rhat changed
  ///   - change:               the change
  ///
  private func positionChange(_ object: Any, _ change: Any) {
    
    if let panVc = _vc as? PanadapterViewController {
      // this is a Slice Flag, move the Flag(s)
      panVc.positionFlags()
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subsciptions to Notifications
  ///     (as of 10.11, subscriptions are automatically removed on deinit when using the Selector-based approach)
  ///
  private func addNotifications() {
    
    NC.makeObserver(self, with: #selector(sliceMeterHasBeenAdded(_:)), of: .sliceMeterHasBeenAdded)
  }
  private var _meterObservations    = [NSKeyValueObservation]()
  
  /// Process sliceMeterHasBeenAdded Notification
  ///
  /// - Parameter note:       a Notification instance
  ///
  @objc private func sliceMeterHasBeenAdded(_ note: Notification) {
    
    // does the Notification contain a Meter object for this Slice?
    if let meter = note.object as? Meter, meter.group.objectId == slice?.id {

      // which meter?
      switch meter.name {
      
      // S-Meter
      case Api.MeterShortName.signalPassband.rawValue:
        
        addMeterObservation( meter )
      
      default:
        break
      }
    }
  }
  /// Respond to a change in the S-Meter
  ///
  /// - Parameters:
  ///   - object:                 the Meter
  ///   - change:                 the Change
  ///
  private func meterChange(_ object: Any, _ change: Any) {
    
    DispatchQueue.main.async { [weak self] in

      let meter = object as! Meter

      var value = CGFloat(meter.value)
      
      // S-Units above S9 are scaled 
      if value > -73 {
        value = ((value + 73) * 0.6) - 73
      }
      
      // set the bargraph level
      self?._sMeter.level = value
      
      // set the "S" level
      switch value {
      case ..<(-121):
        self?._sLevel.stringValue = " S0"
      
      case (-121)..<(-115):
        self?._sLevel.stringValue = " S1"
     
      case (-115)..<(-109):
        self?._sLevel.stringValue = " S2"
      
      case (-109)..<(-103):
        self?._sLevel.stringValue = " S3"
      
      case (-103)..<(-97):
        self?._sLevel.stringValue = " S4"
      
      case (-103)..<(-97):
        self?._sLevel.stringValue = " S5"
      
      case (-97)..<(-91):
        self?._sLevel.stringValue = " S6"
      
      case (-91)..<(-85):
        self?._sLevel.stringValue = " S7"
      
      case (-85)..<(-79):
        self?._sLevel.stringValue = " S8"
      
      case (-79)..<(-73):
        self?._sLevel.stringValue = " S9"
      
      case (-73)..<(-67):
        self?._sLevel.stringValue = "+10"
     
      case (-67)..<(-61):
        self?._sLevel.stringValue = "+20"
      
      case (-61)..<(-55):
        self?._sLevel.stringValue = "+30"
      
      case (-55)..<(-49):
        self?._sLevel.stringValue = "+40"
      
      case (-49)...:
        self?._sLevel.stringValue = "+++"
      default:
        break
      }
    }
  }
}
// --------------------------------------------------------------------------------
// MARK: - Frequency Formatter class implementation
// --------------------------------------------------------------------------------

class FrequencyFormatter: NumberFormatter {
  
  private let _maxFrequency = 54_000_000
  private let _minFrequency = 100_000
  
  override init() {
    super.init()
    groupingSeparator = "."
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, range rangep: UnsafeMutablePointer<NSRange>?) throws {
    
    // remove any non-numeric characters
    let number = string.numbers
    
    if number.lengthOfBytes(using: .utf8) > 0 {
      // convert to an Int
      let intValue = Int(string.numbers)!
      
      // return the value as an NSNumber
      obj?.pointee = NSNumber(value: intValue)
    }
  }
  
  override func string(for obj: Any?) -> String? {
    // guard that it's an Int
    guard let intValue = obj as? Int else { return nil }
    
    // make a String version, get its length
    var stringValue = String(intValue)
    let stringLen = stringValue.lengthOfBytes(using: .utf8)
    
    switch stringLen {
      
    case 9...:
      stringValue = String(stringValue.dropLast(stringLen - 8))
      fallthrough
      
    case 7...8:
      let endIndex = stringValue.endIndex
      stringValue.insert(".", at: stringValue.index(endIndex, offsetBy: -3))
      stringValue.insert(".", at: stringValue.index(endIndex, offsetBy: -6))
      
    case 6:
      stringValue += "0"
      let endIndex = stringValue.endIndex
      stringValue.insert(".", at: stringValue.index(endIndex, offsetBy: -3))
      stringValue.insert(".", at: stringValue.index(endIndex, offsetBy: -6))
      
    case 4...5:
      stringValue += ".000"
      let endIndex = stringValue.endIndex
      stringValue.insert(".", at: stringValue.index(endIndex, offsetBy: -6))
      
    default:
      return nil
    }
    return stringValue
  }
}



