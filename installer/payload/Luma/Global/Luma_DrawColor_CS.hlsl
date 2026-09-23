#include "../Includes/Common.hlsl"

// TODO: we just assume that the target UV is 0? Should we do all of them instead? We still wouldn't know what pixels the original shader was writing.
RWTexture2D<float4> sourceTargetTexture : register(u0);

#ifndef COLOR
#define COLOR float4(0, 0, 0, 0)
#endif

// TODO: is that even necessary?
// numthreads as 1 1 1 to make it compatible with any dispatch size
[numthreads(1,1,1)]
void main(uint3 vDispatchThreadId : SV_DispatchThreadID)
{
  const int3 pixelPos = int3(vDispatchThreadId);
  
  uint width, height;
  sourceTargetTexture.GetDimensions(width, height);
  if (pixelPos.x >= (int)width || pixelPos.y >= (int)height)
    return;
    
  sourceTargetTexture[uint2(pixelPos.xy)] = COLOR;
}