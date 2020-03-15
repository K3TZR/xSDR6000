//
//  DbLegendView.swift
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

public final class DbLegendView             : NSView {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  private weak var _panadapter              : Panadapter?
  
  var width: CGFloat                        = 40
  var font                                  = NSFont(name: "Monaco", size: 12.0)
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _minDbm                       : CGFloat { _panadapter!.minDbm }
  private var _maxDbm                       : CGFloat { _panadapter!.maxDbm }
  private var _spacings                     = Defaults[.dbLegendSpacings]
  private var _path                         = NSBezierPath()  
  private var _attributes                   = [NSAttributedString.Key:AnyObject]() // Font & Size for the db Legend
  private var _fontHeight                   : CGFloat = 0                         // height of typical label
  
  private let kFormat                       = " %4.0f"
  
  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods

  public override func awakeFromNib() {
    super.awakeFromNib()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
  }

  public override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    
//    compositingFilter = CIFilter(name: "CIDifferenceBlendMode")
    
    // set the background color
    layer?.backgroundColor = NSColor.clear.cgColor
    
    // draw the Db legend and horizontal grid lines
    drawLegend(dirtyRect)
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  /// Configure needed parameters
  ///
  /// - Parameter panadapter:               a Panadapter reference
  ///
  func configure(panadapter: Panadapter?) {
    self._panadapter = panadapter
  }
  /// Process a Dbm level drag
  ///
  /// - Parameter dr:         the draggable
  ///
  func updateDbmLevel(dragable dr: PanadapterViewController.Dragable) {
    
    // Upper half of the legend?
    if dr.original.y > frame.height/2 {
      
      // YES, update the max value
      _panadapter!.maxDbm += (dr.previous.y - dr.current.y)
      
    } else {
      
      // NO, update the min value
      _panadapter!.minDbm += (dr.previous.y - dr.current.y)
    }
    // redraw the db legend
    redraw()
  }
  /// Process a Dbm spacing change
  ///
  /// - Parameters:
  ///   - gr:                 a Gesture Recognizer
  ///   - view:               the view of the gesture
  ///
  func updateLegendSpacing(gestureRecognizer gr: NSClickGestureRecognizer, in view: NSView) {
    var item: NSMenuItem!
    
    // get the "click" coordinates and convert to the View
    let position = gr.location(in: view)
    
    // create the Spacings popup menu
    let menu = NSMenu(title: "Spacings")
    
    // populate the popup menu of Spacings
    for i in 0..<_spacings.count {
      item = menu.insertItem(withTitle: "\(_spacings[i]) dbm", action: #selector(legendSpacing(_:)), keyEquivalent: "", at: i)
      item.tag = Int(_spacings[i]) ?? 0
      item.target = self
    }
    // display the popup
    menu.popUp(positioning: menu.item(at: 0), at: position, in: view)
  }
  /// Force the layer to be redrawn
  ///
  func redraw() {
    // interact with the UI
    DispatchQueue.main.async {
      // force a redraw
      self.needsDisplay = true
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Draw the Dbm legend and horizontal grid lines
  ///
  private func drawLegend(_ dirtyRect: NSRect) {
    
    // setup the Legend font & size
    _attributes[NSAttributedString.Key.foregroundColor] = Defaults[.dbLegend]
    _attributes[NSAttributedString.Key.font] = font
    
    // calculate a typical font height
    _fontHeight = "-000".size(withAttributes: _attributes).height
    
    // setup the Legend color
    _attributes[NSAttributedString.Key.foregroundColor] = Defaults[.dbLegend]
    
    // get the spacing between legends
    let dbSpacing = CGFloat(Defaults[.dbLegendSpacing])
    
    // calculate the number of legends & the y pixels per db
    let dbRange = _maxDbm - _minDbm
    let numberOfLegends = Int( dbRange / dbSpacing)
    let yIncrPerDb = frame.height / dbRange
    
    // calculate the value of the first legend & its y coordinate
    let minDbmValue = _minDbm - _minDbm.truncatingRemainder(dividingBy:  dbSpacing)
    let yOffset = -_minDbm.truncatingRemainder(dividingBy: dbSpacing) * yIncrPerDb
    
    // draw the legends
    for i in 0...numberOfLegends {
      
      // calculate the y coordinate of the legend
      let yPosition = yOffset + (CGFloat(i) * yIncrPerDb * dbSpacing) - _fontHeight/3
      
      // format & draw the legend
      let lineLabel = String(format: kFormat, minDbmValue + (CGFloat(i) * dbSpacing))
      lineLabel.draw(at: NSMakePoint(frame.width - width, yPosition ) , withAttributes: _attributes)
    }
    _path.strokeRemove()
    
    // set Line Width, Color & Dash
    _path.lineWidth = 0.4
    let dash: [CGFloat] = [2.0, 0.0]
    _path.setLineDash( dash, count: 2, phase: 0 )
    Defaults[.gridLine].set()
    
    // draw the horizontal grid lines
    for i in 0...numberOfLegends {
      
      // calculate the y coordinate of the legend
      let yPosition = yOffset + (CGFloat(i) * yIncrPerDb * dbSpacing) - _fontHeight/3
      
      // draw the line
      _path.hLine(at: yPosition + _fontHeight/3, fromX: 0, toX: frame.width - width )
    }
    _path.strokeRemove()
  }
  /// respond to the Dbm spacing Menu selection
  ///
  /// - Parameter sender:     the Context Menu
  ///
  @objc private func legendSpacing(_ sender: NSMenuItem) {
    
    // set the Db Legend spacing
    Defaults[.dbLegendSpacing] = String(sender.tag, radix: 10)
    
    // redraw the db legend
    redraw()
  }
}
