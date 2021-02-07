//
//  PanafallButtonViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 6/9/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - Panafall Button View Controller class implementation
// --------------------------------------------------------------------------------

final class PanafallButtonViewController: NSViewController {
    // swiftlint:disable colon
    
    static let kTimeout                       = 10
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var buttonView     : PanafallButtonView!
    
    private var _params                       : Params!
    private var _popover                      : NSPopover?
    
    private let kPanafallEmbedIdentifier      = "PanafallEmbed"
    private let kBandPopoverIdentifier        = "BandPopover"
    private let kAntennaPopoverIdentifier     = "AntennaPopover"
    private let kDisplayPopoverIdentifier     = "DisplayPopover"
    private let kDaxPopoverIdentifier         = "DaxPopover"
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// Prepare to execute a Segue
    ///
    /// - Parameters:
    ///   - segue: a Segue instance
    ///   - sender: the sender
    ///
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        
        _popover = segue.destinationController as? NSPopover
        
        switch segue.identifier! {
        
        case kPanafallEmbedIdentifier:                            // this will always occur first
            // save a reference to the Panafall view controller
            if let panafallViewController = segue.destinationController as? PanafallViewController {
                panafallViewController.configure(params: _params)

                // save a reference to the panadapterViewController & waterfallViewController
                if let panadapterViewController = panafallViewController.splitViewItems[0].viewController as? PanadapterViewController {
                    panadapterViewController.configure(params: _params)
                }
                if let waterfallViewController = panafallViewController.splitViewItems[1].viewController as? WaterfallViewController {
                    waterfallViewController.configure(params: _params)
                }
            }
        case kDisplayPopoverIdentifier:
            if let displayViewController = segue.destinationController as? DisplayViewController {
                displayViewController.configure(params: _params)
            }
        case kAntennaPopoverIdentifier:
            if let antennaViewController = segue.destinationController as? AntennaViewController {
                antennaViewController.configure(params: _params)
            }
        case kBandPopoverIdentifier:
            if let bandButtonViewController = segue.destinationController as? BandButtonViewController {
                bandButtonViewController.configure(params: _params)
            }
        case kDaxPopoverIdentifier:
            if let daxIqViewController = segue.destinationController as? DaxIqViewController {
                daxIqViewController.configure(params: _params)
            }
        default:
            break
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    func configure(params: Params) {
        _params = params
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    /// Zoom + (decrease bandwidth)
    ///
    /// - Parameter sender:           the sender
    ///
    @IBAction func zoomPlus(_ sender: Any) {
        
        // are we near the minimum?
        if _params.bandwidth / 2 > _params.panadapter.minBw {
            
            // NO, make the bandwidth half of its current value
            _params.panadapter.bandwidth = _params.bandwidth / 2
            
        } else {
            
            // YES, make the bandwidth the minimum value
            _params.panadapter.bandwidth = _params.panadapter.minBw
        }
    }
    /// Zoom - (increase the bandwidth)
    ///
    /// - Parameter sender:           the sender
    ///
    @IBAction func zoomMinus(_ sender: Any) {
        // are we near the maximum?
        if _params.bandwidth * 2 > _params.panadapter.maxBw {
            
            // YES, make the bandwidth maximum value
            _params.panadapter.bandwidth = _params.panadapter.maxBw
            
        } else {
            
            // NO, make the bandwidth twice its current value
            _params.panadapter.bandwidth = _params.bandwidth * 2
        }
    }
    /// Zoom to Segment
    ///
    /// - Parameter sender:           the sender
    ///
    @IBAction func zoomSegment(_ sender: NSButton) {
        _params.panadapter.segmentZoomEnabled = !_params.panadapter.segmentZoomEnabled
    }
    /// Zoom to Band
    ///
    /// - Parameter sender:           the sender
    ///
    @IBAction func zoomBand(_ sender: NSButton) {
        _params.panadapter.bandZoomEnabled = !_params.panadapter.bandZoomEnabled
    }
    
    /// Close this Panafall
    ///
    /// - Parameter sender:           the sender
    ///
    @IBAction func close(_ sender: NSButton) {
        
        buttonView.removeTrackingArea()
        
        // tell the Radio to remove this Panafall
        _params.panadapter.remove()
    }
    /// Create a new Slice (if possible)
    ///
    /// - Parameter sender:           the sender
    ///
    @IBAction func rx(_ sender: NSButton) {
        
        // tell the Radio (hardware) to add a Slice on this Panadapter
        _params.radio.requestSlice(panadapter: _params.panadapter)
    }
    /// Create a new Tnf
    ///
    /// - Parameter sender:           the sender
    ///
    @IBAction func tnf(_ sender: NSButton) {
        var frequency: Hz = 0
        
        if let slice = _params.radio.findActiveSlice(on: _params.panadapter.id) {
            // put the Tnf in the center of the active Slice
            frequency = Hz(Int(slice.frequency) + (slice.filterHigh - slice.filterLow) / 2)
            
        } else {
            // put the Tnf in the center of the Panadapter
            frequency = _params.panadapter.center
        }
        // tell the Radio to add a Tnf on this Panadapter
        _params.radio.requestTnf(at: frequency)
    }
}
