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

protocol WanManagerDelegate             : class {

  var smartLinkImage  : NSImage? {get set}
  var auth0Email      : String {get set}
  var wasLoggedIn     : Bool {get set}
  
  func openRadioPicker()

  /// Open the specified Radio
  ///
  /// - Parameter radio: a Discovery packet
  ///
  func openRadio(_ radio: DiscoveryPacket)
  
  /// Close the active Radio
  ///
  /// - Parameter radio: a Discovery packet
  ///
  func closeRadio(_ radio: DiscoveryPacket)
}

public final class WanManager : Auth0Delegate {
  
  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  static let kServiceName                   = ".oauth-token"
  static let testTimeout                    : TimeInterval = 0.1
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  @objc dynamic public var auth0Email       : String = ""

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _wanServer                    : WanServer?
  private let _delegate                     : WanManagerDelegate?
  private var _serverDelegate               : WanServerDelegate?
  private let _log                          = Logger.sharedInstance
  private var _previousToken                : Token?

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
  
  
  init(managerDelegate: WanManagerDelegate, serverDelegate: WanServerDelegate, auth0Email: String) {
    _delegate = managerDelegate
    _serverDelegate = serverDelegate
    
    _wanServer = WanServer(delegate: serverDelegate)
    
    // try to get a logon token
    if let tokenValue = obtainLoginToken(auth0Email) {
      // got a token, try to connect
      loginToSmartLink(tokenValue: tokenValue)
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  public func openRadio(_ packet: DiscoveryPacket) {
    _wanServer?.sendConnectMessage(for: packet)
  }

  public func closeRadio(_ packet: DiscoveryPacket) {
    _wanServer?.sendDisconnectMessage(for: packet)
  }

  public func sendTestConnection(for packet: DiscoveryPacket) {
    _wanServer?.sendTestConnection(for: packet)
  }
  
  
  public func obtainLoginToken(_ auth0Email: String) -> String? {
    var canLogin = false
    var tokenValue : String? = nil
    
    // is there a saved Auth0 token which has not expired?
    if let previousToken = _previousToken, previousToken.isValidAtDate( Date()) {
      
      // YES, we can log into SmartLink, use the saved token
      canLogin = true
      tokenValue = previousToken.value
      
    } else if auth0Email != "" {
      
      // there is a saved email, use it to obtain a refresh token from Keychain
      if let refreshToken = Keychain.get(kService, account: auth0Email) {
        
        // can we get a Token Value from the Refresh Token?
        if let value = getTokenValue(from: refreshToken) {
          
          // YES, we can use the saved token to Log in
          canLogin = true
          tokenValue = value
          
        } else {
          
          // NO, the Keychain entry is no longer valid, delete it
          Keychain.delete(kService, account: auth0Email)
        }
      }
    }
    // exit if we don't have the needed token (User will need to press the Log In button)
    guard canLogin else { return nil}
    
    return canLogin ? tokenValue : nil
  }
  /// Login to SmartLink
  ///
  /// - Parameter token:                token
  ///
  public func loginToSmartLink(tokenValue: String) {
    
    if let image = getUserImage(tokenValue: tokenValue) {
      _delegate!.smartLinkImage = image
    } else {
      _log.logMessage("Error retrieving Logon image", .error, #function, #file, #line)
    }
    // connect with pinger to avoid the SmartLink server to disconnect if we take too long (>30s)
    // to select and connect to a radio
    if _wanServer!.connectToSmartLinkServer(appName: Logger.kAppName, platform: kPlatform, token: tokenValue, ping: true) {
      _log.logMessage("SmartLink Server log in: SUCCEEDED", .debug, #function, #file, #line)
      _delegate?.wasLoggedIn = true
      
    } else {
      // log the error
      _log.logMessage("SmartLink Server log in: FAILED", .warning, #function, #file, #line)
      _delegate?.wasLoggedIn = false
    }
  }
  /// Logout of SmartLink
  ///
  public func logoutOfSmartLink() {
    _wanServer?.disconnectFromSmartLinkServer()
    _wanServer = nil
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
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
      
      _log.logMessage("Error retrieving id token token: \(error?.localizedDescription ?? "")", .error, #function, #file, #line)
      return nil
    }
    
    // is there a Token?
    if let token = parseTokenResponse(data: data) {
      do {
        
        let jwt = try decode(jwt: token)
        
        // validate id token; see https://auth0.com/docs/tokens/id-token#validate-an-id-token
        if !isJWTValid(jwt) {
          // log the error
          _log.logMessage("JWT token not valid", .error, #function, #file, #line)
          
          return nil
        }
        
      } catch let error as NSError {
        // log the error
        _log.logMessage("Error decoding JWT token: \(error.localizedDescription)", .error, #function, #file, #line)
        
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
  // MARK: - Auth0 controller Delegate methods
  
  /// Set the id and refresh token
  ///
  /// - Parameters:
  ///   - idToken:        id Token string
  ///   - refreshToken:   refresh Token string
  ///
  func setTokens(idToken: String, refreshToken: String) {
    var expireDate = Date()
    
    do {
      
      // try to get the JSON Web Token
      let jwt = try decode(jwt: idToken)
      
      // validate id token; see https://auth0.com/docs/tokens/id-token#validate-an-id-token
      if !isJWTValid(jwt) {
        
        _log.logMessage("JWT token not valid", .error, #function, #file, #line)
        
        return
      }
      // save the Log On email (if any)
      var claim = jwt.claim(name: kClaimEmail)
      if let email = claim.string {
        
        // YES, save in user defaults
        _delegate?.auth0Email = email
        
        // save refresh token in keychain
        Keychain.set(kService, account: email, data: refreshToken)
      }
      
      // save the Log On picture (if any)
      claim = jwt.claim(name: kClaimPicture)
      if let gravatar = claim.string, let url = URL(string: gravatar) {
        // get the image
        if let data = try? Data(contentsOf: url) {
          _delegate!.smartLinkImage = NSImage(data: data)
        }
      }
      // get the expiry date (if any)
      if let expiresAt = jwt.expiresAt {
        expireDate = expiresAt
      }
      
    } catch let error as NSError {
      
      // log the error & exit
      _log.logMessage("Error decoding JWT token: \(error.localizedDescription)", .error, #function, #file, #line)
      
      return
    }
    // save id token with expiry date
    _previousToken = Token(value: idToken, expiresAt: expireDate)
    
    // connect to SmartLink server
    loginToSmartLink(tokenValue: idToken)
    
    _delegate?.wasLoggedIn = true
    
    _delegate?.openRadioPicker()
  }
}
