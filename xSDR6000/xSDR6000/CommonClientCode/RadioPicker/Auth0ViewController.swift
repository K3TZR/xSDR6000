//
//  Auth0ViewController.swift
//  CommonCode
//
//  Created by Mario Illgen on 09.02.18.
//  Copyright © 2018 Mario Illgen. All rights reserved.
//

import Cocoa
import WebKit
import xLib6000

//#if XSDR6000
//  import xLib6000
//#endif

// --------------------------------------------------------------------------------
// MARK: - Auth0 Controller Delegate definition
// --------------------------------------------------------------------------------

protocol Auth0ControllerDelegate {
  
  /// Close this sheet
  ///
  func closeAuth0Sheet()
  
  /// set the id and refresh token
  ///
  func setTokens(idToken: String, refreshToken: String)
}

// ------------------------------------------------------------------------------
// MARK: - Auth0 ViewController Class implementation
// ------------------------------------------------------------------------------

final class Auth0ViewController             : NSViewController, WKNavigationDelegate {

  static let kAuth0Domain                   = "https://frtest.auth0.com/"
  static let kClientId                      = "4Y9fEIIsVYyQo5u6jr7yBWc4lV5ugC2m"
  static let kRedirect                      = "https://frtest.auth0.com/mobile"
  static let kResponseType                  = "token"
  static let kScope                         = "openid%20offline_access%20email%20given_name%20family_name%20picture"
  static let kState                         = "ypfolhnqwpedrxdb"

  static let smartLinkURL = """
  \(kAuth0Domain)authorize?client_id=\(kClientId)\
  &redirect_uri=\(kRedirect)\
  &response_type=\(kResponseType)\
  &scope=\(kScope)\
  &state=\(kState)\
  &device=\(AppDelegate.kName)
  """

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _customView    : NSView!
  
  private let _api                          = Api.sharedInstance
  private let _log                          = NSApp.delegate as! AppDelegate
  private var myWebView                     : WKWebView!
  private let myURL                         = URL(string: smartLinkURL)!
  private let kAutosaveName                 = "AuthViewWindow"
  private var _delegate                     : Auth0ControllerDelegate {
    return representedObject as! Auth0ControllerDelegate }

  private let kKeyIdToken                    = "id_token"
  private let kKeyRefreshToken               = "refresh_token"

  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()

    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif

//    // clear all cookies to prevent falling back to earlier saved login credentials
//    let storage = HTTPCookieStorage.shared
//    if let cookies = storage.cookies {
//      for index in 0..<cookies.count {
//        let cookie = cookies[index]
//        storage.deleteCookie(cookie)
//      }
//    }

    // create a URLRequest for the SmartLink URL
    let request = URLRequest(url: myURL)
    
    // configure a web view
    let configuration = WKWebViewConfiguration()
    myWebView = WKWebView(frame: .zero, configuration: configuration)
    myWebView.translatesAutoresizingMaskIntoConstraints = false
    myWebView.navigationDelegate = self
    
    // add it to the view hierarchy
    _customView.addSubview(myWebView)
    
    // anchor its position
    if #available(OSX 10.11, *) {
      // 10.11+
      [myWebView.topAnchor.constraint(equalTo: _customView.topAnchor),
       myWebView.bottomAnchor.constraint(equalTo: _customView.bottomAnchor),
       myWebView.leftAnchor.constraint(equalTo: _customView.leftAnchor),
       myWebView.rightAnchor.constraint(equalTo: _customView.rightAnchor)].forEach  {
        anchor in
        anchor.isActive = true
      }
    
    } else {
      // before 10.11
      NSLayoutConstraint(item: myWebView as Any, attribute: .leading, relatedBy: .equal, toItem: _customView, attribute: .leading, multiplier: 1.0, constant: 0.0).isActive = true
      NSLayoutConstraint(item: myWebView as Any, attribute: .trailing, relatedBy: .equal, toItem: _customView, attribute: .trailing, multiplier: 1.0, constant: 0.0).isActive = true
      NSLayoutConstraint(item: myWebView as Any, attribute: .top, relatedBy: .equal, toItem: _customView, attribute:.top, multiplier: 1.0, constant:0.0).isActive = true
      NSLayoutConstraint(item: myWebView as Any, attribute: .bottom, relatedBy: .equal, toItem: _customView, attribute:.bottom, multiplier: 1.0, constant:0.0).isActive = true
    }
    // load it
    if myWebView.load(request) == nil {
      
      _log.msg("Auth0 web view failed to load", level: .error, function: #function, file: #file, line: #line)
    }
  }
  
  override func viewWillAppear() {
    
    super.viewWillAppear()
    // position it
    view.window!.setFrameUsingName(kAutosaveName)
  }
  
  override func viewWillDisappear() {
    
    super.viewWillDisappear()
    // save its position
    view.window!.saveFrame(usingName: kAutosaveName)
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Respond to the Cancel button
  ///
  /// - Parameter sender:         the button
  ///
  @IBAction func cancelButton(_ sender: NSButton) {
    
    _delegate.closeAuth0Sheet()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - WKNavigation delegate
  
  /// Invoked when an error occurs while starting to load data for the main frame
  ///
  /// - Parameters:
  ///   - webView:                a webView
  ///   - navigation:             descriptive info re navigation action
  ///   - error:                  error (if any)
  ///
  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    
    _log.msg("Could not navigate to Auth0 page: \(error.localizedDescription)", level: .error, function: #function, file: #file, line: #line)
  }
  /// Decides whether to allow or cancel a navigation
  ///
  /// - Parameters:
  ///   - webView:                a webView
  ///   - navigationAction:       descriptive info re navigation action
  ///   - decisionHandler:        ???
  ///
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    
    // does the navigation action's request contain a URL?
    if let url = navigationAction.request.url {
      
      // YES, is there a token inside the url?
      if url.absoluteString.contains(kKeyIdToken) {
      
        // YES, make a dictionary
        var responseParameters = [String: String]()

        // extract the tokens
        if let query = url.query {
          responseParameters += query.parametersFromQueryString
        }
        if let fragment = url.fragment, !fragment.isEmpty {
          responseParameters += fragment.parametersFromQueryString
        }
        // did we extract both tokens?
        if let idToken = responseParameters[kKeyIdToken], let refreshToken = responseParameters[kKeyRefreshToken] {
          
          // YES, pass them to our delegate
          _delegate.setTokens(idToken: idToken, refreshToken: refreshToken)
        }
        // end the navigation
        decisionHandler(.cancel)
        
        // tell the delegate to close the Auth0 sheet
        _delegate.closeAuth0Sheet()
        
        return
      }
    }
    // NO URL, allow the navigation
    decisionHandler(.allow)
  }
}
