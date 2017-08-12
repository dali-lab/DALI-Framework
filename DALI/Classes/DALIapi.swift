//
//  daliAPI.swift
//  
//
//  Created by John Kotz on 7/23/17.
//
//

import UIKit
import SwiftyJSON

/**
Static class to configure and handle general requests the DALI api framework
 */
public class DALIapi {
	private static var unProtConfig: DALIConfig!
	internal static var config: DALIConfig {
		if self.unProtConfig == nil {
			fatalError("DALIapi: Config missing! You are required to have a configuration\n" +
					   "Run:\nlet config = DALIConfig(dict: NSDictionary(contentsOfFile: filePath))\n" +
					   "DALIapi.configure(config)\n" +
					   "before you use it")
		}
		return unProtConfig!
	}
	
	/**
	 * Configures the entire framework
	 */
	public static func configure(config: DALIConfig) {
		self.unProtConfig = config
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
			
			guard let user = DALIUser.parse(userObj) else {
				done(false, DALIError.General.UnexpectedResponse)
				return
			}
			
			self.unProtConfig.token = token
			self.unProtConfig.user = user
			
			done(true, nil)
		}
	}
	
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
				
				guard let user = DALIUser.parse(userObj) else {
					done(false, DALIError.General.UnexpectedResponse)
					return
				}
				
				self.unProtConfig.token = token
				self.unProtConfig.user = user
				
				done(true, nil)
			}
		} catch {
			done(false, nil)
		}
	}
	
	public static func signOut() {
		config.token = nil
	}
	
	internal static func assertUser(funcName: String) {
		if (DALIapi.config.user == nil) {
			fatalError("API key programs may not modify location records! Don't use \(funcName) if you configure with an API key. If you are getting this error and you do not configure using an API key, consult John Kotz")
		}
	}
}
