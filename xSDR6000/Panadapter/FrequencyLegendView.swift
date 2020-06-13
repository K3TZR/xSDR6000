//
//  FrequencyLegendView.swift
//  xSDR6000
//
//  Created by Douglas Adams on 9/30/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

// --------------------------------------------------------------------------------
//  Created by PanafallsViewController
//  Removed by WaterfallViewController
//
//  **** Notifications received ****
//      None
//
//  **** Action Methods ****
//      None
//
//  **** Observations ****
//      None
//
//  **** Constraints manipulated ***
//      None
//
// --------------------------------------------------------------------------------

public final class FrequencyLegendView      : NSView {
  
  typealias BandwidthParamTuple = (high: Int, low: Int, spacing: Int, format: String)

  static let alpha : CGFloat = 0.3
    
  static let green    = NSColor(srgbRed: 0.0, green: 1.0, blue: 0.0, alpha: alpha)
  static let yellow   = NSColor(srgbRed: 1.0, green: 1.0, blue: 0.0, alpha: alpha)
  static let blue     = NSColor(srgbRed: 0.0, green: 0.0, blue: 1.0, alpha: alpha)
  static let red      = NSColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: alpha)
  static let gray     = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: alpha)
  static let brown    = NSColor(srgbRed: 0.0, green: 1.0, blue: 1.0, alpha: alpha)
  static let purple   = NSColor(srgbRed: 1.0, green: 0.0, blue: 1.0, alpha: alpha)
  

  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  weak var radio                            = Api.sharedInstance.radio
  
  var legendHeight                          : CGFloat = 20                  // height of legend area
  var font                                  = NSFont(name: "Monaco", size: 12.0)
  var markerHeight                          : CGFloat = 0.6                 // height % for band markers
  var shadingPosition                       : CGFloat = 21
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties

  private weak var _panadapter              : Panadapter?
  private var _center                       : Int { _panadapter!.center }
  private var _bandwidth                    : Int { _panadapter!.bandwidth }
  private var _start                        : Int { _center - (_bandwidth/2) }
  private var _end                          : Int  { _center + (_bandwidth/2) }
  private var _hzPerUnit                    : CGFloat { CGFloat(_end - _start) / self.frame.width }
  
  private var _bandwidthParam               : BandwidthParamTuple {  // given Bandwidth, return a Spacing & a Format
    get { return kBandwidthParams.filter { $0.high > _bandwidth && $0.low <= _bandwidth }.first ?? kBandwidthParams[0] } }
  
  private var _attributes                   = [NSAttributedString.Key:AnyObject]() // Font & Size for the Frequency Legend
  private var _path                         = NSBezierPath()
  private lazy var _segments                = Band.sharedInstance.segments

  private let kBandwidthParams: [BandwidthParamTuple] =                     // spacing & format vs Bandwidth
    [   //      Bandwidth               Legend
      //  high         low      spacing   format
      (15_000_000, 10_000_000, 1_000_000, "%0.0f"),           // 15.00 -> 10.00 Mhz
      (10_000_000,  5_000_000,   400_000, "%0.1f"),           // 10.00 ->  5.00 Mhz
      ( 5_000_000,   2_000_000,  200_000, "%0.1f"),           //  5.00 ->  2.00 Mhz
      ( 2_000_000,   1_000_000,  100_000, "%0.1f"),           //  2.00 ->  1.00 Mhz
      ( 1_000_000,     500_000,   50_000, "%0.2f"),           //  1.00 ->  0.50 Mhz
      (   500_000,     400_000,   40_000, "%0.2f"),           //  0.50 ->  0.40 Mhz
      (   400_000,     200_000,   20_000, "%0.2f"),           //  0.40 ->  0.20 Mhz
      (   200_000,     100_000,   10_000, "%0.2f"),           //  0.20 ->  0.10 Mhz
      (   100_000,      40_000,    4_000, "%0.3f"),           //  0.10 ->  0.04 Mhz
      (    40_000,      20_000,    2_000, "%0.3f"),           //  0.04 ->  0.02 Mhz
      (    20_000,      10_000,    1_000, "%0.3f"),           //  0.02 ->  0.01 Mhz
      (    10_000,       5_000,      500, "%0.4f"),           //  0.01 ->  0.005 Mhz
      (    5_000,            0,      400, "%0.4f")            //  0.005 -> 0 Mhz
  ]
  private let _frequencyLineWidth           : CGFloat = 2.0
  private let _lineColor                    = NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.2)
  private let _segmentColors                = [green, yellow, blue, red, gray, brown, purple]

  private let kMultiplier                   : CGFloat = 0.001

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  public override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    
    if let panadapter = _panadapter {
      
      drawSlices(panadapter)
      
      drawTnfs()
      
      // draw the Frequency legend and vertical grid lines
      drawLegend(dirtyRect)
      
      // draw band markers (if shown)
      if Defaults.markersEnabled { drawBandMarkers() }
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  /// Configure needed parameters
  ///
  /// - Parameter panadapter:               a Panadapter reference
  ///
  func configure(panadapter: Panadapter?) {
    self._panadapter = panadapter
  }
  /// Process a bandwidth drag
  ///
  /// - Parameter dr:         the draggable
  ///
  func updateBandwidth(dragable dr: PanadapterViewController.Dragable) {
    
    // CGFloat versions of params
    let end = CGFloat(_end)                     // end frequency (Hz)
    let start = CGFloat(_start)                 // start frequency (Hz)
    let bandwidth = CGFloat(_bandwidth)         // bandwidth (hz)
    
    // calculate the % change, + = greater bw, - = lesser bw
    let delta = ((dr.previous.x - dr.current.x) / frame.width)
    
    // calculate the new bandwidth (Hz)
    let newBandwidth = (1 + delta) * bandwidth
    
    // calculate adjustments to start & end
    let adjust = (newBandwidth - bandwidth) / 2.0
    let newStart = start - adjust
    let newEnd = end + adjust
    
    // calculate adjustment to the center
    let newStartPercent = (dr.frequency - newStart) / newBandwidth
    let freqError = (newStartPercent - dr.percent) * newBandwidth
    let newCenter = (newStart + freqError) + (newEnd - newStart) / 2.0
    
    // adjust the center & bandwidth values (Hz)
    _panadapter!.center = Int(newCenter)
    _panadapter!.bandwidth = Int(newBandwidth)
    
    // redraw the frequency legend
    redraw()
  }
  /// Process a center frequency drag
  ///
  /// - Parameter dr:       the draggable
  ///
  func updateCenter(dragable dr: PanadapterViewController.Dragable) {
    
    // adjust the center
    _panadapter!.center = _panadapter!.center - Int( (dr.current.x - dr.previous.x) * _hzPerUnit)
    
    // redraw the frequency legend
    redraw()
  }
  /// Process a Tnf drag
  ///
  /// - Parameter dr:         the draggable
  ///
  func updateTnf(dragable dr: PanadapterViewController.Dragable) {
    
    // calculate offsets in x & y
    let deltaX = dr.current.x - dr.previous.x
    let deltaY = dr.current.y - dr.previous.y
    
    // is there a tnf object?
    if let tnf = dr.object as? Tnf {
      
      // YES, drag or resize?
      if abs(deltaX) > abs(deltaY) {
        
        // drag
        tnf.frequency = Hz(dr.current.x * _hzPerUnit) + _start
      } else {
        
        // resize
//        tnf.width = UInt( max( Int(tnf.width) + Int(deltaY * CGFloat(_bandwidth) * kMultiplier), Int(Tnf.kWidthMin)) )
        tnf.width = tnf.width + Hz(deltaY * CGFloat(_bandwidth) * kMultiplier)
      }
    }
    // redraw the tnfs
    redraw()
  }
  /// Process a Slice drag
  ///
  /// - Parameter dr:         the draggable
  ///
  func updateSlice(dragable dr: PanadapterViewController.Dragable) {
    
    // calculate offsets in x & y
    let deltaX = dr.current.x - dr.previous.x
    let deltaY = dr.current.y - dr.previous.y
    
    // is there a slice object?
    if let slice = dr.object as? xLib6000.Slice {
      
      // YES, drag or resize?
      if abs(deltaX) > abs(deltaY) {
        
        // drag
//        slice.frequency += Int(deltaX * _hzPerUnit)
        
        adjustSliceFrequency(slice, incr: Int(deltaX * _hzPerUnit))
        
      } else {
        
        // resize the filter
        switch slice.mode {
        case "USB", "DIGU":               // upper-side only
          slice.filterHigh += Int(deltaY * CGFloat(_bandwidth) * kMultiplier)
       case "LSB", "DIGL":                // lower-side only
          slice.filterLow -= Int(deltaY * CGFloat(_bandwidth) * kMultiplier)
        case "AM", "SAM", "FM","NFM":     // both sides
          slice.filterHigh += Int(deltaY * CGFloat(_bandwidth) * kMultiplier)
          slice.filterLow -= Int(deltaY * CGFloat(_bandwidth) * kMultiplier)
        default:                          // both sides
          slice.filterHigh += Int(deltaY * CGFloat(_bandwidth) * kMultiplier)
          slice.filterLow -= Int(deltaY * CGFloat(_bandwidth) * kMultiplier)
        }
      }
    }
    // redraw the slices
    redraw()
  }
  /// Force the view to be redrawn
  ///
  func redraw() {
    
    // interact with the UI
    DispatchQueue.main.async {
      // force a redraw
      self.needsDisplay = true      
    }
  }
  /// Incr/decr the Slice frequency (scroll panafall at edges)
  ///
  /// - Parameters:
  ///   - slice: the Slice
  ///   - incr: frequency step
  ///
  func adjustSliceFrequency(_ slice: xLib6000.Slice, incr: Int) {
    var isTooClose = false
    
    // adjust the slice frequency
    slice.frequency += incr
    
    let center = ((slice.frequency + slice.filterHigh) + (slice.frequency + slice.filterLow))/2
    // moving which way?
    if incr > 0 {
      // UP, too close to the high end?
      isTooClose = center > _end - Int(PanafallViewController.kEdgeTolerance * CGFloat(_bandwidth))
      
    } else {
      // DOWN, too close to the low end?
      isTooClose = center + incr < _start + Int(PanafallViewController.kEdgeTolerance * CGFloat(_bandwidth))
    }
    
    // is the new freq too close to an edge?
    if isTooClose  {
      
      // YES, adjust the panafall center frequency (scroll the Panafall)
      _panadapter!.center += incr
      
      redraw()
    }
    // redraw all the slices
    redraw()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  private func drawLegend(_ dirtyRect: NSRect) {
    
    // setup the Frequency Legend font & size
    _attributes[NSAttributedString.Key.foregroundColor] = Defaults.frequencyLegend
    _attributes[NSAttributedString.Key.font] = font

    let bandwidthParams = kBandwidthParams.filter { $0.high > _bandwidth && $0.low <= _bandwidth }.first ?? kBandwidthParams[0]
    let xIncrPerLegend = CGFloat(bandwidthParams.spacing) / _hzPerUnit

    // calculate the number & position of the legend marks
    let numberOfMarks = (_end - _start) / bandwidthParams.spacing
    let firstFreqValue = _start + bandwidthParams.spacing - (_start - ( (_start / bandwidthParams.spacing) * bandwidthParams.spacing))
    let firstFreqPosition = CGFloat(firstFreqValue - _start) / _hzPerUnit

    // remember the position of the previous legend (left to right)
    var previousLegendPosition: CGFloat = 0.0

    NSColor.black.set()
    NSBezierPath.fill(NSRect(x: 0.0, y: 0.0, width: frame.width, height: 20.0))
    
    // make the line solid
    var dash: [CGFloat] = [2.0, 0.0]
    _path.lineWidth = CGFloat(0.5)
    _path.setLineDash( dash, count: 2, phase: 0 )

    // horizontal line above legend
    Defaults.frequencyLegend.set()
    _path.hLine(at: legendHeight, fromX: 0, toX: frame.width)

    // draw legends
    for i in 0...numberOfMarks {
      let xPosition = firstFreqPosition + (CGFloat(i) * xIncrPerLegend)

      // calculate the Frequency legend value & width
      let legendLabel = String(format: bandwidthParams.format, ( CGFloat(firstFreqValue) + CGFloat( i * bandwidthParams.spacing)) / 1_000_000.0)
      let legendWidth = legendLabel.size(withAttributes: _attributes).width

      // skip the legend if it would overlap the start or end or if it would be too close to the previous legend
      if xPosition > 0 && xPosition + legendWidth < frame.width && xPosition - previousLegendPosition > 1.2 * legendWidth {
        // draw the legend
        legendLabel.draw(at: NSMakePoint( xPosition - (legendWidth/2), 1), withAttributes: _attributes)
        // save the position for comparison when drawing the next legend
        previousLegendPosition = xPosition
      }
    }
    _path.strokeRemove()
    
    //        let legendHeight = "123.456".size(withAttributes: _attributes).height
    
    // set Line Width, Color & Dash
    _path.lineWidth = 0.4
    dash = [2.0, 0.0]
    _path.setLineDash( dash, count: 2, phase: 0 )
    Defaults.gridLine.set()
    
    // draw vertical grid lines
    for i in 0...numberOfMarks {
      let xPosition = firstFreqPosition + (CGFloat(i) * xIncrPerLegend)
      
      // draw a vertical line at the frequency legend
      if xPosition < bounds.width {
        _path.vLine(at: xPosition, fromY: bounds.height, toY: legendHeight)
      }
      // draw an "in-between" vertical line
      _path.vLine(at: xPosition + (xIncrPerLegend/2), fromY: bounds.height, toY: legendHeight)
    }
    _path.strokeRemove()
  }
  
  /// Draw the Band Markers
  ///
  private func drawBandMarkers() {
    // use solid lines
    _path.setLineDash( [2.0, 0.0], count: 2, phase: 0 )
    
    // filter for segments that overlap the panadapter frequency range
    let segments = _segments.filter {
      (($0.end >= _start && $0.start < _end) ||       // segment start before pan start with end in pan
        ($0.start >= _start && $0.start < _end) ||    // segment start in pan with end outside of pan
        ($0.start >= _start && $0.end <= _end)) &&    // segment is in panadapter
        $0.enabled && $0.useMarkers}                  // segment is enabled & uses Markers
    
    // ***** Band edges *****
    Defaults.markerEdge.set()  // set the color
    _path.lineWidth = 1         // set the width
    
    // filter for segments that contain a band edge
    segments.filter {$0.startIsEdge || $0.endIsEdge}.forEach {
      
      // is the start of the segment a band edge?
      if $0.startIsEdge {
        
        // YES, draw a vertical line for the starting band edge
        _path.vLine(at: CGFloat($0.start - _start) / _hzPerUnit, fromY: frame.height * markerHeight, toY: 0)
        _path.drawX(at: NSPoint(x: CGFloat($0.start - _start) / _hzPerUnit, y: frame.height * markerHeight), halfWidth: 6)
      }
      
      // is the end of the segment a band edge?
      if $0.endIsEdge {
        
        // YES, draw a vertical line for the ending band edge
        _path.vLine(at: CGFloat($0.end - _start) / _hzPerUnit, fromY: frame.height * markerHeight, toY: 0)
        _path.drawX(at: NSPoint(x: CGFloat($0.end - _start) / _hzPerUnit, y: frame.height * markerHeight), halfWidth: 6)
      }
    }
    _path.strokeRemove()
    
    
    var colorIndex = 0
    
    // ***** Inside segments *****
    Defaults.markerSegment.set()        // set the color
    _path.lineWidth = 1         // set the width
    var previousEnd = 0
    
    // filter for segments that contain an inside segment
    segments.filter {!$0.startIsEdge && !$0.endIsEdge}.forEach {
      // does this segment overlap the previous segment?
      if $0.start != previousEnd {
        
        // NO, draw a vertical line for the inside segment start
        _path.vLine(at: CGFloat($0.start - _start) / _hzPerUnit, fromY: frame.height * markerHeight - 6/2 - 1, toY: 0)
        _path.drawCircle(at: NSPoint(x: CGFloat($0.start - _start) / _hzPerUnit, y: frame.height * markerHeight), radius: 6)
      }
      
      // draw a vertical line for the inside segment end
      _path.vLine(at: CGFloat($0.end - _start) / _hzPerUnit, fromY: frame.height * markerHeight - 6/2 - 1, toY: 0)
      _path.drawCircle(at: NSPoint(x: CGFloat($0.end - _start) / _hzPerUnit, y: frame.height * markerHeight), radius: 6)
      previousEnd = $0.end

    }
    _path.strokeRemove()
    
    // ***** Band Shading *****
//    Defaults.marker.set()
    segments.forEach {
      _segmentColors[colorIndex].set()

      // calculate start & end of shading
      let start = ($0.start >= _start) ? $0.start : _start
      let end = (_end >= $0.end) ? $0.end : _end
      
      // draw a shaded rectangle for the Segment
      let rect = NSRect(x: CGFloat(start - _start) / _hzPerUnit, y: shadingPosition, width: CGFloat(end - start) / _hzPerUnit, height: 10)
      NSBezierPath.fill(rect)
      
      colorIndex += 1
    }
    _path.strokeRemove()
  }
  
  func drawSlices(_ pan: Panadapter) {
    
    // for Slices on this Panadapter
    radio!.slices.filter { $0.value.panadapterId == pan.id }.forEach {
      
      drawFilterOutline($0.value)
      
      drawFrequencyLine($0.value)
    }
  }
  /// Draw the Filter Outline
  ///
  /// - Parameter slice:  this Slice
  ///
  fileprivate func drawFilterOutline(_ slice: xLib6000.Slice) {
    
    // calculate the Filter position & width
    let _filterPosition = CGFloat(slice.filterLow + slice.frequency - _start) / _hzPerUnit
    let _filterWidth = CGFloat(slice.filterHigh - slice.filterLow) / _hzPerUnit
    
    // draw the Filter
    let _rect = NSRect(x: _filterPosition, y: 0, width: _filterWidth, height: frame.height)
    _path.fillRect( _rect, withColor: Defaults.sliceFilter, andAlpha: 0.5)
    
    _path.strokeRemove()
  }
  /// Draw the Frequency line
  ///
  /// - Parameter slice:  this Slice
  ///
  fileprivate func drawFrequencyLine(_ slice: xLib6000.Slice) {
    
    // make the line solid
    let dash: [CGFloat] = [2.0, 0.0]
    _path.setLineDash( dash, count: 2, phase: 0 )

    // set the width & color
    _path.lineWidth = _frequencyLineWidth
    if slice.active { Defaults.sliceActive.set() } else { Defaults.sliceInactive.set() }
    
    // calculate the position
    let _freqPosition = ( CGFloat(slice.frequency - _start) / _hzPerUnit)
    
    // create the Frequency line
    _path.move(to: NSPoint(x: _freqPosition, y: frame.height))
    _path.line(to: NSPoint(x: _freqPosition, y: 0))
    
    // add the triangle cap (if active)
    if slice.active { _path.drawTriangle(at: _freqPosition, topWidth: 15, triangleHeight: 15, topPosition: frame.height) }
    
    _path.strokeRemove()
  }
  /// Draw the outline of tnf(s)
  ///
  fileprivate func drawTnfs() {
    // for each Tnf
    for (_, tnf) in radio!.tnfs {
      
      // is it on this panadapter?
      if tnf.frequency >= _start && tnf.frequency <= _end {
        
        // YES, calculate the position & width
        let tnfPosition = CGFloat(tnf.frequency - tnf.width/2 - _start) / _hzPerUnit
        let tnfWidth = CGFloat(tnf.width) / _hzPerUnit
        
        // draw the rectangle
        let rect = NSRect(x: tnfPosition, y: 0, width: tnfWidth, height: frame.height)
        
        _path.fillRect( rect, withColor: radio!.tnfsEnabled ? Defaults.tnfActive : Defaults.tnfInactive)
        
        // crosshatch it based on depth
        _path.crosshatch(rect, color: _lineColor, depth: Int(tnf.depth), twoWay: true)
        
        // is it "permanent"?
        if tnf.permanent {

          // YES, highlight it
          NSColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.5).set()
          _path.appendRect(rect)
        }
        _path.strokeRemove()
      }
    }
  }
}
