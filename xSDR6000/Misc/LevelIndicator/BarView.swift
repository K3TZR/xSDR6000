//
//  BarView.swift
//  CustomLevelIndicator
//
//  Created by Douglas Adams on 3/4/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Cocoa

final class BarView                       : NSView {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var level                        : CGFloat = 0.0
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _path                       = NSBezierPath()
  private var _params                     : IndicatorParams!
  private var _gradient                   : NSGradient!
  private var _viewType                   : Int!
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize the Bar view
  ///
  /// - Parameters:
  ///   - frameRect:              the rect of the view
  ///   - params:                 a Params struct
  ///
  convenience init(frame frameRect: NSRect, params: IndicatorParams, viewType: Int, gradient: NSGradient) {
    
    self.init(frame: frameRect)
    _params = params
    _viewType = viewType
    
    _gradient = gradient
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  /// Draw in the specified rect
  ///
  /// - Parameter dirtyRect:        the rect to draw in
  ///
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    // calculate the percent
    let levelPercent = (level - _params.origin) / (_params.end - _params.origin)
    
    guard levelPercent <= 100 && levelPercent >= 0 else { return }
    
    // create the clipping rect
    NSBezierPath.clip( levelClipRect(levelPercent: levelPercent, rect: dirtyRect, type: _viewType, flipped: _params.isFlipped))
    
    // add the gradient (subject to the clip area)
    _path.append( gradientBar(at: NSRect(x: 0, y: 0, width: frame.width, height: frame.height),
                              gradient: _gradient,
                              flipped: _params.isFlipped) )
    // draw
    _path.strokeRemove()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Calculate a clipping rect for the bar
  ///
  /// - Parameters:
  ///   - levelPercent:             the level as a percentage
  ///   - rect:                     the Bar rect
  ///   - flipped:                  true = flipped (i.e. right to left)
  /// - Returns:                    the clipping rect
  ///
  private func levelClipRect(levelPercent: CGFloat, rect: NSRect, type: Int, flipped: Bool) -> NSRect {
    
    // Level or Peak?
    let width = ( type == LevelIndicator.kLevelView ? levelPercent * rect.width : LevelIndicator.kPeakWidth )
    
    // Flipped or Normal?
    return flipped ?
      NSRect(x: (1.0 - levelPercent) * rect.width, y: 0, width: width, height: rect.height) :
      NSRect(x: 0, y: 0, width: width, height: rect.height)
  }
  /// Create a gradient filled rect area
  ///
  /// - Parameters:
  ///   - rect:                   the area
  ///   - color:                  an NSGradient
  /// - Returns:                  the filled NSBezierPath
  ///
  private func gradientBar(at rect: NSRect, gradient: NSGradient, flipped: Bool) -> NSBezierPath {
    
    // Flipped or Normal?
    let adjustedRect = flipped ? NSRect(x: rect.width, y: 0, width: -rect.width, height: rect.height) : rect
    
    // create a path with the specified rect
    let path = NSBezierPath(rect: rect)
    
    // fill it with the gradient
    gradient.draw(in: adjustedRect, angle: 0.0)
    
    return path
  }
}
