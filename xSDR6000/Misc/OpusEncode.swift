//
//  OpusEncode.swift
//  xSDR6000
//
//  Created by Douglas Adams on 8/2/18.
//  Copyright © 2018 Douglas Adams. All rights reserved.
//

import Foundation
import OpusOSX
import AVFoundation
import xLib6000

//  DATA FLOW
//
//  Input device  ->  InputNode Tap     ->     AudioConverter    ->    OpusEncoder      ->    Opus.sendTxAudio()
//
//                various               [Float]                  [Float]                 [UInt8]
//
//                various               pcmFloat32               pcmFloat32              opus
//                various               various                  24_000                  24_000
//                various               various                  interleaved             interleaved
//                various               various                  2 channels              2 channels

// --------------------------------------------------------------------------------
// MARK: - Opus Encode class implementation
// --------------------------------------------------------------------------------


public final class OpusEncode               : NSObject {

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private let _log                          = Logger.sharedInstance
  private var _engine                       : AVAudioEngine?
  private var _mixer                        : AVAudioMixerNode?
  private var _remoteTxAudioStream          : RemoteTxAudioStream!
  private var _encoder                      : OpaquePointer!
  
  private var _audioConverter               : AVAudioConverter!
  
  private var _tapInputBlock                : AVAudioNodeTapBlock!
  private var _tapBufferSize                : AVAudioFrameCount = 0
  private var _encoderOutput                = [UInt8](repeating: 0, count: RemoteTxAudioStream.frameCount)
  
  private var _ringBuffer                   = RingBuffer()
  private var _bufferInput                  : AVAudioPCMBuffer!
  private var _bufferOutput                 : AVAudioPCMBuffer!
  private var _bufferSemaphore              : DispatchSemaphore!
  
  private var _outputQ                      = DispatchQueue(label: "Output", qos: .userInteractive, attributes: [.concurrent])
  private var _q                            = DispatchQueue(label: "Object", qos: .userInteractive, attributes: [.concurrent])
  private var _producerIndex                : Int64 = 0
  
  private var __outputActive                = false
  private var _outputActive                 : Bool {
    get { return _q.sync { __outputActive } }
    set { _q.sync(flags: .barrier) { __outputActive = newValue } } }


  private let kConverterOutputFormat        = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                            sampleRate: RemoteTxAudioStream.sampleRate,
                                                            channels: AVAudioChannelCount(RemoteTxAudioStream.channelCount),
                                                            interleaved: RemoteTxAudioStream.isInterleaved)!
  private let kConverterOutputFrameCount    = Int(RemoteTxAudioStream.sampleRate / 10)
  private let kRingBufferSlots              = 3
  private let kTapBus                       = 0

  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ remoteTxAudioStream: RemoteTxAudioStream) {
    _remoteTxAudioStream = remoteTxAudioStream
    
    super.init()
    
    // create the Ring buffer and buffers for Input and Output from the Ring buffer
    createBuffers()
    
    // create the Tap block
    createTapInputBlock()
    
    // cerate an Opus encoder
    createOpusEncoder()

    // observe Opus parameters
    createObservations(&_observations)
  }
  
  deinit {
    _ringBuffer?.deallocate()
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  

  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Capture data, convert it and place it in the ring buffer
  ///
  private func startInput(_ device: AHAudioDevice) {
    
    // get the input device's ASBD & derive the AVAudioFormat from it
    var asbd = device.asbd!
    let inputFormat = AVAudioFormat(streamDescription: &asbd)!
    
    // the Tap format is whatever the input node's output produces
    let tapFormat = _engine!.inputNode.outputFormat(forBus: kTapBus)
    
    // calculate a buffer size for 100 milliseconds of audio at the Tap
    //    NOTE: installTap header file says "Supported range is [100, 400] ms."
    _tapBufferSize = AVAudioFrameCount(tapFormat.sampleRate/10)
    
    Swift.print("Input            device  = \(device.name!), ID = \(device.id)")
    Swift.print("Input            format  = \(inputFormat)")
    Swift.print("Converter input  format  = \(tapFormat)")
    Swift.print("Converter output format  = \(kConverterOutputFormat)")
    
    // setupt the converter to go from the Tap format to Opus format
    _audioConverter = AVAudioConverter(from: tapFormat, to: kConverterOutputFormat)
    
    // clear the buffers
    clearBuffers()
    
    // start a thread to empty the ring buffer
    _bufferSemaphore = DispatchSemaphore(value: 0)
    _outputActive = true
    startOutput()
    
    _producerIndex = 0
    
    // setup the Tap callback to populate the ring buffer
    _engine!.inputNode.installTap(onBus: kTapBus, bufferSize: _tapBufferSize, format: tapFormat, block: _tapInputBlock)

    // prepare & start the engine
    _engine!.prepare()
    try! _engine!.start()
  }
  /// Start a thread to empty the ring buffer
  ///
  private func startOutput() {
    
    _outputQ.async { [unowned self] in
      
      // start at the beginning of the ring buffer
      var frameNumber : Int64 = 0
      
      while self._outputActive {
        
        // wait for the data
        self._bufferSemaphore.wait()
        
        // process 240 frames per iteration
        for _ in 0..<10 {
          
          let fetchError = self._ringBuffer!.fetch(self._bufferOutput.mutableAudioBufferList,
                                                   nFrame: UInt32(RemoteTxAudioStream.frameCount),
                                                   frameNumnber: frameNumber)
          if fetchError != 0 { Swift.print("Fetch error = \(String(describing: fetchError))") }
          
          
//          Swift.print("\(self._bufferOutput.floatChannelData![0][120])")
          
          
          
          // ------------------ ENCODE ------------------
          
          // perform Opus encoding
          let encodedFrames = opus_encode_float(self._encoder,                            // an encoder
                                                self._bufferOutput.floatChannelData![0],  // source (interleaved .pcmFloat32)
                                                Int32(RemoteTxAudioStream.frameCount),    // source, frames per channel
                                                &self._encoderOutput,                     // destination (Opus-encoded bytes)
                                                Int32(RemoteTxAudioStream.frameCount))    // destination, max size (bytes)
          // check for encode errors
          if encodedFrames < 0 { Swift.print("Encoder error - " + String(cString: opus_strerror(encodedFrames))) }
          
          // send the encoded audio to the Radio
          self._remoteTxAudioStream!.sendRemoteTxAudioStream(buffer: self._encoderOutput, samples: Int(encodedFrames))
          
          // bump the frame number
          frameNumber += Int64( RemoteTxAudioStream.frameCount )
        }
      }
    }
  }
  /// Set the input device for the engine
  ///
  /// - Parameter id:             an AudioDeviceID
  /// - Returns:                  true if successful
  ///
  private func setInputDevice(_ id: AudioDeviceID) -> Bool {
    
    // get the underlying AudioUnit
    let audioUnit = _engine!.inputNode.audioUnit!
    
    // set the new device as the input device
    var inputDeviceID = id
    let error = AudioUnitSetProperty(audioUnit,
                                     kAudioOutputUnitProperty_CurrentDevice,
                                     kAudioUnitScope_Global,
                                     0,
                                     &inputDeviceID,
                                     UInt32(MemoryLayout<AudioDeviceID>.size))
    // success if no errors
    return error == noErr
  }
  /// Create all of the buffers
  ///
  private func createBuffers() {
    
    // create the Ring buffer
    _ringBuffer!.allocate(UInt32(RemoteTxAudioStream.channelCount),
                          bytesPerFrame: UInt32(MemoryLayout<Float>.size * Int(kConverterOutputFormat.channelCount)),
                          capacityFrames: UInt32(kConverterOutputFrameCount * kRingBufferSlots))
    
    // create a buffer for output from the AudioConverter (input to the ring buffer)
    _bufferInput = AVAudioPCMBuffer(pcmFormat: kConverterOutputFormat,
                                    frameCapacity: AVAudioFrameCount(kConverterOutputFrameCount))!
    _bufferInput.frameLength = _bufferInput.frameCapacity
    
    // create a buffer for output from the ring buffer
    _bufferOutput = AVAudioPCMBuffer(pcmFormat: kConverterOutputFormat,
                                     frameCapacity: AVAudioFrameCount(RemoteTxAudioStream.frameCount))!
    _bufferOutput.frameLength = _bufferOutput.frameCapacity
    
  }
  /// Create an Opus encoder
  ///
  private func createOpusEncoder() {
    
    // create the Opus encoder
    var opusError : Int32 = 0
    _encoder = opus_encoder_create(Int32(RemoteTxAudioStream.sampleRate),
                                   Int32(RemoteTxAudioStream.channelCount),
                                   Int32(RemoteTxAudioStream.application),
                                   &opusError)
    if opusError != OPUS_OK { fatalError("Unable to create OpusEncoder, error = \(opusError)") }
    
  }
  /// Create a block to process the Tap data
  ///
  private func createTapInputBlock() {
    
    _tapInputBlock = { [unowned self] (inputBuffer, time) in
      
      // setup the Converter callback (assumes no errors)
      var error: NSError?
      self._audioConverter.convert(to: self._bufferInput, error: &error, withInputFrom: { (inNumPackets, outStatus) -> AVAudioBuffer? in
        
        // signal we have the needed amount of data
        outStatus.pointee = AVAudioConverterInputStatus.haveData
        
        // return the data to be converted
        return inputBuffer
      } )
      
      // push the converted audio into the Ring buffer
      let storeError = self._ringBuffer!.store(self._bufferInput.mutableAudioBufferList, nFrames: UInt32(self.kConverterOutputFrameCount), frameNumber: self._producerIndex )
      if storeError != 0 { Swift.print("Store error = \(String(describing: storeError))") }
      
      // bump the Ring buffer location
      self._producerIndex += Int64(self.kConverterOutputFrameCount)
      
      // signal the availability of data for the Output thread
      self._bufferSemaphore.signal()
    }
  }
  /// Clear all buffers
  ///
  private func clearBuffers() {
    
    // clear the buffers
    memset(_bufferInput.floatChannelData![0], 0, Int(_bufferInput.frameLength) * MemoryLayout<Float>.size * RemoteTxAudioStream.channelCount)
    memset(_bufferOutput.floatChannelData![0], 0, Int(_bufferOutput.frameLength) * MemoryLayout<Float>.size * RemoteTxAudioStream.channelCount)
    
    // FIXME: Clear the ring buffer?
    
  }

  // ----------------------------------------------------------------------------
  // MARK: - Observation methods
  
  private var _observations        = [NSKeyValueObservation]()
  
  /// Add observations of various properties
  ///
  private func createObservations(_ observations: inout [NSKeyValueObservation]) {
    
//    observations = [
//      _remoteTxAudioStream.observe(\.txEnabled, options: [.initial, .new]) { [weak self] (object, change) in
//        self?.opusTxAudio(object, change) }
//    ]
  }
  /// Respond to changes in Opus txEnabled
  ///
  /// - Parameters:
  ///   - object:                       the object holding the properties
  ///   - change:                       the change
  ///
  private func opusTxAudio(_ object: Any, _ change: Any) {
    
//    if _remoteTxAudioStream.txEnabled && _engine == nil {
//
//      // get the default input device
//      let device = AudioHelper.inputDevices.filter { $0.isDefault }.first!
//
//      // start Opus Tx Audio
//      _engine = AVAudioEngine()
//      clearBuffers()
//
//      // try to set it as the input device for the engine
//      if setInputDevice(device.id) {
//
//        _log("RemoteTxAudioStream started: Stream Id = \(RemoteTxAudioStream.streamId.hex), Device = \(device.name!)", .info, #function, #file, #line)
//
//        // start capture using this input device
//        startInput(device)
//
//      } else {
//
//        _log("RemoteTxAudioStream FAILED: Device = \(device.name!)", .warning, #function, #file, #line)
//
//        _engine?.stop()
//        _engine = nil
//      }
//
//    } else if !_remoteTxAudioStream.txEnabled && _engine != nil {
//
//      _log("RemoteTxAudioStream stopped", .info, #function, #file, #line)
//
//      // stop Opus Tx Audio
//      _engine?.inputNode.removeTap(onBus: kTapBus)
//      _engine?.stop()
//      _engine = nil
//    }
//  }
  }
}
