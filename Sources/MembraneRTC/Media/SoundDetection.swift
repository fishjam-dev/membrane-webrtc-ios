import AVFoundation

public class SoundDetection: ObservableObject {

  private var engine: AVAudioEngine!
  private var inputNode: AVAudioInputNode!
  private var mixerNode: AVAudioMixerNode!
  private var onSoundDetectedListener: ((_ detectionResult: Bool) -> Void)?
  private var onVolumeChangedListener: ((_ volume: Int) -> Void)?

  @Published public var isRecording: Bool = false

  public func setOnVolumeChangedListener(listener: ((_ volume: Int) -> Void)?) {
    onVolumeChangedListener = listener
  }

  public func setOnSoundDetectedListener(listener: ((_ detectionResult: Bool) -> Void)?) {
    onSoundDetectedListener = listener
  }

  fileprivate func setIsSoundVolumeChanged(soundVolume: Int) {
    onVolumeChangedListener?(soundVolume)
  }

  fileprivate func setIsSoundDetected(detectionResult: Bool) {
    onSoundDetectedListener?(detectionResult)
  }

  public init() {
    setupSession()
    setupEngine()
  }

  fileprivate func setupSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.record)
    try? session.setActive(true, options: .notifyOthersOnDeactivation)
  }

  fileprivate func setupEngine() {
    engine = AVAudioEngine()
    mixerNode = AVAudioMixerNode()
    mixerNode.volume = 0
    engine.attach(mixerNode)
    makeConnections()
    engine.prepare()
  }

  fileprivate func makeConnections() {
    let inputNode = engine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)
    engine.connect(inputNode, to: mixerNode, format: inputFormat)
    let mainMixerNode = engine.mainMixerNode
    let mixerFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32, sampleRate: inputFormat.sampleRate, channels: 1,
      interleaved: false)
    engine.connect(mixerNode, to: mainMixerNode, format: mixerFormat)
  }

  public func start() {
    let tapNode: AVAudioNode = mixerNode
    let format = tapNode.outputFormat(forBus: 0)

    tapNode.installTap(
      onBus: 0, bufferSize: 4096, format: format,
      block: {
        (buffer, time) in
        self.startSoundDetection(from: buffer)
      })

    do {
      try engine.start()
      isRecording = true
    } catch let error {
      print("Failed to start audio engine: \(error.localizedDescription)")
    }

  }

  public func stop() {
    mixerNode.removeTap(onBus: 0)
    engine.stop()
    isRecording = false
  }

  func startSoundDetection(from buffer: AVAudioPCMBuffer) {
    let amplitude = getMaxAmplitude(from: buffer)
    let value = calculateValue(from: amplitude)
    detectSound(volumeValue: value)
  }

  fileprivate func getMaxAmplitude(from buffer: AVAudioPCMBuffer) -> Int {
    let convertedBuffer = convertFloat32To16(buffer: buffer)
    guard let data = convertedBuffer?.int16ChannelData else {
      return 0
    }
    let frameLength = Int(buffer.frameLength)
    var maxAmplitude: Int16 = 0
    for i in 0..<Int(frameLength) {
      maxAmplitude = max(data[0][i], maxAmplitude)
    }
    return Int(maxAmplitude)
  }

  fileprivate func convertFloat32To16(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    let sourceFormat = buffer.format
    let targetFormat = AVAudioFormat(
      commonFormat: .pcmFormatInt16, sampleRate: sourceFormat.sampleRate,
      channels: sourceFormat.channelCount,
      interleaved: true)

    guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat!) else {
      return nil
    }

    let outputBuffer = AVAudioPCMBuffer(
      pcmFormat: targetFormat!, frameCapacity: buffer.frameCapacity)
    let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
      outStatus.pointee = .haveData
      return buffer
    }

    var error: NSError? = nil
    let result = converter.convert(to: outputBuffer!, error: &error, withInputFrom: inputBlock)

    if result == .error || error != nil {
      return nil
    }

    return outputBuffer
  }

  fileprivate func calculateValue(from maxAmplitude: Int) -> Int {
    if maxAmplitude <= 0 { return -160 }
    return Int(20 * log10(Double(maxAmplitude) / 1.0))
  }

  fileprivate func detectSound(volumeValue: Int, _ volumeThreshold: Int = 60) {
    setIsSoundDetected(detectionResult: volumeValue > volumeThreshold)
    setIsSoundVolumeChanged(soundVolume: volumeValue)
  }

}
