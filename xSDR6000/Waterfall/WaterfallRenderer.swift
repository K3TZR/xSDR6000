//
//  WaterfallRenderer.swift
//  Waterfall
//
//  Created by Douglas Adams on 10/7/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation
import MetalKit
import xLib6000

public final class WaterfallRenderer: NSObject, MTKViewDelegate {
    
    //  Vertices    v1  (-1, 1)     |     ( 1, 1)  v3       Texture     v1  ( 0, 0) |---------  ( 1, 0)  v3
    //  (-1 to +1)                  |                       (0 to 1)                |
    //                          ----|----                                           |
    //                              |                                               |
    //              v0  (-1,-1)     |     ( 1,-1)  v2                   v0  ( 0, 1) |           ( 1, 1)  v2
    //
    
    // as an example, consider a 10 line array of lines
    //
    //    index 0
    //          1
    //          2
    //          3
    //          4
    //          5
    //          6
    //          7
    //          8
    //          9
    //
    //  * write the 1st line into index 9
    //  * draw line 9 at the top of the waterfall area
    //
    //  * write the 2nd line into index 8
    //  * draw line 8 at the top of the waterfall area
    //  .......
    //  * write the 10th line into index 0
    //  * draw line 0 at the top of the waterfall area
    //
    //  * write the 11th line into index 9
    //  * draw line 9 at the top of the waterfall area
    //
    // the writeIndex is initially set to = (array.count - 1)
    // after each write the writeIndex = (writeIndex - 1) % array.count
    //
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    var updateNeeded                          = true                          // true == recalc texture coords
    
    struct Intensity {
        var i                                   : UInt16 = 0
    }
    
    struct Line {
        var index                               : UInt16 = 0
    }
    
    struct BinData {
        var firstBinFrequency                   : Float = 0.0
        var binBandwidth                        : Float = 0.0
    }
    
    struct Constants {
        var blackLevel                          : UInt16 = 0
        var colorGain                           : UInt16 = 0
        var numberOfBufferLines                 : UInt16 = 0
        var numberOfScreenLines                 : UInt16 = 0
        var topLineIndex                        : UInt16 = 0
        var startingFrequency                   : Float = 0.0
        var endingFrequency                     : Float = 0.0
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _params                       : Params!
    
    // values chosen to accomodate the largest possible waterfall
    private let kBufferLines                  = 2048                       // must be >= max number of lines
    private let kMaxIntensities               = 3360                       // must be >= max number of Bins
    
    private var _metalView                    : MTKView!
    private var _commandQueue                 : MTLCommandQueue!
    private var _binData                      = BinData()
    private var _line                         = Line()
    private var _device                       : MTLDevice!
    
    private var _intensityBuffer              : MTLBuffer!
    private var _pipelineState                : MTLRenderPipelineState!
    private var _gradientSamplerState         : MTLSamplerState!
    private var _gradientTexture              : MTLTexture!
    private var _binDataBuffer                : MTLBuffer!
    private var _lineIndexBuffer              : MTLBuffer!
    
    private var _writeIndex                   = 0
    private var _drawIndex                    = 0
    
    private let _waterQ                       = DispatchQueue(label: AppDelegate.kAppName + ".waterQ", attributes: [.concurrent])
    private var _waterDrawQ                   = DispatchQueue(label: AppDelegate.kAppName + ".waterDrawQ")
    private var _isDrawing                    : DispatchSemaphore = DispatchSemaphore(value: 1)
    
    private let kFragmentShader               = "waterfall_fragment"
    private let kVertexShader                 = "waterfall_vertex"
    private let kGradientSize                 = 256
    
    private var _constants                    : Constants {
        get { _waterQ.sync { __constants } }
        set { _waterQ.sync(flags: .barrier) { __constants = newValue } } }
    
    // ----------------------------------------------------------------------------
    // *** Backing properties (Do NOT use) ***
    
    private var __constants                   = Constants()
    private var __topLine                     = 0
    
    // swiftlint:enable colon
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    init(view: MTKView, params: Params) {
        
        _metalView = view
        _params = params
        _metalView.preferredFramesPerSecond = 30
        
        super.init()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// The size of the MetalKit View has changed
    ///
    /// - Parameters:
    ///   - view:         the MetalKit View
    ///   - size:         its new size
    ///
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
        DispatchQueue.main.async { [unowned self] in
            self._isDrawing.wait()
            self._constants.numberOfScreenLines = UInt16(self._metalView.frame.size.height)
            self._isDrawing.signal()
        }
    }
    /// Draw lines colored by the Gradient texture
    ///
    /// - Parameter view: the MetalKit view
    ///
    public func draw(in view: MTKView) {
        
        // create a Command Buffer & Encoder
        guard let buffer = _commandQueue.makeCommandBuffer() else { fatalError("Unable to create a Command Queue") }
        guard let desc = view.currentRenderPassDescriptor else { fatalError("Unable to create a Render Pass Descriptor") }
        desc.colorAttachments[0].loadAction = .clear
        desc.colorAttachments[0].storeAction = .dontCare
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: desc) else { fatalError("Unable to create a Command Encoder") }
        
        encoder.pushDebugGroup("Draw")
        
        // set the pipeline state
        encoder.setRenderPipelineState(_pipelineState)
        
        // bind the buffers
        encoder.setVertexBuffer(_intensityBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(_binDataBuffer, offset: 0, index: 1)
        encoder.setVertexBuffer(_lineIndexBuffer, offset: 0, index: 2)
        encoder.setVertexBytes(&_constants, length: MemoryLayout<Constants>.size, index: 3)
        
        // bind the Gradient texture & sampler
        encoder.setFragmentTexture(_gradientTexture, index: 0)
        encoder.setFragmentSamplerState(_gradientSamplerState, index: 0)
        
        var bottom = Int(_constants.topLineIndex) - Int(_constants.numberOfScreenLines - 1)
        if bottom < 0 { bottom = Int(_constants.numberOfBufferLines) + bottom }
        
        // Draw as many lines as fit on the screen
        for i in (0..<Int(_constants.numberOfScreenLines)) {
            // find the offset of the line in the buffer
            let offset = (bottom + i) % Int(_constants.numberOfBufferLines)
            
            // set the buffer offsets
            encoder.setVertexBufferOffset(offset * MemoryLayout<Intensity>.stride * kMaxIntensities, index: 0)
            encoder.setVertexBufferOffset((offset * MemoryLayout<BinData>.stride), index: 1)
            encoder.setVertexBufferOffset(i * MemoryLayout<Line>.stride, index: 2)
            // add the line to the drawing
            encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: kMaxIntensities)
        }
        
        // finish encoding commands
        encoder.endEncoding()
        
        // present the drawable to the screen
        buffer.present(view.currentDrawable!)
        
        // finalize rendering & push the command buffer to the GPU
        buffer.commit()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    func setConstants() {
        DispatchQueue.main.async { [unowned self] in
            self._isDrawing.wait()
            
            self._constants.numberOfBufferLines = UInt16(self.kBufferLines)
            self._constants.numberOfScreenLines = UInt16(self._metalView.frame.size.height)
            self._constants.topLineIndex        = UInt16(0)
            self._constants.startingFrequency   = Float(self._params.start)
            self._constants.endingFrequency     = Float(self._params.end)
            
            self._writeIndex = 0
            
            self._isDrawing.signal()
        }
    }
    /// Setup persistent objects & state
    ///
    func setup(device: MTLDevice) {
        
        _device = device
        makeIntensityBuffer(device: device)
        makeBinDataBuffer(device: device)
        makeLineIndexBuffer(device: device)
        makePipeline(device: device)
        makeGradient(device: device)
        makeCommandQueue(device: device)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    private func makeIntensityBuffer(device: MTLDevice) {
        // create the buffer at it's maximum size
        let size = kBufferLines * kMaxIntensities * MemoryLayout<Intensity>.stride
        _intensityBuffer = device.makeBuffer(length: size, options: [.storageModeShared])
    }
    
    private func makeBinDataBuffer(device: MTLDevice) {
        // create the buffer at it's maximum size
        let size = kBufferLines * MemoryLayout<BinData>.stride
        _binDataBuffer = device.makeBuffer(length: size, options: [.storageModeShared])
    }
    
    private func makeLineIndexBuffer(device: MTLDevice) {
        // create the buffer at it's maximum size
        let size = kBufferLines * MemoryLayout<Line>.stride
        _lineIndexBuffer = device.makeBuffer(length: size, options: [.storageModeShared])
        
        // number each entry with its index value
        for i in 0..<kBufferLines {
            _line.index = UInt16(i)
            memcpy(_lineIndexBuffer.contents().advanced(by: i * MemoryLayout<Line>.stride), &_line, MemoryLayout<Line>.size)
        }
    }
    
    private func makePipeline(device: MTLDevice) {
        // get the Library (contains all compiled .metal files in this project)
        let library = device.makeDefaultLibrary()
        
        // are the vertex & fragment shaders in the Library?
        guard let vertexShader = library?.makeFunction(name: kVertexShader), let fragmentShader = library?.makeFunction(name: kFragmentShader) else {
            fatalError("Unable to find shader function(s) - \(kVertexShader) or \(kFragmentShader)")
        }
        // create the Render Pipeline State object
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = vertexShader
        pipelineDesc.fragmentFunction = fragmentShader
        pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        do {
            _pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDesc)
        } catch {
            fatalError("WaterfallRenderer: failed to create render pipeline state")
        }
    }
    
    private func makeGradient(device: MTLDevice) {
        // define a 1D texture for a Gradient
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type1D
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = kGradientSize
        textureDescriptor.usage = [.shaderRead]
        _gradientTexture = device.makeTexture(descriptor: textureDescriptor)
        
        // create a gradient Sampler state
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.minFilter = .nearest
        samplerDescriptor.magFilter = .nearest
        _gradientSamplerState = device.makeSamplerState(descriptor: samplerDescriptor)
    }
    
    private func makeCommandQueue(device: MTLDevice) {
        // create a Command Queue object
        _commandQueue = device.makeCommandQueue()
    }
    
    func setGradient(_ array: [UInt8]) {
        // copy the Gradient data into the texture
        let region = MTLRegionMake1D(0, kGradientSize)
        _gradientTexture!.replace(region: region, mipmapLevel: 0, withBytes: array, bytesPerRow: kGradientSize * MemoryLayout<Float>.size)
    }
}

// ----------------------------------------------------------------------------
// MARK: - WaterfallStreamHandler protocol methods
//

extension WaterfallRenderer: StreamHandler {
    
    //  frame Layout: (see xLib6000 WaterfallFrame)
    //
    //  public private(set) var firstBinFreq      : CGFloat   = 0.0               // Frequency of first Bin (Hz)
    //  public private(set) var binBandwidth      : CGFloat   = 0.0               // Bandwidth of a single bin (Hz)
    //  public private(set) var lineDuration      = 0                             // Duration of this line (ms)
    //  public private(set) var numberOfBins      = 0                             // Number of bins
    //  public private(set) var height            = 0                             // Height of frame (pixels)
    //  public private(set) var receivedFrame     = 0                             // Time code
    //  public private(set) var autoBlackLevel    : UInt32 = 0                    // Auto black level
    //  public private(set) var totalBins         = 0                             //
    //  public private(set) var startingBin       = 0                             //
    //  public var bins                           = [UInt16]()                    // Array of bin values
    //
    
    /// Process the UDP Stream Data for the Waterfall
    ///
    ///   StreamHandler protocol, executes on the streamQ
    ///
    /// - Parameter streamFrame:        a Waterfall frame
    ///
    public func streamHandler<T>(_ streamFrame: T) {
        
        guard var streamFrame = streamFrame as? WaterfallFrame else { return }
        
        _isDrawing.wait()
        
        if _constants.numberOfBufferLines != 0 {
            
            _constants.topLineIndex = UInt16(_writeIndex)
            
            // copy the Intensities into the Intensity buffer
            memcpy(_intensityBuffer.contents().advanced(by: _writeIndex * MemoryLayout<Intensity>.stride * kMaxIntensities),
                   &streamFrame.bins, streamFrame.binsInThisFrame * MemoryLayout<UInt16>.size)
            
            // update the constants
            _constants.startingFrequency = Float(_params.start)
            _constants.endingFrequency = Float(_params.end)
            _constants.blackLevel = _params.waterfall.autoBlackEnabled ? UInt16(streamFrame.autoBlackLevel) : UInt16( (Float(_params.waterfall.blackLevel) / 100.0) * Float(UInt16.max) )
            _constants.colorGain = UInt16(_params.waterfall.colorGain)
            
            // copy the First Bin Frequency & Bin Bandwidth for this line
            var firstBinFrequency = Float(streamFrame.firstBinFreq)
            var binBandWidth = Float(streamFrame.binBandwidth)
            memcpy(_binDataBuffer.contents().advanced(by: _writeIndex * MemoryLayout<BinData>.stride), &firstBinFrequency, MemoryLayout<Float>.size)
            memcpy(_binDataBuffer.contents().advanced(by: _writeIndex * MemoryLayout<BinData>.stride + MemoryLayout<Float>.stride), &binBandWidth, MemoryLayout<Float>.size)
            
            _writeIndex = (_writeIndex + 1) % kBufferLines
        }
        _isDrawing.signal()
    }
}
