// ---- Created with 3Dmigoto v1.4.1 on Sun Apr  5 13:36:53 2026
#include "Includes/Common.hlsl"

cbuffer HPixel_Buffer : register(b12)
{
  float4 g_TargetUvParam : packoffset(c0);
}

cbuffer ParamBuffer : register(b10)
{
  float4 screenSize_ : packoffset(c0);
  float blurSize_ : packoffset(c1);
  float samplingStride_ : packoffset(c1.y);
}

Texture2D<float4> ColorTexture : register(t0);
Texture2D<float4> DenoisedColorTexture : register(t1);
Texture2D<float4> TiledVelocityTexture : register(t4);
Texture2D<float4> DepthVelocityTexture : register(t5);


// 3Dmigoto declarations
#define cmp -


void main(
  float4 v0 : SV_Position0,
  float2 v1 : TEXCOORD0,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1,r2,r3,r4,r5,r6,r7;
  uint4 bitmask, uiDest;
  float4 fDest;
#if TONEMAP_AFTER_TAA
  float4 targetUvParam = float4(LumaSettings.SwapchainInvSize, LumaSettings.SwapchainInvSize);
#else
  float4 targetUvParam = g_TargetUvParam;
#endif
  r0.xy = (int2)v0.xy;
  r1.x = rcp(targetUvParam.w);
  r2.xy = (uint2)r0.xy >> int2(3,3);
  r2.zw = float2(0,0);
  r1.yz = TiledVelocityTexture.Load(r2.xyz).xy;
  r1.w = dot(r1.yz, r1.yz);
  r2.x = cmp(9.99999975e-05 < r1.w);
  if (r2.x != 0) {
    r0.z = 0;
    r2.xyzw = DenoisedColorTexture.Load(r0.xyz).xyzw;
  } else {
    r0.w = 0;
    r2.xyzw = ColorTexture.Load(r0.xyw).xyzw;
  }
  r1.x = r1.x * r1.x;
  r1.x = cmp(r1.w < r1.x);
  if (r1.x != 0) {
    o0.xyzw = r2.xyzw;
    return;
  }
  r3.xy = v0.xy / targetUvParam.zw;
  r0.zw = float2(0,0);
  r0.xy = DepthVelocityTexture.Load(r0.xyz).xy;
  r0.zw = float2(1,0.015625) * r0.xy;
  r0.w = r0.w * r0.w;
  r0.y = r0.y * 0.015625 + 1.00000001e-07;
  r0.y = 1 / r0.y;
  r0.y = saturate(r0.y);
  r2.xyz = r2.xyz * r0.yyy;
  r1.x = cmp(1.5 < samplingStride_);
  r1.x = r1.x ? 0.300000012 : 0.170000002;
  r1.x = blurSize_ * r1.x;
  r1.w = 1.00000001e-07 + r1.w;
  r1.w = sqrt(r1.w);
  r2.w = dot(r3.xy, float2(12.9898005,78.2330017));
  r2.w = sin(r2.w);
  r2.w = 43758.5469 * r2.w;
  r2.w = frac(r2.w);
  r2.w = -0.5 + r2.w;
  r2.w = r2.w * r1.w;
  r1.w = r1.w * 96 + 2.5;
  r1.w = min(9, r1.w);
  r1.w = (int)r1.w;
  r3.z = (int)r1.w | 1;
  r1.w = (uint)r1.w >> 1;
  r3.w = (int)r3.z;
  r3.w = 1 / r3.w;
  r4.x = 0.0999999642 * r0.w;
  r4.x = 1 / r4.x;
  r5.zw = float2(0,0);
  r4.yzw = r2.xyz;
  r6.x = r0.y;
  r6.y = 0;
  while (true) {
    r6.z = cmp((int)r6.y >= (int)r3.z);
    if (r6.z != 0) break;
    r6.z = (int)-r1.w + (int)r6.y;
    if (r6.z == 0) {
      r6.w = (int)r6.y + 1;
      r6.y = r6.w;
      continue;
    }
    r6.z = (int)r6.z;
    r6.z = r2.w * 4 + r6.z;
    r6.z = r6.z * r3.w;
    r6.z = r6.z * r1.x;
    r6.zw = r1.yz * r6.zz + r3.xy;
    r7.xy = saturate(r6.zw);
    r7.xy = targetUvParam.zw * r7.xy;
    r5.xy = (int2)r7.xy;
    r7.xy = DepthVelocityTexture.Load(r5.xyw).xy;
    r7.yz = float2(1,0.015625) * r7.xy;
    r7.z = r7.z * r7.z;
    r6.zw = -r6.zw + r3.xy;
    r6.z = dot(r6.zw, r6.zw);
    r6.w = r7.x * 1 + -r0.z;
    r6.w = saturate(-r6.w * 100 + 1);
    r7.x = r6.z / r7.z;
    r7.x = 1 + -r7.x;
    r7.y = r0.x * 1 + -r7.y;
    r7.y = saturate(-r7.y * 100 + 1);
    r7.w = 0.000500000024 + r6.z;
    r7.w = r7.w / r0.w;
    r7.w = 1 + -r7.w;
    r7.xw = max(float2(0,0), r7.xw);
    r7.y = r7.y * r7.w;
    r6.w = r6.w * r7.x + r7.y;
    r7.x = 0.0999999642 * r7.z;
    r7.y = -r7.z * 0.949999988 + r6.z;
    r7.x = 1 / r7.x;
    r7.x = saturate(r7.y * r7.x);
    r7.y = r7.x * -2 + 3;
    r7.x = r7.x * r7.x;
    r7.x = -r7.y * r7.x + 1;
    r7.x = max(0, r7.x);
    r6.z = -r0.w * 0.949999988 + r6.z;
    r6.z = saturate(r6.z * r4.x);
    r7.y = r6.z * -2 + 3;
    r6.z = r6.z * r6.z;
    r6.z = -r7.y * r6.z + 1;
    r6.z = max(0, r6.z);
    r6.z = dot(r7.xx, r6.zz);
    r6.z = r6.w + r6.z;
    r6.z = min(1, r6.z);
    r7.xyz = DenoisedColorTexture.Load(r5.xyz).xyz;
    r4.yzw = r7.xyz * r6.zzz + r4.yzw;
    r6.x = r6.x + r6.z;
    r6.y = (int)r6.y + 1;
  }
  o0.xyz = r4.yzw / r6.xxx;
  o0.w = 1;
  return;
}