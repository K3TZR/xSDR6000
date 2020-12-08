//
//  Auth0ViewController.swift
//  CommonCode
//
//  Created by Mario Illgen on 09.02.18.
//  Copyright © 2018 Mario Illgen. All rights reserved.
//

import Cocoa
import WebKit
import SwiftyUserDefaults
import xLib6000

// --------------------------------------------------------------------------------
// MARK: - Auth0 Delegate definition
// --------------------------------------------------------------------------------

protocol Auth0Delegate : class {
  
  /// set the id and refresh token
  ///
  func setTokens(idToken: String, refreshToken: String)
  
  func closeAuth0()
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
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public weak var delegate                  : Auth0Delegate?
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private weak var _customView    : NSView!
  
  private let _api                          = Api.sharedInstance
  private let _log                          = Logger.sharedInstance.logMessage
  private var myWebView                     : WKWebView!
  private let kAutosaveName                 = "AuthViewWindow"
  
  private let kKeyIdToken                    = "id_token"
  private let kKeyRefreshToken               = "refresh_token"
  
  
  private var _smartLinkURL = ""
  
  // ----------------------------------------------------------------------------
  // MARK: - Overridden methods
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    _log("Auth0 view loaded", .debug, #function, #file, #line)

//    if !Defaults.smartLinkWasLoggedIn {
      // clear all cookies to prevent falling back to earlier saved login credentials
      let storage = HTTPCookieStorage.shared
      if let cookies = storage.cookies {
        for index in 0..<cookies.count {
          let cookie = cookies[index]
          storage.deleteCookie(cookie)
        }
      }
//    }
    
    let _state = String.random(length: 16)
    _smartLinkURL =  """
    \(Auth0ViewController.kAuth0Domain)authorize?client_id=\(Auth0ViewController.kClientId)\
    &redirect_uri=\(Auth0ViewController.kRedirect)\
    &response_type=\(Auth0ViewController.kResponseType)\
    &scope=\(Auth0ViewController.kScope)\
    &state=\(_state)\
    &device=\(AppDelegate.kAppName)
    """
    
    // create a URLRequest for the SmartLink URL
    let request = URLRequest(url: URL(string: _smartLinkURL)!)
    
    // configure a web view
    let configuration = WKWebViewConfiguration()
    myWebView = WKWebView(frame: .zero, configuration: configuration)
    myWebView.translatesAutoresizingMaskIntoConstraints = false
    myWebView.navigationDelegate = self
    
    // add it to the view hierarchy
    _customView.addSubview(myWebView)
    
    // anchor its position
    [myWebView.topAnchor.constraint(equalTo: _customView.topAnchor),
     myWebView.bottomAnchor.constraint(equalTo: _customView.bottomAnchor),
     myWebView.leftAnchor.constraint(equalTo: _customView.leftAnchor),
     myWebView.rightAnchor.constraint(equalTo: _customView.rightAnchor)].forEach {
      $0.isActive = true }
    
    // load it
    if myWebView.load(request) == nil {
      
      _log("Auth0 web view failed to load", .error, #function, #file, #line)
    }
    
    print(request)
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
  
  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  @IBAction func cancelButton(_ sender: Any) {
    DispatchQueue.main.async { [weak self] in
      self?.dismiss(self)
    }
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
    
    let nsError = (error as NSError)
    if (nsError.domain == "WebKitErrorDomain" && nsError.code == 102) || (nsError.domain == "WebKitErrorDomain" && nsError.code == 101) {
      // Error code 102 "Frame load interrupted" is raised by the WKWebView
      // when the URL is from an http redirect. This is a common pattern when
      // implementing OAuth with a WebView.
      return
    }
    _log("Auth0 navigation failed: \(error.localizedDescription)", .error, #function, #file, #line)
    
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
        
        // extract the tokens
        var responseParameters = [String: String]()
        if let query = url.query { responseParameters += query.parametersFromQueryString }
        if let fragment = url.fragment, !fragment.isEmpty { responseParameters += fragment.parametersFromQueryString }
        
        // did we extract both tokens?
        if let idToken = responseParameters[kKeyIdToken], let refreshToken = responseParameters[kKeyRefreshToken] {
          
          // YES, pass them to our delegate
          delegate!.setTokens(idToken: idToken, refreshToken: refreshToken)
        }
        decisionHandler(.cancel)
        
        delegate!.closeAuth0()
        return
      }
    }
    decisionHandler(.allow)
  }
}
