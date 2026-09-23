#include "Includes/Common.hlsl"

cbuffer SceneBuffer : register(b0)
{
   float4x4 g_View : packoffset(c0);
   float4x4 g_Proj : packoffset(c4);
   float4x4 g_ViewProjection : packoffset(c8);
   float4x4 g_ViewInverseMatrix : packoffset(c12);
   float4x4 g_PrevView : packoffset(c16);
   float4x4 g_PrevProj : packoffset(c20);
   float4x4 g_PrevViewProjection : packoffset(c24);
   float4x4 g_PrevViewInverseMatrix : packoffset(c28);
   float4 g_ProjectionOffset : packoffset(c32);
   int g_FrameCount[4] : packoffset(c33);
}

cbuffer CamParam_HPixel_Buffer : register(b13)
{
   float4 g_CameraParam : packoffset(c0);
   float4 g_CameraVec : packoffset(c1);
   float4 g_CameraParam2 : packoffset(c2);
}

cbuffer ShaderParams : register(b11)
{
   float g_RangeNearest : packoffset(c0);
   float g_RangeToNear : packoffset(c0.y);
   float g_RangeNear : packoffset(c0.z);
   float g_RangeToFar : packoffset(c0.w);
   float g_PowerNearest : packoffset(c1);
   float g_PowerNear : packoffset(c1.y);
   float g_PowerFar : packoffset(c1.z);
   float g_ZRange : packoffset(c1.w);
   float g_resolutionScale_ : packoffset(c2);
   int reserved1_ : packoffset(c2.y);
   int reserved2_ : packoffset(c2.z);
   int reserved3_ : packoffset(c2.w);
   float depthLineThresholdOffset_ : packoffset(c3);
   float depthLineThresholdScale_ : packoffset(c3.y);
   float depthLineThresholdSmax_ : packoffset(c3.z);
   float depthLineThresholdSmin_ : packoffset(c3.w);
   float depthRangeScale_ : packoffset(c4);
   float depthOffset_ : packoffset(c4.y);
   float depthMin_ : packoffset(c4.z);
   float depthMax_ : packoffset(c4.w);
   float3 color_ : packoffset(c5);
   int reserved4_ : packoffset(c5.w);
   float coefficient_ : packoffset(c6);
   float coefficientAroundFrame_ : packoffset(c6.y);
   float coefficientNear_ : packoffset(c6.z);
   float pixelOffset_ : packoffset(c6.w);
   float width_ : packoffset(c7);
   float widthClose_ : packoffset(c7.y);
   float centerEmiStrength_ : packoffset(c7.z);
   float centerMaskSmax_ : packoffset(c7.w);
   float centerMaskSmin_ : packoffset(c8);
   int reserved5_ : packoffset(c8.y);
   int reserved6_ : packoffset(c8.z);
   int reserved7_ : packoffset(c8.w);
   float2 maskCenterPosition_ : packoffset(c9);
   int reserved8_ : packoffset(c9.z);
   int reserved9_ : packoffset(c9.w);
   float2 maskRatio_ : packoffset(c10);
   int reserved10_ : packoffset(c10.z);
   int reserved11_ : packoffset(c10.w);
   float4 screenSize_ : packoffset(c11);
   float farZ_ : packoffset(c12);
}

Texture2D<float4> SrcTexture : register(t0);
Texture2D<float4> DepthTexture : register(t2);
Texture2D<uint4> g_StencilBuffer : register(t25);
RWTexture2D<float4> OutputTexture : register(u0);

#define cmp -

[numthreads(16, 16, 1)]
void main(uint2 vThreadID: SV_DispatchThreadID)
{

   float4 r0, r1, r2, r3, r4, r5;

   int4 r0i = vThreadID.xyxy;
// #if TONEMAP_AFTER_TAA
//   r1.xy = cmp(r0.zw >= LumaSettings.SwapchainSize.xy);
// #else
//   r1.xy = cmp(r0.zw >= screenSize_.xy);
// #endif
//   r1.x = asfloat(asint(r1.y) | asint(r1.x));
//   if (r1.x != 0) {
//     return;
//   }
#if TONEMAP_AFTER_TAA
   if (any(vThreadID.xy >= (uint2)LumaSettings.SwapchainSize.xy))
   {
      return;
   }
#else
   if (any(vThreadID.xy >= (uint2)screenSize_.xy))
   {
      return;
   }
#endif

   r1.xy = vThreadID.xy;
   r1.zw = float2(0, 0);
   int3 loadCoord = int3(vThreadID.xy, 0);
   r2.xyz = SrcTexture.Load(loadCoord).xyz;
   OutputTexture[vThreadID.xy] = float4(r2.xyz, 1);
   return;
#if TONEMAP_AFTER_TAA
   if (LumaSettings.GameSettings.RenderScale != 1.0f)
   {
      uint2 depthCoord = min((uint2)floor((vThreadID.xy + 0.5f) * LumaSettings.GameSettings.RenderScale),
                             (uint2)(screenSize_.xy - 1.0f));
      r3.x = DepthTexture.Load(int3(depthCoord, 0)).x;
   }
   else
   {
      r3.x = DepthTexture.Load(int3(r1.xy, 0)).x;
   }
#else
   r3.x = DepthTexture.Load(r1.xyw).x;
#endif

   float4x4 _proj = g_Proj;

#if TONEMAP_AFTER_TAA
   _proj[2][0] = 0.0;
   _proj[2][1] = 0.0;
#endif
   r3.x = _proj._m22 + r3.x;
   r3.x = _proj._m32 / r3.x;
   r3.x = -g_CameraParam.x + r3.x;
   r3.y = 1 / g_CameraParam.y;
   r3.x = r3.x * r3.y;
   r3.y = cmp(r3.x < 0.99000001);
   if (r3.y != 0)
   {
#if TONEMAP_AFTER_TAA
      const float2 _outputSize = LumaSettings.SwapchainSize.xy;
      const float2 _invOutputSize = LumaSettings.SwapchainInvSize.xy;
      const uint2 _stencilCoord = min((uint2)floor((vThreadID.xy + 0.5f) * LumaSettings.GameSettings.RenderScale),
                                      (uint2)(screenSize_.xy - 1.0f));
#else
      const float2 _outputSize = screenSize_.xy;
      const float2 _invOutputSize = screenSize_.zw;
      const uint2 _stencilCoord = vThreadID.xy;
#endif
      r0.xyzw = _invOutputSize.xyxy * r0.xyzw;
      r1.x = g_StencilBuffer.Load(int3(_stencilCoord, 0)).y;
      r1.xy = (int2)r1.xx & int2(15, 128);
      r1.y = r1.y ? 9 : 0;
      r1.x = (int)r1.y + (int)r1.x;
      r1.y = farZ_ * r3.x;
      r1.z = r1.y * 0.0399999991 + depthLineThresholdOffset_;
      r1.z = -r1.z * depthLineThresholdScale_ + 1;
      r1.w = depthLineThresholdSmax_ + -depthLineThresholdSmin_;
      r1.z = -depthLineThresholdSmin_ + r1.z;
      r1.w = 1 / r1.w;
      r1.z = saturate(r1.z * r1.w);
      r1.w = r1.z * -2 + 3;
      r1.z = r1.z * r1.z;
      r1.z = r1.w * r1.z;
      r3.xy = r0.zw * float2(2, 2) + maskCenterPosition_.xy;
      r3.xy = float2(-1, -1) + r3.xy;
      r3.xy = maskRatio_.xy * r3.xy;
      r1.w = dot(r3.xy, r3.xy);
      r1.w = sqrt(r1.w);
      r3.x = -centerMaskSmin_ + centerMaskSmax_;
      r1.w = -centerMaskSmin_ + r1.w;
      r3.x = 1 / r3.x;
      r1.w = saturate(r3.x * r1.w);
      r3.x = r1.w * -2 + 3;
      r1.w = r1.w * r1.w;
      r1.w = r3.x * r1.w;
      r1.w = saturate(-r1.w * centerEmiStrength_ + 1);
      r3.x = max(-0.5, pixelOffset_);
      r3.x = min(0, r3.x);
      r3.xyzw = float4(0, 1, 0, -1) + r3.xxxx;
      r4.xyzw = r0.zwzw * _outputSize.xyxy + r3.yxwz;
      r4.xy = min(_outputSize.xy, r4.xy);
      r5.xy = (int2)r4.xy;
      r5.zw = float2(0, 0);
      r5.xyz = SrcTexture.Load(r5.xyz).xyz;
      r4.xy = max(float2(0, 0), r4.zw);
      r4.xy = (int2)r4.xy;
      r4.zw = float2(0, 0);
      r4.xyz = SrcTexture.Load(r4.xyz).xyz;
      r0.xyzw = r0.xyzw * _outputSize.xyxy + r3.xyzw;
      r0.xy = min(_outputSize.xy, r0.xy);
      r3.xy = (int2)r0.xy;
      r3.zw = float2(0, 0);
      r3.xyz = SrcTexture.Load(r3.xyz).xyz;
      r0.xy = max(float2(0, 0), r0.zw);
      r0.xy = (int2)r0.xy;
      r0.zw = float2(0, 0);
      r0.xyz = SrcTexture.Load(r0.xyz).xyz;
      r4.xyz = r5.xyz + -r4.xyz;
      r0.xyz = r3.xyz + -r0.xyz;
      r0.w = dot(r4.xyz, r4.xyz);
      r0.x = dot(r0.xyz, r0.xyz);
      r0.x = r0.w + r0.x;
      r0.y = coefficientNear_ + -coefficient_;
      r0.y = r1.z * r0.y + coefficient_;
      r0.y = -coefficientAroundFrame_ + r0.y;
      r0.y = r1.w * r0.y + coefficientAroundFrame_;
      r0.x = saturate(r0.x * r0.y);
      r0.yzw = float3(1, 1, 1) + -color_.xyz;
      r0.xyz = r0.yzw * r0.xxx;
      r0.w = r1.y * 0.0399999991 + depthOffset_;
      r0.w = saturate(depthRangeScale_ * r0.w);
      r0.xyz = r0.www * -r0.xyz;
      r3.xyzw = cmp((int4)r1.xxxx == int4(9, 10, 13, 11));
      r3.xyzw = r3.xyzw ? float4(1, 1, 1, 1) : 0;
      r0.w = r3.y + r3.z;
      r0.w = r0.w + r3.w;
      r1.x = cmp((int)r1.x == 12);
      r1.x = r1.x ? 1.000000 : 0;
      r0.w = r1.x + r0.w;
      r0.w = r0.w + r3.x;
      r0.w = min(1, r0.w);
      r0.w = 1 + -r0.w;
      r2.xyz = r0.www * r0.xyz + r2.xyz;
   }
   r2.w = 1;
   OutputTexture[vThreadID.xy] = float4(r2.xyz, r2.w);
   return;
}
