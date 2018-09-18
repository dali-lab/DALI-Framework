//
//  DALIEquipment.swift
//  DALI
//
//  Created by John Kotz on 9/17/18.
//

import Foundation
import FutureKit
import SwiftyJSON

public struct DALIEquipment {
    let name: String
    let password: String
    let id: String
    let lastCheckedOut: CheckOutRecord?
    var isCheckedOut: Bool {
        return lastCheckedOut?.endDate != nil
    }
    
    public static func equipment(for id: String) -> Future<DALIEquipment> {
        let promise = Promise<DALIEquipment>()
        
        ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/equipment/\(id)") { (json, errorCode, error) in
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
            let id = dict["id"]?.string
        else {
            return nil
        }
        
        self.name = name
        self.id = id
        if let lastCheckedOutJSON = dict["lastCheckedOut"] {
            self.lastCheckedOut = CheckOutRecord(json: lastCheckedOutJSON)
        } else {
            self.lastCheckedOut = nil
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
}
