//
//  WaterfallViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 6/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import MetalKit
import SwiftyUserDefaults
import xLib6000


final class WaterfallViewController               : NSViewController, NSGestureRecognizerDelegate {
  
  enum GradientType: String {
    case Basic
    case Dark
    case Deuteranopia
    case Grayscale
    case Purple
    case Tritanopia
  }
  static let gradientNames = [
    GradientType.Basic.rawValue,
    GradientType.Dark.rawValue,
    GradientType.Deuteranopia.rawValue,
    GradientType.Grayscale.rawValue,
    GradientType.Purple.rawValue,
    GradientType.Tritanopia.rawValue
  ]
  
  // arbitrary choice of a reasonable number of color gradations for the waterfall
  private let kGradientSize                  = 256                           // number of colors in a gradient

  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  @objc dynamic weak var panadapter         : Panadapter?

  var radio: Radio?                         = Api.sharedInstance.radio
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _waterfallView : MTKView!
  @IBOutlet private weak var _timeView      : NSView!
  
  private var _waterfallRenderer            : WaterfallRenderer!

  private weak var _waterfall               : Waterfall? { radio!.waterfalls[panadapter!.waterfallId] }
  private let _log                          = (NSApp.delegate as! AppDelegate)
  private var _center                       : Hz  { panadapter!.center }
  private var _bandwidth                    : Hz  { panadapter!.bandwidth }
  private var _start                        : Hz  { _center - (_bandwidth/2) }
  private var _end                          : Hz  { _center + (_bandwidth/2) }
  private var _hzPerUnit                    : CGFloat { CGFloat(_end - _start) / panadapter!.xPixels }
  
  // constants
  private let _filter                       = CIFilter(name: "CIDifferenceBlendMode")

  private enum Colors {
    static let clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  /// The View has loaded
  ///
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif

    _waterfallRenderer = WaterfallRenderer(view: _waterfallView, radio: Api.sharedInstance.radio!, panadapter: panadapter!)
    
    _waterfallView.isPaused = true
    _waterfallView.enableSetNeedsDisplay = false
    
    // setup
    if let device = makeDevice(view: _waterfallView) {
      
      _waterfallRenderer.setConstants(size: view.frame.size)
      _waterfallRenderer.setup(device: device)
      
      _waterfallView.delegate = _waterfallRenderer
      _waterfallView.clearColor = Colors.clearColor
      
      // setup the gradient texture
      _waterfallRenderer.setGradient( loadGradient(index: _waterfall!.gradientIndex) )
      
      setupObservations()
      
      // make the Renderer the Stream Handler
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(3), execute: {  self._waterfall?.delegate = self._waterfallRenderer })
    }
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  // force a redraw of a layer
  
//  public func redrawTimeLegend() {
//    _timeLayer?.redraw()
//  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  /// Configure needed parameters
  ///
  /// - Parameter panadapter:               a Panadapter reference
  ///
  func configure(panadapter: Panadapter?) {
    self.panadapter = panadapter
  }
  /// Load the gradient at the specified index
  ///
  func loadGradient(index: Int) -> [UInt8] {
    var i = 0
    if (0..<WaterfallViewController.gradientNames.count).contains(index) { i = index }
    
    return loadGradient(name: WaterfallViewController.gradientNames[i])
  }
  /// Load a gradient from the named file
  ///
  private func loadGradient(name: String) -> [UInt8] {
    var file: FileHandle?
    
    if let texURL = Bundle.main.url(forResource: name, withExtension: "tex") {
      do {
        file = try FileHandle(forReadingFrom: texURL)
      } catch {
        fatalError("Gradient file '\(name).tex' not found")
      }
      // Read all the data
      let data = file!.readDataToEndOfFile()
      
      // Close the file
      file!.closeFile()
      
      // copy the data into the gradientArray
      var array = [UInt8](repeating: 0, count: data.count)
      data.copyBytes(to: &array[0], count: data.count)
      
      return array
    }
    // resource not found
    fatalError("Gradient file '\(name).tex' not found")
  }
//  /// Prevent the Right Click recognizer from responding when the mouse is not over the Legend
//  ///
//  /// - Parameters:
//  ///   - gr:             the Gesture Recognizer
//  ///   - event:          the Event
//  /// - Returns:          True = allow, false = ignore
//  ///
//  func gestureRecognizer(_ gr: NSGestureRecognizer, shouldAttemptToRecognizeWith event: NSEvent) -> Bool {
//
//    // is it a right click?
//    if gr.action == #selector(WaterfallViewController.clickRight(_:)) {
//      // YES, if not over the legend, push it up the responder chain
//      return view.convert(event.locationInWindow, from: nil).x >= view.frame.width - _waterfallView!.timeLegendWidth
//    } else {
//      // not right click, process it
//      return true
//    }
//  }
//  /// respond to Right Click gesture
//  ///     NOTE: will only receive events in time legend, see previous method
//  ///
//  /// - Parameter gr:     the Click Gesture Recognizer
//  ///
//  @objc func clickRight(_ gr: NSClickGestureRecognizer) {
//
//    // update the time Legend
//    _timeLayer?.updateLegendSpacing(gestureRecognizer: gr, in: view)
//  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Obtain the default Metal Device
  ///
  /// - Parameter view:         an MTKView
  /// - Returns:                a MTLDevice
  ///
  private func makeDevice(view: MTKView) -> MTLDevice? {
    
    if let device = MTLCreateSystemDefaultDevice() {
      view.device = device
      return device
    }
    return nil
  }
  /// start observations & Notification
  ///
  private func setupObservations() {

    // begin observations (panadapter, waterfall & Defaults)
    createBaseObservations(&_baseObservations)
    
    // add notification subscriptions
    addNotifications()
  }

  // ----------------------------------------------------------------------------
  // MARK: - NEW Observation methods

  private var _baseObservations        = [NSKeyValueObservation]()
  
  /// Add observations of various properties
  ///
  private func createBaseObservations(_ observations: inout [NSKeyValueObservation]) {
    
    observations = [
      panadapter!.observe(\.band, options: [.initial, .new]) { [weak self] (object, change) in
        self?.panadapterBandChange(object, change) },

//      panadapter!.observe(\.bandwidth, options: [.initial, .new]) { [weak self] (object, change) in
//        self?.panadapterUpdate(object, change)},
//
//      panadapter!.observe(\.center, options: [.initial, .new]) { [weak self] (object, change) in
//        self?.panadapterUpdate(object, change) },
      
//      _waterfall!.observe(\.autoBlackEnabled, options: [.initial, .new]) { [weak self] (object, change) in
//        self?.waterfallObserverLevels(object, change) },
//
//      _waterfall!.observe(\.blackLevel, options: [.initial, .new]) { [weak self] (object, change) in
//        self?.waterfallObserverLevels(object, change) },
//
//      _waterfall!.observe(\.colorGain, options: [.initial, .new]) { [weak self] (object, change) in
//        self?.waterfallObserverLevels(object, change) },
      
      _waterfall!.observe(\.gradientIndex, options: [.initial, .new]) { [weak self] (object, change) in
        self?.waterfallObserverGradient(object, change) },

      Defaults.observe(\.spectrumBackground, options: [.initial, .new]) { [weak self] (object, change) in
        self?.defaultsObserver(object, change) }
    ]
  }
  /// Invalidate observations (optionally remove)
  ///
  /// - Parameters:
  ///   - observations:                 an array of NSKeyValueObservation
  ///   - remove:                       remove all enabled
  ///
  func invalidateObservations(_ observations: inout [NSKeyValueObservation], remove: Bool = true) {
    
    // invalidate each observation
    observations.forEach {$0.invalidate()}

    // if specified, remove the tokens
    if remove { observations.removeAll() }
  }
  /// Respond to Panadapter observations
  ///
  /// - Parameters:
  ///   - object:                       the object holding the properties
  ///   - change:                       the change
  ///
//  private func panadapterUpdate(_ object: Panadapter, _ change: Any) {
//
      // update the Waterfall
//      _waterfallRenderer.update()
//  }
  /// Respond to Panadapter observations
  ///
  /// - Parameters:
  ///   - object:                       the object holding the properties
  ///   - change:                       the change
  ///
  private func panadapterBandChange(_ object: Panadapter, _ change: Any) {

    // force the Waterfall to restart
    _waterfallRenderer.restart()
  }
  /// Respond to Waterfall observations
  ///
  /// - Parameters:
  ///   - object:                       the object holding the properties
  ///   - change:                       the change
  ///
//  private func waterfallObserverLevels(_ waterfall: Waterfall, _ change: Any) {
//
//      // update the levels
//    _waterfallRenderer.setLevels(autoBlack: waterfall.autoBlackEnabled, blackLevel: waterfall.blackLevel, colorGain: waterfall.colorGain)
  
//    Swift.print("Observer: colorGain = \(waterfall.colorGain), autoBlack = \(waterfall.autoBlackEnabled), blackLevel = \(waterfall.blackLevel)")
//    }
  /// Respond to Waterfall observations
  ///
  /// - Parameters:
  ///   - object:                       the object holding the properties
  ///   - change:                       the change
  ///
  private func waterfallObserverGradient(_ waterfall: Waterfall, _ change: Any) {

    // reload the Gradient
    _waterfallRenderer.setGradient(loadGradient(index: waterfall.gradientIndex) )
  }
  /// Respond to Defaults observations
  ///
  /// - Parameters:
  ///   - object:                       the object holding the properties
  ///   - change:                       the change
  ///
  private func defaultsObserver(_ defaults: UserDefaults, _ change: Any) {
    
    // reset the spectrum background color
    let color = Defaults[.spectrumBackground]
    _waterfallView.clearColor = MTLClearColor(red: Double(color.redComponent),
                                              green: Double(color.greenComponent),
                                              blue: Double(color.blueComponent),
                                              alpha: Double(color.alphaComponent) )
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subsciptions to Notifications
  ///     (as of 10.11, subscriptions are automatically removed on deinit when using the Selector-based approach)
  ///
  private func addNotifications() {

    // only receive removal Notifications sent by this Waterfall
    NC.makeObserver(self, with: #selector(waterfallWillBeRemoved(_:)), of: .waterfallWillBeRemoved, object: _waterfall!)
  }
  /// Process .waterfallWillBeRemoved Notification
  ///
  /// - Parameter note:         a Notification instance
  ///
  @objc private func waterfallWillBeRemoved(_ note: Notification) {

    // does the Notification contain a Panadapter object?
    let waterfall = note.object as! Waterfall
    
    // YES, log the event
    _log.logMessage("Waterfall will be removed: Id = \(waterfall.id.hex)", .info, #function, #file, #line)

    // stop processing waterfall data
    waterfall.delegate = nil
    
    // invalidate all property observers
    invalidateObservations(&_baseObservations)
    
    // remove the UI components of the Panafall
    DispatchQueue.main.async { [weak self] in

      // remove the entire PanafallButtonViewController hierarchy
      let panafallButtonVc = self?.parent!.parent!
      panafallButtonVc?.removeFromParent()
    }
  }
}

