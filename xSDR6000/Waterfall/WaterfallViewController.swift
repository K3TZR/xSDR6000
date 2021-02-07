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
    
    @IBOutlet private weak var _waterfallView : MTKView!
    @IBOutlet private weak var _timeView      : NSView!
    
    private var _waterfallRenderer            : WaterfallRenderer!
    
    private var _params                       : Params!
    private var _hzPerUnit                    : CGFloat { CGFloat(_params.end - _params.start) / _params.panadapter.xPixels }
    
    // constants
    private let kGradientSize                 = 256  // number of color gradations for the waterfall
    
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
        
        _waterfallRenderer = WaterfallRenderer(view: _waterfallView, params: _params)
        
        // configure the Metal view
        _waterfallView.isPaused = (Defaults.waterfallEnabled == false)
        _waterfallView.enableSetNeedsDisplay = false
        
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
