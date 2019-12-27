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

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods

  override func viewDidLoad() {
    super.viewDidLoad()

    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    view.translatesAutoresizingMaskIntoConstraints = false
    
    view.isHidden = true
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
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

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
