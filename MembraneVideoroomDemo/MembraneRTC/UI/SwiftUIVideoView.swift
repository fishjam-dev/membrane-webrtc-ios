import Foundation
import UIKit

class SwiftUIVideoView: UIViewRepresentable {
  let track: RTCVideoTrack
  let fit: NativeVideoView.BoxFit
  let mirror: Bool

  @Binding var dimensions: Dimensions?

  public init(
    _ track: RTCVideoTrack, fit: NativeVideoView.BoxFit = .fill, mirror: Bool = false,
    dimensions: Binding<Dimensions?> = .constant(nil)
  ) {
    self.track = track
    self.fit = fit
    self.mirror = mirror
    self.dimensions = dimensions
    

    // TODO: here we should probably handle some resizing of track, this is at least what the LiveKit does...
  }

  public func makeUIView(context: Context) -> VideoView {
    let view = NativeVideoView()
    updateUIView(view, context: context)
    return view
  }

  public func updateUIView(_ videoView: VideoView, context: Context) {
    videoView.track = track
    videoView.mode = mode
    videoView.mirrored = mirrored
  }

  public static func dismantleUIView(_ videoView: VideoView, coordinator: ()) {
    videoView.track = nil
  }
}
