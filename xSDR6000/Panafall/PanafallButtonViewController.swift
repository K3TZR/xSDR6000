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
  
  private weak var _radio                   : Radio?
  private weak var _panadapter              : Panadapter?
  private weak var _waterfall               : Waterfall?
  private var _bandwidth                    : Hz { _panadapter!.bandwidth }
  private var _popover                      : NSPopover?
  
  private let kPanafallEmbedIdentifier      = "PanafallEmbed"
  private let kBandPopoverIdentifier        = "BandPopover"
  private let kAntennaPopoverIdentifier     = "AntennaPopover"
  private let kDisplayPopoverIdentifier     = "DisplayPopover"
  private let kDaxPopoverIdentifier         = "DaxPopover"
  
  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func awakeFromNib() {
    super.awakeFromNib()
    
  }
  
  
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
      panafallViewController!.configure(radio: _radio, panadapter: _panadapter)
            
      // save a reference to the panadapterViewController & waterfallViewController
      let panadapterViewController = panafallViewController!.splitViewItems[0].viewController as? PanadapterViewController
      panadapterViewController!.configure(panadapter: _panadapter)

      let waterfallViewController = panafallViewController!.splitViewItems[1].viewController as? WaterfallViewController
      waterfallViewController!.configure(panadapter: _panadapter, waterfall: _waterfall)
      
    case kDisplayPopoverIdentifier:
      
      // pass needed parameters
      (segue.destinationController as! DisplayViewController).configure(panadapter: _panadapter!, waterfall: _waterfall!)
      
    case kAntennaPopoverIdentifier, kBandPopoverIdentifier, kDaxPopoverIdentifier:
      
      // pass the Popovers a reference to the panadapter
      (segue.destinationController as! NSViewController).representedObject = _panadapter
      
    default:
      break
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  /// Configure needed parameters
  ///
  /// - Parameter panadapter:               a Panadapter reference
  ///
  func configure(radio: Radio, panadapter: Panadapter, waterfall: Waterfall) {
    
    _radio = radio
    _panadapter = panadapter
    _waterfall = waterfall
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Zoom + (decrease bandwidth)
  ///
  /// - Parameter sender:           the sender
  ///
  @IBAction func zoomPlus(_ sender: Any) {
    
    // are we near the minimum?
    if _bandwidth / 2 > _panadapter!.minBw {
      
      // NO, make the bandwidth half of its current value
      _panadapter!.bandwidth = _bandwidth / 2
      
    } else {
      
      // YES, make the bandwidth the minimum value
      _panadapter!.bandwidth = _panadapter!.minBw
    }
  }
  /// Zoom - (increase the bandwidth)
  ///
  /// - Parameter sender:           the sender
  ///
  @IBAction func zoomMinus(_ sender: Any) {
    // are we near the maximum?
    if _bandwidth * 2 > _panadapter!.maxBw {
      
      // YES, make the bandwidth maximum value
      _panadapter!.bandwidth = _panadapter!.maxBw
      
    } else {
      
      // NO, make the bandwidth twice its current value
      _panadapter!.bandwidth = _bandwidth * 2
    }
  }
  /// Zoom to Segment
  ///
  /// - Parameter sender:           the sender
  ///
  @IBAction func zoomSegment(_ sender: NSButton) {
    _panadapter!.segmentZoomEnabled = !_panadapter!.segmentZoomEnabled
  }
  /// Zoom to Band
  ///
  /// - Parameter sender:           the sender
  ///
  @IBAction func zoomBand(_ sender: NSButton) {
    _panadapter!.bandZoomEnabled = !_panadapter!.bandZoomEnabled
  }
  
  /// Close this Panafall
  ///
  /// - Parameter sender:           the sender
  ///
  @IBAction func close(_ sender: NSButton) {
    
    buttonView.removeTrackingArea()
    
    // tell the Radio to remove this Panafall
    _panadapter!.remove()
  }
  /// Create a new Slice (if possible)
  ///
  /// - Parameter sender:           the sender
  ///
  @IBAction func rx(_ sender: NSButton) {
    
    // tell the Radio (hardware) to add a Slice on this Panadapter
    _radio?.requestSlice(panadapter: _panadapter!)
  }
  /// Create a new Tnf
  ///
  /// - Parameter sender:           the sender
  ///
  @IBAction func tnf(_ sender: NSButton) {
    var frequency : Hz = 0
    
    if let slice = _radio?.findActiveSlice(on: _panadapter!.id) {
      // put the Tnf in the center of the active Slice
      frequency = Hz(Int(slice.frequency) + (slice.filterHigh - slice.filterLow) / 2)

    } else {
      // put the Tnf in the center of the Panadapter
      frequency = _panadapter!.center
    }
    // tell the Radio to add a Tnf on this Panadapter
    _radio?.requestTnf(at: frequency)
  }
}
