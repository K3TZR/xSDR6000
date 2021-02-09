//
//  PanafallsViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 4/30/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

typealias LogFunction = (_ : String, _ : MessageLevel, _ : StaticString, _ : StaticString, _ : Int) -> Void

// swiftlint:disable colon
public struct Params {
    var api         : Api
    var log         : LogFunction
    var radio       : Radio
    var panadapter  : Panadapter
    var waterfall   : Waterfall
    var center      : Int { panadapter.center }
    var bandwidth   : Int { panadapter.bandwidth }
    var start       : Int { center - (bandwidth/2) }
    var end         : Int { center + (bandwidth/2) }
}
// swiftlint:enable colon

final class PanafallsViewController: NSSplitViewController {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private weak var _radio                   : Radio? { Api.sharedInstance.radio }
    private let _log                          = Logger.sharedInstance.logMessage
    private var _storyboard                   : NSStoryboard?
    private var _api                          = Api.sharedInstance
    
    private let kPanafallStoryboard           = "Panafall"
    private let kPanafallButtonIdentifier     = "Button"
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // get the Storyboard containing a Panafall Button View Controller
        _storyboard = NSStoryboard(name: kPanafallStoryboard, bundle: nil)
        
        // add notification subscriptions
        addNotifications()
    }

    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    /// Add subsciptions to Notifications
    ///     (as of 10.11, subscriptions are automatically removed on deinit when using the Selector-based approach)
    ///
    private func addNotifications() {
        NCtr.makeObserver(self, with: #selector(panadapterHasBeenAdded(_:)), of: .panadapterHasBeenAdded)
        NCtr.makeObserver(self, with: #selector(waterfallHasBeenAdded(_:)), of: .waterfallHasBeenAdded)
    }
    
    /// Process .panadapterHasBeenAdded Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc private func panadapterHasBeenAdded(_ note: Notification) {
        // does the Notification contain a Panadapter?
        if let panadapter = note.object as? Panadapter {
            // In V3, check is it for this Client
            if _radio!.version.isOldApi || _radio!.version.isNewApi && panadapter.clientHandle == _api.connectionHandle {
                // log the event
                _log("Panadapter added: id = \(panadapter.id.hex)", .info, #function, #file, #line)
            }
        }
    }
    
    /// Process .waterfallHasBeenAdded Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc private func waterfallHasBeenAdded(_ note: Notification) {
        // does the Notification contain a Waterfall?
        if let waterfall = note.object as? Waterfall {
            // In V3, check is it for this Client
            if  _radio!.version.isOldApi || _radio!.version.isNewApi && waterfall.clientHandle == _api.connectionHandle {
                // log the event
                _log("Waterfall added: id = \(waterfall.id.hex)", .info, #function, #file, #line)
                
                let panadapter = _api.radio!.panadapters[waterfall.panadapterId]!
                
                // interact with the UI
                DispatchQueue.main.sync { [weak self] in
                    // create a Panafall Button View Controller
                    if let panafallButtonVc = _storyboard!.instantiateController(withIdentifier: kPanafallButtonIdentifier) as? PanafallButtonViewController {                        
                        // pass needed parameters
                        panafallButtonVc.configure(params: Params(api: _api,
                                                                  log: _log,
                                                                  radio: _radio!,
                                                                  panadapter: panadapter,
                                                                  waterfall: waterfall))
                        
                        self?.addSplitViewItem(NSSplitViewItem(viewController: panafallButtonVc))
                        self?.splitView.adjustSubviews()
                    }
                }
            }
        }
    }
}
