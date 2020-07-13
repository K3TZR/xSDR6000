//
//  WaterfallShaders.metal
//  xSDR6000
//
//  Created by Douglas Adams on 10/9/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// --------------------------------------------------------------------------------
// MARK: - Vertex & Fragment shaders for Waterfall draw calls
// --------------------------------------------------------------------------------

struct Intensity {                    // Intensity struct
  ushort  i;
};

struct BinValue {
  float   firstBinFrequency;
  float   binBandwidth;
};

struct Line {
  ushort  index ;
};

struct Constants {
  ushort  blackLevel;
  ushort  colorGain;
  ushort  numberOfBufferLines;
  ushort  numberOfScreenLines;
  ushort  topLineIndex;
  float   startingFrequency;
  float   endingFrequency;
};

struct VertexOutput {
  float4  coord [[ position ]];       // vertex coordinates
  float   intensity;                  // vertex intensity
};

// Waterfall vertex shader
//
//  - Parameters:
//    - intensities:    an array of Intensity structs
//    - Line:           an array of Line struct
//    - constants:      a Constants struct
//    - vertexId:       a system generated vertex index
//
//  - Returns:          a VertexOutput struct
//
vertex VertexOutput waterfall_vertex(const device Intensity* intensities [[ buffer(0) ]],
                                     const device BinValue &binValue [[ buffer(1) ]],
                                     const device Line &line [[ buffer(2) ]],
                                     constant Constants &constants [[ buffer(3) ]],
                                     unsigned int vertexId [[ vertex_id ]])

{
  VertexOutput v_out;
  float  xCoord;
  float  yCoord;
  float  power;
  
  float startingBin;
  float endingBin;
  float deltaX;
  
  startingBin = (constants.startingFrequency - binValue.firstBinFrequency) / binValue.binBandwidth;
  endingBin = (constants.endingFrequency - binValue.firstBinFrequency) / binValue.binBandwidth;
  deltaX = 1.0 / (endingBin - startingBin);

  // calculate the x coordinate & normalize to clip space
  xCoord = ((float(vertexId - startingBin) * deltaX) * 2) - 1 ;
  
  // normalize the y coordinate to clip space
  yCoord = ( ( (float(line.index) / float(constants.numberOfScreenLines - 1)) * 2.0) - 1.0);

  // pass the vertex & texture coordinates to the Fragment shader
  v_out.coord = float4(xCoord, yCoord, 0.0, 1.0);
  
  // is the intensity below the black level?
  if (intensities[vertexId].i < constants.blackLevel) {
    // YES, ignore it
    v_out.intensity = 0;
    
  } else {
    
    // NO, make it non-linear
    power = pow( (1.0 + float(constants.colorGain)/100.0), 4.0 );
    
    // normalize it (0 -> UInt16.max becomes 0.0 -> 1.0)
    v_out.intensity = float( (intensities[vertexId].i - constants.blackLevel) / float(65536) ) * power;
  }
  
  return v_out;
}

// Waterfall fragment shader
///
//  - Parameters:
//    - in:             VertexOutput struct
//  - Returns:          the fragment color
//
fragment float4 waterfall_fragment( VertexOutput in [[ stage_in ]],
                                   texture1d<float, access::sample> gradientTexture [[texture(0)]],
                                   sampler gradientTextureSampler [[sampler(0)]])
{
  // paint the fragment with the gradient color
  return float4( gradientTexture.sample(gradientTextureSampler, in.intensity));
}
