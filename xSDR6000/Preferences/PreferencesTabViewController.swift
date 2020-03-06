//
//  PreferencesTabViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 11/16/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults

// ----------------------------------------------------------------------------
// MARK: - Overrides

final class PreferencesTabViewController    : NSTabViewController {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _autosaveName                 = "PreferencesWindow"
  private let _log                          = Logger.sharedInstance

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    view.translatesAutoresizingMaskIntoConstraints = false
    
    // select the previously selelcted tab
    tabView.selectTabViewItem(withIdentifier: NSUserInterfaceItemIdentifier(Defaults[.preferencesTabId]) )

    _log.logMessage("Preferences window opened", .info, #function, #file, #line)
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    
    view.window!.setFrameUsingName(_autosaveName)
    view.window!.level = .floating

    // select the previously displayed tab
    tabView.selectTabViewItem(withIdentifier: NSUserInterfaceItemIdentifier(Defaults[.preferencesTabId]) )
  }
  
  override func viewWillDisappear() {
    super.viewWillDisappear()
    
    view.window!.saveFrame(usingName: _autosaveName)

    // close the ColorPicker (if open)
    if NSColorPanel.shared.isVisible {
      NSColorPanel.shared.performClose(nil)
    }
    // save the currently displayed tab
    Defaults[.preferencesTabId] = (tabView.selectedTabViewItem?.identifier as! NSUserInterfaceItemIdentifier).rawValue
  }

  override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
    super.tabView(tabView, willSelect: tabViewItem)

    // close the ColorPicker (if open)
    if NSColorPanel.shared.isVisible {
      NSColorPanel.shared.performClose(nil)
    }
  }
  deinit {
    _log.logMessage("Preferences window closed", .info, #function, #file, #line)
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
  }

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
//  /// Respond to the Quit menu item
//  ///
//  /// - Parameter sender:     the button
//  ///
//  @IBAction func quitRadio(_ sender: AnyObject) {
//
//    dismiss(sender)
//
//    // perform an orderly shutdown of all the components
//    Api.sharedInstance.shutdown(reason: .normal)
//
//    DispatchQueue.main.async {
//      _log("Application closed by user", .info, #function, #file, #line)
//
//      NSApp.terminate(self)
//    }
//  }
}

