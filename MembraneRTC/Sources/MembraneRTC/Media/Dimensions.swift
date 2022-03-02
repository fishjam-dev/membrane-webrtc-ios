import CoreMedia
import Foundation

// TODO: reference livekit files as this is purely taken from them...
public typealias Dimensions = CMVideoDimensions

public extension Dimensions {
    static let aspect16By9 = 16.0 / 9.0
    static let aspect4By3 = 4.0 / 3.0
}

extension Dimensions: Equatable {
    public static func == (lhs: Dimensions, rhs: Dimensions) -> Bool {
        lhs.width == rhs.width &&
            lhs.height == rhs.height
    }
}

extension Dimensions {
    func computeSuggestedPresets() -> [VideoParameters] {
        let aspect = Double(width) / Double(height)
        if abs(aspect - Dimensions.aspect16By9) < abs(aspect - Dimensions.aspect4By3) {
            return VideoParameters.presets169
        }
        return VideoParameters.presets43
    }

    func computeSuggestedPreset(in presets: [VideoParameters]) -> VideoParameters {
        assert(!presets.isEmpty)
        var result = presets[0]
        for preset in presets {
            if width >= preset.dimensions.width, height >= preset.dimensions.height {
                result = preset
            }
        }
        return result
    }

    func computeSuggestedPresetIndex(in presets: [VideoParameters]) -> Int {
        assert(!presets.isEmpty)
        var result = 0
        for preset in presets {
            if width >= preset.dimensions.width, height >= preset.dimensions.height {
                result += 1
            }
        }
        return result
    }
    
    public func flip() -> Dimensions {
        return Dimensions(width: height, height: width)
    }
}
