//
//  Band.swift
//  xSDR6000
//
//  Created by Douglas Adams on 8/18/14.
//

import Cocoa

// ----------------------------------------------------------------------------
// MARK: - Band Model class implementation
// ----------------------------------------------------------------------------

final public class Band {
  
  typealias BandName                      = String
  typealias BandExtent                    = (start: Int, end: Int)

  // ----------------------------------------------------------------------------
  // MARK: - Internal Properties
  
  private(set) var segments               = [Segment]()
  private(set) var bands                  = [BandName:BandExtent]()
  private(set) var sortedBands            : [String]!

  // ----------------------------------------------------------------------------
  // MARK: - Private Properties
  
  //    var frequency = [Int]()
  //    var band = [BandStruct]()
  //    var soundEnabled = true
  //    var soundLeavingBand = "Basso"
  //    var soundEnteringBand = "Glass"
  //  var sortAscending: Bool = false {
  //    didSet {
  //      // re-sort
  //      sortedBandTitles = loadSortedBands()
  //    }
  //  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Read Only Internal Properties
  
  //    private(set) var allBands: [[String:AnyObject]]?
  //    private(set) var sortedBandTitles: [String]?
  
  // ----------------------------------------------------------------------------
  // MARK: - Structure
  
  struct Segment {
    private(set) var name               : String
    private(set) var title              : String
    private(set) var start              : Int
    private(set) var end                : Int
    private(set) var startIsEdge        : Bool
    private(set) var endIsEdge          : Bool
    private(set) var useMarkers         : Bool
    private(set) var enabled            : Bool
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Properties
  
  //    private var _previousBandDict: [NSObject:AnyObject]?
  private let _log                        = (NSApp.delegate as! AppDelegate).msg

  // constants
  private let kSoundLeavingBand           = "Basso"
  private let kSoundEnteringBand          = "Glass"
  private let kSortKey                    = "integerValue"
  private let kBandKey                    = "band"
  private let kEnabledKey                 = "enabled"
  private let kBandSegmentsFile           = "BandSegments"
  private let kBandPlanFolder             = "Resources"
  private let kStartKey                   = "start"
  private let kEndKey                     = "end"
  private let kSegmentsKey                = "segments"
  private let kUseMarkersKey              = "useMarkers"
  private let kContiguousSegmentsKey      = "contiguousSegments"
  private let kUnknownBandName            = "Gen Coverage"
  private let kUnknownBandStart           : CGFloat = 0
  private let kUnknownBandEnd             : CGFloat = 60_000_000
  
  // ----------------------------------------------------------------------------
  // MARK: - Singleton
  
  public static let sharedInstance = Band()
  
  private init() {            // "private" prevents others from calling init()
    
    // read the BandSegments file (prefer the User version, if it exists)
    let bandSegments = arrayForFile( kBandSegmentsFile, ofType: "plist", fromBundle: Bundle.main ) as! [[String:AnyObject]]
    for s in bandSegments {
      
      segments.append(Segment(name: s["band"] as! String,
                              title: s["segment"] as! String,
                              start: s["start"]?.intValue ?? 0,
                              end: s["end"]?.intValue ?? 0,
                              startIsEdge: s["startIsEdge"]?.boolValue ?? false,
                              endIsEdge: s["endIsEdge"]?.boolValue ?? false,
                              useMarkers: s["useMarkers"]?.boolValue ?? false,
                              enabled: s["enabled"]?.boolValue ?? false ))
      
      // is the band already in the Bands dictionary?
      if var bandExtent = bands[s["band"] as! String] {
        
        // YES, add its segments
        if bandExtent.start > (s["start"] as? NSNumber)?.intValue ?? 0 {
          // starting segment
          bandExtent.start = (s["start"] as? NSNumber)?.intValue ?? 0
        }
        
        if bandExtent.end < (s["end"] as? NSNumber)?.intValue ?? 0 {
          // ending segment
          bandExtent.end = (s["end"] as? NSNumber)?.intValue ?? 0
        }
        bands[s["band"] as! String] = bandExtent
        
      } else {
        
        // NO, add the band to the dictionary
        bands[s["band"] as! String] = ( start: (s["start"] as? NSNumber)?.intValue ?? 0, end: (s["end"] as? NSNumber)?.intValue ?? 0 )
      }
    }
    // sort by frequency
    sortedBands = bands.keys.sorted {return Int($0) ?? 0 > Int($1) ?? 0}

    // setup the frequency and band arrays
    //    frequency = [Int]( count: kMaxSlices, repeatedValue: 0 )
    //    band = [BandStruct]( count: kMaxSlices, repeatedValue: BandStruct() )
    
    //    // initialize band lists
    //    sortedBandTitles = loadSortedBands()
    //    allBands = loadAllBands()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Instance Methods
  
  //  /**
  //  * Change the Frequency of a Slice
  //  */
  //  func frequency( freq: Int, forSlice slice: Int ) {
  //    frequency[slice] = freq
  //    load( slice )
  //  }
  //
  //  // ----------------------------------------------------------------------------
  //  // MARK: - Private Methods
  //
  //  /**
  //  * Populate the class with values from the backing store
  //  */
  //  private func load( slice: Int ) {
  //
  //    let freq = frequency[ slice ]
  //    if let prevDict = _previousBandDict {
  //      if true == ( freq >= (  prevDict[ kStartKey ] as! Int ) && freq <=  (prevDict[ kEndKey ] as! Int) )  {
  //        // the new Frequency is in the current Band
  //        findInBand( freq, bandKey: band[slice].name!.title, bandDict: prevDict, slice: slice )
  //      } else {
  //        // the new Frequency is NOT in the "prevDict", scan the entire BandPlan
  //        scanBandPlan( freq, slice: slice )
  //      }
  //    } else {
  //      // there is no "prevDict", scan the entire BandPlan
  //      scanBandPlan( freq, slice: slice )
  //    }
  //  }
  //  /**
  //  * Scan the BandPlan for the specified frequency
  //  */
  //  private func scanBandPlan( freq: Int, slice: Int ) {
  //    // iterate through the Band Plan
  //    for (bandKey, bandDict ) in _plan {
  //      if findInBand(freq, bandKey: bandKey as! String, bandDict: bandDict as! Dictionary, slice: slice) == true { return }
  //    }
  //    // the Frequency is not in any known Band
  //    band[slice].isContiguous = true
  //    band[slice].useMarkers = false
  //    band[slice].name = (kUnknownBandName, kUnknownBandStart, kUnknownBandEnd)
  //    band[slice].segment = nil
  //    _previousBandDict = nil
  //  }
  //  /**
  //  * Search the specified Band for the current frequency
  //  */
  //  private func findInBand( freq: Int, bandKey: String, bandDict: [NSObject:AnyObject], slice: Int ) -> Bool {
  //    if (bandDict[ kContiguousSegmentsKey ] as! Bool) == true {
  //      // this band has Contiguous Segments
  //      if true == ( freq >= (  bandDict[ kStartKey ] as! Int ) && freq <=  (bandDict[ kEndKey ] as! Int) )  {
  //        band[slice].isContiguous = true
  //        band[slice].useMarkers = (bandDict[ kUseMarkersKey ] as! Bool)
  //        band[slice].enabled = (bandDict[ kEnabledKey ] as! Bool)
  //        band[slice].name = (bandKey, CGFloat(bandDict[ kStartKey ] as! Int) , CGFloat(bandDict[ kEndKey ] as! Int ))
  //
  //        for (segmentKey, segmentDict) in ( bandDict[ kSegmentsKey ] as! [NSObject:AnyObject] ) {
  //          if true == ( freq >= ( segmentDict[ kStartKey ] as! Int ) && freq <= (segmentDict[ kEndKey ] as! Int) ) {
  //            band[slice].segment = (segmentKey as! String, CGFloat(segmentDict[ kStartKey ] as! Int) , CGFloat(segmentDict[ kEndKey ] as! Int))
  //          }
  //        }
  //        _previousBandDict = (bandDict as [NSObject:AnyObject])
  //        return true
  //      }
  //    } else {
  //      // this band has Non-Contiguous Segments
  //      for (segmentKey, segmentDict) in ( bandDict[ kSegmentsKey ] as! [NSObject:AnyObject] ) {
  //        if true == ( freq >= (  segmentDict[ kStartKey ] as! Int ) && freq <= (segmentDict[ kEndKey ] as! Int) ) {
  //          band[slice].isContiguous = false
  //          band[slice].useMarkers = (bandDict[ kUseMarkersKey ] as! Bool)
  //          band[slice].name = (bandKey, CGFloat(bandDict[ kStartKey ] as! Int) , CGFloat(bandDict[ kEndKey ] as! Int))
  //          band[slice].segment = (segmentKey as! String, CGFloat(segmentDict[ kStartKey ] as! Int) , CGFloat(segmentDict[ kEndKey ] as! Int))
  //          _previousBandDict = (bandDict as [NSObject:AnyObject])
  //          return true
  //        }
  //      }
  //    }
  //    return false
  //  }
  //  /**
  //  * Return a sorted Array of Band Titles
  //  */
  //  private func loadSortedBands() -> [String] {
  //    // sort the Bands
  //    let bands = Array( _plan.keys )
  //    if sortAscending == true {
  //        return (bands as! [String]).sort()
  //    } else {
  //      return (bands as! [String]).sort()
  //    }
  //  }
  //  /**
  //  * Return an Array of Dictionaries containing Band information
  //  */
  //  private func loadAllBands() -> [[String:AnyObject]] {
  //    var allBandsArray = [[String:AnyObject]]()
  //
  //    // populate the Bands Array
  //    for band in Array( _plan.keys ) {
  //      // get the Band's dictionary
  //      if let bandDict = _plan[ band ] as? [String:AnyObject] {
  //        allBandsArray.append( bandDict ) }
  //    }
  //    return allBandsArray
  //  }
  
  /// Return an Array with the contents of a file in the User domain (if it exists)
  ///
  /// - Parameters:
  ///   - fileName:             a file name
  ///   - fileType:             a file type
  ///   - bundle:               a bundle
  /// - Returns:                an array
  ///
  private func arrayForFile( _ fileName:String, ofType fileType:String, fromBundle bundle:Bundle ) -> [AnyObject] {
    var theArray: NSArray
    
    let userFilePath = appFolder().path + "/" + fileName + "." + fileType
    let fileManager = FileManager.default
    if fileManager.fileExists( atPath: userFilePath ) {
      
      // user file exists
      theArray = NSArray(contentsOfFile: userFilePath )!
    
    } else {
      
      // no user file exists, use the default file
      let defaultFilePath = bundle.path(forResource: fileName, ofType: fileType )
      theArray = NSArray(contentsOfFile: defaultFilePath! )!
      
      // create a user version of the file
      theArray.write(toFile: userFilePath, atomically: true)
    }
    return theArray as [AnyObject]
  }
  /// Return the folder (as a URL) for App specific files
  ///
  /// - Returns:            a URL
  ///
  private func appFolder() -> URL {
    let fileManager = FileManager()
    let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask ) as [URL]
    
    let appFolder = urls.first!.appendingPathComponent( Bundle.main.bundleIdentifier! )
    
    // does the folder exist?
    if !fileManager.fileExists( atPath: appFolder.path ) {
      
      // NO, try to create it
      do {
        try fileManager.createDirectory( at: appFolder, withIntermediateDirectories: false, attributes: nil)
      
      } catch let error as NSError {
        _log("Error creating App Support folder: \(error.localizedDescription)", .warning, #function, #file, #line)
      }
    }
    return appFolder
  }
}

