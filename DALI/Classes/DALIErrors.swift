//
//  DALIErrors.swift
//  DALIapi
//
//  Created by John Kotz on 7/28/17.
//  Copyright © 2017 DALI Lab. All rights reserved.
//

import Foundation

/// A set of errors used by the DALIapi framework to signal the user when there is an issue
open class DALIError {
	/// Pertaining to the Save opperation
	public enum Save: Error {
		
	}
	
	/// Pertaining to the Create opperation
	public enum Create: Error {
		/// The object you are calling create on has already been created
		case AlreadyCreated
	}

	/// Pertaining to the General opperations. Mostly used by the ServerCommunicator
	public enum General: Error {
		/// The request did not have proper authorization
		case Unauthorized
		/// A unknown error has occured. Information about the error is stored. Code will be -1 if there is no code
		case UnknownError(error: Error?, text: String?, code: Int)
		/// Response was not JSON! Text version is stored
		case InvalidJSON(text: String?, jsonError: NSError)
		/// The data sent to the server was not able to be processed for whatever reason
		case Unprocessable
		/// The data sent was not valid for the route. Consult the documentation for the route you are using
		case BadRequest
		/// The response to the request was not as expected. Consult the documentation for the route you are using
		case UnexpectedResponse
		/// The requested object(s) were not found on the server
		case Unfound
        
        public var localizedDescription: String {
            switch self {
            case .Unprocessable:
                return "Data was unprocessable"
            default:
                return "Unknown error has occured"
            }
        }
	}
}
