//
//  File.swift
//  
//
//  Created by Jakub Perzylo on 14/01/2022.
//

import Foundation

public protocol Event {
    func deserialize(payload: String);
    // either serialize to string or to json object
    func serialize() -> String;
}
