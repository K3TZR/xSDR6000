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

typealias NC = NotificationCenter

extension NSColor : DefaultsSerializable {}

extension DefaultsKeys {
  
  // Radio level info
  
  static var username                 : DefaultsKey<String?>        { return .init("username") }
  
  static var cwxViewOpen              : DefaultsKey<Bool>           { return .init("cwxViewOpen", defaultValue: false)}
  static var clientId                 : DefaultsKey<String?>        { return .init("clientId")}
  static var defaultRadioSerialNumber : DefaultsKey<String>         { return .init("defaultRadioSerialNumber", defaultValue: "")}
  static var eqRxSelected             : DefaultsKey<Bool>           { return .init("eqRxSelected", defaultValue: false)}
  static var flagBorderEnabled        : DefaultsKey<Bool>           { return .init("flagBorderEnabled", defaultValue: false)}
  static var fullDuplexEnabled        : DefaultsKey<Bool>           { return .init("fullDuplexEnabled", defaultValue: false)}
  static var lowBandwidthEnabled      : DefaultsKey<Bool>           { return .init("lowBandwidthEnabled", defaultValue: false)}
  static var macAudioEnabled          : DefaultsKey<Bool>           { return .init("macAudioEnabled", defaultValue: false)}
  static var markersEnabled           : DefaultsKey<Bool>           { return .init("markersEnabled", defaultValue: false)}
  static var preferencesTabId         : DefaultsKey<String>         { return .init("preferencesTabId", defaultValue: "")}
  static var profilesTabId            : DefaultsKey<String>         { return .init("profilesTabId", defaultValue: "")}
  static var quickMode0               : DefaultsKey<String>         { return .init("quickMode0", defaultValue: "")}
  static var quickMode1               : DefaultsKey<String>         { return .init("quickMode1", defaultValue: "")}
  static var quickMode2               : DefaultsKey<String>         { return .init("quickMode2", defaultValue: "")}
  static var quickMode3               : DefaultsKey<String>         { return .init("quickMode3", defaultValue: "")}
  static var radioModel               : DefaultsKey<String>         { return .init("radioModel", defaultValue: "")}
  static var remoteViewOpen           : DefaultsKey<Bool>           { return .init("remoteViewOpen", defaultValue: false)}
  static var sideViewOpen             : DefaultsKey<Bool>           { return .init("sideViewOpen", defaultValue: false)}
  static var sideRxOpen               : DefaultsKey<Bool>           { return .init("sideRxOpen", defaultValue: false)}
  static var sideTxOpen               : DefaultsKey<Bool>           { return .init("sideTxOpen", defaultValue: false)}
  static var sidePcwOpen              : DefaultsKey<Bool>           { return .init("sidePcwOpen", defaultValue: false)}
  static var sidePhneOpen             : DefaultsKey<Bool>           { return .init("sidePhneOpen", defaultValue: false)}
  static var sideEqOpen               : DefaultsKey<Bool>           { return .init("sideEqOpen", defaultValue: false)}
  static var smartLinkAuth0Email      : DefaultsKey<String>         { return .init("smartLinkAuth0Email", defaultValue: "")}
  static var smartLinkToken           : DefaultsKey<String?>        { return .init("smartLinkToken")}
  static var smartLinkTokenExpiry     : DefaultsKey<Date?>          { return .init("smartLinkTokenExpiry")}
  static var splitDistance            : DefaultsKey<Int>            { return .init("splitDistance", defaultValue: 0)}
  static var supportingApps           : DefaultsKey<[[String:Any]]> { return .init("supportingApps", defaultValue:[])}
  static var tnfsEnabled              : DefaultsKey<Bool>           { return .init("tnfsEnabled", defaultValue: false)}
  static var spectrumFillLevel        : DefaultsKey<Int>            { return .init("spectrumFillLevel", defaultValue: 0)}
  static var spectrumIsFilled         : DefaultsKey<Bool>           { return .init("spectrumIsFilled", defaultValue: false)}
  static var versionRadio             : DefaultsKey<String>         { return .init("versionRadio", defaultValue: "")}

  static var smartLinkWasLoggedIn     : DefaultsKey<Bool>           { return .init("smartLinkWasLoggedIn", defaultValue: false)}
  
  // Colors common to all Panafalls
  static var dbLegend                 : DefaultsKey<NSColor>        { return .init("dbLegend", defaultValue: .red)}
  static var frequencyLegend          : DefaultsKey<NSColor>        { return .init("frequencyLegend", defaultValue: .red)}
  static var gridLine                 : DefaultsKey<NSColor>        { return .init("gridLine", defaultValue: .red)}
  static var marker                   : DefaultsKey<NSColor>        { return .init("marker", defaultValue: .red)}
  static var markerEdge               : DefaultsKey<NSColor>        { return .init("markerEdge", defaultValue: .red)}
  static var markerSegment            : DefaultsKey<NSColor>        { return .init("markerSegment", defaultValue: .red)}
  static var sliceActive              : DefaultsKey<NSColor>        { return .init("sliceActive", defaultValue: .red)}
  static var sliceFilter              : DefaultsKey<NSColor>        { return .init("sliceFilter", defaultValue: .red)}
  static var sliceInactive            : DefaultsKey<NSColor>        { return .init("sliceInactive", defaultValue: .red)}
  static var spectrum                 : DefaultsKey<NSColor>        { return .init("spectrum", defaultValue: .red)}
  static var spectrumBackground       : DefaultsKey<NSColor>        { return .init("spectrumBackground", defaultValue: .red)}
  static var spectrumFill             : DefaultsKey<NSColor>        { return .init("spectrumFill", defaultValue: .red)}
  static var tnfActive                : DefaultsKey<NSColor>        { return .init("tnfActive", defaultValue: .red)}
  static var tnfInactive              : DefaultsKey<NSColor>        { return .init("tnfInactive", defaultValue: .red)}
  
  // Settings common to all Panafalls
  static var dbLegendSpacing          : DefaultsKey<String>         { return .init("dbLegendSpacing", defaultValue: "")}
  static var dbLegendSpacings         : DefaultsKey<[String]>       { return .init("dbLegendSpacings", defaultValue: [])}
  static var timeLegendSpacing        : DefaultsKey<String>         { return .init("timeLegendSpacing", defaultValue: "")}
  static var timeLegendSpacings       : DefaultsKey<[String]>       { return .init("timeLegendSpacings", defaultValue: [])}
}

extension  UserDefaults {
  
  // alternate access to allow KVO observation
  @objc dynamic var dbLegend : NSColor {
    get { return Defaults[.dbLegend] }
    set { Defaults[.dbLegend] = newValue } }
  
  @objc dynamic var dbLegendSpacing : String {
    get { return Defaults[.dbLegendSpacing] }
    set { Defaults[.dbLegendSpacing] = newValue } }
  
  @objc dynamic var cwxViewOpen : Bool {
    get { return Defaults[.cwxViewOpen] }
    set { Defaults[.cwxViewOpen] = newValue } }
  
  @objc dynamic var frequencyLegend : NSColor {
    get { return Defaults[.frequencyLegend] }
    set { Defaults[.frequencyLegend] = newValue } }
  
  @objc dynamic var fullDuplexEnabled : Bool {
    get { return Defaults[.fullDuplexEnabled] }
    set { Defaults[.fullDuplexEnabled] = newValue } }
  
  @objc dynamic var gridLine : NSColor {
    get { return Defaults[.gridLine] }
    set { Defaults[.gridLine] = newValue } }
  
  @objc dynamic var macAudioEnabled : Bool {
    get { return Defaults[.macAudioEnabled] }
    set { Defaults[.macAudioEnabled] = newValue } }
  
  @objc dynamic var marker : NSColor {
    get { return Defaults[.marker] }
    set { Defaults[.marker] = newValue } }
  
  @objc dynamic var markerSegment : NSColor {
    get { return Defaults[.markerSegment] }
    set { Defaults[.markerSegment] = newValue } }
  
  @objc dynamic var markerEdge : NSColor {
    get { return Defaults[.markerEdge] }
    set { Defaults[.markerEdge] = newValue } }
  
  @objc dynamic var markersEnabled : Bool {
    get { return Defaults[.markersEnabled] }
    set { Defaults[.markersEnabled] = newValue } }
  
  @objc dynamic var sliceActive : NSColor {
    get { return Defaults[.sliceActive] }
    set { Defaults[.sliceActive] = newValue } }
  
  @objc dynamic var sliceFilter : NSColor {
    get { return Defaults[.sliceFilter] }
    set { Defaults[.sliceFilter] = newValue } }
  
  @objc dynamic var sliceInactive : NSColor {
    get { return Defaults[.sliceInactive] }
    set { Defaults[.sliceInactive] = newValue } }
  
  @objc dynamic var spectrum : NSColor {
    get { return Defaults[.spectrum] }
    set { Defaults[.spectrum] = newValue } }
  
  @objc dynamic var spectrumBackground : NSColor {
    get { return Defaults[.spectrumBackground] }
    set { Defaults[.spectrumBackground] = newValue } }
  
  @objc dynamic var spectrumFillLevel : Int {
    get { return Defaults[.spectrumFillLevel] }
    set { Defaults[.spectrumFillLevel] = newValue } }
  
  @objc dynamic var splitDistance : Int {
    get { return Defaults[.splitDistance] }
    set { Defaults[.splitDistance] = newValue } }
  
  @objc dynamic var supportingApps : [[String:Any]] {
    get { return Defaults[.supportingApps] }
    set { Defaults[.supportingApps] = newValue } }
  
  @objc dynamic var tnfActive : NSColor {
    get { return Defaults[.tnfActive] }
    set { Defaults[.tnfActive] = newValue } }
  
  @objc dynamic var tnfInactive : NSColor {
    get { return Defaults[.tnfInactive] }
    set { Defaults[.tnfInactive] = newValue } }

  @objc dynamic var tnfsEnabled : Bool {
    get { return Defaults[.tnfsEnabled] }
    set { Defaults[.tnfsEnabled] = newValue } }
  
  @objc dynamic var versionRadio : String {
    get { return Defaults[.versionRadio] }
    set { Defaults[.versionRadio] = newValue } }
}

extension Bool {

  var state : NSControl.StateValue {
    return self == true ? NSControl.StateValue.on : NSControl.StateValue.off
  }
}

extension NSButton {
  /// Boolean equivalent of an NSButton state property
  ///
  var boolState : Bool {
    get { return self.state == NSControl.StateValue.on ? true : false }
    set { self.state = (newValue == true ? NSControl.StateValue.on : NSControl.StateValue.off) }
  }
}

extension FileManager {
  
  /// Get / create the Application Support folder
  ///
  static var appFolder : URL {
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
  func hLine(at y:CGFloat, fromX x1:CGFloat, toX x2:CGFloat) {
    
    move( to: NSMakePoint( x1, y ) )
    line( to: NSMakePoint( x2, y ) )
  }
  /// Draw a Vertical line
  ///
  /// - Parameters:
  ///   - x:            x-position of the line
  ///   - y1:           starting y-position
  ///   - y2:           ending y-position
  ///
  func vLine(at x:CGFloat, fromY y1:CGFloat, toY y2:CGFloat) {
    
    move( to: NSMakePoint( x, y1) )
    line( to: NSMakePoint( x, y2 ) )
  }
  /// Fill a Rectangle
  ///
  /// - Parameters:
  ///   - rect:           the rect
  ///   - color:          the fill color
  ///
  func fillRect( _ rect:NSRect, withColor color:NSColor, andAlpha alpha:CGFloat = 1) {
    
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
  func drawTriangle(at center:CGFloat, topWidth:CGFloat, triangleHeight:CGFloat, topPosition:CGFloat) {
    
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
  func drawCircle(in rect: NSRect, color:NSColor, andAlpha alpha:CGFloat = 1) {
    
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
  func drawX(at point:NSPoint, halfWidth: CGFloat) {
    
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
      move( to: NSMakePoint( rect.origin.x, CGFloat(i) * incr))
      line(to: NSMakePoint(rect.origin.x + rect.size.width, CGFloat(i+1) * incr))
    }
    if twoWay {
      // draw the opposite crosshatch
      for i in 0..<numberOfLines {
        move( to: NSMakePoint( rect.origin.x + rect.size.width, CGFloat(i) * incr))
        line(to: NSMakePoint(rect.origin.x, CGFloat(i+1) * incr))
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
    get {
      let colors = [
        NSColor(red: 0, green: 0, blue: 0, alpha: 1),                     // black
        NSColor(red: 0, green: 0, blue: 1, alpha: 1),                     // blue
        NSColor(red: 0, green: 1, blue: 1, alpha: 1),                     // cyan
        NSColor(red: 0, green: 1, blue: 0, alpha: 1),                     // green
        NSColor(red: 1, green: 1, blue: 0, alpha: 1),                     // yellow
        NSColor(red: 1, green: 0, blue: 0, alpha: 1),                     // red
        NSColor(red: 1, green: 1, blue: 1, alpha: 1)                      // white
      ]
      let locations: Array<CGFloat> = [ 0.0, 0.15, 0.25, 0.35, 0.55, 0.90, 1.0 ]
      return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
    }
  }
  
  // return a "dark" Gradient
  static var dark: NSGradient {
    get {
      let colors = [
        NSColor(red: 0, green: 0, blue: 0, alpha: 1),                     // black
        NSColor(red: 0, green: 0, blue: 1, alpha: 1),                     // blue
        NSColor(red: 0, green: 1, blue: 0, alpha: 1),                     // green
        NSColor(red: 1, green: 0, blue: 0, alpha: 1),                     // red
        NSColor(red: 1, green: 0.71, blue: 0.76, alpha: 1)                // light pink
      ]
      let locations: Array<CGFloat> = [ 0.0, 0.65, 0.90, 0.95, 1.0 ]
      return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
    }
  }
  
  // return a "deuteranopia" Gradient
  static var deuteranopia: NSGradient {
    get {
      let colors = [
        NSColor(red: 0, green: 0, blue: 0, alpha: 1),                     // black
        NSColor(red: 0.03, green: 0.23, blue: 0.42, alpha: 1),            // dark blue
        NSColor(red: 0.52, green: 0.63, blue: 0.84, alpha: 1),            // light blue
        NSColor(red: 0.65, green: 0.59, blue: 0.45, alpha: 1),            // dark yellow
        NSColor(red: 1, green: 1, blue: 0, alpha: 1),                     // yellow
        NSColor(red: 1, green: 1, blue: 0, alpha: 1),                     // yellow
        NSColor(red: 1, green: 1, blue: 1, alpha: 1)                      // white
      ]
      let locations: Array<CGFloat> = [ 0.0, 0.15, 0.50, 0.65, 0.75, 0.95, 1.0 ]
      return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
    }
  }
  
  // return a "grayscale" Gradient
  static var grayscale: NSGradient {
    get {
      let colors = [
        NSColor(red: 0, green: 0, blue: 0, alpha: 1),                     // black
        NSColor(red: 1, green: 1, blue: 1, alpha: 1)                      // white
      ]
      let locations: Array<CGFloat> = [ 0.0, 1.0 ]
      return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
    }
  }
  
  // return a "purple" Gradient
  static var purple: NSGradient {
    get {
      let colors = [
        NSColor(red: 0, green: 0, blue: 0, alpha: 1),                     // black
        NSColor(red: 0, green: 0, blue: 1, alpha: 1),                     // blue
        NSColor(red: 0, green: 1, blue: 0, alpha: 1),                     // green
        NSColor(red: 1, green: 1, blue: 0, alpha: 1),                     // yellow
        NSColor(red: 1, green: 0, blue: 0, alpha: 1),                     // red
        NSColor(red: 0.5, green: 0, blue: 0.5, alpha: 1),                 // purple
        NSColor(red: 1, green: 1, blue: 1, alpha: 1)                      // white
      ]
      let locations: Array<CGFloat> = [ 0.0, 0.15, 0.30, 0.45, 0.60, 0.75, 1.0 ]
      return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
    }
  }
  
  // return a "tritanopia" Gradient
  static var tritanopia: NSGradient {
    get {
      let colors = [
        NSColor(red: 0, green: 0, blue: 0, alpha: 1),                     // black
        NSColor(red: 0, green: 0.27, blue: 0.32, alpha: 1),               // dark teal
        NSColor(red: 0.42, green: 0.73, blue: 0.84, alpha: 1),            // light blue
        NSColor(red: 0.29, green: 0.03, blue: 0.09, alpha: 1),            // dark red
        NSColor(red: 1, green: 0, blue: 0, alpha: 1),                     // red
        NSColor(red: 0.84, green: 0.47, blue: 0.52, alpha: 1),            // light red
        NSColor(red: 1, green: 1, blue: 1, alpha: 1)                      // white
      ]
      let locations: Array<CGFloat> = [ 0.0, 0.15, 0.25, 0.45, 0.90, 0.95, 1.0 ]
      return NSGradient(colors: colors, atLocations: locations, colorSpace: .deviceRGB)!
    }
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

extension String{
   static func random(length:Int)->String{
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString = ""

        while randomString.utf8.count < length{
            let randomLetter = letters.randomElement()
            randomString += randomLetter?.description ?? ""
        }
        return randomString
    }
}

extension Float {
  
  // return the Power value of a Dbm (1 watt) value
  var powerFromDbm: Float {
    return Float( pow( Double(10.0),Double( (self - 30.0)/10.0) ) )
  }
}

extension URL {
  
  /// setup the Support folders
  ///
  static var appSupport : URL { return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first! }
  static var logs : URL { return createAsNeeded("Logs") }
  static var macros : URL { return createAsNeeded("Macros") }
  
  static func createAsNeeded(_ folder: String) -> URL {
    let fileManager = FileManager.default
    let folderUrl = appSupport.appendingPathComponent( folder )
    
    // does the folder exist?
    if fileManager.fileExists( atPath: folderUrl.path ) == false {
      
      // NO, create it
      do {
        try fileManager.createDirectory( at: folderUrl, withIntermediateDirectories: false, attributes: nil)
      } catch let error as NSError {
        fatalError("Error creating App Support folder: \(error.localizedDescription)")
      }
    }
    return folderUrl
  }
}

extension Int {  
  var intHzToDoubleMhz : Double { Double(self) / 1_000_000 }
}

extension Double {
  var doubleMhzToIntHz : Int { Int( self * 1_000_000 ) }
}

// ----------------------------------------------------------------------------
// MARK: - TOP-LEVEL FUNCTIONS

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
  var fileURL : URL? = nil
  
  // get the name & extension
  let parts = file.split(separator: ".")
  
  // exit if invalid
  guard parts.count != 0 else {return }
  
  if parts.count >= 2 {
    
    // name & extension
    fileURL = Bundle.main.url(forResource: String(parts[0]), withExtension: String(parts[1]))
    
  } else if parts.count == 1 {
    
    // name only
    fileURL = Bundle.main.url(forResource: String(parts[0]), withExtension: "")
  }
  
  if let fileURL = fileURL {
    // load the contents
    let myDefaults = NSDictionary(contentsOf: fileURL)!
    
    // register the defaults
    UserDefaults.standard.register(defaults: myDefaults as! Dictionary<String, Any>)
  }
}

/// Return the version of the named Package
/// - Parameter packageName:    the name of a package
///
//func versionOf(_ packageName: String) -> String {
//
  /* Assumes a file with a structure like this
   {
     "object": {
       "pins": [
         {
           "package": "Nimble",
           "repositoryURL": "https://github.com/Quick/Nimble.git",
           "state": {
             "branch": null,
             "revision": "e9d769113660769a4d9dd3afb855562c0b7ae7b0",
             "version": "7.3.4"
           }
         },
         {
           "package": "Quick",
           "repositoryURL": "https://github.com/Quick/Quick.git",
           "state": {
             "branch": null,
             "revision": "f2b5a06440ea87eba1a167cab37bf6496646c52e",
             "version": "1.3.4"
           }
         },
         {
           "package": "SwiftyUserDefaults",
           "repositoryURL": "https://github.com/sunshinejr/SwiftyUserDefaults.git",
           "state": {
             "branch": null,
             "revision": "566ace16ee91242b61e2e9da6cdbe7dfdadd926c",
             "version": "4.0.0"
           }
         },
         {
           "package": "XCGLogger",
           "repositoryURL": "https://github.com/DaveWoodCom/XCGLogger.git",
           "state": {
             "branch": null,
             "revision": "a9c4667b247928a29bdd41be2ec2c8d304215a54",
             "version": "7.0.1"
           }
         },
         {
           "package": "xLib6000",
           "repositoryURL": "https://github.com/K3TZR/xLib6000.git",
           "state": {
             "branch": null,
             "revision": "43f637fbf0475574618d0aa105478d0a4c41df92",
             "version": "1.2.6"
           }
         }
       ]
     },
     "version": 1
   }

   */
//
//  struct State: Codable {
//    var branch    : String?
//    var revision  : String
//    var version   : String?
//  }
//
//  struct Pin: Codable {
//    var package       : String
//    var repositoryURL : String
//    var state         : State
//  }
//
//  struct Pins: Codable {
//    var pins  : [Pin]
//  }
//
//  struct Object: Codable {
//    var object    : Pins
//    var version   : Int
//  }
//
//  let decoder = JSONDecoder()
//
//  // get the Package.resolved file
//  if let url = Bundle.main.url(forResource: "Package", withExtension: "resolved") {
//    // decode it
//    if let json = try? Data(contentsOf: url), let container = try? decoder.decode(Object.self, from: json) {
//      // find the desired entry
//      for pin in container.object.pins where pin.package == packageName {
//        // return either the version or the branch
//        return pin.state.version != nil ? pin.state.version! : pin.state.branch ?? "empty branch"
//      }
//      // packageName not present in Package.resolved
//      return "Unknown package: " + packageName
//    }
//    // decode failure
//    return "Package.resolved file decode failed"
//  }
//  // file not found
//  return "Package.resolved file NOT found"
//}

// ----------------------------------------------------------------------------
// MARK: - DEBUG FUNCTIONS


#if XDEBUG
/// Print a Responder Chain on the console
///
/// - Parameter view:               a view at the root of the chain
///
func responderChain(for rootView: NSView) {
  var currentResponder :NSResponder?
  
  DispatchQueue.main.async {
    currentResponder = rootView as NSResponder
    
    Swift.print("\nResponder chain for \(rootView.identifier?.rawValue ?? "No Identifier")\n")
    while true {
      if let responder = currentResponder?.nextResponder {
        
        if let view = responder as? NSView {
          Swift.print("\t\(view.identifier?.rawValue ?? String(describing: view))")
        } else if let vc = responder as? NSViewController {
          Swift.print("\t\(vc.identifier?.rawValue ?? String(describing: vc))")
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
  var currentView :NSView?
  
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
