//
//  DALILocation.swift
//  DALIapi
//
//  Created by John Kotz on 7/31/17.
//  Copyright © 2017 DALI Lab. All rights reserved.
//

import Foundation
import SwiftyJSON

/**
A static struct that contains all location updates and queries

## Example:

	DALILocation.Tim.get { (tim, error) in
	    // ...
	    if tim.inDALI {
	        // ...
	    } else if tim.inOffice {
	        // ...
	    }
	}
*/
public struct DALILocation {
	private init() {}
	
	/**
	A simple struct that holds booleans that indicate Tim's location. Use it wisely 😉
	*/
	public struct Tim {
		public private(set) static var current: Tim?
		
		/// Tim is in DALI
		public private(set) var inDALI: Bool
		/// Tim in in his office
		public private(set) var inOffice: Bool
		
		/**
		Gets the current data on Tim's Location and returns it.
		
		- parameter callback: Function to be called when the request is complete
		
		## Example:
		
			DALILocation.Tim.get { (tim, error) in 
			    if tim.inDALI {
			        // ...
			    } else if tim.inOffice {
			        // ...
			    }
			}
		*/
		public static func get(callback: @escaping (Tim?, DALIError.General?) -> Void) {
			ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/location/tim") { (object, code, error) in
				if let error = error {
					callback(nil, error)
					return
				}
				
				guard let dict = object?.dictionary, let inDALI = dict["inDALI"]?.bool, let inOffice = dict["inOffice"]?.bool else {
					callback(nil, DALIError.General.UnexpectedResponse)
					return
				}
				let tim = Tim(inDALI: inDALI, inOffice: inOffice)
				self.current = tim
				
				callback(tim, nil)
			}
		}
		
		/**
		Submit information about tim's location. Will generate an error if user is not tim
		- important: If you call this without a user will `fatalerror`
		
		- parameter inDALI: Tim is in DALI
		- parameter inOffice: Tim is in his office
		- parameter callback: Function called apon completion
		*/
		public static func submit(inDALI: Bool, inOffice: Bool, callback: @escaping (Bool, DALIError.General?) -> Void) {
			DALIapi.assertUser(funcName: "DALILocation.Tim.submit")
			
			let dict: [String: Any] = [
				"inDALI": inDALI,
				"inOffice": inOffice
			]
			
			do {
				try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)", json: JSON(dict)) { (success, response, error) in
					callback(success, error)
				}
			} catch {
				callback(false, DALIError.General.InvalidJSON(text: dict.description, jsonError: NSError(domain: "SwiftyJSON", code: ErrorInvalidJSON, userInfo: nil)))
			}
		}
	}
	
	/**
	A simple struct that handles getting a list of shared user
	*/
	public struct Shared {
		/**
		Get a list of all the people in the lab who are sharing their location
		
		- parameter callback: Function called apon completion
		*/
		public static func get(callback: @escaping ([DALIMember]?, DALIError.General?) -> Void) {
			ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/location/shared") { (object, code, error) in
				if let error = error {
					callback(nil, error)
					return
				}
				
				guard let arr = object?.array else {
					callback(nil, DALIError.General.UnexpectedResponse)
					return
				}
				
				var outputArr: [DALIMember] = []
				for obj in arr {
					guard let dict = obj.dictionary, let user = dict["user"], let member = DALIMember.parse(user) else {
						callback(nil, DALIError.General.UnexpectedResponse)
						return
					}

					outputArr.append(member)
				}
				
				callback(outputArr, nil)
			}
		}
		
		/**
		Submit the current location of the user
		- important: Do not run this on an API authenticated program. It will fatal error to protect the server!
		
		- parameter inDALI: The user is in DALI
		- parameter entering: The user is entering DALI
		- parameter callback: Function that is called when done
		*/
		public static func submit(inDALI: Bool, entering: Bool, callback: @escaping (Bool, DALIError.General?) -> Void) {
			DALIapi.assertUser(funcName: "DALILocation.submit")
			
			let dict: [String: Any] = [
				"inDALI": inDALI,
				"entering": entering,
				"sharing": DALILocation.sharing
			]
			
			do {
				try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/location/shared", json: JSON(dict)) { (success, response, error) in
					callback(success, error)
				}
			} catch {
				callback(false, DALIError.General.InvalidJSON(text: dict.description, jsonError: NSError(domain: "SwiftyJSON", code: ErrorInvalidJSON, userInfo: nil)))
			}
		}
	}
	
	/// The current user is sharing this device's location
	public static var sharing: Bool {
		get {
			return UserDefaults.standard.value(forKey: "DALIapi:sharing:\(DALIapi.config.member?.id ?? "all")") as? Bool ?? DALIapi.config.sharingDefault
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "DALIapi:sharing:\(DALIapi.config.member?.id ?? "all")")
			do {
				try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/location/shared/updatePreference", json: JSON(["sharing": newValue]), callback: { (success, object, error) in
				
			})
			} catch {
				
			}
		}
	}
}
