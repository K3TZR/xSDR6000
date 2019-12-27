//
//  URLSessionExtension.swift
//  xAPITester
//
//  Created by Mario Illgen on 11.02.18.
//  Copyright © 2018 Mario Illgen. All rights reserved.
//

import Foundation

extension URLSession {
  
  func synchronousDataTask(with urlRequest: URLRequest) -> (Data?, URLResponse?, Error?) {
    var data: Data?
    var response: URLResponse?
    var error: Error?
    
    let semaphore = DispatchSemaphore(value: 0)
    
    let dataTask = self.dataTask(with: urlRequest) {
      data = $0
      response = $1
      error = $2
      
      semaphore.signal()
    }
    dataTask.resume()
    
    _ = semaphore.wait(timeout: .distantFuture)
    
    return (data, response, error)
  }
  
  func synchronousDataTask(with url: URL) -> (Data?, URLResponse?, Error?) {
    var data: Data?
    var response: URLResponse?
    var error: Error?
    
    let semaphore = DispatchSemaphore(value: 0)
    
    let dataTask = self.dataTask(with: url) {
      data = $0
      response = $1
      error = $2
      
      semaphore.signal()
    }
    dataTask.resume()
    
    _ = semaphore.wait(timeout: .distantFuture)
    
    return (data, response, error)
  }
}
