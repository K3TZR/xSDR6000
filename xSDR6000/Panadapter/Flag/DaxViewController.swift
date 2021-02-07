//
//  DaxViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 1/7/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

final class DaxViewController: NSViewController {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var _daxPopUp      : NSPopUpButton!
    
    private var _slice                        : xLib6000.Slice? {
        return representedObject as? xLib6000.Slice }
    
    private var _observations                 = [NSKeyValueObservation]()
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        if Defaults.flagBorderEnabled {
            view.layer?.borderColor = NSColor.darkGray.cgColor
            view.layer?.borderWidth = 0.5
        }
        // populate the choices
        _daxPopUp.addItems(withTitles: Api.kDaxChannels)
        
        // start observing
        addObservations()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // set the background color of the Flag
        view.layer?.backgroundColor = ControlsViewController.kBackgroundColor
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    /// Respond to the DAX popup
    ///
    /// - Parameter sender:         the button
    ///
    @IBAction func buttons(_ sender: NSPopUpButton) {
        
        _slice?.daxChannel = sender.indexOfSelectedItem
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    /// Add observations of various properties used by the view
    ///
    private func addObservations() {
        
        _observations = [
            _slice!.observe(\.daxChannel, options: [.initial, .new]) { [weak self] (slice, change) in
                self?.changeHandler(slice, change) }
        ]
    }
    /// Process observations
    ///
    /// - Parameters:
    ///   - slice:                    the slice being observed
    ///   - change:                   the change
    ///
    private func changeHandler(_ slice: xLib6000.Slice, _ change: Any) {
        
        DispatchQueue.main.async { [weak self] in
            self?._daxPopUp.selectItem(at: slice.daxChannel)
        }
    }
}
