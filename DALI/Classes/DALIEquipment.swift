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
    var name: String
    var password: String?
    let id: String
    let qrID: String
    var lastCheckedOut: CheckOutRecord?
    var isCheckedOut: Bool {
        return lastCheckedOut?.endDate != nil
    }
    var socket: SocketIOClient!
    
    public static func equipment(for qrID: String) -> Future<DALIEquipment> {
        let promise = Promise<DALIEquipment>()
        
        ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/equipment/\(qrID)") { (json, errorCode, error) in
            if let error = error {
                promise.completeWithFail(error)
                return;
            }
            
            if let json = json, let equipment = DALIEquipment(json: json) {
                promise.completeWithSuccess(equipment)
                return;
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
                allEquipmentObservationCallback(array, nil)
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
                
                promise.completeWithSuccess(array)
            }
            
            promise.failIfNotCompleted(error ?? DALIError.General.UnexpectedResponse)
        }
        
        return promise.future
    }
    
    internal init?(json: JSON) {
        guard let dict = json.dictionary,
            let name = dict["name"]?.string,
            let id = dict["id"]?.string,
            let qrID = dict["qrID"]?.string
        else {
            return nil
        }
        
        self.name = name
        self.id = id
        self.qrID = qrID
        self.password = dict["password"]?.string
        if let lastCheckedOutJSON = dict["lastCheckedOut"] {
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
        if let lastCheckedOutJSON = dict["lastCheckedOut"] {
            self.lastCheckedOut = CheckOutRecord(json: lastCheckedOutJSON)
        }
    }
    
    public struct CheckOutRecord {
        let member: DALIMember
        let startDate: Date
        let endDate: Date?
        let projectedEndDate: Date?
        
        internal init?(json: JSON) {
            guard let dict = json.dictionary,
                let startDate = dict["startDate"]?.date else {
                return nil
            }
            guard let memberJSON = dict["user"], let member = DALIMember.parse(memberJSON) else {
                return nil
            }
            
            self.startDate = startDate
            self.endDate = dict["endDate"]?.date
            self.projectedEndDate = dict["projectedEndDate"]?.date
            self.member = member
        }
    }
    
    func getHistory() -> Future<[CheckOutRecord]> {
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
            
            promise.completeWithSuccess(list)
        }
        
        return promise.future
    }
    
    func checkout() -> Future<CheckOutRecord> {
        let promise = Promise<CheckOutRecord>()
        
        ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/equipment/\(self.id)/checkout", data: nil) { (success, response, error) in
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
    
    func returnEquipment() -> Future<Any> {
        let promise = Promise<Any>();
        
        ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/equipment/\(self.id)/return", data: nil) { (success, response, error) in
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
