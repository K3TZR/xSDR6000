//
//  StringExtension.swift
//
//  Created by Mario Illgen on 21.03.17.
//  Copyright © 2017 Mario Illgen. All rights reserved.
//
// updated for Swift 4

import Foundation

// extensions for URL strings
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
