//
//  OpusPlayer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 2/12/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Foundation
// import OpusOSX
import Accelerate
import AudioToolbox
import AVFoundation
import xLib6000

//  DATA FLOW
//
//  Stream Handler  ->  Opus Decoder   ->   Ring Buffer   ->  OutputUnit    -> Output device
//
//                  [UInt8]            [Float]            [Float]           set by hardware
//
//                  opus               pcmFloat32         pcmFloat32
//                  24_000             24_000             24_000
//                  2 channels         2 channels         2 channels
//                                     interleaved        interleaved
// --------------------------------------------------------------------------------
// MARK: - Opus Player class implementation
// --------------------------------------------------------------------------------

public final class OpusPlayer: NSObject, StreamHandler {
    
    // ----------------------------------------------------------------------------
    // MARK: - Static properties
    
    static let bufferSize         = RemoteRxAudioStream.frameCount * RemoteRxAudioStream.elementSize  // size of a buffer (in Bytes)
    static let ringBufferCapacity = 20      // number of AudioBufferLists in the Ring buffer
    static let ringBufferOverage  = 2_048   // allowance for Ring buffer metadata (in Bytes)
    static let ringBufferSize     = (OpusPlayer.bufferSize * RemoteRxAudioStream.channelCount * OpusPlayer.ringBufferCapacity) + OpusPlayer.ringBufferOverage
    
    // Opus sample rate, format, 2 channels for compressed Opus data
    static var opusASBD = AudioStreamBasicDescription(mSampleRate: RemoteRxAudioStream.sampleRate,
                                                      mFormatID: kAudioFormatOpus,
                                                      mFormatFlags: 0,
                                                      mBytesPerPacket: 0,
                                                      mFramesPerPacket: UInt32(RemoteRxAudioStream.frameCount),
                                                      mBytesPerFrame: 0,
                                                      mChannelsPerFrame: UInt32(RemoteRxAudioStream.channelCount),
                                                      mBitsPerChannel: 0,
                                                      mReserved: 0)
    // Opus sample rate, PCM, Float32, 2 channel, interleaved
    static var decoderOutputASBD = AudioStreamBasicDescription(mSampleRate: RemoteRxAudioStream.sampleRate,
                                                               mFormatID: kAudioFormatLinearPCM,
                                                               mFormatFlags: kAudioFormatFlagIsFloat,
                                                               mBytesPerPacket: UInt32(RemoteRxAudioStream.elementSize * RemoteRxAudioStream.channelCount),
                                                               mFramesPerPacket: 1,
                                                               mBytesPerFrame: UInt32(RemoteRxAudioStream.elementSize * RemoteRxAudioStream.channelCount),
                                                               mChannelsPerFrame: UInt32(RemoteRxAudioStream.channelCount),
                                                               mBitsPerChannel: UInt32(RemoteRxAudioStream.elementSize * 8) ,
                                                               mReserved: 0)
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let _log = Logger.sharedInstance
    private var _outputUnit: AudioUnit?
    private var _ringBuffer = TPCircularBuffer()
    private var _q = DispatchQueue(label: AppDelegate.kAppName + "OpusPlayerObjectQ", qos: .userInteractive, attributes: [.concurrent])
    
    private var __outputActive = false
    private var _outputActive: Bool {
        get { return _q.sync { __outputActive } }
        set { _q.sync(flags: .barrier) { __outputActive = newValue } } }
    
    private var _inputBuffer = AVAudioCompressedBuffer()
    private var _outputBuffer = AVAudioPCMBuffer()
    private var _converter: AVAudioConverter?
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    override init() {
        
        super.init()
        
        setupConversion()
        
        setupOutputUnit()
    }
    deinit {
        guard let outputUnit = _outputUnit else { return }
        AudioUnitUninitialize(outputUnit)
        AudioComponentInstanceDispose(outputUnit)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    public func start() {
        guard let outputUnit = _outputUnit else { fatalError("Output unit is null") }
        TPCircularBufferClear(&_ringBuffer)
        
        let availableFrames = TPCircularBufferGetAvailableSpace(&_ringBuffer, &OpusPlayer.decoderOutputASBD)
        _log.logMessage("OpusPlayer start: frames = \(availableFrames)", .debug, #function, #file, #line)
        
        // register render callback
        var input: AURenderCallbackStruct = AURenderCallbackStruct(inputProc: renderProc, inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        AudioUnitSetProperty(outputUnit,
                             kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input,
                             0,
                             &input,
                             UInt32(MemoryLayout.size(ofValue: input)))
        guard AudioUnitInitialize(outputUnit) == noErr else { fatalError("Output unit not initialized") }
        
        // start playing
//        guard AudioOutputUnitStart(outputUnit) == noErr else { fatalError("Output unit failed to start") }
//        _outputActive = true
    }
    
    public func stop() {
        _outputActive = false
        
        guard let outputUnit = _outputUnit else { return }
        
        AudioOutputUnitStop(outputUnit)
        
        let availableFrames = TPCircularBufferGetAvailableSpace(&_ringBuffer, &OpusPlayer.decoderOutputASBD)
        _log.logMessage("OpusPlayer stop: frames = \(availableFrames) ", .debug, #function, #file, #line)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Setup buffers and Converters
    ///
    private func setupConversion() {
        // setup the Converter Input & Output buffers
        _inputBuffer = AVAudioCompressedBuffer(format: AVAudioFormat(streamDescription: &OpusPlayer.opusASBD)!, packetCapacity: 1, maximumPacketSize: RemoteRxAudioStream.frameCount)
        _outputBuffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(streamDescription: &OpusPlayer.decoderOutputASBD)!, frameCapacity: UInt32(RemoteRxAudioStream.frameCount))!
        
        // convert from Opus compressed -> PCM Float32, 2 channel, interleaved
        _converter = AVAudioConverter(from: AVAudioFormat(streamDescription: &OpusPlayer.opusASBD)!,
                                      to: AVAudioFormat(streamDescription: &OpusPlayer.decoderOutputASBD)!)
        // create the Ring buffer (actual size will be adjusted to fit virtual memory page size)
        guard _TPCircularBufferInit( &_ringBuffer, UInt32(OpusPlayer.ringBufferSize), MemoryLayout<TPCircularBuffer>.stride ) else { fatalError("Ring Buffer not created") }
    }
    
    /// Setup the Output Unit
    ///
    func setupOutputUnit() {
        // create an Audio Component Description
        var outputcd = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                                 componentSubType: kAudioUnitSubType_DefaultOutput,
                                                 componentManufacturer: kAudioUnitManufacturer_Apple,
                                                 componentFlags: 0,
                                                 componentFlagsMask: 0)
        // get the output device
        guard let audioComponent = AudioComponentFindNext(nil, &outputcd) else { fatalError("Output unit not found") }
        
        // create the player's output unit
        guard AudioComponentInstanceNew(audioComponent, &_outputUnit) == noErr else { fatalError("Output unit not created") }
        guard let outputUnit = _outputUnit else { fatalError("Output unit is null") }
        
        // set the output unit's Input sample rate
        var inputSampleRate = RemoteRxAudioStream.sampleRate
        AudioUnitSetProperty(outputUnit,
                             kAudioUnitProperty_SampleRate,
                             kAudioUnitScope_Input,
                             0,
                             &inputSampleRate,
                             UInt32(MemoryLayout<Float64>.size))
        
        // set the output unit's Input stream format (PCM Float32 interleaved)
        var inputStreamFormat = OpusPlayer.decoderOutputASBD
        AudioUnitSetProperty(outputUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             0,
                             &inputStreamFormat,
                             UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
    }
    
    /// AudioUnit Render proc
    ///
    ///   returns PCM Float32 interleaved data
    ///
    private let renderProc: AURenderCallback = { (inRefCon: UnsafeMutableRawPointer, _, _, _, inNumberFrames: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>? ) in
        guard let ioData = ioData else { fatalError("ioData is null") }
        
        // get a reference to the OpusPlayer
        let player = Unmanaged<OpusPlayer>.fromOpaque(inRefCon).takeUnretainedValue()
        
        // retrieve the requested number of frames
        var lengthInFrames = inNumberFrames
        TPCircularBufferDequeueBufferListFrames(&player._ringBuffer, &lengthInFrames, ioData, nil, &OpusPlayer.decoderOutputASBD)
        
        // assumes no error
        return noErr
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Stream Handler protocol methods
    //
    
    /// Process the UDP Stream Data for RemoteRxAudio (Opus) streams
    ///
    ///   StreamHandler protocol, executes on the streamQ
    ///
    /// - Parameter frame:            an Opus Rx Frame
    ///
    public func streamHandler<T>(_ streamFrame: T) {
        guard let frame = streamFrame as? RemoteRxAudioFrame else { return }
        
        // create an AVAudioCompressedBuffer for input to the converter
        _inputBuffer = AVAudioCompressedBuffer(format: AVAudioFormat(streamDescription: &OpusPlayer.opusASBD)!, packetCapacity: 1, maximumPacketSize: RemoteRxAudioStream.frameCount)
        
        // create an AVAudioPCMBuffer buffer for output from the converter
        _outputBuffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(streamDescription: &OpusPlayer.decoderOutputASBD)!, frameCapacity: UInt32(RemoteRxAudioStream.frameCount))!
        _outputBuffer.frameLength = _outputBuffer.frameCapacity
        
        if frame.numberOfSamples != 0 {
            // Valid packet: copy the data and save the count
            memcpy(_inputBuffer.data, frame.samples, frame.numberOfSamples)
            _inputBuffer.byteLength = UInt32(frame.numberOfSamples)
            _inputBuffer.packetCount = AVAudioPacketCount(1)
            _inputBuffer.packetDescriptions![0].mDataByteSize = _inputBuffer.byteLength
        } else {
            // Missed packet:
            _inputBuffer.byteLength = UInt32(frame.numberOfSamples)
            _inputBuffer.packetCount = AVAudioPacketCount(1)
            _inputBuffer.packetDescriptions![0].mDataByteSize = _inputBuffer.byteLength
        }
        // Convert from the inputBuffer (Opus) to the outputBuffer (PCM Float32, interleaved)
        var error: NSError?
        _ = (_converter!.convert(to: _outputBuffer, error: &error, withInputFrom: { (_, outputStatus) -> AVAudioBuffer? in
            outputStatus.pointee = .haveData
            return self._inputBuffer
        }))
        
        // check for decode errors
        if error != nil {
            _log.logMessage("Opus conversion error: \(error!)", .error, #function, #file, #line)
        }
        // copy the frame's buffer to the Ring buffer & make it available
        TPCircularBufferCopyAudioBufferList(&_ringBuffer, &_outputBuffer.mutableAudioBufferList.pointee, nil, UInt32(RemoteRxAudioStream.frameCount), &OpusPlayer.decoderOutputASBD)

        // start playing
        if _outputActive == false {
            guard AudioOutputUnitStart(_outputUnit!) == noErr else { fatalError("Output unit failed to start") }
            _outputActive = true
        }
    }
}
