//
//  ControlsViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 11/8/18.
//  Copyright © 2018 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - Controls View Controller class implementation
// --------------------------------------------------------------------------------

final class ControlsViewController: NSTabViewController {
    
    // swiftlint:disable colon
    static let kControlsHeight                : CGFloat = 90
    static let kBackgroundColor               = NSColor.black.withAlphaComponent(0.3).cgColor
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var leadingConstraint                     : NSLayoutConstraint?
    var trailingConstraint                    : NSLayoutConstraint?
    var topConstraint                         : NSLayoutConstraint?
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private weak var _slice                   : xLib6000.Slice?
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        view.isHidden = true

        // set the background color of the Flag
        view.layer?.backgroundColor = NSColor.black.cgColor
//        if !(_viewController is SideViewController) {
            view.layer?.borderWidth = 0.5
            view.layer?.borderColor = .init(gray: 0.4, alpha: 1.0)
//        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // set the background color of the Flag
        view.layer?.backgroundColor = ControlsViewController.kBackgroundColor
    }
    ///
    /// - Parameters:
    ///   - tabView:                  the TabView
    ///   - tabViewItem:              the Item being selected
    ///
    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        
        // give it a reference to the Slice
        tabViewItem?.viewController?.representedObject = _slice
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    /// Configure needed parameters
    ///
    /// - Parameters:
    ///   - slice:                    a Slice reference
    ///   - slice:                    a Slice reference
    ///
    func configure(slice: xLib6000.Slice?) {
        _slice = slice!
        
        tabViewItems[0].viewController!.representedObject = _slice
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    /// Respond to the 0 button for Rit
    ///
    /// - Parameter sender:           a button
    ///
    @IBAction func zeroRit(_ sender: NSButton) {
        _slice?.ritOffset = 0
    }
    /// Respond to the 0 button for Xit
    ///
    /// - Parameter sender:           a button
    ///
    @IBAction func zeroXit(_ sender: NSButton) {
        _slice?.xitOffset = 0
    }
}
