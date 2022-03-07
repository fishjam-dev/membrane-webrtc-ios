/// A bunch of application specific constants
struct Constants {
    /// Remote media serer's url
    static let rtcEngineUrl = "https://dscout-us.membrane.work"
    
    // for local development
    // static let rtcEngineUrl = "http://192.168.83.178:4000"
    
    /// App Group used for communicating with `Broadcast Upload Extension`
    static let appGroup = "group.com.swmansion.membrane"
    /// Bundle identifier of the `Broadcast Upload Extension` responsible for capturing screen and sending it to the applicaction
    static let screencastExtensionBundleId = "com.swmansion.MembraneVideoroomDemo.ScreenBroadcastExt"
}
