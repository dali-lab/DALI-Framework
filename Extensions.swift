//
//  Extensions.swift
//  DALI
//
//  Created by John Kotz on 9/17/18.
//

import Foundation
import SwiftyJSON

/**
 Extending JSON class to support date parsing. From: https://github.com/SwiftyJSON/SwiftyJSON/issues/421#issuecomment-165408535
 */
extension JSON {
    
    public var date: Date? {
        get {
            switch self.type {
            case .string:
                return Formatter.jsonDateFormatter.date(from: self.object as! String)
            default:
                return nil
            }
        }
    }
    
    public var dateTime: Date? {
        get {
            switch self.type {
            case .string:
                return Formatter.jsonDateTimeFormatter.date(from: self.object as! String)
            default:
                return nil
            }
        }
    }
    
    class Formatter {
        
        private static var internalJsonDateFormatter: DateFormatter?
        private static var internalJsonDateTimeFormatter: DateFormatter?
        
        static var jsonDateFormatter: DateFormatter {
            if (internalJsonDateFormatter == nil) {
                internalJsonDateFormatter = DateFormatter()
                internalJsonDateFormatter!.dateFormat = "yyyy-MM-dd"
            }
            return internalJsonDateFormatter!
        }
        
        static var jsonDateTimeFormatter: DateFormatter {
            if (internalJsonDateTimeFormatter == nil) {
                internalJsonDateTimeFormatter = DateFormatter()
                internalJsonDateTimeFormatter!.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSS'Z'"
            }
            return internalJsonDateTimeFormatter!
        }
        
    }
}
