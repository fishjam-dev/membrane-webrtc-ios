//
//  Metadata.swift
//  MembraneVideoroomDemo
//
//  Created by Jakub Perzylo on 20/01/2022.
//

import Foundation


// NOTE: by default swift is not able to decode type of [String: Any] as
// 'Any' is not decodable. For now we will assume that the metadata is a dictionary
// consisting of keys and values all being strings. Once this is wrong please consider
// refactoring the json serialization/deserialization


public typealias Metadata = [String: String]
