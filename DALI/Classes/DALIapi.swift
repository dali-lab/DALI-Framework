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
	public static var config: DALIConfig {
		if self.unProtConfig == nil {
			fatalError("DALIapi: Config missing! You are required to have a configuration\n" +
					   "Run:\nlet config = DALIConfig(dict: NSDictionary(contentsOfFile: filePath))\n" +
					   "DALIapi.configure(config)\n" +
					   "before you use it")
		}
		return unProtConfig!
	}
	internal static var socket: SocketIOClient!
	private static var socketConnected: Bool = false
	
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
		socket = SocketIOClient(socketURL: URL(string: config.serverURL)!)
		
		if config.enableSockets {
			self.enableSockets()
		}
	}
	
	internal static func enableSockets() {
//		if !socketConnected { socket.connect() }
		socketConnected = true
		
		NotificationCenter.default.addObserver(self, selector: #selector(self.goingForeground), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(self.goingBackground), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
	}
	
	internal static func disableSockets() {
//		socket.disconnect()
		socketConnected = false
		
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
		
		if DALIEvent.updatesSocket != nil {
			DALIEvent.updatesSocket.disconnect()
		}
	}
	
	@objc internal static func goingBackground() {
		
		if config.socketAutoSwitching {
//			if socketConnected { socket.disconnect() }
			if DALIEvent.updatesSocket != nil {
				DALIEvent.updatesSocket.disconnect()
			}
			socketConnected = false
		}
	}
	
	@objc internal static func goingForeground() {
		if config.socketAutoSwitching {
//			if !socketConnected { socket.connect() }
			if DALIEvent.updatesSocket != nil {
				DALIEvent.updatesSocket.connect()
			}
			socketConnected = true
		}
	}
	
	/// Signs in on the server using Google Signin provided server auth code
	public static func signin(authCode: String, done: @escaping (Bool, DALIError.General?) -> Void) {
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
	
	/// Signs in on the server using access and refresh tokens provided by Google Signin. Will not sign in if already signed in
	public static func signin(accessToken: String, refreshToken: String, done: @escaping (Bool, DALIError.General?) -> Void) {
		self.signin(accessToken: accessToken, refreshToken: refreshToken, forced: false, done: done)
	}
	
	/// Signs in on the server using access and refresh tokens provided by Google Signin
	public static func signin(accessToken: String, refreshToken: String, forced: Bool, done: @escaping (Bool, DALIError.General?) -> Void) {
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
				
				guard let user = DALIMember.parse(userObj) else {
					done(false, DALIError.General.UnexpectedResponse)
					return
				}
				
				self.unProtConfig.token = token
				self.unProtConfig.member = user
				
				done(true, nil)
			}
		} catch {
			done(false, nil)
		}
	}
	
	/// Signs out of your account on the API
	public static func signOut() {
		config.token = nil
	}
	
	/**
	Sends a notification to EVERY device with the given tag set to true
	*/
	public static func sendSimpleNotification(with title: String, and subtitle: String, to tag: String,callback: @escaping (Bool, DALIError.General?) -> Void) {
		
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
			callback(false, DALIError.General.InvalidJSON(text: dict.description, jsonError: NSError(domain: "some", code: ErrorInvalidJSON, userInfo: nil)))
		}
	}
	
	internal static func assertUser(funcName: String) {
		if (DALIapi.config.member == nil) {
			fatalError("API key programs may not modify location records! Don't use \(funcName) if you configure with an API key. If you are getting this error and you do not configure using an API key, consult John Kotz")
		}
	}
}
