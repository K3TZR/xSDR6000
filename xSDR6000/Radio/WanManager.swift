//
//  WanManager.swift
//  xSDR6000
//
//  Created by Douglas Adams on 5/5/20.
//  Copyright © 2020 Douglas Adams. All rights reserved.
//

import Cocoa
import xLib6000
import JWTDecode

// --------------------------------------------------------------------------------
// MARK: - WanManager Delegate protocol
// --------------------------------------------------------------------------------

protocol WanManagerDelegate: class {
    // swiftlint:disable colon
    
    var userEmail               : String? { get set}
    var smartLinkWasLoggedIn    : Bool { get set}
    var smartLinkIsLoggedIn     : Bool { get set}
    
    func smartLinkTestResults(results: WanTestConnectionResults)
    func smartLinkConnectionReady(handle: String, serial: String)
    func smartLinkUserSettings(name: String?, call: String?)
    func smartLinkImage(image: NSImage?)
    
    func showRadioPicker()
    // swiftlint:enable colon
}

public final class WanManager: WanServerDelegate, Auth0Delegate {
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Static properties
    
    static let kServiceName             = ".oauth-token"
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private weak var _delegate          : WanManagerDelegate!
    
    private var _auth0ViewController    : Auth0ViewController?
    private let _log                    = Logger.sharedInstance.logMessage
    private var _previousIdToken        : IdToken = nil
    private var _wanServer              : WanServer?
    
    // constants
    private let kService                = AppDelegate.kAppName + kServiceName
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    init(delegate: WanManagerDelegate) {
        _delegate = delegate
        _wanServer = WanServer(delegate: self)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    /// Open a connection to the SmartLink server using existing credentials
    /// - Parameter auth0Email:     saved email (if any)
    ///
    public func smartLinkLogin(_ userEmail: String?) -> Bool {
        // is there an Id Token available?
        if let idToken = getIdToken(userEmail) {
            // YES, save the ID Token
            _previousIdToken = idToken
            
            _log("WanManager, Smartlink login: saved/refreshed ID Token found", .debug, #function, #file, #line)
            
            // try to connect
            return _wanServer!.connect(appName: AppDelegate.kAppName, platform: "macOS", idToken: idToken)
        }
        // NO, user will need to reenter Auth0 user/pwd to authenticate (i.e. obtain credentials)
        _log("WanManager, Smartlink login: saved/refreshed ID Token NOT found", .debug, #function, #file, #line)
        return false
    }
    
    /// Close the connection to the SmartLink server
    ///
    public func smartLinkLogout() {
        _delegate.smartLinkIsLoggedIn = false
        _wanServer?.disconnect()
        _wanServer = nil
    }
    
    /// Open the Auth0 Sheet
    ///
    public func presentAuth0Sheet() {
        if let window = NSApplication.shared.mainWindow {
            let auth0Storyboard = NSStoryboard(name: "RadioPicker", bundle: nil)
            _auth0ViewController = auth0Storyboard.instantiateController(withIdentifier: "Auth0Login") as? Auth0ViewController
            _auth0ViewController!.delegate = self
            window.contentViewController!.presentAsSheet(_auth0ViewController!)
        }
    }
    
    /// Open a SmartLink connection to a Radio
    /// - Parameters:
    ///   - serialNumber:       the serial number of the Radio
    ///   - holePunchPort:      the negotiated Hole Punch port number
    ///
    public func openRadio(_ serialNumber: String, holePunchPort: Int) {
        _wanServer?.sendConnectMessage(for: serialNumber, holePunchPort: holePunchPort)
    }
    
    /// Close the SmartLink connection to a Radio
    /// - Parameter serialNumber:     serial number of the Radio
    ///
    public func closeRadio(_ serialNumber: String) {
        _wanServer?.sendDisconnectMessage(for: serialNumber)
    }
    
    /// Test the connection to the SmartLink server
    /// - Parameter serialNumber:     serial number of the Radio
    ///
    public func testConnection(_ serialNumber: String) {
        _wanServer?.sendTestConnection(for: serialNumber)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Obtain an Id Token from previous credentials
    /// - Parameter userEmail:      saved email (if any)
    /// - Returns:                  an ID Token (if any)
    ///
    private func getIdToken(_ userEmail: String?) -> IdToken {
        // is there a saved Auth0 token which has not expired?
        if let previousToken = _previousIdToken, isValidIdToken(previousToken) {
            // YES, use the saved token
            return previousToken
            
        } else if userEmail != nil {
            // use it to obtain a refresh token from Keychain
            if let refreshToken = Keychain.get(kService, account: userEmail!) {
                
                // can we get an ID Token using the Refresh Token?
                if let idToken = requestIdToken(from: refreshToken) {
                    // YES,
                    return idToken
                    
                } else {
                    // NO, the Keychain entry is no longer valid, delete it
                    Keychain.delete(kService, account: userEmail!)
                }
            }
        }
        return nil
    }
    
    /// Given a Refresh Token, perform a URLRequest for an ID Token
    ///
    /// - Parameter refreshToken:     a Refresh Token
    /// - Returns:                    the Data (if created)
    ///
    private func requestIdToken(from refreshToken: String) -> IdToken {
        // build a URL Request
        let url = URL(string: "https://frtest.auth0.com/delegation")
        var urlRequest = URLRequest(url: url!)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "content-type")
        
        // create & populate the dictionary
        var dict = [String: String]()
        dict["client_id"] = Auth0ViewController.kClientId
        dict["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer"
        dict["refresh_token"] = refreshToken
        dict["target"] = Auth0ViewController.kClientId
        dict["scope"] = "openid email given_name family_name picture"
        
        // try to obtain the data
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            urlRequest.httpBody = data
            // update the URL Request and retrieve the data
            let (responseData, error) = URLSession.shared.synchronousDataTask(with: urlRequest)
            
            guard let jsonData = responseData, error == nil else {
                _log("WanManager, Error retrieving ID Token from Refresh Token: \(error?.localizedDescription ?? "")", .error, #function, #file, #line)
                return nil
            }
            do {
                // try to parse
                if let object = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                    // YES, does it have a Token?
                    if let  idToken = object["id_token"] as? String {
                        // YES, validate it
                        if isValidIdToken(idToken) { return idToken }
                        return nil  // invalid token
                    }
                }
                _log("WanManager, Unable to parse Refresh Token response", .error, #function, #file, #line)
                return nil          // unable to parse
            } catch _ {
                _log("WanManager, Unable to parse Refresh Token response", .error, #function, #file, #line)
                return nil          // parse error
            }
        } catch {
            fatalError("WanManager: failed to create JSON data")
        }
    }
    
    /// Validate an Id Token
    /// - Parameter idToken:        the Id Token
    /// - Returns:                  nil if valid, else a ValidationError
    ///
    private func isValidIdToken(_ idToken: IdToken) -> Bool {
        guard idToken != nil else { return false }
        
        do {
            // attempt to decode it
            let jwt = try decode(jwt: idToken!)
            // is it valid?
            let result = IDTokenValidation(issuer: Auth0ViewController.kAuth0Domain, audience: Auth0ViewController.kClientId).validate(jwt)
            if result == nil {
                // YES, is there an email?
                if let email = jwt.claim(name: "email").string {
                    // YES, save it
                    _delegate.userEmail = email
                }
                // is there a picture?
                if let gravatar = jwt.claim(name: "picture").string, let url = URL(string: gravatar) {
                    // YES, get the image
                    if let data = try? Data(contentsOf: url) {
                        _delegate.smartLinkImage(image: NSImage(data: data))
                    }
                }
                return true
                
            } else {
                var explanation = ""
                
                switch result {
                case .expired:                  explanation = "expired"
                case .invalidClaim(let claim):  explanation = "invalid claim - \(claim)"
                case .nonce:                    explanation = "nonce"
                case .none:                     explanation = "nil token"
                }
                _log("WanManager, SmartLink login: Id Token INVALID: \(explanation)", .error, #function, #file, #line)
                return false
            }
        } catch {
            _log("WanManager, error decoding Id Token", .error, #function, #file, #line)
            return false
        }
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
        if isValidIdToken(idToken) {
            
            // save the Refresh Token (in Keychain)
            Keychain.set(kService, account: _delegate.userEmail!, data: refreshToken)
            
            // save Id Token & note that we are logged in
            _previousIdToken = idToken
            _log("WanManager, SmartLink login: tokens received", .error, #function, #file, #line)
            
            if _wanServer!.connect(appName: AppDelegate.kAppName, platform: "macOS", idToken: idToken) {
                _delegate.smartLinkWasLoggedIn = true
                _delegate.smartLinkIsLoggedIn = true
            }
        }
    }
    
    func dismissAuth0Sheet() {
        _auth0ViewController!.dismiss(nil)
        _auth0ViewController = nil
        _log("WanManager, Auth0 view unloaded", .error, #function, #file, #line)
        
        _delegate.showRadioPicker()
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
