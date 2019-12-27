//
//  AppDelegate.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/7/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import XCGLogger
import SwiftyUserDefaults
import xLib6000

@NSApplicationMain
final class AppDelegate                     : NSObject, NSApplicationDelegate , LogHandler {
  
  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  // App parameters
  static let kName                          = "xSDR6000"
  static let kVersion                       = Version("2.4.9.2019_12_10" )
  
  // Log parameters
  static let kLoggerName                    = AppDelegate.kName
  static let kLogFile                       = AppDelegate.kLoggerName + ".log"
  static let kMaxLogFiles                   : UInt8 = 5
  static let kMaxFileSize                   : UInt64 = 1_048_576                     // 2^20
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  var logLevel : XCGLogger.Level {
    // first parameter is complete executable path, second parameter is the logDebug flag (if present)
    if CommandLine.arguments.count >= 2 {
      switch CommandLine.arguments[1].lowercased() {
      case "-logdebug":
        return .debug
      case "-loginfo":
        return .info
      case "-logwarning":
        return .warning
      case "-logerror":
        return .error
      default:
        return .debug
      }
    } else {
      return .debug
    }
  }
  
  // lazy setup of the XCGLogger
  lazy var log: XCGLogger = {
    
    // Create a logger object with no destinations
    let log = XCGLogger(identifier: AppDelegate.kLoggerName, includeDefaultDestinations: false)
    
    #if DEBUG
    
    // for DEBUG only
    // Create a destination for the system console log (via NSLog)
    let systemDestination = AppleSystemLogDestination(identifier: AppDelegate.kLoggerName + ".systemDestination")
    
    // Optionally set some configuration options
    systemDestination.outputLevel           = logLevel
    systemDestination.showLogIdentifier     = false
    systemDestination.showFileName          = false
    systemDestination.showFunctionName      = false
    systemDestination.showThreadName        = false
    systemDestination.showLevel             = true
    systemDestination.showLineNumber        = false
    
    // Add the destination to the logger
    log.add(destination: systemDestination)
    
    #endif
    
    // Create a file log destination
    let fileDestination = AutoRotatingFileDestination(writeToFile: URL.logs.appendingPathComponent(AppDelegate.kLogFile), identifier: AppDelegate.kLoggerName + ".autoRotatingFileDestination")
    
    // Optionally set some configuration options
    fileDestination.targetMaxFileSize       = AppDelegate.kMaxFileSize
    fileDestination.targetMaxLogFiles       = AppDelegate.kMaxLogFiles
    fileDestination.outputLevel             = logLevel
    fileDestination.showLogIdentifier       = false
    fileDestination.showFileName            = false
    fileDestination.showFunctionName        = true
    fileDestination.showThreadName          = true
    fileDestination.showLevel               = true
    fileDestination.showLineNumber          = true
    
    fileDestination.showDate                = true
    
    // Process this destination in the background
    fileDestination.logQueue = XCGLogger.logQueue
    
    // Add the destination to the logger
    log.add(destination: fileDestination)
    
    // Add basic app info, version info etc, to the start of the logs
    log.logAppDetails()
    
    // format the date (only effects the file logging)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss:SSS"
    dateFormatter.locale = Locale.current
    log.dateFormatter = dateFormatter
    
    return log
  }()

  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - LogHandlerDelegate methods
  
  /// Process log messages
  ///
  /// - Parameters:
  ///   - msg:        a message
  ///   - level:      the severity level of the message
  ///   - function:   the name of the function creating the msg
  ///   - file:       the name of the file containing the function
  ///   - line:       the line number creating the msg
  ///
  public func msg(_ msg: String, level: MessageLevel, function: StaticString, file: StaticString, line: Int ) -> Void {
    
    // Log Handler to support XCGLogger
    
    switch level {
    case .verbose:
      log.verbose(msg, functionName: function, fileName: file, lineNumber: line )
      
    case .debug:
      log.debug(msg, functionName: function, fileName: file, lineNumber: line)
      
    case .info:
      log.info(msg, functionName: function, fileName: file, lineNumber: line)
      
    case .warning:
      log.warning(msg, functionName: function, fileName: file, lineNumber: line)
      
    case .error:
      log.error(msg, functionName: function, fileName: file, lineNumber: line)
      
    case .severe:
      log.severe(msg, functionName: function, fileName: file, lineNumber: line)
    }
  }
}


