//
//  DataExtensions.swift
//
//  Created by Mario Illgen on 27.01.18.
//  Copyright © 2018 Mario Illgen. All rights reserved.
//

import Foundation

extension Data {
  
//  init?(base64URLEncoded string: String) {
//    let base64Encoded = string
//      .replacingOccurrences(of: "_", with: "/")
//      .replacingOccurrences(of: "-", with: "+")
//    // iOS can't handle base64 encoding without padding. Add manually
//    let padLength = (4 - (base64Encoded.count % 4)) % 4
//    let base64EncodedWithPadding = base64Encoded + String(repeating: "=", count: padLength)
//    self.init(base64Encoded: base64EncodedWithPadding)
//  }
//  
//  func base64URLEncodedString() -> String {
//    // use URL safe encoding and remove padding
//    return self.base64EncodedString()
//      .replacingOccurrences(of: "/", with: "_")
//      .replacingOccurrences(of: "+", with: "-")
//      .replacingOccurrences(of: "=", with: "")
//  }
}
