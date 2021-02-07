//
//  AppExtensions.swift
//  xSDR6000
//
//  Created by Douglas Adams on 9/22/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import simd

typealias NCtr = NotificationCenter

extension NSColor: DefaultsSerializable {}

// swiftlint:disable opening_brace colon
extension DefaultsKeys {    
    // Radio level info
    var cwxViewOpen              : DefaultsKey<Bool>           { .init("cwxViewOpen", defaultValue: false)}
    var clientId                 : DefaultsKey<String?>        { .init("clientId")}
    var defaultRadio             : DefaultsKey<String?>        { .init("defaultRadio")}
    var eqRxSelected             : DefaultsKey<Bool>           { .init("eqRxSelected", defaultValue: false)}
    var flagBorderEnabled        : DefaultsKey<Bool>           { .init("flagBorderEnabled", defaultValue: false)}
    var fullDuplexEnabled        : DefaultsKey<Bool>           { .init("fullDuplexEnabled", defaultValue: false)}
    var logLevel                 : DefaultsKey<String>         { .init("logLevel", defaultValue: "Debug")}
    var lowBandwidthEnabled      : DefaultsKey<Bool>           { .init("lowBandwidthEnabled", defaultValue: false)}
    var macAudioActive           : DefaultsKey<Bool>           { .init("macAudioActive", defaultValue: false)}
    var markersEnabled           : DefaultsKey<Bool>           { .init("markersEnabled", defaultValue: false)}
    var preferencesTabId         : DefaultsKey<String>         { .init("preferencesTabId", defaultValue: "radio")}
    var profileType              : DefaultsKey<String>         { .init("profileType", defaultValue: "global")}
    var quickMode0               : DefaultsKey<String>         { .init("quickMode0", defaultValue: "usb")}
    var quickMode1               : DefaultsKey<String>         { .init("quickMode1", defaultValue: "lsb")}
    var quickMode2               : DefaultsKey<String>         { .init("quickMode2", defaultValue: "cw")}
    var quickMode3               : DefaultsKey<String>         { .init("quickMode3", defaultValue: "am")}
    var sideViewOpen             : DefaultsKey<Bool>           { .init("sideViewOpen", defaultValue: false)}
    var sideRxOpen               : DefaultsKey<Bool>           { .init("sideRxOpen", defaultValue: false)}
    var sideTxOpen               : DefaultsKey<Bool>           { .init("sideTxOpen", defaultValue: false)}
    var sidePcwOpen              : DefaultsKey<Bool>           { .init("sidePcwOpen", defaultValue: false)}
    var sidePhneOpen             : DefaultsKey<Bool>           { .init("sidePhneOpen", defaultValue: false)}
    var sideEqOpen               : DefaultsKey<Bool>           { .init("sideEqOpen", defaultValue: false)}
    var smartLinkEnabled         : DefaultsKey<Bool>           { .init("smartLinkEnabled", defaultValue: true)}
    var smartLinkToken           : DefaultsKey<String?>        { .init("smartLinkToken")}
    var smartLinkTokenExpiry     : DefaultsKey<Date?>          { .init("smartLinkTokenExpiry")}
    var smartLinkWasLoggedIn     : DefaultsKey<Bool>           { .init("smartLinkWasLoggedIn", defaultValue: false)}
    var splitDistance            : DefaultsKey<Int>            { .init("splitDistance", defaultValue: 5_000)}
    var supportingApps           : DefaultsKey<[[String:Any]]> { .init("supportingApps", defaultValue:[])}
    var showStartupMessage       : DefaultsKey<Bool>           { .init("showStartupMessage", defaultValue: true)}
    var tnfsEnabled              : DefaultsKey<Bool>           { .init("tnfsEnabled", defaultValue: false)}
    var spectrumFillLevel        : DefaultsKey<Int>            { .init("spectrumFillLevel", defaultValue: 0)}
    var spectrumIsFilled         : DefaultsKey<Bool>           { .init("spectrumIsFilled", defaultValue: false)}
    var userEmail                : DefaultsKey<String?>        { .init("userEmail")}
    
    // Colors common to all Panafalls
    var dbLegend                 : DefaultsKey<NSColor>        { .init("dbLegend", defaultValue: NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0))}
    var frequencyLegend          : DefaultsKey<NSColor>        { .init("frequencyLegend", defaultValue: NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0))}
    var gridLine                 : DefaultsKey<NSColor>        { .init("gridLine", defaultValue: NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.3))}
    var marker                   : DefaultsKey<NSColor>        { .init("marker", defaultValue: NSColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0))}
    var markerEdge               : DefaultsKey<NSColor>        { .init("markerEdge", defaultValue: NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.2))}
    var markerSegment            : DefaultsKey<NSColor>        { .init("markerSegment", defaultValue: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.2))}
    var sliceActive              : DefaultsKey<NSColor>        { .init("sliceActive", defaultValue: NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.6))}
    var sliceFilter              : DefaultsKey<NSColor>        { .init("sliceFilter", defaultValue: NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.3))}
    var sliceInactive            : DefaultsKey<NSColor>        { .init("sliceInactive", defaultValue: NSColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.6))}
    var spectrum                 : DefaultsKey<NSColor>        { .init("spectrum", defaultValue: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))}
    var spectrumBackground       : DefaultsKey<NSColor>        { .init("spectrumBackground", defaultValue: NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0))}
    var spectrumFill             : DefaultsKey<NSColor>        { .init("spectrumFill", defaultValue: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.2))}
    var tnfActive                : DefaultsKey<NSColor>        { .init("tnfActive", defaultValue: NSColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 0.2))}
    var tnfInactive              : DefaultsKey<NSColor>        { .init("tnfInactive", defaultValue: NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.2))}
    
    // Settings common to all Panafalls
    var dbLegendSpacing          : DefaultsKey<String>         { .init("dbLegendSpacing", defaultValue: "10")}
    var dbLegendSpacings         : DefaultsKey<[String]>       { .init("dbLegendSpacings", defaultValue: ["5", "10", "15", "20"])}
    var timeLegendSpacing        : DefaultsKey<String>         { .init("timeLegendSpacing", defaultValue: "5")}
    var timeLegendSpacings       : DefaultsKey<[String]>       { .init("timeLegendSpacings", defaultValue: ["5", "10", "20", "30", "60"])}
    
    // debug settings
    var panadapterEnabled        : DefaultsKey<Bool>           { .init("panadapterEnabled", defaultValue: true)}
    var waterfallEnabled         : DefaultsKey<Bool>           { .init("waterfallEnabled", defaultValue: true)}
    // swiftlint:enable opening_brace colon
}

extension Bool {
    var state: NSControl.StateValue {
        return self == true ? NSControl.StateValue.on : NSControl.StateValue.off
    }
}

extension NSButton {
    /// Boolean equivalent of an NSButton state property
    ///
    var boolState: Bool {
        get { return self.state == NSControl.StateValue.on ? true : false }
        set { self.state = (newValue == true ? NSControl.StateValue.on : NSControl.StateValue.off) }
    }
}

extension NSMenuItem {
    /// Boolean equivalent of an NSMenuItem state property
    ///
    var boolState: Bool {
        get { return self.state == NSControl.StateValue.on ? true : false }
        set { self.state = (newValue == true ? NSControl.StateValue.on : NSControl.StateValue.off) }
    }
}

extension NSMenuItem {
    func item(title: String) -> NSMenuItem? {
        self.submenu?.items.first(where: {$0.title == title})
    }
}

extension FileManager {
    /// Get / create the Application Support folder
    ///
    static var appFolder: URL {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask )
        let appFolderUrl = urls.first!.appendingPathComponent( Bundle.main.bundleIdentifier! )
        
        // does the folder exist?
        if !fileManager.fileExists( atPath: appFolderUrl.path ) {
            
            // NO, create it
            do {
                try fileManager.createDirectory( at: appFolderUrl, withIntermediateDirectories: false, attributes: nil)
            } catch let error as NSError {
                fatalError("Error creating App Support folder: \(error.localizedDescription)")
            }
        }
        return appFolderUrl
    }
}

extension NSBezierPath {
    
    /// Draw a Horizontal line
    ///
    /// - Parameters:
    ///   - y:            y-position of the line
    ///   - x1:           starting x-position
    ///   - x2:           ending x-position
    ///
    func hLine(at y: CGFloat, fromX: CGFloat, toX: CGFloat) {
        move( to: CGPoint( x: fromX, y: y ) )
        line( to: CGPoint( x: toX, y: y ) )
    }
    /// Draw a Vertical line
    ///
    /// - Parameters:
    ///   - x:            x-position of the line
    ///   - y1:           starting y-position
    ///   - y2:           ending y-position
    ///
    func vLine(at x: CGFloat, fromY: CGFloat, toY: CGFloat) {
        move( to: CGPoint( x: x, y: fromY) )
        line( to: CGPoint( x: x, y: toY ) )
    }
    
    /// Fill a Rectangle
    ///
    /// - Parameters:
    ///   - rect:           the rect
    ///   - color:          the fill color
    ///
    func fillRect( _ rect: NSRect, withColor color: NSColor, andAlpha alpha: CGFloat = 1) {
        // fill the rectangle with the requested color and alpha
        color.withAlphaComponent(alpha).set()
        appendRect( rect )
        fill()
    }
    
    /// Draw a triangle
    ///
    ///
    /// - Parameters:
    ///   - center:         x-posiion of the triangle's center
    ///   - topWidth:       width of the triangle
    ///   - triangleHeight: height of the triangle
    ///   - topPosition:    y-position of the top of the triangle
    ///
    func drawTriangle(at center: CGFloat, topWidth: CGFloat, triangleHeight: CGFloat, topPosition: CGFloat) {
        move(to: NSPoint(x: center - (topWidth/2), y: topPosition))
        line(to: NSPoint(x: center + (topWidth/2), y: topPosition))
        line(to: NSPoint(x: center, y: topPosition - triangleHeight))
        line(to: NSPoint(x: center - (topWidth/2), y: topPosition))
        fill()
    }
    
    /// Draw an Oval inside a Rectangle
    ///
    /// - Parameters:
    ///   - rect:           the rect
    ///   - color:          the color
    ///   - alpha:          the alpha value
    ///
    func drawCircle(in rect: NSRect, color: NSColor, andAlpha alpha: CGFloat = 1) {
        appendOval(in: rect)
        color.withAlphaComponent(alpha).set()
        fill()
    }
    
    /// Draw a Circle
    ///
    /// - Parameters:
    ///   - point:          the center of the circle
    ///   - radius:         the radius of the circle
    ///
    func drawCircle(at point: NSPoint, radius: CGFloat) {
        let rect = NSRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        appendOval(in: rect)
    }
    
    /// Draw an X
    ///
    /// - Parameters:
    ///   - point:          the center of the X
    ///   - halfWidth:      the half width of the X
    ///
    func drawX(at point: NSPoint, halfWidth: CGFloat) {
        move(to: NSPoint(x: point.x - halfWidth, y: point.y + halfWidth))
        line(to: NSPoint(x: point.x + halfWidth, y: point.y - halfWidth))
        move(to: NSPoint(x: point.x + halfWidth, y: point.y + halfWidth))
        line(to: NSPoint(x: point.x - halfWidth, y: point.y - halfWidth))
    }
    
    /// Crosshatch an area
    ///
    /// - Parameters:
    ///   - rect:           the rect
    ///   - color:          a color
    ///   - depth:          an integer ( 1, 2 or 3)
    ///   - linewidth:      width of the crosshatch lines
    ///   - multiplier:     lines per depth
    ///
    func crosshatch(_ rect: NSRect, color: NSColor, depth: Int, twoWay: Bool = false, linewidth: CGFloat = 1, multiplier: Int = 5) {
        if depth == 1 || depth > 3 { return }
        
        // calculate the number of lines to draw
        let numberOfLines = depth * multiplier * (depth == 2 ? 1 : 2)
        
        // calculate the line increment
        let incr: CGFloat = rect.size.height / CGFloat(numberOfLines)
        
        // set color and line width
        color.set()
        lineWidth = linewidth
        
        // draw the crosshatch
        for i in 0..<numberOfLines {
            move( to: CGPoint( x: rect.origin.x, y: CGFloat(i) * incr))
            line(to: CGPoint(x: rect.origin.x + rect.size.width, y: CGFloat(i+1) * incr))
        }
        if twoWay {
            // draw the opposite crosshatch
            for i in 0..<numberOfLines {
                move( to: CGPoint( x: rect.origin.x + rect.size.width, y: CGFloat(i) * incr))
                line(to: CGPoint(x: rect.origin.x, y: CGFloat(i+1) * incr))
            }
        }
    }
    /// Stroke and then Remove all points
    ///
    func strokeRemove() {
        stroke()
        removeAllPoints()
    }
}

extension NSGradient {
    // return a "basic" Gradient
    static var basic: NSGradient {
        let colors = [
            NSColor(red: 0, green: 0, blue: 0, alpha: 1),                     // black
            NSColor(red: 0, green: 0, blue: 1, alpha: 1),                     // blue
            NSColor(red: 0, green: 1, blue: 1, alpha: 1),                     // cyan
            NSColor(red: 0, green: 1, blue: 0, alpha: 1),                     // green
            NSColor(red: 1, green: 1, blue: 0, alpha: 1),                     // yellow
            NSColor(red: 1, green: 0, blue: 0, alpha: 1),                     // red
            NSColor(red: 1, green: 1, blue: 1, alpha: 1)                      // white
        ]
        let locations: [CGFloat] = [ 0.0, 0.15, 0.25, 0.35, 0.55, 0.90, 1.0 ]
        return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
    }
    
    // return a "dark" Gradient
    static var dark: NSGradient {
        let colors = [
            NSColor(red: 0, green: 0, blue: 0, alpha: 1),                     // black
            NSColor(red: 0, green: 0, blue: 1, alpha: 1),                     // blue
            NSColor(red: 0, green: 1, blue: 0, alpha: 1),                     // green
            NSColor(red: 1, green: 0, blue: 0, alpha: 1),                     // red
            NSColor(red: 1, green: 0.71, blue: 0.76, alpha: 1)                // light pink
        ]
        let locations: [CGFloat] = [ 0.0, 0.65, 0.90, 0.95, 1.0 ]
        return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
    }
    
    // return a "deuteranopia" Gradient
    static var deuteranopia: NSGradient {
        let colors = [
            NSColor(red: 0, green: 0, blue: 0, alpha: 1),                     // black
            NSColor(red: 0.03, green: 0.23, blue: 0.42, alpha: 1),            // dark blue
            NSColor(red: 0.52, green: 0.63, blue: 0.84, alpha: 1),            // light blue
            NSColor(red: 0.65, green: 0.59, blue: 0.45, alpha: 1),            // dark yellow
            NSColor(red: 1, green: 1, blue: 0, alpha: 1),                     // yellow
            NSColor(red: 1, green: 1, blue: 0, alpha: 1),                     // yellow
            NSColor(red: 1, green: 1, blue: 1, alpha: 1)                      // white
        ]
        let locations: [CGFloat] = [ 0.0, 0.15, 0.50, 0.65, 0.75, 0.95, 1.0 ]
        return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
    }
    
    // return a "grayscale" Gradient
    static var grayscale: NSGradient {
        let colors = [
            NSColor(red: 0, green: 0, blue: 0, alpha: 1),                     // black
            NSColor(red: 1, green: 1, blue: 1, alpha: 1)                      // white
        ]
        let locations: [CGFloat] = [ 0.0, 1.0 ]
        return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
    }
    
    // return a "purple" Gradient
    static var purple: NSGradient {
        let colors = [
            NSColor(red: 0, green: 0, blue: 0, alpha: 1),                     // black
            NSColor(red: 0, green: 0, blue: 1, alpha: 1),                     // blue
            NSColor(red: 0, green: 1, blue: 0, alpha: 1),                     // green
            NSColor(red: 1, green: 1, blue: 0, alpha: 1),                     // yellow
            NSColor(red: 1, green: 0, blue: 0, alpha: 1),                     // red
            NSColor(red: 0.5, green: 0, blue: 0.5, alpha: 1),                 // purple
            NSColor(red: 1, green: 1, blue: 1, alpha: 1)                      // white
        ]
        let locations: [CGFloat] = [ 0.0, 0.15, 0.30, 0.45, 0.60, 0.75, 1.0 ]
        return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
    }
    
    // return a "tritanopia" Gradient
    static var tritanopia: NSGradient {
        let colors = [
            NSColor(red: 0, green: 0, blue: 0, alpha: 1),                     // black
            NSColor(red: 0, green: 0.27, blue: 0.32, alpha: 1),               // dark teal
            NSColor(red: 0.42, green: 0.73, blue: 0.84, alpha: 1),            // light blue
            NSColor(red: 0.29, green: 0.03, blue: 0.09, alpha: 1),            // dark red
            NSColor(red: 1, green: 0, blue: 0, alpha: 1),                     // red
            NSColor(red: 0.84, green: 0.47, blue: 0.52, alpha: 1),            // light red
            NSColor(red: 1, green: 1, blue: 1, alpha: 1)                      // white
        ]
        let locations: [CGFloat] = [ 0.0, 0.15, 0.25, 0.45, 0.90, 0.95, 1.0 ]
        return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
    }
}

extension NSColor {
    // return a float4 version of an rgba NSColor
    var float4Color: SIMD4<Float> { return SIMD4<Float>( Float(self.redComponent),
                                                         Float(self.greenComponent),
                                                         Float(self.blueComponent),
                                                         Float(self.alphaComponent))
    }
    // return a bgr8Unorm version of an rgba NSColor
    var bgra8Unorm: UInt32 {
        
        // capture the component values (assumes that the Blue & Red are swapped)
        //      see the Note at the top of this class
        let alpha = UInt32( UInt8( self.alphaComponent * CGFloat(UInt8.max) ) ) << 24
        let red = UInt32( UInt8( self.redComponent * CGFloat(UInt8.max) ) ) << 16
        let green = UInt32( UInt8( self.greenComponent * CGFloat(UInt8.max) ) ) << 8
        let blue = UInt32( UInt8( self.blueComponent * CGFloat(UInt8.max) ) )
        
        // return the UInt32 (in bgra format)
        return alpha + red + green + blue
    }
    // return a Metal Clear Color version of an NSColor
    var metalClearColor: MTLClearColor {
        return MTLClearColor(red: Double(self.redComponent),
                             green: Double(self.greenComponent),
                             blue: Double(self.blueComponent),
                             alpha: Double(self.alphaComponent) )
    }
}

extension String {
    var numbers: String {
        return String(describing: filter { String($0).rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789")) != nil })
    }
}

extension String {
    static func random(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString = ""
        
        while randomString.utf8.count < length {
            let randomLetter = letters.randomElement()
            randomString += randomLetter?.description ?? ""
        }
        return randomString
    }
}

extension String {
    var expandingTilde: String { NSString(string: self).expandingTildeInPath }
}

extension Float {
    // return the Power value of a Dbm (1 watt) value
    var powerFromDbm: Float {
        return Float( pow( Double(10.0), Double( (self - 30.0)/10.0) ) )
    }
}

extension URL {
    /// setup the Support folders
    ///
    static var appSupport: URL { return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first! }
    static var logs: URL { return createAsNeeded("net.k3tzr." + AppDelegate.kAppName + "/Logs") }
    static var macros: URL { return createAsNeeded("net.k3tzr." + AppDelegate.kAppName + "/Macros") }
    
    static func createAsNeeded(_ folder: String) -> URL {
        let fileManager = FileManager.default
        let folderUrl = appSupport.appendingPathComponent( folder )
        
        // does the folder exist?
        if fileManager.fileExists( atPath: folderUrl.path ) == false {
            
            // NO, create it
            do {
                try fileManager.createDirectory( at: folderUrl, withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                fatalError("Error creating App Support folder: \(error.localizedDescription)")
            }
        }
        return folderUrl
    }
}

extension Int {  
    var intHzToDoubleMhz: Double { Double(self) / 1_000_000 }
}

extension Double {
    var doubleMhzToIntHz: Int { Int( self * 1_000_000 ) }
}

extension Bundle {
    static func parsePlist(_ name: String, bundle: Bundle) -> [[String: String]] {
        var arrayOfDict = NSArray()
        // check if plist data available
       if let plistURL = bundle.url(forResource: name, withExtension: "plist") {
        arrayOfDict = NSArray(contentsOf: plistURL) ?? arrayOfDict
       }
        if let array = arrayOfDict as? [[String: String]] {
            return array
        }
        fatalError("Unable to return array of dictionary")
    }
}

extension URLSession {
    func synchronousDataTask(with urlRequest: URLRequest) -> (Data?, Error?) {
        var data: Data?
        //    var response: URLResponse?
        var error: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let dataTask = self.dataTask(with: urlRequest) {
            data = $0
            //      response = $1
            error = $2
            
            semaphore.signal()
        }
        dataTask.resume()
        
        _ = semaphore.wait(timeout: .distantFuture)
        
        return (data, error)
    }
}

extension String {
    var responseDict: [String: String] {
        let elementSeparator = "&"
        let partsSeparator = "="
        
        var string = self
        var parameters = [String: String]()
        
        if hasPrefix(elementSeparator) { string = String(dropFirst(1)) }
        
        for item in string.components(separatedBy: elementSeparator) {
            let parts = item.components(separatedBy: partsSeparator)
            parameters[parts[0]] = parts[1]
        }
        return parameters
    }
}

func +=<K: RangeReplaceableCollection, V: RangeReplaceableCollection> (left: inout [K: V], right: [K: V]) { left.merge(right, uniquingKeysWith: { (_, new) in new }) }

// ----------------------------------------------------------------------------
// MARK: - TOP-LEVEL FUNCTIONS

/// Repeatedly perform a condition func until satisfied or a timeout
/// - Parameters:
///   - interval:           how offten to check the condition func (seconds)
///   - wait:               how long until timeout (seconds)
///   - condition:          a condition func ()->Bool
///   - completionHandler:  a completion handler (wasCancelled)->()
///
func checkLoop(interval: Int, wait: TimeInterval, condition: @escaping () -> Bool, completionHandler: @escaping (Bool) -> Void) {
    
    // create the timer
    let start = Date()
    let timer = DispatchSource.makeTimerSource()
    
    timer.schedule(deadline: DispatchTime.now(), repeating: .seconds(interval))
    timer.setEventHandler {
        // timeout after "wait" seconds
        if Date(timeIntervalSinceNow: 0).timeIntervalSince(start) > wait {
            // time out
            timer.cancel()
            completionHandler(false)
        } else {
            // not time out, check condition
            if condition() {
                timer.cancel()
                completionHandler(true)
            }
        }
    }
    // start the timer
    timer.resume()
}

/// Display an Alert sheet for a limited time or until some condition is met (whichever comes first)
/// - Parameters:
///   - message:            the message to display
///   - window:             the window for the sheet
///   - interval:           how offten to check the condition func (seconds)
///   - wait:               how long until timeout (seconds)
///   - condition:          a condition func ()->Bool
///   - completionHandler:  a completion handler (wasCancelled)->()
///
func waitAlert(message: String, window: NSWindow, interval: Int, wait: TimeInterval, condition: @escaping () -> Bool, completionHandler: @escaping (Bool) -> Void) {
    
    // create the timer
    let start = Date()
    let timer = DispatchSource.makeTimerSource()
    let alert = NSAlert()
    
    timer.schedule(deadline: DispatchTime.now(), repeating: .seconds(interval))
    timer.setEventHandler {
        // timeout after "wait" seconds
        if Date(timeIntervalSinceNow: 0).timeIntervalSince(start) > wait {
            // time out
            timer.cancel()
            completionHandler(false)
            DispatchQueue.main.async {
                window.endSheet(alert.window)
            }
        } else {
            // not time out, check condition
            if condition() {
                timer.cancel()
                completionHandler(true)
                DispatchQueue.main.async {
                    window.endSheet(alert.window)
                }
            }
        }
    }
    alert.messageText = message
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Cancel")
    alert.beginSheetModal(for: window, completionHandler: { (response) in
        if response == NSApplication.ModalResponse.alertFirstButtonReturn { timer.cancel() ; completionHandler(false) }
    })
    // start the timer
    timer.resume()
}

func notImplemented(_ featureName: String) -> NSAlert {
    
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = featureName + " NOT IMPLEMENTED"
    alert.informativeText = "Later versions may incorporate this feature"
    return alert
}

/// Setup & Register User Defaults from a file
///
/// - Parameter file:         a file name (w/wo extension)
///
func defaults(from file: String) {
    var fileURL: URL?
    
    // get the name & extension
    let parts = file.split(separator: ".")
    
    // exit if invalid
    guard !parts.isEmpty else {return }
    
    if parts.count >= 2 {
        
        // name & extension
        fileURL = Bundle.main.url(forResource: String(parts[0]), withExtension: String(parts[1]))
        
    } else if parts.count == 1 {
        
        // name only
        fileURL = Bundle.main.url(forResource: String(parts[0]), withExtension: "")
    }
    
    if let fileURL = fileURL {
        // load the contents
        if let myDefaults = NSDictionary(contentsOf: fileURL) as? [String: Any] {
            
            // register the defaults
            UserDefaults.standard.register(defaults: myDefaults)
        }
    }
}

// ----------------------------------------------------------------------------
// MARK: - DEBUG FUNCTIONS

#if XDEBUG
/// Print a Responder Chain on the console
///
/// - Parameter view:               a view at the root of the chain
///
func responderChain(for rootView: NSView) {
    var currentResponder: NSResponder?
    
    DispatchQueue.main.async {
        currentResponder = rootView as NSResponder
        
        Swift.print("\nResponder chain for \(rootView.identifier?.rawValue ?? "No Identifier")\n")
        while true {
            if let responder = currentResponder?.nextResponder {
                
                if let view = responder as? NSView {
                    Swift.print("\t\(view.identifier?.rawValue ?? String(describing: view))")
                } else if let viewController = responder as? NSViewController {
                    Swift.print("\t\(viewController.identifier?.rawValue ?? String(describing: vc))")
                }
                currentResponder = responder
            } else {
                break
            }
        }
        Swift.print("")
    }
}
/// Print a View Hierarchy on the console
///
/// - Parameter view:               a view at the root of the chain
///
func viewHierarchy(for rootView: NSView) {
    var currentView: NSView?
    
    DispatchQueue.main.async {
        currentView = rootView as NSView
        
        Swift.print("\nView Hierarchy for \(rootView.identifier?.rawValue ?? "No Identifier")\n")
        while currentView != nil {
            if let view = currentView?.superview {
                
                if view === NSApp.mainWindow?.contentView {
                    Swift.print("\t\(NSApp.mainWindow?.identifier?.rawValue ?? String(describing: NSApp.mainWindow))")
                } else {
                    Swift.print("\t\(view.identifier?.rawValue ?? String(describing: view))")
                }
                currentView = view
            }
        }
        Swift.print("")
    }
}
/// Print a list of a view's constraints
///
/// - Parameters:
///   - name:                     the name of the view
///   - view:                     the view
///
func listConstraints(for name: String, view: NSView) {
    
    Swift.print("\(name), frame = \(view.frame), isHidden = \(view.isHidden)")
    for constraint in view.constraints {
        Swift.print("\t\(constraint)")
    }
    Swift.print("")
}
#endif
