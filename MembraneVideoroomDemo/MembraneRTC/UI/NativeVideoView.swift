import Foundation
import WebRTC
import UIKit

public class NativeVideoView: NativeView {
    public enum BoxFit {
        case fit
        case fill
    }

    public var mode: BoxFit = .fill {
        didSet {
            markNeedsLayout()
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
            markNeedsLayout()

            // notify dimensions update
            guard let dimensions = dimensions else { return }

            track?.notify { [weak track] in
                guard let track = track else { return }
                $0.track(track, videoView: self, didUpdate: dimensions)
            }
        }
    }

    /// Size of this view (used to notify delegates)
    /// usually should be equal to `frame.size`
    public private(set) var viewSize: CGSize {
        didSet {
            guard oldValue != viewSize else { return }
            // notify viewSize update
            track?.notify { $0.track(self.track!, videoView: self, didUpdate: self.viewSize) }
        }
    }

    override init(frame: CGRect) {
        self.viewSize = frame.size
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public private(set) lazy var rendererView: RTCVideoRenderer = {
        VideoView.createNativeRendererView(delegate: self)
    }()

    /// Calls addRenderer and/or removeRenderer internally for convenience.
    public var track: VideoTrack? {
        didSet {
            if let oldValue = oldValue {
                oldValue.remove(rendererView)
                // oldValue.notify { $0.track(oldValue, didDetach: self) }
            }
            track?.add(rendererView)
            // track?.notify { [weak track] in
            //     guard let track = track else { return }
            //     $0.track(track, didAttach: self)
            // }
        }
    }

    override func shouldPrepare() {
        super.shouldPrepare()

        guard let rendererView = rendererView as? NativeViewType else { return }

        rendererView.translatesAutoresizingMaskIntoConstraints = true
        addSubview(rendererView)
        shouldLayout()
    }

    override func shouldLayout() {
        super.shouldLayout()
        self.viewSize = frame.size

        guard let rendererView = rendererView as? NativeViewType else { return }

        guard let dimensions = dimensions else {
            rendererView.isHidden = true
            return
        }

        if case .fill = mode {
            // manual calculation for .fill

            var size = viewSize
            let widthRatio = size.width / CGFloat(dimensions.width)
            let heightRatio = size.height / CGFloat(dimensions.height)

            if heightRatio > widthRatio {
                size.width = size.height / CGFloat(dimensions.height) * CGFloat(dimensions.width)
            } else if widthRatio > heightRatio {
                size.height = size.width / CGFloat(dimensions.width) * CGFloat(dimensions.height)
            }

            // center layout
            rendererView.frame = CGRect(x: -((size.width - viewSize.width) / 2),
                                        y: -((size.height - viewSize.height) / 2),
                                        width: size.width,
                                        height: size.height)

        } else {
            //
            rendererView.frame = bounds
        }

        rendererView.isHidden = false
    }

    private static let mirrorTransform = CGAffineTransform(scaleX: -1.0, y: 1.0)

    private func update(mirror: Bool) {
        let layer = self.layer

        layer.setAffineTransform(mirror ? VideoView.mirrorTransform : .identity)
    }

    public static func isMetalAvailable() -> Bool {
        MTLCreateSystemDefaultDevice() != nil
    }

    private static func createNativeRendererView(delegate: RTCVideoViewDelegate) -> RTCVideoRenderer {
        DispatchQueue.webRTC.sync {
            let view: RTCVideoRenderer

            if isMetalAvailable() {
                logger.debug("Using RTCMTLVideoView for VideoView's Renderer")
                let mtlView = RTCMTLVideoView()
                // use .fit here to match macOS behavior and
                // manually calculate .fill if necessary
                mtlView.contentMode = .scaleAspectFit
                mtlView.videoContentMode = .scaleAspectFit
                mtlView.delegate = delegate
                view = mtlView
            } else {
                logger.debug("Using RTCEAGLVideoView for VideoView's Renderer")
                let glView = RTCEAGLVideoView()
                glView.contentMode = .scaleAspectFit
                glView.delegate = delegate
                view = glView
            }

            return view
        }
    }
}

extension VideoView: RTCVideoViewDelegate {

    public func videoView(_: RTCVideoRenderer, didChangeVideoSize size: CGSize) {

        logger.debug("VideoView: didChangeVideoSize \(size)")

        guard let width = Int32(exactly: size.width),
              let height = Int32(exactly: size.height) else {
            // CGSize is used by WebRTC but this should always be an integer
            logger.warning("VideoView: size width/height is not an integer")
            return
        }

        guard width > 1, height > 1 else {
            // Handle known issue where the delegate (rarely) reports dimensions of 1x1
            // which causes [MTLTextureDescriptorInternal validateWithDevice] to crash.
            logger.warning("VideoView: size is 1x1, ignoring...")
            return
        }

        DispatchQueue.main.async {
            self.dimensions = Dimensions(width: width,
                                         height: height)
        }
    }
}

