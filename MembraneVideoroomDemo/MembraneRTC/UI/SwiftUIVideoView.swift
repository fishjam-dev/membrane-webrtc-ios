import Foundation
import UIKit
import SwiftUI
import WebRTC

internal class SwiftUIVideViewReceiver: VideoViewDelegate {
    @Binding var dimensions: Dimensions?
    
    init(dimensions: Binding<Dimensions?> = .constant(nil)) {
        self._dimensions = dimensions
    }
    
    func didChange(dimensions: Dimensions) {
        DispatchQueue.main.async {
            self.dimensions = dimensions
        }
    }
}

/// A SwiftUI component wrapping underneath a `NativeVideoView`.
public struct SwiftUIVideoView: UIViewRepresentable {
    let track: RTCVideoTrack
    let layout: VideoView.Layout
    let mirror: Bool
    
    @Binding var dimensions: Dimensions?
    
    let receiverDelegate: SwiftUIVideViewReceiver
    
    public init(
        _ track: RTCVideoTrack, layout: VideoView.Layout = .fill, mirror: Bool = false,
        dimensions: Binding<Dimensions?> = .constant(nil)
    ) {
        self.track = track
        self.layout = layout
        self.mirror = mirror
        self._dimensions = dimensions
        
        self.receiverDelegate = SwiftUIVideViewReceiver(dimensions: dimensions)
    }
    
    public func makeUIView(context: Context) -> VideoView {
        let view = VideoView()
        view.delegate = self.receiverDelegate
        
        updateUIView(view, context: context)
        return view
    }
    
    public func updateUIView(_ videoView: VideoView, context: Context) {
        if videoView.track != track {
            videoView.track = track
        }
        videoView.layout = layout
        videoView.mirror = mirror
        
        videoView.delegate = self.receiverDelegate
    }
    
    public static func dismantleUIView(_ videoView: VideoView, coordinator: ()) {
        videoView.track = nil
    }
}
