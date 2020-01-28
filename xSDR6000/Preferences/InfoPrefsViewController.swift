//
//  InfoPrefsViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 1/8/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

final class InfoPrefsViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

  static let kAppName                               = "appName"
  static let kEnabled                               = "enabled"
  static let kDelay                                 = "delay"
  static let kInterval                              = "interval"
  static let kParameters                            = "parameters"

  // ----------------------------------------------------------------------------
  // MARK: - Private properties

  @IBOutlet private weak var _versionGuiTextField   : NSTextField!
  @IBOutlet private weak var _versionApiTextField   : NSTextField!
  @IBOutlet private weak var _versionRadioTextField : NSTextField!
  
  @IBOutlet private weak var _tableView             : NSTableView!     // table of Apps
  @IBOutlet private weak var _deleteButton          : NSButton!
  
  //  var _array = [
  //    ["appName":"/Applications/Photo Booth.app", "enabled": true, "delay": false, "interval": 500, "parameter": ""],
  //    ["appName":"/Applications/Notes.app", "enabled": false, "delay": true, "interval": 2000, "parameter": ""],
  //    ["appName":"/Applications/Numbers.app", "enabled": true, "delay": false, "interval": 0, "parameter": ""],
  //    ["appName":"/Applications/News.app", "enabled": false, "delay": true, "interval": 50, "parameter": ""]
  //  ]
  private var _array                                : [[String:Any]] = []
  private var _observations                         = [NSKeyValueObservation]()
  

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    view.translatesAutoresizingMaskIntoConstraints = false
    
    // populate the version fields
    _versionApiTextField.stringValue = Api.kVersion.string
    _versionGuiTextField.stringValue = AppDelegate.kVersion.string
    _versionRadioTextField.stringValue = Api.sharedInstance.radio?.version.string ?? ""

    // load the array
    _array = Defaults[.supportingApps]
    
    // populate the App table
    _tableView.delegate = self
    _tableView.reloadData()
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Respond to the Add button
  ///
  /// - Parameter sender:             the button
  ///
  @IBAction func addButtton(_ sender: NSButton) {
    
    // open a dialog
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.allowedFileTypes = ["app"]
    panel.allowsOtherFileTypes = false
    panel.allowsMultipleSelection = false
    panel.directoryURL = FileManager.default.urls(for: .allApplicationsDirectory, in: .systemDomainMask).first!
    panel.beginSheetModal(for: view.window!, completionHandler: {(response) in
      // if something chosen
      if response == NSApplication.ModalResponse.OK {
        // if a valid path
        if let appPath = panel.url?.lastPathComponent {
          // get the name of the app
          let appName = String(appPath[..<appPath.firstIndex(of: ".")!])
          // add the app to the array
          self._array.append([InfoPrefsViewController.kAppName: appName,
                              InfoPrefsViewController.kEnabled: false,
                              InfoPrefsViewController.kDelay: false,
                              InfoPrefsViewController.kInterval: 0,
                              InfoPrefsViewController.kParameters: ""])
          // redraw the table
          self._tableView.reloadData()
          // update the Defaults
          self.save(self._array)
          
        } else {
          fatalError()
        }
      }
    })
  }
  /// Respond to the Delete button
  ///
  /// - Parameter sender:             the button
  ///
  @IBAction func deleteButton(_ sender: NSButton) {
    
    // a row must be selected
    if _tableView.selectedRow >= 0 {
      
      // remove from the array & redraw the table
      _array.remove(at: _tableView.selectedRow)
      _tableView.reloadData()
      
      // update the Defaults
      save(_array)
    }
  }
  /// Respond to one of the check boxes
  ///
  /// - Parameter sender:             the button
  ///
  @IBAction func checkBoxes(_ sender: NSButton) {
    
    let row = _tableView.row(for: sender)
    
    // update the array and the Defaults
    _array[row][sender.identifier!.rawValue] = sender.boolState
    save(_array)
  }
  /// Respond to one of the text fields
  ///
  /// - Parameter sender:             the text field
  ///
  @IBAction func textFields(_ sender: NSTextField) {
    
    let row = _tableView.row(for: sender)
    let identifier = sender.identifier!.rawValue
    
    // update the array
    switch identifier {

    case InfoPrefsViewController.kAppName, InfoPrefsViewController.kParameters:
      _array[row][identifier] = sender.stringValue

    case InfoPrefsViewController.kInterval:
      _array[row][identifier] = sender.integerValue

    default:
      fatalError()
    }
    // update the Defaults
    save(_array)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  private func save(_ array: [[String:Any]]) {
    
    Defaults[.supportingApps] = array
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

    // which type of cell?
    let identifier = tableColumn!.identifier.rawValue
    switch identifier {
    case InfoPrefsViewController.kAppName, InfoPrefsViewController.kParameters: // Strings
      (cellView as! NSTableCellView).textField?.stringValue = _array[row][identifier] as! String
      
    case InfoPrefsViewController.kEnabled, InfoPrefsViewController.kDelay:  // Bools
      (((cellView as! NSTableCellView).subviews[0]) as! NSButton).boolState = _array[row][identifier] as! Bool

    case InfoPrefsViewController.kInterval: // Ints
      (cellView as! NSTableCellView).textField?.integerValue = _array[row][identifier] as! Int

    default:
      fatalError()
    }
    return cellView
  }
  /// Tableview selection change delegate method
  ///
  /// - Parameter notification:           notification object
  ///
  func tableViewSelectionDidChange(_ notification: Notification) {
    
    // A row must be selected to enable the Delete button
    _deleteButton.isEnabled = (_tableView.selectedRow >= 0)
  }
}


