//
//  PanafallsViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 4/30/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

final class PanafallsViewController         : NSSplitViewController {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private weak var _radio                   : Radio? { Api.sharedInstance.radio }
  private let _log                          = (NSApp.delegate as! AppDelegate)
  private var _sb                           : NSStoryboard?
  private var _api                          = Api.sharedInstance
  
  private let kPanafallStoryboard           = "Panafall"
  private let kPanafallButtonIdentifier     = "Button"
  
  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  /// the View has loaded
  ///
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif

    // get the Storyboard containing a Panafall Button View Controller
    _sb = NSStoryboard(name: kPanafallStoryboard, bundle: nil)

    // add notification subscriptions
    addNotifications()
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subsciptions to Notifications
  ///     (as of 10.11, subscriptions are automatically removed on deinit when using the Selector-based approach)
  ///
  private func addNotifications() {
    
    // Panadapter initialized
    NC.makeObserver(self, with: #selector(panadapterHasBeenAdded(_:)), of: .panadapterHasBeenAdded)
    
    // Waterfall initialized
    NC.makeObserver(self, with: #selector(waterfallHasBeenAdded(_:)), of: .waterfallHasBeenAdded)
  }
  //
  //  Panafall creation:
  //
  //      Step 1 .panadapterInitialized
  //      Step 2 .waterfallInitialized
  //
  /// Process .panadapterHasBeenAdded Notification
  ///
  /// - Parameter note: a Notification instance
  ///
  @objc private func panadapterHasBeenAdded(_ note: Notification) {
    // a Panadapter model has been added to the Panadapters collection and Initialized

    // does the Notification contain a Panadapter?
    let panadapter = note.object as! Panadapter
    
//    // In V3, check is it for this Client
//    if (_radio!.version.isV3 && panadapter.clientHandle == _api.connectionHandle) || _radio!.version.isV3 == false {
      // log the event
      _log.logMessage("Panadapter added: Id = \(panadapter.id.hex)", .info, #function, #file, #line)
//    }
  }
  /// Process .waterfallHasBeenAdded Notification
  ///
  /// - Parameter note: a Notification instance
  ///
  @objc private func waterfallHasBeenAdded(_ note: Notification) {
    // a Waterfall model has been added to the Waterfalls collection and Initialized
    
    // does the Notification contain a Panadapter?
    let waterfall = note.object as! Waterfall
    
//    // In V3, check is it for this Client
//    if (_radio!.version.isV3 && waterfall.clientHandle == _api.connectionHandle) || _radio!.version.isV3 == false {
      // log the event
      _log.logMessage("Waterfall added: Id = \(waterfall.id.hex)", .info, #function, #file, #line)
      
      let panadapter = _api.radio!.panadapters[waterfall.panadapterId]
      
      // interact with the UI
      DispatchQueue.main.sync { [weak self] in
        
        // create a Panafall Button View Controller
        let panafallButtonVc = _sb!.instantiateController(withIdentifier: kPanafallButtonIdentifier) as! PanafallButtonViewController
        
        // pass needed parameters
        panafallButtonVc.configure(radio: _api.radio!, panadapter: panadapter, waterfall: waterfall)
        
        self?.addSplitViewItem(NSSplitViewItem(viewController: panafallButtonVc))
      }
//    }
  }
}
