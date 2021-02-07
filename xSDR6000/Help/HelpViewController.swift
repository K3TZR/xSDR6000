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

final class HelpViewController: NSViewController {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let kAutosaveName       = "xSDR6000HelpWindow"
    private let _log                = Logger.sharedInstance.logMessage
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _log("Help Viewer opened", .debug, #function, #file, #line)
        
        // dispaly the help file
        if let url = Bundle.main.url(forResource: "xSDR6000", withExtension: "pdf") {
            let pdf = PDFDocument(url: url)
            if let view = self.view as? PDFView {
                view.document = pdf
            }
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
    deinit {
        _log("Help Viewer closed", .debug, #function, #file, #line)
    }
}
