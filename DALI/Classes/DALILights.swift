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
import FutureKit

/**
A class for controlling the lights in the lab
*/
public class DALILights {
	private static var scenesMap: [String:[String]] = [:]
	private static var scenesAvgColorMap: [String:[String:String]] = [:]
	
	/**
	A group of lights. This is defined as one of the rooms in DALI, each one a grouping of lights that can be controlled
	*/
	public struct Group {
		/// The name of the group
		public let name: String
		/// The formatted name of the group for printing
		public var formattedName: String {
			if name == "tvspace" {
				return "TV Space"
			} else {
				return name.lowercased().replacingOccurrences(of: "pod:", with: "").capitalized
			}
		}
		/// The name the currently set scene
		public let scene: String?
		/// The formated scene name for printing
		public var formattedScene: String? {
			return scene?.capitalized
		}
		/// The current color set for the group
		public let color: String?
		
		/// An average current color. Used for displaying state via color overlay
		public var avgColor: String? {
			if let color = color {
				return color
			}else if let scene = scene {
				return DALILights.scenesAvgColorMap[self.name]?[scene]
			} else {
				return nil
			}
		}
		
		/// Boolean of current power status
		public let isOn: Bool
		/// The scenes available for this group
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
					} else {
						allSet = set
					}
				}
				
				return Array(allSet!).sorted(by: { (string1, string2) -> Bool in
					return string1 == "default" || string1 < string2
				})
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
						} else {
							podsSet = set
						}
					}
				}
				
				return Array(podsSet!).sorted(by: { (string1, string2) -> Bool in
					return string1 == "default" || string1 < string2
				})
			}
			
			if let scenes = DALILights.scenesMap[name] {
				return scenes.sorted(by: { (string1, string2) -> Bool in
					return string1 == "default" || string1 < string2
				})
			} else {
				return []
			}
		}
		
		/// Initialize the group
		internal init(name: String, scene: String?, color: String?, isOn: Bool) {
			self.name = name
			self.scene = scene
			self.color = color
			self.isOn = isOn
		}
		
		/**
		Set the scene of the group
		
		- parameter scene: The scene to set the lights to
		- parameter callback: Called when done
		- parameter success: Was successful
		- parameter error: The error, if any, encountered
		*/
		public func set(scene: String) -> Future<Void> {
			return setValue(value: scene)
		}
		
		/// Used to set the value of the lights. The API uses strings to idenitify actions to take on the lights
		internal func setValue(value: String) -> Future<Void> {
			do {
                return try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/lights/\(name)", json: JSON(["value":value])).onSuccess(block: { (response) in
                    if !response.success {
                        throw response.assertedError
                    }
                })
			} catch {
				return Future(fail: error)
			}
		}
		
		/**
		Set the color of the group
		
		- parameter color: The color to set the lights
		- parameter callback: Called when done
		- parameter success: Was successful
		- parameter error: The error, if any, encountered
		*/
		public func set(color: String) -> Future<Void> {
			return setValue(value: color)
		}
		
		/**
		Set the power
		
		- parameter on: Boolean = the power is on
		- parameter callback: Called when done
		- parameter success: Was successful
		- parameter error: The error, if any, encountered
		*/
		public func set(on: Bool) -> Future<Void> {
			return setValue(value: on ? "on" : "off")
		}
		
		/// All the groups
		public static internal(set) var all = Group(name: "all", scene: nil, color: nil, isOn: false)
		/// The pod groups
		public static internal(set) var pods = Group(name: "pods", scene: nil, color: nil, isOn: false)
	}
	
	internal static var updatingSocket: SocketIOClient!
	
	/**
	Observe all the groups
	
	- parameter callback: Called when done
	- parameter groups: The updated groups
	*/
	public static func oberserveAll(callback: @escaping (_ groups: [Group]) -> Void) -> Observation {
		if updatingSocket == nil {
			updatingSocket = DALIapi.socketManager.socket(forNamespace: "/lights")
			
			updatingSocket.connect()
			
			updatingSocket.on(clientEvent: .connect, callback: { (data, ack) in
				ServerCommunicator.authenticateSocket(socket: updatingSocket)
			})
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
		
        _ = ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/lights/scenes").onSuccess { (response) in
            guard let dict = response.json?.dictionary else {
                return
            }
            
            var map = [String:[String]]()
            var colorMap = [String:[String:String]]()
            
            for entry in dict {
                colorMap[entry.key] = [:]
                if let value = entry.value.array {
                    var array: [String] = []
                    for scene in value {
                        if let sceneDict = scene.dictionary, let scene = sceneDict["name"]?.string {
                            
                            array.append(scene)
                            colorMap[entry.key]![scene] = sceneDict["averageColor"]?.string
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

