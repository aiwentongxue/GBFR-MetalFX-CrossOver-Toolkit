
#include "../Includes/ColorGradingLUT.hlsl"

Texture3D<float4> sourceLUT : register(t0);
RWTexture3D<float4> targetLUT : register(u0);

SamplerState linearSampler : register(s0);

// Scale LUT input coordinates to acknowledge the half texel offset
float3 ColorToUVZ(float3 color, float3 size)
{
  float3 scale = (size - 1.0) / size;
  float3 bias = 0.5 / size;
  return saturate(color) * scale + bias;
}

// Corrects a LUT out from a LUT in. Works on any size.
[numthreads(8, 8, 8)]
void main(uint3 vDispatchThreadId : SV_DispatchThreadID)
{
  const int3 pixelPos = int3(vDispatchThreadId);
  
  uint width, height, depth;
  sourceLUT.GetDimensions(width, height, depth);
  if (pixelPos.x >= (int)width || pixelPos.y >= (int)height || pixelPos.z >= (int)depth)
    return;
  float3 size = float3(width, height, depth);
  
  float4 originalColor = sourceLUT.Load(int4(pixelPos, 0));
  float4 black = sourceLUT.SampleLevel(linearSampler, ColorToUVZ(0.0, size), 0.0);
  float4 midGrey = sourceLUT.SampleLevel(linearSampler, ColorToUVZ(0.5, size), 0.0);
  float4 white = sourceLUT.SampleLevel(linearSampler, ColorToUVZ(1.0, size), 0.0);
  float4 neutralColor = float4(float3(pixelPos) / (size - 1.0), 1.0);

#if 1
  targetLUT[uint3(pixelPos.xyz)] = float4(NormalizeLUT(originalColor.rgb, black.rgb, midGrey.rgb, white.rgb, neutralColor.rgb), originalColor.a); // TODO: do OKLAB hue restore on the original hue!!!
#elif 1 // TEST: no correction
  targetLUT[uint3(pixelPos.xyz)] = originalColor;
#else // TEST: purple
  targetLUT[uint3(pixelPos.xyz)] = float4(1, 1, 1, 1);
#endif
}