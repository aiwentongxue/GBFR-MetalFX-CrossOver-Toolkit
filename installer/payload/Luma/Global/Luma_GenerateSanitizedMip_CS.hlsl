#include "../Includes/Common.hlsl"

#define USE_UAV_SOURCE 1

#if USE_UAV_SOURCE
RWTexture2D<float4> sourceMip : register(u0);
RWTexture2D<float4> targetMip : register(u1);
#else
Texture2D<float4> sourceMip : register(t0);
RWTexture2D<float4> targetMip : register(u0);
#endif

// This can downscale mips and smooth out any NaNs with their closest non NaN value (iteratively)
[numthreads(8,8,1)]
void main(uint3 vDispatchThreadId : SV_DispatchThreadID)
{
  const uint3 pixelPos = vDispatchThreadId;

  uint2 size;
  targetMip.GetDimensions(size.x, size.y);

  if (pixelPos.x >= size.x || pixelPos.y >= size.y) return;

  // 2x2 box downsample
#if USE_UAV_SOURCE
  float4 c0 = sourceMip[pixelPos.xy * 2];
  float4 c1 = sourceMip[pixelPos.xy * 2 + int2(1,0)];
  float4 c2 = sourceMip[pixelPos.xy * 2 + int2(0,1)];
  float4 c3 = sourceMip[pixelPos.xy * 2 + int2(1,1)];
#else
  float4 c0 = sourceMip.Load(int3(pixelPos.xy * 2, 0));
  float4 c1 = sourceMip.Load(int3(pixelPos.xy * 2 + int2(1,0), 0));
  float4 c2 = sourceMip.Load(int3(pixelPos.xy * 2 + int2(0,1), 0));
  float4 c3 = sourceMip.Load(int3(pixelPos.xy * 2 + int2(1,1), 0));
#endif

  float4 cSum = 0.0;
  float4 cWeight = 0.0;
  bool4 nans;

  // Note: classic NaNs checks might not be performed unless we build with /Gis, so we use strict ones
  nans = IsNaN_Strict(c0);
  cSum += nans ? 0.0 : c0;
  cWeight += nans ? 0.0 : 1.0;

  nans = IsNaN_Strict(c1);
  cSum += nans ? 0.0 : c1;
  cWeight += nans ? 0.0 : 1.0;
  
  nans = IsNaN_Strict(c2);
  cSum += nans ? 0.0 : c2;
  cWeight += nans ? 0.0 : 1.0;

  nans = IsNaN_Strict(c3);
  cSum += nans ? 0.0 : c3;
  cWeight += nans ? 0.0 : 1.0;

  // Force keep to NaN if it was all NaNs
  cSum /= cWeight;
  cSum = (cWeight == 0.0) ? FLT_NAN : cSum;
  
#if 0 // TODO: delete
  uint2 sizeSource;
  sourceMip.GetDimensions(sizeSource.x, sizeSource.y);
  //targetMip[pixelPos.xy] = sizeSource.y / 80.0 ; return;
  if (sizeSource.y >= 2160)
  {
     targetMip[pixelPos.xy] = float4(1, 0, 0, 0); return;
  }
  if (sizeSource.y >= (2160 / 2))
  {
     targetMip[pixelPos.xy] = float4(0, 1, 0, 0); return;
  }
  if (sizeSource.y >= (2160 / 4))
  {
     targetMip[pixelPos.xy] = float4(0, 0, 1, 0); return;
  }
#endif

  targetMip[pixelPos.xy] = cSum;
}