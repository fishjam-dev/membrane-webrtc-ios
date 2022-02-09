import Foundation
import UIKit
import WebRTC
import ReplayKit

public protocol NativeVideoViewDelegate: AnyObject {
    func didChange(dimensions: Dimensions);
}

/// `NativeVideoView` is responsible for receiving the `RTCVideoTrack` and accordingly
/// making sure that it gets properly rendered.
///
/// It supports two types of fitting, `fit` and `fill` where the prior tries to keep the original dimensions
/// and the later one tries to fil lthe available space. Additionaly one can set mirror mode to flip the video horizontally,
/// usually expected when displaying the local user's view.
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
    
    /// Dimensions can change dynamically, either when the device changes the orientation
    /// or when the resolution changes adaptively.
    public private(set) var dimensions: Dimensions? {
        didSet {
            guard oldValue != dimensions else { return }
            
            // when the dimensions change force the new layout
            shouldLayout()
            
            guard let dimensions = dimensions else { return }
            self.delegate?.didChange(dimensions: dimensions)
        }
    }
    
    /// usually should be equal to `frame.size`
    private var viewSize: CGSize
    
    override init(frame: CGRect) {
        self.viewSize = frame.size
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public private(set) var rendererView: RTCVideoRenderer?
    
    /// When the track changes,a new renderer gets created and attached to the new track.
    /// To avoid leaking resources the old renderer gets removed from the old track.
    public var track: RTCVideoTrack? {
        didSet {
            if let oldValue = oldValue,
               let rendererView = self.rendererView {
                oldValue.remove(rendererView)
            }
            
            if let track = track {
                // create a new renderer view for the new track
                self.createAndPrepareRenderView()
                
                if let rendererView = rendererView {
                    track.add(rendererView)
                }
            }
            
            shouldLayout()
        }
    }
    
    /// Delegate listening for the view's changes such as dimensions.
    public weak var delegate: NativeVideoViewDelegate?
    
    /// In case of an old renderer view, it gets detached from the current view and a new instance
    /// gets created and then reattached.
    private func createAndPrepareRenderView() {
        if let view = self.rendererView as? UIView {
            view.removeFromSuperview()
        }
        
        self.rendererView = NativeVideoView.createNativeRendererView(delegate: self)
        if let view = self.rendererView as? UIView {
            view.translatesAutoresizingMaskIntoConstraints = true
            addSubview(view)
        }
    }
    
    // this somehow fixes a bug where the view would get layouted but somehow
    // the frame size would be a `0` at the time therefore breaking the video display
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if self.viewSize != self.frame.size {
            shouldLayout()
        }
    }
    
    func shouldLayout() {
        setNeedsLayout()
        
        self.viewSize = frame.size
        
        guard let rendererView = rendererView as? UIView else { return }
        
        guard let dimensions = self.dimensions else {
            // hide the view until we receive the video's dimensions
            rendererView.isHidden = true
            return
        }
        
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
        
        rendererView.isHidden = false
    }
    
    private func update(mirror: Bool) {
        let mirrorTransform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        
        self.layer.setAffineTransform(mirror ? mirrorTransform : .identity)
    }
    
    public static func isMetalAvailable() -> Bool {
        MTLCreateSystemDefaultDevice() != nil
    }
    
    private static func createNativeRendererView(delegate: RTCVideoViewDelegate) -> RTCVideoRenderer {
        DispatchQueue.webRTC.sync {
            if isMetalAvailable() {
                let mtlView = RTCMTLVideoView()
                mtlView.contentMode = .scaleAspectFit
                mtlView.videoContentMode = .scaleAspectFit
                mtlView.delegate = delegate
                
                return mtlView
            } else {
                let glView = RTCEAGLVideoView()
                glView.contentMode = .scaleAspectFit
                glView.delegate = delegate
                return glView
            }
        }
    }
}

extension NativeVideoView: RTCVideoViewDelegate {
    public func videoView(_ : RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        guard let width = Int32(exactly: size.width),
              let height = Int32(exactly: size.height) else {
                  // CGSize is used by WebRTC but this should always be an integer
                  sdkLogger.error("VideoView: size width/height is not an integer")
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
