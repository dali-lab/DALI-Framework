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
	
	/**
	Observe the current listing of food
	
	- parameter callback: Called when complete
	- parameter food: The food listed for tonight, if any
	*/
	public static func observeFood(callback: @escaping (_ food: String?) -> Void) -> Observation {
		if socket == nil {
			let manager = SocketManager(socketURL: URL(string: DALIapi.config.serverURL)!)
			socket = manager.socket(forNamespace: "/food")
			
			socket!.connect()
			socket!.on(clientEvent: .connect, callback: { (data, ack) in
				ServerCommunicator.authenticateSocket(socket: socket!)
			})
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
	
	/**
	Sets the food listing for the night
	
	![Admin only](http://icons.iconarchive.com/icons/graphicloads/flat-finance/64/lock-icon.png)
	
	- parameter food: The food to set the listing to
	- parameter callback: Called when complete
	- parameter success: Was successful
	*/
	public static func setFood(food: String, callback: @escaping (_ success: Bool) -> Void) {
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
	
	/**
	Cancels the food listing for tonight
	
	![Admin only](http://icons.iconarchive.com/icons/graphicloads/flat-finance/64/lock-icon.png)
	
	- parameter callback: Called when complete
	- parameter success: Was successful
	*/
	public static func cancelFood(callback: @escaping (_ success: Bool) -> Void) {
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
