#include "../Includes/Common.hlsl"

Texture2D<float4> sourceTexture : register(t0);
SamplerState pointSampler : register(s0);
RWTexture2D<float4> sourceTargetTexture : register(u0);

#if CS
[numthreads(8,8,1)]
void main(uint3 vDispatchThreadId : SV_DispatchThreadID)
#else // PS
float4 main(float4 pos : SV_Position) : SV_Target0
#endif
{
#if CS
  const uint3 pixelPos = vDispatchThreadId;
  
  uint width, height;
  sourceTargetTexture.GetDimensions(width, height);
  if (pixelPos.x >= width || pixelPos.y >= height)
    return;

  float4 color = sourceTargetTexture[pixelPos.xy];
#else // PS
  float2 size;
  sourceTexture.GetDimensions(size.x, size.y);

  float2 uv = pos.xy / size;
  
  float4 color = sourceTexture.Sample(pointSampler, uv);
#endif

  color = IsNaN_Strict(color) ? 0.0 : color;
  
#if 1 // Optionally saturate alpha, which is almost always wanted (e.g. emulating UNORM behaviour on FLOAT)
  color.a = saturate(color.a);
#endif

#if CS
  sourceTargetTexture[pixelPos.xy] = color;
#else // PS
  return color;
#endif
}