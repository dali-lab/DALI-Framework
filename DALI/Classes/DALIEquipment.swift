//
//  DALIEquipment.swift
//  DALI
//
//  Created by John Kotz on 9/17/18.
//

import Foundation
import FutureKit
import SwiftyJSON
import SocketIO
import EmitterKit

/**
 Singular equipment object describing one of the items DALI has available for sign out
 */
final public class DALIEquipment: DALIObject {
    /// Identifier for this equipment
    public let id: String
    /// Name of the device
    public var name: String
    /// Password, if any
    public var password: String?
    /// The most recent record of this device being checked out
    public var lastCheckedOut: CheckOutRecord?
    /// This device has been checked
    public var isCheckedOut: Bool {
        return lastCheckedOut != nil && lastCheckedOut!.endDate == nil
    }
    var updatesSocket: SocketIOClient!
    static private var staticUpdatesSocket: SocketIOClient!
    static private var staticUpdatesEvent = Event<[DALIEquipment]>()
    
    // MARK: - Setup
    
    internal init?(json: JSON) {
        guard let dict = json.dictionary,
            let name = dict["name"]?.string,
            let id = dict["id"]?.string
            else {
                return nil
        }
        
        self.name = name
        self.id = id
        self.password = dict["password"]?.string
        if let lastCheckedOutJSON = dict["lastCheckOut"] {
            self.lastCheckedOut = CheckOutRecord(json: lastCheckedOutJSON)
        } else {
            self.lastCheckedOut = nil
        }
    }
    
    private func update(json: JSON) {
        guard let dict = json.dictionary else {
            return
        }
        
        self.name = dict["name"]?.string ?? self.name
        self.password = dict["password"]?.string ?? self.password
        if let lastCheckedOutJSON = dict["lastCheckOut"] {
            self.lastCheckedOut = CheckOutRecord(json: lastCheckedOutJSON)
        }
    }
    
    // MARK: - Public API
    
    // MARK: Static Getters
    
    /**
     Get a single equipment object with a given id
     */
    public static func equipment(for id: String) -> Future<DALIEquipment> {
        return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/equipment/\(id)").onSuccess(block: { (response) -> Future<DALIEquipment> in
            if let json = response.json, let equipment = DALIEquipment(json: json) {
                return equipment.retreiveRequirements()
            } else {
                throw response.assertedError
            }
        })
    }
    
    /**
     Get all the equipment
     */
    public static func allEquipment() -> Future<[DALIEquipment]> {
        return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/equipment").onSuccess(block: { (response) -> Future<[DALIEquipment]> in
            if let dataArray = response.json?.array {
                var array = [DALIEquipment]()
                
                dataArray.forEach({ (json) in
                    if let equipment = DALIEquipment(json: json) {
                        array.append(equipment)
                    }
                })
                
                return retriveAllRequirements(on: array)
            } else {
                throw response.assertedError
            }
        })
    }
    
    // MARK: Single equipment methods
    
    /**
     Reload the information stored in this equipment
     */
    public func reload() -> Future<DALIEquipment> {
        return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/equipment/\(id)").onSuccess(block: { (response) -> Future<DALIEquipment> in
            guard let json = response.json else {
                throw response.assertedError
            }
            
            self.update(json: json)
            return self.retreiveRequirements()
        })
    }
    
    /**
     Get all the checkouts in the past for this equipment
     */
    public func getHistory() -> Future<[CheckOutRecord]> {
        return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/equipment/\(self.id)/checkout").onSuccess { (response) -> Future<[CheckOutRecord]> in
            guard let array = response.json?.array else {
                throw response.assertedError
            }
            
            let list = array.compactMap({ (json) -> CheckOutRecord? in
                return CheckOutRecord(json: json)
            })
            return retriveAllRequirements(on: list)
        }
    }
    
    /**
     Check out this equipment
     
     - note: Will only succeed when the user is signed in and it is not currently checked out
     */
    public func checkout(expectedEndDate: Date) -> Future<CheckOutRecord> {
        guard !isCheckedOut else {
            return Future<CheckOutRecord>(fail: DALIError.Equipment.AlreadyCheckedOut)
        }
        
        let dict = ["projectedEndDate" : DALIEvent.dateFormatter().string(from: expectedEndDate)]
        var data: Data!
        do {
            data = try JSONSerialization.data(withJSONObject: dict, options: [])
        } catch {
            return Future(fail: error)
        }
        
        return ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/equipment/\(id)/checkout", data: data).onSuccess { (response) -> Future<CheckOutRecord> in
            if let json = response.json, let checkOutRecord = CheckOutRecord(json: json) {
                return Future(success: checkOutRecord)
            } else {
                return self.reload().onSuccess { (equipment) in
                    if equipment.isCheckedOut {
                        throw DALIError.Equipment.AlreadyCheckedOut
                    } else {
                        throw DALIError.General.UnexpectedResponse
                    }
                }
            }
        }
    }
    
    public func returnEquipment() -> Future<DALIEquipment> {
        return ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/equipment/\(id)/return", data: nil).onSuccess(block: { (response) -> Future<DALIEquipment> in
            if !response.success {
                throw response.assertedError
            }
            return self.reload()
        })
    }
    
    // MARK: Observing changes
    
    /**
     Observe all the equipment, get updates whenever there are changes
     
     - parameter block: The block that will be called when new information is available
     - returns: Observation to allow you to control the flow of new information
     */
    public static func observeAllEquipment(block: @escaping ([DALIEquipment]) -> Void) -> Observation {
        assertStaticSocket()
        let listener = staticUpdatesEvent.on(block)
        
        return Observation(stop: {
            listener.isListening = false
            updateStaticSocketEnabled()
        }, listener: listener, restartBlock: {
            listener.isListening = true
            assertStaticSocket()
            return true
        })
    }
    
    // MARK: - DALIObject
    
    func retreiveRequirements() -> Future<DALIEquipment> {
        if let subFuture = lastCheckedOut?.retreiveRequirements() {
            return subFuture.map { (_) -> DALIEquipment in
                return self
            }
        }
        return Future<DALIEquipment>(success: self)
    }
    
    // MARK: - Helpers
    
    /// Check to see if the static socket is open. If not, open one
    private static func assertStaticSocket() {
        guard staticUpdatesSocket == nil else {
            return
        }
        staticUpdatesSocket = DALIapi.socketManager.socket(forNamespace: "/equipment")
        
        staticUpdatesSocket.on("equipmentUpdate") { (data, ack) in
            guard let array = data[0] as? [[String: Any]] else {
                staticUpdatesEvent.emit([])
                return
            }
            
            let equipment = array.compactMap({ (data) -> DALIEquipment? in
                return DALIEquipment(json: JSON(data))
            })
            
            _ = retriveAllRequirements(on: equipment).onSuccess { (equipment) in
                self.staticUpdatesEvent.emit(equipment)
            }
        }
        
        staticUpdatesSocket.connect()
        staticUpdatesSocket.on(clientEvent: .connect, callback: { (data, ack) in
            ServerCommunicator.authenticateSocket(socket: staticUpdatesSocket!)
        })
    }
    
    /// Disconnect the socket if no one is listening
    private static func updateStaticSocketEnabled() {
        guard let staticUpdatesSocket = staticUpdatesSocket else {
            return
        }
        
        let listeners = staticUpdatesEvent.getListeners(nil).filter { (listener) -> Bool in
            return listener.isListening
        }
        
        if listeners.count <= 0 {
            staticUpdatesSocket.disconnect()
            self.staticUpdatesSocket = nil
        }
    }
    
    private var observeCallback: ((DALIEquipment) -> Void)?
    private var observeCheckoutsCallback: (([CheckOutRecord], DALIEquipment) -> Void)?
    private var observeDeletionCallback: ((DALIEquipment) -> Void)?
    
    private func assertSocket() {
        if (updatesSocket == nil) {
            updatesSocket = DALIapi.socketManager.socket(forNamespace: "/equipment")
            
            updatesSocket.on("checkOuts") { (data, ack) in
                if let observeCheckoutsCallback = self.observeCheckoutsCallback, let data = data[0] as? [[String: Any]] {
                    var checkOuts = [CheckOutRecord]()
                    for obj in data {
                        if let checkOut = CheckOutRecord(json: JSON(obj)) {
                            checkOuts.append(checkOut)
                        }
                    }
                    observeCheckoutsCallback(checkOuts, self)
                }
            }
            updatesSocket.on("update") { (data, ack) in
                if let observeCallback = self.observeCallback, let data = data[0] as? [String:Any] {
                    self.update(json: JSON(data))
                    observeCallback(self)
                }
            }
            updatesSocket.on("deleted") { (data, ack) in
                if let observeDeletionCallback = self.observeDeletionCallback {
                    observeDeletionCallback(self)
                }
            }
            
            updatesSocket.connect()
            updatesSocket.on(clientEvent: .connect) { (data, ack) in
                ServerCommunicator.authenticateSocket(socket: self.updatesSocket)
            }
            updatesSocket.on("authed", callback: { (data, ack) in
                self.updatesSocket.emit("equipmentSelect", self.id)
            })
        }
    }
    
    private func cleanupSocket() {
        if (observeCallback == nil && observeCheckoutsCallback == nil && observeDeletionCallback == nil) {
            updatesSocket?.disconnect()
        }
    }
    
    func observe(callback: @escaping (DALIEquipment) -> Void) -> Observation {
        self.assertSocket()
        observeCallback = callback
        
        return Observation(stop: {
            self.observeCallback = nil
            self.cleanupSocket()
        }, id: "observing-\(id)")
    }
    
    func observeCheckouts(callback: @escaping ([CheckOutRecord], DALIEquipment) -> Void) -> Observation {
        self.assertSocket()
        observeCheckoutsCallback = callback
        
        return Observation(stop: {
            self.observeCheckoutsCallback = nil
            self.cleanupSocket()
        }, id: "observingCheckOuts-\(id)")
    }
    
    func observeDeletion(callback: @escaping (DALIEquipment) -> Void) -> Observation {
        self.assertSocket()
        observeDeletionCallback = callback
        
        return Observation(stop: {
            self.observeDeletionCallback = nil
            self.cleanupSocket()
        }, id: "observingDeletion-\(id)")
    }
}
