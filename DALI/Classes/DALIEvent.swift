//
//  DALIEvent.swift
//  DALIapi
//
//  Created by John Kotz on 7/28/17.
//  Copyright © 2017 DALI Lab. All rights reserved.
//

import Foundation
import SwiftyJSON
import SocketIO
import EmitterKit
import FutureKit

/**
A DALI event
*/
public class DALIEvent {
	// MARK: - Properties
	private var name_in: String
	private var description_in: String?
	private var location_in: String?
	private var start_in: Date
	private var end_in: Date
	
	/// Name of the event
	public var name: String {
		get { return name_in }
		set { if self.editable { self.name_in = newValue; self.dict?["name"] = JSON(newValue); self.dirty = true } }
	}
	/// Description of the event
	public var description: String? {
		get { return description_in }
		set { if self.editable { self.description_in = newValue; if let newValue = newValue { self.dict?["description"] = JSON(newValue) } else { self.dict?.removeValue(forKey: "description") }; self.dirty = true } }
	}
	/// Location of the event
	public var location: String? {
		get { return location_in }
		set { if self.editable { self.location_in = newValue; if let newValue = newValue { self.dict?["location"] = JSON(newValue) } else { self.dict?.removeValue(forKey: "location") }; self.dirty = true } }
	}
	/// Start time of the event
	public var start: Date {
		get { return start_in }
		set { if self.editable { self.start_in = newValue; self.dict?["start"] = JSON(newValue); self.dirty = true } }
	}
	/// Start time of the event
	public var end: Date {
		get { return end_in }
		set { if self.editable { self.end_in = newValue; self.dict?["end"] = JSON(newValue); self.dirty = true } }
	}
	
	fileprivate var googleID: String?
	
	/// The identifier used by the server
	public private(set) var id: String!
	
	/// Signifies when this event object contains information that has not been saved
	public private(set) var dirty: Bool
	
	/// A flag that indicates if this event can be edited
	public var editable: Bool {
		return googleID == nil
	}
	/// A flag that indicates if this event is happening now
	public var isNow: Bool {
		return self.start_in <= Date() && self.end_in >= Date()
	}
	/// The dictionary data that was parsed to this event
	internal var dict: [String: JSON]?
	
	
	// MARK: - Subclasses
	
	/**
		Handles all voting communications
	*/
	public class VotingEvent: DALIEvent {
		// MARK: - Properties
		/// The configure the voting
		public private(set) var config: Config
		/// The options connected to the event
		public private(set) var options: [Option]?
		/// Voting results have been released
		public private(set) var resultsReleased: Bool
		
		// MARK: - Structures
		
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
			public var awards: [String]?
			
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
			
			/// Get the JSON value of this config
			public func json() -> JSON {
				return JSON([ "numSelected": numSelected, "ordered": ordered ])
			}
		}
		
		// MARK: Initialization Methods
		
		/**
		Create a new voting event with all the given information
		*/
		init(name: String, description: String?, location: String?, start: Date, end: Date, votingConfig config: Config, options: [Option]?, resultsReleased: Bool) {
			self.config = config
			self.options = options
			self.resultsReleased = resultsReleased
			
			super.init(name: name, description: description, location: location, start: start, end: end)
		}
		
		/**
		Converts the event into a voting event
		*/
		init(event: DALIEvent, votingConfig config: Config, options: [Option]?, resultsReleased: Bool) {
			self.config = config
			self.options = options
			self.resultsReleased = resultsReleased
			
			super.init(name: event.name_in, description: event.description_in, location: event.description_in, start: event.start_in, end: event.end_in)
			
			self.dict = event.dict
			self.id = event.id
			self.googleID = event.googleID
			self.dirty = event.dirty
			
			self.dict?["votingConfig"] = config.json()
			self.dict?["votingResultsReleased"] = JSON(resultsReleased)
			self.dict?["votingEnabled"] = JSON(true)
		}
		
		/**
		Try to extract a voting event from the event's data.
		
		NOTE: This is a fallable initializer, meaning it may return null
		
		- parameter event: The DALIEvent to attempt to cast into a VotingEvent
		*/
		convenience init?(event: DALIEvent) {
			guard let dict = event.dict, let resultsReleased = dict["votingResultsReleased"]?.bool else {
				return nil
			}
			
			guard let configDict = dict["votingConfig"]?.dictionary, let numSelected = configDict["numSelected"]?.int, let ordered = configDict["ordered"]?.bool else {
				return nil
			}
			
			let config = Config(numSelected: numSelected, ordered: ordered)
			
			self.init(event: event, votingConfig: config, options: nil, resultsReleased: resultsReleased)
		}
		
		// MARK: JSON Methods
		
		/**
		Converts the data stored in the event into a JSON format that the API will understand
		
		- returns: JSON data describing the event
		*/
		public override func json() -> JSON {
			if let dict = self.dict {
				return JSON(dict)
			}
			
			let dict: [String: Any?] = [
				"name": self.name_in,
				"startTime": DALIEvent.dateFormatter().string(from: self.start_in),
				"endTime": DALIEvent.dateFormatter().string(from: self.end_in),
				"description": self.description,
				"id": self.id,
				"votingEnabled": true,
				"votingResultsReleased": resultsReleased,
				"votingConfig": config.json(),
				"googleID": self.googleID,
			]
			
			self.dict = JSON(dict).dictionary
			
			return JSON(dict)
		}
		
		/**
		Parses a JSON object. May return nil if this is not a voting event or if it fails
		
		- parameter object: The JSON object to parse
		*/
		public override class func parse(_ object: JSON) -> VotingEvent? {
			return super.parse(object) as? VotingEvent
		}
		
		// MARK: Public Methods
		
		/**
		Get if the current device and user have already voted for this event
		
		- parameter callback: Function called when done
		- parameter haveVoted: Flag expressing if the user and device has voted already (default false)
		- parameter error: The error encountered, if any
		*/
		public func haveVoted() -> Future<Bool> {
			guard let id = self.id else {
                return Future(fail: DALIError.General.BadRequest)
			}
			
            return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/voting/public/\(id)/hasVoted").onSuccess { (response) -> Bool in
                guard let dict = response.json?.dictionary, let haveVoted = dict["voted"]?.bool else {
                    throw response.assertedError
                }
                return haveVoted
            }
		}
		
		/**
		Get the public results for this event
		
		- parameters event: Event to get the results of
		- parameters callback: Function to be called when done
		*/
		public func getResults() -> Future<[Option]> {
			guard let id = self.id else {
				return Future(fail: DALIError.General.BadRequest)
			}
			
            return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/voting/public/\(id)/results").onSuccess { (response) -> [Option] in
                guard let array = response.json?.array else {
                    throw response.assertedError
                }
                
                self.options = array.compactMap({ (json) -> Option? in
                    return Option.parse(object: json)
                })
                return self.options!
            }
		}
		
		/**
		Get all the options for this event
		
		- parameter event: Event to get the options for
		- parameters callback: Function to be called when done
		*/
        public func getOptions() -> Future<[Option]> {
            let promise = Promise<[Option]>()
			if let options = self.options {
				promise.completeWithSuccess(options)
			}
			
			guard let id = self.id else {
				return promise.futureWithFailure(error: DALIError.General.BadRequest)
			}
			
           _ = ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/voting/public/\(id)").onSuccess { (response) in
                guard let array = response.json?.array else {
                    promise.completeWithFail(response.assertedError)
                    return
                }
                
                self.options = array.compactMap({ (json) -> Option? in
                    return Option.parse(object: json)
                })
                promise.completeWithSuccess(self.options!)
            }
            
            return promise.future
		}
		
		/**
		Submit the given options as a vote
		
		- parameter options: The options to be submitted. If the voting event is ordered then they need to be in 1st, 2nd, 3rd, ..., nth choice order
		- parameter callback: Function to be called when done
		*/
		public func submitVote(options: [Option]) -> Future<Void> {
			var optionsData: [[String: Any]] = []
			
			for option in options {
				if let storedOptions = self.options, storedOptions.contains(where: { (storedOption) -> Bool in return storedOption.id == option.id }) {
					optionsData.append([
						"id": option.id,
						"name": option.name
						])
				} else {
					// TODO: Have an error
				}
			}
			
			guard let id = self.id else {
				return Future(fail: DALIError.General.BadRequest)
			}
			
			do {
                return try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/voting/public/\(id)", json: JSON(optionsData)).onSuccess(block: { (response) in
                    if !response.success {
                        throw response.assertedError
                    }
                })
			}catch {
				return Future(fail: error)
			}
		}
		
		// ===================== Admin only methods ======================
		// MARK: Admin Methods
		
		/**
		Save the awards given to the given options
		
		![Admin only](http://icons.iconarchive.com/icons/graphicloads/flat-finance/64/lock-icon.png)
		
		- parameter options: The options to save
		- parameter callback: Function called when done
		*/
		public func saveResults(options: [Option]) -> Future<Void> {
			guard DALIapi.config.member?.isAdmin ?? false else {
				return Future(fail: DALIError.General.Unauthorized)
			}
            guard let id = self.id else {
                return Future(fail: DALIError.General.BadRequest)
            }
			
            let optionsData = options.map { (option) -> [String:Any] in
                return ["id": option.id, "awards": option.awards ?? []]
            }
			
			do {
                return try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/voting/admin/\(id)/results", json: JSON(optionsData)).onSuccess(block: { (response) in
                    if !response.success {
                        throw response.assertedError
                    }
                })
			} catch {
				return Future(fail: error)
			}
		}
		
		/**
		Get the results of an event.
		
		![Admin only](http://icons.iconarchive.com/icons/graphicloads/flat-finance/64/lock-icon.png)
		
		- parameter event: Event to get the events of
		- parameter callback: Function to be called when done
		- parameter results: The results requested
		- parameter error: Error encountered (if any)
		*/
		public func getUnreleasedResults() -> Future<[Option]> {
            guard DALIapi.config.member?.isAdmin ?? false else {
				return Future(fail: DALIError.General.Unauthorized)
			}
			
			guard let id = self.id else {
				return Future(fail: DALIError.General.BadRequest)
			}
			
            return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/voting/admin/\(id)").onSuccess { (response) -> [Option] in
                guard let array = response.json?.array else {
                    throw response.assertedError
                }
                
                self.options = array.compactMap({ (json) -> Option? in
                    return Option.parse(object: json)
                })
                return self.options!
            }
		}
		
		/**
		Releases the results
		
		![Admin only](http://icons.iconarchive.com/icons/graphicloads/flat-finance/64/lock-icon.png)
		
		- parameter callback: Function called when done
		*/
		public func release() -> Future<Void> {
			if !(DALIapi.config.member?.isAdmin ?? false) {
				return Future(fail: DALIError.General.Unauthorized)
			}
			
			guard let id = self.id else {
				return Future(fail: DALIError.General.BadRequest)
			}
			
            return ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/voting/admin/\(id)", data: "".data(using: .utf8)!).onSuccess { (response) in
                if response.success {
                    self.resultsReleased = true
                    self.dict?["votingResultsReleased"] = JSON(true)
                } else {
                    throw response.assertedError
                }
            }
		}
		
		/**
		Adds an option to the event
		
		![Admin only](http://icons.iconarchive.com/icons/graphicloads/flat-finance/64/lock-icon.png)
		
		- parameter option: The option to be added
		- parameter callback: Function called when done
		*/
		public func addOption(option: String) -> Future<Void> {
			guard DALIapi.config.member?.isAdmin ?? false else {
				return Future(fail: DALIError.General.Unauthorized)
			}
            guard let id = self.id else {
                return Future(fail: DALIError.General.BadRequest)
            }
			
			let dict: [String: String] = [
				"option": option
			]
			
			do {
                return try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/voting/admin/\(id)/options", json: JSON(dict)).onSuccess(block: { (response) in
                    guard let data = response.json, let option = Option.parse(object: data) else {
                        throw response.assertedError
                    }
                    self.options = self.options ?? []
                    self.options!.append(option)
                })
			} catch {
                return Future(fail: error)
			}
		}
		
		/**
		Removes the given option from the list of options
		
		![Admin only](http://icons.iconarchive.com/icons/graphicloads/flat-finance/64/lock-icon.png)
		
		- parameter option: The option to remove
		- parameter callback: Function called when done
		*/
		public func removeOption(option: Option) -> Future<Void> {
			guard DALIapi.config.member?.isAdmin ?? false else {
				return Future(fail: DALIError.General.Unauthorized)
			}
            guard let id = self.id else {
                return Future(fail: DALIError.General.BadRequest)
            }
			
			let dict: [String: String] = [
				"option": option.id
			]
			
			do {
                return try ServerCommunicator.delete(url: "\(DALIapi.config.serverURL)/api/voting/admin/\(id)/options", json: JSON(dict)).onSuccess(block: { (response) in
                    if response.success {
                        if let index = self.options?.firstIndex(where: { (option2) -> Bool in return option2.id == option.id }) {
                            self.options?.remove(at: index)
                        }
                    } else {
                        throw response.assertedError
                    }
                })
			} catch {
				return Future(fail: error)
			}
		}
		
		// =================== Static Methods =======================
		// MARK: Static Getter Methods
		
		/**
		Get the current voting event
	
		- parameter callback: Function called when done
		- parameter event: Event found (if any)
		- parameter error: Error encountered (if any)
		*/
		public static func getCurrent() -> Future<[VotingEvent]> {
            
            // TODO: Observe current and released events
            return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/voting/public/current").onSuccess { (response) -> [VotingEvent] in
                guard let list = response.json?.array else {
                    throw response.assertedError
                }
                
                return list.compactMap({ (json) -> VotingEvent? in
                    return VotingEvent.parse(json)
                })
            }
		}
		
        private static func handleEventList(response: ServerCommunicator.Response) throws -> [VotingEvent] {
            guard let eventObjects = response.json?.array else {
                throw response.assertedError
            }
            
            return eventObjects.compactMap { (json) -> VotingEvent? in
                VotingEvent.parse(json)
            }
		}
		
		/**
		Get all events that have results released
	
		- parameter callback: Function called when done
		- parameter events: List of events retrieved
		- parameter error: Error encountered (if any)
		*/
		public static func getReleasedEvents() -> Future<[VotingEvent]> {
            return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/voting/public").onSuccess { (response) -> [VotingEvent] in
                return try handleEventList(response: response)
            }
		}
		
		/**
		Get voting events as an admin. The signed in user __must__ be an admin, otherwise will exit immediately
		
		![Admin only](http://icons.iconarchive.com/icons/graphicloads/flat-finance/64/lock-icon.png)
	
		- parameter callback: Function called when done
		- parameter events: List of events retrieved
		- parameter error: Error encountered (if any)
		*/
		public static func get() -> Future<[VotingEvent]> {
			guard DALIapi.config.member?.isAdmin ?? false else {
				return Future(fail: DALIError.General.Unauthorized)
			}
			
            return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/voting/admin").onSuccess { (response) -> [VotingEvent] in
                return try handleEventList(response: response)
            }
		}
        
        // MARK: Static Observation Methods
        internal static var votingEventSocket: SocketIOClient?
        internal static var observationEvent: Event<[VotingEvent]>?
        
        public static func observe() -> Event<[VotingEvent]> {
            guard observationEvent == nil else {
                return observationEvent!
            }
            
            observationEvent = Event<[VotingEvent]>()
            votingEventSocket = DALIapi.socketManager.socket(forNamespace: "/voting")
            
            votingEventSocket?.connect()
            ServerCommunicator.authenticateSocket(socket: votingEventSocket!)
            
            votingEventSocket?.on("events", callback: { (data, ack) in
                guard let eventsData = data[0] as? [Any] else {
                    DispatchQueue.main.async {
                        observationEvent?.emit([])
                    }
                    return;
                }
                
                var events: [VotingEvent] = []
                for eventDataObj in eventsData {
                    if let event = VotingEvent.parse(JSON(eventDataObj)) {
                        events.append(event)
                    }
                }
                
                DispatchQueue.main.async {
                    observationEvent?.emit(events)
                }
            })
            
            return observationEvent!;
        }
	}
	
	// MARK: Initialization Methods
	
	/**
		Creates an event object
	
		- parameter name: The name of the event
		- parameter description: The description of the event
		- parameter location: The location of the event
		- parameter start: The start time
		- parameter end: End time
	 */
	public init(name: String, description: String?, location: String?, start: Date, end: Date) {
		self.name_in = name
		self.description_in = description
		self.location_in = location
		self.start_in = start
		self.end_in = end
		self.googleID = nil
		self.dirty = true
		self.id = nil
	}
	
	/**
		Creates the event on the server
		
		- parameter callback: A function that will be called when the job is done
	
		- throws: `DALIError.Create` error describing some error encountered
	 */
	public func create() -> Future<Void> {
		guard self.id == nil else {
			return Future(fail: DALIError.Create.AlreadyCreated)
		}
		
        do {
            return try ServerCommunicator.post(url: DALIapi.config.serverURL + "/api/events", json: self.json()).onSuccess(block: { (response) in
                if !response.success {
                    throw response.assertedError
                }
            })
        } catch {
            return Future(fail: error)
        }
	}
	
	// MARK: JSON Parsing and Constructing Methods
	
	/**
		Parses a given json object and returns an event object if it can find one
	
		- parameter object: The JSON object you want parsed
	
		- returns: `DALIEvent` that was found. Will be nil if object is not event
	 */
	public class func parse(_ object: JSON) -> DALIEvent? {
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
		guard let id = dict["id"]?.string else {
			return nil
		}
		let googleID = dict["googleID"]?.string
		
		let event = DALIEvent(name: name, description: description, location: location, start: start, end: end)
		event.id = id
		event.googleID = googleID
		event.dict = dict
		
		if let votingEvent = VotingEvent(event: event) {
			return votingEvent
		}
		
		return event
	}
	
	/**
	Get the event in JSON form. Converts all data in the event into a form the API would use
	*/
	public func json() -> JSON {
		if let dict = self.dict {
			return JSON(dict)
		}
		
		if let event = VotingEvent(event: self) {
			return event.json()
		}
		
		let dict: [String: Any?] = [
			"name": self.name_in,
			"startTime": DALIEvent.dateFormatter().string(from: self.start_in),
			"endTime": DALIEvent.dateFormatter().string(from: self.end_in),
			"description": self.description,
			"location": self.location,
			"id": self.id,
			"votingEnabled": false,
			"googleID": self.googleID,
		]
		
		return JSON(dict)
	}
	
	// MARK: Static Get Methods
	
	/**
	Pulls __all__ the events from the server

	- parameter callback: Function called when done
	- parameter events: The events returned by the API
	- parameter error: The error encountered (if any)
	 */
	public static func getAll() -> Future<[DALIEvent]> {
        return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/events").onSuccess { (response) -> [DALIEvent] in
            guard let array = response.json?.array else {
                throw DALIError.General.UnexpectedResponse
            }
            
            return array.compactMap({ (json) -> DALIEvent? in
                return DALIEvent.parse(json)
            })
        }
	}
	
	/// The socket used to get event updates
	internal static var updatesSocket: SocketIOClient!
	/// The callbacks for each event type
	internal static var updatesCallbacks: [String: ([DALIEvent]?, DALIError.General?) -> Void] = [:]
	/// Makes sure the socket is open and waiting for updates
	internal static func assertUpdatesSocket() {
		if updatesSocket == nil {
			
			updatesSocket = DALIapi.socketManager.socket(forNamespace: "/eventsReloads")
			
			updatesSocket.onAny({ (event) in
				if let callback = updatesCallbacks[event.event] {
					guard let arr = event.items?[0] as? [[String: Any]] else {
						DispatchQueue.main.async {
							callback(nil, DALIError.General.UnexpectedResponse)
						}
						return
					}
					
					var events: [DALIEvent] = []
					for obj in arr {
						if let event = DALIEvent.parse(JSON(obj)) {
							events.append(event)
						}
					}
					
					DispatchQueue.main.async {
						callback(events, nil)
					}
				}
			})
			
			updatesSocket.connect()
			updatesSocket.on(clientEvent: .connect, callback: { (data, ack) in
				ServerCommunicator.authenticateSocket(socket: updatesSocket)
			})
		}
	}
	
	/**
	Observes all events. Will call callback every time something changes
	
	- parameter callback: The function called when the updates occur
	- parameter events: The updated events
	- parameter error: The error, if any, encountered
	*/
	public static func observeAll(block: @escaping (_ events: [DALIEvent]?, _ error: Error?) -> Void) -> Observation {
		assertUpdatesSocket()
		updatesCallbacks["allEvents"] = block
		
        getAll().onSuccess { (events) in
            block(events, nil)
        }.onFail { (error) in
            block(nil, error)
        }
        
		return Observation(stop: {
			removeCallback(forKey: "allEvents")
		}, id: "allEventsOberver")
	}
	
	/**
	Observes all upcoming events. Will call callback every time something changes
	
	- parameter callback: The function to call when done
	- parameter events: The events
	- parameter error: The error, if any, encountered
	*/
	public static func observeUpcoming(callback: @escaping (_ events: [DALIEvent]?, _ error: Error?) -> Void) -> Observation {
		assertUpdatesSocket()
		updatesCallbacks["weekEvents"] = callback
		
        getUpcoming().onSuccess { (events) in
            callback(events, nil)
        }.onFail { (error) in
            callback(nil, error)
        }
		
		return Observation(stop: {
			removeCallback(forKey: "weekEvents")
		}, id: "weekEventsOberver")
	}
	
	/// Cancels the callback for that key
	internal static func removeCallback(forKey key: String) {
		updatesCallbacks.removeValue(forKey: key)
		
		if updatesCallbacks.keys.count == 0 && updatesSocket != nil {
			if updatesSocket.status != .disconnected {
				updatesSocket.disconnect()
			}
			updatesSocket = nil
		}
	}
	
	/**
	Observe future events
	
	- parameter includeHidden: Include events marked as hidden (admin only)
	- parameter callback: The function to call when update happens
	- parameter events: The updated events
	- parameter error: The error, if any, encountered
	*/
	public static func observeFuture(includeHidden: Bool = false, callback: @escaping (_ events: [DALIEvent]?, _ error: Error?) -> Void) -> Observation {
		assertUpdatesSocket()
		updatesCallbacks["futureEvents" + (includeHidden && (DALIapi.config.member?.isAdmin ?? false) ? "Hidden" : "")] = callback
		
        getFuture(includeHidden: includeHidden && (DALIapi.config.member?.isAdmin ?? false)).onSuccess { (events) in
            callback(events, nil)
        }.onFail { (error) in
            callback(nil, error)
        }
		
		return Observation(stop: {
			removeCallback(forKey: "futureEvents" + (includeHidden && (DALIapi.config.member?.isAdmin ?? false) ? "Hidden" : ""))
		}, id: "futureEvents" + (includeHidden && (DALIapi.config.member?.isAdmin ?? false) ? "Hidden" : "") + "Oberver")
	}
	
	/**
	Observes public events.
	
	- parameter callback: The function called when the data is updated
	- parameter events: The events that have been updated
	- parameter error: The error, if any, encountered
	*/
	public static func observePublicUpcoming(callback: @escaping (_ events: [DALIEvent]?, _ error: Error?) -> Void) -> Observation {
		assertUpdatesSocket()
		updatesCallbacks["publicEvents"] = callback
		
        getPublicUpcoming().onSuccess { (events) in
            callback(events, nil)
        }.onFail { (error) in
            callback(nil, error)
        }
		
		return Observation(stop: {
			removeCallback(forKey: "publicEvents")
		}, id: "publicEventsOberver")
	}
	
	/**
	Gets all upcoming events within a week from now

	- parameter callback: Function called when done
	- parameter events: The events returned by the API
	- parameter error: The error encountered (if any)
	*/
	public static func getUpcoming() -> Future<[DALIEvent]> {
        return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/events/week").onSuccess { (response) -> [DALIEvent] in
            guard let array = response.json?.array else {
                throw response.assertedError
            }
            return array.compactMap({ (json) -> DALIEvent? in
                return DALIEvent.parse(json)
            })
        }
	}
	
	/**
	Gets all upcoming events within a week from now that are public
	No authorization is needed for this route
	
	- parameter callback: Function called when done
	- parameter events: The events returned by the API
	- parameter error: The error encountered (if any)
	*/
	public static func getPublicUpcoming() -> Future<[DALIEvent]> {
        return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/events/public/week").onSuccess { (response) -> [DALIEvent] in
            guard let array = response.json?.array else {
                throw response.assertedError
            }
            return array.compactMap({ (json) -> DALIEvent? in
                return DALIEvent.parse(json)
            })
        }
	}
	
	/**
	Gets all events in the future
	
	- parameter includeHidden: Include events that have been marked hidden (admin only)
	- parameter callback: Function called when done
	- parameter events: The events returned by the API
	- parameter error: The error encountered (if any)
	*/
	public static func getFuture(includeHidden: Bool = false) -> Future<[DALIEvent]> {
        var params = [String:String]()
		if includeHidden && (DALIapi.config.member?.isAdmin ?? false) {
			params["hidden"] = "true"
		}
		
        return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/events/future", params: params).onSuccess { (response) -> [DALIEvent] in
            guard let array = response.json?.array else {
                throw response.assertedError
            }
            return array.compactMap({ (json) -> DALIEvent? in
                return DALIEvent.parse(json)
            })
        }
	}
	
	// MARK: Voting Conversion Methods
	
	/**
	Enable voting on this event
	
	![Admin only](http://icons.iconarchive.com/icons/graphicloads/flat-finance/64/lock-icon.png)
	
	- parameter numSelected: Number of options the user should select
	- parameter ordered: The choices the user makes should be ordered (1st, 2nd, 3rd, ...)
	- parameter callback: Function to call when done
	- parameter success: Flag to indicate that the event has been properly enabled for voting
	- parameter event: The new VotingEvent, if it was successful
	- parameter error: The error encountered if it was not successful
	*/
	public func enableVoting(numSelected: Int, ordered: Bool) -> Future<VotingEvent> {
        guard DALIapi.config.member?.isAdmin ?? false else {
			return Future(fail: DALIError.General.Unauthorized)
        }
        guard let id = self.id else {
            return Future(fail: DALIError.General.BadRequest)
        }
		
		let config = VotingEvent.Config(numSelected: numSelected, ordered: ordered)
        let url = "\(DALIapi.config.serverURL)/api/voting/admin/\(id)/enable"
		
		do {
            return try ServerCommunicator.post(url: url, json: config.json()).onSuccess(block: { (response) -> VotingEvent in
                if response.success {
                    return VotingEvent(event: self, votingConfig: config, options: nil, resultsReleased: false)
                } else {
                    throw response.assertedError
                }
            })
		} catch {
			return Future(fail: error)
		}
	}
	
	// MARK: Check In Methods
	
	/**
	Checks in the current user to whatever event is happening now
	
	- parameter major: The major value of the bluetooth beacon
	- parameter minor: The minor value of the beacon
	- parameter callback: Called when done
	- parameter success: The operation was a success
	- parameter error: The error, if any, encountered
	*/
	public static func checkIn(major: Int, minor: Int) -> Future<Void> {
		DALIapi.assertUser(funcName: "checkIn")
		let data = ["major": major, "minor": minor]
		
		do {
            return try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/events/checkin", json: JSON(data)).onSuccess(block: { (response) in
                if !response.success {
                    throw response.assertedError
                }
            })
		} catch {
			return Future(fail: error)
		}
	}
	
	/**
	Enables checkin on the event, and gets back major and minor values to be used when advertizing
	
	- parameter callback: Called when done
	- parameter success: The operation was a success
	- parameter major: The major value of the bluetooth beacon
	- parameter minor: The minor value of the beacon
	- parameter error: The error, if any, encountered
	*/
    public func enableCheckin() -> Future<(major: Int?, minor: Int?)> {
		guard let id = self.id else {
			return Future(fail: DALIError.General.BadRequest)
		}
		
        return ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/events/\(id)/checkin", data: "".data(using: .utf8)!).onSuccess { (response) -> (Int?, Int?) in
            if !response.success {
                throw response.assertedError
            }
            
            let dict = response.json?.dictionary
            let major: Int? = dict?["major"]?.int
            let minor: Int? = dict?["minor"]?.int
            return (major, minor)
        }
	}
	
	/**
	Gets a list of members who have checked in
	
	- parameter callback: Called when done
	- parameter members: The members who have been checked in to the event
	- parameter error: The error, if any, encountered
	*/
    public func getMembersCheckedIn() -> Future<[DALIMember]> {
		guard let id = self.id else {
			return Future(fail: DALIError.General.BadRequest)
		}
		
        return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/events/\(id)/checkin").onSuccess { (response) -> [DALIMember] in
            guard let array = response.json?.array else {
                throw response.assertedError
            }
            
            return array.compactMap({ (json) -> DALIMember? in
                return DALIMember(json: json)
            })
        }
	}
	
	internal var checkinSocket: SocketIOClient?
	
	/**
	Observe the list of members whom have checked in
	
	- parameter callback: Called when complete
	- parameter memebers: The members who have checked in
	*/
	public func observeMembersCheckedIn(callback: @escaping (_ members: [DALIMember]) -> Void) -> Observation {
		if checkinSocket == nil {
			self.checkinSocket = DALIapi.socketManager.socket(forNamespace: "/listCheckins")
			
			let checkinSocket = self.checkinSocket!
			
			checkinSocket.on(clientEvent: .connect, callback: { (data, ack) in
				ServerCommunicator.authenticateSocket(socket: checkinSocket)
			})
			
			checkinSocket.on("authed", callback: { (data, ack) in
				checkinSocket.emit("eventSelect", self.id!)
			})
			
			checkinSocket.connect()
		}
		
		self.checkinSocket!.on("members", callback: { (data, ack) in
			guard let array = data[0] as? [Any] else {
				DispatchQueue.main.async {
					callback([])
				}
				return
			}
			
			var members: [DALIMember] = []
			for memberObj in array {
				if let member = DALIMember(json:JSON(memberObj)) {
					members.append(member)
				}
			}
			
			DispatchQueue.main.async {
				DispatchQueue.main.async {
					callback(members)
				}
			}
		})
		
		return Observation(stop: { 
			if self.checkinSocket?.status != .disconnected {
				self.checkinSocket?.disconnect()
			}
			self.checkinSocket = nil
		}, id: "checkInMembers:\(self.id!)")
	}
	
	internal static func dateFormatter() -> DateFormatter {
		let formatter = DateFormatter()
		formatter.calendar = Calendar(identifier: .iso8601)
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.timeZone = TimeZone(secondsFromGMT: 0)
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
		return formatter
	}
}
