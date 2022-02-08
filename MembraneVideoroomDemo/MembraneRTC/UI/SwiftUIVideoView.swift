import Foundation
import UIKit
import SwiftUI
import WebRTC

internal class SwiftUIVideViewReceiver: NativeVideoViewDelegate {
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
    let fit: NativeVideoView.BoxFit
    let mirror: Bool
    
    @Binding var dimensions: Dimensions?
    
    let receiverDelegate: SwiftUIVideViewReceiver
    
    public init(
        _ track: RTCVideoTrack, fit: NativeVideoView.BoxFit = .fill, mirror: Bool = false,
        dimensions: Binding<Dimensions?> = .constant(nil)
    ) {
        self.track = track
        self.fit = fit
        self.mirror = mirror
        self._dimensions = dimensions
        
        self.receiverDelegate = SwiftUIVideViewReceiver(dimensions: dimensions)
    }
    
    public func makeUIView(context: Context) -> NativeVideoView {
        let view = NativeVideoView()
        view.delegate = self.receiverDelegate
        
        updateUIView(view, context: context)
        return view
    }
    
    public func updateUIView(_ videoView: NativeVideoView, context: Context) {
        if videoView.track != track {
            videoView.track = track
        }
        
        videoView.fit = fit
        videoView.mirror = mirror
    }
    
    public static func dismantleUIView(_ videoView: NativeVideoView, coordinator: ()) {
        videoView.track = nil
    }
}
