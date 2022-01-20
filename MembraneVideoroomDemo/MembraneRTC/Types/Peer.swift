//
//  File.swift
//  
//
//  Created by Jakub Perzylo on 14/01/2022.
//

import Foundation
import UIKit

public struct Peer: Codable {
    public let id: String
    public let metadata: Metadata
    public let trackIdToMetadata: [String: Metadata]?
    
    public init(id: String, metadata: Metadata, trackIdToMetadata: [String: Metadata]) {
        self.id = id
        self.metadata = metadata
        self.trackIdToMetadata = trackIdToMetadata
    }
}
