//
//  TimeLayer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/7/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

public final class TimeLayer                : CALayer, CALayerDelegate {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  weak var radio                            = Api.sharedInstance.radio
  weak var panadapter                       : Panadapter?
  
  var font                                  = NSFont(name: "Monaco", size: 12.0)
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private weak var _waterfall               : Waterfall? { return radio!.waterfalls[panadapter!.waterfallId] }
  
  private var _spacings                     = Defaults[.timeLegendSpacings]
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
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
  /// respond to the Context Menu selection
  ///
  /// - Parameter sender:     the Context Menu
  ///
  @objc private func legendSpacing(_ sender: NSMenuItem) {
    
    // set the Db Legend spacing
    Defaults[.timeLegendSpacing] = String(sender.tag, radix: 10)
    
    // redraw the db legend
    redraw()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - CALayerDelegate methods
  
  /// Draw Layers
  ///
  /// - Parameters:
  ///   - layer:      a CALayer
  ///   - ctx:        context
  ///
  public func draw(_ layer: CALayer, in ctx: CGContext) {
    
    // setup the graphics context
    let context = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    
    
    
    
    
    // restore the graphics context
    NSGraphicsContext.restoreGraphicsState()
  }
  /// Force the layer to be redrawn
  ///
  func redraw() {
    // interact with the UI
    DispatchQueue.main.async {
      // force a redraw
      self.setNeedsDisplay()
    }
  }
}
