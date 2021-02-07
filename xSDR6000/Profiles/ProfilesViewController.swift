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

// --------------------------------------------------------------------------------
// MARK: - Profiles Delegate protocol
// --------------------------------------------------------------------------------

// protocol ProfilesDelegate : class {
//
//  var group       : Profile.Group {get set}
//  var profile     : Profile       {get}
////  var profileSelection   : String {get}
//
//  /// Load the specified Profile
//  ///
//  /// - Parameter row:      the row number in the Profile
//  ///
//  func load(_ row: Int)
//
//  /// Create a new Profile with the specified name
//  ///
//  /// - Parameter name:     a Profile name
//  ///
//  func create(_ name: String)
//
//  /// Reset the specified Profile
//  ///
//  /// - Parameter row:      the row number in the Profile
//  ///
//  func reset(_ row: Int)
//
//  /// Delete the specified Profile
//  ///
//  /// - Parameter row:      the row number in the Profile
//  ///
//  func delete(_ row: Int)
// }

final class ProfilesViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - Static properties
    
    static let autosaveName = "ProfilesWindow"
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    // state that could be sourced from a delegate
    private let _log          = Logger.sharedInstance.logMessage
    private let _api          = Api.sharedInstance
    private var _profiles     : [ProfileId: Profile] { _api.radio!.profiles}
    private var _profileType  : String {
        get { Defaults.profileType }
        set { Defaults.profileType = newValue }
    }
    
    @IBOutlet private weak var _segmentedControl  : NSSegmentedControl!
    @IBOutlet private weak var _tableView         : NSTableView!
    @IBOutlet private weak var _loadButton        : NSButton!
    @IBOutlet private weak var _createButton      : NSButton!
    @IBOutlet private weak var _resetButton       : NSButton!  
    @IBOutlet private weak var _deleteButton      : NSButton!
    @IBOutlet private weak var _nameTextField     : NSTextField!
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.translatesAutoresizingMaskIntoConstraints = false
        _log("Profiles window opened", .debug, #function, #file, #line)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        view.window!.setFrameUsingName(ProfilesViewController.autosaveName)
        view.window!.level = .floating
        
        // allow the User to double-click the desired Profile
        _tableView.doubleAction = #selector(  clickLoad )
        _tableView.allowsMultipleSelection = false
        
        // select the previously selected Profile type
        setupProfile(_profileType)
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        view.window!.saveFrame(usingName: ProfilesViewController.autosaveName)
    }
    
    deinit {
        _log("Profiles window closed", .debug, #function, #file, #line)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    @IBAction func segmentedControl(_ sender: NSSegmentedControl) {
        
        switch sender.selectedSegment {
        case 0:
            _profileType = Profile.Group.global.rawValue
        case 1:
            _profileType = Profile.Group.tx.rawValue
        case 2:
            _profileType = Profile.Group.mic.rawValue
        default:
            _profileType = Profile.Group.global.rawValue
        }
        setupProfile(_profileType)
    }
    
    @IBAction func buttons(_ sender: NSButton) {
        
        if _profiles[_profileType] == nil { _profileType = "global" }
        
        if _tableView.selectedRow >= 0 {
            let name = _profiles[_profileType]!.list[_tableView.selectedRow]
            
            switch sender.identifier!.rawValue {
            case "load":    loadProfile(_profileType, name: name)
            case "create":
                if !_nameTextField.stringValue.isEmpty {
                    createProfile(_profileType, name: _nameTextField.stringValue)
                    _nameTextField.stringValue = ""
                    _createButton.isEnabled = false
                    if let next = _nameTextField.nextResponder { next.becomeFirstResponder() }
                }
            case "reset":   resetProfile(_profileType, name: name)
            case "delete":  deleteProfile(_profileType, name: name)
            default:        break
            }
        }
    }
    
    //  @IBAction func quitRadio(_ sender: Any) {
    //    
    //    // perform an orderly disconnect of all the components
    //    if _api.state != .clientDisconnected { _api.disconnect(reason: "User Initiated") }
    //    
    //    _log("Application closed by user", .info, #function, #file, #line)
    //    DispatchQueue.main.async {
    //
    //      
    //      // close the app
    //      NSApp.terminate(sender)
    //    }
    //  }
    
    func controlTextDidChange(_ obj: Notification) {
        _createButton.isEnabled = !_nameTextField.stringValue.isEmpty
        
        _loadButton.isEnabled = _nameTextField.stringValue.isEmpty
        _deleteButton.isEnabled = _nameTextField.stringValue.isEmpty
        _resetButton.isEnabled = _nameTextField.stringValue.isEmpty
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Support double-click of a Profile
    ///
    @objc private func clickLoad() {
        
        _loadButton.performClick(self)
    }
    /// Load the Profile array
    ///
    /// - Parameter id:           a profile id
    ///
    private func setupProfile(_ type: String) {
        
        switch type.lowercased() {
        case "global":  _segmentedControl.selectSegment(withTag: 0) ; _profileType = type
        case "tx":      _segmentedControl.selectSegment(withTag: 1) ; _profileType = type
        case "mic":     _segmentedControl.selectSegment(withTag: 2) ; _profileType = type
        default:        _segmentedControl.selectSegment(withTag: 0) ; _profileType = "global"
        }
        addObservations(to: _profiles[_profileType]!)
        
        reloadTable()
    }
    /// Update the view and select the active profile
    ///
    private func reloadTable(select row: Int = -1) {
        
        if _profiles[_profileType] == nil { _profileType = "global" }
        
        // redraw
        var row = -1
        for i in 0..<_profiles[_profileType]!.list.count where _profiles[_profileType]!.list[i] == _profiles[_profileType]!.selection {
            row = i
        }
        DispatchQueue.main.async { [weak self] in
            self?._tableView.reloadData()
            if row >= 0 { self?._tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }    }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods that could be in a delegate
    
    private func loadProfile(_ type: String, name: String) {
        _log("Load profile: \(type)->\(name)", .debug, #function, #file, #line)
        _api.radio!.sendCommand("profile \(type) load \"" + "\(name)" + "\"")
    }
    
    private func createProfile(_ type: String, name: String) {
        var cmd = ""
        
        switch type {
        case "tx":  cmd = "profile transmit create \"" + "\(name.replacingOccurrences(of: "*", with: ""))" + "\""
        case "mic": cmd = "profile \(type) create \"" + "\(name.replacingOccurrences(of: "*", with: ""))" + "\""
        default:    break
        }
        guard !cmd.isEmpty else { return }
        
        _log("Create profile: \(type)->\(name)", .debug, #function, #file, #line)
        _api.radio!.sendCommand(cmd)
    }
    
    func resetProfile(_ type: String, name: String) {
        var cmd = ""
        
        switch type {
        case "tx":  cmd = "profile transmit reset \"" + "\(name.replacingOccurrences(of: "*", with: ""))" + "\""
        case "mic": cmd = "profile \(type) reset \"" + "\(name.replacingOccurrences(of: "*", with: ""))" + "\""
        default:    break
        }
        guard !cmd.isEmpty else { return }
        
        _log("Reset profile: \(type)->\(name)", .debug, #function, #file, #line)
        _api.radio!.sendCommand(cmd)
    }
    
    func deleteProfile(_ type: String, name: String) {
        var cmd = ""
        
        switch type {
        case "tx":      cmd = "profile transmit delete \"" + "\(name.replacingOccurrences(of: "*", with: ""))" + "\""
        case "mic":     cmd = "profile \(type) delete \"" + "\(name.replacingOccurrences(of: "*", with: ""))" + "\""
        case "global":  cmd = "profile \(type) delete \"" + name + "\""
        default:        break
        }
        guard !cmd.isEmpty else { return }
        
        _log("Delete profile: \(type)->\(name)", .debug, #function, #file, #line)
        _api.radio!.sendCommand(cmd)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    private var _observations                 = [NSKeyValueObservation]()
    
    /// Add observations of various properties
    ///
    private func addObservations(to profile: Profile ) {
        
        _observations = [NSKeyValueObservation]()
        
        _observations = [
            
            profile.observe(\.selection, options: [.initial, .new]) { [weak self] (_, _) in
                self?.reloadTable()},
            
            profile.observe(\.list, options: [.initial, .new]) { [weak self] (_, _) in
                self?.reloadTable()}
        ]
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - NSTableView DataSource methods
    
    /// Tableview numberOfRows delegate method
    ///
    /// - Parameter aTableView:   the Tableview
    /// - Returns:                number of rows
    ///
    func numberOfRows(in aTableView: NSTableView) -> Int {
        
        // get the number of rows
        return _profiles[_profileType]!.list.count
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - NSTableView Delegate methods
    
    /// Tableview view delegate method
    ///
    /// - Parameters:
    ///   - tableView:            the Tableview
    ///   - tableColumn:          a Tablecolumn
    ///   - row:                  the row number
    /// - Returns:                an NSView
    ///
    func tableView( _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        // get a view for the cell & set its textField
        if let column = tableColumn, let cellView = tableView.makeView(withIdentifier: column.identifier, owner: self) as? NSTableCellView {
            
            cellView.textField?.textColor = (_profiles[_profileType]!.selection == _profiles[_profileType]!.list[row] ? NSColor.systemRed : NSColor.labelColor)
            
            cellView.textField?.stringValue = _profiles[_profileType]!.list[row]
            
            return cellView
        }
        return nil
    }
    /// Tableview selection change delegate method
    ///
    /// - Parameter notification:           notification object
    ///
    func tableViewSelectionDidChange(_ notification: Notification) {
        
        // A row must be selected to enable buttons
        _loadButton.isEnabled = (_tableView.selectedRow >= 0)
        _deleteButton.isEnabled = (_tableView.selectedRow >= 0)
        _resetButton.isEnabled = (_tableView.selectedRow >= 0)
    }
}
