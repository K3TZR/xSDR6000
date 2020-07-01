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


  
  // ----------------------------------------------------------------------------
  // MARK: - Static properties
  
  // values chosen to accomodate the largest possible waterfall
  static let kMaxLines                      = 2048                          // must be >= max number of lines
  static let kMaxIntensities                = 3360                          // must be >= max number of Bins

  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  var updateNeeded                          = true                          // true == recalc texture coords
  
  struct Intensity {
    var i                                   : UInt16 = 0
  }
  
  struct Line {
    var firstBinFrequency                   : Float = 0.0
    var binBandwidth                        : Float = 0.0
    var index                               : UInt16 = 0
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

  private weak var _radio                   : Radio?
  private weak var _panadapter              : Panadapter?
  private weak var _waterfall               : Waterfall? { _radio!.waterfalls[_panadapter!.waterfallId] }

  private var _center                       : Hz { _panadapter!.center }
  private var _bandwidth                    : Hz { _panadapter!.bandwidth }
  private var _start                        : Hz { _center - (_bandwidth/2) }
  private var _end                          : Hz  { _center + (_bandwidth/2) }
  
  private var _metalView                    : MTKView!
  private var _commandQueue                 : MTLCommandQueue!
  private var _line                         = Line()
  private var _device                       : MTLDevice!

  private var _intensityBuffer              : MTLBuffer!
  private var _pipelineState                : MTLRenderPipelineState!
  private var _gradientSamplerState         : MTLSamplerState!
  private var _gradientTexture              : MTLTexture!
  private var _lineBuffer                   : MTLBuffer!
  
  private let _waterQ                       = DispatchQueue(label: Logger.kAppName + ".waterQ", attributes: [.concurrent])
  private var _waterDrawQ                   = DispatchQueue(label: Logger.kAppName + ".waterDrawQ")
  private var _isDrawing                    : DispatchSemaphore = DispatchSemaphore(value: 1)
  
  private let kFragmentShader               = "waterfall_fragment"
  private let kVertexShader                 = "waterfall_vertex"
  private let kGradientSize                 = 256

//  private var _visibleLineCount             = 0
//  private var _sizeOfLine                   = 0
//  private var _sizeOfIntensities            = 0
//  private var _activeLines                  : UInt16 = 0
//  private var _autoBlackLevel               : UInt32 = 0
// arbitrary choice of a reasonable number of color gradations for the waterfall
// in real waterfall these are properties that change
//  static let kEndingBin                     = (kNumberOfBins - 1 - kStartingBin)  // last bin on screen
//  static let kFrameHeight                   = 270                           // frame height (pixels)
//  static let kFrameWidth                    = 480                           // frame width (pixels)
//  static let kNumberOfBins                  = 2048                          // number of stream samples
//  static let kStartingBin                   = (kNumberOfBins -  kFrameWidth)  / 2 // first bin on screen
//  private var _numberOfVertices             = 0
//  private var _first                        = true
//  private var intensityTestData             = [Intensity]()
  
  private var _changingSize                 : Bool {
    get { _waterQ.sync { __changingSize } }
    set { _waterQ.sync(flags: .barrier) { __changingSize = newValue } } }

  private var _constants                    : Constants {
    get { _waterQ.sync { __constants } }
    set { _waterQ.sync(flags: .barrier) { __constants = newValue } } }

//  private var _topLine                      : Int {
//    get { _waterQ.sync { __topLine } }
//    set { _waterQ.sync(flags: .barrier) { __topLine = newValue } } }

  // ----------------------------------------------------------------------------
  // *** Backing properties (Do NOT use) ***
  
  private var __changingSize                = false
  private var __constants                   = Constants()
  private var __topLine                     = 0

  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  init(view: MTKView, radio: Radio, panadapter: Panadapter) {
    
    _metalView = view
    _radio = radio
    _panadapter = panadapter
    
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
      self._changingSize = true

      self._isDrawing.wait()
      self._constants.numberOfScreenLines = UInt16(self._metalView.frame.size.height)
      self._isDrawing.signal()

      self._changingSize = false
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
    guard let encoder = buffer.makeRenderCommandEncoder(descriptor: desc) else { fatalError("Unable to create a Command Encoder") }

    encoder.pushDebugGroup("Draw")
    
    // set the pipeline state
    encoder.setRenderPipelineState(_pipelineState)
    
    // bind the buffers
    encoder.setVertexBuffer(_intensityBuffer, offset: 0, index: 0)
    encoder.setVertexBuffer(_lineBuffer, offset: 0, index: 1)
    encoder.setVertexBytes(&_constants, length: MemoryLayout<Constants>.size, index: 2)
    
    // bind the Gradient texture & sampler
    encoder.setFragmentTexture(_gradientTexture, index: 0)
    encoder.setFragmentSamplerState(_gradientSamplerState, index: 0)
    
    // Draw the visible line(s)
    for i in 0..<Int(_constants.numberOfScreenLines - 1) {
      let loc = (Int(_constants.topLineIndex) + i) % Int(_constants.numberOfBufferLines)
      
      // move to the next set of Intensities & Line params
      encoder.setVertexBufferOffset(loc * MemoryLayout<Intensity>.stride * WaterfallRenderer.kMaxIntensities, index: 0)
      encoder.setVertexBufferOffset((loc * MemoryLayout<Line>.stride), index: 1)
      // draw
      encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: WaterfallRenderer.kMaxIntensities)
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
      
      self._constants.numberOfBufferLines = UInt16(WaterfallRenderer.kMaxLines)
      self._constants.numberOfScreenLines = UInt16(self._metalView.frame.size.height)
      self._constants.topLineIndex        = UInt16(WaterfallRenderer.kMaxLines)
      self._constants.startingFrequency   = Float(self._start)
      self._constants.endingFrequency     = Float(self._end)

      self._isDrawing.signal()
    }
  }
  /// Setup persistent objects & state
  ///
  func setup(device: MTLDevice) {
    
    _device = device
    makeIntensityBuffer(device: device)
    makeLineBuffer(device: device)
    makePipeline(device: device)
    makeGradient(device: device)
    makeCommandQueue(device: device)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  
  private func makeIntensityBuffer(device: MTLDevice) {
    // create the buffer at it's maximum size
    let size = WaterfallRenderer.kMaxLines * WaterfallRenderer.kMaxIntensities * MemoryLayout<Intensity>.stride
    _intensityBuffer = device.makeBuffer(length: size, options: [.storageModeShared])
  }
  
  private func makeLineBuffer(device: MTLDevice) {
    // create the buffer at it's maximum size
    let size = WaterfallRenderer.kMaxLines * MemoryLayout<Line>.stride
    _lineBuffer = device.makeBuffer(length: size, options: [.storageModeShared])

    // number each entry with its index value
    for i in 0..<WaterfallRenderer.kMaxLines {
      _line.index = UInt16(i)
      memcpy(_lineBuffer.contents().advanced(by: i * MemoryLayout<Line>.stride), &_line, MemoryLayout<Line>.size)
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
    _pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDesc)
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

extension WaterfallRenderer                 : StreamHandler {
  
  //  frame Layout: (see xLib6000 WaterfallFrame)
  //
  //  public var firstBinFreq   : CGFloat     // Frequency of first Bin in Hz
  //  public var binBandwidth   : CGFloat     // Bandwidth of a single bin in Hz
  //  public var lineDuration   : Int         // Duration of this line in ms (1 to 100)
  //  public var lineHeight     : Int         // Height of frame in pixels (always 1)
  //  public var autoBlackLevel : UInt32      // Auto black level
  //  public var numberOfBins   : Int         // Number of bins
  //  public var bins           : [UInt16]    // Array of bin values
  //
  
  /// Process the UDP Stream Data for the Waterfall
  ///
  ///   StreamHandler protocol, executes on the streamQ
  ///
  /// - Parameter streamFrame:        a Waterfall frame
  ///
  public func streamHandler<T>(_ streamFrame: T) {
    
    guard let streamFrame = streamFrame as? WaterfallFrame else { return }
    
    _isDrawing.wait()
    
    if _constants.numberOfBufferLines != 0 {
    
    // decrement the Top Line
    _constants.topLineIndex = (_constants.topLineIndex == 0 ? _constants.numberOfBufferLines - 1 : _constants.topLineIndex - 1)

    // copy the Intensities into the Intensity buffer
    memcpy(_intensityBuffer.contents().advanced(by: Int(_constants.topLineIndex) * MemoryLayout<Intensity>.stride * WaterfallRenderer.kMaxIntensities), &streamFrame.bins, streamFrame.numberOfBins * MemoryLayout<UInt16>.size)
    
    // update the constants
    _constants.startingFrequency = Float(_start)
    _constants.endingFrequency = Float(_end)
    _constants.blackLevel = _waterfall!.autoBlackEnabled ? UInt16(streamFrame.autoBlackLevel) : UInt16( (Float(_waterfall!.blackLevel) / 100.0) * Float(UInt16.max) )
    _constants.colorGain = UInt16(_waterfall!.colorGain)

    // copy the First Bin Frequency & Bin Bandwidth for this line
    var firstBinFrequency = Float(streamFrame.firstBinFreq)
    var binBandWidth = Float(streamFrame.binBandwidth)
    memcpy(_lineBuffer.contents().advanced(by: Int(_constants.topLineIndex) * MemoryLayout<Line>.stride), &firstBinFrequency, MemoryLayout<Float>.size)
    memcpy(_lineBuffer.contents().advanced(by: Int(_constants.topLineIndex) * MemoryLayout<Line>.stride + MemoryLayout<Float>.stride), &binBandWidth, MemoryLayout<Float>.size)

//    _waterDrawQ.async { [unowned self] in
//      autoreleasepool {
//        self._metalView.draw()
//      }
//    }
    }
    _isDrawing.signal()
  }
}
