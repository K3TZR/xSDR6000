//
//  MiniViewController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 7/15/20.
//  Copyright © 2020 Douglas Adams. All rights reserved.
//
import Cocoa
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - MiniView Delegate protocol
// --------------------------------------------------------------------------------

protocol MiniViewDelegate : class {
  
  func closeMiniWindows(_ item: AnyObject?)
}

final class MiniViewController : NSViewController {
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  var slice : xLib6000.Slice?
  var pan   : Panadapter?

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _miniContainer       : NSView!
  @IBOutlet private weak var _miniContainerHeight : NSLayoutConstraint!
  
  private var _delegate     : MainWindowController?
  
  private var _autosaveName = ""
  private var _flagVc       : FlagViewController!
  
  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    addNotifications()
    
    // create a Flag with this popover as its parent
    _flagVc = FlagViewController.createFlag(for: slice!, and: pan!, on: self)
    
    // add the Flag to the view hierarchy
    FlagViewController.addFlag(_flagVc!,
                               to: _miniContainer,
                               flagPosition: 0,
                               flagHeight: FlagViewController.kLargeFlagHeight,
                               flagWidth: FlagViewController.kLargeFlagWidth)
    
    // make it visible
    _miniContainerHeight.constant = 90
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
        
    _autosaveName = view.window!.title
    
    view.window!.level = .floating
    view.window!.styleMask.remove(.resizable)
    view.window!.styleMask.remove(.miniaturizable)

    view.window!.setFrameUsingName(_autosaveName)
  }
  
  override func viewWillDisappear() {
    super.viewWillDisappear()
    
    view.window!.saveFrame(usingName: _autosaveName)
  }
  
  deinit {
    Swift.print("----->>>>> MiniViewController Deinit")
    _flagVc.removeObservations()
  }

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  @IBAction func xMiniMenu(_ sender: NSMenuItem) {
    sender.boolState = false
    _delegate?.closeMiniWindows()
  }

  @IBAction func nextSliceMenu(_ sender: NSMenuItem) {
    if let slice = Api.sharedInstance.radio!.findActiveSlice() {
      let slicesOnThisPan = Api.sharedInstance.radio!.slices.values.sorted { $0.frequency < $1.frequency }
      var index = slicesOnThisPan.firstIndex(of: slice)!
      
      index = index + 1
      index = index % slicesOnThisPan.count
      
      slice.active = false
      slicesOnThisPan[index].active = true
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Internal methods

  func configure(delegate: MainWindowController, slice: Slice, pan: Panadapter) {
    _delegate = delegate
    self.slice = slice
    self.pan = pan
  }
  
  func setMiniHeight(_ height: CGFloat) {
    self._miniContainerHeight.constant = height
  }
  
  func removeObservations() {
    _flagVc.removeObservations()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Notification methods
  
  private func addNotifications() {
    NC.makeObserver(self, with: #selector(sliceChange(_:)), of: .sliceHasBeenAdded)
    NC.makeObserver(self, with: #selector(sliceChange(_:)), of: .sliceBecameActive)
  }

  @objc private func sliceChange(_ note: Notification) {
    let slice = note.object as! xLib6000.Slice

    // find the Panadapter of this Slice
    let pan = Api.sharedInstance.radio!.panadapters[slice.panadapterId]!
    
    DispatchQueue.main.async { [weak self] in
      self?._flagVc!.updateFlag(slice: slice, panadapter: pan)
    }
  }
}
