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

public struct Observation {
	public let stop: () -> Void
	public let id: String
}

