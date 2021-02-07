//
//  LevelIndicator.swift
//  CustomLevelIndicator
//
//  Created by Douglas Adams on 9/8/18.
//  Copyright © 2018 Douglas Adams. All rights reserved.
//

import Cocoa

public typealias LegendTuple = (tick: Int?, label: String, fudge: CGFloat)

// swiftlint:disable colon
struct IndicatorParams {
    var style                 : Int
    var origin                : CGFloat
    var end                   : CGFloat
    var warningPercent        : CGFloat
    var criticalPercent       : CGFloat
    var backgroundColor       : NSColor
    var normalColor           : NSColor
    var warningColor          : NSColor
    var criticalColor         : NSColor
    var isFlipped             : Bool
}
// swiftlint:enable colon

final class LevelIndicator: NSView {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Static properties
    
    static let kLevelView                     = 0
    static let kPeakView                      = 1
    static let kPeakWidth                     : CGFloat = 5
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    public var level                          : CGFloat = 0.0 {
        didSet { _levelView?.level = level ; _levelView?.needsDisplay = true} }
    public var peak                           : CGFloat = 0.0 {
        didSet { _peakView?.level = peak ; _peakView?.needsDisplay = true } }
    
    public var font                           = NSFont(name: "Monaco", size: 14.0)
    public var legends                        : [LegendTuple] = [ (nil, "Level", 0) ]
    
    // layout
    @IBInspectable var _style                 : Int = 0
    @IBInspectable var _hasLevel              : Bool = true
    @IBInspectable var _hasPeak               : Bool = true
    @IBInspectable var _segments              : Int = 4
    @IBInspectable var _origin                : CGFloat = 0
    @IBInspectable var _end                   : CGFloat = 100
    @IBInspectable var _warningLevel          : CGFloat = 80
    @IBInspectable var _criticalLevel         : CGFloat = 90
    @IBInspectable var _isFlipped             : Bool = false
    
    // colors
    @IBInspectable var _legendColor           : NSColor = NSColor.systemYellow
    @IBInspectable var _frameColor            : NSColor = NSColor(red: 0.2, green: 0.2, blue: 0.8, alpha: 1.0)
    @IBInspectable var _backgroundColor       : NSColor = NSColor.black
    @IBInspectable var _normalColor           : NSColor = NSColor.systemGreen
    @IBInspectable var _warningColor          : NSColor = NSColor.systemYellow
    @IBInspectable var _criticalColor         : NSColor = NSColor.systemRed
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _gradient                     : NSGradient?
    private var _barRect                      : NSRect?
    private var _framePath                    = NSBezierPath()
    private var _levelView                    : BarView?
    private var _peakView                     : BarView?
    
    // internal
    private var _warningPercent               : CGFloat = 0.0
    private var _criticalPercent              : CGFloat = 0.0
    private var _criticalPosition             : CGFloat = 0.0
    private var _indicatorFrameWidth          : CGFloat = 0.0
    private var _barWidth                     : CGFloat = 0.0
    private var _segmentWidth                 : CGFloat = 0.0
    
    // font related
    private var _attributes                   = [NSAttributedString.Key:AnyObject]()
    
    // calculated sizes
    private var _fontHeight                   : CGFloat = 0
    private var _frameTop                     : CGFloat = 0
    private var _frameBottom                  : CGFloat = 0
    private var _fontBottom                   : CGFloat = 0
    private var _barTop                       : CGFloat = 0
    private var _barBottom                    : CGFloat = 0
    private var _barHeight                    : CGFloat = 0
    
    // constants
    private let kStandard                     = 0
    private let kSMeter                       = 1
    private let kLineWidth                    : CGFloat = 1.0
    private let kHorizontalBorder             : CGFloat = 10
    private let kVerticalBorder               : CGFloat = 2
    private let kStandardBarHeight            : CGFloat = 10
    private let kSMeterBarHeight              : CGFloat = 5.0
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    override func viewDidMoveToWindow() {
        
        layer?.backgroundColor = _backgroundColor.cgColor
        
        _indicatorFrameWidth = frame.width - (2 * kHorizontalBorder)
        _segmentWidth = _indicatorFrameWidth / CGFloat(_segments)
        
        // setup the Legend font & size
        _attributes[NSAttributedString.Key.font] = font
        
        // setup the Legend color
        _attributes[NSAttributedString.Key.foregroundColor] = NSColor.systemYellow
        
        // calculate a typical font height
        _fontHeight = "-000".size(withAttributes: _attributes).height
        
        _barWidth = _indicatorFrameWidth - (2.0 * kLineWidth)
        
        // calculate sizes
        switch _style {
        
        case 0: // standard
            
            _frameTop = frame.height - kVerticalBorder - _fontHeight + kLineWidth
            _frameBottom = frame.height - kVerticalBorder - _fontHeight - kStandardBarHeight - kLineWidth
            
            _barTop = _frameTop - kLineWidth
            _barBottom = _frameBottom + kLineWidth
            
            _fontBottom = _frameTop
            
        //      assert(frame.height >= (2.0 * kVerticalBorder) + _fontHeight + kStandardBarHeight, "Frame height too small")
        
        case 1: // sMeter
            _barTop = frame.height - kLineWidth
            _barBottom = _barTop - kSMeterBarHeight
            
            _fontBottom = _barBottom - kLineWidth - _fontHeight
            
        default:
            fatalError("Invalid indicator style")
        }
        
        // populate the parameters
        let params = IndicatorParams(
            style: _style,
            origin: _origin,
            end: _end,
            warningPercent: min( (_warningLevel - _origin) / (_end - _origin), 1.0),
            criticalPercent: min( (_criticalLevel - _origin) / (_end - _origin), 1.0),
            backgroundColor: _backgroundColor,
            normalColor: _normalColor,
            warningColor: _warningColor,
            criticalColor: _criticalColor,
            isFlipped: _isFlipped)
        
        // create the gradient
        _gradient = NSGradient(colors: [params.normalColor, params.warningColor, params.criticalColor],
                               atLocations: [0.0, params.warningPercent, params.criticalPercent],
                               colorSpace: NSColorSpace.sRGB)
        // calculate the critical position (before being flipped)
        _criticalPosition = (params.criticalPercent * _indicatorFrameWidth) + kHorizontalBorder
        
        // create the Level and/or Peak view rect
        _barRect = NSRect(x: kHorizontalBorder + kLineWidth, y: _barBottom, width: _barWidth, height: _barTop - _barBottom)
        
        // create the Level view (if required)
        if _hasLevel {
            _levelView = BarView(frame: _barRect!,
                                 params: params,
                                 viewType: LevelIndicator.kLevelView,
                                 gradient: _gradient!)
            _levelView?.translatesAutoresizingMaskIntoConstraints = false
            addSubview(_levelView!)
        }
        // create the Peak view (if required)
        if _hasPeak {
            _peakView = BarView(frame: _barRect!,
                                params: params,
                                viewType: LevelIndicator.kPeakView,
                                gradient: _gradient!)
            _peakView?.translatesAutoresizingMaskIntoConstraints = false
            addSubview(_peakView!)
        }
        // set the indicators at origin
        level = _origin
        peak = _origin
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden Methods
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if _style == kStandard { drawFrame(dirtyRect) }
        
        drawLegends(legends)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private Methods
    
    /// Setup the meter frame
    ///
    /// - Parameter dirtyRect:          LevelIndicator rect
    ///
    fileprivate func drawFrame(_ dirtyRect: NSRect) {
        
        // set Line Width
        _framePath.lineWidth = kLineWidth
        
        // create the top & bottom line (critical range)
        _criticalColor.set()
        if _isFlipped {
            _framePath.hLine(at: _frameTop, fromX: kHorizontalBorder, toX: dirtyRect.width - _criticalPosition)
            _framePath.hLine(at: _frameBottom, fromX: kHorizontalBorder, toX: dirtyRect.width - _criticalPosition)
        } else {
            _framePath.hLine(at: _frameTop, fromX: _criticalPosition, toX: dirtyRect.width - kHorizontalBorder)
            _framePath.hLine(at: _frameBottom, fromX: _criticalPosition, toX: dirtyRect.width - kHorizontalBorder)
        }
        _framePath.strokeRemove()
        
        // create the top & bottom line (normal & warning range)
        _frameColor.set()
        if _isFlipped {
            _framePath.hLine(at: _frameTop, fromX: dirtyRect.width - _criticalPosition, toX: dirtyRect.width - kHorizontalBorder)
            _framePath.hLine(at: _frameBottom, fromX: dirtyRect.width - _criticalPosition, toX: dirtyRect.width - kHorizontalBorder)
        } else {
            _framePath.hLine(at: _frameTop, fromX: kHorizontalBorder, toX: _criticalPosition)
            _framePath.hLine(at: _frameBottom, fromX: kHorizontalBorder, toX: _criticalPosition)
        }
        _framePath.strokeRemove()
        
        // create the vertical hash marks
        var lineColor: NSColor
        var xPosition: CGFloat
        for i in 0..._segments {
            xPosition = _segmentWidth * CGFloat(i) + kHorizontalBorder
            
            if _isFlipped {
                // determine the line color
                switch xPosition {
                
                case ..<(dirtyRect.width - _criticalPosition):
                    lineColor = _criticalColor
                    
                default:
                    lineColor = _frameColor
                }
            } else {
                // determine the line color
                switch xPosition {
                
                case _criticalPosition...:
                    lineColor = _criticalColor
                    
                default:
                    lineColor = _frameColor
                }
                
            }
            // create line with the required color
            lineColor.set()
            
            _framePath.vLine(at: xPosition, fromY: _barTop, toY: _barBottom)
            _framePath.strokeRemove()
        }
        
    }
    /// Draw a legend at specified vertical bar(s)
    ///
    /// - Parameter legends:        an array of LegendTuple
    ///
    private func drawLegends(_ legends: [LegendTuple]) {
        var xPosition: CGFloat = 0.0
        var fix: CGFloat = 0.0
        
        // draw the legends
        for legend in legends {
            // is it a normal legend?
            if let tick = legend.tick {
                // YES, calculate the x coordinate of the legend
                let width = legend.label.size(withAttributes: _attributes).width
                
                // adjust the start & end positions
                if tick == 0 {
                    fix = 0.0
                } else if tick == _segments {
                    fix = 1.0
                } else {
                    fix = legend.fudge
                }
                // calculate the adjusted x-coordinate
                xPosition = kHorizontalBorder + (CGFloat(tick) * _segmentWidth) - (width * fix)
                
                // format & draw the legend
                legend.label.draw(at: CGPoint(x: xPosition, y: _fontBottom), withAttributes: _attributes)
                
            } else {
                
                // NO, draw a centered legend
                let width = legend.label.size(withAttributes: _attributes).width
                
                // calculate the x-coordinate
                xPosition = (frame.width / 2.0) - (width / 2.0) + (width * legend.fudge)
                legend.label.draw(at: CGPoint(x: xPosition, y: _fontBottom), withAttributes: _attributes)
            }
        }
    }
}
