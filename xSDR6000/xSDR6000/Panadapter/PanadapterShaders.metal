//
//  Shaders.metal
//  xSDR6000
//
//  Created by Douglas Adams on 6/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// --------------------------------------------------------------------------------
// MARK: - Shader structures
// --------------------------------------------------------------------------------

struct SpectrumValue {                      // intensity values
  ushort          i;
};

struct Constants {                          // constant values
  float           delta;
  float           height;
  unsigned int    maxNumberOfBins;
};

struct Color {                              // color value
  float4          spectrumColor;
};

struct VertexOutput {                       // vertex output
  float4          coord [[ position ]];
  half4           spectrumColor;
};

// --------------------------------------------------------------------------------
// MARK: - Shaders for Panadapter Spectrum draw calls
// --------------------------------------------------------------------------------

// Panadapter vertex shader
//
//  Parameters:
//      intensities:      an array of vertices at position 0 (in problem space, ushort i.e. 16-bit unsigned)
//      vertexId:         a system generated vertex index
//      constants:        constant parameter values
//      color:            constant color value
//
//  Returns:
//      a VertexOutput struct
//
vertex VertexOutput panadapter_vertex(const device SpectrumValue* intensities [[ buffer(0) ]],
                                      unsigned int vertexId [[ vertex_id ]],
                                      constant Constants &constants [[ buffer(1) ]],
                                      constant Color &color [[ buffer(2) ]])
{    
  VertexOutput v_out;
  float xCoord;
  float yCoord;
  
  unsigned int effectiveVertexId;
  float intensity;
  
  // is this a "real" vertex?
  if (vertexId < constants.maxNumberOfBins ) {
    
    // YES, y values must be flipped and normalized
    intensity = float(intensities[vertexId].i);
    yCoord = -( (2.0 * intensity/constants.height ) - 1 );
    
    // use the vertexId "as-is"
    effectiveVertexId = vertexId;

  } else {
    
    // NO, y value always -1 (bottom of the view)
    yCoord = -1;
    
    // calculate an effective vertexId
    effectiveVertexId = vertexId - constants.maxNumberOfBins;
  }
  // calculate the x coordinate & normalize to clip space
  xCoord = ((float(effectiveVertexId) * constants.delta) * 2) - 1 ;
  
  // send the clip space coords to the fragment shader
  v_out.coord = float4( xCoord, yCoord, 0.0, 1.0);
  
  // pass the color to the fragment shader
  v_out.spectrumColor = half4(color.spectrumColor);
  
  return v_out;
}

// Panadapter fragment shader
//  Parameters:
//      in:         VertexOutput struct
//
//  Returns:
//      the fragment color
//
fragment half4 panadapter_fragment( VertexOutput in [[ stage_in ]])
{
  return in.spectrumColor;
}

