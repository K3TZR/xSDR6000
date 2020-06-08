//
//  WanManager.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/5/20.
//  Copyright © 2020 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000

public struct Token {
  
  var value         : String
  var expiresAt     : Date
  
  public func isValidAtDate(_ date: Date) -> Bool {
    return (date < self.expiresAt)
  }
}

// --------------------------------------------------------------------------------
// MARK: - WanManager Delegate protocol
// --------------------------------------------------------------------------------

protocol WanManagerDelegate : class {
  
  var auth0Email            : String?   {get set}
  var smartLinkWasLoggedIn  : Bool      {get set}
  
  func smartLinkTestResults(results: WanTestConnectionResults)
  func smartLinkConnectionReady(handle: String, serial: String)
  func smartLinkUserSettings(name: String?, call: String?)
  func smartLinkImage(image: NSImage?)
  
  func openRadioPicker()
}

public final class WanManager : WanServerDelegate, Auth0Delegate {

  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  static let kServiceName                   = ".oauth-token"
  static let testTimeout                    : TimeInterval = 0.1
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties

  private var _wanServer                    : WanServer?
  private let _delegate                     : WanManagerDelegate!
  private var _serverDelegate               : WanServerDelegate?
  private let _log                          = Logger.sharedInstance.logMessage
  private var _previousToken                : Token?
  private var _auth0ViewController          : Auth0ViewController?
  private var _mainWindow                   : NSWindow { NSApplication.shared.mainWindow! }
  
  // constants
  private let kApplicationJson              = "application/json"
  private let kAuth0Delegation              = "https://frtest.auth0.com/delegation"
  private let kClaimEmail                   = "email"
  private let kClaimPicture                 = "picture"
  private let kConnectTitle                 = "Connect"
  private let kDisconnectTitle              = "Disconnect"
  private let kGrantType                    = "urn:ietf:params:oauth:grant-type:jwt-bearer"
  private let kHttpHeaderField              = "content-type"
  private let kHttpPost                     = "POST"
  
  private let kKeyClientId                  = "client_id"                   // dictionary keys
  private let kKeyGrantType                 = "grant_type"
  private let kKeyIdToken                   = "id_token"
  private let kKeyRefreshToken              = "refresh_token"
  private let kKeyScope                     = "scope"
  private let kKeyTarget                    = "target"
  
  private let kLowBWTitle                   = "Low BW Connect"
  private let kLoginTitle                   = "Log In"
  private let kLogoutTitle                  = "Log Out"
  private let kPlatform                     = "macOS"
  private let kScope                        = "openid email given_name family_name picture"
  private let kService                      = Logger.kAppName + kServiceName
  private let kUpnpIdentifier               = "upnpSupported"
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization

  init(delegate: WanManagerDelegate) {
    _delegate = delegate
    
    _wanServer = WanServer(delegate: self)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// SmartLink log in
  /// - Parameter auth0Email:     saved email (if any)
  ///
  public func smartLinkLogin(using auth0Email: String?) -> Bool {
    
    if let tokenValue = getToken(using: auth0Email) {
      
      _delegate!.smartLinkImage(image: getUserImage(tokenValue: tokenValue))
      
      // have a token, try to connect
      return _wanServer!.connectToSmartLinkServer(appName: Logger.kAppName, platform: kPlatform, token: tokenValue, ping: true)
    }
    
    _log("Smartlink login: token NOT found", .debug, #function, #file, #line)
    return false
  }
  /// SmartLink log out
  ///
  public func smartLinkLogout() {
    _wanServer?.disconnectFromSmartLinkServer()
    _wanServer = nil
  }
  
  public func validateAuth0Credentials() {
    // show the Auth0 sheet
    let auth0Storyboard = NSStoryboard(name: "RadioPicker", bundle: nil)
    _auth0ViewController = auth0Storyboard.instantiateController(withIdentifier: "Auth0Login") as? Auth0ViewController
    _auth0ViewController!.delegate = self
    _mainWindow.contentViewController!.presentAsSheet(_auth0ViewController!)
  }

  public func openRadio(_ packet: DiscoveryPacket) {
    _wanServer?.sendConnectMessage(for: packet)
  }
  
  public func closeRadio(_ packet: DiscoveryPacket) {
    _wanServer?.sendDisconnectMessage(for: packet)
  }
  
  public func testConnection(_ packet: DiscoveryPacket) {
    _wanServer?.sendTestConnection(for: packet)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Obtain atoken
  /// - Parameter auth0Email:     saved email (if any)
  /// - Returns:                  a Token (if any)
  ///
  private func getToken(using auth0Email: String?) -> String? {
    var tokenValue : String? = nil
    
    // is there a saved Auth0 token which has not expired?
    if let previousToken = _previousToken, previousToken.isValidAtDate( Date()) {
      // YES, we can log into SmartLink, use the saved token
      tokenValue = previousToken.value
      
      _log("Smartlink login: previous token is unexpired", .debug, #function, #file, #line)

    } else if auth0Email != nil {
      // there is a saved email, use it to obtain a refresh token from Keychain
      if let refreshToken = Keychain.get(kService, account: auth0Email!) {
        
        // can we get a Token Value from the Refresh Token?
        if let value = getTokenValue(from: refreshToken) {
          // YES, we can use the saved token to Log in
          tokenValue = value

          _log("Smartlink login: token obtained from refresh token", .debug, #function, #file, #line)

        } else {
          // NO, the Keychain entry is no longer valid, delete it
          Keychain.delete(kService, account: auth0Email!)
          
          _log("Smartlink login: refresh token invalid", .debug, #function, #file, #line)
        }
      } else {

        _log("Smartlink login: refresh token not found", .debug, #function, #file, #line)
      }
      
    } else {
      _log("Smartlink login: refresh email empty", .debug, #function, #file, #line)
    }
    return tokenValue
  }
  /// Given a Refresh Token attempt to get a Token
  ///
  /// - Parameter refreshToken:         a Refresh Token
  /// - Returns:                        a Token (if any)
  ///
  private func getTokenValue(from refreshToken: String) -> String? {
    
    // guard that the token isn't empty
    guard refreshToken != "" else { return nil }
    
    // build a URL Request
    let url = URL(string: kAuth0Delegation)
    var urlRequest = URLRequest(url: url!)
    urlRequest.httpMethod = kHttpPost
    urlRequest.addValue(kApplicationJson, forHTTPHeaderField: kHttpHeaderField)
    
    // guard that body data was created
    guard let bodyData = createBodyData(refreshToken: refreshToken) else { return "" }
    
    // update the URL Request and retrieve the data
    urlRequest.httpBody = bodyData
    let (responseData, _, error) = URLSession.shared.synchronousDataTask(with: urlRequest)
    
    // guard that the data isn't empty and that no error occurred
    guard let data = responseData, error == nil else {
      
      _log("SmartLink login: error retrieving token, \(error?.localizedDescription ?? "")", .error, #function, #file, #line)
      return nil
    }
    
    // is there a Token?
    if let token = parseTokenResponse(data: data) {
      do {
        
        let jwt = try decode(jwt: token)
        
        // validate id token; see https://auth0.com/docs/tokens/id-token#validate-an-id-token
        if !isJWTValid(jwt) {
          // log the error
          _log("SmartLink login: token invalid", .error, #function, #file, #line)
          
          return nil
        }
        
      } catch let error as NSError {
        // log the error
        _log("SmartLink login: error decoding token, \(error.localizedDescription)", .error, #function, #file, #line)
        
        return nil
      }
      return token
    }
    // NO token
    return nil
  }
  /// Get the Logon Image
  /// - Parameter token:    a token value
  /// - Returns:            the image or nil
  ///
  private func getUserImage( tokenValue: String) -> NSImage? {
    
    // try to get the JSON Web Token
    if let jwt = try? decode(jwt: tokenValue) {
      
      // get the Log On image (if any) from the token
      let claim = jwt.claim(name: kClaimPicture)
      if let gravatar = claim.string, let url = URL(string: gravatar) {
        // get the image
        if let data = try? Data(contentsOf: url) {
          return NSImage(data: data)
        }
      }
    }
    return nil
  }
  /// Create the Body Data for use in a URLSession
  ///
  /// - Parameter refreshToken:     a Refresh Token
  /// - Returns:                    the Data (if created)
  ///
  private func createBodyData(refreshToken: String) -> Data? {
    
    // guard that the Refresh Token isn't empty
    guard refreshToken != "" else { return nil }
    
    // create & populate the dictionary
    var dict = [String : String]()
    dict[kKeyClientId] = Auth0ViewController.kClientId
    dict[kKeyGrantType] = kGrantType
    dict[kKeyRefreshToken] = refreshToken
    dict[kKeyTarget] = Auth0ViewController.kClientId
    dict[kKeyScope] = kScope
    
    // try to obtain the data
    do {
      
      let data = try JSONSerialization.data(withJSONObject: dict)
      // success
      return data
      
    } catch _ {
      // failure
      return nil
    }
  }
  /// Parse the URLSession data
  ///
  /// - Parameter data:               a Data
  /// - Returns:                      a Token (if any)
  ///
  private func parseTokenResponse(data: Data) -> String? {
    
    do {
      // try to parse
      let myJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
      
      // was something returned?
      if let parseJSON = myJSON {
        
        // YES, does it have a Token?
        if let  idToken = parseJSON[kKeyIdToken] as? String {
          // YES, retutn it
          return idToken
        }
      }
      // nothing returned
      return nil
      
    } catch _ {
      // parse error
      return nil
    }
  }
  /// check if a JWT token is valid
  ///
  /// - Parameter jwt:                  a JWT token
  /// - Returns:                        valid / invalid
  ///
  private func isJWTValid(_ jwt: JWT) -> Bool {
    // see: https://auth0.com/docs/tokens/id-token#validate-an-id-token
    // validate only the claims
    
    // 1.
    // Token expiration: The current date/time must be before the expiration date/time listed in the exp claim (which
    // is a Unix timestamp).
    guard let expiresAt = jwt.expiresAt, Date() < expiresAt else { return false }
    
    // 2.
    // Token issuer: The iss claim denotes the issuer of the JWT. The value must match the the URL of your Auth0
    // tenant. For JWTs issued by Auth0, iss holds your Auth0 domain with a https:// prefix and a / suffix:
    // https://YOUR_AUTH0_DOMAIN/.
    var claim = jwt.claim(name: "iss")
    guard let domain = claim.string, domain == Auth0ViewController.kAuth0Domain else { return false }
    
    // 3.
    // Token audience: The aud claim identifies the recipients that the JWT is intended for. The value must match the
    // Client ID of your Auth0 Client.
    claim = jwt.claim(name: "aud")
    guard let clientId = claim.string, clientId == Auth0ViewController.kClientId else { return false }
    
    return true
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Auth0Delegate methods
  
  /// Set the id and refresh token
  ///
  /// - Parameters:
  ///   - idToken:        id Token string
  ///   - refreshToken:   refresh Token string
  ///
  func setTokens(idToken: String, refreshToken: String) {
    var expireDate = Date()
    
//    Swift.print("----->>>>> IdToken = \(idToken)\n----->>>>> refreshToken = \(refreshToken)")

    do {
      
      // try to get the JSON Web Token
      let jwt = try decode(jwt: idToken)
      
      // validate id token; see https://auth0.com/docs/tokens/id-token#validate-an-id-token
      if !isJWTValid(jwt) {
        
        _log("SmartLink login: token INVALID", .error, #function, #file, #line)
        
        return
      }
      // save the Log On email (if any)
      var claim = jwt.claim(name: kClaimEmail)
      if let email = claim.string {
        
        // YES, save in user defaults
        _delegate.auth0Email = email
        
        // save refresh token in keychain
        Keychain.set(kService, account: email, data: refreshToken)
      }
      
      // save the Log On picture (if any)
      claim = jwt.claim(name: kClaimPicture)
      if let gravatar = claim.string, let url = URL(string: gravatar) {
        // get the image
        if let data = try? Data(contentsOf: url) {
          _delegate.smartLinkImage(image: NSImage(data: data))
        }
      }
      // get the expiry date (if any)
      if let expiresAt = jwt.expiresAt {
        expireDate = expiresAt
      }
      
    } catch let error as NSError {
      
      // log the error & exit
      _log("SmartLink login: error decoding token, \(error.localizedDescription)", .error, #function, #file, #line)
      
      return
    }
    // save id token with expiry date
    _previousToken = Token(value: idToken, expiresAt: expireDate)
    
    _delegate.smartLinkWasLoggedIn = true
  }

  func closeAuth0() {
    
    _auth0ViewController!.dismiss(nil)
  
    _ = smartLinkLogin(using: _delegate.auth0Email)
    
    _delegate.openRadioPicker()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - WanServerDelegate methods
  
  public func wanUserSettings(name: String, call: String) {
    _delegate.smartLinkUserSettings(name: name, call: call)
  }
  
  public func wanRadioConnectReady(handle: String, serial: String) {
    _delegate.smartLinkConnectionReady(handle: handle, serial: serial)
  }
  
  public func wanTestResultsReceived(results: WanTestConnectionResults) {
    _delegate.smartLinkTestResults(results: results)
  }
}
