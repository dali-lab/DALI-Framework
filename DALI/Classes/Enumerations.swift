//
//  Enumerations.swift
//  Pods
//
//  Created by John Kotz on 9/5/17.
//
//

import Foundation
import EmitterKit

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
    /// The listener this represents
    internal let listener: Listener?
    /// The block that will restart the observation (if possible)
    internal let restartBlock: (() -> Bool)?
    
    init(stop: @escaping () -> Void, id: String = "", listener: Listener? = nil, restartBlock: (() -> Bool)? = nil) {
        self.stop = stop
        self.id = id
        self.listener = listener
        self.restartBlock = restartBlock
    }
    
    /**
     Restart the observation if possible
     
     - note: Not all classes that use Observation support restarting
     
     - returns: Whether restart was successful
     */
    func restart() -> Bool {
        let result = restartBlock?()
        return restartBlock != nil && result!
    }
}

