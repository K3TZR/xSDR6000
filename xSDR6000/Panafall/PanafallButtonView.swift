//
//  PanafallButtonView.swift
//  xSDR6000
//
//  Created by Douglas Adams on 6/10/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults

// --------------------------------------------------------------------------------
// MARK: - Panafall Button View class implementation
// --------------------------------------------------------------------------------

final class PanafallButtonView: NSView {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var buttonViewWidth  : NSLayoutConstraint!
    
    private var _buttonTracking                 : NSTrackingArea?
    
    private let _trackingOptions                = NSTrackingArea.Options.mouseEnteredAndExited.union(.activeInActiveApp)
    private let kButtonViewWidth                : CGFloat = 75                // default button area width
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func awakeFromNib() {
        
        // hide the Button area
        buttonViewWidth.constant = 0
        
        // add a Tracking area
        addTrackingArea()
    }
    
    deinit {
        
        // remove the Tracking area (if any)
        removeTrackingArea()
    }
    
    /// Mouse entered the Button area
    ///
    /// - Parameter theEvent:           mouse Event
    ///
    override func mouseEntered(with theEvent: NSEvent) {
        
        // make the Button View visible
        buttonViewWidth.constant = kButtonViewWidth
    }
    
    /// Mouse exited the Button area
    ///
    /// - Parameter theEvent:           mouse Event
    ///
    override func mouseExited(with theEvent: NSEvent) {
        
        // make the Button View invisible
        buttonViewWidth.constant = 0
    }
    /// Respond to updateTrackingAreas calls (automaticly called by the view)
    ///
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        removeTrackingArea()
        addTrackingArea()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Add a Tracking Area for the Button view
    ///
    private func addTrackingArea() {
        
        // create the tracking rectangle
        let rect = NSRect(x: 0, y: 0, width: kButtonViewWidth, height: frame.height)
        
        // create & add the Button View Tracking Area
        _buttonTracking = NSTrackingArea(rect: rect, options: _trackingOptions, owner: self, userInfo: ["Type": "button"])
        addTrackingArea(_buttonTracking!)
    }
    /// Remove the Tracking Area (if any) for the Button view
    ///
    public func removeTrackingArea() {
        
        // remove the existing Button View Tracking Area (if any)
        if _buttonTracking != nil { removeTrackingArea(_buttonTracking!) ; _buttonTracking = nil }
    }
}
