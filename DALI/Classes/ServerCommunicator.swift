//
//  ServerCommunications.swift
//  DALIapi
//
//  Created by John Kotz on 7/28/17.
//  Copyright © 2017 DALI Lab. All rights reserved.
//

import Foundation
import SwiftyJSON
import SocketIO
import FutureKit

class ServerCommunicator {
	private static var config: DALIConfig {
		return DALIapi.config
	}
	
	static func authenticateSocket(socket: SocketIOClient) {
		socket.emit("authenticate", with: [(config.token ?? config.apiKey) as Any])
	}
	
	// MARK : POST and GET methods
	// ===========================
	
	/**
	Makes a GET request on a given url, calling the callback with the response JSON object when its done
	
	- parameter url: String - The URL you wan to GET from
	- parameter callback: (response: Any)->Void - The callback that will be invoked when the task is done
	- parameter response: The data response from the server
	- parameter code: The code for the response
	- parameter error: The error encountered (if any)
	*/
    static func get(url: String) -> Future<Response> {
        return get(url: url, params: nil)
    }
    
    static func get(url: String, params: [String:String]?) -> Future<Response> {
        return doDataRequest(url: url, httpMethod: "GET", params: params, data: nil)
	}
	
	static func delete(url: String, json: JSON) -> Future<Response> {
        do {
            return delete(url: url, data: try json.rawData())
        } catch {
            return Future(fail: error)
        }
	}
	
	static func delete(url: String, data: Data) -> Future<Response> {
		return doDataRequest(url: url, httpMethod: "DELETE", params: nil, data: data)
	}
	
	/**
	Convenience function for posting JSON data
	
	- parameter url: The URL you want to post to
	- parameter json: A JSON encoded data string to be sent to the server
	- parameter callback: A callback that will be invoked when the process is complete
	- parameter success: Flag indicating success
	- parameter data: The JSON data sent back
	- parameter error: The error encountered (if any)
	*/
    static func post(url: String, json: JSON) -> Future<Response> {
        do {
            return post(url: url, data: try json.rawData())
        } catch {
            return Future(fail: error)
        }
	}
	
	/**
	Makes a POST request to the given url using the given data, using the callback when it is done
	
	- parameter url: String - The URL you want to post to
	- parameter data: Data - A JSON encoded data string to be sent to the server
	- parameter callback: A callback that will be invoked when the process is complete
	- parameter success: Flag indicating success
	- parameter data: The JSON data sent back
	- parameter error: The error encountered (if any)
	*/
	static func post(url: String, data: Data?) -> Future<Response> {
		return doDataRequest(url: url, httpMethod: "POST", params: nil, data: data)
	}
    
    static func put(url: String, json: JSON) -> Future<Response> {
        do {
            return put(url: url, data: try json.rawData())
        } catch {
            return Future(fail: error)
        }
    }
    
    static func put(url: String, data: Data?) -> Future<Response> {
        return doDataRequest(url: url, httpMethod: "PUT", params: nil, data: data)
    }
    
    static func doDataRequest(url: String, httpMethod: String, params: [String:String]?, data: Data?) -> Future<Response> {
        var urlComps = URLComponents(string: url)!
        if let params = params {
            urlComps.queryItems = params.keys.map({ (key) -> URLQueryItem in
                return URLQueryItem(name: key, value: params[key])
            })
        }
        
        var request = URLRequest(url: urlComps.url!)
        request.httpMethod = httpMethod
        request.httpBody = data
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = config.token {
            request.addValue(token, forHTTPHeaderField: "authorization")
        }else if let apiKey = config.apiKey {
            request.addValue(apiKey, forHTTPHeaderField: "apiKey")
        }
        
        let promise = Promise<Response>()
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            let response = Response(response: response, data: data, error: error)
            promise.completeWithSuccess(response)
            }.resume()
        
        return promise.future
    }
    
    struct Response {
        let response: URLResponse?
        let data: Data?
        let error: Error?
        
        // MARK: - Computed variables
        
        var success: Bool {
            return code == 200
        }
        var code: Int? {
            return (response as? HTTPURLResponse)?.statusCode
        }
        
        var jsonError: SwiftyJSONError? {
            guard let data = data else {
                return SwiftyJSONError.notExist
            }
            
            do {
                _ = try JSON.init(data: data)
            } catch is SwiftyJSONError {
                return error as? SwiftyJSONError
            } catch {}
            return nil
        }
        
        var assertedError: Error {
            if error != nil {
                return error!
            } else if generalError != nil {
                return generalError!
            } else if jsonError != nil {
                return jsonError!
            }
            return unknownError
        }
        
        var json: JSON? {
            guard let data = data else {
                return nil
            }
            return try? JSON.init(data: data)
        }
        
        var generalError: DALIError.General? {
            guard let code = code else {
                return nil
            }
            
            switch code {
            case 200: return nil
            case 401: return DALIError.General.Unauthorized
            case 403: fatalError("DALIapi: Provided API Key invalid!")
            case 422: return DALIError.General.Unprocessable
            case 400: return DALIError.General.BadRequest
            case 404: return DALIError.General.Unfound
            default: return nil
            }
        }
        
        var unknownError: DALIError.General {
            let text = data == nil ? nil : String(data: data!, encoding: .utf8)
            return DALIError.General.UnknownError(error: error, text: text, code: code)
        }
    }
}
