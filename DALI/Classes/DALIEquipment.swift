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

public class DALIEquipment {
    public var name: String
    public var password: String?
    public let id: String
    public var lastCheckedOut: CheckOutRecord?
    public var isCheckedOut: Bool {
        return lastCheckedOut != nil && lastCheckedOut!.endDate == nil
    }
    var socket: SocketIOClient!
    
    public static func equipment(for id: String) -> Future<DALIEquipment> {
        let promise = Promise<DALIEquipment>()
        
        ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/equipment/\(id)") { (json, errorCode, error) in
            if let error = error {
                promise.completeWithFail(error)
                return
            }
            
            if let json = json, let equipment = DALIEquipment(json: json) {
                let future = equipment.retreiveRequirements().map(block: { (_) -> DALIEquipment in
                    return equipment
                })
                promise.completeUsingFuture(future)
                return
            }
            promise.completeWithFail(DALIError.General.UnexpectedResponse)
        }
        
        return promise.future
    }
    
    static private var generalSocket: SocketIOClient!
    static private var allEquipmentObservationCallback: (([DALIEquipment], DALIError.General?) -> Void)!
    
    public static func observeAllEquipment(callback: @escaping ([DALIEquipment], DALIError.General?) -> Void) -> Observation {
        if (generalSocket == nil) {
            generalSocket = DALIapi.socketManager.socket(forNamespace: "/equipment")
            
            generalSocket.on("equipmentUpdate") { (data, ack) in
                guard let arr = data[0] as? [[String: Any]] else {
                    DispatchQueue.main.async {
                        allEquipmentObservationCallback([], DALIError.General.UnexpectedResponse)
                    }
                    return
                }
                
                var array = [DALIEquipment]()
                for obj in arr {
                    if let equipment = DALIEquipment(json: JSON(obj)) {
                        array.append(equipment)
                    }
                }
                let futures = array.map({ (equipment) -> Future<Any> in
                    return equipment.retreiveRequirements()
                })
                FutureBatch(futures).batchFuture.onComplete { (_) in
                    self.allEquipmentObservationCallback(array, nil)
                }
            }
            
            generalSocket.connect()
            generalSocket.on(clientEvent: .connect, callback: { (data, ack) in
                ServerCommunicator.authenticateSocket(socket: generalSocket!)
            })
        }
        allEquipmentObservationCallback = callback;
        
        return Observation(stop: {
            if let generalSocket = generalSocket {
                generalSocket.disconnect()
                self.generalSocket = nil
                self.allEquipmentObservationCallback = nil
            }
        }, id: "equipmentUpdate")
    }
    
    public static func allEquipment() -> Future<[DALIEquipment]> {
        let promise = Promise<[DALIEquipment]>()
        
        ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/equipment") { (response, responseCode, error) in
            if let dataArray = response?.array {
                var array = [DALIEquipment]()
                
                dataArray.forEach({ (json) in
                    if let equipment = DALIEquipment(json: json) {
                        array.append(equipment)
                    }
                })
                
                let future = FutureBatch(array.map({ (equipment) -> Future<Any> in
                    return equipment.retreiveRequirements()
                })).batchFuture.map(block: { (_) -> [DALIEquipment] in
                    return array
                })
                
                promise.completeUsingFuture(future)
            } else {
                promise.completeWithFail(error ?? DALIError.General.UnexpectedResponse)
            }
        }
        
        return promise.future
    }
    
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
    
    func retreiveRequirements() -> Future<Any> {
        return lastCheckedOut?.retreiveRequirements() ?? Future<Any>(success: self)
    }
    
    public class CheckOutRecord {
        private var memberID: String?
        public var member: DALIMember! = nil
        public let startDate: Date
        public let endDate: Date?
        public let projectedEndDate: Date?
        
        internal init?(json: JSON) {
            guard let dict = json.dictionary,
                let startDateString = dict["startDate"]?.string,
                let startDate = DALIEvent.dateFormatter().date(from: startDateString) else {
                return nil
            }
            if let memberJSON = dict["user"], let member = DALIMember(json: memberJSON) {
                self.member = member
            } else if let memberID = dict["user"]?.string {
                self.memberID = memberID
            } else {
                return nil
            }
            
            let endDateString = dict["endDate"]?.string
            let projectedEndDateString = dict["projectedEndDate"]?.string
            
            let endDate = endDateString != nil ? DALIEvent.dateFormatter().date(from: endDateString!) : nil
            let projectedEndDate = projectedEndDateString != nil ? DALIEvent.dateFormatter().date(from: projectedEndDateString!) : nil
            
            self.startDate = startDate
            self.endDate = endDate
            self.projectedEndDate = projectedEndDate
        }
        
        func retreiveRequirements() -> Future<Any> {
            if let memberID = memberID, member == nil {
                let future = DALIMember.get(id: memberID)
                return future.onSuccess { (member) -> Any in
                    self.member = member
                    return self
                }
            } else {
                return Future<Any>(success: self)
            }
        }
    }
    
    public func reload() -> Future<DALIEquipment> {
        let promise = Promise<DALIEquipment>()
        
        ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/equipment/\(id)") { (json, code, error) in
            guard error == nil else {
                promise.completeWithFail(error!)
                return
            }
            guard let json = json else {
                promise.completeWithFail(DALIError.General.UnexpectedResponse)
                return
            }
            
            self.update(json: json)
            promise.completeUsingFuture(self.retreiveRequirements().map(block: { (_) -> DALIEquipment in
                return self
            }))
        }
        
        return promise.future
    }
    
    public func getHistory() -> Future<[CheckOutRecord]> {
        let promise = Promise<[CheckOutRecord]>()
        
        ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/equipment/\(self.id)/checkout") { (response, errorCode, error) in
            if let error = error {
                promise.completeWithFail(error)
                return
            }
            
            guard let array = response?.array else {
                promise.completeWithFail(DALIError.General.UnexpectedResponse)
                return
            }
            
            var list = [CheckOutRecord]()
            for json in array {
                if let checkOutRecord = CheckOutRecord(json: json) {
                    list.append(checkOutRecord)
                }
            }
            
            let future = FutureBatch(list.map({ (record) -> Future<CheckOutRecord> in
                return record.retreiveRequirements().map(block: { (_) -> CheckOutRecord in
                    return record
                })
            })).batchFuture.map(block: { (list) -> [CheckOutRecord] in
                return list as! [CheckOutRecord]
            })
            
            promise.completeUsingFuture(future)
        }
        
        return promise.future
    }
    
    public func checkout(expectedEndDate: Date) -> Future<CheckOutRecord> {
        let promise = Promise<CheckOutRecord>()
        
        let dict = ["projectedEndDate" : DALIEvent.dateFormatter().string(from: expectedEndDate)]
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else {
            promise.completeWithFail(DALIError.General.Unprocessable)
            return promise.future
        }
        
        ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/equipment/\(id)/checkout", data: data) { (success, response, error) in
            if let error = error {
                promise.completeWithFail(error)
            } else if success {
                if let response = response, let checkOutRecord = CheckOutRecord(json: response) {
                    promise.completeWithSuccess(checkOutRecord)
                } else {
                    promise.completeWithFail(DALIError.General.UnexpectedResponse)
                }
            }
            promise.failIfNotCompleted(DALIError.General.BadRequest)
        }
        
        return promise.future
    }
    
    public func returnEquipment() -> Future<Any> {
        let promise = Promise<Any>();
        
        ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/equipment/\(id)/return", data: nil) { (success, response, error) in
             if let error = error {
                promise.completeWithFail(error)
                return
            }
            
            promise.completeWithSuccess(self)
        }
        
        return promise.future;
    }
    
    private var observeCallback: ((DALIEquipment) -> Void)?
    private var observeCheckoutsCallback: (([CheckOutRecord], DALIEquipment) -> Void)?
    private var observeDeletionCallback: ((DALIEquipment) -> Void)?
    
    private func assertSocket() {
        if (socket == nil) {
            socket = DALIapi.socketManager.socket(forNamespace: "/equipment")
            
            socket.on("checkOuts") { (data, ack) in
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
            socket.on("update") { (data, ack) in
                if let observeCallback = self.observeCallback, let data = data[0] as? [String:Any] {
                    self.update(json: JSON(data))
                    observeCallback(self)
                }
            }
            socket.on("deleted") { (data, ack) in
                if let observeDeletionCallback = self.observeDeletionCallback {
                    observeDeletionCallback(self)
                }
            }
            
            socket.connect()
            socket.on(clientEvent: .connect) { (data, ack) in
                ServerCommunicator.authenticateSocket(socket: self.socket)
            }
            socket.on("authed", callback: { (data, ack) in
                self.socket.emit("equipmentSelect", self.id)
            })
        }
    }
    
    private func cleanupSocket() {
        if (observeCallback == nil && observeCheckoutsCallback == nil && observeDeletionCallback == nil) {
            socket?.disconnect()
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
