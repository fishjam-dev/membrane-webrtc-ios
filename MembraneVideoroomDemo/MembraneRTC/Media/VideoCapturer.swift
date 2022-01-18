import WebRTC

protocol VideoCapturer {
    func startCapturing(); 
    func stopCapturing();
}