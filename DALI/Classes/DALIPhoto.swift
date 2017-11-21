//
//  DALIPhotos.swift
//  DALI
//
//  Created by John Kotz on 10/13/17.
//

import Foundation

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
	public static func get(callback: @escaping (_ photos: [String], _ error: DALIError.General?) -> Void) {
		ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/photos") { (data, code, error) in
			guard let array = data?.array else {
				callback([], error)
				return
			}
			
			var photos = [String]()
			for value in array {
				if let photoURL = value.string {
					photos.append(photoURL)
				}
			}
		
			callback(photos, error)
		}
	}
}
