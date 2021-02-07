//
//  ColorsPrefsViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 1/8/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults

final class ColorsPrefsViewController: NSViewController {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var _dbLegend           : NSColorWell!
    @IBOutlet private weak var _frequencyLegend    : NSColorWell!
    @IBOutlet private weak var _gridLine           : NSColorWell!
    @IBOutlet private weak var _marker             : NSColorWell!
    @IBOutlet private weak var _markerEdge         : NSColorWell!
    @IBOutlet private weak var _markerSegment      : NSColorWell!
    @IBOutlet private weak var _sliceActive        : NSColorWell!
    @IBOutlet private weak var _sliceFilter        : NSColorWell!
    @IBOutlet private weak var _sliceInactive      : NSColorWell!
    @IBOutlet private weak var _spectrum           : NSColorWell!
    @IBOutlet private weak var _spectrumBackground : NSColorWell!
    @IBOutlet private weak var _tnfActive          : NSColorWell!
    @IBOutlet private weak var _tnfInactive        : NSColorWell!
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        addObservations()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    @IBAction func singleResetButtons(_ sender: NSButton) {
        let defaults = DefaultsKeys()
        
        // reset the respective color
        switch sender.identifier!.rawValue {
        case "DbLegendReset":
            Defaults.dbLegend = defaults.dbLegend.defaultValue!
        case "FrequencyLegendReset":
            Defaults.frequencyLegend = defaults.frequencyLegend.defaultValue!
        case "GridLineReset":
            Defaults.gridLine = defaults.gridLine.defaultValue!
        case "MarkerReset":
            Defaults.marker = defaults.marker.defaultValue!
        case "MarkerEdgeReset":
            Defaults.markerEdge = defaults.markerEdge.defaultValue!
        case "MarkerSegmentReset":
            Defaults.markerSegment = defaults.markerSegment.defaultValue!
        case "SliceActiveReset":
            Defaults.sliceActive = defaults.sliceActive.defaultValue!
        case "SliceFilterReset":
            Defaults.sliceFilter = defaults.sliceFilter.defaultValue!
        case "SliceInactiveReset":
            Defaults.sliceInactive = defaults.sliceInactive.defaultValue!
        case "SpectrumBackgroundReset":
            Defaults.spectrumBackground = defaults.spectrumBackground.defaultValue!
        case "SpectrumReset":
            Defaults.spectrum = defaults.spectrum.defaultValue!
        case "TnfActiveReset":
            Defaults.tnfActive = defaults.tnfActive.defaultValue!
        case "TnfInactiveReset":
            Defaults.tnfInactive = defaults.tnfInactive.defaultValue!
        default:
            fatalError()
        }
    }
    
    /// Respond to one of the colorwells
    ///
    /// - Parameter sender:         the colorwell
    ///
    @IBAction func colors(_ sender: NSColorWell) {
        
        // set the respective color
        switch sender.identifier!.rawValue {
        case "dbLegend":
            Defaults.dbLegend = sender.color
        case "frequencyLegend":
            Defaults.frequencyLegend = sender.color
        case "gridLine":
            Defaults.gridLine = sender.color
        case "marker":
            Defaults.marker = sender.color
        case "markerEdge":
            Defaults.markerEdge = sender.color
        case "markerSegment":
            Defaults.markerSegment = sender.color
        case "sliceActive":
            Defaults.sliceActive = sender.color
        case "sliceFilter":
            Defaults.sliceFilter = sender.color
        case "sliceInactive":
            Defaults.sliceInactive = sender.color
        case "spectrum":
            Defaults.spectrum = sender.color
        case "spectrumBackground":
            Defaults.spectrumBackground = sender.color
        case "tnfActive":
            Defaults.tnfActive = sender.color
        case "tnfInactive":
            Defaults.tnfInactive = sender.color
        default:
            fatalError()
        }
    }
    /// Respond to the Reset button
    ///
    /// - Parameter sender:             the button
    ///
    @IBAction func resetButton(_ sender: NSButton) {
        let defaults = DefaultsKeys()
        
        // reset all colors to their default values
        Defaults.dbLegend           = defaults.dbLegend.defaultValue!
        Defaults.frequencyLegend    = defaults.frequencyLegend.defaultValue!
        Defaults.gridLine           = defaults.gridLine.defaultValue!
        Defaults.marker             = defaults.marker.defaultValue!
        Defaults.markerEdge         = defaults.markerEdge.defaultValue!
        Defaults.markerSegment      = defaults.markerSegment.defaultValue!
        Defaults.sliceActive        = defaults.sliceActive.defaultValue!
        Defaults.sliceFilter        = defaults.sliceFilter.defaultValue!
        Defaults.sliceInactive      = defaults.sliceInactive.defaultValue!
        Defaults.spectrumBackground = defaults.spectrumBackground.defaultValue!
        Defaults.spectrum           = defaults.spectrum.defaultValue!
        Defaults.tnfActive          = defaults.tnfActive.defaultValue!
        Defaults.tnfInactive        = defaults.tnfInactive.defaultValue!
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    private var _defaultsObservations   = [DefaultsDisposable]()
    
    /// Add observations of various properties used by the view
    ///
    private func addObservations() {
        
        _defaultsObservations = [
            
            Defaults.observe(\.dbLegend, options: [.initial, .new]) { [weak self] update in
                DispatchQueue.main.async {
                    self?._dbLegend.color = update.newValue! }},
            
            Defaults.observe(\.frequencyLegend, options: [.initial, .new]) { [weak self] update in
                DispatchQueue.main.async {
                    self?._frequencyLegend.color =  update.newValue!}},
            
            Defaults.observe(\.gridLine, options: [.initial, .new]) { [weak self] update in
                DispatchQueue.main.async {
                    self?._gridLine.color =  update.newValue! }},
            
            Defaults.observe(\.marker, options: [.initial, .new]) { [weak self] update in
                DispatchQueue.main.async {
                    self?._marker.color =  update.newValue! }},
            
            Defaults.observe(\.markerEdge, options: [.initial, .new]) { [weak self] update in
                DispatchQueue.main.async {
                    self?._markerEdge.color =  update.newValue! }},
            
            Defaults.observe(\.markerSegment, options: [.initial, .new]) { [weak self] update in
                DispatchQueue.main.async {
                    self?._markerSegment.color =  update.newValue! }},
            
            Defaults.observe(\.sliceActive, options: [.initial, .new]) { [weak self] update in
                DispatchQueue.main.async {
                    self?._sliceActive.color =  update.newValue! }},
            
            Defaults.observe(\.sliceFilter, options: [.initial, .new]) { [weak self] update in
                DispatchQueue.main.async {
                    self?._sliceFilter.color =  update.newValue! }},
            
            Defaults.observe(\.sliceInactive, options: [.initial, .new]) { [weak self] update in
                DispatchQueue.main.async {
                    self?._sliceInactive.color =  update.newValue! }},
            
            Defaults.observe(\.spectrum, options: [.initial, .new]) { [weak self] update in
                DispatchQueue.main.async {
                    self?._spectrum.color =  update.newValue! }},
            
            Defaults.observe(\.spectrumBackground, options: [.initial, .new]) { [weak self] update in
                DispatchQueue.main.async {
                    self?._spectrumBackground.color =  update.newValue! }},
            
            Defaults.observe(\.tnfActive, options: [.initial, .new]) { [weak self] update in
                DispatchQueue.main.async {
                    self?._tnfActive.color =  update.newValue! }},
            
            Defaults.observe(\.tnfInactive, options: [.initial, .new]) { [weak self] update in
                DispatchQueue.main.async {
                    self?._tnfInactive.color =  update.newValue! }}
        ]
    }
}
