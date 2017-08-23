//
//  DALIEvent.swift
//  DALIapi
//
//  Created by John Kotz on 7/28/17.
//  Copyright © 2017 BrunchLabs. All rights reserved.
//

import Foundation
import SwiftyJSON

/**
An DALI event struct

Handles event queries

### Honestly, this is how I coded this part:

![Coding stuff](https://media.giphy.com/media/o0vwzuFwCGAFO/giphy.gif)

I'll be cleaning it up soon enough
*/
public class DALIEvent {
	
	/**
		Handles all voting communications
	*/
	public struct Voting {
		/**
			An option that a user can vote for.
		*/
		public struct Option {
			/// The title of the option
			public private(set) var name: String
			/// The number of points the option has gotten. Only accessable by admin
			public private(set) var points: Int?
			/// Identifier for the option
			public private(set) var id: String
			/// The awards this option has earned. Available only for admins or for events with results released
			public private(set) var awards: [String]?
			
			/// A boolean to indicate if the user is voting for this one
			public var isVotedFor: Bool = false
			/// An int to indicate the order (starting at 1 ending at numSelected). Only nescesary if event is ordered
			public var voteOrder: Int? = nil
			
			/// Parse the given json object
			public static func parse(object: JSON) -> Option? {
				guard let dict = object.dictionary else {
					return nil
				}
				
				let points = dict["points"]?.int
				let awards = dict["awards"]?.arrayObject as? [String]
				
				guard let name = dict["name"]?.string, let id = dict["id"]?.string else {
					return nil
				}
				
				return Option(name: name, points: points, id: id, awards: awards, isVotedFor: false, voteOrder: nil)
			}
			
			/// Get the JSON value of this option
			public func json() -> JSON {
				var data: [String:Any] = [
					"name": name,
					"id": id,
				]
				if let awards = awards {
					data["awards"] = awards
				}
				
				return JSON(data)
			}
		}
		
		
		
		/**
		The configuration for voting events
		*/
		public struct Config {
			/// The number of options a user can select when voting
			public private(set) var numSelected: Int
			/// Boolean to indicate whether the user should put their options in order
			public private(set) var ordered: Bool
		}
		
		/**
			Get the current voting event
		
			- parameter callback: Function called when done
		*/
		public static func getCurrent(callback: @escaping (DALIEvent?, DALIError.General?) -> Void) {
			ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/voting/events/current") { (object, code, error) in
				if let error = error {
					callback(nil, error)
					return
				}
				
				guard let event = DALIEvent.parse(object!) else {
					callback(nil, DALIError.General.Unfound)
					return
				}
				
				callback(event, nil)
			}
		}
		
		private static func handleEventList(object: JSON?, code: Int?, error: DALIError.General?, callback: @escaping ([DALIEvent]?, DALIError.General?) -> Void) {
			if let error = error {
				callback(nil, error)
				return
			}
			
			guard let eventObjects = object?.array else {
				callback(nil, DALIError.General.UnexpectedResponse)
				return
			}
			
			var outputArr = [DALIEvent]()
			for object in eventObjects {
				if let event = DALIEvent.parse(object) {
					outputArr.append(event)
				}
			}
			
			callback(outputArr, nil)
		}
		
		/**
			Get all events that have results released
		
			- parameter callback: Function called when done
		*/
		public static func getResults(callback: @escaping ([DALIEvent]?, DALIError.General?) -> Void) {
			ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/voting/events") { (object, code, error) in
				handleEventList(object: object, code: code, error: error, callback: callback)
			}
		}
		
		/**
			Get voting events as an admin. The signed in user __must__ be an admin, otherwise will exit immediately. Also cannot be API-key-authorized product
		
			- parameters callback: Function called when done
		*/
		public static func get(callback: @escaping ([DALIEvent]?, DALIError.General?) -> Void) {
			if DALIapi.config.member?.isAdmin ?? false {
				callback(nil, DALIError.General.Unauthorized)
				return
			}
			
			ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/voting/admin/events") { (object, code, error) in
				handleEventList(object: object, code: code, error: error, callback: callback)
			}
		}
	}
	
	public var description: String {
		var outputStr = "{\n"
		
		outputStr += "\tname: \(name)\n"
		outputStr += "\tdescription: \(desc ?? "nil")\n"
		outputStr += "\tlocation: \(location ?? "nil")\n"
		outputStr += "\tstart: \(start)\n"
		outputStr += "\tend: \(end)\n"
	
		return outputStr + "}"
	}
	
	public var votingOptions: [Voting.Option]?
	
	private var name_in: String
	private var desc_in: String?
	private var location_in: String?
	private var start_in: Date
	private var end_in: Date
	
	/// Name of the event
	public var name: String {
		get { return name_in }
		set { if self.editable { self.name_in = newValue; self.myDirty = true } }
	}
	/// Description of the event
	public var desc: String? {
		get { return desc_in }
		set { if self.editable { self.desc_in = newValue; self.myDirty = true } }
	}
	/// Location of the event
	public var location: String? {
		get { return location_in }
		set { if self.editable { self.location_in = newValue; self.myDirty = true } }
	}
	/// Start time of the event
	public var start: Date {
		get { return start_in }
		set { if self.editable { self.start_in = newValue; self.myDirty = true } }
	}
	/// Start time of the event
	public var end: Date {
		get { return end_in }
		set { if self.editable { self.end_in = newValue; self.myDirty = true } }
	}
	/// Voting is enabled for this work
	public private(set) var votingEnabled: Bool
	/// The configure the voting
	public private(set) var votingConfig: Voting.Config?
	
	fileprivate var myId: String!
	fileprivate var myDirty: Bool = true
	fileprivate var myGoogleID: String?
	
	/// The identifier used by the server
	public var id: String { return myId }
	
	/// Signifies when this event object contains information that has not been saved
	public var dirty: Bool { return myDirty }
	
	/// A flag that indicates if this event can be edited
	public var editable: Bool {
		return myGoogleID == nil
	}
	/// A flag that indicates if this event is happening now
	public var isNow: Bool {
		return self.start_in <= Date() && self.end_in >= Date()
	}
	
	/**
		Creates an event object
	
		- parameter name: The name of the event
		- parameter description: The description of the event
		- parameter location: The location of the event
		- parameter start: The start time
		- parameter end: End time
	 */
	public init(name: String, desc: String?, location: String?, start: Date, end: Date) {
		self.name_in = name
		self.desc_in = desc
		self.location_in = location
		self.start_in = start
		self.end_in = end
		self.votingEnabled = false
		self.votingConfig = nil
	}
	
	/**
		Creates the event on the server
		
		- parameter callback: A function that will be called when the job is done
	
		- throws: `DALIError.Create` error describing some error encountered
	 */
	public func create(callback: @escaping (Bool, DALIError.General?) -> Void) throws {
		if self.myId != nil {
			throw DALIError.Create.AlreadyCreated
		}
		
		var dict: [String: Any] = [
			"name": self.name,
			"start": DALIEvent.dateFormatter().string(from: self.start),
			"end": DALIEvent.dateFormatter().string(from: self.end),
			"votingEnabled": self.votingEnabled
		]
		
		if let description = self.desc {
			dict["description"] = description
		}
		if let location = self.location {
			dict["location"] = location
		}
		
		if let config = self.votingConfig {
			dict["votingConfig"] = [
				"numSelected": config.numSelected,
				"ordered": config.ordered
			] as [String : Any]
		}
		
		try ServerCommunicator.post(url: DALIapi.config.serverURL + "/api/events", json: JSON(dict)) { success, json, error in
			callback(success, error)
		}
	}
	
	/**
		Parses a given json object and returns an event object if it can find one
	
		- parameter object: The JSON object you want parsed
	
		- returns: `DALIEvent` that was found. Will be nil if object is not event
	 */
	public static func parse(_ object: JSON) -> DALIEvent? {
		guard let dict = object.dictionary else {
			return nil
		}
		
		// Get the required parts and guard
		guard let name = dict["name"]?.string,
			let startString = dict["startTime"]?.string,
			let endString = dict["endTime"]?.string else {
				return nil
		}
		
		// Get some of the optionals. No need to guard
		let description = dict["description"]?.string
		let location = dict["location"]?.string
		
		// Parse the dates
		guard let start = DALIEvent.dateFormatter().date(from: startString),
			let end: Date = DALIEvent.dateFormatter().date(from: endString) else {
				return nil
		}
		
		// Get the rest
		guard let id = dict["id"]?.string, let voting = dict["votingEnabled"]?.bool else {
			return nil
		}
		let googleID = dict["googleID"]?.string
		
		let event = DALIEvent(name: name, desc: description, location: location, start: start, end: end)
		event.myId = id
		event.myGoogleID = googleID
		event.votingEnabled = voting
		if let numSelected = dict["votingConfig"]?["numSelected"].int, let ordered = dict["votingCongig"]?["ordered"].bool {
			event.votingConfig = Voting.Config(numSelected: numSelected, ordered: ordered)
		} else if voting {
			return nil
		}
		
		return event
	}
	
	/**
		Pulls __all__ the events from the server
	
		- parameter callback: Function called when done
	 */
	public static func getAll(callback: @escaping ([DALIEvent]?, DALIError.General?) -> Void) {
		ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/events") { (json, code, error) in
			if let error = error {
				callback(nil, error)
				return
			}
			
			guard let array = json?.array else {
				callback(nil, DALIError.General.UnexpectedResponse)
				return
			}
			
			var outputArr = [DALIEvent]()
			for object in array {
				if let event = DALIEvent.parse(object) {
					outputArr.append(event)
				}
			}
			
			callback(outputArr, nil)
		}
	}
	
	/**
		Gets all upcoming events within a week from now
	
		- parameter callback: Fucntion called when done
	*/
	public static func getUpcoming(callback: @escaping ([DALIEvent]?, DALIError.General?) -> Void) {
		ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/events/week") { (json, code, error) in
			if let error = error {
				callback(nil, error)
				return
			}
			
			guard let array = json?.array else {
				callback(nil, DALIError.General.UnexpectedResponse)
				return
			}
			
			var outputArr = [DALIEvent]()
			for object in array {
				if let event = DALIEvent.parse(object) {
					outputArr.append(event)
				}
			}
			
			callback(outputArr, nil)
		}
	}
	
	/**
	Checks in the current user to whatever event is happening now
	*/
	public static func checkIn(major: Int, minor: Int, callback: @escaping (Bool, DALIError.General?) -> Void) {
		DALIapi.assertUser(funcName: "checkIn")
		let data = ["major": major, "minor": minor]
		
		do {
			try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/events/checkin", json: JSON(data)) { (success, json, error) in
				callback(success, error)
			}
		} catch {
			
		}
	}
	
	/**
	Enables checkin on the event, and gets back major and minor values to be used when advertizing
	*/
	public func enableCheckin(callback: @escaping (Bool, Int?, Int?, DALIError.General?) -> Void) {
		ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/events/\(self.id)/checkin", data: "".data(using: .utf8)!) { (success, json, error) in
			var major: Int?
			var minor: Int?
			
			if let dict = json?.dictionary {
				major = dict["major"]?.int
				minor = dict["minor"]?.int
			}
			
			callback(success, major, minor, error)
		}
	}
	
	/**
	Gets a list of members who have checked in
	*/
	public func getMembersCheckedIn(callback: @escaping ([DALIMember], DALIError.General?) -> Void) {
		ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/events/\(self.id)/checkin") { (data, code, error) in
			
			var members: [DALIMember] = []
			if let array = data?.array {
				for memberObj in array {
					if let member = DALIMember.parse(memberObj) {
						members.append(member)
					}
				}
			}
			
			callback(members, error)
		}
	}
	
	
	/**
	Get the public results for this event
	
	- parameters event: Event to get the results of
	- parameters callback: Function to be called when done
	*/
	public func getPublicResults(callback: @escaping ([Voting.Option]?, DALIError.General?) -> Void) {
		ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/voting/results/events/\(self.id)") { (object, code, error) in
			if let error = error {
				callback(nil, error)
				return
			}
			
			guard let array = object?.array else {
				callback(nil, DALIError.General.UnexpectedResponse)
				return
			}
			
			var outputArr: [Voting.Option] = []
			for optionObj in array {
				if let option = Voting.Option.parse(object: optionObj) {
					outputArr.append(option)
				}
			}
			
			self.votingOptions = outputArr
			
			callback(outputArr, nil)
		}
	}
	
	
	
	/**
	Get all the options for this event
	
	- parameter event: Event to get the options for
	- parameters callback: Function to be called when done
	*/
	public func getOptions(callback: @escaping ([Voting.Option]?, DALIError.General?) -> Void) {
		if let options = self.votingOptions {
			callback(options, nil)
		}
		
		ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/voting/events/\(self.id)") { (object, code, error) in
			if let error = error {
				callback(nil, error)
				return
			}
			
			guard let array = object?.array else {
				callback(nil, DALIError.General.UnexpectedResponse)
				return
			}
			
			var outputArr: [Voting.Option] = []
			for optionObj in array {
				if let option = Voting.Option.parse(object: optionObj) {
					outputArr.append(option)
				}
			}
			self.votingOptions = outputArr
			
			callback(outputArr, nil)
		}
	}
	
	/**
	Get the results of an event. This route will only work on admin accounts
	
	- parameters event: Event to get the events of
	- parameters callback: Function to be called when done
	*/
	public func getResults(callback: @escaping ([Voting.Option]?, DALIError.General?) -> Void) {
		ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/voting/admin/events/\(self.id)") { (object, code, error) in
			if let error = error {
				callback(nil, error)
				return
			}
			
			guard let array = object?.array else {
				callback(nil, DALIError.General.UnexpectedResponse)
				return
			}
			
			var outputArr: [Voting.Option] = []
			for optionObj in array {
				if let option = Voting.Option.parse(object: optionObj) {
					outputArr.append(option)
				}
			}
			self.votingOptions = outputArr
			
			callback(outputArr, nil)
		}
	}
	
	private static func dateFormatter() -> DateFormatter {
		let formatter = DateFormatter()
		formatter.calendar = Calendar(identifier: .iso8601)
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.timeZone = TimeZone(secondsFromGMT: 0)
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
		return formatter
	}
}
