//
//  DALILocation.swift
//  DALIapi
//
//  Created by John Kotz on 7/31/17.
//  Copyright © 2017 DALI Lab. All rights reserved.
//

import Foundation
import SwiftyJSON
import SocketIO

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
public class DALILocation {
	internal static var sharedCallback: (([DALIMember]?, DALIError.General?) -> Void)?
	internal static var timCallback: ((Tim?, DALIError.General?) -> Void)?
	internal static var updatingSocket: SocketIOClient!
	internal static func assertSocket() {
		if updatingSocket == nil {
			updatingSocket = SocketIOClient(socketURL: URL(string: DALIapi.config.serverURL)!, config: [SocketIOClientOption.nsp("/location"), SocketIOClientOption.forcePolling(false)])
			
			updatingSocket.on("shared", callback: { (data, ack) in
				guard let arr = data[0] as? [Any] else {
					if let sharedCallback = sharedCallback {
						DispatchQueue.main.async {
							sharedCallback(nil, DALIError.General.UnexpectedResponse)
						}
					}
					return
				}
				
				var outputArr: [DALIMember] = []
				for obj in arr {
					guard let dict = obj as? [String: Any], let user = dict["user"], let member = DALIMember.parse(JSON(user)) else {
						if let sharedCallback = sharedCallback {
							DispatchQueue.main.async {
								sharedCallback(nil, DALIError.General.UnexpectedResponse)
							}
						}
						return
					}
					
					outputArr.append(member)
				}
				
				if let sharedCallback = sharedCallback {
					DispatchQueue.main.async {
						sharedCallback(outputArr, nil)
					}
				}
			})
			
			updatingSocket.on("tim", callback: { (data, ack) in
				guard let dict = data[0] as? [String: Any], let inDALI = dict["inDALI"] as? Bool, let inOffice = dict["inOffice"] as? Bool else {
					if let timCallback = timCallback {
						DispatchQueue.main.async {
							timCallback(nil, DALIError.General.UnexpectedResponse)
						}
					}
					return
				}
				
				let tim = Tim(inDALI: inDALI, inOffice: inOffice)
				Tim.current = tim
				
				if let timCallback = timCallback {
					DispatchQueue.main.async {
						timCallback(tim, nil)
					}
				}
			})
			
			updatingSocket.connect()
		}
	}
	
	/**
	A simple struct that holds booleans that indicate Tim's location. Use it wisely 😉
	*/
	public struct Tim {
		public internal(set) static var current: Tim?
		
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
					DispatchQueue.main.async {
						callback(nil, error)
					}
					return
				}
				
				guard let dict = object?.dictionary, let inDALI = dict["inDALI"]?.bool, let inOffice = dict["inOffice"]?.bool else {
					DispatchQueue.main.async {
						callback(nil, DALIError.General.UnexpectedResponse)
					}
					return
				}
				let tim = Tim(inDALI: inDALI, inOffice: inOffice)
				self.current = tim
				
				DispatchQueue.main.async {
					callback(tim, nil)
				}
			}
		}
		
		public static func observe(callback: @escaping (Tim?, DALIError.General?) -> Void) -> Observation {
			DALILocation.assertSocket()
			DALILocation.timCallback = callback
			
			return Observation(stop: {
				DALILocation.timCallback = nil
				if DALILocation.sharedCallback == nil && DALILocation.updatingSocket != nil {
					if DALILocation.updatingSocket.status != .disconnected {
						DALILocation.updatingSocket.disconnect()
					}
					DALILocation.updatingSocket = nil
				}
			}, id: "timObserver")
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
				try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/location/tim", json: JSON(dict)) { (success, response, error) in
					DispatchQueue.main.async {
						callback(success, error)
					}
				}
			} catch {
				DispatchQueue.main.async {
					callback(false, DALIError.General.InvalidJSON(text: dict.description, jsonError: NSError(domain: "SwiftyJSON", code: ErrorInvalidJSON, userInfo: nil)))
				}
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
					DispatchQueue.main.async {
						callback(nil, error)
					}
					return
				}
				
				guard let arr = object?.array else {
					DispatchQueue.main.async {
						callback(nil, DALIError.General.UnexpectedResponse)
					}
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
				
				DispatchQueue.main.async {
					callback(outputArr, nil)
				}
			}
		}
		
		public static func observe(callback: @escaping ([DALIMember]?, DALIError.General?) -> Void) -> Observation {
			DALILocation.assertSocket()
			DALILocation.sharedCallback = callback
			
			return Observation(stop: {
				DALILocation.sharedCallback = nil
				if DALILocation.timCallback == nil && DALILocation.updatingSocket != nil {
					if DALILocation.updatingSocket.status != .disconnected {
						DALILocation.updatingSocket.disconnect()
					}
					DALILocation.updatingSocket = nil
				}
			}, id: "sharedObserver")
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
					DispatchQueue.main.async {
						callback(success, error)
					}
				}
			} catch {
				DispatchQueue.main.async {
					callback(false, DALIError.General.InvalidJSON(text: dict.description, jsonError: NSError(domain: "SwiftyJSON", code: ErrorInvalidJSON, userInfo: nil)))
				}
			}
		}
	}
	
	/// The current user is sharing this device's location
	public static var sharing: Bool {
		get {
			return UserDefaults.standard.value(forKey: "DALIapi:sharing") as? Bool ?? DALIapi.config.sharingDefault
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "DALIapi:sharing")
			do {
				try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/location/shared/updatePreference", json: JSON(["sharing": newValue]), callback: { (success, object, error) in
				
			})
			} catch {
				
			}
		}
	}
}
