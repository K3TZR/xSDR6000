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

final class WaterfallViewController: NSViewController, NSGestureRecognizerDelegate {
    
    enum GradientType: String {
        case basic  = "Basic"
        case dark   = "Dark"
        case deuteranopia   = "Deuteranopia"
        case grayscale  = "Grayscale"
        case purple = "Purple"
        case tritanopia = "Tritanopia"
    }
    static let gradientNames = [
        GradientType.basic.rawValue,
        GradientType.dark.rawValue,
        GradientType.deuteranopia.rawValue,
        GradientType.grayscale.rawValue,
        GradientType.purple.rawValue,
        GradientType.tritanopia.rawValue
    ]
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var _waterfallView   : MTKView!
    @IBOutlet private weak var _timeView        : NSView!
    
    private var _clickLeft                      : NSClickGestureRecognizer!
    private var _hzPerUnit                      : CGFloat { CGFloat(_params.end - _params.start) / _params.panadapter.xPixels }
    private weak var _panafallViewController    : PanafallViewController?
    private var _params                         : Params!
    private var _waterfallRenderer              : WaterfallRenderer!
    
    // constants
    private let kGradientSize                   = 256  // number of color gradations for the waterfall
    private let kLeftButton                     = 0x01
    private enum Colors {
        static let clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    }
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// The View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _panafallViewController = parent as? PanafallViewController
        
        _waterfallRenderer = WaterfallRenderer(view: _waterfallView, params: _params)
        
        // configure the Metal view
        _waterfallView.isPaused = (Defaults.waterfallEnabled == false)
        _waterfallView.enableSetNeedsDisplay = false
        
        // Double-Click, LEFT in panadapter
        _clickLeft = NSClickGestureRecognizer(target: self, action: #selector(clickLeft(_:)))
        _clickLeft.buttonMask = kLeftButton
        _clickLeft.numberOfClicksRequired = 2
        _clickLeft.delegate = self
        view.addGestureRecognizer(_clickLeft)
        
        // setup
        if let device = makeDevice(for: _waterfallView) {
            
            _waterfallRenderer.setConstants()
            _waterfallRenderer.setup(device: device)
            
            _waterfallView.delegate = _waterfallRenderer
            _waterfallView.clearColor = Colors.clearColor
            
            // setup the gradient texture
            _waterfallRenderer.setGradient( loadGradient(index: _params.waterfall.gradientIndex) )
            
            addObservations()
            addNotifications()
            
            // make the Renderer the Stream Handler
            //      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(3), execute: {  self._waterfall?.delegate = self._waterfallRenderer })
            self._params.waterfall.delegate = self._waterfallRenderer
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    // force a redraw of a layer
    
    //  public func redrawTimeLegend() {
    //    _timeLayer?.redraw()
    //  }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    func configure(params: Params) {
        _params = params
    }
    
    /// Load the gradient at the specified index
    ///
    func loadGradient(index: Int) -> [UInt8] {
        var i = 0
        if (0..<WaterfallViewController.gradientNames.count).contains(index) { i = index }
        
        return loadGradient(name: WaterfallViewController.gradientNames[i])
    }
    
    /// Respond to Click-Left gesture
    ///
    /// - Parameter gr:         the Click Gesture Recognizer
    ///
    @objc func clickLeft(_ gestureRecognizer: NSClickGestureRecognizer) {
        // get the coordinates and convert to this View
        let mouseLocation = gestureRecognizer.location(in: view)
        
        // calculate the frequency
        let clickFrequency = (mouseLocation.x * _hzPerUnit) + CGFloat(_params.start)
        
        // is there a Slice at the clickFrequency?
        
        // is there a Slice at the indicated freq?
        if let slice = hitTestSlice(at: clickFrequency, thisPanOnly: true) {
            // YES, make it active
            activateSlice(slice)
            
            // is there a slice on this pan?
        } else if let slice = Api.sharedInstance.radio!.findActiveSlice(on: _params.panadapter.id) {
            
            // YES, move it to the nearest step value
            let delta = Int(clickFrequency) % slice.step
            if delta >= slice.step / 2 {
                // move it to the step value above the click
                slice.frequency = Int(clickFrequency) + (slice.step - delta)
                
            } else {
                
                // move it to the step value below the click
                slice.frequency = Int(clickFrequency) - delta
            }
        }
        // redraw
        _panafallViewController?.redrawSlices()
    }
    
    /// Find the Slice at a frequency (if any)
    ///
    /// - Parameter freq:       the target frequency
    /// - Returns:              a slice or nil
    ///
    private func hitTestSlice(at freq: CGFloat, thisPanOnly: Bool = true) -> xLib6000.Slice? {
        var hitSlice: xLib6000.Slice?
        
        // calculate a minimum width for hit testing
        //    let effectiveWidth = Int( CGFloat(_p.bandwidth) * 0.01)
        
        for (_, slice) in _params.radio.slices {
            
            // only Slices on this Panadapter?
            if thisPanOnly && slice.panadapterId != _params.panadapter.id {
                
                // YES, skip this Slice
                continue
            }
            //      let testWidth = max(effectiveWidth, (slice.filterHigh - slice.filterLow))
            let testWidth = slice.filterHigh - slice.filterLow
            // is the Slice within the testWidth?
            switch slice.mode {
            case "USB", "DIGU":               // upper-side only
                if Int(freq) >= slice.frequency && Int(freq) <= slice.frequency + testWidth { hitSlice = slice }
            //        Swift.print("USB: \(Int(freq)) >= \(slice.frequency)  &&  <= \(slice.frequency + testWidth), \(hitSlice == nil ? "NO" : "YES")")
            
            case "LSB", "DIGL":                // lower-side only
                if Int(freq) >= slice.frequency - testWidth && Int(freq) <= slice.frequency { hitSlice = slice }
            //        Swift.print("LSB: \(Int(freq)) >= \(slice.frequency - testWidth)  &&  <= \(slice.frequency), \(hitSlice == nil ? "NO" : "YES")")
            
            case "AM", "SAM", "FM", "NFM":     // both sides
                if Int(freq) >= slice.frequency - (testWidth/2) && Int(freq) <= slice.frequency + (testWidth/2) { hitSlice = slice }
            //        Swift.print("AM: \(Int(freq)) >= \(slice.frequency - (testWidth/2))  &&  <= \(slice.frequency + (testWidth/2)), \(hitSlice == nil ? "NO" : "YES")")
            
            default:                          // both sides
                if Int(freq) >= slice.frequency - (testWidth/2) && Int(freq) <= slice.frequency + (testWidth/2) { hitSlice = slice }
            //        Swift.print("DEFAULT: \(Int(freq)) >= \(slice.frequency - (testWidth/2))  &&  <= \(slice.frequency + (testWidth/2)), \(hitSlice == nil ? "NO" : "YES")")
            }
            if hitSlice != nil { break }
        }
        return hitSlice
    }
    
    /// Make a Slice active
    ///
    /// - Parameter freq:       the target frequency
    ///
    private func activateSlice(_ slice: xLib6000.Slice) {
        // make all other Slices (if any) inactive
        _params.radio.slices.forEach { $0.value.active = false }
        
        // make the specified Slice active
        slice.active = true
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
    private func makeDevice(for view: MTKView) -> MTLDevice? {
        
        if let device = MTLCreateSystemDefaultDevice() {
            view.device = device
            return device
        }
        return nil
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    private var _observations           = [NSKeyValueObservation]()
    private var _defaultsObservations   = [DefaultsDisposable]()
    
    private func addObservations() {
        
        _observations = [
            _params.panadapter.observe(\.band, options: [.initial, .new]) { [weak self] (_, _) in
                // force the Waterfall to restart
                self?._waterfallRenderer.setConstants()},
            
            _params.waterfall.observe(\.gradientIndex, options: [.initial, .new]) { [weak self] (waterfall, _) in
                // reload the Gradient
                self?._waterfallRenderer.setGradient(self!.loadGradient(index: waterfall.gradientIndex) )}
        ]
        _defaultsObservations = [
            Defaults.observe(\.spectrumBackground, options: [.initial, .new]) { [weak self] update in
                let color = update.newValue!
                // reset the spectrum background color
                self?._waterfallView.clearColor = MTLClearColor(red: Double(color.redComponent),
                                                                green: Double(color.greenComponent),
                                                                blue: Double(color.blueComponent),
                                                                alpha: Double(color.alphaComponent) )}
        ]
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    /// Add subsciptions to Notifications
    ///     (as of 10.11, subscriptions are automatically removed on deinit when using the Selector-based approach)
    ///
    private func addNotifications() {
        
        // only receive removal Notifications sent by this view's Waterfall
        NCtr.makeObserver(self, with: #selector(waterfallWillBeRemoved(_:)), of: .waterfallWillBeRemoved, object: _params.waterfall)
    }
    /// Process .waterfallWillBeRemoved Notification
    ///
    /// - Parameter note:         a Notification instance
    ///
    @objc private func waterfallWillBeRemoved(_ note: Notification) {
        
        // does the Notification contain a Waterfall object?
        if let waterfall = note.object as? Waterfall {
            
            // YES, log the event
            _params.log("Waterfall will be removed: id = \(waterfall.id.hex)", .info, #function, #file, #line)
            
            // stop processing waterfall data
            _waterfallView.isPaused = true
            waterfall.delegate = nil
            
            // remove the UI components of the Panafall
            DispatchQueue.main.async { [weak self] in
                
                // remove the entire PanafallButtonViewController hierarchy
                let panafallButtonVc = self?.parent!.parent!
                panafallButtonVc?.removeFromParent()
            }
        }
    }
}
