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
    final public class CheckOutRecord {
        private var memberID: String?
        /// The member that checked this out
        public var member: DALIMember
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
                let startDate = DALIEvent.dateFormatter().date(from: startDateString),
                let memberJSON = dict["user"],
                let member = DALIMember(json: memberJSON)
                else {
                    return nil
            }
            
            let endDateString = dict["endDate"]?.string
            let projectedEndDateString = dict["projectedEndDate"]?.string
            
            let endDate = endDateString != nil ? DALIEvent.dateFormatter().date(from: endDateString!) : nil
            let projectedEndDate = projectedEndDateString != nil ? DALIEvent.dateFormatter().date(from: projectedEndDateString!) : nil
            
            self.member = member
            self.startDate = startDate
            self.endDate = endDate
            self.expectedReturnDate = projectedEndDate
        }
    }
}
