//
//  Enumerations.swift
//  Pods
//
//  Created by John Kotz on 9/5/17.
//
//

import Foundation

extension Notification.Name {
	enum Custom {
		static let SocketsDisabled = Notification.Name(rawValue: "SocketsDisabled")
		static let SocketsEnabled = Notification.Name(rawValue: "SocketsEnabled")
	}
}

/**
An object that allows the user to control socket observations.

You receive an object of this class when you observe some data.
	You may use this object to close the observation when you are done.
	The observation will automatically be closed when the app terminates,
	and the socket will be temporarily suspended when the app goes into the background.
*/
public struct Observation {
	/// A function to cancel an observation
	public let stop: () -> Void
	/// An identifier of the observation
	public let id: String
}

