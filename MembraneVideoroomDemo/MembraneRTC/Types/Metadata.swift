import Foundation

/// By default swift is not able to decode type of [String: Any] as
/// `Any` is not decodable. For now we will assume that the metadata is a dictionary
/// consisting of keys and values all being strings. Once this is wrong please consider
/// refactoring the json serialization/deserialization or consider making the related type explicit.
public typealias Metadata = [String: String]
