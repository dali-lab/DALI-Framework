//
//  daliAPI.swift
//  
//
//  Created by John Kotz on 7/23/17.
//
//

import UIKit
import SwiftyJSON
import SocketIO
import FutureKit

/**
Static class to configure and handle general requests for the DALI api framework
*/
public class DALIapi {
	private static var unProtConfig: DALIConfig!
	/// The current configuration being used by the framework
	public static var config: DALIConfig {
		if self.unProtConfig == nil {
			fatalError("DALIapi: Config missing! You are required to have a configuration\n" +
					   "Run:\nlet config = DALIConfig(dict: NSDictionary(contentsOfFile: filePath))\n" +
					   "DALIapi.configure(config)\n" +
					   "before you use it")
		}
		return unProtConfig!
	}
	
	internal static let socketManager = SocketManager(socketURL: DALIapi.config.serverURLobject)
	
	/// Defines if the user is signed in
    public static var isSignedIn: Bool {
        return config.member != nil
    }
	
	/**
	A callback reporting either success or failure in the requested action
	
	- parameter success: Flag indicating success in the action
	- parameter error: Error encountered (if any)
	*/
	public typealias SuccessCallback = (_ success: Bool, _ error: DALIError.General?) -> Void
	
	/**
	Configures the entire framework
	
	NOTE: Make sure to run this configure method before using anything on the API
	*/
	public static func configure(config: DALIConfig) {
		self.unProtConfig = config
		
		if config.enableSockets {
			enableSockets()
			self.socketManager.config = SocketIOClientConfiguration(arrayLiteral: SocketIOClientConfiguration.Element.forceWebsockets(config.forceWebsockets))
		}
	}
	
	/// Enables the use of sockets
	public static func enableSockets() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.goingForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.goingBackground), name: UIApplication.willResignActiveNotification, object: nil)
	}
	
	/// Disables all sockets used by the API
	public static func disableSockets() {
		
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
		
		if let eventSocket = DALIEvent.updatesSocket, eventSocket.status != .disconnected {
			eventSocket.disconnect()
		}
		if let locationSocket = DALILocation.updatingSocket, locationSocket.status != .disconnected {
			locationSocket.disconnect()
		}
		if let lightsSocket = DALILights.updatingSocket, lightsSocket.status != .disconnected {
			lightsSocket.disconnect()
		}
		if let socket = DALIFood.socket, socket.status != .disconnected {
			socket.disconnect()
		}
	}
	
	/// Called when switching to background mode, this function will close sockets of autoswitching is enabled
	@objc internal static func goingBackground() {
		if config.socketAutoSwitching {
			if let eventSocket = DALIEvent.updatesSocket, eventSocket.status != .disconnected {
				eventSocket.disconnect()
			}
			if let locationSocket = DALILocation.updatingSocket, locationSocket.status != .disconnected {
				locationSocket.disconnect()
			}
			if let updatingSocket = DALILights.updatingSocket, updatingSocket.status != .disconnected {
				updatingSocket.disconnect()
			}
			if let socket = DALIFood.socket, socket.status != .disconnected {
				socket.disconnect()
			}
		}
	}
	
	/// Called when switching to forground mode, this function will reconnect sockets of autoswitching is enabled
	@objc internal static func goingForeground() {
		if config.socketAutoSwitching {
			if let eventSocket = DALIEvent.updatesSocket, eventSocket.status == .disconnected {
				eventSocket.connect()
			}
			if let locationSocket = DALILocation.updatingSocket, locationSocket.status == .disconnected {
				locationSocket.connect()
			}
			if let updatingSocket = DALILights.updatingSocket, updatingSocket.status == .disconnected {
				updatingSocket.connect()
			}
			if let socket = DALIFood.socket, socket.status == .disconnected {
				socket.connect()
			}
		}
	}
	
	/**
	Signs in on the server using Google Signin provided server auth code
	
	- parameter authCode: The authCode provided by Google signin
	- parameter done: Function called when signin is complete
	- parameter success: The signin completed correctly
	- parameter error: The error, if any, encountered
	*/
	public static func signin(authCode: String) -> Future<DALIMember> {
		// One way or the other are we already authenticated
		if (config.token != nil || config.apiKey != nil) {
			return Future(fail: DALIError.General.Unauthorized)
		}
		
        return ServerCommunicator.get(url: "\(config.serverURL)/api/auth/google/callback?code=\(authCode)").onSuccess { (response) -> DALIMember in
            guard let json = response.json,
                let token = json["token"].string,
                let member = DALIMember(json: json["user"])
            else {
                throw response.assertedError
            }
            
            self.unProtConfig.token = token
            self.unProtConfig.member = member
            
            return member
        }
	}
	
	/**
	Signs in on the server using access and refresh tokens provided by Google Signin. Will not sign in if already signed in
	
	- parameter accessToken: The access token provided by Google signin
	- parameter refreshToken: The refresh token from Google siginin
	- parameter done: Function called when signin is complete
	- parameter success: The signin completed correctly
	- parameter error: The error, if any, encountered
	*/
	public static func signin(accessToken: String, refreshToken: String) -> Future<DALIMember> {
		return self.signin(accessToken: accessToken, refreshToken: refreshToken, forced: false)
	}
	
	/**
	Signs in on the server using access and refresh tokens provided by Google Signin
	
	- parameter accessToken: The access token provided by Google signin
	- parameter refreshToken: The refresh token from Google siginin
	- parameter forced: Flag forces signin even if there is already a token avialable
	- parameter done: Function called when signin is complete
	- parameter success: The signin completed correctly
	- parameter error: The error, if any, encountered
	*/
	public static func signin(accessToken: String, refreshToken: String, forced: Bool) -> Future<DALIMember> {
		// One way or the other are we already authenticated
		if ((config.token != nil || config.apiKey != nil) && !forced) {
			return Future(fail: DALIError.General.Unauthorized)
		}
		
		let package = ["access_token": accessToken, "refresh_token": refreshToken]
		
		do {
            return try ServerCommunicator.post(url: "\(config.serverURL)/api/signin", json: JSON(package)).onSuccess(block: { (response) -> DALIMember in
                guard let json = response.json?.dictionary,
                    let token = json["token"]?.string,
                    let userObj = json["user"],
                    let member = DALIMember(json: userObj)
                else {
                    throw response.assertedError
                }
                
                self.unProtConfig.token = token
                self.unProtConfig.member = member
                return member
            })
		} catch {
			return Future(fail: error)
		}
	}

	/**
	Silently updates the current member object from the server
	
	- parameter callback: A function to be called when the opperation is complete
	- parameter member: The updated memeber object
	*/
	public static func silentMemberUpdate() -> Future<DALIMember?> {
        return ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/users/me").onSuccess { (response) in
            guard let data = response.json, let member = DALIMember(json: data) else {
                return nil
            }
            self.unProtConfig.member = member
            return member
        }
	}
	
	/// Signs out of your account on the API
	public static func signOut() {
		config.token = nil
		config.member = nil
	}
	
	/**
	Sends a notification to EVERY device with the given tag set to true
	
	- parameter title: The title of the notification
	- parameter subtitle: The main message to be sent
	- parameter tag: The tag that OneSignal will use to identify recipient devices
	- parameter callback: The function that iwll be called when the process is done
	- parameter success: The notification was sent correctly
	- parameter error: The error, if any, encountered
	*/
	public static func sendSimpleNotification(with title: String, and subtitle: String, to tag: String) -> Future<Void> {
		let dict: [String: Any] = [
			"title": title,
			"subtitle": subtitle,
			"tag": tag
		]
		
		do {
            return try ServerCommunicator.post(url: "\(DALIapi.config.serverURL)/api/notify", json: JSON(dict)).onSuccess(block: { (response) in
                if !response.success {
                    throw response.assertedError
                }
            })
		} catch {
			return Future(fail: error)
		}
	}
	
	/// Asserts that a member is signed in
	internal static func assertUser(funcName: String) {
		if (DALIapi.config.member == nil) {
			fatalError("API key programs may not modify location records! Don't use \(funcName) if you configure with an API key. If you are getting this error and you do not configure using an API key, consult John Kotz")
		}
	}
}
