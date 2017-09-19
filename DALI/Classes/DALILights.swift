//
//  DALILights.swift
//  Pods
//
//  Created by John Kotz on 9/17/17.
//
//

import Foundation
import SwiftyJSON
import SocketIO

public class DALILights {
	private static var scenesMap: [String:[String]] = [:]
	private static var scenesAvgColorMap: [String:String] = [:]
	
	public struct Group {
		public let name: String
		public var formattedName: String {
			if name == "tvspace" {
				return "TV Space"
			}else{
				return name.replacingOccurrences(of: "pod:", with: "").capitalized
			}
		}
		public let scene: String?
		public var formattedScene: String? {
			return scene?.capitalized
		}
		public let color: String?
		
		public var avgColor: String? {
			if let color = color {
				return color
			}else if let scene = scene {
				return DALILights.scenesAvgColorMap[scene]
			}else{
				return nil
			}
		}
		
		public let isOn: Bool
		public var scenes: [String] {
			if name == "all" {
				var allSet: Set<String>?
				for entry in scenesMap {
					var set = Set<String>()
					for scene in entry.value {
						set.insert(scene)
					}
					if allSet != nil {
						allSet = allSet!.intersection(set)
					}else{
						allSet = set
					}
				}
				
				return Array(allSet!).sorted()
			}else if name == "pods" {
				var podsSet: Set<String>?
				for entry in scenesMap {
					if entry.key.contains("pod") {
						var set = Set<String>()
						for scene in entry.value {
							set.insert(scene)
						}
						if podsSet != nil {
							podsSet = podsSet!.intersection(set)
						}else{
							podsSet = set
						}
					}
				}
				
				return Array(podsSet!).sorted()
			}
			
			if let scenes = DALILights.scenesMap[name] {
				return scenes.sorted()
			}else{
				return []
			}
		}
		
		public init(name: String, scene: String?, color: String?, isOn: Bool) {
			self.name = name
			self.scene = scene
			self.color = color
			self.isOn = isOn
		}
		
		public func set(scene: String, callback: @escaping (_ success: Bool, _ error: DALIError.General?) -> Void) {
			self.setValue(value: scene, callback: callback)
		}
		
		internal func setValue(value: String, callback: @escaping (_ success: Bool, _ error: DALIError.General?) -> Void) {
			do {
				try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/lights/\(name)", json: JSON(["value":value]), callback: { (success, data, error) in
					DispatchQueue.main.async {
						callback(success, error)
					}
				})
			} catch {
				
			}
		}
		
		public func set(color: String, callback: @escaping (_ success: Bool, _ error: DALIError.General?) -> Void) {
			self.setValue(value: color, callback: callback)
		}
		
		public func set(on: Bool, callback: @escaping (_ success: Bool, _ error: DALIError.General?) -> Void) {
			self.setValue(value: on ? "on" : "off", callback: callback)
		}
		
		public static internal(set) var all = Group(name: "all", scene: nil, color: nil, isOn: false)
		public static internal(set) var pods = Group(name: "pods", scene: nil, color: nil, isOn: false)
	}
	
	internal static var updatingSocket: SocketIOClient!
	
	public static func oberserveAll(callback: @escaping ([Group]) -> Void) -> Observation {
		if updatingSocket == nil {
			updatingSocket = SocketIOClient(socketURL: URL(string: "\(DALIapi.config.serverURL)")!, config: [.nsp("/lights")])
			
			updatingSocket.connect()
		}
		
		updatingSocket.on("state", callback: { (data, ack) in
			guard let dict = data[0] as? [String: Any] else {
				return
			}
			
			guard let hueDict = dict["hue"] as? [String: Any] else {
				return
			}
			
			var groups: [Group] = []
			var allOn = true
			var podsOn = true
			var allScene: String?
			var noAllScene = false
			var allColor: String?
			var noAllColor = false
			var podsScene: String?
			var noPodsScene = false
			var podsColor: String?
			var noPodsColor = false
			
			for entry in hueDict {
				let name = entry.key
				if let dict = entry.value as? [String:Any], let isOn = dict["isOn"] as? Bool {
					let color = dict["color"] as? String
					let scene = dict["scene"] as? String
					allOn = allOn && isOn
					if name.contains("pod") {
						podsOn = isOn
						
						if podsScene == nil {
							podsScene = scene
						}else if podsScene != scene {
							noPodsScene = true
						}
						
						if podsColor == nil {
							podsColor = color
						}else if podsColor != color {
							noPodsColor = true
						}
					}
					
					if allScene == nil {
						allScene = scene
					}else if allScene != scene {
						noAllScene = true
					}
					
					if allColor == nil {
						allColor = color
					}else if allColor != color {
						noAllColor = true
					}
					
					groups.append(Group(name: name, scene: scene, color: color, isOn: isOn))
				}
			}
			
			Group.all = Group(name: "all", scene: noAllScene ? nil : allScene, color: noAllColor ? nil : allColor, isOn: allOn)
			Group.pods = Group(name: "pods", scene: noPodsScene ? nil : podsScene, color: noPodsColor ? nil : podsColor, isOn: podsOn)
			
			DispatchQueue.main.async {
				callback(groups)
			}
		})
		
		ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/lights/config") { (data, code, error) in
			guard let dict = data?.dictionary else {
				return
			}
			
			var map = [String:[String]]()
			var colorMap = [String:String]()
			
			for entry in dict {
				if let value = entry.value.array {
					var array: [String] = []
					for scene in value {
						if let sceneDict = scene.dictionary, let scene = sceneDict["name"]?.string {
							array.append(scene)
							colorMap[scene] = sceneDict["averageColor"]?.string
						}
					}
					
					map[entry.key] = array
				}
			}
			
			DALILights.scenesAvgColorMap = colorMap
			DALILights.scenesMap = map
		}
		
		return Observation(stop: { 
			updatingSocket.disconnect()
			updatingSocket = nil
		}, id: "lights")
	}
}
