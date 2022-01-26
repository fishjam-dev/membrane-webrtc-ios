import Foundation
import UIKit
import WebRTC
import ReplayKit


public protocol NativeVideoViewDelegate: AnyObject {
    func didChange(dimensions: Dimensions);
}

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

    // TODO: handle device rotation, for now assume that is held vertically
    /// Dimensions can change dynamically due to RTC changing the resolution itself or by rotation
    public private(set) var dimensions: Dimensions? {
        didSet {
            guard oldValue != dimensions else { return }

            shouldLayout()

            // notify dimensions update
            
            guard let dimensions = dimensions else { return }
            
            self.delegate?.didChange(dimensions: dimensions)
        }
    }

    /// usually should be equal to `frame.size`
    public private(set) var viewSize: CGSize {
        didSet {
            guard oldValue != viewSize else { return }
        }
    }

    override init(frame: CGRect) {
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
            }
            track?.add(rendererView)
        }
    }
    
    public weak var delegate: NativeVideoViewDelegate?

    func shouldPrepare() {
        guard let rendererView = rendererView as? UIView else { return }

        rendererView.translatesAutoresizingMaskIntoConstraints = true
        addSubview(rendererView)
        shouldLayout()
    }

    func shouldLayout() {
        setNeedsLayout()
        self.viewSize = frame.size
        
        guard let rendererView = rendererView as? UIView else { return }
        
        guard let dimensions = self.dimensions else {
            rendererView.isHidden = true
            return
        }

        // FIXME: this fill behaviour does not work well...
        if case .fill = fit {
            var size = self.viewSize
            
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
            rendererView.frame = bounds
        }
        // FIXME: ignore fill and always do the fit unless it gets fixed up
        rendererView.frame = bounds
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
                let mtlView = RTCMTLVideoView()
                mtlView.contentMode = .scaleAspectFit
                mtlView.videoContentMode = .scaleAspectFit
                mtlView.delegate = delegate
                view = mtlView
            } else {
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
            return
        }

        DispatchQueue.main.async {
            self.dimensions = Dimensions(width: width,
                                         height: height)
        }
    }
}

