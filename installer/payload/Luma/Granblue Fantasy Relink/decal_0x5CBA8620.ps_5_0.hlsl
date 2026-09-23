
struct DecalData
{
    float4x3 worldMtx;             // Offset:    0
    float4x3 invWorldMtx;          // Offset:   48
    float4x3 rot;                  // Offset:   96
    float4x4 colormatrix;          // Offset:  144
    float alpha;                   // Offset:  208
    float cliffAlpha;              // Offset:  212
    float useMask_Box;             // Offset:  216
    float useMask_Sphere;          // Offset:  220
    float useOverrideRoughtness;   // Offset:  224
    float Roughtness;              // Offset:  228
    float useWet;                  // Offset:  232
    float uvfluffy;                // Offset:  236
    float AlbedoIntensity;         // Offset:  240
    float AffectAngleAlpha;        // Offset:  244
    float parallaxStepScale;       // Offset:  248
    float stepCount;               // Offset:  252
    float2 uvScroll;               // Offset:  256
    float2 uvTiling;               // Offset:  264
    float4 uvClip;                 // Offset:  272
    float4 Mask;                   // Offset:  288
    float2 mask_tiling;            // Offset:  304
    float CutOcclusion;            // Offset:  312
    float directivityFlag;         // Offset:  316
    float3 directivityCameraVec;   // Offset:  320
    float directivityRate;         // Offset:  332
    float directivityReverse;      // Offset:  336
    float directivityAlphaReverse; // Offset:  340
    float uselengthFade;           // Offset:  344
    float lengthFadeReverse;       // Offset:  348
    float lengthFadeAlphaDistance; // Offset:  352
    float lengthFadeMin;           // Offset:  356
    float lengthFadeMax;           // Offset:  360
    float lengthFadePower;         // Offset:  364
};

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

cbuffer HPixel_Buffer : register(b12)
{
  float4 g_TargetUvParam : packoffset(c0);
}

cbuffer CamParam_HPixel_Buffer : register(b13)
{
  float4 g_CameraParam : packoffset(c0);
  float4 g_CameraVec : packoffset(c1);
  float4 g_CameraParam2 : packoffset(c2);
}

SamplerState g_AlbedTextureSampler_s : register(s4);
SamplerState g_MGOTextureSampler_s : register(s6);
SamplerState g_MaskTextureSampler_s : register(s8);
StructuredBuffer<DecalData> instanceData : register(t0);
Texture2D<float4> g_AlbedTexture : register(t4);
Texture2D<float4> g_MGOTexture : register(t6);
Texture2D<float4> g_MaskTexture : register(t8);
Texture2D<float4> g_GeometryBuffer01 : register(t21);
Texture2D<float4> g_ZBuffer : register(t24);

#define cmp -

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD1,
  float4 v2 : TEXCOORD2,
  nointerpolation uint v3 : INSTANCE_ID0,
  out float4 o0 : SV_Target0,
  out float4 o1 : SV_Target1)
{
  float4 r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.x = instanceData[v3.x].invWorldMtx._m00;
  r0.y = instanceData[v3.x].invWorldMtx._m10;
  r0.z = instanceData[v3.x].invWorldMtx._m20;
  r0.w = instanceData[v3.x].invWorldMtx._m30;
  r1.x = instanceData[v3.x].invWorldMtx._m01;
  r1.y = instanceData[v3.x].invWorldMtx._m11;
  r1.z = instanceData[v3.x].invWorldMtx._m21;
  r1.w = instanceData[v3.x].invWorldMtx._m31;
  r2.x = instanceData[v3.x].invWorldMtx._m02;
  r2.y = instanceData[v3.x].invWorldMtx._m12;
  r2.z = instanceData[v3.x].invWorldMtx._m22;
  r2.w = instanceData[v3.x].invWorldMtx._m32;
  r3.x = instanceData[v3.x].rot._m20;
  r3.y = instanceData[v3.x].rot._m21;
  r3.z = instanceData[v3.x].rot._m22;
  r4.x = instanceData[v3.x].alpha;
  r4.y = instanceData[v3.x].cliffAlpha;
  r4.z = instanceData[v3.x].useMask_Box;
  r4.w = instanceData[v3.x].useMask_Sphere;
  r5.x = instanceData[v3.x].useOverrideRoughtness;
  r5.y = instanceData[v3.x].Roughtness;
  r5.z = instanceData[v3.x].useWet;
  r5.w = instanceData[v3.x].uvfluffy;
  r6.x = instanceData[v3.x].AlbedoIntensity;
  r6.y = instanceData[v3.x].AffectAngleAlpha;
  r7.x = instanceData[v3.x].uvScroll.x;
  r7.y = instanceData[v3.x].uvScroll.y;
  r7.z = instanceData[v3.x].uvTiling.x;
  r7.w = instanceData[v3.x].uvTiling.y;
  r8.x = instanceData[v3.x].uvClip.x;
  r8.y = instanceData[v3.x].uvClip.y;
  r8.z = instanceData[v3.x].uvClip.z;
  r8.w = instanceData[v3.x].uvClip.w;
  r9.x = instanceData[v3.x].Mask.x;
  r9.y = instanceData[v3.x].Mask.y;
  r9.z = instanceData[v3.x].Mask.z;
  r9.w = instanceData[v3.x].Mask.w;
  r10.x = instanceData[v3.x].mask_tiling.x;
  r10.y = instanceData[v3.x].mask_tiling.y;
  r10.z = instanceData[v3.x].CutOcclusion;
  r10.w = instanceData[v3.x].directivityFlag;
  r11.x = instanceData[v3.x].directivityCameraVec.x;
  r11.y = instanceData[v3.x].directivityCameraVec.y;
  r11.z = instanceData[v3.x].directivityCameraVec.z;
  r11.w = instanceData[v3.x].directivityRate;
  r12.x = instanceData[v3.x].directivityReverse;
  r12.y = instanceData[v3.x].directivityAlphaReverse;
  r12.z = instanceData[v3.x].uselengthFade;
  r12.w = instanceData[v3.x].lengthFadeReverse;
  r13.x = instanceData[v3.x].lengthFadeAlphaDistance;
  r13.y = instanceData[v3.x].lengthFadeMin;
  r13.z = instanceData[v3.x].lengthFadeMax;
  r13.w = instanceData[v3.x].lengthFadePower;
  r6.zw = v0.xy / g_TargetUvParam.zw;
  r14.xy = (int2)v0.xy;
  r14.zw = float2(0,0);
  r3.w = g_GeometryBuffer01.Load(r14.xyw).z;
  r14.x = g_ZBuffer.Load(r14.xyz).x;
  r15.x = 1 / g_Proj._m00;
  r15.y = 1 / g_Proj._m11;
  r14.x = r14.x * g_CameraParam.y + g_CameraParam.x;
  r6.zw = r6.zw * float2(2,-2) + float2(-1,1);
  r6.zw = r6.zw * r14.xx;
  r15.xy = r6.zw * r15.xy;
  r15.z = -r14.x;
  r15.w = 1;
  r14.x = dot(r15.xyzw, g_ViewInverseMatrix._m00_m10_m20_m30);
  r14.y = dot(r15.xyzw, g_ViewInverseMatrix._m01_m11_m21_m31);
  r14.z = dot(r15.xyzw, g_ViewInverseMatrix._m02_m12_m22_m32);
  r14.w = 1;
  r0.x = dot(r14.xyzw, r0.xyzw);
  r0.y = dot(r14.xyzw, r1.xyzw);
  r0.z = dot(r14.xyzw, r2.xyzw);
  r0.w = -r0.x + r8.y;
  r0.w = -0.5 + r0.w;
  r1.xyz = float3(0.5,0.5,0.5) + r0.xxy;
  r1.w = 0.5 + -r0.y;
  r1.xw = r1.xw + -r8.xz;
  r2.x = r0.y + r8.w;
  r2.x = -0.5 + r2.x;
  r1.w = min(r2.x, r1.w);
  r1.x = min(r1.x, r1.w);
  r0.w = min(r1.x, r0.w);
  r0.w = cmp(r0.w < 0);
  if (r0.w != 0) discard;
  r2.xyz = float3(0.5,0.5,0.5) + -abs(r0.xyz);
  r8.xyz = cmp(r2.xyz < float3(0,0,0));
  r0.w = (int)r8.y | (int)r8.x;
  r0.w = (int)r8.z | (int)r0.w;
  if (r0.w != 0) discard;
  r1.xw = r1.yz + r7.xy;
  r1.xw = r1.xw * r7.zw;
  r0.w = r1.z * r10.y;
  r6.zw = float2(25.1327419,25.1327419) * r1.yz;
  r6.zw = sin(r6.zw);
  r6.zw = g_CameraVec.ww + r6.zw;
  r6.zw = sin(r6.zw);
  r6.zw = r6.zw * r5.ww;
  r7.x = r1.y * r10.x + r6.w;
  r7.y = r6.z * 0.5 + r0.w;
  r7.xyzw = g_MaskTexture.Sample(g_MaskTextureSampler_s, r7.xy).xyzw;
  r7.xyzw = r7.xyzw * r9.xyzw;
  r0.w = dot(r7.xyzw, r7.xyzw);
  r0.w = sqrt(r0.w);
  r0.w = min(1, r0.w);
  r1.y = r4.x * r0.w;
  r0.w = r4.x * r0.w + -0.00999999978;
  r0.w = cmp(r0.w < 0);
  if (r0.w != 0) discard;
  r4.xz = cmp(float2(0.5,0.5) < r4.zw);
  r2.xyz = r2.xyz + r2.xyz;
  r0.w = min(r2.x, r2.y);
  r0.w = min(r0.w, r2.z);
  r0.w = max(0, r0.w);
  r0.w = r0.w * -2 + 1;
  r0.w = 1 + -r0.w;
  r0.w = min(1, r0.w);
  r0.w = r1.y * r0.w;
  r0.w = r4.x ? r0.w : r1.y;
  r0.x = dot(r0.xyz, r0.xyz);
  r0.x = sqrt(r0.x);
  r0.x = 0.5 + -r0.x;
  r0.x = r0.x + r0.x;
  r0.x = max(0, r0.x);
  r0.x = 1 + -r0.x;
  r0.x = r0.x * r0.x;
  r0.x = -r0.x * r0.x + 1;
  r0.x = r0.w * r0.x;
  r0.x = r4.z ? r0.x : r0.w;
  r0.yz = cmp(float2(0,0) != r10.zw);
  r0.w = r0.x * r3.w;
  r0.x = r0.y ? r0.w : r0.x;
  r2.xyz = g_CameraVec.xyz + -r14.xyz;
  r4.xzw = cmp(float3(0,0,0) != r12.xyw);
  r0.y = dot(r11.xyz, r2.xyz);
  r0.w = dot(r2.xyz, r2.xyz);
  r1.y = rsqrt(r0.w);
  r2.xyz = r2.xyz * r1.yyy;
  r1.y = dot(r11.xyz, r2.xyz);
  r0.y = saturate(r4.x ? abs(r0.y) : r1.y);
  r0.y = log2(r0.y);
  r0.y = r11.w * r0.y;
  r0.y = exp2(r0.y);
  r1.y = 1 + -r0.y;
  r0.y = r4.z ? r1.y : r0.y;
  r0.y = r0.x * r0.y;
  r0.x = r0.z ? r0.y : r0.x;
  r0.y = cmp(0.5 < r12.z);
  r0.z = sqrt(r0.w);
  r0.z = r0.z + -r13.x;
  r0.w = 1 / r13.x;
  r0.z = saturate(r0.z * r0.w);
  r0.w = r0.z * -2 + 3;
  r0.z = r0.z * r0.z;
  r0.z = r0.w * r0.z;
  r0.z = max(0.00100000005, r0.z);
  r0.z = log2(r0.z);
  r0.z = r13.w * r0.z;
  r0.z = exp2(r0.z);
  r0.w = 1 + -r0.z;
  r0.z = r4.w ? r0.w : r0.z;
  r0.z = max(r0.z, r13.y);
  r0.z = min(r0.z, r13.z);
  r0.z = r0.x * r0.z;
  r0.x = r0.y ? r0.z : r0.x;
  r0.yzw = ddx_fine(r14.yzx);
  r2.xyz = ddy_fine(r14.zxy);
  r4.xzw = r2.xyz * r0.yzw;
  r0.yzw = r2.zxy * r0.zwy + -r4.xzw;
  r1.y = dot(r0.yzw, r0.yzw);
  r1.y = rsqrt(r1.y);
  r0.yzw = r1.yyy * r0.yzw;
  r1.y = cmp(0 != r6.y);
  r0.y = saturate(dot(r3.xyz, r0.yzw));
  r0.y = max(0.00999999978, r0.y);
  r0.y = log2(r0.y);
  r0.y = r4.y * r0.y;
  r0.y = exp2(r0.y);
  r0.y = r0.x * r0.y;
  r0.x = r1.y ? r0.y : r0.x;
  r0.yz = cmp(float2(0.5,0.5) < r5.zx);
  if (r0.y != 0) {
    r0.y = r0.x * r6.x;
    r2.xyz = float3(0,0,0);
  } else {
    r3.x = instanceData[v3.x].colormatrix._m00;
    r3.y = instanceData[v3.x].colormatrix._m10;
    r3.z = instanceData[v3.x].colormatrix._m20;
    r3.w = instanceData[v3.x].colormatrix._m30;
    r4.x = instanceData[v3.x].colormatrix._m01;
    r4.y = instanceData[v3.x].colormatrix._m11;
    r4.z = instanceData[v3.x].colormatrix._m21;
    r4.w = instanceData[v3.x].colormatrix._m31;
    r7.x = instanceData[v3.x].colormatrix._m02;
    r7.y = instanceData[v3.x].colormatrix._m12;
    r7.z = instanceData[v3.x].colormatrix._m22;
    r7.w = instanceData[v3.x].colormatrix._m32;
    r8.xyzw = g_AlbedTexture.Sample(g_AlbedTextureSampler_s, r1.xw).xyzw;
    r6.xyz = r8.xyz * r6.xxx;
    r6.w = 1;
    r2.x = dot(r6.xyzw, r3.xyzw);
    r2.y = dot(r6.xyzw, r4.xyzw);
    r2.z = dot(r6.xyzw, r7.xyzw);
    r0.y = r8.w * r0.x;
  }
  r2.w = r0.x * r0.y;
  r0.x = r0.x * r0.y + -9.99999975e-05;
  r0.x = cmp(r0.x < 0);
  if (r0.x != 0) discard;
  r0.x = g_MGOTexture.Sample(g_MGOTextureSampler_s, r1.xw).y;
  r0.x = 1 + -r0.x;
  o1.y = r0.z ? r5.y : r0.x;
  o0.xyzw = r2.xyzw;
  o0 = max(0.f, o0);
  o1.xz = float2(0,0);
  o1.w = r2.w;
  o0 = max(0.f, o0);
  return;
}