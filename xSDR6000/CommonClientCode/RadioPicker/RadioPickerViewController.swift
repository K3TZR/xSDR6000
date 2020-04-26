//
//  RadioPickerViewController.swift
//  CommonCode
//
//  Created by Mario Illgen on 08.02.18.
//  Copyright © 2018 Mario Illgen. All rights reserved.
//

import Cocoa
import SwiftyUserDefaults
import xLib6000

public struct Token {

  var value         : String
  var expiresAt     : Date

  public func isValidAtDate(_ date: Date) -> Bool {
    return (date < self.expiresAt)
  }
}

// --------------------------------------------------------------------------------
// MARK: - RadioPicker Delegate protocol
// --------------------------------------------------------------------------------

protocol RadioPickerDelegate             : class {
  
  var token: Token? {get set}

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

final class RadioPickerViewController    : NSViewController, NSTableViewDelegate, NSTableViewDataSource, Auth0ControllerDelegate, WanServerDelegate {
  
  static let kServiceName                   = ".oauth-token"
  static let testTimeout                    : TimeInterval = 0.1

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  @IBOutlet private var _radioTableView     : NSTableView!                  // table of Radios
  @IBOutlet private var _selectButton       : NSButton!                     // Connect / Disconnect
  @IBOutlet private weak var _gravatarView  : NSImageView!
  @IBOutlet private weak var _nameLabel     : NSTextField!
  @IBOutlet private weak var _callLabel     : NSTextField!
  @IBOutlet private weak var _loginButton   : NSButton!
  @IBOutlet private weak var _testIndicator : NSButton!
  @IBOutlet private weak var _testButton    : NSButton!
  
  private var _api                          = Api.sharedInstance
  private var _discoveredRadios             = [DiscoveryPacket]()           // Radios discovered
  private let _log                          = Logger.sharedInstance
  private var _auth0ViewController          : Auth0ViewController?
  private weak var _delegate                : RadioPickerDelegate? {
    return representedObject as? RadioPickerDelegate
  }
  private var _discoveryPacket              : DiscoveryPacket?
  private var _wanServer                    : WanServer?
//  private var _parentVc                     : NSViewController!

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
  // MARK: - Overriden methods
  
  /// the View has loaded
  ///
  override func viewDidLoad() {
    super.viewDidLoad()
    
    var idToken = ""
    var canLogIn = false
    
    #if XDEBUG
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
    #endif
    
    // allow the User to double-click the desired Radio
    _radioTableView.doubleAction = #selector(RadioPickerViewController.selectButton(_:))
    
    _selectButton.title = kConnectTitle
    _loginButton.title = kLoginTitle
    _nameLabel.stringValue = ""
    _callLabel.stringValue = ""
    _testIndicator.boolState = false

    // TODO: put this on a background queue??
    // check if we were logged in into Auth0, try to get a token

    if Defaults[.smartLinkWasLoggedIn] {
      
      // is there a saved Auth0 token which has not expired?
      if let previousIdToken = _delegate?.token, previousIdToken.isValidAtDate( Date()) {
        
        // YES, we can log into SmartLink, use the saved token
        canLogIn = true
        idToken = previousIdToken.value
      
      } else if Defaults[.smartLinkAuth0Email] != "" {
              
        // there is a saved email, use it to obtain a refresh token from Keychain
        if let refreshToken = Keychain.get(kService, account: Defaults[.smartLinkAuth0Email]) {
          
          // can we get an Id Token from the Refresh Token?
          if let refreshedIdToken = getIdToken(from: refreshToken) {
            
            // YES, we can use the saved token to Log in
            canLogIn = true
            idToken = refreshedIdToken
            
          } else {
            
            // NO, the refresh token and email are no longer valid, delete them
            Defaults[.smartLinkAuth0Email] = ""
            Keychain.delete(kService, account: Defaults[.smartLinkAuth0Email])

            canLogIn = false
            idToken = ""
          }
        } else {
          
          // no refresh token in Keychain
          canLogIn = false
          idToken = ""
        }
      } else {
        
        // no saved email, user must log in
        canLogIn = false
        idToken = ""
      }
    }
    // exit if we don't have the needed token (User will need to press the Log In button)
    guard canLogIn else { return }
    
    // we have the token, get the User image (gravatar)
    do {
      
      // try to get the JSON Web Token
      let jwt = try decode(jwt: idToken)
      
      // get the Log On image (if any) from the token
      let claim = jwt.claim(name: kClaimPicture)
      if let gravatar = claim.string, let url = URL(string: gravatar) {
        
        setLogOnImage(from: url)
      }
      
    } catch let error as NSError {
      
      // log the error
      _log.logMessage("Error decoding JWT token: \(error.localizedDescription)", .error, #function, #file, #line)
    }
    
    // connect to the SmartLink server (Log in)
    connectWanServer(token: idToken)
    
    // change the button title
    _loginButton.title = kLogoutTitle
  }
  #if XDEBUG
  deinit {
    Swift.print("\(#function) - \(URL(fileURLWithPath: #file).lastPathComponent.dropLast(6))")
  }
  #endif

  // ----------------------------------------------------------------------------
  // MARK: - Action methods
  
  /// Respond to the Close button
  ///
  /// - Parameter sender:         the button
  ///
  @IBAction func closeButton(_ sender: NSButton) {
    
    dismiss(sender)
  }
  /// Respond to the Select button
  ///
  /// - Parameter:                the button
  ///
  @IBAction func selectButton( _: NSButton ) {
    
    // attempt to Connect / Disconnect the selected Radio
    connectDisconnect()
  }
  /// Respond to the Login button
  ///
  /// - Parameter _: the button
  ///
  @IBAction func loginButton(_ sender: NSButton) {
    
    // Log In / Out of SmartLink
    logInOut()
  }
  
  @IBAction func testButton(_ sender: NSButton) {
    _testIndicator.boolState = false

    _wanServer?.sendTestConnection(for: _discoveryPacket!)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
    
  /// Connect / Disconnect a Radio
  ///
  private func connectDisconnect() {
    
    guard let packet = _discoveryPacket else { return }
    guard let delegate = _delegate else { return }

    // Connect / Disconnect
    if _selectButton.title == kConnectTitle {
      
      // CONNECT
      if packet.isWan { openRadio(packet) } else { _delegate?.openRadio(packet) }
      
      // close the picker
      dismiss(self)
      
    } else {
      // DISCONNECT, RadioPicker remains open
      delegate.closeRadio(packet)
    }
  }

  /// Open a Radio & close the Picker
  ///
  private func openRadio(_ packet: DiscoveryPacket) {
    
    getAuthentification(for: packet)
    
    DispatchQueue.main.async { [weak self] in
      self?.dismiss(self)
    }
  }
  /// Start the process to get Authentifictaion for radio connection
  ///
  /// - Parameter radio: Radio to connect to
  ///
  private func getAuthentification(for packet: DiscoveryPacket) {
    
    // is a "Hole Punch" required?
    if packet.requiresHolePunch {
      
      // YES
      _wanServer?.sendConnectMessage(for: packet)
      
    } else {
      
      // NO
      _wanServer?.sendConnectMessage(for: packet)
    }
  }
  /// Login or Logout to Auth0
  ///
  private func logInOut() {
    
    if _loginButton.title == kLoginTitle {
      
      // Login to auth0
      // get an instance of Auth0 controller
      _auth0ViewController = storyboard!.instantiateController(withIdentifier: "Auth0Login") as? Auth0ViewController
      
      // make this View Controller the delegate of the Auth0 controller
      _auth0ViewController!.representedObject = self
      
      // show the Auth0 sheet
      presentAsSheet(_auth0ViewController!)

    } else {
      // logout from the actual auth0 account
      // remove refresh token from keychain and email from defaults
      
      Defaults[.smartLinkWasLoggedIn] = false
      
      if Defaults[.smartLinkAuth0Email] != "" {
        
        Keychain.delete(kService, account: Defaults[.smartLinkAuth0Email])
        Defaults[.smartLinkAuth0Email] = ""
      }
      
      // clear tableview
      _discoveredRadios.removeAll()
      reload()
      
      // disconnect with Smartlink server
      _wanServer?.disconnect()
      
      _loginButton.title = kLoginTitle
      _nameLabel.stringValue = ""
      _callLabel.stringValue = ""
      _gravatarView.image = nil
    }
  }
  /// Reload the Radio table
  ///
  private func reload() {
    
    DispatchQueue.main.async { [unowned self] in
      self._radioTableView.reloadData()
    }
  }
  /// Connect to the Wan Server
  ///
  /// - Parameter token:                token
  ///
  private func connectWanServer(token: String) {
    
    // instantiate a WanServer instance
    _wanServer = WanServer(delegate: self)
    
    // connect with pinger to avoid the SmartLink server to disconnect if we take too long (>30s)
    // to select and connect to a radio
    if _wanServer!.connect(appName: Logger.kAppName, platform: kPlatform, token: token, ping: true) {
      
      Defaults[.smartLinkWasLoggedIn] = true

    } else {
      
      Defaults[.smartLinkWasLoggedIn] = false
      // log the error
      _log.logMessage("SmartLink Server log in: FAILED", .warning, #function, #file, #line)
    }
  }
  /// Given a Refresh Token attempt to get a Token
  ///
  /// - Parameter refreshToken:         a Refresh Token
  /// - Returns:                        a Token (if any)
  ///
  private func getIdToken(from refreshToken: String) -> String? {
    
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
      
      // log the error
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
  /// Set the Log On image
  ///
  /// - Parameter url:                  the URL of the image
  ///
  private func setLogOnImage(from url: URL) {
    
    // get the image
//    let image = NSImage(contentsOf: url)
    let image = getImage(fromURL: url)
    _gravatarView.image = image
  }


  func getImage(fromURL url: URL) -> NSImage? {
      guard let data = try? Data(contentsOf: url) else { return nil }
      guard let image = NSImage(data: data) else { return nil }
      return image
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
  // MARK: - WanServer Delegate methods
  
  /// Received radio list from server
  ///
  func wanRadioListReceived(wanRadioList: [DiscoveryPacket]) {
    
    // relaod to display the updated list
    _discoveredRadios = wanRadioList
   
    for (i, _) in wanRadioList.enumerated() {
      
      wanRadioList[i].isWan = true
      Discovery.sharedInstance.processPacket(wanRadioList[i])
      
//      Swift.print("WanServer packet = \(wanRadioList[i].nickname), isWan = \(wanRadioList[i].lastSeen)")
    }
    
    reload()
  }
  /// Received user settings from server
  ///
  /// - Parameter userSettings:         a USer Setting struct
  ///
  func wanUserSettings(_ userSettings: WanUserSettings) {
    
    DispatchQueue.main.async { [unowned self] in
      
      self._nameLabel.stringValue = userSettings.firstName + " " + userSettings.lastName
      self._callLabel.stringValue = userSettings.callsign
    }
  }
  /// Radio is ready to connect
  ///
  /// - Parameters:
  ///   - handle:                       a Radio handle
  ///   - serial:                       a Radio Serial Number
  ///
  func wanRadioConnectReady(handle: String, serial: String) {
    
    DispatchQueue.main.async { [unowned self] in
      
      guard self._discoveryPacket?.serialNumber == serial, self._delegate != nil else { return }
      self._discoveryPacket!.wanHandle = handle
      // tell the delegate to connect to the selected Radio
      self._delegate!.openRadio(self._discoveryPacket!)
    }
  }
  
  /// Received Wan test results
  ///
  /// - Parameter results:            test results
  ///
  func wanTestConnectionResultsReceived(results: WanTestConnectionResults) {
    
    // was it successful?
    let success = (results.forwardTcpPortWorking == true &&
                  results.forwardUdpPortWorking == true &&
                  results.upnpTcpPortWorking == false &&
                  results.upnpUdpPortWorking == false &&
                  results.natSupportsHolePunch  == false) ||
      
                  (results.forwardTcpPortWorking == false &&
                  results.forwardUdpPortWorking == false &&
                  results.upnpTcpPortWorking == true &&
                  results.upnpUdpPortWorking == true &&
                  results.natSupportsHolePunch  == false)
    // Log the result
    _log.logMessage("SmartLink Test completed \(success ? "successfully" : "with errors")", .info, #function, #file, #line)

    DispatchQueue.main.async {
      
      // set the indicator
      self._testIndicator.boolState = success
        
      // Alert the user on failure
      if !success {
      
        let alert = NSAlert()
        alert.alertStyle = .critical
        let acc = NSTextField(frame: NSMakeRect(0, 0, 233, 125))
        acc.stringValue = results.string()
        acc.isEditable = false
        acc.drawsBackground = true
        alert.accessoryView = acc
        alert.messageText = "SmartLink Test Failure"
        alert.informativeText = "Check your SmartLink settings"
        
        alert.beginSheetModal(for: self.view.window!, completionHandler: { (response) in
          
          if response == NSApplication.ModalResponse.alertFirstButtonReturn { return }
        })
      }
    }
  }
    
  // ----------------------------------------------------------------------------
  // MARK: - Auth0 controller Delegate methods
  
  /// Close this sheet
  ///
  func closeAuth0Sheet() {
    
    if _auth0ViewController != nil { dismiss(_auth0ViewController!) }
    _auth0ViewController = nil
  }
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
        Defaults[.smartLinkAuth0Email] = email
        
        // save refresh token in keychain
        Keychain.set(kService, account: email, data: refreshToken)
      }
      
      // save the Log On picture (if any)
      claim = jwt.claim(name: kClaimPicture)
      if let gravatar = claim.string, let url = URL(string: gravatar) {
        setLogOnImage(from: url)
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
    
    // we have logged in so set the login button title
    DispatchQueue.main.async { [unowned self] in
      
      self._loginButton.title = self.kLogoutTitle
    }
    
    // save id token with expiry date
    _delegate?.token = Token(value: idToken, expiresAt: expireDate)

    // connect to SmartLink server
    connectWanServer(token: idToken)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - NSTableView DataSource methods
  
  /// Tableview numberOfRows delegate method
  ///
  /// - Parameter aTableView:     the Tableview
  /// - Returns:                  number of rows
  ///
  func numberOfRows(in aTableView: NSTableView) -> Int {
    
    // get the number of rows
//    return _discoveredRadios.count
   return  Discovery.sharedInstance.discoveredRadios.count
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - NSTableView Delegate methods
  
  /// Tableview view delegate method
  ///
  /// - Parameters:
  ///   - tableView:              the Tableview
  ///   - tableColumn:            a Tablecolumn
  ///   - row:                    the row number
  /// - Returns:                  an NSView
  ///
  func tableView( _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    
//    let version = Version(_discoveredRadios[row].firmwareVersion)
    let version = Version(Discovery.sharedInstance.discoveredRadios[row].firmwareVersion)

    let type = (Discovery.sharedInstance.discoveredRadios[row].isWan ? "SMARTLINK" : "LOCAL")
    
    // get a view for the cell
    let cellView = tableView.makeView(withIdentifier: tableColumn!.identifier, owner:self) as! NSTableCellView
    
    // set the stringValue of the cell's text field to the appropriate field
    switch tableColumn!.identifier.rawValue {
//    case "model":     cellView.textField!.stringValue = _discoveredRadios[row].model
//    case "nickname":  cellView.textField!.stringValue = _discoveredRadios[row].nickname
//    case "status":    cellView.textField!.stringValue = _discoveredRadios[row].status
//    case "stations":  cellView.textField!.stringValue = (version.isNewApi ? _discoveredRadios[row].guiClientStations : "n/a")
//    case "publicIp":  cellView.textField!.stringValue = _discoveredRadios[row].publicIp
//    case "model":     cellView.textField!.stringValue = Discovery.sharedInstance.discoveredRadios[row].model
    case "model":     cellView.textField!.stringValue = type
    case "nickname":  cellView.textField!.stringValue = Discovery.sharedInstance.discoveredRadios[row].nickname
    case "status":    cellView.textField!.stringValue = Discovery.sharedInstance.discoveredRadios[row].status
    case "stations":  cellView.textField!.stringValue = (version.isNewApi ? Discovery.sharedInstance.discoveredRadios[row].guiClientStations : "n/a")
    case "publicIp":  cellView.textField!.stringValue = Discovery.sharedInstance.discoveredRadios[row].publicIp
    default:          break
    }
    return cellView
  }
  /// Tableview selection change delegate method
  ///
  /// - Parameter notification:   notification object
  ///
  func tableViewSelectionDidChange(_ notification: Notification) {
    
    // A row must be selected to enable the buttons
    _selectButton.isEnabled = (_radioTableView.selectedRow >= 0)
    
    // is a row is selected?
    if _radioTableView.selectedRow >= 0 {

      // YES, a row is selected
      _discoveryPacket = Discovery.sharedInstance.discoveredRadios[_radioTableView.selectedRow]
      
      _testIndicator.boolState = false
      _testButton.isEnabled = Discovery.sharedInstance.discoveredRadios[_radioTableView.selectedRow].isWan

      // set the "select button" title appropriately
      var isActive = false
      if let radio = Api.sharedInstance.radio {
        isActive = ( radio.discoveryPacket == Discovery.sharedInstance.discoveredRadios[_radioTableView.selectedRow] )
      }
      _selectButton.title = (isActive ? kDisconnectTitle : kConnectTitle)
    
    } else {
      _testButton.isEnabled = false
      
      // NO, no row is selected, set the button titles
      _selectButton.title = kConnectTitle
      _testIndicator.boolState = false
    }
  }
}
