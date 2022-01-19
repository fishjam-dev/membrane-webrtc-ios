import Foundation
import UIKit
import SwiftUI
import WebRTC

public struct SwiftUIVideoView: UIViewRepresentable {
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
    self._dimensions = dimensions
    

    // TODO: here we should probably handle some resizing of track, this is at least what the LiveKit does...
  }

  public func makeUIView(context: Context) -> NativeVideoView {
    let view = NativeVideoView()
    updateUIView(view, context: context)
    return view
  }

  public func updateUIView(_ videoView: NativeVideoView, context: Context) {
    videoView.track = track
    videoView.fit = fit
    videoView.mirror = mirror
  }

  public static func dismantleUIView(_ videoView: NativeVideoView, coordinator: ()) {
    videoView.track = nil
  }
}
