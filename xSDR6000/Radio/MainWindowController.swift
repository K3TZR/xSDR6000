//
//  MainWindowController.swift
//  xSDR6000
//
//  Created by Douglas Adams on 3/1/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import SwiftyUserDefaults

// --------------------------------------------------------------------------------
// MARK: - Main Window Controller class implementation
// --------------------------------------------------------------------------------

final class MainWindowController: NSWindowController, NSWindowDelegate {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    @objc dynamic var smartLinkCall   : String?
    @objc dynamic var smartLinkImage  : NSImage?
    @objc dynamic var smartLinkUser   : String?
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private weak var _connectButton       : NSButton!
    @IBOutlet private weak var _panButton           : NSButton!
    @IBOutlet private weak var _macAudioButton      : NSButton!
    @IBOutlet private weak var _tnfButton           : NSButton!
    @IBOutlet private weak var _markersButton       : NSButton!
    @IBOutlet private weak var _sideButton          : NSButton!
    @IBOutlet private weak var _fdxButton           : NSButton!
    @IBOutlet private weak var _cwxButton           : NSButton!
    @IBOutlet private weak var _lineoutMuteButton   : NSButton!
    @IBOutlet private weak var _headphoneMuteButton : NSButton!
    @IBOutlet private weak var _lineoutGainSlider   : NSSlider!
    @IBOutlet private weak var _headphoneGainSlider : NSSlider!
    
    private var _radioPickerViewController      : RadioPickerViewController?
    
    private var _pingResponse                   = false
    private var _api                            = Api.sharedInstance
    let _log                                    = Logger.sharedInstance.logMessage
    private var _observations                   = [NSKeyValueObservation]()
    private var _opusPlayer                     : OpusPlayer?
    var _radioManager                           : RadioManager!
    
    private var _sideViewController             : SideViewController?
    private var _profilesWindowController       : NSWindowController?
    private var _preferencesWindowController    : NSWindowController?
    private var _temperatureMeterAvailable      = false
    private var _voltageMeterAvailable          = false
    private var _pleaseWait                     : NSAlert!
    private var _xMiniWindows                   = [NSWindow]()

    var smartLinkEnabled: Bool { Defaults.smartLinkEnabled }
    var smartLinkIsLoggedIn = false

    private enum WindowState {
        case open
        case close
    }
    
    private lazy var _xSDR6000Menu              = NSApplication.shared.mainMenu?.item(withTitle: AppDelegate.kAppName)
    private lazy var _radioMenu                 = NSApplication.shared.mainMenu?.item(withTitle: "Radio")
    
    private let kSideStoryboardName             = "Side"
    private let kSideIdentifier                 = "Side"
    private let kSideViewDelay                  = 2   // seconds
    private let kAvailable                      = "available"
    private let kInUse                          = "in_use"
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        windowFrameAutosaveName = "MainWindow"
        
        // limit color pickers to the ColorWheel
        NSColorPanel.setPickerMask(NSColorPanel.Options.wheelModeMask)
        
        _radioMenu?.item(title: "SmartLink enabled")?.boolState = Defaults.smartLinkEnabled
        
        // get my version
        Logger.sharedInstance.version = Version()
        
        title()
        enableButtons(false)
        
        startupMessage()
        
        // create the Radio Manager
        _radioManager = RadioManager(delegate: self)
        
        addNotifications()
        
        findDefault()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        DispatchQueue.main.async { self.quitApplication(sender) }
        return false
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    // ----- Buttons -----
    
    @IBAction func connectButton(_ sender: NSButton) {
        if sender.title == "Connect" {
            //      _connectButton.isEnabled = false
            // find & open the default (if any)
            findDefault()
        } else {
            if Api.sharedInstance.state != .clientDisconnected { Api.sharedInstance.disconnect(reason: "User Initiated") }
        }
    }
    
    @IBAction func cwxButton(_ sender: NSButton) {
        Defaults.cwxViewOpen = sender.boolState
    }
    
    @IBAction func fdxButton(_ sender: NSButton) {
        Api.sharedInstance.radio!.fullDuplexEnabled = sender.boolState
    }
    
    @IBAction func headphoneGainSlider(_ sender: NSSlider) {
        Api.sharedInstance.radio!.headphoneGain = sender.integerValue
    }
    
    @IBAction func headphoneMuteButton(_ sender: NSButton) {
        Api.sharedInstance.radio!.headphoneMute = sender.boolState
    }
    
    @IBAction func lineoutGainSlider(_ sender: NSSlider) {
        Api.sharedInstance.radio!.lineoutGain = sender.integerValue
    }
    
    @IBAction func lineoutMuteButton(_ sender: NSButton) {
        Api.sharedInstance.radio!.lineoutMute = sender.boolState
    }
    
    @IBAction func macAudioButton(_ sender: NSButton) {
        Defaults.macAudioActive = sender.boolState
        if sender.boolState { macAudioStart() } else { macAudioStop() }
    }
    
    @IBAction func markersButton(_ sender: NSButton) {
        _radioMenu?.item(title: "Markers On/Off")?.boolState = sender.boolState
        Defaults.markersEnabled = sender.boolState
    }
    
    @IBAction func panButton(_ sender: AnyObject) {
        // dimensions are dummy values; when created, will be resized to fit its view
        Api.sharedInstance.radio?.requestPanadapter(CGSize(width: 50, height: 50))
    }
    
    @IBAction func sideButton(_ sender: NSButton) {
        _radioMenu?.item(title: "Side View On/Off")?.boolState = sender.boolState
        Defaults.sideViewOpen = sender.boolState
        if sender.boolState {
            openSideView()
        } else {
            closeSideView()
        }
    }
    
    @IBAction func tnfButton(_ sender: NSButton) {
        _radioMenu?.item(title: "Tnf On/Off")?.boolState = sender.boolState
        Api.sharedInstance.radio!.tnfsEnabled = sender.boolState
    }
    
    // ----- Menus -----
    
    @IBAction func markersMenu(_ sender: NSMenuItem) {
        sender.boolState.toggle()
        Defaults.markersEnabled = sender.boolState
        _markersButton.boolState = sender.boolState
    }
    
    @IBAction func nextSliceMenu(_ sender: NSMenuItem) {
        if let slice = Api.sharedInstance.radio!.findActiveSlice() {
            let slicesOnThisPan = Api.sharedInstance.radio!.slices.values.sorted { $0.frequency < $1.frequency }
            var index = slicesOnThisPan.firstIndex(of: slice)!
            
            index += 1
            index = index % slicesOnThisPan.count
            
            slice.active = false
            slicesOnThisPan[index].active = true
        }
    }
    
    @IBAction func panMenu(_ sender: NSMenuItem) {
        panButton(self)
    }
    
    @IBAction func quitxSDR6000Menu(_ sender: Any) {
        quitApplication(sender)
    }
    
    @IBAction func radioSelectionMenu(_ sender: AnyObject) {
        openRadioPicker()
    }
    
    @IBAction func sideMenu(_ sender: NSMenuItem) {
        sender.boolState.toggle()
        Defaults.sideViewOpen = sender.boolState
        _sideButton.boolState = sender.boolState
        
        if sender.boolState {
            openSideView()
        } else {
            closeSideView()
        }
    }
    
    @IBAction func smartLinkMenu(_ sender: NSMenuItem) {
        sender.boolState.toggle()
        Defaults.smartLinkEnabled = sender.boolState
        if sender.boolState == false {
            _radioManager?.smartLinkLogout()
        } else {
            _radioManager?.smartLinkLogin()
        }
    }
    
    @IBAction func tnfMenu(_ sender: NSMenuItem) {
        sender.boolState.toggle()
        Defaults.tnfsEnabled = sender.boolState
        _tnfButton.boolState = sender.boolState
        Api.sharedInstance.radio!.tnfsEnabled = sender.boolState
    }
    
    @IBAction func xMiniMenu(_ sender: NSMenuItem) {
        sender.boolState.toggle()
        
        if sender.boolState {
            // Show the Mini window(s) and minitiarize the main window
            showMiniWindows()
            window!.miniaturize(self)
            
        } else {
            // Close the Mini window(s) and restore the main window
            closeMiniWindows()
        }
    }
    
    /// Deccrement the active slice's frequency (by the step value)
    /// - Parameter sender:     a menu item
    ///
    @IBAction func decrFrequency(_ sender: Any) {
        if let slice = Api.sharedInstance.radio!.findActiveSlice() {
            // change the frequency
            slice.frequency -= slice.step
            // move the panadapter to keep the slice in the same relative position
            if let pan = Api.sharedInstance.radio?.panadapters[slice.panadapterId] {
                pan.center -= slice.step
            }
        }
    }
    
    /// Increment the active slice's frequency (by the step value)
    /// - Parameter sender:     a menu item
    ///
    @IBAction func incrFrequency(_ sender: Any) {
        if let slice = Api.sharedInstance.radio!.findActiveSlice() {
            // change the frequency
            slice.frequency += slice.step
            // move the panadapter to keep the slice in the same relative position
            if let pan = Api.sharedInstance.radio?.panadapters[slice.panadapterId] {
                pan.center += slice.step
            }
        }
    }
    
    @IBAction func toggleXmit(_ sender: Any) {
        if let slice = Api.sharedInstance.radio!.findActiveSlice() {
            slice.txEnabled.toggle()
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    private func showMiniWindows() {
        // for each panadapter on this Station
        for (id, pan) in _api.radio!.panadapters where _api.connectionHandle == pan.clientHandle {
            // if there is a Slice
            if let slice =  _api.radio!.findFirstSlice(on: id) {
                
                // create a Mini, set its title, show it cascaded with others
                let storyboard = NSStoryboard(name: "Main", bundle: nil)
                let xMini = storyboard.instantiateController(withIdentifier: "xmini") as? MiniViewController
                xMini?.configure(delegate: self, slice: slice, pan: pan)
                let xMiniWindow = NSWindow(contentViewController: xMini!)
                xMiniWindow.title = "xMini - \(pan.band)"
                xMiniWindow.makeKeyAndOrderFront(self)
                _xMiniWindows.append(xMiniWindow)
                
                // observe its closing
                NCtr.makeObserver(self, with: #selector(xMiniWindowWillClose(_:)), of: NSWindow.willCloseNotification.rawValue, object: xMiniWindow)
            }
        }
    }
    
    private func startupMessage() {
        if Defaults.showStartupMessage {
            
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Please help 👇"
                alert.informativeText =
                    """
        xSDR600 is starting to be useable for some even though it's far from complete.
        
        I want to focus on "stability" for the next few releases. I need feedback from users. If you see a bug or experience a crash, please take a minute to report it to:
        
        support@k3tzr.net
        
        If possible, include a copy of the log(s) found in:
        
        ~/Library/Application Support/net.k3tzr.xSDR6000/Logs/
        
        Thank you for your help! 👍
        """
                alert.alertStyle = .informational
                alert.showsSuppressionButton = true
                alert.runModal()
                Defaults.showStartupMessage = !alert.suppressionButton!.boolState
            }
        }
    }
    
    private func quitApplication(_ sender: Any) {
        _log("Application closed by user", .info, #function, #file, #line)
        
        usleep(50_000)
        
        // perform an orderly disconnect of all the components
        if Api.sharedInstance.state != .clientDisconnected { Api.sharedInstance.disconnect(reason: "User Initiated") }
        
        NSApp.terminate(nil)
    }
    
    /// Open the Side view
    ///
    private func openSideView() {
        if _sideViewController == nil {
            
            let sideStoryboard = NSStoryboard(name: "Side", bundle: nil)
            _sideViewController = sideStoryboard.instantiateController(withIdentifier: kSideIdentifier) as? SideViewController
            
            _log("Side view opened", .debug, #function, #file, #line)
            DispatchQueue.main.async { [weak self] in
                // add it to the split view
                if let viewController = self?.contentViewController {
                    viewController.addChild(self!._sideViewController!)
                }
            }
        }
    }
    
    /// Close the Side view (if open)
    ///
    private func closeSideView() {
        if _sideViewController != nil {
            
            DispatchQueue.main.async { [weak self] in
                // remove it from the split view
                if let viewController = self?.contentViewController {
                    // remove it
                    viewController.removeChild(at: 1)
                }
                self?._sideViewController = nil
                self?._log("Side view closed", .debug, #function, #file, #line)
            }
        }
    }
    
    /// Find and Open the Default Radio (if any) else the Radio Picker
    ///
    private func findDefault() {
        if Defaults.defaultRadio == nil {
            openRadioPicker()
            
        } else {
            checkLoop(interval: 1, wait: 4, condition: checkForDefault, completionHandler: { defaultFound in
                if defaultFound {
                    self.openSelectedRadio(Discovery.sharedInstance.defaultFound( Defaults.defaultRadio )!)
                } else {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Default Radio NOT found"
                        alert.alertStyle = .warning
                        alert.beginSheetModal(for: self.window!, completionHandler: { (_) in
                            self.openRadioPicker()
                        })
                    }
                }
            })
        }
    }
    
    /// Check if the default radio is in DiscoveredRadios
    /// - Returns: Bool for found / NOT found
    ///
    private func checkForDefault() -> Bool {
        return Discovery.sharedInstance.defaultFound( Defaults.defaultRadio ) != nil
    }
    
    /// Open the Radio Picker as a sheet
    ///
    private func openRadioPicker() {
        let radioPickerStoryboard = NSStoryboard(name: "RadioPicker", bundle: nil)
        _radioPickerViewController = radioPickerStoryboard.instantiateController(withIdentifier: "RadioPicker") as? RadioPickerViewController
        _radioPickerViewController!.delegate = self
        
        DispatchQueue.main.async { [unowned self] in
            // show the RadioPicker sheet
            self.window!.contentViewController!.presentAsSheet(self._radioPickerViewController!)
        }
    }
    
    /// Open the specified Radio
    /// - Parameter discoveryPacket: a DiscoveryPacket
    ///
    private func openRadio(_ packet: DiscoveryPacket) {
        _log("OpenRadio initiated: \(packet.nickname)", .debug, #function, #file, #line)
        //    DispatchQueue.main.async { self._connectButton.isEnabled = false }
        
        // CONNECT, is the selected radio connected to another client?
        switch (Version(packet.firmwareVersion).isNewApi, packet.status.lowercased(), packet.guiClients.count) {
        
        case (false, kAvailable, _):          // oldApi, not connected to another client
            _radioManager.connectRadio(packet)
            
        case (false, kInUse, _):              // oldApi, connected to another client
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Radio is connected to another Client"
                alert.informativeText = "Close the Client?"
                alert.addButton(withTitle: "Close current client")
                alert.addButton(withTitle: "Cancel")
                
                // ignore if not confirmed by the user
                alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
                    // close the connected Radio if the YES button pressed
                    
                    switch response {
                    case NSApplication.ModalResponse.alertFirstButtonReturn:
                        self._radioManager.connectRadio(packet, pendingDisconnect: .oldApi)
                        sleep(1)
                        self._api.disconnect()
                        sleep(1)
                        self.openRadioPicker()
                        
                    default:  break
                    }
                    
                })}
            
        case (true, kAvailable, 0):           // newApi, not connected to another client
            _radioManager.connectRadio(packet)
            
        case (true, kAvailable, _):           // newApi, connected to another client
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Radio is connected to Station: \(packet.guiClients[0].station)"
                alert.informativeText = "Close the Station . . Or . . Connect using Multiflex . . Or . . use Remote Control"
                alert.addButton(withTitle: "Close \(packet.guiClients[0].station)")
                alert.addButton(withTitle: "Multiflex Connect")
                alert.addButton(withTitle: "Remote Control")
                alert.addButton(withTitle: "Cancel")
                
                alert.buttons[2].isEnabled = false
                
                // ignore if not confirmed by the user
                alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
                    // close the connected Radio if the YES button pressed
                    
                    switch response {
                    case NSApplication.ModalResponse.alertFirstButtonReturn:  self._radioManager.connectRadio(packet,
                                                                                                              pendingDisconnect: .newApi(handle: packet.guiClients[0].handle))
                    case NSApplication.ModalResponse.alertSecondButtonReturn: self._radioManager.connectRadio(packet)
                    default:  break
                    }
                })}
            
        case (true, kInUse, 2):               // newApi, connected to 2 clients
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Radio is connected to multiple Stations"
                alert.informativeText = "Close one of the Stations . . Or . . use Remote Control"
                alert.addButton(withTitle: "Close \(packet.guiClients[0].station)")
                alert.addButton(withTitle: "Close \(packet.guiClients[1].station)")
                alert.addButton(withTitle: "Remote Control")
                alert.addButton(withTitle: "Cancel")
                
                alert.buttons[2].isEnabled = false
                
                // ignore if not confirmed by the user
                alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
                    
                    switch response {
                    case NSApplication.ModalResponse.alertFirstButtonReturn:  self._radioManager.connectRadio(packet,
                                                                                                              pendingDisconnect: .newApi(handle: packet.guiClients[0].handle))
                    case NSApplication.ModalResponse.alertSecondButtonReturn: self._radioManager.connectRadio(packet,
                                                                                                              pendingDisconnect: .newApi(handle: packet.guiClients[1].handle))
                    default:  break
                    }
                })}
            
        default:
            break
        }
    }
    
    /// Close  a currently active connection
    ///
    private func closeRadio(_ packet: DiscoveryPacket) {
        _log("CloseRadio initiated: \(packet.nickname)", .debug, #function, #file, #line)
        //    DispatchQueue.main.async { self._connectButton.isEnabled = true }
        
        // CONNECT, is the selected radio connected to another client?
        switch (Version(packet.firmwareVersion).isNewApi, packet.status.lowercased(), packet.guiClients.count) {
        
        case (false, _, _):                   // oldApi
            self.disconnectApplication()
            
        case (true, kAvailable, 1):           // newApi, 1 client
            // am I the client?
            if packet.guiClients[0].handle == _api.connectionHandle {
                // YES, disconnect me
                self.disconnectApplication()
                
            } else {
                // NO, let the user choose what to do (don't think can ever be executed)
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.alertStyle = .informational
                    alert.messageText = "Radio is connected to one Station"
                    alert.informativeText = "Close the Station . . Or . . Disconnect " + AppDelegate.kAppName
                    alert.addButton(withTitle: "Close \(packet.guiClients[0].station)")
                    alert.addButton(withTitle: "Disconnect " + AppDelegate.kAppName)
                    alert.addButton(withTitle: "Cancel")
                    
                    alert.buttons[0].isEnabled = packet.guiClients[0].station != AppDelegate.kAppName
                    
                    // ignore if not confirmed by the user
                    alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
                        // close the connected Radio if the YES button pressed
                        
                        switch response {
                        case NSApplication.ModalResponse.alertFirstButtonReturn:  self._api.requestClientDisconnect( packet: packet, handle: packet.guiClients[0].handle)
                        case NSApplication.ModalResponse.alertSecondButtonReturn: self.disconnectApplication()
                        default:      break
                            
                        }
                    })}
            }
            
        case (true, kInUse, 2):           // newApi, 2 clients
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.alertStyle = .informational
                alert.messageText = "Radio is connected to multiple Stations"
                alert.informativeText = "Close a Station . . Or . . Disconnect "  + AppDelegate.kAppName
                if packet.guiClients[0].station != AppDelegate.kAppName {
                    alert.addButton(withTitle: "Close \(packet.guiClients[0].station)")
                } else {
                    alert.addButton(withTitle: "---")
                }
                if packet.guiClients[1].station != AppDelegate.kAppName {
                    alert.addButton(withTitle: "Close \(packet.guiClients[1].station)")
                } else {
                    alert.addButton(withTitle: "---")
                }
                alert.addButton(withTitle: "Disconnect " + AppDelegate.kAppName)
                alert.addButton(withTitle: "Cancel")
                
                alert.buttons[0].isEnabled = packet.guiClients[0].station != AppDelegate.kAppName
                alert.buttons[1].isEnabled = packet.guiClients[1].station != AppDelegate.kAppName
                
                // ignore if not confirmed by the user
                alert.beginSheetModal(for: NSApplication.shared.mainWindow!, completionHandler: { (response) in
                    
                    switch response {
                    case NSApplication.ModalResponse.alertFirstButtonReturn:  self._api.requestClientDisconnect( packet: packet, handle: packet.guiClients[0].handle)
                    case NSApplication.ModalResponse.alertSecondButtonReturn: self._api.requestClientDisconnect( packet: packet, handle: packet.guiClients[1].handle)
                    case NSApplication.ModalResponse.alertThirdButtonReturn:  self.disconnectApplication()
                    default:      break
                    }
                })}
            
        default:
            self.disconnectApplication()
        }
    }
    
    /// Start Mac Audio
    ///
    private func macAudioStart() {
        // what API version?
        if _api.radio!.version.isNewApi {
            // NewApi
            _api.radio!.requestRemoteRxAudioStream()
        } else {
            // OldApi
            Api.sharedInstance.radio!.startStopOpusRxAudioStream(state: true)
            usleep(50_000)
            _opusPlayer?.start()
        }
    }
    
    /// Stop Mac Audio
    ///
    private func macAudioStop() {
        // what API version?
        if _api.radio!.version.isNewApi {
            // NewApi
            _opusPlayer?.stop()
            _opusPlayer = nil
            _api.radio!.removeRemoteRxAudioStream(for: _api.connectionHandle!)
        } else {
            // OldApi
            Api.sharedInstance.radio!.startStopOpusRxAudioStream(state: false)
            _opusPlayer?.stop()
        }
    }
    
    /// Disconect this Application
    ///
    private func disconnectApplication() {
        // perform an orderly disconnect of all the components
        _api.disconnect(reason: "User Initiated")
    }
    
    /// Set the Window's title
    ///
    private func title() {
        // set the title bar
        DispatchQueue.main.async { [unowned self] in
            var title = ""
            // are we connected?
            if let radio = Api.sharedInstance.radio {
                // YES, format and set the window title
                title = "\(radio.packet.nickname)" +
                    " v\(radio.version.longString)" +
                    " \(radio.packet.isWan ? "SmartLink" : "Local")" +
                    "         \(AppDelegate.kAppName)" +
                    " v\(Logger.sharedInstance.version.string)"
                
            } else {
                // NO, show App & Api only
                title = "\(AppDelegate.kAppName) v\(Logger.sharedInstance.version.string)"
            }
            self.window?.title = title
        }
    }
}

extension MainWindowController {
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    /// Add observations of various properties used by the Panadapter
    ///
    private func addObservations(of radio: Radio) {
        _observations = [
            radio.observe(\.tnfsEnabled, options: [.initial, .new]) { [weak self] (_, _) in
                DispatchQueue.main.async { self?._tnfButton.boolState = radio[keyPath: \.tnfsEnabled]} },
            radio.observe(\.fullDuplexEnabled, options: [.initial, .new]) { [weak self] (_, _) in
                DispatchQueue.main.async { self?._fdxButton.boolState = radio[keyPath: \.fullDuplexEnabled]} },
            radio.observe(\.lineoutMute, options: [.initial, .new]) { [weak self] (_, _) in
                DispatchQueue.main.async { self?._lineoutMuteButton.boolState = radio[keyPath: \.lineoutMute]} },
            radio.observe(\.headphoneMute, options: [.initial, .new]) { [weak self] (_, _) in
                DispatchQueue.main.async { self?._headphoneMuteButton.boolState = radio[keyPath: \.headphoneMute]} },
            radio.observe(\.lineoutGain, options: [.initial, .new]) { [weak self] (_, _) in
                DispatchQueue.main.async { self?._lineoutGainSlider.integerValue = radio[keyPath: \.lineoutGain]} },
            radio.observe(\.headphoneGain, options: [.initial, .new]) { [weak self] (_, _) in
                DispatchQueue.main.async { self?._headphoneGainSlider.integerValue = radio[keyPath: \.headphoneGain]} }
        ]
    }
    
    private func removeObservations() {
        // invalidate each observation
        _observations.forEach { $0.invalidate() }
        
        // remove the tokens
        _observations.removeAll()
    }
    
    /// Enable / Disable UI elements
    ///
    /// - Parameters:
    ///   - state:       enable / disable
    ///
    private func enableButtons(_ state: Bool) {
        DispatchQueue.main.async { [weak self] in
            
            self?._log("EnableButtons: state = \(state)", .debug, #function, #file, #line)
            
            self?._panButton.isEnabled            = state
            self?._macAudioButton.isEnabled       = state
            self?._tnfButton.isEnabled            = state
            self?._markersButton.isEnabled        = state
            self?._fdxButton.isEnabled            = state
            self?._cwxButton.isEnabled            = state
            self?._lineoutGainSlider.isEnabled    = state
            self?._lineoutMuteButton.isEnabled    = state
            self?._headphoneGainSlider.isEnabled  = state
            self?._headphoneMuteButton.isEnabled  = state
            
            self?._connectButton.title = (state ? "Disconnect" : "Connect")
            
            self?._xSDR6000Menu?.item(title: "Preferences")?.isEnabled = state
            self?._xSDR6000Menu?.item(title: "Profiles")?.isEnabled = state
            
            self?._radioMenu?.item(title: "New Pan")?.isEnabled = state
            self?._radioMenu?.item(title: "Tnf On/Off")?.isEnabled = state
            self?._radioMenu?.item(title: "Markers On/Off")?.isEnabled = state
            self?._radioMenu?.item(title: "Side View On/Off")?.isEnabled = state
            self?._radioMenu?.item(title: "Next Slice")?.isEnabled = state
            self?._radioMenu?.item(title: "xMini")?.isEnabled = state
        }
    }
    
    private func setButtonState(_ radio: Radio) {
        DispatchQueue.main.async { [weak self] in
            
            self?._log("setButtonState: radio = \(String(describing: radio))", .debug, #function, #file, #line)
            
            self?._macAudioButton.boolState         = Defaults.macAudioActive
            
            self?._tnfButton.boolState              = radio.tnfsEnabled
            self?._radioMenu?.item(title: "Tnf On/Off")?.boolState = radio.tnfsEnabled
            
            self?._markersButton.boolState          = Defaults.markersEnabled
            self?._radioMenu?.item(title: "Markers On/Off")?.boolState = Defaults.markersEnabled
            
            self?._sideButton.boolState             = Defaults.sideViewOpen
            self?._radioMenu?.item(title: "Side View On/Off")?.boolState = Defaults.sideViewOpen
            
            self?._fdxButton.boolState              = radio.fullDuplexEnabled
            self?._cwxButton.boolState              = Defaults.cwxViewOpen
            self?._lineoutGainSlider.integerValue   = radio.lineoutGain
            self?._lineoutMuteButton.boolState      = radio.lineoutMute
            self?._headphoneGainSlider.integerValue = radio.headphoneGain
            self?._headphoneMuteButton.boolState    = radio.headphoneMute
            
            //      self?._connectButton.isEnabled = true
        }
    }
    
    private func closeRadioPicker() {
        if _radioPickerViewController != nil { _radioPickerViewController?.dismiss( self ) }
        _radioPickerViewController = nil
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    private func addNotifications() {
        NCtr.makeObserver(self, with: #selector(didDeminiaturize(_:)), of: NSWindow.didDeminiaturizeNotification.rawValue)
        
        NCtr.makeObserver(self, with: #selector(radioHasBeenAdded(_:)), of: .radioHasBeenAdded)
        NCtr.makeObserver(self, with: #selector(radioWillBeRemoved(_:)), of: .radioWillBeRemoved)
        NCtr.makeObserver(self, with: #selector(radioHasBeenRemoved(_:)), of: .radioHasBeenRemoved)
        
        NCtr.makeObserver(self, with: #selector(panadapterWillBeRemoved(_:)), of: .panadapterWillBeRemoved)
        NCtr.makeObserver(self, with: #selector(sliceWillBeRemoved(_:)), of: .sliceWillBeRemoved)
        
        NCtr.makeObserver(self, with: #selector(tcpPingResponse(_:)), of: .tcpPingResponse)
        
        NCtr.makeObserver(self, with: #selector(opusAudioStreamHasBeenAdded(_:)), of: .opusAudioStreamHasBeenAdded)
        NCtr.makeObserver(self, with: #selector(opusAudioStreamWillBeRemoved(_:)), of: .opusAudioStreamWillBeRemoved)
        
        NCtr.makeObserver(self, with: #selector(remoteRxAudioStreamHasBeenAdded(_:)), of: .remoteRxAudioStreamHasBeenAdded)
        NCtr.makeObserver(self, with: #selector(remoteRxAudioStreamWillBeRemoved(_:)), of: .remoteRxAudioStreamWillBeRemoved)
    }
    
    @objc private func radioHasBeenAdded(_ note: Notification) {
        // the Radio class has been initialized
        if let radio = note.object as? Radio {
            
            _log("Radio initialized: \(radio.nickname), v\(radio.packet.firmwareVersion)", .info, #function, #file, #line)

            enableButtons(true)
            title()
            
            addObservations(of: radio)
            setButtonState(radio)
        }
    }
    
    @objc private func radioWillBeRemoved(_ note: Notification) {
        // the Radio class is being removed
        if let radio = note.object as? Radio {
            
            _log("Radio will be removed: \(radio.nickname)", .info, #function, #file, #line)
            
            _pingResponse = false
            enableButtons(false)
            
            closeMiniWindows()
            
            // close the Side view (if open)
            if Defaults.sideViewOpen { DispatchQueue.main.async { self.closeSideView() } }
            
            // stop Mac audio (if active)
            if Defaults.macAudioActive { macAudioStop() }

            removeObservations()
            radio.removeAllObjects()
            title()
        }
    }
    
    @objc private func radioHasBeenRemoved(_ note: Notification) {
        if let name = note.object as? String {
            // the Radio class has been removed
            _log("Radio has been removed: \(name)", .info, #function, #file, #line)
        }
    }
    
    @objc private func tcpPingResponse(_ note: Notification) {
        // receipt of the first n Ping responses indicates the Radio is being initialized
        _pingResponse = true

        _log("Ping response received", .info, #function, #file, #line)

        // show/hide the Side view
        if Defaults.sideViewOpen { DispatchQueue.main.async { self.openSideView() } }

        // start audio if active
        if Defaults.macAudioActive { macAudioStart() }
    }
    
    @objc private func opusAudioStreamHasBeenAdded(_ note: Notification) {
        // the OpusAudioStream has been added
        if let opusAudioStream = note.object as? OpusAudioStream {
            
            _log("OpusAudioStream added: id = \(opusAudioStream.id.hex)", .info, #function, #file, #line)
            
            _opusPlayer = OpusPlayer()
            opusAudioStream.delegate = _opusPlayer
            if Defaults.macAudioActive { _opusPlayer!.start() }
        }
    }
    
    @objc private func opusAudioStreamWillBeRemoved(_ note: Notification) {
        // the OpusAudioStream is being removed
        if let opusAudioStream = note.object as? OpusAudioStream {
            
            _log("OpusAudioStream will be removed: id = \(opusAudioStream.id.hex)", .info, #function, #file, #line)
            
            opusAudioStream.delegate = nil
            _opusPlayer?.stop()
            _opusPlayer = nil
        }
    }
    
    @objc private func remoteRxAudioStreamHasBeenAdded(_ note: Notification) {
        // the RemoteRxAudioStream class has been initialized
        if let remoteRxAudioStream = note.object as? RemoteRxAudioStream {
            
            _log("RemoteRxAudioStream added: id = \(remoteRxAudioStream.id.hex)", .info, #function, #file, #line)
            
            _opusPlayer = OpusPlayer()
            _opusPlayer?.start()
            remoteRxAudioStream.delegate = _opusPlayer
        }
    }
    
    @objc private func remoteRxAudioStreamWillBeRemoved(_ note: Notification) {
        // the RemoteRxAudioStream is being removed
        if let remoteRxAudioStream = note.object as? RemoteRxAudioStream {
            
            _log("RemoteRxAudioStream will be removed: id = \(remoteRxAudioStream.id.hex)", .info, #function, #file, #line)
            
            remoteRxAudioStream.delegate = nil
//            _opusPlayer?.stop()
//            _opusPlayer = nil
        }
    }
    
    @objc private func panadapterWillBeRemoved(_ note: Notification) {
        if let pan = note.object as? Panadapter {
            closeMiniWindows( pan as AnyObject)
        }
    }
    
    @objc private func sliceWillBeRemoved(_ note: Notification) {
        if let slice = note.object as? Slice {
            closeMiniWindows( slice as AnyObject)
        }
    }
    
    @objc private func xMiniWindowWillClose(_ note: Notification) {
        window!.deminiaturize(self)
    }
    
    @objc private func didDeminiaturize(_ note: Notification) {
        closeMiniWindows()
    }
}

extension MainWindowController: MiniViewDelegate, RadioPickerDelegate, WanManagerDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - RadioPickerDelegate methods
    
    /// Open a Radio
    /// - Parameters:
    ///   - packet:       a DiscoveryPacket
    ///
    func openSelectedRadio(_ packet: DiscoveryPacket) {
        if packet.isWan {
            _radioManager?.openWanRadio(packet.serialNumber, holePunchPort: packet.negotiatedHolePunchPort)
        } else {
            openRadio(packet)
        }
    }
    
    /// Close a Radio
    /// - Parameters:
    ///   - packet:       a DiscoveryPacket
    ///
    func closeSelectedRadio(_ packet: DiscoveryPacket) {
        if packet.isWan {
            _radioManager?.closeWanRadio(packet.serialNumber)
        } else {
            closeRadio(packet)
        }
    }
    
    /// Test the Wan connection
    ///
    /// - Parameter packet:     a DiscoveryPacket
    ///
    func testWanConnection(_ packet: DiscoveryPacket ) {
        _radioManager.testWanConnection(packet.serialNumber)
    }
    
    /// Login to SmartLink
    ///
    func smartLinkLogin() {
        _log("SmartLink login requested", .info, #function, #file, #line)
        
        closeRadioPicker()
        _radioManager?.smartLinkLogin()
    }
    
    /// Logout of SmartLink
    ///
    func smartLinkLogout() {
        _log("SmartLink logout requested", .info, #function, #file, #line)
        
        Discovery.sharedInstance.removeSmartLinkRadios()
        
        _radioManager?.smartLinkLogout()
        willChangeValue(for: \.smartLinkUser)
        smartLinkUser = nil
        didChangeValue(for: \.smartLinkUser)
        
        willChangeValue(for: \.smartLinkCall)
        smartLinkCall = nil
        didChangeValue(for: \.smartLinkCall)
        
        willChangeValue(for: \.smartLinkImage)
        smartLinkImage = nil
        didChangeValue(for: \.smartLinkImage)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - WanManagerDelegate methods
    
    var userEmail: String? {
        get { Defaults.userEmail }
        set { Defaults.userEmail = newValue }
    }
    var smartLinkWasLoggedIn: Bool {
        get { Defaults.smartLinkWasLoggedIn }
        set { Defaults.smartLinkWasLoggedIn = newValue }
    }
    
    func showRadioPicker() {
        self.openRadioPicker()
    }
    
    func smartLinkTestResults(results: WanTestConnectionResults) {
        // was it successful?
        let status = (results.forwardTcpPortWorking == true &&
                        results.forwardUdpPortWorking == true &&
                        results.upnpTcpPortWorking == false &&
                        results.upnpUdpPortWorking == false &&
                        results.natSupportsHolePunch  == false) ||
            
            (results.forwardTcpPortWorking == false &&
                results.forwardUdpPortWorking == false &&
                results.upnpTcpPortWorking == true &&
                results.upnpUdpPortWorking == true &&
                results.natSupportsHolePunch  == false)
        // Log the result
        var msg = status ? "successfully" : "with errors: "
        if status == false { msg += "\(results.forwardUdpPortWorking), \(results.upnpTcpPortWorking), \(results.upnpUdpPortWorking), \(results.natSupportsHolePunch)" }
        _log("SmartLink Test completed \(msg)", .info, #function, #file, #line)
        
        DispatchQueue.main.async { [unowned self] in
            
            // set the indicator
            self._radioPickerViewController?.testIndicator.boolState = status
            
            // Alert the user on failure
            if status == false {
                
                let alert = NSAlert()
                alert.alertStyle = .critical
                let acc = NSTextField(frame: CGRect(x: 0, y: 0, width: 233, height: 125))
                acc.stringValue = results.string()
                acc.isEditable = false
                acc.drawsBackground = true
                alert.accessoryView = acc
                alert.messageText = "SmartLink Test Failure"
                alert.informativeText = "Check your SmartLink settings"
                
                alert.beginSheetModal(for: self.window!, completionHandler: { (response) in
                    
                    if response == NSApplication.ModalResponse.alertFirstButtonReturn { return }
                })
            }
        }
    }
    
    func smartLinkConnectionReady(handle: String, serial: String) {
        for (i, packet) in Discovery.sharedInstance.discoveryPackets.enumerated() where packet.serialNumber == serial && packet.isWan {
            Discovery.sharedInstance.discoveryPackets[i].wanHandle = handle
            openRadio(Discovery.sharedInstance.discoveryPackets[i])
        }
    }
    
    func smartLinkUserSettings(name: String?, call: String?) {
        willChangeValue(for: \.smartLinkUser)
        smartLinkUser = name
        didChangeValue(for: \.smartLinkUser)
        
        willChangeValue(for: \.smartLinkCall)
        smartLinkCall = call
        didChangeValue(for: \.smartLinkCall)
    }
    
    func smartLinkImage(image: NSImage?) {
        willChangeValue(for: \.smartLinkImage)
        smartLinkImage = image
        didChangeValue(for: \.smartLinkImage)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - MiniViewDelegate methods
    
    func closeMiniWindows(_ item: AnyObject? = nil) {
        DispatchQueue.main.async { [unowned self] in
            if item == nil {
                // close them all
                self._xMiniWindows.forEach { $0.performClose(self) }
                // empty the array
                self._xMiniWindows.removeAll()
                // bring back the main window
                self.window!.deminiaturize(self)
                
            } else {
                if let pan = item as? Panadapter {
                    
                    for (i, window) in self._xMiniWindows.enumerated().reversed() {
                        if let mini = window.contentViewController as? MiniViewController, mini.pan == pan {
                            mini.removeObservations()
                            self._xMiniWindows[i].performClose(self)
                            self._xMiniWindows.remove(at: i)
                        }
                    }
                    
                } else if let slice = item as? xLib6000.Slice {
                    
                    for (i, window) in self._xMiniWindows.enumerated().reversed() {
                        if let mini = window.contentViewController as? MiniViewController, mini.slice == slice {
                            mini.removeObservations()
                            self._xMiniWindows[i].performClose(self)
                            self._xMiniWindows.remove(at: i)
                        }
                    }
                }
            }
            if self._xMiniWindows.isEmpty { self._radioMenu?.item(title: "xMini")?.boolState = false
            }
        }
    }
}
