import Foundation

/// A bunch of application specific constants
struct Constants {
    static func getRtcEngineUrl() -> String {
        return (Bundle.main.infoDictionary?["rtc_engine_url"] as! String).replacingOccurrences(of: "\\", with: "")
    }

    /// App Group used for communicating with `Broadcast Upload Extension`
    static let appGroup = "group.com.swmansion.membrane"
    /// Bundle identifier of the `Broadcast Upload Extension` responsible for capturing screen and sending it to the applicaction
    static let screencastExtensionBundleId = "com.swmansion.MembraneVideoroomDemo.ScreenBroadcastExt"
}
