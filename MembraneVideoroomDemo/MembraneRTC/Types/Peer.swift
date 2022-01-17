//
//  File.swift
//  
//
//  Created by Jakub Perzylo on 14/01/2022.
//

import Foundation
import UIKit

public struct Peer {
    public var id: String
    public var metadata: [String: Any]
    public var trackIdToMetadata: [String: Any]
    
    public init(id: String, metadata: [String: Any], trackIdToMetadata: [String: Any]) {
        self.id = id
        self.metadata = metadata
        self.trackIdToMetadata = trackIdToMetadata
    }
}
