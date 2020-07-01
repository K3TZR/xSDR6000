//
//  AppDelegate.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/7/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa

@NSApplicationMain
  final class AppDelegate                     : NSObject, NSApplicationDelegate {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    
    Swift.print("----->>>>> Last window closed <<<<<-----")
    
    return true
  }
  func applicationWillTerminate(_ notification: Notification) {
    
    
    Swift.print("----->>>>> applicationWillTerminate <<<<<-----")
//    CVDisplayLinkStop()
    
  }
}


