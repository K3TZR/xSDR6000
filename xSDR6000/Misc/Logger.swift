//
//  Logger.swift
//  xSDR6000
//
//  Created by Douglas Adams on 3/4/20.
//  Copyright © 2020 Douglas Adams. All rights reserved.
//

import Foundation
import XCGLogger
import xLib6000

public class Logger : LogHandler {
  
  public static let kAppName                = "xSDR6000"
  
  // Log parameters
  static let kLoggerName                    = kAppName
  static let kLogFile                       = kLoggerName + ".log"
  static let kMaxLogFiles                   : UInt8 = 5
  static let kMaxFileSize                   : UInt64 = 20_000_000

  public var version                        : Version!
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties

  var logLevel : XCGLogger.Level {
    // first parameter is complete executable path, second parameter is the logDebug flag (if present)
    if CommandLine.arguments.count >= 2 {
      switch CommandLine.arguments[1].lowercased() {
      case "-logdebug":   return .debug
      case "-loginfo":    return .info
      case "-logwarning": return .warning
      case "-logerror":   return .error
      default:            return .info
      }
    } else {
      return .info
    }
  }
  
  // lazy setup of the XCGLogger
  lazy var log: XCGLogger = {
    
    // Create a logger object with no destinations
    let log = XCGLogger(identifier: Logger.kLoggerName, includeDefaultDestinations: false)
    
    #if DEBUG
    
    // for DEBUG only
    // Create a destination for the system console log (via NSLog)
    let systemDestination = AppleSystemLogDestination(identifier: Logger.kLoggerName + ".systemDestination")
    
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
    let fileDestination = AutoRotatingFileDestination(writeToFile: URL.logs.appendingPathComponent(Logger.kLogFile), identifier: Logger.kLoggerName + ".autoRotatingFileDestination")
    
    // Optionally set some configuration options
    fileDestination.targetMaxFileSize       = Logger.kMaxFileSize
    fileDestination.targetMaxLogFiles       = Logger.kMaxLogFiles
    fileDestination.outputLevel             = logLevel
    fileDestination.showLogIdentifier       = false
    fileDestination.showFileName            = false
    fileDestination.showFunctionName        = false
    fileDestination.showThreadName          = false
    fileDestination.showLevel               = true
    fileDestination.showLineNumber          = false
    
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
  // MARK: - Singleton
  
  /// Provide access to the Logger singleton
  ///
  public static var sharedInstance = Logger()
  
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
  public func logMessage(_ msg: String, _ level: MessageLevel, _ function: StaticString, _ file: StaticString, _ line: Int) -> Void {
    
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
