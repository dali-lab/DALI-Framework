//
//  DALIFood.swift
//  Pods
//
//  Created by John Kotz on 9/6/17.
//
//

import Foundation
import SwiftyJSON
import SocketIO

/**
An interface for getting and setting information about food in the lab
*/
public class DALIFood {
	/// The most recently gathered information on food
	public static var current: String?
	
	/**
	Gets the current food for the night
	
	- parameter callback: The function called when the data has been received
	- parameter food: The food tonight
	*/
	public static func getFood(callback: @escaping (_ food: String?) -> Void) {
		ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/food") { (data, code, error) in
			DispatchQueue.main.async {
				callback(data?.string)
			}
		}
	}
	
	/// The socket to be used for observing
	internal static var socket: SocketIOClient?
	
	public static func observeFood(callback: @escaping (String?) -> Void) -> Observation {
		if socket == nil {
			socket = SocketIOClient(socketURL: URL(string: DALIapi.config.serverURL)!, config: [.nsp("/food")])
			
			socket?.connect()
		}
		
		socket!.on("foodUpdate", callback: { (data, ack) in
			DispatchQueue.main.async {
				callback(data[0] as? String)
			}
		})
		
		return Observation(stop: { 
			if socket?.status != .disconnected {
				socket?.disconnect()
			}
			socket = nil
		}, id: "foodSocket")
	}
	
	public static func setFood(food: String, callback: @escaping (Bool) -> Void) {
		if !(DALIMember.current?.isAdmin ?? false) {
			DispatchQueue.main.async {
				callback(false)
			}
			return
		}
		
		do {
			try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/food", json: JSON(["food": food]), callback: { (success, data, error) in
				DispatchQueue.main.async {
					callback(success)
				}
			})
		} catch {
			DispatchQueue.main.async {
				callback(false)
			}
		}
	}
	
	public static func cancelFood(callback: @escaping (Bool) -> Void) {
		if !(DALIMember.current?.isAdmin ?? false) {
			DispatchQueue.main.async {
				callback(false)
			}
			return
		}
		
		do {
			try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/food", json: JSON([:]), callback: { (success, data, error) in
				DispatchQueue.main.async {
					callback(success)
				}
			})
		} catch {
			DispatchQueue.main.async {
				callback(false)
			}
		}
	}
}
