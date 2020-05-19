//
//  RadioPickerViewController.swift
//  CommonCode
//
//  Created by Mario Illgen on 08.02.18.
//  Copyright © 2018 Mario Illgen. All rights reserved.
//

import Cocoa
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - RadioPicker delegate protocol
// --------------------------------------------------------------------------------

protocol RadioPickerDelegate             : class {
  
  var defaultRadio  : String? {get}
  var radios        : [DiscoveryPacket] {get}
  var isLoggedIn    : Bool {get}
  
  /// Connect  /  Disconnect the specified Radio
  /// - Parameters:
  ///   - packet:           a DIscoveryPacket
  ///   - connect:          connect / disconnect
  ///
  func radioAction(_ packet: DiscoveryPacket, connect: Bool)
  
  /// Determine whether the specified packet is the Default Radio packet
  /// - Parameter packet:   a DiscoveryPacket
  ///
  func isActive(_ packet: DiscoveryPacket) -> Bool
  
  /// Make the specified Radio the default (if any)
  ///
  /// - Parameter defaultString: a String identifying the default radio (if any)
  ///
  func setDefault(_ packet: DiscoveryPacket?)
  
  /// Request a Test Connection message be sent to the Radio
  ///
  /// - Parameter packet:   a Discovery packet
  ///
  func testConnection(_ packet: DiscoveryPacket)
  
  /// Login / Logout Auth0
  ///
  /// - Parameter login:    login / logout
  ///
  func auth0Action(login: Bool )
}

final class RadioPickerViewController : NSViewController, NSTableViewDelegate, NSTableViewDataSource {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  @IBOutlet public weak var testIndicator     : NSButton!

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _loginButton     : NSButton!
  @IBOutlet private weak var _testButton      : NSButton!
  @IBOutlet private weak var _nameLabel       : NSTextField!
  @IBOutlet private weak var _callLabel       : NSTextField!
  @IBOutlet private weak var _logonImage      : NSImageView!

  @IBOutlet private var _radioTable           : NSTableView!
  @IBOutlet private var _selectButton         : NSButton!
  
  private weak var _delegate                  : RadioPickerDelegate? { representedObject as? RadioPickerDelegate }
  private var _rightClick                     : NSClickGestureRecognizer!
  
  private let kConnectTitle                   = "Connect"
  private let kDisconnectTitle                = "Disconnect"
  private let kLogin                          = "Log In"
  private let kLogout                         = "Log Out"

  // ----------------------------------------------------------------------------
  // MARK: - Overriden methods
  
  /// the View has loaded
  ///
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    addNotifications()
    
    // setup Right Single Click recognizer
    _rightClick = NSClickGestureRecognizer(target: self, action: #selector(rightClick(_:)))
    _rightClick.buttonMask = 0x02
    _rightClick.numberOfClicksRequired = 1
    _radioTable.addGestureRecognizer(_rightClick)
    
    // allow the User to double-click the desired Radio
    _radioTable.doubleAction = #selector(RadioPickerViewController.selectButton(_:))
    
    _selectButton.title = kConnectTitle
    _loginButton.title = _delegate!.isLoggedIn ? kLogout : kLogin
    _nameLabel.stringValue = ""
    _callLabel.stringValue = ""
    testIndicator.boolState = false
  }
  
  override func viewDidAppear() {
    super.viewDidAppear()
    addObservations()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  @IBAction func closeButton(_ sender: NSButton) {
    dismiss(sender)
  }
  
  @IBAction func selectButton( _: NSButton ) {
    // Open / Close the selected Radio
    let row = _radioTable.selectedRow
    if row >= 0 {
      let packet = _delegate!.radios[row]
      
      // Connect / Disconnect
      _delegate!.radioAction(packet, connect: _selectButton.title == kConnectTitle)
      
      // close the picker
      dismiss(self)
    }
  }
  
  @IBAction func loginButton(_ sender: NSButton) {
    // Log In / Out of SmartLink
    _delegate?.auth0Action(login: _loginButton.title == kLogin)
    dismiss(self)
  }
  
  @IBAction func testButton(_ sender: NSButton) {
    // initiate a Wan connection test
    testIndicator.boolState = false
    let packet = _delegate!.radios[_radioTable.selectedRow]
    _delegate?.testConnection( packet )
  }
  
  @IBAction func quitRadio(_ sender: Any) {
    
    // perform an orderly disconnect of all the components
    if Api.sharedInstance.apiState != .disconnected { Api.sharedInstance.disconnect(reason: .normal) }
    
    dismiss(self)
    
    DispatchQueue.main.async {
      // close the app
      NSApp.terminate(sender)
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Respond to a Right Click gesture
  ///
  /// - Parameter gr: the GestureRecognizer
  ///
  @objc private func rightClick(_ gr: NSClickGestureRecognizer) {
    
    // get the "click" coordinates and convert to this View
    let mouseLocation = gr.location(in: _radioTable)
    
    // Calculate the clicked row
    let row = _radioTable.row(at: mouseLocation)
    
    // If the click occurred outside of a row (i.e. empty space), don't show the menu
    guard row != -1 else { return }
    
    // Select the clicked row, implicitly clearing the previous selection
    _radioTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    
    // create and display the popup menu
    let menu = NSMenu()
    menu.addItem(withTitle: "Clear  Default", action: #selector(clearDefault(_:)), keyEquivalent: "")
    menu.addItem(withTitle: "Set as Default", action: #selector(setDefault(_:)), keyEquivalent: "")
    menu.popUp(positioning: menu.item(at: 0), at: mouseLocation, in: _radioTable)
  }
  /// Set the Default radio
  ///
  /// - Parameter sender: a MenuItem
  ///
  @objc private func setDefault(_ sender: NSMenuItem) {
    
    let packet = _delegate!.radios[_radioTable.selectedRow]
    _delegate?.setDefault( packet )
    _radioTable.reloadData()
  }
  /// Clear the Default radio
  ///
  /// - Parameter sender: a MenuItem
  ///
  @objc private func clearDefault(_ sender: NSMenuItem) {
    
    _delegate?.setDefault( nil )
    _radioTable.reloadData()
  }
  /// Reload the Radio table
  ///
  private func reload() {
    DispatchQueue.main.async { [unowned self] in
      self._radioTable.reloadData()
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Observation methods

  private var _observations                 = [NSKeyValueObservation]()

  /// Add observations of various properties
  ///
  private func addObservations() {
    
    let delegate = _delegate as! RadioManager
    _observations = [
      
      delegate.observe(\.smartLinkUser, options: [.initial, .new]) { [weak self] (_, _) in
        DispatchQueue.main.async {
          self?._nameLabel.stringValue = delegate[keyPath: \.smartLinkUser] }},
      
      delegate.observe(\.smartLinkCall, options: [.initial, .new]) { [weak self] (_, _) in
        DispatchQueue.main.async {
          self?._callLabel.stringValue = delegate[keyPath: \.smartLinkCall] }},
      
      delegate.observe(\.smartLinkImage, options: [.initial, .new]) { [weak self] (_, _) in
        DispatchQueue.main.async {
          self?._logonImage.image = delegate[keyPath: \.smartLinkImage] }}
    ]
  }

  // ----------------------------------------------------------------------------
  // MARK: - Notification Methods
  
  /// Add subscriptions to Notifications
  ///
  private func addNotifications() {
    
    NC.makeObserver(self, with: #selector(radiosHasChanged(_:)), of: .discoveredRadios)
    NC.makeObserver(self, with: #selector(radiosHasChanged(_:)), of: .guiClientHasBeenAdded)
    NC.makeObserver(self, with: #selector(radiosHasChanged(_:)), of: .guiClientHasBeenRemoved)
  }
  @objc private func radiosHasChanged(_ note: Notification) {
    reload()
  }

  // ----------------------------------------------------------------------------
  // MARK: - NSTableView DataSource methods
  
  /// Tableview numberOfRows delegate method
  ///
  /// - Parameter aTableView:     the Tableview
  /// - Returns:                  number of rows
  ///
  func numberOfRows(in aTableView: NSTableView) -> Int {
    
    // get the number of rows
    return  _delegate!.radios.count
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - NSTableView Delegate methods
  
  /// Tableview view delegate method
  ///
  /// - Parameters:
  ///   - tableView:              the Tableview
  ///   - tableColumn:            a Tablecolumn
  ///   - row:                    the row number
  /// - Returns:                  an NSView
  ///
  func tableView( _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    
    let packet = _delegate!.radios[row]
    
    // get a view for the cell
    let cellView = tableView.makeView(withIdentifier: tableColumn!.identifier, owner:self) as! NSTableCellView
    cellView.toolTip = "Right-click to Set Default"
    
    // Default radio has unique color
    let packetParams = "\(packet.isWan ? "wan" : "local").\(packet.serialNumber)"
    cellView.textField!.textColor = (packetParams == _delegate?.defaultRadio ? NSColor.systemRed : NSColor.labelColor)
    
    // set the stringValue of the cell's text field to the appropriate field
    switch tableColumn!.identifier.rawValue {
    case "type":      cellView.textField!.stringValue = (packet.isWan ? "SMARTLINK" : "LOCAL")
    case "nickname":  cellView.textField!.stringValue = packet.nickname
    case "status":    cellView.textField!.stringValue = packet.status
    case "stations":  cellView.textField!.stringValue = (Version(packet.firmwareVersion).isNewApi ? packet.guiClientStations.replacingOccurrences(of: ",", with: ", ") : "n/a")
    case "publicIp":  cellView.textField!.stringValue = packet.publicIp
    default:          break
    }
    return cellView
  }
  /// Tableview selection change delegate method
  ///
  /// - Parameter notification:   notification object
  ///
  func tableViewSelectionDidChange(_ notification: Notification) {
    
    // A row must be selected to enable the buttons
    _selectButton.isEnabled = (_radioTable.selectedRow >= 0)
    
    // is a row is selected?
    if _radioTable.selectedRow >= 0 {
      
      let packet = _delegate!.radios[_radioTable.selectedRow]
      
      // YES, setup the Test button
      testIndicator.boolState = false
      _testButton.isEnabled = packet.isWan
      
      // setup the Select button
      _selectButton.title = _delegate!.isActive(packet) ? kDisconnectTitle : kConnectTitle
      
    } else {
      // NO, no row is selected
      _selectButton.title = kConnectTitle
      testIndicator.boolState = false
      _testButton.isEnabled = false
    }
  }
}
