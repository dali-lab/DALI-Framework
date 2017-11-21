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

/**
A member of DALI

The user object contains as much data as is allowed to a general client by the api
 */
public struct DALIMember {
	// MARK: - Properties
	/// The current member
	public static var current: DALIMember? {
		return DALIapi.config.member
	}
	
	private var name_in: String
	private var gender_in: String?
	private var email_in: String
	private var photoURL_in: String
	private var website_in: String?
	private var linkedin_in: String?
	private var greeting_in: String?
	private var githubUsername_in: String?
	private var coverPhoto_in: String?
	private var googlePhotoURL_in: String
	private var location_in: CLLocation?
	private var jobTitle_in: String?
	private var skills_in: [String]?
	internal var json: JSON
	
	/// User's full name (eg. John Kotz)
	public var name: String {
		get { return name_in }
		set { name_in = newValue; self.dirty_in = true}
	}
	/// User's entered gender
	public var gender: String? {
		get { return gender_in }
		set { gender_in = newValue; self.dirty_in = true}
	}
	/// User's email address
	public var email: String {
		get { return email_in }
		set { email_in = newValue; self.dirty_in = true}
	}
	/// URL to the user's photo
	public var photoURL: String {
		get { return photoURL_in }
		set { photoURL_in = newValue; self.dirty_in = true}
	}
	/// URL to the user's website
	public var website: String? {
		get { return website_in }
		set { website_in = newValue; self.dirty_in = true}
	}
	/// URL to the user's linkedin
	public var linkedin: String? {
		get { return linkedin_in }
		set { linkedin_in = newValue; self.dirty_in = true}
	}
	/// User's greeting
	public var greeting: String? {
		get { return greeting_in }
		set { greeting_in = newValue; self.dirty_in = true}
	}
	/// User's Github username
	public var githubUsername: String? {
		get { return githubUsername_in }
		set { githubUsername_in = newValue; self.dirty_in = true}
	}
	/// URL to user's cover photo
	public var coverPhoto: String? {
		get { return coverPhoto_in }
		set { coverPhoto_in = newValue; self.dirty_in = true}
	}
	/// URL to user's goolge photo
	public var googlePhotoURL: String {
		get { return googlePhotoURL_in }
		set { googlePhotoURL_in = newValue; self.dirty_in = true}
	}
	/// User's chosen origin location (data used by mappy)
	public var location: CLLocation? {
		get { return location_in }
		set { location_in = newValue; self.dirty_in = true}
	}
	/// User's job title
	public var jobTitle: String? {
		get { return jobTitle_in }
		set { jobTitle_in = newValue; self.dirty_in = true}
	}
	/// A list of skills the user has listed for themselves
	public var skills: [String]? {
		get { return skills_in }
		set { skills_in = newValue; self.dirty_in = true}
	}
	
	private var id_in: String
	private var dirty_in: Bool
	
	/// The user is an admin
	public private(set) var isAdmin: Bool = false
	
	/// The identifier used by the server
	public var id: String {
		return id_in
	}
	/// Signifies if data has been changed in the object without saving to the server
	public var dirty: Bool {
		return dirty_in
	}
	
	// MARK: - Functions
	
	/**
		Parses a json object and returns a DALIUser object if it can find all the required information
	
		- parameter object: `JSON` object used to generate the user
	
		- returns: `DALIUser?` - The user object that was generated, if it could
	 */
	public static func parse(_ object: JSON) -> DALIMember? {
		guard let dict = object.dictionary else {
			return nil
		}
		
		guard	let name = dict["fullName"]?.string,
				let email = dict["email"]?.string,
				let photoURL = dict["photoUrl"]?.string,
				let googlePhotoURL = dict["googlePhotoUrl"]?.string else {
			return nil
		}
		
		guard let id = dict["id"]?.string else {
			return nil
		}
		
		let location = dict["location"]?.arrayObject as? [Double]
		
		let user = DALIMember(
			name_in: name,
			gender_in: dict["gender"]?.string,
			email_in: email,
			photoURL_in: photoURL,
			website_in: dict["website"]?.string,
			linkedin_in: dict["linkedin"]?.string,
			greeting_in: dict["greeting"]?.string,
			githubUsername_in: dict["githubUsername"]?.string,
			coverPhoto_in: dict["coverPhoto"]?.string,
			googlePhotoURL_in: googlePhotoURL,
			location_in: location != nil ? CLLocation.init(latitude: location![0], longitude: location![1]) : nil,
			jobTitle_in: dict["jobTitle"]?.string,
			skills_in: dict["skills"]?.arrayObject as? [String],
			json: object,
			id_in: id,
			dirty_in: false,
			isAdmin: dict["isAdmin"]?.bool ?? false
		)
		
		return user
	}
}
