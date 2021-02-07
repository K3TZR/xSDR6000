//
//  PanadapterViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/13/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import MetalKit
import SwiftyUserDefaults
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - Panadapter View Controller class implementation
// --------------------------------------------------------------------------------

final class PanadapterViewController: NSViewController, NSGestureRecognizerDelegate {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    enum DragType {
        case dbm        // +/- Panadapter dbm upper/lower level
        case frequency  // +/- Panadapter bandwidth
        case slice      // +/- Slice frequency/width
        case spectrum   // +/- Panadapter center frequency
        case tnf        // +/- Tnf frequency/width
    }
    
    struct Dragable {
        var type        = DragType.spectrum
        var original    = NSPoint(x: 0.0, y: 0.0)
        var previous    = NSPoint(x: 0.0, y: 0.0)
        var current     = NSPoint(x: 0.0, y: 0.0)
        var percent     : CGFloat = 0.0
        var frequency   : CGFloat = 0.0
        var cursor      : NSCursor!
        var object      : Any?
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var _frequencyLegendView : FrequencyLegendView!
    @IBOutlet private weak var _dbLegendView        : DbLegendView!
    @IBOutlet private weak var _panadapterView      : MTKView!
    
    private var _params                       : Params!
    private var _hzPerUnit                    : CGFloat { CGFloat(_params.end - _params.start) / _params.panadapter.xPixels }
    
    private var _flags                        = [SliceId:FlagViewController]()
    private var _panadapterRenderer           : PanadapterRenderer!
    
    // gesture recognizer related
    private var _clickLeft                    : NSClickGestureRecognizer!
    private var _clickRight                   : NSClickGestureRecognizer!
    private var _panCenter                    : NSPanGestureRecognizer!
    private var _panBandwidth                 : NSPanGestureRecognizer!
    private var _panRightButton               : NSPanGestureRecognizer!
    private var _panStart                     : NSPoint?
    private var _slice                        : xLib6000.Slice?
    private var _panTnf                       : Tnf?
    private var _dbmTop                       = false
    private var _newCursor                    : NSCursor?
    private var _dbLegendSpacings             = [String]()                  // Db spacing choices
    private var _dragable                     = Dragable()
    
    private let kLeftButton                   = 0x01                        // button masks
    private let kRightButton                  = 0x02
    private let kDbLegendWidth                : CGFloat = 40                // width of Db legend
    private let kFrequencyLegendHeight        : CGFloat = 20                // height of the Frequency legend
    private let kFilter                       = CIFilter(name: "CIDifferenceBlendMode")
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // configure the Metal view
        _panadapterView.isPaused = (Defaults.panadapterEnabled == false)
        _panadapterView.enableSetNeedsDisplay = false
        
        // determine how the various views are blended on screen
        _panadapterView.compositingFilter = kFilter
        _dbLegendView.compositingFilter = kFilter
        _frequencyLegendView.compositingFilter = kFilter
        
        // create the Renderer
        _panadapterRenderer = PanadapterRenderer(view: _panadapterView, clearColor: Defaults.spectrumBackground)
        
        // tell the Panadapter to tell the Radio the current dimensions
        _params.panadapter.xPixels = view.frame.width
        _params.panadapter.yPixels = view.frame.height
        
        // setup
        if let device = makeDevice(view: _panadapterView) {
            
            _panadapterRenderer.setConstants(size: view.frame.size)
            _panadapterRenderer.setup(device: device)
            
            // get the list of possible Db level spacings
            _dbLegendSpacings = Defaults.dbLegendSpacings
            
//            // Click, LEFT in panadapter
//            _clickLeft = NSClickGestureRecognizer(target: self, action: #selector(clickLeft(_:)))
//            _clickLeft.buttonMask = kLeftButton
//            _clickLeft.numberOfClicksRequired = 2
//            _clickLeft.delegate = self
//            _dbLegendView.addGestureRecognizer(_clickLeft)
            
            // Click, RIGHT in panadapter
            _clickRight = NSClickGestureRecognizer(target: self, action: #selector(clickRight(_:)))
            _clickRight.buttonMask = kRightButton
            _clickRight.numberOfClicksRequired = 1
            _clickRight.delegate = self
            _dbLegendView.addGestureRecognizer(_clickRight)
            
            // Pan, LEFT in panadapter
            _panCenter = NSPanGestureRecognizer(target: self, action: #selector(panLeft(_:)))
            _panCenter.buttonMask = kLeftButton
            _panCenter.delegate = self
            _dbLegendView.addGestureRecognizer(_panCenter)
            
            // Pan, LEFT in Frequency legend
            _panBandwidth = NSPanGestureRecognizer(target: self, action: #selector(panLeft(_:)))
            _panBandwidth.buttonMask = kLeftButton
            _panBandwidth.delegate = self
            _frequencyLegendView.addGestureRecognizer(_panBandwidth)
            
            // pass a reference to the Panadapter
            _frequencyLegendView.configure(panadapter: _params.panadapter)
            _dbLegendView.configure(panadapter: _params.panadapter)
            
            setupObservations()
            
            _params.panadapter.fillLevel = Defaults.spectrumFillLevel
            
            // make the Renderer the Stream Handler
            _params.panadapter.delegate = _panadapterRenderer
            
        } else {
            
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "This Mac does not support Metal graphics."
            alert.informativeText = """
      Metal is required for the Panadapter & Waterfall displays.
      """
            alert.addButton(withTitle: "Ok")
            alert.runModal()
            NSApp.terminate(self)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    func configure(params: Params) {
        _params = params
    }
    /// start observations & Notification
    ///
    private func setupObservations() {
        
        // add notification subscriptions
        addNotifications()
        
        // begin observations (defaults, panadapter & radio)
        createBaseObservations(&_baseObservations)
    }
    
    // force a redraw of one of the views
    //
    func redrawFrequencyLegend() {
        _frequencyLegendView.redraw()
        positionFlags()
    }
    func redrawDbLegend() {
        _dbLegendView.redraw()
    }
    func redrawTnfs() {
        _frequencyLegendView.redraw()
    }
    func redrawSlices() {
        _frequencyLegendView.redraw()
    }
    /// Respond to Pan gesture (left mouse down)
    ///
    /// - Parameter gr:         the Pan Gesture Recognizer
    ///
    @objc func panLeft(_ gestureRecognizer: NSPanGestureRecognizer) {
        
        // ----------------------------------------------------------------------------
        // nested function to update layers
        func update(_ dragable: Dragable) {
            
            // call the appropriate function on the appropriate layer
            switch dragable.type {
            case .dbm:
                _dbLegendView.updateDbmLevel(dragable: dragable)
                
            case .frequency:
                _frequencyLegendView.updateBandwidth(dragable: dragable)
                
            case .slice:
                _frequencyLegendView.updateSlice(dragable: dragable)
                
            case .spectrum:
                _frequencyLegendView.updateCenter(dragable: dragable)
                
            case .tnf:
                _frequencyLegendView.updateTnf(dragable: dragable)
            }
        }
        // ----------------------------------------------------------------------------
        
        // get the current position
        _dragable.current = gestureRecognizer.location(in: view)
        
        // save the starting position
        if gestureRecognizer.state == .began {
            _dragable.original = _dragable.current
            
            // calculate start's percent of width & it's frequency
            _dragable.percent = _dragable.current.x / view.frame.width
            _dragable.frequency = (_dragable.percent * CGFloat(_params.bandwidth)) + CGFloat(_params.start)
            
            _dragable.object = nil
            
            // what type of drag?
            if _dragable.original.y < kFrequencyLegendHeight {
                
                // in frequency legend, bandwidth drag
                _dragable.type = .frequency
                _dragable.cursor = NSCursor.resizeLeftRight
                
            } else if _dragable.original.x < view.frame.width - kDbLegendWidth {
                
                // in spectrum, check for presence of Slice or Tnf
                let dragSlice = hitTestSlice(at: _dragable.frequency)
                let dragTnf = hitTestTnf(at: _dragable.frequency)
                if dragSlice != nil {
                    // in Slice - drag Slice / resize Slice Filter
                    _dragable.type = .slice
                    _dragable.object = dragSlice
                    _dragable.cursor = NSCursor.crosshair
                    
                } else if dragTnf != nil {
                    // in Tnf - drag Tnf / resize Tnf width
                    _dragable.type = .tnf
                    _dragable.object = dragTnf
                    _dragable.cursor = NSCursor.crosshair
                    
                } else {
                    // spectrum drag
                    _dragable.type = .spectrum
                    _dragable.cursor = NSCursor.resizeLeftRight
                }
            } else {
                // in db legend - db legend drag
                _dragable.type = .dbm
                _dragable.cursor = NSCursor.resizeUpDown
            }
        }
        // what portion of the drag are we in?
        switch gestureRecognizer.state {
        
        case .began:
            // set the cursor
            _dragable.cursor.push()
            
            // save the starting coordinate
            _dragable.previous = _dragable.current
            
        case .changed:
            // update the appropriate layer
            update(_dragable)
            
            // save the current (intermediate) location as the previous
            _dragable.previous = _dragable.current
            
        case .ended:
            // update the appropriate layer
            update(_dragable)
            
            // restore the previous cursor
            NSCursor.pop()
            
        default:
            // ignore other states
            break
        }
    }
    /// Prevent the Right Click recognizer from responding when the mouse is not over the Legend
    ///
    /// - Parameters:
    ///   - gr:           the Gesture Recognizer
    ///   - event:        the Event
    /// - Returns:        True = allow, false = ignore
    ///
    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldAttemptToRecognizeWith event: NSEvent) -> Bool {
        
        // is it a right click?
        if gestureRecognizer.action == #selector(clickRight(_:)) {
            
            // Right-Click, process it here if over the legend, otherwise push it up the responder chain
            let processHere = view.convert(event.locationInWindow, from: nil).x >= view.frame.width - kDbLegendWidth
            return processHere
            
        } else {
            
            // NOT Right-CLick, process it here
            return true
        }
    }
    /// Respond to Right-Click gesture
    ///     NOTE: will only receive events in db legend (see gestureRecognizer method above)
    ///
    /// - Parameter gr:         the Click Gesture Recognizer
    ///
    @objc func clickRight(_ gestureRecognizer: NSClickGestureRecognizer) {
        
        // update the Db Legend spacings
        _dbLegendView.updateLegendSpacing(gestureRecognizer: gestureRecognizer, in: view)
    }
    
//    /// Respond to Click-Left gesture
//    ///
//    /// - Parameter gr:         the Click Gesture Recognizer
//    ///
//    @objc func clickLeft(_ gestureRecognizer: NSClickGestureRecognizer) {
//        // get the coordinates and convert to this View
//        let mouseLocation = gestureRecognizer.location(in: view)
//        
//        // calculate the frequency
//        let clickFrequency = (mouseLocation.x * _hzPerUnit) + CGFloat(_params.start)
//        
//        // is there a Slice at the clickFrequency?
//        
//        // is there a Slice at the indicated freq?
//        if let slice = hitTestSlice(at: clickFrequency, thisPanOnly: true) {
//            // YES, make it active
//            activateSlice(slice)
//            
//            // is there a slice on this pan?
//        } else if let slice = Api.sharedInstance.radio!.findActiveSlice(on: _params.panadapter.id) {
//            
//            // YES, move it to the nearest step value
//            let delta = Int(clickFrequency) % slice.step
//            if delta >= slice.step / 2 {
//                // move it to the step value above the click
//                slice.frequency = Int(clickFrequency) + (slice.step - delta)
//                
//            } else {
//                
//                // move it to the step value below the click
//                slice.frequency = Int(clickFrequency) - delta
//            }
//        }
//        // redraw
//        redrawSlices()
//    }
    
    // Position Slice flags
    //
    func positionFlags() {
        var current  : (isOnLeft: Bool, freqPosition: CGFloat) = (true, 0.0)
        var previous : (isOnLeft: Bool, freqPosition: CGFloat) = (true, 0.0)
        
        DispatchQueue.main.async {
            // sort the Flags from left to right
            for flagVc in self._flags.values.sorted(by: {$0.slice!.frequency < $1.slice!.frequency}) {
                
                // calculate the frequency's position
                current.freqPosition = CGFloat(flagVc.slice!.frequency - self._params.start) / self._hzPerUnit
                
                let flagWidth = flagVc.smallFlagDisplayed ? FlagViewController.kSmallFlagWidth : FlagViewController.kLargeFlagWidth
                
                // is there room for the Flag on the left?
                if previous.isOnLeft {
                    current.isOnLeft = current.freqPosition - previous.freqPosition > flagWidth + FlagViewController.kFlagOffset
                } else {
                    current.isOnLeft = current.freqPosition - previous.freqPosition > 2 * (flagWidth + FlagViewController.kFlagOffset) + FlagViewController.kFlagMinimumSeparation
                }
                flagVc.isOnLeft = current.isOnLeft
                
                // Flag position based on room for it
                let flagPosition = (current.isOnLeft ? current.freqPosition - flagWidth - FlagViewController.kFlagOffset : current.freqPosition + FlagViewController.kFlagOffset)
                
                flagVc.flagXPositionConstraint?.isActive = false
                flagVc.flagXPositionConstraint?.constant = flagPosition
                flagVc.flagXPositionConstraint?.isActive = true
                
                // enable/disable the Split button on the Flag (a Split can't create another Split)
                flagVc.isaSplit = self.splitCheck(flagVc.slice!.id)
                // make the current State the previous one
                previous = current
            }
        }
    }
    
    func splitCheck(_ sliceId: SliceId) -> Bool {
        
        for flag in _flags where flag.value.splitId == sliceId {
            return true
        }
        return false
    }
    
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
    
    /// Find the Tnf at or near a frequency (if any)
    ///
    /// - Parameter freq:       the target frequency
    /// - Returns:              a tnf or nil
    ///
    private func hitTestTnf(at freq: CGFloat) -> Tnf? {
        var tnf: Tnf?
        
        // calculate a minimum width for hit testing
        let effectiveWidth = Hz( CGFloat(_params.bandwidth) * 0.01)
        
        _params.radio.tnfs.forEach {
            let halfWidth = max(effectiveWidth, $0.value.width/2)
            if $0.value.frequency - halfWidth <= UInt(freq) && $0.value.frequency + halfWidth >= UInt(freq) {
                tnf = $0.value
            }
        }
        return tnf
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    private var _baseObservations       = [NSKeyValueObservation]()
    private var _defaultsObservations   = [DefaultsDisposable]()
    private var _tnfObservations        = [NSKeyValueObservation]()
    
    /// Add observations of various properties used by the Panadapter
    ///
    private func createBaseObservations(_ observations: inout [NSKeyValueObservation]) {
        observations = [
            
            _params.panadapter.observe(\.bandwidth, options: [.initial, .new]) { [weak self] (_, _) in
                self?.redrawLegends() },
            _params.panadapter.observe(\.center, options: [.initial, .new]) { [weak self] (_, _) in
                self?.redrawLegends() },
            _params.radio.observe(\.tnfsEnabled, options: [.initial, .new]) { [weak self] (_, _) in
                self?.redrawLegends() },
            _params.panadapter.observe(\.fillLevel, options: [.initial, .new]) { [weak self] (_, _) in
                self?.fillLevel() }
        ]
        _defaultsObservations = [
            
            Defaults.observe(\.dbLegend, options: [.initial, .new]) { [weak self] _ in
                self?.redrawLegends() },
            Defaults.observe(\.marker, options: [.initial, .new]) { [weak self] _ in
                self?.redrawLegends() },
            Defaults.observe(\.dbLegendSpacing, options: [.initial, .new]) { [weak self] _ in
                self?.redrawLegends() },
            Defaults.observe(\.frequencyLegend, options: [.initial, .new]) { [weak self] _ in
                self?.redrawLegends() },
            Defaults.observe(\.sliceActive, options: [.initial, .new]) { [weak self] _ in
                self?.redrawLegends() },
            Defaults.observe(\.markersEnabled, options: [.initial, .new]) { [weak self] _ in
                self?.redrawLegends() },
            Defaults.observe(\.markerSegment, options: [.initial, .new]) { [weak self] _ in
                self?.redrawLegends() },
            Defaults.observe(\.markerEdge, options: [.initial, .new]) { [weak self] _ in
                self?.redrawLegends() },
            Defaults.observe(\.sliceFilter, options: [.initial, .new]) { [weak self] _ in
                self?.redrawLegends() },
            Defaults.observe(\.sliceInactive, options: [.initial, .new]) { [weak self] _ in
                self?.redrawLegends() },
            Defaults.observe(\.tnfActive, options: [.initial, .new]) { [weak self] _ in
                self?.redrawLegends() },
            Defaults.observe(\.tnfInactive, options: [.initial, .new]) { [weak self] _ in
                self?.redrawLegends() },
            Defaults.observe(\.gridLine, options: [.initial, .new]) { [weak self] _ in
                self?.redrawLegends() },
            Defaults.observe(\.spectrum, options: [.initial, .new]) { [weak self] _ in
                self?.defaultsObserver() },
            Defaults.observe(\.spectrumBackground, options: [.initial, .new]) { [weak self] _ in
                self?.defaultsObserver() }
        ]
    }
    
    /// Add observations of Tnf's used by the Panadapter
    ///
    private func addTnfObservations(_ observations: inout [NSKeyValueObservation], tnf: Tnf ) {
        observations.append( tnf.observe(\.frequency, options: [.initial, .new]) { [weak self] (_, _) in
                                self?.redrawFrequencyLegend() })
        observations.append( tnf.observe(\.depth, options: [.initial, .new]) { [weak self] (_, _) in
                                self?.redrawFrequencyLegend() })
        observations.append( tnf.observe(\.width, options: [.initial, .new]) { [weak self] (_, _) in
                                self?.redrawFrequencyLegend() })
        observations.append( tnf.observe(\.permanent, options: [.initial, .new]) { [weak self] (_, _) in
                                self?.redrawFrequencyLegend() })
    }
    
    /// Invalidate observations (optionally remove)
    ///
    /// - Parameters:
    ///   - observations:                 an array of NSKeyValueObservation
    ///   - remove:                       remove all enabled
    ///
    func invalidateObservations(_ observations: inout [NSKeyValueObservation], remove: Bool = true) {
        // invalidate each observation
        observations.forEach { $0.invalidate() }
        
        // if specified, remove the tokens
        if remove { observations.removeAll() }
    }
    
    /// Respond to Defaults observations
    ///
    /// - Parameters:
    ///   - object:                       the object holding the properties
    ///   - change:                       the change
    ///
    private func defaultsObserver() {
        DispatchQueue.main.async { [unowned self] in
            self._panadapterRenderer.updateColor(spectrumColor: Defaults.spectrum, fillLevel: self._params.panadapter.fillLevel, fillColor: Defaults.spectrum)
            
            // Panadapter background color
            self._panadapterView.clearColor = Defaults.spectrumBackground.metalClearColor
        }
    }
    
    /// Respond to Panadapter fillLevel observations
    ///
    private func fillLevel() {
        DispatchQueue.main.async { [unowned self] in
            self._panadapterRenderer.updateColor(spectrumColor: Defaults.spectrum, fillLevel: self._params.panadapter.fillLevel, fillColor: Defaults.spectrum)
            
            // Panadapter background color
            self._panadapterView.clearColor = Defaults.spectrumBackground.metalClearColor
            
        }
    }
    
    /// Respond to observations requiring a redraw of the entire Panadapter
    ///
    /// - Parameters:
    ///   - object:                       the object holding the properties
    ///   - change:                       the change
    ///
    private func redrawLegends() {
        _frequencyLegendView.redraw()
        _dbLegendView.redraw()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    /// Add subsciptions to Notifications
    ///     (as of 10.11, subscriptions are automatically removed on deinit when using the Selector-based approach)
    ///
    private func addNotifications() {
        
        NCtr.makeObserver(self, with: #selector(frameDidChange(_:)), of: NSView.frameDidChangeNotification.rawValue, object: view)
        //    NC.makeObserver(self, with: #selector(radioWillBeRemoved(_:)), of: .radioWillBeRemoved)
        // only receive removal Notifications sent by this view's Panadapter
        NCtr.makeObserver(self, with: #selector(panadapterWillBeRemoved(_:)), of: .panadapterWillBeRemoved, object: _params.panadapter)
        NCtr.makeObserver(self, with: #selector(tnfHasBeenAdded(_:)), of: .tnfHasBeenAdded)
        NCtr.makeObserver(self, with: #selector(tnfWillBeRemoved(_:)), of: .tnfWillBeRemoved)
        NCtr.makeObserver(self, with: #selector(sliceHasBeenAdded(_:)), of: .sliceHasBeenAdded)
    }
    
    /// Process frameDidChange Notification
    ///
    /// - Parameter note:       a Notification instance
    ///
    @objc private func frameDidChange(_ note: Notification) {
        // tell the Panadapter to tell the Radio the current dimensions
        _params.panadapter.xPixels = view.frame.width
        _params.panadapter.yPixels = view.frame.height
        
        // update the Constant values with the new size
        _panadapterRenderer.setConstants(size: view.frame.size)
        
        positionFlags()
    }

    /// Process .panadapterWillBeRemoved Notification
    ///
    /// - Parameter note:       a Notification instance
    ///
    @objc private func panadapterWillBeRemoved(_ note: Notification) {
        // does the Notification contain a Panadapter object?
        if let panadapter = note.object as? Panadapter {
            
            _panadapterView.isPaused = true
            
            // stop processing this Panadapter's stream
            panadapter.delegate = nil
            _frequencyLegendView = nil
            _dbLegendView = nil
            _panadapterView = nil
            
            // YES, log the event
            _params.log("Panadapter will be removed: id = \(panadapter.id.hex)", .info, #function, #file, #line)
            
            // invalidate Base property observations
            invalidateObservations(&_baseObservations)
        }
    }
    
    /// Process .sliceHasBeenAdded Notification
    ///
    /// - Parameter note:       a Notification instance
    ///
    @objc private func sliceHasBeenAdded(_ note: Notification) {
        // does the Notification contain a Slice object?
        if let slice = note.object as? xLib6000.Slice {
            
            // YES, is the slice on this Panadapter?
            if slice.panadapterId == _params.panadapter.id {
                
                // YES, log the event
                _params.log("Slice added: id = \(slice.id), Panadapter id = \(_params.panadapter.id.hex), Frequency = \(slice.frequency.hzToMhz)", .info, #function, #file, #line)
                
                // observe removal of this Slice
                NCtr.makeObserver(self, with: #selector(sliceWillBeRemoved(_:)), of: .sliceWillBeRemoved, object: slice)
                
                // add a Flag for this Slice
                sliceFlag(slice: slice, pan: _params.panadapter, viewController: self)
                
                activateSlice(slice)
                
                _frequencyLegendView.redraw()
                
                DispatchQueue.main.async { [weak self] in
                    self?.positionFlags()
                }
            }
        }
    }
    
    /// Process .sliceWillBeRemoved Notification
    ///
    /// - Parameter note:       a Notification instance
    ///
    @objc private func sliceWillBeRemoved(_ note: Notification) {
        // does the Notification contain a Slice object?
        if let slice = note.object as? xLib6000.Slice {
            
            // YES, is the slice on this Panadapter?
            if slice.panadapterId == _params.panadapter.id {
                
                // YES, log the event
                _params.log("Slice will be removed: id = \(slice.id), pan = \(_params.panadapter.id.hex), freq = \(slice.frequency)", .info, #function, #file, #line)
                
                // remove the Flag & Observations of this Slice
                removeFlag(for: slice)
                
                // force a redraw
                _frequencyLegendView.redraw()
            }
        }
    }
    
    /// Process .tnfHasBeenAdded Notification
    ///
    /// - Parameter note:       a Notification instance
    ///
    @objc private func tnfHasBeenAdded(_ note: Notification) {
        // does the Notification contain a Tnf object?
        if let tnf = note.object as? Tnf {
            
            // YES, log the event
            _params.log("Tnf added: Object id = \(tnf.id), frequency - \(tnf.frequency.hzToMhz)", .info, #function, #file, #line)
            
            // add observations for this Tnf
            addTnfObservations(&_tnfObservations, tnf: tnf)
            
            // force a redraw
            _frequencyLegendView.redraw()
        }
    }
    
    /// Process .tnfWillBeRemoved Notification
    ///
    /// - Parameter note:       a Notification instance
    ///
    @objc private func tnfWillBeRemoved(_ note: Notification) {
        // does the Notification contain a Tnf object?
        if let tnfToRemove = note.object as? Tnf {
            
            // YES, log the event
            _params.log("Tnf will be removed: id = \(tnfToRemove.id)", .info, #function, #file, #line)
            
            // invalidate & remove all of the Tnf observations
            invalidateObservations(&_tnfObservations)
            
            // put back all except the one being removed
            _params.radio.tnfs.forEach { if $0.value != tnfToRemove { addTnfObservations(&_tnfObservations, tnf: $0.value) } }
            
            // force a redraw
            _frequencyLegendView.redraw()
        }
    }
    
    /// Add a Flag to a Slice
    ///
    /// - Parameters:
    ///   - slice:                    a Slice
    ///   - pan:                      the Panadapter containing the Slice
    ///   - viewController:           the parent ViewController
    ///
    func sliceFlag(slice: xLib6000.Slice, pan: Panadapter, viewController: NSViewController) {
        DispatchQueue.main.async {
            // create a Flag with the Panadapter view controller as its parent
            let flagVc = FlagViewController.createFlag(for: slice, and: pan, on: viewController)
            
            // add it to the list of Flags
            self._flags[slice.id] = flagVc
            
            // determine the Flag x-position
            let freqPosition = CGFloat(flagVc.slice!.frequency - self._params.start) / self._hzPerUnit
            let flagPosition = freqPosition - FlagViewController.kLargeFlagWidth - FlagViewController.kFlagOffset
            
            // add the Flag to the view hierarchy
            FlagViewController.addFlag(flagVc,
                                       to: viewController.view,
                                       flagPosition: flagPosition,
                                       flagHeight: FlagViewController.kLargeFlagHeight,
                                       flagWidth: FlagViewController.kLargeFlagWidth)
        }
    }
    
    /// Remove the Flag on the specified Slice
    ///
    /// - Parameter id:             a Slice Id
    ///
    private func removeFlag(for slice: xLib6000.Slice) {        
        // get the Flag view controller
        let flagVc = _flags[slice.id]
        
        // remove all of the Flag's observations
        flagVc?.removeObservations()
        
        // remove it from the list of Flags
        _flags[slice.id] = nil
        
        DispatchQueue.main.async {
            // remove the Flag from the view hierarchy
            flagVc?.controlsVc?.view.removeFromSuperview()
            flagVc?.view.removeFromSuperview()
        }
    }
}
