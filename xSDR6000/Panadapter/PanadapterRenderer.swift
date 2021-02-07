//
//  PanadapterRenderer.swift
//  xSDR6000
//
//  Created by Douglas Adams on 9/30/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation
import MetalKit
import xLib6000

public final class PanadapterRenderer: NSObject {
    
    //  As input, the renderer expects an array of UInt16 intensity values. The intensity values are
    //  scaled by the radio to be between zero and Panadapter.yPixels. The values are inverted
    //  i.e. the value of Panadapter.yPixels is zero intensity and a value of zero is maximum intensity.
    //  The Panadapter sends an array of size Panadapter.xPixels (same as frame.width).
    //
    
    // swiftlint:disable colon
    // ----------------------------------------------------------------------------
    // MARK: - Static properties
    
    static let kMaxIntensities                = 3_072                         // max number of intensity values (bins)
    
    // ----------------------------------------------------------------------------
    // MARK: - Shader structs
    
    private struct SpectrumValue {
        var i                                   : ushort                        // intensity
    }
    
    private struct Constants {
        var delta                               : Float = 0                     // distance between x coordinates
        var height                              : Float = 0                     // height of view (yPixels)
        var maxNumberOfBins                     : UInt32 = 0                    // number of DataFrame bins
    }
    
    private struct Color {
        var spectrumColor                       : SIMD4<Float>                        // spectrum / fill color
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _metalView                    : MTKView!
    private var _device                       : MTLDevice!
    
    private var _spectrumValues               = [UInt16](repeating: 0, count: PanadapterRenderer.kMaxIntensities * 2)
    private var _spectrumBuffers              = [MTLBuffer]()
    private var _spectrumIndices              = [UInt16](repeating: 0, count: PanadapterRenderer.kMaxIntensities * 2)
    private var _spectrumIndicesBuffer        : MTLBuffer!
    
    private var _maxNumberOfBins              = PanadapterRenderer.kMaxIntensities
    
    private var _colorArray                   = [Color](repeating: Color(spectrumColor: NSColor.yellow.float4Color), count: 2)
    
    private var _commandQueue                 : MTLCommandQueue!
    private var _pipelineState                : MTLRenderPipelineState!
    
    //  private var _fillLevel                    = 1
    
    private let _panQ                         = DispatchQueue(label: AppDelegate.kAppName + ".panQ", attributes: [.concurrent])
    private let _panDrawQ                     = DispatchQueue(label: AppDelegate.kAppName + ".panDrawQ")
    private var _isDrawing                    : DispatchSemaphore = DispatchSemaphore(value: 1)
    
    // swiftlint:enable colon
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY -----------------------------------
    //
    private var __constants                   = Constants()
    private var __currentFrameIndex           = 0
    private var __numberOfBins                = UInt32(PanadapterRenderer.kMaxIntensities)
    //
    // ----- Backing properties - SHOULD NOT BE ACCESSED DIRECTLY -----------------------------------
    
    private var _constants: Constants {
        get { return _panQ.sync { __constants } }
        set { _panQ.sync( flags: .barrier) { __constants = newValue } } }
    
    private var _currentFrameIndex: Int {
        get { return _panQ.sync { __currentFrameIndex } }
        set { _panQ.sync( flags: .barrier) { __currentFrameIndex = newValue } } }
    
    private var _numberOfBins: UInt32 {
        get { return _panQ.sync { __numberOfBins } }
        set { _panQ.sync( flags: .barrier) { __numberOfBins = newValue } } }
    
    // constants
    private let _log                          = Logger.sharedInstance
    private let kPanadapterVertex             = "panadapter_vertex"
    private let kPanadapterFragment           = "panadapter_fragment"
    private let kSpectrumBufferIndex          = 0
    private let kConstantsBufferIndex         = 1
    private let kColorBufferIndex             = 2
    
    private let kFillColor                    = 0
    private let kLineColor                    = 1
    
    private static let kNumberSpectrumBuffers = 3
    
    // ----------------------------------------------------------------------------
    // MARK: - Initialization
    
    init(view: MTKView, clearColor color: NSColor) {
        
        _metalView = view
        
        super.init()
        
        // set the Metal view Clear color
        clearColor(color)
        
        view.delegate = self
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    func setConstants(size: CGSize) {
        self._isDrawing.wait()
        
        // Constants struct mapping (bytes)
        //  <--- 4 ---> <--- 4 ---> <--- 4 ---> <-- empty -->              delta, height, maxNumberOfBins
        
        // populate it
        _constants.delta = Float(1.0 / (size.width - 1.0))
        _constants.height = Float(size.height)
        _constants.maxNumberOfBins = UInt32(_maxNumberOfBins)
        
        self._isDrawing.signal()
    }
    
    func updateColor(spectrumColor: NSColor, fillLevel: Int, fillColor: NSColor) {
        self._isDrawing.wait()
        
        // Color struct mapping
        //  <--------------------- 16 ---------------------->              spectrumColor
        
        // calculate the effective fill color
        let fillPercent = CGFloat(fillLevel)/CGFloat(100.0)
        let adjFillColor = NSColor(red: fillColor.redComponent * fillPercent,
                                   green: fillColor.greenComponent * fillPercent,
                                   blue: fillColor.blueComponent * fillPercent,
                                   alpha: fillColor.alphaComponent * fillPercent)
        
        // update the array
        _colorArray[kFillColor].spectrumColor = adjFillColor.float4Color
        _colorArray[kLineColor].spectrumColor = spectrumColor.float4Color
        
        self._isDrawing.signal()
    }
    /// Set the Metal view clear color
    ///
    /// - Parameter color:        an NSColor
    ///
    func clearColor(_ color: NSColor) {
        _metalView.clearColor = MTLClearColor(red: Double(color.redComponent),
                                              green: Double(color.greenComponent),
                                              blue: Double(color.blueComponent),
                                              alpha: Double(color.alphaComponent) )
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Setup Objects, Buffers & State
    ///
    func setup(device: MTLDevice) {
        
        _device = device
        
        // create and populate Spectrum buffers
        let dataSize = _spectrumValues.count * MemoryLayout.stride(ofValue: _spectrumValues[0])
        for _ in 0..<PanadapterRenderer.kNumberSpectrumBuffers {
            _spectrumBuffers.append(_device.makeBuffer(bytes: _spectrumValues, length: dataSize, options: [.storageModeShared])!)
        }
        
        // populate the Indices array used for style == .fill || style == .fillWithTexture
        for i in 0..<PanadapterRenderer.kMaxIntensities {
            // n,0,n+1,1,...2n-1,n-1
            _spectrumIndices[2 * i] = UInt16(PanadapterRenderer.kMaxIntensities + i)
            _spectrumIndices[(2 * i) + 1] = UInt16(i)
        }
        
        // create and populate an Indices buffer (for filled drawing only)
        let indexSize = _spectrumIndices.count * MemoryLayout.stride(ofValue: _spectrumIndices[0])
        _spectrumIndicesBuffer = _device.makeBuffer(bytes: _spectrumIndices, length: indexSize, options: [.storageModeShared])
        
        // get the Shaders library
        let library = _device.makeDefaultLibrary()!
        
        // create a Render Pipeline descriptor
        let rpd = MTLRenderPipelineDescriptor()
        rpd.vertexFunction = library.makeFunction(name: kPanadapterVertex)
        rpd.fragmentFunction = library.makeFunction(name: kPanadapterFragment)
        rpd.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // create the Render Pipeline State object
        do {
            _pipelineState = try _device.makeRenderPipelineState(descriptor: rpd)
        } catch {
            fatalError("PanadapterRenderer: failed to create render pipeline")
        }
        
        // create and save a Command Queue object
        _commandQueue = _device.makeCommandQueue()
        _commandQueue.label = "Panadapter"
    }
}

// ----------------------------------------------------------------------------
// MARK: - MTKViewDelegate protocol methods

extension PanadapterRenderer: MTKViewDelegate {
    
    /// Respond to a change in the size of the MTKView
    ///
    /// - Parameters:
    ///   - view:             the MTKView
    ///   - size:             its new size
    ///
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // not used
    }
    /// Draw in the MTKView
    ///
    /// - Parameter view:     the MTKView
    ///
    public func draw(in view: MTKView) {
        
        self._isDrawing.wait()
        
        // obtain a Command buffer & a Render Pass descriptor
        guard let cmdBuffer = self._commandQueue.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor else { return }
        
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .dontCare
        
        // Create a render encoder
        let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        
        encoder.pushDebugGroup("Fill")
        
        // set the Spectrum pipeline state
        encoder.setRenderPipelineState(_pipelineState)
        
        // bind the active Spectrum buffer
        encoder.setVertexBuffer(_spectrumBuffers[_currentFrameIndex], offset: 0, index: kSpectrumBufferIndex)
        
        // bind the Constants
        encoder.setVertexBytes(&_constants, length: MemoryLayout.size(ofValue: _constants), index: kConstantsBufferIndex)
        
        //    // is the Panadapter "filled"?
        //    if self._fillLevel > 1 {
        
        // YES, bind the Fill Color
        encoder.setVertexBytes(&_colorArray[kFillColor], length: MemoryLayout.size(ofValue: _colorArray[kFillColor]), index: kColorBufferIndex)
        
        // Draw filled
        encoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: Int(_numberOfBins * 2), indexType: .uint16, indexBuffer: _spectrumIndicesBuffer, indexBufferOffset: 0)
        //    }
        encoder.popDebugGroup()
        encoder.pushDebugGroup("Line")
        
        // bind the Line Color
        encoder.setVertexBytes(&_colorArray[kLineColor], length: MemoryLayout.size(ofValue: _colorArray[kLineColor]), index: kColorBufferIndex)
        
        // Draw as a Line
        encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: Int(_numberOfBins))
        
        // finish using this encoder
        encoder.endEncoding()
        
        // present the drawable to the screen
        cmdBuffer.present(_metalView.currentDrawable!)
        
        // push the command buffer to the GPU
        cmdBuffer.commit()
        
        self._isDrawing.signal()
    }
}

// ----------------------------------------------------------------------------
// MARK: - PanadapterStreamHandler protocol methods

extension PanadapterRenderer: StreamHandler {
    
    //  DataFrame Layout: (see xLib6000 PanadapterFrame)
    //
    //  var startingBinIndex                    : UInt16
    //  var numberOfBins                        : UInt16
    //  var binSize                             : UInt16
    //  var totalBinsInFrame                    : UInt16
    //  var frameIndex                          : UInt32
    //  var bins: [UInt16]
    //
    
    /// Process the UDP Stream Data for the Panadapter
    ///
    ///   StreamHandler protocol, executes on the streamQ
    ///
    /// - Parameter streamFrame:        a Panadapter frame
    ///
    public func streamHandler<T>(_ streamFrame: T) {
        
        guard let streamFrame = streamFrame as? PanadapterFrame else { return }
        
        _isDrawing.wait()
        // move to using the next spectrumBuffer
        _currentFrameIndex = (_currentFrameIndex + 1) % PanadapterRenderer.kNumberSpectrumBuffers
        
        // totalBins is the number of horizontal pixels in the spectrum waveform
        _numberOfBins = UInt32(streamFrame.totalBins)
        
        // put the Intensities into the current Spectrum Buffer
        _spectrumBuffers[_currentFrameIndex].contents().copyMemory(from: streamFrame.bins, byteCount: streamFrame.totalBins * MemoryLayout<ushort>.stride)
        
        _isDrawing.signal()
        
        //    _panDrawQ.async { [unowned self] in
        //      autoreleasepool {
        //        self._metalView.draw()
        //      }
        //    }
    }
}
