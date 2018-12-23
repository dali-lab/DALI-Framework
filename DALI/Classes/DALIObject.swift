//
//  DALIObject.swift
//  ChromaColorPicker
//
//  Created by John Kotz on 12/22/18.
//

import Foundation
import FutureKit

protocol DALIObject {
    func retreiveRequirements() -> Future<Self>
}

func retriveAllRequirements<T:DALIObject>(on objects: [T]) -> Future<[T]> {
    let futures = objects.map { (object) -> Future<T> in
        return object.retreiveRequirements()
    }
    return FutureBatch(futures).future.map { (results) -> [T] in
        return results as? [T] ?? []
    }
}
