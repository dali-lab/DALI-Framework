//
//  daliAPI.swift
//  
//
//  Created by John Kotz on 7/23/17.
//
//

import UIKit
import SwiftyJSON
import SocketIO

/**
Static class to configure and handle general requests for the DALI api framework
*/
public class DALIapi {
	private static var unProtConfig: DALIConfig!
	/// The current configuration being used by the framework
	public static var config: DALIConfig {
		if self.unProtConfig == nil {
			fatalError("DALIapi: Config missing! You are required to have a configuration\n" +
					   "Run:\nlet config = DALIConfig(dict: NSDictionary(contentsOfFile: filePath))\n" +
					   "DALIapi.configure(config)\n" +
					   "before you use it")
		}
		return unProtConfig!
	}
	
	internal static let socketManager = SocketManager(socketURL: DALIapi.config.serverURLobject)
	
	/// Defines if the user is signed in
    public static var isSignedIn: Bool {
        return config.member != nil
    }
	
	/**
	A callback reporting either success or failure in the requested action
	
	- parameter success: Flag indicating success in the action
	- parameter error: Error encountered (if any)
	*/
	public typealias SuccessCallback = (_ success: Bool, _ error: DALIError.General?) -> Void
	
	/**
	Configures the entire framework
	
	NOTE: Make sure to run this configure method before using anything on the API
	*/
	public static func configure(config: DALIConfig) {
		self.unProtConfig = config
		
		if config.enableSockets {
			enableSockets()
		}
	}
	
	/// Enables the use of sockets
	internal static func enableSockets() {
		
		NotificationCenter.default.addObserver(self, selector: #selector(self.goingForeground), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(self.goingBackground), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
	}
	
	/// Disables all sockets used by the API
	internal static func disableSockets() {
		
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
		
		if let eventSocket = DALIEvent.updatesSocket, eventSocket.status != .disconnected {
			eventSocket.disconnect()
		}
		if let locationSocket = DALILocation.updatingSocket, locationSocket.status != .disconnected {
			locationSocket.disconnect()
		}
		if let lightsSocket = DALILights.updatingSocket, lightsSocket.status != .disconnected {
			lightsSocket.disconnect()
		}
		if let socket = DALIFood.socket, socket.status != .disconnected {
			socket.disconnect()
		}
	}
	
	/// Called when switching to background mode, this function will close sockets of autoswitching is enabled
	@objc internal static func goingBackground() {
		if config.socketAutoSwitching {
			if let eventSocket = DALIEvent.updatesSocket, eventSocket.status != .disconnected {
				eventSocket.disconnect()
			}
			if let locationSocket = DALILocation.updatingSocket, locationSocket.status != .disconnected {
				locationSocket.disconnect()
			}
			if let updatingSocket = DALILights.updatingSocket, updatingSocket.status != .disconnected {
				updatingSocket.disconnect()
			}
			if let socket = DALIFood.socket, socket.status != .disconnected {
				socket.disconnect()
			}
		}
	}
	
	/// Called when switching to forground mode, this function will reconnect sockets of autoswitching is enabled
	@objc internal static func goingForeground() {
		if config.socketAutoSwitching {
			if let eventSocket = DALIEvent.updatesSocket, eventSocket.status == .disconnected {
				eventSocket.connect()
			}
			if let locationSocket = DALILocation.updatingSocket, locationSocket.status == .disconnected {
				locationSocket.connect()
			}
			if let updatingSocket = DALILights.updatingSocket, updatingSocket.status == .disconnected {
				updatingSocket.connect()
			}
			if let socket = DALIFood.socket, socket.status == .disconnected {
				socket.connect()
			}
		}
	}
	
	/**
	Signs in on the server using Google Signin provided server auth code
	
	- parameter authCode: The authCode provided by Google signin
	- parameter done: Function called when signin is complete
	- parameter success: The signin completed correctly
	- parameter error: The error, if any, encountered
	*/
	public static func signin(authCode: String, done: @escaping (_ success: Bool, _ error: DALIError.General?) -> Void) {
		// One way or the other are we already authenticated
		if (config.token != nil || config.apiKey != nil) {
			done(true, nil)
			return
		}
		
		ServerCommunicator.get(url: "\(config.serverURL)/api/auth/google/callback?code=\(authCode)") { (json, code, error) in
			if let error = error {
				switch error {
				case .InvalidJSON(text: let text, jsonError: let jsonError):
					print("DALIapi: Got error '\(text ?? "")' signing in: \(jsonError)")
					done(false, error)
					break
					
				default:
					done(false, error)
					break
				}
				
				return
			}
			
			guard let json = json, let token = json["token"].string else {
				done(false, DALIError.General.UnexpectedResponse)
				return
			}
			
			let userObj = json["user"]
			
			guard let member = DALIMember.parse(userObj) else {
				done(false, DALIError.General.UnexpectedResponse)
				return
			}
			
			self.unProtConfig.token = token
			self.unProtConfig.member = member
			
			done(true, nil)
		}
	}
	
	/**
	Signs in on the server using access and refresh tokens provided by Google Signin. Will not sign in if already signed in
	
	- parameter accessToken: The access token provided by Google signin
	- parameter refreshToken: The refresh token from Google siginin
	- parameter done: Function called when signin is complete
	- parameter success: The signin completed correctly
	- parameter error: The error, if any, encountered
	*/
	public static func signin(accessToken: String, refreshToken: String, done: @escaping (_ success: Bool, _ error: DALIError.General?) -> Void) {
		self.signin(accessToken: accessToken, refreshToken: refreshToken, forced: false, done: done)
	}
	
	/**
	Signs in on the server using access and refresh tokens provided by Google Signin
	
	- parameter accessToken: The access token provided by Google signin
	- parameter refreshToken: The refresh token from Google siginin
	- parameter forced: Flag forces signin even if there is already a token avialable
	- parameter done: Function called when signin is complete
	- parameter success: The signin completed correctly
	- parameter error: The error, if any, encountered
	*/
	public static func signin(accessToken: String, refreshToken: String, forced: Bool, done: @escaping (_ success: Bool, _ error: DALIError.General?) -> Void) {
		// One way or the other are we already authenticated
		if ((config.token != nil || config.apiKey != nil) && !forced) {
			done(true, nil)
			return
		}
		
		let package = [
			"access_token": accessToken,
			"refresh_token": refreshToken
		]
		
		
		do {
			try ServerCommunicator.post(url: "\(config.serverURL)/api/signin", json: JSON(package)) { success, json, error in
				if let error = error {
					done(false, error)
					return
				}
				
				guard let json = json?.dictionary, let token = json["token"]?.string, let userObj = json["user"] else {
					done(false, DALIError.General.UnexpectedResponse)
					return
				}
				
				guard let member = DALIMember.parse(userObj) else {
					done(false, DALIError.General.UnexpectedResponse)
					return
				}
				
				self.unProtConfig.token = token
				self.unProtConfig.member = member
				
				done(true, nil)
			}
		} catch {
			done(false, nil)
		}
	}

	/**
	Silently updates the current member object from the server
	
	- parameter callback: A function to be called when the opperation is complete
	- parameter member: The updated memeber object
	*/
	public static func silentMemberUpdate(callback: @escaping (_ member: DALIMember?) -> Void) {
		ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/users/me") { (data, code, error) in
			guard let data = data, let member = DALIMember.parse(data) else {
				callback(nil)
				return
			}
			self.unProtConfig.member = member
			
			callback(member)
		}
	}
	
	/// Signs out of your account on the API
	public static func signOut() {
		config.token = nil
		config.member = nil
	}
	
	/**
	Sends a notification to EVERY device with the given tag set to true
	
	- parameter title: The title of the notification
	- parameter subtitle: The main message to be sent
	- parameter tag: The tag that OneSignal will use to identify recipient devices
	- parameter callback: The function that iwll be called when the process is done
	- parameter success: The notification was sent correctly
	- parameter error: The error, if any, encountered
	*/
	public static func sendSimpleNotification(with title: String, and subtitle: String, to tag: String, callback: @escaping (_ success: Bool, _ error: DALIError.General?) -> Void) {
		
		let dict: [String: Any] = [
			"title": title,
			"subtitle": subtitle,
			"tag": tag
		]
		
		do {
			try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/notify", json: JSON(dict), callback: { (success, data, error) in
				callback(success, error)
			})
		}catch {
			callback(false, DALIError.General.InvalidJSON(text: dict.description, jsonError: NSError(domain: "some", code: SwiftyJSONError.invalidJSON.rawValue, userInfo: nil)))
		}
	}
	
	/// Asserts that a member is signed in
	internal static func assertUser(funcName: String) {
		if (DALIapi.config.member == nil) {
			fatalError("API key programs may not modify location records! Don't use \(funcName) if you configure with an API key. If you are getting this error and you do not configure using an API key, consult John Kotz")
		}
	}
}
