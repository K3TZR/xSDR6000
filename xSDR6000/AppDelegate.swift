//
//  AppDelegate.swift
//  xSDR6000
//
//  Created by Douglas Adams on 10/7/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa

@NSApplicationMain
  final class AppDelegate                     : NSObject, NSApplicationDelegate, NSWindowDelegate {

  private let transformer : Void = {
      let myTransformer = FrequencyTransformer()
      ValueTransformer.setValueTransformer(myTransformer, forName:NSValueTransformerName("FrequencyTransformer"))
  }()

  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

}


