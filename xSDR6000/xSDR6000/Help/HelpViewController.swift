//
//  HelpViewController.swift
//  xAPITester
//
//  Created by Douglas Adams on 8/11/17.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Cocoa
import Quartz

// ------------------------------------------------------------------------------
// MARK: - Help ViewController Class implementation
// ------------------------------------------------------------------------------

final class HelpViewController              : NSViewController {
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let kAutosaveName                 = "xSDR6000HelpWindow"        // AutoSave name for the window
  
  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // dispaly the help file
    if let url = Bundle.main.url(forResource: "xSDR6000", withExtension: "pdf") {
      
      let pdf = PDFDocument(url: url)
      
      let view = self.view as! PDFView
      
      view.document = pdf
    }
  }
  
  override func viewWillAppear() {
    
    super.viewWillAppear()
    
    // restore the position
    view.window!.setFrameUsingName(kAutosaveName)
  }
  
  override func viewWillDisappear() {
    
    super.viewWillDisappear()
    
    // save the position
    view.window!.saveFrame(usingName: kAutosaveName)
  }
  
}
