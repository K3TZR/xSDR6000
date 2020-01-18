//
//  ColorsPrefsViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 1/8/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults

final class ColorsPrefsViewController            : NSViewController {
  
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
  
  private var _observations                      = [NSKeyValueObservation]()

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    view.translatesAutoresizingMaskIntoConstraints = false
    
    // start observing
    addObservations()
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  @IBAction func singleResetButtons(_ sender: NSButton) {
    
    // reset the respective color
    switch sender.identifier!.rawValue {
    case "DbLegendReset":
      Defaults.remove(.dbLegend)
    case "FrequencyLegendReset":
      Defaults.remove(.frequencyLegend)
    case "GridLineReset":
      Defaults.remove(.gridLine)
    case "MarkerReset":
      Defaults.remove(.marker)
    case "MarkerEdgeReset":
      Defaults.remove(.markerEdge)
    case "MarkerSegmentReset":
      Defaults.remove(.markerSegment)
    case "SliceActiveReset":
      Defaults.remove(.sliceActive)
    case "SliceFilterReset":
      Defaults.remove(.sliceFilter)
    case "SliceInactiveReset":
      Defaults.remove(.sliceInactive)
    case "SpectrumBackgroundReset":
      Defaults.remove(.spectrumBackground)
    case "SpectrumReset":
      Defaults.remove(.spectrum)
    case "TnfActiveReset":
      Defaults.remove(.tnfActive)
    case "TnfInactiveReset":
      Defaults.remove(.tnfInactive)
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
      Defaults[.dbLegend] = sender.color
    case "frequencyLegend":
      Defaults[.frequencyLegend] = sender.color
    case "gridLine":
      Defaults[.gridLine] = sender.color
    case "marker":
      Defaults[.marker] = sender.color
    case "markerEdge":
      Defaults[.markerEdge] = sender.color
    case "markerSegment":
      Defaults[.markerSegment] = sender.color
    case "sliceActive":
      Defaults[.sliceActive] = sender.color
    case "sliceFilter":
      Defaults[.sliceFilter] = sender.color
    case "sliceInactive":
      Defaults[.sliceInactive] = sender.color
    case "spectrum":
      Defaults[.spectrum] = sender.color
    case "spectrumBackground":
      Defaults[.spectrumBackground] = sender.color
    case "tnfActive":
      Defaults[.tnfActive] = sender.color
    case "tnfInactive":
      Defaults[.tnfInactive] = sender.color
    default:
      fatalError()
    }
  }
  /// Respond to the Reset button
  ///
  /// - Parameter sender:             the button
  ///
  @IBAction func resetButton(_ sender: NSButton) {
    
    // reset all colors to their default values
    Defaults.remove(.dbLegend)
    Defaults.remove(.frequencyLegend)
    Defaults.remove(.gridLine)
    Defaults.remove(.marker)
    Defaults.remove(.markerEdge)
    Defaults.remove(.markerSegment)
    Defaults.remove(.sliceActive)
    Defaults.remove(.sliceFilter)
    Defaults.remove(.sliceInactive)
    Defaults.remove(.spectrum)
    Defaults.remove(.spectrumBackground)
    Defaults.remove(.tnfActive)
    Defaults.remove(.tnfInactive)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  /// Add observations of various properties used by the view
  ///
  private func addObservations() {
    
    _observations = [
      
      Defaults.observe(\.dbLegend, options: [.initial, .new]) { [weak self] (object, change) in
        self?._dbLegend.color = Defaults[.dbLegend] },

      Defaults.observe(\.frequencyLegend, options: [.initial, .new]) { [weak self] (object, change) in
        self?._frequencyLegend.color = Defaults[.frequencyLegend] },

      Defaults.observe(\.gridLine, options: [.initial, .new]) { [weak self] (object, change) in
        self?._gridLine.color = Defaults[.gridLine] },

      Defaults.observe(\.marker, options: [.initial, .new]) { [weak self] (object, change) in
        self?._marker.color = Defaults[.marker] },

      Defaults.observe(\.markerEdge, options: [.initial, .new]) { [weak self] (object, change) in
        self?._markerEdge.color = Defaults[.markerEdge] },

      Defaults.observe(\.markerSegment, options: [.initial, .new]) { [weak self] (object, change) in
        self?._markerSegment.color = Defaults[.markerSegment] },

      Defaults.observe(\.sliceActive, options: [.initial, .new]) { [weak self] (object, change) in
        self?._sliceActive.color = Defaults[.sliceActive] },

      Defaults.observe(\.sliceFilter, options: [.initial, .new]) { [weak self] (object, change) in
        self?._sliceFilter.color = Defaults[.sliceFilter] },

      Defaults.observe(\.sliceInactive, options: [.initial, .new]) { [weak self] (object, change) in
        self?._sliceInactive.color = Defaults[.sliceInactive] },

      Defaults.observe(\.spectrum, options: [.initial, .new]) { [weak self] (object, change) in
        self?._spectrum.color = Defaults[.spectrum] },

      Defaults.observe(\.spectrumBackground, options: [.initial, .new]) { [weak self] (object, change) in
        self?._spectrumBackground.color = Defaults[.spectrumBackground] },

      Defaults.observe(\.tnfActive, options: [.initial, .new]) { [weak self] (object, change) in
        self?._tnfActive.color = Defaults[.tnfActive] },

      Defaults.observe(\.tnfInactive, options: [.initial, .new]) { [weak self] (object, change) in
        self?._tnfInactive.color = Defaults[.tnfInactive] }
    ]
  }
  /// Process observations
  ///
  /// - Parameters:
  ///   - defaults:                 the Defaults being observed
  ///   - change:                   the change
  ///
//  private func changeHandler(_ defaults: Any, _ change: Any) {
//
//    DispatchQueue.main.async { [weak self] in
//      self?._dbLegend.color = Defaults[.dbLegend]
//      self?._frequencyLegend.color = Defaults[.frequencyLegend]
//      self?._gridLine.color = Defaults[.gridLine]
//      self?._marker.color = Defaults[.marker]
//      self?._markerEdge.color = Defaults[.markerEdge]
//      self?._markerSegment.color = Defaults[.markerSegment]
//      self?._sliceActive.color = Defaults[.sliceActive]
//      self?._sliceFilter.color = Defaults[.sliceFilter]
//      self?._sliceInactive.color = Defaults[.sliceInactive]
//      self?._spectrum.color = Defaults[.spectrum]
//      self?._spectrumBackground.color = Defaults[.spectrumBackground]
//      self?._tnfActive.color = Defaults[.tnfActive]
//      self?._tnfInactive.color = Defaults[.tnfInactive]
//
//    }
//  }
}
