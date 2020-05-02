//
//  LogViewerViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/1/20.
//  Copyright © 2020 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

class LogViewerViewController: NSViewController {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private var _textView           : NSTextView!
  @IBOutlet private weak var _logLevelPopUp : NSPopUpButton!
  
  private var _openFileUrl        : URL?
  private var _logEntries         : String!
  private var _filteredLogEntries = [String.SubSequence]()
  private lazy var _lines         = _textView.string.split(separator: "\n")
  
  // ----------------------------------------------------------------------------
  // MARK: - Overriden methods
  
  override func viewDidLoad() {
        super.viewDidLoad()

    _textView.isSelectable = false
    _textView.isEditable = false
    
    loadDefaultLog()
    
    _logLevelPopUp.selectItem(withTitle: Defaults[.logLevel])
    filterLog(level: Defaults[.logLevel])
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Respond to a change in the Log Level popup
  /// - Parameter sender:         the popup
  ///
  @IBAction func logLevelPopUp(_ sender: NSPopUpButton) {
    let level = sender.titleOfSelectedItem ?? "Debug"
    filterLog(level: level)
    Defaults[.logLevel] = level
  }
  /// Load the selected Log file
  /// - Parameter sender:         unused
  ///
  @IBAction func loadButton(_ sender: Any) {
    
    // allow the user to select a Log file
    let openPanel = NSOpenPanel()
    openPanel.canChooseFiles = true
    openPanel.allowedFileTypes = ["log"]
    openPanel.directoryURL = URL(fileURLWithPath: FileManager.appFolder.path + "/Logs")
    
    // open an Open Dialog
    openPanel.beginSheetModal(for: self.view.window!) { [weak self] (result: NSApplication.ModalResponse) in
      
      // if the user selects Open
      if result == NSApplication.ModalResponse.OK {
        do {
          let logString = try String(contentsOf: openPanel.url!, encoding: .ascii)
          
          self?._textView.string = logString
          self?._openFileUrl = openPanel.url!
          
        } catch {
          fatalError("Unable to open the Log file")
        }
      }
    }
  }
  /// Close the Log Viewer
  /// - Parameter sender:       unused
  ///
  @IBAction func closeButton(_ sender: Any) {
    view.window?.performClose(nil)
  }
  /// Save the currently open Log to a file
  /// - Parameter sender:       unused
  ///
  @IBAction func saveButton(_ sender: Any) {
    
    // Allow the User to save a copy of the Log file
    let savePanel = NSSavePanel()
    savePanel.allowedFileTypes = ["log"]
    savePanel.allowsOtherFileTypes = false
    savePanel.nameFieldStringValue = _openFileUrl?.lastPathComponent ?? ""
    savePanel.directoryURL = URL(fileURLWithPath: "~/Desktop".expandingTilde)
    
    // open a Save Dialog
    savePanel.beginSheetModal(for: self.view.window!) { [weak self] (result: NSApplication.ModalResponse) in
      
      // if the user pressed Save
      if result == NSApplication.ModalResponse.OK {
        
        // write it to the File
        do {
          try self?._textView.string.write(to: savePanel.url!, atomically: true, encoding: .ascii)
        } catch {
          fatalError("Unable to save the Log file")
        }
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Load the current Log
  ///
  private func loadDefaultLog() {
    // get the url for the Logs
    let logUrl = FileManager.appFolder.appendingPathComponent( "/Logs/xSDR6000.log")

    // does the Log file exist?
    if FileManager.default.fileExists( atPath: logUrl.path ) {
      // YES, read it & populate the textView
      _logEntries = try! String(contentsOf: logUrl, encoding: .ascii)
      _textView.string = _logEntries
    }
  }
  /// Filter the displayed Log
  /// - Parameter level:    log level
  ///
  private func filterLog(level: String) {
    // filter the log entries
    switch level {
    case "Debug":     _filteredLogEntries = _lines
    case "Info":      _filteredLogEntries = _lines.filter { $0.contains(" [Error] ") || $0.contains(" [Warning] ") || $0.contains(" [Info] ") }
    case "Warning":   _filteredLogEntries = _lines.filter { $0.contains(" [Error] ") || $0.contains(" [Warning] ") }
    case "Error":     _filteredLogEntries = _lines.filter { $0.contains(" [Error] ") }
    default:          _filteredLogEntries = _lines
    }
    _textView.string = _filteredLogEntries.joined(separator: "\n")
  }
  
}
