//
//  PanafallViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/14/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - Panafall View Controller class implementation
// --------------------------------------------------------------------------------

final class PanafallViewController: NSSplitViewController, NSGestureRecognizerDelegate {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Static properties
    
    static let kEdgeTolerance                 : CGFloat = 0.1                 // percent of bandwidth
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    enum DragType {
        case dbm        // +/- Panadapter dbm upper/lower level
        case frequency  // +/- Panadapter bandwidth
        case slice      // +/- Slice frequency/width
        case spectrum   // +/- Panadapter center frequency
        case tnf        // +/- Tnf frequency/width
        case none
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

    @IBOutlet private weak var _panadapterSplitViewItem: NSSplitViewItem!
    @IBOutlet private weak var _waterfallSplitViewItem: NSSplitViewItem!

    private var _params                       : Params!
    private var _hzPerUnit                    : CGFloat { CGFloat(_params.end - _params.start) / view.frame.width }
    
    private weak var _panadapterViewController  : PanadapterViewController? { _panadapterSplitViewItem.viewController as? PanadapterViewController }
    private weak var _waterfallViewController   : WaterfallViewController? { _waterfallSplitViewItem.viewController as? WaterfallViewController }

    private var _dragable                     = Dragable()
    private var _rightSingleClickPanadapter   : NSClickGestureRecognizer!
    private var _rightSingleClickWaterfall    : NSClickGestureRecognizer!
    private var _dragLeftButtonPanadapter     : NSPanGestureRecognizer!
    private var _dragLeftButtonWaterfall      : NSPanGestureRecognizer!
    private var _panBandwidth                 : NSPanGestureRecognizer!
    private var _panRightButton               : NSPanGestureRecognizer!
    private var _panStart                     : NSPoint?

    private let kLeftButton                   = 0x01                          // masks for Gesture Recognizers
    private let kRightButton                  = 0x02
    private let kButtonViewWidth              : CGFloat = 75                  // Width of ButtonView when open
    private let kCreateSlice                  = "Create Slice"                // Menu titles
    private let kRemoveSlice                  = "Remove Slice"
    private let kCreateTnf                    = "Create Tnf"
    private let kRemoveTnf                    = "Remove Tnf"
    private let kPermanentTnf                 = "Permanent"
    private let kNormalTnf                    = "Normal"
    private let kDeepTnf                      = "Deep"
    private let kVeryDeepTnf                  = "Very Deep"
    private let kTnfFindWidth: CGFloat        = 0.01                          // * bandwidth = Tnf tolerance multiplier
    private let kSliceFindWidth: CGFloat      = 0.01                          // * bandwidth = Slice tolerance multiplier

    private let kDbLegendWidth                : CGFloat = 40                // width of Db legend
    private let kFrequencyLegendHeight        : CGFloat = 20                // height of the Frequency legend

    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.delegate = self
        splitViewItems.forEach { $0.minimumThickness = 20 }
        
        // Right-Button, Single-Click, Panadapter - presents context menu
        _rightSingleClickPanadapter = NSClickGestureRecognizer(target: self, action: #selector(rightSingleClick(_:)))
        _rightSingleClickPanadapter.buttonMask = kRightButton
        _rightSingleClickPanadapter.numberOfClicksRequired = 1
        _panadapterViewController?.view.addGestureRecognizer(_rightSingleClickPanadapter)
        
        // Right-Button, Single-Click, Waterfall - presents context menu
        _rightSingleClickWaterfall = NSClickGestureRecognizer(target: self, action: #selector(rightSingleClick(_:)))
        _rightSingleClickWaterfall.buttonMask = kRightButton
        _rightSingleClickWaterfall.numberOfClicksRequired = 1
        _waterfallViewController?.view.addGestureRecognizer(_rightSingleClickWaterfall)

        // Left-Button, Drag, Panadapter - move slice / center
        _dragLeftButtonPanadapter = NSPanGestureRecognizer(target: self, action: #selector(dragLeftButton(_:)))
        _dragLeftButtonPanadapter.buttonMask = kLeftButton
        _dragLeftButtonPanadapter.delegate = self
        _panadapterViewController?.view.addGestureRecognizer(_dragLeftButtonPanadapter)

        // Left-Button, Drag, Waterfall - move slice / center
        _dragLeftButtonWaterfall = NSPanGestureRecognizer(target: self, action: #selector(dragLeftButton(_:)))
        _dragLeftButtonWaterfall.buttonMask = kLeftButton
        _dragLeftButtonWaterfall.delegate = self
        _waterfallViewController?.view.addGestureRecognizer(_dragLeftButtonWaterfall)

        // save the divider position
        splitView.autosaveName = "Panadapter \(_params.panadapter.id.hex)"
    }
    
    override func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        return false
    }
    
    /// Process scroll wheel events to change the Active Slice frequency
    ///
    /// - Parameter theEvent: a Scroll Wheel event
    ///
    override func scrollWheel(with theEvent: NSEvent) {
        // ignore events not in the Y direction
        if theEvent.deltaY != 0 {
            
            // find the Active Slice
            if let slice = Api.sharedInstance.radio!.findActiveSlice(on: _params.panadapter.id) {
                
                // use the Slice's step value, unless the Shift key is down
                var step = slice.step
                if theEvent.modifierFlags.contains(.shift) && !theEvent.modifierFlags.contains(.option) {
                    // step value when the Shift key is down
                    step = 100
                } else if theEvent.modifierFlags.contains(.option) && !theEvent.modifierFlags.contains(.shift) {
                    // step value when the Option key is down
                    step = 10
                } else if theEvent.modifierFlags.contains(.option)  && theEvent.modifierFlags.contains(.shift) {
                    // step value when the Option and Shift keys are down
                    step = 1
                }
                var incr = 0
                // is scrolling "natural" or "classic" (as set in macOS System Preferences)
                if theEvent.isDirectionInvertedFromDevice {
                    // natural
                    incr = theEvent.deltaY < 0 ? step : -step
                } else {
                    // classic
                    incr = theEvent.deltaY < 0 ? -step : step
                }
                // update the frequency
                adjustSliceFrequency(slice, incr: incr)
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    func configure(params: Params) {
        _params = params
    }
    
    func redrawSlices() {
        _panadapterViewController?.redrawSlices()
    }
    
    /// Respond to Pan gesture (left mouse down)
    /// - Parameter gr:         the Pan Gesture Recognizer
    ///
    @objc func dragLeftButton(_ gestureRecognizer: NSPanGestureRecognizer) {
        
        // ----------------------------------------------------------------------------
        // nested function to update layers
        func update(_ dragable: Dragable) {            
            // call the appropriate function on the appropriate layer
            switch dragable.type {

            case .dbm:          _panadapterViewController?.updateDbmLevel(dragable: dragable)
            case .frequency:    _panadapterViewController?.updateBandwidth(dragable: dragable)
            case .slice:        _panadapterViewController?.updateSlice(dragable: dragable)
            case .spectrum:     _panadapterViewController?.updateCenter(dragable: dragable)
            case .tnf:          _panadapterViewController?.updateTnf(dragable: dragable)
            case .none:         break
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
                if gestureRecognizer === _dragLeftButtonPanadapter {
                    _dragable.type = .dbm
                    _dragable.cursor = NSCursor.resizeUpDown
                } else {
                    _dragable.type = .none
                    gestureRecognizer.state = .ended
                }
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
 
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Respond to a Right Click gesture
    ///
    /// - Parameter gr: the GestureRecognizer
    ///
    @objc private func rightSingleClick(_ gestureRecognizer: NSClickGestureRecognizer) {
        var item: NSMenuItem!
        var index = 0
        
        // get the "click" coordinates and convert to this View
        let mouseLocation = gestureRecognizer.location(in: splitView)
        
        // create the popup menu
        let menu = NSMenu(title: "Panadapter")
        
        // calculate the frequency
        let mouseFrequency = Int(mouseLocation.x * _hzPerUnit) + _params.start
        
        // is the Frequency inside a Slice?
        let slice = Api.sharedInstance.radio!.findSlice(on: _params.panadapter.id, at: mouseFrequency, width: Int( CGFloat(_params.bandwidth) * kSliceFindWidth ))
        if let slice = slice {
            
            // YES, mouse is in a Slice
            item = menu.insertItem(withTitle: kRemoveSlice, action: #selector(contextMenu(_:)), keyEquivalent: "", at: index)
            item.representedObject = slice
            item.target = self
            
        } else {
            
            // NO, mouse is not in a Slice
            item = menu.insertItem(withTitle: kCreateSlice, action: #selector(contextMenu(_:)), keyEquivalent: "", at: index)
            item.representedObject = NSNumber(value: mouseFrequency)
            item.target = self
        }
        
        // is the Frequency inside a Tnf?
        let tnf = Api.sharedInstance.radio!.findTnf(at: Hz(mouseFrequency), minWidth: Hz( CGFloat(_params.bandwidth) * kTnfFindWidth ))
        if let tnf = tnf {
            // YES, mouse is in a TNF
            index += 1
            menu.insertItem(NSMenuItem.separator(), at: index)
            
            index += 1
            item = menu.insertItem(withTitle: tnf.frequency.hzToMhz + " MHz", action: nil, keyEquivalent: "", at: index)
            
            index += 1
            item = menu.insertItem(withTitle: "Width: \(tnf.width) Hz", action: nil, keyEquivalent: "", at: index)
            
            index += 1
            menu.insertItem(NSMenuItem.separator(), at: 4)
            
            index += 1
            item = menu.insertItem(withTitle: kRemoveTnf, action: #selector(contextMenu(_:)), keyEquivalent: "", at: index)
            item.representedObject = tnf
            item.target = self
            
            index += 1
            menu.insertItem(NSMenuItem.separator(), at: 2)
            
            index += 1
            item = menu.insertItem(withTitle: kPermanentTnf, action: #selector(contextMenu(_:)), keyEquivalent: "", at: index)
            item.state = tnf.permanent ? NSControl.StateValue.on : NSControl.StateValue.off
            item.representedObject = tnf
            item.target = self
            
            index += 1
            item = menu.insertItem(withTitle: kNormalTnf, action: #selector(contextMenu(_:)), keyEquivalent: "", at: index)
            item.state = (tnf.depth == Tnf.Depth.normal.rawValue) ? NSControl.StateValue.on : NSControl.StateValue.off
            item.representedObject = tnf
            item.target = self
            
            index += 1
            item = menu.insertItem(withTitle: kDeepTnf, action: #selector(contextMenu(_:)), keyEquivalent: "", at: index)
            item.state = (tnf.depth == Tnf.Depth.deep.rawValue) ? NSControl.StateValue.on : NSControl.StateValue.off
            item.representedObject = tnf
            item.target = self
            
            index += 1
            item = menu.insertItem(withTitle: kVeryDeepTnf, action: #selector(contextMenu(_:)), keyEquivalent: "", at: index)
            item.state = (tnf.depth == Tnf.Depth.veryDeep.rawValue) ? NSControl.StateValue.on : NSControl.StateValue.off
            item.representedObject = tnf
            item.target = self
            
        } else {
            
            // NO, mouse is not in a TNF
            index += 1
            item = menu.insertItem(withTitle: kCreateTnf, action: #selector(contextMenu(_:)), keyEquivalent: "", at: index)
            item.representedObject = NSNumber(value: Float(mouseFrequency))
            item.target = self
        }
        
        // display the popup
        menu.popUp(positioning: menu.item(at: 0), at: mouseLocation, in: splitView)
        
    }
    /// Perform the appropriate action
    ///
    /// - Parameter sender: a MenuItem
    ///
    @objc private func contextMenu(_ sender: NSMenuItem) {
        
        switch sender.title {
        
        case kCreateSlice:        // tell the Radio to create a new Slice
            if let frequency = sender.representedObject as? NSNumber {
                _params.radio.requestSlice(panadapter: _params.panadapter, frequency: frequency.intValue)
            }
            
        case kRemoveSlice:        // tell the Radio to remove the Slice
            if let slice = sender.representedObject as? xLib6000.Slice {
                slice.remove()
            }
            
        case kCreateTnf:          // tell the Radio to create a new Tnf
            if let frequency = sender.representedObject as? NSNumber {
                _params.radio.requestTnf(at: frequency.intValue)
            }
        case kRemoveTnf:    if let tnf = sender.representedObject as? Tnf { tnf.remove() }
        case kPermanentTnf: if let tnf = sender.representedObject as? Tnf { tnf.permanent.toggle() }
        case kNormalTnf:    if let tnf = sender.representedObject as? Tnf { tnf.depth = Tnf.Depth.normal.rawValue }
        case kDeepTnf:      if let tnf = sender.representedObject as? Tnf { tnf.depth = Tnf.Depth.deep.rawValue }
        case kVeryDeepTnf:  if let tnf = sender.representedObject as? Tnf { tnf.depth = Tnf.Depth.veryDeep.rawValue }

        default:
            break
        }
    }
    /// Incr/decr the Slice frequency (scroll panafall at edges)
    ///
    /// - Parameters:
    ///   - slice: the Slice
    ///   - incr: frequency step
    ///
    private func adjustSliceFrequency(_ slice: xLib6000.Slice, incr: Int) {
        var isTooClose = false
        
        // is the existing frequency a multiple of the incr?
        if slice.frequency % incr == 0 {
            // YES, adjust the slice frequency by the incr value
            slice.frequency += incr
            
        } else {
            // NO, adjust to the nearest multiple of the incr
            var normalizedFreq = Double(slice.frequency) / Double(incr)
            if incr > 0 {
                // moving higher, adjust the slice frequency
                normalizedFreq.round(.toNearestOrAwayFromZero)
                
            } else {
                // moving lower, adjust the slice frequency
                normalizedFreq.round(.towardZero)
            }
            slice.frequency = Hz(normalizedFreq * Double(incr))
        }
        // decide whether to move the panadapter center
        let center = ((slice.frequency + slice.filterHigh) + (slice.frequency + slice.filterLow))/2
        // moving which way?
        if incr > 0 {
            // UP, too close to the high end?
            isTooClose = center > _params.end - Int(PanafallViewController.kEdgeTolerance * CGFloat(_params.bandwidth))
            
        } else {
            // DOWN, too close to the low end?
            isTooClose = center + incr < _params.start + Int(PanafallViewController.kEdgeTolerance * CGFloat(_params.bandwidth))
        }
        // is the new freq too close to an edge?
        if isTooClose {
            // YES, adjust the panafall center frequency (scroll the Panafall)
            _params.panadapter.center += incr
            
            _panadapterViewController?.redrawFrequencyLegend()
        }
        // redraw all the slices
        _panadapterViewController?.redrawSlices()
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
}
