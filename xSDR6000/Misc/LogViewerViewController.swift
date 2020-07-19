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
  
  @IBOutlet private var _textView                 : NSTextView!
  @IBOutlet private weak var _logLevelPopUp       : NSPopUpButton!
  @IBOutlet private weak var _limitToPopUp        : NSPopUpButton!
  @IBOutlet private weak var _limitValueTextField : NSTextField!
  
  private let _log                = Logger.sharedInstance.logMessage
  private var _openFileUrl        : URL?
  private var _logEntries         : String!
  private var _filteredLines      = [String.SubSequence]()
  private lazy var _lines         = _textView.string.split(separator: "\n")
  
  // ----------------------------------------------------------------------------
  // MARK: - Overriden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()

    _log("Log Viewer opened", .debug,  #function, #file, #line)

    view.window?.windowController?.windowFrameAutosaveName = "LogViewerWindow"

    _textView.isSelectable = false
    _textView.isEditable = false
    
    loadDefaultLog()
    
    _logLevelPopUp.selectItem(withTitle: Defaults.logLevel)
    filterLog(level: Defaults.logLevel, limit: _limitToPopUp.titleOfSelectedItem ?? "None")
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    
    view.window!.setFrameUsingName("LogViewerWindow")
    view.window!.level = .floating
  }
  override func viewWillDisappear() {
    super.viewWillDisappear()
    
    view.window!.saveFrame(usingName: "LogViewerWindow")
  }
  
  deinit {
    _log("Log Viewer closed", .debug,  #function, #file, #line)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  @IBAction func limitPopUp(_ sender: NSPopUpButton) {
    let limit = sender.titleOfSelectedItem ?? "None"
    filterLog(level: _logLevelPopUp.titleOfSelectedItem ?? "Debug", limit: limit)
    
    _log("Log limit changed to: \(limit)", .debug,  #function, #file, #line)
  }
  
  @IBAction func limitToTextField(_ sender: NSTextField) {
    
    filterLog(level: _logLevelPopUp.titleOfSelectedItem ?? "Debug", limit: _limitToPopUp.titleOfSelectedItem ?? "None")

    _log("Log limit text changed to: \(sender.stringValue)", .debug,  #function, #file, #line)
  }

  @IBAction func loadButton(_ sender: Any) {
    
    // allow the user to select a Log file
    let openPanel = NSOpenPanel()
    openPanel.canChooseFiles = true
    openPanel.canChooseDirectories = false
    openPanel.allowsMultipleSelection = false
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

          self?._log("Log loaded: \(openPanel.url!)", .debug,  #function, #file, #line)

        } catch {
          let alert = NSAlert()
          alert.messageText = "Unable to load file"
          alert.informativeText = "File\n\n\(openPanel.url!)\n\nNOT loaded"
          alert.alertStyle = .critical
          alert.addButton(withTitle: "Ok")
          
          let _ = alert.runModal()
        }
      }
    }
  }

  @IBAction func logLevelPopUp(_ sender: NSPopUpButton) {
    let level = sender.titleOfSelectedItem ?? "Debug"
    filterLog(level: level, limit: _limitToPopUp.titleOfSelectedItem ?? "None")
    Defaults.logLevel = level

    _log("Log level changed to: \(level)", .debug,  #function, #file, #line)
  }
  
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

          self?._log("Log \(savePanel.nameFieldStringValue) saved to: \(savePanel.url!)", .debug,  #function, #file, #line)

        } catch {
          let alert = NSAlert()
          alert.messageText = "Unable to save Log"
          alert.informativeText = "File\n\n\(savePanel.url!)\n\nNOT saved"
          alert.alertStyle = .critical
          alert.addButton(withTitle: "Ok")
          
          let _ = alert.runModal()
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
    let defaultLogUrl = FileManager.appFolder.appendingPathComponent( "Logs/xSDR6000.log")

      // read it & populate the textView
      do {
        _logEntries = try String(contentsOf: defaultLogUrl, encoding: .ascii)
        _textView.string = _logEntries
        _openFileUrl = defaultLogUrl
        _log("Default Log loaded: \(defaultLogUrl)", .debug,  #function, #file, #line)

      } catch {
        let alert = NSAlert()
        alert.messageText = "Unable to load Default Log"
        alert.informativeText = "Log file\n\n\(defaultLogUrl)\n\nNOT found"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Ok")
        
        let _ = alert.runModal()
      }
  }
  /// Filter the displayed Log
  /// - Parameter level:    log level
  ///
  private func filterLog(level: String, limit: String) {
    var limitedLines = [String.SubSequence]()
    
    // filter the log entries
    switch level {
    case "Debug":     _filteredLines = _lines
    case "Info":      _filteredLines = _lines.filter { $0.contains(" [Error] ") || $0.contains(" [Warning] ") || $0.contains(" [Info] ") }
    case "Warning":   _filteredLines = _lines.filter { $0.contains(" [Error] ") || $0.contains(" [Warning] ") }
    case "Error":     _filteredLines = _lines.filter { $0.contains(" [Error] ") }
    default:          _filteredLines = _lines
    }
    
    switch limit {
    case "None":      limitedLines = _filteredLines
    case "Prefix":    limitedLines = _filteredLines.filter { $0.hasPrefix(_limitValueTextField.stringValue) }
    case "Contains":  limitedLines = _filteredLines.filter { $0.contains(_limitValueTextField.stringValue) }
    case "Excludes":  limitedLines = _filteredLines.filter { !$0.contains(_limitValueTextField.stringValue) }
    default:          limitedLines = _filteredLines
    }
    _textView.string = limitedLines.joined(separator: "\n")
  }
  
}
