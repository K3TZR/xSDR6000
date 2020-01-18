
//  RadioPickerViewController.swift
//  CommonCode
//
//  Created by Mario Illgen on 13.01.17.
//  Copyright © 2017 Mario Illgen. All rights reserved.
//
//  Originally Created by Douglas Adams on 5/21/15.

import Cocoa
import SwiftyUserDefaults
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - LAN RadioPicker Delegate definition
// --------------------------------------------------------------------------------

protocol LANRadioPickerDelegate: class {
  
  /// Close this sheet
  ///
  func closeRadioPicker()
  
  /// Open the specified Radio
  ///
  /// - Parameters:
  ///   - radio:          a DiscoveryStruct struct
  ///   - remote:         remote / local
  ///   - handle:         remote handle
  /// - Returns:          success / failure
  ///
  func openRadio(_ radio: DiscoveryStruct?, remote: Bool, handle: String ) -> Bool
  
  /// Close the active Radio
  ///
  func closeRadio()

  /// Clear the reply table
  ///
  func clearTable()
  
  /// Close the application
  ///
  func terminateApp()
}

// --------------------------------------------------------------------------------
// MARK: - RadioPicker View Controller class implementation
// --------------------------------------------------------------------------------

final class LANRadioPickerViewController    : NSViewController, NSTableViewDelegate, NSTableViewDataSource {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private var _radioTableView     : NSTableView!                // table of Radios
  @IBOutlet private var _selectButton       : NSButton!                   // Connect / Disconnect
  @IBOutlet private var _defaultButton      : NSButton!                   // Set as default
  
  private var _api                          = Api.sharedInstance
  private var _radios                       : [DiscoveryStruct] { return Discovery.sharedInstance.discoveredRadios }
  private let _log                          = (NSApp.delegate as! AppDelegate)
  private var _selectedRadio                : DiscoveryStruct?            // Radio in selected row
  private weak var _parentVc                : NSViewController!
  
  private weak var _delegate                : RadioPickerDelegate? {
    return representedObject as? RadioPickerDelegate
  }

  // constants
  private let kColumnIdentifierDefaultRadio = "defaultRadio"
  private let kConnectTitle                 = "Connect"
  private let kDisconnectTitle              = "Disconnect"
  private let kSetAsDefault                 = "Set as Default"
  private let kClearDefault                 = "Clear Default"
  private let kDefaultFlag                  = "YES"
  
  // ----------------------------------------------------------------------------
  // MARK: - Overriden methods
  
  /// the View has loaded
  ///
  override func viewDidLoad() {
    super.viewDidLoad()

    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    // allow the User to double-click the desired Radio
    _radioTableView.doubleAction = #selector(LANRadioPickerViewController.selectButton(_:))
    
    _selectButton.title = kConnectTitle

    // get a reference to the Tab view controller (the "presented" vc)
    _parentVc = parent!
    
    addNotifications()
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Respond to the Quit menu item
  ///
  /// - Parameter sender:     the button
  ///
  @IBAction func quitRadio(_ sender: AnyObject) {
    
    _parentVc.dismiss(sender)
    
    // perform an orderly disconnect of all the components
    _api.disconnect(reason: .normal)
    
    _log.msg("Application closed by user", level: .info, function: #function, file: #file, line: #line)
    DispatchQueue.main.async {

      NSApp.terminate(self)
    }
  }
  /// Respond to the Default button
  ///
  /// - Parameter sender: the button
  ///
  @IBAction func defaultButton(_ sender: NSButton) {
    
    // save the selection
    let selectedRow = _radioTableView.selectedRow
    
    // Clear / Set the Default
    if sender.title == kClearDefault {
      
      Defaults[.defaultRadioSerialNumber] = ""
      
    } else {
      
      Defaults[.defaultRadioSerialNumber] = _radios[selectedRow].serialNumber
    }
    
    // to display the Default status
    _radioTableView.reloadData()
    
    // restore the selection
    _radioTableView.selectRowIndexes(IndexSet(integersIn: selectedRow..<selectedRow+1), byExtendingSelection: true)
    
  }
  /// Respond to the Close button
  ///
  /// - Parameter sender: the button
  ///
  @IBAction func closeButton(_ sender: AnyObject) {

    // close this view & controller
    _parentVc.dismiss(sender)
  }
  /// Respond to the Select button
  ///
  /// - Parameter _: the button
  ///
  @IBAction func selectButton( _: AnyObject ) {
    
    openClose()
  }
  /// Respond to a double-clicked Table row
  ///
  /// - Parameter _: the row clicked
  ///
  func doubleClick(_: AnyObject) {
    
    openClose()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Open or Close the selected Radio
  ///
  /// - Parameter open: Open/Close
  ///
  private func openClose() {
    
    guard let selectedRadio = _selectedRadio else { return }
    
    if _selectButton.title == kConnectTitle {
      
      // is the selected radio in use?
      if selectedRadio.status == "In_Use" && _api.radio == nil {

        // YES, ask the user to confirm closing it
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Disconnect Radio?"
        alert.informativeText = "Are you sure you want to disconnect the current radio session?"
        alert.addButton(withTitle: "Yes")   // 1000
        alert.addButton(withTitle: "No")    // 1001

        // ignore if not confirmed by the user
        alert.beginSheetModal(for: view.window!, completionHandler: { (response) in
          // close the connected Radio if the YES button pressed
          if response == NSApplication.ModalResponse.alertFirstButtonReturn { self.openRadio(selectedRadio) }
        })
      } else {
        // NO, just open it
        openRadio(selectedRadio)
      }

    } else {
      // RadioPicker sheet will remain open & Radio will be disconnected
      
      // tell the delegate to disconnect
      _delegate?.closeRadio()
      _selectButton.title = kConnectTitle
    }
  }
  /// Open a Radio & close the Picker
  ///
  private func openRadio(_ radio: DiscoveryStruct?) {
    
    // RadioPicker sheet will close & Radio will be opened
    
    // tell the delegate to connect to the selected Radio
    let _ = _delegate?.openRadio(radio, isWan: false, wanHandle: "")
    
    DispatchQueue.main.async { [unowned self] in
      self.closeButton(self)
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subscriptions to Notifications
  ///
  private func addNotifications() {
    
    // Available Radios changed
    NC.makeObserver(self, with: #selector(Discovered(_:)), of: .discoveredRadios)
  }
  /// Process .DiscoveryStructs Notification
  ///
  /// - Parameter note: a Notification instance
  ///
  @objc private func Discovered(_ note: Notification) {
    
    DispatchQueue.main.async { [weak self] in
      
      self?._radioTableView.reloadData()
    }
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
    return _radios.count
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
    let cellView = tableView.makeView(withIdentifier: tableColumn!.identifier, owner:self) as! NSTableCellView
    cellView.toolTip = _radios[row].description

    // is this the default row?
    let isDefaultRow = Defaults[.defaultRadioSerialNumber]  == _radios[row].serialNumber
    
    // set the stringValue of the cell's text field to the appropriate field
    switch tableColumn!.identifier.rawValue {
      
    case "model":     cellView.textField!.stringValue = _radios[row].model
    case "nickname":  cellView.textField!.stringValue = _radios[row].nickname
    case "status":    cellView.textField!.stringValue = _radios[row].status
    case "publicIp":  cellView.textField!.stringValue = _radios[row].publicIp
    default:          _log.msg("Unknown table column: \(tableColumn!.identifier.rawValue)", level: .error, function: #function, file: #file, line: #line)
    }

    // color the default row
    cellView.wantsLayer = true
    if isDefaultRow {
      cellView.layer!.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.2).cgColor
    } else {
      cellView.layer!.backgroundColor = NSColor.clear.cgColor
    }
    return cellView
  }
  /// Tableview selection change delegate method
  ///
  /// - Parameter notification: notification object
  ///
  func tableViewSelectionDidChange(_ notification: Notification) {
    
    // A row must be selected to enable the buttons
    _selectButton.isEnabled = (_radioTableView.selectedRow >= 0)
    _defaultButton.isEnabled = (_radioTableView.selectedRow >= 0)
    
    if _radioTableView.selectedRow >= 0 {
      // a row is selected
      _selectedRadio = _radios[_radioTableView.selectedRow]
      
      // set the "select button" title appropriately
      var isActive = false
      if let radio = Api.sharedInstance.radio {
        isActive = ( radio.discoveryPacket == _radios[_radioTableView.selectedRow] )
      }
      // set "default button" title appropriately
      _defaultButton.title = (Defaults[.defaultRadioSerialNumber] == _radios[_radioTableView.selectedRow].serialNumber ? kClearDefault : kSetAsDefault)
      _selectButton.title = (isActive ? kDisconnectTitle : kConnectTitle)
      
    } else {
      // no row is selected, set the button titles
      _defaultButton.title = kSetAsDefault
      _selectButton.title = kConnectTitle
    }
  }
}
