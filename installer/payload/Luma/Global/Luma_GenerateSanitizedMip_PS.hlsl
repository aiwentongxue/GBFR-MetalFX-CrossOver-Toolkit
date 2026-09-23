#include "../Includes/Common.hlsl"

// Needs to be a different resource from the render target in DX11, even if the views point at different mips
Texture2D<float4> sourceMip : register(t0);

// This can downscale mips and smooth out any NaNs with their closest non NaN value (iteratively)
float4 main(float4 pos : SV_Position) : SV_Target0
{
  const int2 pixelPos = pos.xy;

  // 2x2 box downsample
  float4 c0 = sourceMip.Load(int3(pixelPos.xy * 2, 0));
  float4 c1 = sourceMip.Load(int3(pixelPos.xy * 2 + int2(1,0), 0));
  float4 c2 = sourceMip.Load(int3(pixelPos.xy * 2 + int2(0,1), 0));
  float4 c3 = sourceMip.Load(int3(pixelPos.xy * 2 + int2(1,1), 0));

  float4 cSum = 0.0;
  float4 cWeight = 0.0;
  bool4 nans;

  // TODO: add a define to actually spread any NaN texel channel to all channels on all texels, to quickly detect them in games

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

  cSum /= cWeight;
  // Force keep to NaN if it was all NaNs
  cSum = (cWeight == 0.0) ? FLT_NAN : cSum;

  return cSum;
}