import Foundation
import UIKit
import WebRTC
import ReplayKit

public class NativeVideoView: UIView {
    public enum BoxFit {
        case fit
        case fill
    }

    public var fit: BoxFit = .fill {
        didSet {
            setNeedsLayout()
        }
    }

    public var mirror: Bool = false {
        didSet {
            guard oldValue != mirror else { return }
            update(mirror: mirror)
        }
    }

    /// Size of the actual video, this will change when the publisher
    /// changes dimensions of the video such as rotating etc.
    public private(set) var dimensions: Dimensions? {
        didSet {
            guard oldValue != dimensions else { return }

            // force layout
            setNeedsLayout()

            // notify dimensions update
            // guard let dimensions = dimensions else { return }

            // track?.notify { [weak track] in
            //    guard let track = track else { return }
            //    $0.track(track, videoView: self, didUpdate: dimensions)
            // }
        }
    }

    /// Size of this view (used to notify delegates), we are not yet using delegates though, no idea if they are necessary to begin with, will see...
    /// usually should be equal to `frame.size`
    public private(set) var viewSize: CGSize {
        didSet {
            guard oldValue != viewSize else { return }
            // notify viewSize update
            // track?.notify { $0.track(self.track!, videoView: self, didUpdate: self.viewSize) }
        }
    }

    override init(frame: CGRect) {
//        let newFrame = CGRect(x: 0.0, y: 0.0, width: 480, height: 720)
//        self.viewSize = newFrame.size
//        super.init(frame: newFrame)
        
        // TODO: fix me as this frame has bad sizing...
        self.viewSize = frame.size
        super.init(frame: frame)
        shouldPrepare()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public private(set) lazy var rendererView: RTCVideoRenderer = {
        NativeVideoView.createNativeRendererView(delegate: self)
    }()

    /// Calls addRenderer and/or removeRenderer internally for convenience.
    public var track: RTCVideoTrack? {
        didSet {
            if let oldValue = oldValue {
                oldValue.remove(rendererView)
                // oldValue.notify { $0.track(oldValue, didDetach: self) }
            }
//            print("Adding renderer for a track", track, rendererView)
            track?.add(rendererView)
            // track?.notify { [weak track] in
            //     guard let track = track else { return }
            //     $0.track(track, didAttach: self)
            // }
        }
    }

    func shouldPrepare() {
        guard let rendererView = rendererView as? UIView else { return }

        rendererView.translatesAutoresizingMaskIntoConstraints = true
        addSubview(rendererView)
        shouldLayout()
    }

    func shouldLayout() {
        setNeedsLayout()
        
        guard let rendererView = rendererView as? UIView else { return }
        
        // TODO: handle this dimensions here, should have something in common with the real video
//        if dimensions == nil {
//            print("Setting renderer to hidden, why though?")
//        }

        // hard code if for now...
        let dimensions = Dimensions(width: 480, height: 720)

        if case .fill = fit {
            let vSize = CGSize(width: 240, height: 360)
            var size = vSize
            
            let widthRatio = size.width / CGFloat(dimensions.width)
            let heightRatio = size.height / CGFloat(dimensions.height)

            if heightRatio > widthRatio {
                size.width = size.height / CGFloat(dimensions.height) * CGFloat(dimensions.width)
            } else if widthRatio > heightRatio {
                size.height = size.width / CGFloat(dimensions.width) * CGFloat(dimensions.height)
            }

            // center layout
            rendererView.frame = CGRect(x: -((size.width - vSize.width) / 2),
                                        y: -((size.height - vSize.height) / 2),
                                        width: size.width,
                                        height: size.height)

        } else {
            rendererView.frame = bounds
        }
        rendererView.isHidden = false
    }

    private static let mirrorTransform = CGAffineTransform(scaleX: -1.0, y: 1.0)

    private func update(mirror: Bool) {
        let layer = self.layer

        layer.setAffineTransform(mirror ? NativeVideoView.mirrorTransform : .identity)
    }

    public static func isMetalAvailable() -> Bool {
        MTLCreateSystemDefaultDevice() != nil
    }

    private static func createNativeRendererView(delegate: RTCVideoViewDelegate) -> RTCVideoRenderer {
        DispatchQueue.webRTC.sync {
            let view: RTCVideoRenderer

            if isMetalAvailable() {
                // debugPrint("Using RTCMTLVideoView for VideoView's Renderer")
                let mtlView = RTCMTLVideoView()
                // use .fit here to match macOS behavior and
                // manually calculate .fill if necessary
                mtlView.contentMode = .scaleAspectFit
                mtlView.videoContentMode = .scaleAspectFit
                mtlView.delegate = delegate
                view = mtlView
            } else {
                // debugPrint("Using RTCEAGLVideoView for VideoView's Renderer")
                let glView = RTCEAGLVideoView()
                glView.contentMode = .scaleAspectFit
                glView.delegate = delegate
                view = glView
            }

            return view
        }
    }
}

extension NativeVideoView: RTCVideoViewDelegate {

    public func videoView(_: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        guard let width = Int32(exactly: size.width),
              let height = Int32(exactly: size.height) else {
            // CGSize is used by WebRTC but this should always be an integer
            debugPrint("VideoView: size width/height is not an integer")
            return
        }

        guard width > 1, height > 1 else {
            // Handle known issue where the delegate (rarely) reports dimensions of 1x1
            // which causes [MTLTextureDescriptorInternal validateWithDevice] to crash.
            debugPrint("VideoView: size is 1x1, ignoring...")
            return
        }

        DispatchQueue.main.async {
            self.dimensions = Dimensions(width: width,
                                         height: height)
        }
    }
}

