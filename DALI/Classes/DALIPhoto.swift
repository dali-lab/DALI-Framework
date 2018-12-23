//
//  DALIPhotos.swift
//  DALI
//
//  Created by John Kotz on 10/13/17.
//

import Foundation
import FutureKit

/**
Photo class for getting a list of all photos from the API
*/
public class DALIPhoto {
	
	/**
	Gets list of photo urls
	
	- parameter callback: Function called when the data arrives
	- parameter photos: The photos that were retrieved
	- parameter error: The error, if any, encountered
	*/
	public static func get() -> Future<[String]> {
        return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/photos").onSuccess { (response) -> [String] in
            guard let array = response.json?.array else {
                throw response.assertedError
            }
            
            return array.compactMap({ (value) -> String? in
                return value.string
            })
        }
	}
}
