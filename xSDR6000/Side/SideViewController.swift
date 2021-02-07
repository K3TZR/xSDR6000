//
//  SideViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 4/30/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - Side View Controller class implementation
// --------------------------------------------------------------------------------

final class SideViewController: NSViewController {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var _rxContainer   : NSView!
    
    @IBOutlet private weak var _scrollView    : NSScrollView!
    @IBOutlet private weak var _rxButton      : NSButton!
    @IBOutlet private weak var _txButton      : NSButton!
    @IBOutlet private weak var _pcwButton     : NSButton!
    @IBOutlet private weak var _phneButton    : NSButton!
    @IBOutlet private weak var _eqButton      : NSButton!
    
    @IBOutlet private weak var _insideViewHeight      : NSLayoutConstraint!
    @IBOutlet private weak var _rxContainerHeight     : NSLayoutConstraint!
    @IBOutlet private weak var _txContainerHeight     : NSLayoutConstraint!
    @IBOutlet private weak var _pcwContainerHeight    : NSLayoutConstraint!
    @IBOutlet private weak var _cwContainerHeight     : NSLayoutConstraint!
    @IBOutlet private weak var _phneContainerHeight   : NSLayoutConstraint!
    @IBOutlet private weak var _eqContainerHeight     : NSLayoutConstraint!
    
    private var _rxViewLoaded                 = false
    private var _flagVc                       : FlagViewController?
    
    private let kSideViewWidth                : CGFloat = 311
    private let kRxHeightOpen                 : CGFloat = 90
    private let kTxHeightOpen                 : CGFloat = 210
    private let kPcwHeightOpen                : CGFloat = 235
    private let kCwHeightOpen                 : CGFloat = 235
    private let kPhneHeightOpen               : CGFloat = 210
    private let kEqHeightOpen                 : CGFloat = 210
    private let kHeightClosed                 : CGFloat = 0
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overriden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        addNotifications()
        
        let widthConstraint = view.widthAnchor.constraint(equalToConstant: kSideViewWidth)
        widthConstraint.identifier = "Side width constraint"
        widthConstraint.isActive = true
        
        // is there an Active Slice?
        if let slice = Api.sharedInstance.radio?.findActiveSlice(), let pan = Api.sharedInstance.radio?.panadapters[slice.panadapterId] {
            // YES, add a Flag
            sideFlag(slice: slice, pan: pan, viewController: self)
            
            addObservations()
        }
        
        // set the button states
        _rxButton.state = Defaults.sideRxOpen.state
        _txButton.state = Defaults.sideTxOpen.state
        _pcwButton.state = Defaults.sidePcwOpen.state
        _phneButton.state = Defaults.sidePhneOpen.state
        _eqButton.state = Defaults.sideEqOpen.state
        
        // open the Pcw / Cw views as appropriate
        pcwStatus()
        
        // unhide the selected views
        _rxContainerHeight.constant = ( Defaults.sideRxOpen ? kRxHeightOpen : kHeightClosed )
        _txContainerHeight.constant = ( Defaults.sideTxOpen ? kTxHeightOpen : kHeightClosed )
        _phneContainerHeight.constant = ( Defaults.sidePhneOpen ? kPhneHeightOpen : kHeightClosed )
        _eqContainerHeight.constant = ( Defaults.sideEqOpen ? kEqHeightOpen : kHeightClosed )
    }
    override func viewDidLayout() {
        
        // position the scroll view at the top
        positionAtTop(_scrollView)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    /// Respond to one of the Side buttons
    ///
    /// - Parameter sender:             the Button
    ///
    @IBAction func sideButtons(_ sender: NSButton) {
        
        switch sender.identifier!.rawValue {
        case "RxButton":
            Defaults.sideRxOpen = sender.boolState
            _rxContainerHeight.constant = (sender.boolState ? kRxHeightOpen : kHeightClosed)
        case "TxButton":
            Defaults.sideTxOpen = sender.boolState
            _txContainerHeight.constant = (sender.boolState ? kTxHeightOpen : kHeightClosed)
        case "PcwButton":
            Defaults.sidePcwOpen = sender.boolState
            if _flagVc?.slice?.mode == xLib6000.Slice.Mode.CW.rawValue {
                _cwContainerHeight.constant = (sender.boolState ? kCwHeightOpen : kHeightClosed)
            } else {
                _pcwContainerHeight.constant = (sender.boolState ? kPcwHeightOpen : kHeightClosed)
            }
        case "PhneButton":
            Defaults.sidePhneOpen = sender.boolState
            _phneContainerHeight.constant = (sender.boolState ? kPhneHeightOpen : kHeightClosed)
        case "EqButton":
            Defaults.sideEqOpen = sender.boolState
            _eqContainerHeight.constant = (sender.boolState ? kEqHeightOpen : kHeightClosed)
        default:
            fatalError()
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    func setRxHeight(_ height: CGFloat) {
        self._rxContainerHeight.constant = height
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    private func pcwStatus() {
        // Is PCW open?
        if Defaults.sidePcwOpen {
            // YES, get the active Slice (if any)
            if _flagVc != nil {
                // CW or non-CW?
                if _flagVc?.slice?.mode == xLib6000.Slice.Mode.CW.rawValue {
                    // CW
                    _pcwContainerHeight.constant = kHeightClosed
                    _cwContainerHeight.constant = kCwHeightOpen
                } else {
                    // non-CW
                    _pcwContainerHeight.constant = kPcwHeightOpen
                    _cwContainerHeight.constant = kHeightClosed
                }
            } else {
                // no active Slice
                _pcwContainerHeight.constant = kHeightClosed
                _cwContainerHeight.constant = kHeightClosed
            }
        } else {
            // no flag
            _pcwContainerHeight.constant = kHeightClosed
            _cwContainerHeight.constant = kHeightClosed
        }
    }
    
    /// Add a Flag to the Side view
    ///
    /// - Parameters:
    ///   - slice:                    a Slice
    ///   - pan:                      the Panadapter containing the Slice
    ///   - viewController:           the parent ViewController
    ///
    private func sideFlag(slice: xLib6000.Slice, pan: Panadapter, viewController: NSViewController) {
        
        // create a Flag with the Side view controller as its parent
        self._flagVc = FlagViewController.createFlag(for: slice, and: pan, on: viewController)
        
        // add the Flag to the view hierarchy
        FlagViewController.addFlag(self._flagVc!,
                                   to: _rxContainer,
                                   flagPosition: 0,
                                   flagHeight: FlagViewController.kLargeFlagHeight,
                                   flagWidth: FlagViewController.kLargeFlagWidth + 36)
        
        // if selected, make it visible (i.e. height > 0)
        _rxContainerHeight.constant = (Defaults.sideRxOpen ? kRxHeightOpen : kHeightClosed)
    }
    
    /// Position a scroll view at the top
    ///
    /// - Parameter scrollView:         the ScrollView
    ///
    private func positionAtTop(_ scrollView: NSScrollView) {
        // position the scroll view at the top
        if let docView = scrollView.documentView {
            docView.scroll(NSPoint(x: 0, y: view.frame.height))
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    private var _observation: NSKeyValueObservation?
    
    /// Add observations
    ///
    private func addObservations() {
        _observation =
            _flagVc!.slice!.observe(\.mode, options: [.initial, .new]) { [weak self] (slice, change) in
                self?.modeChange(slice, change) }
    }
    
    /// The slice's mode changed
    ///
    /// - Parameters:
    ///   - slice:                  the Slice
    ///   - change:                 the change
    ///
    private func modeChange(_ slice: xLib6000.Slice, _ change: Any) {
        DispatchQueue.main.async { [weak self] in
            // adjust the PCW view
            self?.pcwStatus()
        }
    }
    
    /// Remove observations
    ///
    func removeObservations() {
        if _observation != nil {
            // invalidate observation
            _observation!.invalidate()
            
            // remove the token
            _observation = nil
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    /// Add subsciptions to Notifications
    ///     (as of 10.11, subscriptions are automatically removed on deinit when using the Selector-based approach)
    ///
    private func addNotifications() {
        NCtr.makeObserver(self, with: #selector(frameDidChange(_:)), of: NSView.frameDidChangeNotification.rawValue, object: view)
        NCtr.makeObserver(self, with: #selector(activeSliceChange(_:)), of: .sliceHasBeenAdded)
        NCtr.makeObserver(self, with: #selector(activeSliceChange(_:)), of: .sliceBecameActive)
    }
    
    /// Process frameDidChange Notification
    ///
    /// - Parameter note:               a Notification instance
    ///
    @objc private func frameDidChange(_ note: Notification) {
        _scrollView.needsLayout = true
    }
    
    /// Process .sliceHasBeenAdded & .sliceBecameActive Notification
    ///
    /// - Parameter note:               a Notification instance
    ///
    @objc private func activeSliceChange(_ note: Notification) {
        if let slice = note.object as? xLib6000.Slice {            
            // stop observing the previous Slice
            removeObservations()
            
            // find the Panadapter of this Slice
            if let pan = Api.sharedInstance.radio?.panadapters[slice.panadapterId] {
                // has the Rx Side view been loaded?
                if _rxViewLoaded {
                    // YES, update it
                    DispatchQueue.main.async { [weak self] in
                        self?._flagVc!.updateFlag(slice: slice, panadapter: pan)
                        // adjust the PCW view
                        self?.adjustAndObserve()
                    }
                } else {
                    // NO, load it
                    _rxViewLoaded = true
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.sideFlag(slice: slice, pan: pan, viewController: self!)
                        
                        // adjust the PCW view
                        self?.adjustAndObserve()
                    }
                }
            }
        }
    }
    
    private func adjustAndObserve() {
        // adjust the PCW view
        pcwStatus()
        
        // start observing the new Slice
        addObservations()
    }
}
