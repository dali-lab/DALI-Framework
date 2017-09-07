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

public class DALIFood {
	public static var current: String?
	
	public static func getFood(callback: @escaping (String?) -> Void) {
		ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/food") { (data, code, error) in
			callback(data?.string)
		}
	}
	
	internal static var socket: SocketIOClient?
	
	public static func observeFood(callback: @escaping (String?) -> Void) -> Observation {
		if socket == nil {
			socket = SocketIOClient(socketURL: URL(string: DALIapi.config.serverURL)!, config: [.nsp("/food")])
			
			socket?.connect()
		}
		
		socket!.on("foodUpdate", callback: { (data, ack) in
			callback(data[0] as? String)
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
			callback(false)
			return
		}
		
		do {
			try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/food", json: JSON(["food": food]), callback: { (success, data, error) in
				callback(success)
			})
		} catch {
			callback(false)
		}
	}
	
	public static func cancelFood(callback: @escaping (Bool) -> Void) {
		if !(DALIMember.current?.isAdmin ?? false) {
			callback(false)
			return
		}
		
		do {
			try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/food", json: JSON([:]), callback: { (success, data, error) in
				callback(success)
			})
		} catch {
			callback(false)
		}
	}
}
