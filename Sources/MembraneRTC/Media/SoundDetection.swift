import AVFoundation

// Class for sound detection using the device's microphone
public class SoundDetection: ObservableObject {

  // Audio engine for sound detection
  private var engine: AVAudioEngine!
  private var inputNode: AVAudioInputNode!
  private var mixerNode: AVAudioMixerNode!
  private var onSoundDetectedListener: ((_ detectionResult: Bool) -> Void)?
  private var onVolumeChangedListener: ((_ volume: Int) -> Void)?

  // Property to indicate the recording state
  @Published public var isRecording: Bool = false

  /// Sets a listener to receive sound volume change events.
  ///
  /// - Parameter listener: The listener to be notified when sound volume changes.
  public func setOnVolumeChangedListener(listener: ((_ volume: Int) -> Void)?) {
    onVolumeChangedListener = listener
  }

  /// Sets a listener to receive sound detection events.
  ///
  /// - Parameter listener: The listener to be notified when a sound is detected.
  public func setOnSoundDetectedListener(listener: ((_ detectionResult: Bool) -> Void)?) {
    onSoundDetectedListener = listener
  }

  /// Initializer which sets up the audio session and audio engine.
  public init() {
    do {
      try setupSession()
      try setupEngine()
    } catch let error {
      print("Failed during initial setup: \(error.localizedDescription)")
    }
  }

  /// Method to set up the Audio Session.
  fileprivate func setupSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.record)
    try session.setActive(true, options: .notifyOthersOnDeactivation)
  }

  /// Method to set up the Audio Engine.
  fileprivate func setupEngine() {
    engine = AVAudioEngine()
    mixerNode = AVAudioMixerNode()
    mixerNode.volume = 0
    engine.attach(mixerNode)
    makeConnections()
    engine.prepare()
  }

  /// Method to patch AVAudioNodes together.
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

  /// Starts the sound detection process with the specified volume threshold.
  ///
  /// - Parameter volumeThreshold: The threshold value in decibels (dB) above which a sound is considered detected.
  public func start(_ volumeThreshold: Int = 60) {
    let tapNode: AVAudioNode = mixerNode
    let format = tapNode.outputFormat(forBus: 0)

    tapNode.installTap(
      onBus: 0, bufferSize: 4096, format: format,
      block: {
        (buffer, time) in
        self.processAudioBufferForSoundDetection(from: buffer, volumeThreshold)
      })

    do {
      try engine.start()
      isRecording = true
    } catch let error {
      print("Failed to start audio engine: \(error.localizedDescription)")
    }
  }

  /// Processes the provided AVAudioPCMBuffer for sound detection.
  ///
  /// - Parameters:
  ///   - buffer: The audio buffer.
  ///   - volumeThreshold: The threshold value in decibels (dB) above which a sound is considered detected.
  fileprivate func processAudioBufferForSoundDetection(
    from buffer: AVAudioPCMBuffer, _ volumeThreshold: Int = 60
  ) {
    let amplitude = getMaxAmplitude(from: buffer)
    let soundVolume = calculateValue(from: amplitude)
    onVolumeChangedListener?(soundVolume)
    onSoundDetectedListener?(soundVolume > volumeThreshold)
  }

  /// Stops the sound detection process.
  public func stop() {
    mixerNode.removeTap(onBus: 0)
    engine.stop()
    isRecording = false
  }

  /// Method to calculate the maximum amplitude in the buffer.
  ///
  /// - Parameter buffer: The audio buffer.
  /// - Returns: The maximum amplitude value from the buffer.
  fileprivate func getMaxAmplitude(from buffer: AVAudioPCMBuffer) -> Int {
    let convertedBuffer = convertFloat32To16(buffer: buffer)
    guard let data = convertedBuffer?.int16ChannelData else {
      return 0
    }
    let frameLength = Int(buffer.frameLength)
    var maxAmplitude: Int16 = 0
    for i in 0..<frameLength {
      maxAmplitude = max(data[0][i], maxAmplitude)
    }
    return Int(maxAmplitude)
  }

  /// Converts PCM Buffer from Float32 to Int16
  ///
  /// - Parameter buffer: The audio buffer in Float32.
  /// - Returns: The converted audio buffer in Int16 format, returned nil if conversion failed.
  fileprivate func convertFloat32To16(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    let sourceFormat = buffer.format
    let targetFormat = AVAudioFormat(
      commonFormat: .pcmFormatInt16, sampleRate: sourceFormat.sampleRate,
      channels: sourceFormat.channelCount,
      interleaved: true)

    guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat!) else {
      print("Failed to initialize audio converter.")
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
      print("Failed to convert audio data: \(error?.localizedDescription ?? "")")
      return nil
    }

    return outputBuffer
  }

  /// Method to calculate decibel (dB) value from maximum amplitude.
  ///
  /// Sound pressure level (SPL) or volume is often expressed in decibels. This method transforms the amplitude
  /// of the audio signal into a decibel value using the formula `20 * log10(amplitude)`. [https://en.wikipedia.org/wiki/Sound_pressure#Sound_pressure_level]
  ///
  /// As the logarithm of a number less than one is negative and we're dealing with sound 'pressure',
  /// we take the logarithm of the positive maximum amplitude. `-160 dB` is used as a minimum threshold because
  /// it's generally accepted as a "below the threshold of hearing" in humans.
  ///
  /// - Parameter maxAmplitude: The calculated maximum amplitude from the audio buffer.
  /// - Returns: The calculated sound level value in decibels (dB).
  fileprivate func calculateValue(from maxAmplitude: Int) -> Int {
    if maxAmplitude <= 0 { return -160 }
    return Int(20 * log10(Double(maxAmplitude) / 1.0))
  }

}
