//
//  CheckOutRecord.swift
//  ChromaColorPicker
//
//  Created by John Kotz on 12/22/18.
//

import Foundation
import FutureKit
import SwiftyJSON

extension DALIEquipment {
    /**
     A record of a peice of equipment being checked out
     */
    final public class CheckOutRecord: DALIObject {
        private var memberID: String?
        /// The member that checked this out
        public var member: DALIMember! = nil
        /// The time it was checked out
        public let startDate: Date
        /// The time it was returned
        public let endDate: Date?
        /// The day the user anticipates returning the equipment
        public let expectedReturnDate: Date?
        
        /// Setup using json
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
            self.expectedReturnDate = projectedEndDate
        }
        
        
        func retreiveRequirements() -> Future<DALIEquipment.CheckOutRecord> {
            if let memberID = memberID, member == nil {
                let future = DALIMember.get(id: memberID)
                return future.onSuccess { (member) -> DALIEquipment.CheckOutRecord in
                    self.member = member
                    return self
                }
            } else {
                return Future<DALIEquipment.CheckOutRecord>(success: self)
            }
        }
    }
}
