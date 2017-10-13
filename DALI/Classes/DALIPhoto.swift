//
//  DALIPhotos.swift
//  DALI
//
//  Created by John Kotz on 10/13/17.
//

import Foundation

public class DALIPhoto {
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
