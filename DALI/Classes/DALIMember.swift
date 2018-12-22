//
//  DALIUser.swift
//  DALIapi
//
//  Created by John Kotz on 7/29/17.
//  Copyright © 2017 DALI Lab. All rights reserved.
//

import Foundation
import CoreLocation
import SwiftyJSON
import FutureKit

/**
A member of DALI

The user object contains as much data as is allowed to a general client by the api
 */
public class DALIMember: Equatable {
	// MARK: - Properties
	/// The current member
	public static var current: DALIMember? {
		return DALIapi.config.member
	}
    
	internal var json: JSON
	
	/// User's full name (eg. John Kotz)
	public var name: String
	/// User's entered gender
	public var gender: String?
	/// User's email address
	public var email: String
	/// URL to the user's photo
	public var photoURL: String
	/// URL to the user's website
	public var website: String?
	/// URL to the user's linkedin
	public var linkedin: String?
	/// User's greeting
	public var greeting: String?
	/// User's Github username
	public var githubUsername: String?
	/// URL to user's cover photo
	public var coverPhoto: String?
	/// URL to user's goolge photo
	public var googlePhotoURL: String
	/// User's chosen origin location (data used by mappy)
	public var location: CLLocation?
	/// User's job title
	public var jobTitle: String?
	/// A list of skills the user has listed for themselves
	public var skills: [String]?
	
	/// The user is an admin
	public private(set) var isAdmin: Bool = false
	
	/// The identifier used by the server
	public var id: String
	
	// MARK: - Functions
    
    init?(json: JSON) {
        guard let dict = json.dictionary else {
            return nil
        }
        
        guard let name = dict["fullName"]?.string,
            let email = dict["email"]?.string,
            let photoURL = dict["photoUrl"]?.string,
            let googlePhotoURL = dict["googlePhotoUrl"]?.string else {
                return nil
        }
        
        guard let id = dict["id"]?.string else {
            return nil
        }
        
        if let location = dict["location"]?.arrayObject as? [Double] {
            self.location = CLLocation.init(latitude: location[0], longitude: location[1])
        }
        self.json = json
        self.name = name
        self.gender = dict["gender"]?.string
        self.email = email
        self.photoURL = photoURL
        self.website = dict["website"]?.string
        self.linkedin = dict["linkedin"]?.string
        self.greeting = dict["greeting"]?.string
        self.githubUsername = dict["githubUsername"]?.string
        self.coverPhoto = dict["coverPhoto"]?.string
        self.googlePhotoURL = googlePhotoURL
        self.jobTitle = dict["jobTitle"]?.string
        self.skills = dict["skills"]?.arrayObject as? [String]
        self.isAdmin = dict["isAdmin"]?.bool ?? false
        self.id = id
    }
    
    public static func == (lhs: DALIMember, rhs: DALIMember) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func get(id: String) -> Future<DALIMember> {
        let promise = Promise<DALIMember>()
        
        ServerCommunicator.get(url: "\(DALIapi.config.serverURL)/api/users/\(id)") { (json, code, error) in
            if let json = json, let member = DALIMember(json: json) {
                promise.completeWithSuccess(member)
            } else if let error = error {
                promise.completeWithFail(error)
            } else {
                promise.completeWithFail("Failed to get user")
            }
        }
        
        return promise.future
    }
}
