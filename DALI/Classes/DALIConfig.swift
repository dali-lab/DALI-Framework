//
//  HandleConfigFile.swift
//  DALIapi
//
//  Created by John Kotz on 7/28/17.
//  Copyright © 2017 DALI Lab. All rights reserved.
//

import Foundation
import SwiftyJSON

/**
Configurations for the DALIapi framework can be stored and handled using this

Example usage:

	let file = NSDictionary(dictionary: [
	    "server_url": "https://dalilab-api.herokuapp.com/"
	])
	let config = DALIConfig(dict: file)
	DALIapi.configure(config: config)
*/
open class DALIConfig {
	/// The URL to the server. This is required
	internal var serverURL: String
	/// Used to connect to the server without needing user signin
	internal var apiKey: String?
	
	/// Token. This is needed for requests when needing user signin
	internal var token_stored: String?
	internal var token: String? {
		get {
			if let token_stored = token_stored {
				return token_stored
			}else if let token = UserDefaults.standard.string(forKey: "DALIapi:token") {
				token_stored = token
				return token
			}else{
				return nil
			}
		}
		set {
			self.token_stored = newValue
			if let token = newValue {
				UserDefaults.standard.set(token, forKey: "DALIapi:token")
			}else{
				UserDefaults.standard.removeObject(forKey: "DALIapi:token")
			}
		}
	}
	
	/// The current member signed in
	internal var member_stored: DALIMember?
	internal var member: DALIMember? {
		get {
			if let member_stored = member_stored {
				return member_stored
			}else if let stored = UserDefaults.standard.data(forKey: "DALIapi:member"), let member = DALIMember.parse(JSON(stored)) {
				member_stored = member
				return member
			}
			return nil
		}
		set {
			self.member_stored = newValue
			if let data = try? newValue?.json.rawData() {
				UserDefaults.standard.set(data, forKey: "DALIapi:member")
			}else if newValue == nil {
				UserDefaults.standard.removeObject(forKey: "DALIapi:member")
			}
		}
	}
	
	/// A default value for the sharing preference
	public var sharingDefault = true
	private var enableSockets_internal = false
	public var enableSockets: Bool {
		get { return enableSockets_internal }
		set { enableSockets_internal = newValue; if newValue { DALIapi.enableSockets() } else { DALIapi.disableSockets() } }
	}
	public var socketAutoSwitching = true
	
	/**
	Creates a DALIConfig object

	- parameter dict: A dictionary containing server_url
	*/
	public convenience init(dict: NSDictionary) {
		guard let serverURL = dict["server_url"] as? String else {
			fatalError("DALIConfig: Server URL Missing! Make sure server_url is in your config dictionary")
		}
		
		self.init(serverURL: serverURL, apiKey: dict["api_key"] as? String, enableSockets: dict["enableSockets"] as? Bool)
	}
	
	public convenience init(serverURL: String, apiKey: String) {
		self.init(serverURL: serverURL, apiKey: apiKey, enableSockets: nil)
	}
	
	public convenience init(serverURL: String) {
		self.init(serverURL: serverURL, apiKey: nil, enableSockets: nil)
	}
	
	public convenience init(serverURL: String, enableSockets: Bool) {
		self.init(serverURL: serverURL, apiKey: nil, enableSockets: enableSockets)
	}
	
	public init(serverURL: String, apiKey: String?, enableSockets: Bool?) {
		self.serverURL = serverURL
		self.apiKey = apiKey
		
		if self.serverURL.characters.last == "/" {
			self.serverURL = self.serverURL.substring(to: self.serverURL.index(before: self.serverURL.endIndex))
		}
		
		self.enableSockets_internal = enableSockets ?? false
	}
}
