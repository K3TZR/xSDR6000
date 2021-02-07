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
    
    typealias BandName      = String
    typealias BandExtent    = (start: Int, end: Int)
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Static Properties
    
    static let hfList = [
        ( 160, "160" ),
        ( 80, "80" ),
        ( 60, "60" ),
        ( 40, "40" ),
        ( 30, "30" ),
        ( 20, "20" ),
        ( 17, "17" ),
        ( 15, "15" ),
        ( 12, "12" ),
        ( 10, "10" ),
        ( 6, "6" ),
        ( 4, "4" ),
        ( 0, "" ),
        ( 33, "WWV" ),
        ( 34, "GEN" ),
        ( 2200, "2200" ),
        ( 6300, "6300" ),
        ( -1, "XVTR" )
    ]
    static let xvtrList = [
        ( 0, "" ),
        ( 0, "" ),
        ( 0, "" ),
        ( 0, "" ),
        ( 0, "" ),
        ( 0, "" ),
        ( 0, "" ),
        ( 0, "" ),
        ( 0, "" ),
        ( 0, "" ),
        ( 0, "" ),
        ( 0, "" ),
        ( 0, "" ),
        ( 0, "" ),
        ( 0, "" ),
        ( 0, "" ),
        ( 0, "" ),
        ( -2, "HF" )
    ]
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal Properties
    
    private(set) var segments               = [Segment]()
    private(set) var bands                  = [BandName:BandExtent]()
    private(set) var sortedBands            : [String]!
    
    // ----------------------------------------------------------------------------
    // MARK: - Private Properties
        
    struct Segment {
        private(set) var band               : BandName
        private(set) var title              : String
        private(set) var start              : Int
        private(set) var end                : Int
        private(set) var startIsEdge        : Bool
        private(set) var endIsEdge          : Bool
        private(set) var useMarkers         : Bool
        private(set) var enabled            : Bool
    }
    
    // constants
    private let kBandSegmentsFile           = "BandSegments"
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Singleton
    
    public static let sharedInstance = Band()
    
    private init() {            // "private" prevents others from calling init()
        // read the BandSegments file (prefer the User version, if it exists)
        let plistDictArray = Bundle.parsePlist( kBandSegmentsFile, bundle: Bundle.main )
        
        for entry in plistDictArray {
            segments.append(Segment(band: entry["band"] ?? "Unknown",
                                    title: entry["segment"] ?? "",
                                    start: (entry["start"] ?? "").asInt,
                                    end: (entry["end"] ?? "").asInt,
                                    startIsEdge: (entry["startIsEdge"] ?? "").asBool,
                                    endIsEdge: (entry["endIsEdge"] ?? "").asBool,
                                    useMarkers: (entry["useMarkers"] ?? "").asBool,
                                    enabled: (entry["enabled"] ?? "").asBool))
        }
        for segment in segments {
            // is the band already in the Bands dictionary?
            if var bandExtent = bands[segment.band] {
                // YES, add its segments
                if bandExtent.start > segment.start { bandExtent.start = segment.start }
                if bandExtent.end < segment.end {  bandExtent.end = segment.end }
                bands[segment.band] = bandExtent
                
            } else {
                // NO, add the band to the dictionary
                bands[segment.band] = ( start: segment.start, end: segment.end )
            }
        }
        // sort by frequency
        sortedBands = bands.keys.sorted {return Int($0) ?? 0 > Int($1) ?? 0}
    }
}
