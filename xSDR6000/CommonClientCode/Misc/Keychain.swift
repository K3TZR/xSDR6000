//
//  Keychain.swift
//  CommonCode
//
//  Created by Mario Illgen on 12.02.18.
//  Copyright © 2018 Mario Illgen. All rights reserved.
//

import Foundation

import Security

final class Keychain {
  
  static func set(_ service: String, account: String, data: String) {
    var item: SecKeychainItem? = nil
    
    var status = SecKeychainFindGenericPassword(
      nil,
      UInt32(service.utf8.count),
      service,
      UInt32(account.utf8.count),
      account,
      nil,
      nil,
      &item)
    
    if status != noErr && status != errSecItemNotFound {
      print("Error finding keychain item to modify: \(status), \(SecCopyErrorMessageString(status, nil) ?? "" as CFString)")
      return
    }
    
    if item != nil {
      status = SecKeychainItemModifyContent(item!, nil, UInt32(data.utf8.count), data)
    } else {
      status = SecKeychainAddGenericPassword(
        nil,
        UInt32(service.utf8.count),
        service,
        UInt32(account.utf8.count),
        account,
        UInt32(data.utf8.count),
        data,
        nil)
    }
    
    if status != noErr {
      print("Error setting keychain item: \(SecCopyErrorMessageString(status, nil) ?? "" as CFString)")
    }
  }
  
  static func get(_ service: String, account: String) -> String? {
    var passwordLength: UInt32 = 0
    var password: UnsafeMutableRawPointer? = nil
    
    let status = SecKeychainFindGenericPassword(
      nil,
      UInt32(service.utf8.count),
      service,
      UInt32(account.utf8.count),
      account,
      &passwordLength,
      &password,
      nil)
    
    if status == errSecSuccess {
      guard password != nil else { return nil }
      let result = NSString(bytes: password!, length: Int(passwordLength), encoding: String.Encoding.utf8.rawValue) as String?
      SecKeychainItemFreeContent(nil, password)
      return result
    }
    
    return nil
  }
  
  static func delete(_ service: String, account: String) {
    var item: SecKeychainItem? = nil
    
    var status = SecKeychainFindGenericPassword(
      nil,
      UInt32(service.utf8.count),
      service,
      UInt32(account.utf8.count),
      account,
      nil,
      nil,
      &item)
    
    if status == errSecItemNotFound {
      return
    }
    
    if status != noErr {
      print("Error finding keychain item to delete: \(SecCopyErrorMessageString(status, nil) ?? "" as CFString)")
    }
    
    if item != nil {
      status = SecKeychainItemDelete(item!)
    }
    
    if status != noErr {
      print("Error deleting keychain item: \(SecCopyErrorMessageString(status, nil) ?? "" as CFString)")
    }
  }
}
