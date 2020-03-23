//
//  MicProfileViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 1/30/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

final class ProfileViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

  @IBOutlet private weak var _segmentedControl  : NSSegmentedControl!
  @IBOutlet private weak var _tableView         : NSTableView!
  @IBOutlet private weak var _loadButton        : NSButton!
  @IBOutlet private weak var _deleteButton      : NSButton!
  
  private weak var _radio                       = Api.sharedInstance.radio
  private var _currentSelection                 : String!
  private var _array                            = [String]()
  private var _observations                     = [NSKeyValueObservation]()

  private let _autosaveName                     = "ProfilesWindow"
  private let _log                              = Logger.sharedInstance

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
    
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    view.translatesAutoresizingMaskIntoConstraints = false
    
    // allow the User to double-click the desired Profile
    _tableView.doubleAction = #selector(  clickLoad )
    
    // select the previously selected segment
    setupProfile(Defaults[.profilesTabId])
    
    // start observations
    addObservations()
    
    _log.logMessage("Profiles window opened", .info, #function, #file, #line)
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    
    view.window!.setFrameUsingName(_autosaveName)
    view.window!.level = .floating

    // select the previously selected segment
    setupProfile(Defaults[.profilesTabId])
  }

  override func viewWillDisappear() {
    super.viewWillDisappear()
    
    view.window!.saveFrame(usingName: _autosaveName)
  }
  deinit {
    _log.logMessage("Profiles window closed", .info, #function, #file, #line)

    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
  }

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Respond to a change in the Segmented COntrol
  ///
  /// - Parameter sender:             the control
  ///
  @IBAction func segmentedControl(_ sender: NSSegmentedControl) {
    
    switch sender.selectedSegment {
    case 0:
      Defaults[.profilesTabId] = Profile.Group.global.rawValue
    case 1:
      Defaults[.profilesTabId] = Profile.Group.tx.rawValue
    case 2:
      Defaults[.profilesTabId] = Profile.Group.mic.rawValue
    default:
      Defaults[.profilesTabId] = Profile.Group.global.rawValue
    }
    setupProfile(Defaults[.profilesTabId])
  }

  /// Respond to a change in a Profile name textfield
  ///
  /// - Parameter sender:             the TextField
  ///
  @IBAction func profileName(_ sender: NSTextField) {
    
    let row = _tableView.row(for: sender)
    
    _array[row] = sender.stringValue
    _tableView.reloadData()
    
    // tell the Radio
//    Profile.save(id, name: sender.stringValue)
  }
  /// Respond to one of the buttons
  ///
  /// - Parameter sender:             the Button
  ///
  @IBAction func buttons(_ sender: NSButton) {
    
    let row = _tableView.selectedRow

    switch sender.identifier!.rawValue {
    case "Delete":
      // tell the Radio
//      Profile.delete(id, name: _array[row])
      break

    case "Load":
      // change the selection
      _radio?.profiles[Defaults[.profilesTabId]]!.selection = _array[row]
      
    default:
      fatalError()
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Support double-click of a Profile
  ///
  @objc private func clickLoad() {
    
    _loadButton.performClick(self)
  }
//  /// Load a Profile by its Tag
//  ///
//  /// - Parameter tag:          the Tag of the Profile button
//  ///
//  private func loadProfile(tag: Int) {
//
//    switch tag {
//    case 0:
//      Defaults[.profilesTabId] = Profile.Group.global.rawValue
//    case 1:
//      Defaults[.profilesTabId] = Profile.Group.tx.rawValue
//    case 2:
//      Defaults[.profilesTabId] = Profile.Group.mic.rawValue
//    default:
//      _log.logMessage("Unknown profile tag: \(tag)", .error, #function, #file, #line)
//      Defaults[.profilesTabId] = Profile.Group.global.rawValue
//    }
//    setupProfile(Defaults[.profilesTabId])
//  }
  /// Load the Profile array
  ///
  /// - Parameter id:           a profile id
  ///
  private func setupProfile(_ id: String) {
  
    // get the selection
    _currentSelection = _radio!.profiles[id]!.selection
    
    // populate the table
    _array = _radio!.profiles[id]!.list
    
    reloadTable()
    
    // save the current Profile type
    Defaults[.profilesTabId] = id
  }
  /// Update the view and select the active profile
  ///
  private func reloadTable() {
    
    DispatchQueue.main.async { [unowned self] in
      var selectedIndex = -1
      
      // find the selection (if any)
      for (i, profileName) in self._array.enumerated() {
        if profileName == self._currentSelection { selectedIndex = i ; break}
      }
      // redraw
      self._tableView.reloadData()
      
      // highlight the selection (if any)
      self._tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: true)
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  /// Add observations of various properties used by the view
  ///
  private func addObservations() {
    
    _observations = [
      _radio!.profiles[Defaults[.profilesTabId]]!.observe(\.list, options: [.initial, .new]) { [weak self] (profile, change) in
        self?._array = profile.list },
      
      _radio!.profiles[Defaults[.profilesTabId]]!.observe(\.selection, options: [.initial, .new]) { [weak self] (profile, change) in
        self?._currentSelection = profile.selection }
    ]
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - NSTableView DataSource methods
  
  /// Tableview numberOfRows delegate method
  ///
  /// - Parameter aTableView: the Tableview
  /// - Returns: number of rows
  ///
  func numberOfRows(in aTableView: NSTableView) -> Int {
    
    // get the number of rows
    return _array.count
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - NSTableView Delegate methods
  
  /// Tableview view delegate method
  ///
  /// - Parameters:
  ///   - tableView: the Tableview
  ///   - tableColumn: a Tablecolumn
  ///   - row: the row number
  /// - Returns: an NSView
  ///
  func tableView( _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    
    // get a view for the cell
    let cellView = tableView.makeView(withIdentifier: tableColumn!.identifier, owner:self)
    
    // set the cell value
    (cellView as! NSTableCellView).textField?.stringValue = _array[row]
    (cellView as! NSTableCellView).textField?.formatter = ProfileFormatter()
    
    return cellView
  }
  /// Tableview selection change delegate method
  ///
  /// - Parameter notification:           notification object
  ///
  func tableViewSelectionDidChange(_ notification: Notification) {
    
    // A row must be selected to enable buttons
    _loadButton.isEnabled = (_tableView.selectedRow >= 0)
    _deleteButton.isEnabled = (_tableView.selectedRow >= 0)
  }

}
