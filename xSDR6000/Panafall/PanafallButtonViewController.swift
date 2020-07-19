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

final class PanafallButtonViewController    : NSViewController {

  static let kTimeout                       = 10
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties

  @IBOutlet private weak var buttonView     : PanafallButtonView!
  
  private var _p                            : Params!
  private var _popover                      : NSPopover?
  
  private let kPanafallEmbedIdentifier      = "PanafallEmbed"
  private let kBandPopoverIdentifier        = "BandPopover"
  private let kAntennaPopoverIdentifier     = "AntennaPopover"
  private let kDisplayPopoverIdentifier     = "DisplayPopover"
  private let kDaxPopoverIdentifier         = "DaxPopover"

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
      let panafallViewController = segue.destinationController as? PanafallViewController

      // pass needed parameters
      panafallViewController!.configure(params: _p)
            
      // save a reference to the panadapterViewController & waterfallViewController
      let panadapterViewController = panafallViewController!.splitViewItems[0].viewController as? PanadapterViewController
      panadapterViewController!.configure(params: _p)

      let waterfallViewController = panafallViewController!.splitViewItems[1].viewController as? WaterfallViewController
      waterfallViewController!.configure(params: _p)
      
    case kDisplayPopoverIdentifier:
      // pass needed parameters
      (segue.destinationController as! DisplayViewController).configure(params: _p)
      
    case kAntennaPopoverIdentifier:
      // pass the Popovers a reference to the panadapter
      (segue.destinationController as! AntennaViewController).configure(params: _p)
      
    case kBandPopoverIdentifier:
      // pass the Popovers a reference to the panadapter
      (segue.destinationController as! BandButtonViewController).configure(params: _p)

    case kDaxPopoverIdentifier:
      // pass the Popovers a reference to the panadapter
      (segue.destinationController as! DaxIqViewController).configure(params: _p)

    default:
      break
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  func configure(params: Params) {
    _p = params
  }

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Zoom + (decrease bandwidth)
  ///
  /// - Parameter sender:           the sender
  ///
  @IBAction func zoomPlus(_ sender: Any) {
    
    // are we near the minimum?
    if _p.bandwidth / 2 > _p.panadapter.minBw {
      
      // NO, make the bandwidth half of its current value
      _p.panadapter.bandwidth = _p.bandwidth / 2
      
    } else {
      
      // YES, make the bandwidth the minimum value
      _p.panadapter.bandwidth = _p.panadapter.minBw
    }
  }
  /// Zoom - (increase the bandwidth)
  ///
  /// - Parameter sender:           the sender
  ///
  @IBAction func zoomMinus(_ sender: Any) {
    // are we near the maximum?
    if _p.bandwidth * 2 > _p.panadapter.maxBw {
      
      // YES, make the bandwidth maximum value
      _p.panadapter.bandwidth = _p.panadapter.maxBw
      
    } else {
      
      // NO, make the bandwidth twice its current value
      _p.panadapter.bandwidth = _p.bandwidth * 2
    }
  }
  /// Zoom to Segment
  ///
  /// - Parameter sender:           the sender
  ///
  @IBAction func zoomSegment(_ sender: NSButton) {
    _p.panadapter.segmentZoomEnabled = !_p.panadapter.segmentZoomEnabled
  }
  /// Zoom to Band
  ///
  /// - Parameter sender:           the sender
  ///
  @IBAction func zoomBand(_ sender: NSButton) {
    _p.panadapter.bandZoomEnabled = !_p.panadapter.bandZoomEnabled
  }
  
  /// Close this Panafall
  ///
  /// - Parameter sender:           the sender
  ///
  @IBAction func close(_ sender: NSButton) {
    
    buttonView.removeTrackingArea()
    
    // tell the Radio to remove this Panafall
    _p.panadapter.remove()
  }
  /// Create a new Slice (if possible)
  ///
  /// - Parameter sender:           the sender
  ///
  @IBAction func rx(_ sender: NSButton) {
    
    // tell the Radio (hardware) to add a Slice on this Panadapter
    _p.radio.requestSlice(panadapter: _p.panadapter)
  }
  /// Create a new Tnf
  ///
  /// - Parameter sender:           the sender
  ///
  @IBAction func tnf(_ sender: NSButton) {
    var frequency : Hz = 0
    
    if let slice = _p.radio.findActiveSlice(on: _p.panadapter.id) {
      // put the Tnf in the center of the active Slice
      frequency = Hz(Int(slice.frequency) + (slice.filterHigh - slice.filterLow) / 2)

    } else {
      // put the Tnf in the center of the Panadapter
      frequency = _p.panadapter.center
    }
    // tell the Radio to add a Tnf on this Panadapter
    _p.radio.requestTnf(at: frequency)
  }
}
