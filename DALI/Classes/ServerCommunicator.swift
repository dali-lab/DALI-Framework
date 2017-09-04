//
//  ServerCommunications.swift
//  DALIapi
//
//  Created by John Kotz on 7/28/17.
//  Copyright © 2017 DALI Lab. All rights reserved.
//

import Foundation
import SwiftyJSON

class ServerCommunicator {
	private static var config: DALIConfig {
		return DALIapi.config
	}
	
	
	// MARK : POST and GET methods
	// ===========================
	
	/**
	Makes a GET request on a given url, calling the callback with the response JSON object when its done
	
	- paramters:
		- url: String - The URL you wan to GET from
		- callback: (response: Any)->Void - The callback that will be invoked when the task is done
	*/
	static func get(url: String, callback: @escaping (_ response: JSON?, _ code: Int?, _ error: DALIError.General?) -> Void) {
		var request = URLRequest(url: URL(string: url)!)
		request.httpMethod = "GET"
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")
		request.addValue("application/json", forHTTPHeaderField: "Accept")
		if let token = config.token {
			request.addValue(token, forHTTPHeaderField: "authorization")
		}else if let apiKey = config.apiKey {
			request.addValue(apiKey, forHTTPHeaderField: "apiKey")
		}
		
		let task = URLSession.shared.dataTask(with: request) { data, response, error in
			let httpResponse = response as? HTTPURLResponse
			
			if let httpResponse = httpResponse, httpResponse.statusCode != 200 || error != nil {
				print("Didn't get 200: \(httpResponse.statusCode)")
				
				var err: DALIError.General = DALIError.General.UnknownError(error: error, text: data == nil ? nil : String(data: data!, encoding: .utf8), code: httpResponse.statusCode)
				
				switch httpResponse.statusCode {
				case 401:
					err = DALIError.General.Unauthorized
					break
				case 403:
					fatalError("DALIapi: Provided API Key out invalid!")
					break
				case 422:
					err = DALIError.General.Unprocessable
					break
				case 400:
					err = DALIError.General.BadRequest
					break
				case 404:
					err = DALIError.General.Unfound
					break
				default:
					break
				}
				
				callback(nil, httpResponse.statusCode, err)
				return
			}else if let error = error {
				print(error)
				
				callback(nil, httpResponse?.statusCode, DALIError.General.UnknownError(error: error, text: data == nil ? nil : String(data: data!, encoding: .utf8), code: httpResponse == nil ? -1 : httpResponse!.statusCode))
				return
			}
			
			
			guard let data = data else {
				print("Data is empty")
				callback(nil, httpResponse?.statusCode, nil)
				return
			}
			
			let json = JSON.init(data: data)
			
			if let error = json.error {
				if error.code == ErrorInvalidJSON {
					callback(nil, httpResponse?.statusCode, DALIError.General.InvalidJSON(text: String(data: data, encoding: .utf8), jsonError: error))
					return
				}
			}
			
			callback(json, httpResponse?.statusCode, nil)
		}
		
		task.resume()
	}
	
	/**
	Convenience function for posting JSON data
	
	- Parameters:
		- url: `String` - The URL you want to post to
		- json: `Data` - A JSON encoded data string to be sent to the server
		- callback: `(Bool, DALIError.General?)->Void` - A callback that will be invoked when the process is complete
	*/
	static func post(url: String, json: JSON, callback: @escaping (Bool, JSON?, DALIError.General?) -> Void) throws {
		let data = try json.rawData()
		
		ServerCommunicator.post(url: url, data: data, callback: callback)
	}
	
	/**
	Makes a POST request to the given url using the given data, using the callback when it is done
	
	- Parameters:
		- url: String - The URL you want to post to
		- data: Data - A JSON encoded data string to be sent to the server
		- callback: ()->Void - A callback that will be invoked when the process is complete
	*/
	static func post(url: String, data: Data, callback: @escaping (Bool, JSON?, DALIError.General?) -> Void) {
		var request = URLRequest(url: URL(string: url)!)
		request.httpMethod = "POST"
		request.httpBody = data
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")
		request.addValue("application/json", forHTTPHeaderField: "Accept")
		if let token = config.token {
			request.addValue(token, forHTTPHeaderField: "authorization")
		}else if let apiKey = config.apiKey {
			request.addValue(apiKey, forHTTPHeaderField: "apiKey")
		}
		
		// Set up the task
		let task = URLSession.shared.dataTask(with: request) { data, response, error in
			let httpResponse = response as? HTTPURLResponse
			
			if let httpResponse = httpResponse, httpResponse.statusCode != 200 || error != nil {
				print("Didn't get 200: \(httpResponse.statusCode)")
				
				var err: DALIError.General = DALIError.General.UnknownError(error: error, text: data == nil ? nil : String(data: data!, encoding: .utf8), code: httpResponse.statusCode)
				
				switch httpResponse.statusCode {
				case 401:
					err = DALIError.General.Unauthorized
					break
				case 403:
					fatalError("DALIapi: Provided API Key out invalid!")
					break
				case 422:
					err = DALIError.General.Unprocessable
					break
				case 400:
					err = DALIError.General.BadRequest
					break
				case 404:
					err = DALIError.General.Unfound 
					break
				default:
					break
				}
				
				callback(false, nil, err)
				return
			}else if let error = error {
				print(error)
				
				callback(false, nil, DALIError.General.UnknownError(error: error, text: data == nil ? nil : String(data: data!, encoding: .utf8), code: -1))
				return
			}
			
			guard let data = data else {
				print("Data is empty")
				callback(true, nil, nil)
				return
			}
			
			let json = JSON.init(data: data)
			
			if let error = json.error {
				if error.code == ErrorInvalidJSON {
					callback(true, json, DALIError.General.InvalidJSON(text: String(data: data, encoding: .utf8), jsonError: error))
					return
				}
			}
			
			callback(true, json, nil)
		}
		
		// And complete it
		task.resume()
	}
}
