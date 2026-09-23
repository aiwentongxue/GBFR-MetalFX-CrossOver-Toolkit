
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
StructuredBuffer<DecalData> instanceData : register(t0);
Texture2D<float4> g_AlbedTexture : register(t4);
Texture2D<float4> g_GeometryBuffer01 : register(t21);
Texture2D<float4> g_ZBuffer : register(t24);

#define cmp -

void main(
  float4 v0 : SV_Position0,
  float4 v1 : TEXCOORD1,
  float4 v2 : TEXCOORD2,
  nointerpolation uint v3 : INSTANCE_ID0,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12;
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
  r3.w = instanceData[v3.x].useWet;
  r5.x = instanceData[v3.x].AlbedoIntensity;
  r5.y = instanceData[v3.x].AffectAngleAlpha;
  r6.x = instanceData[v3.x].uvClip.x;
  r6.y = instanceData[v3.x].uvClip.y;
  r6.z = instanceData[v3.x].uvClip.z;
  r6.w = instanceData[v3.x].uvClip.w;
  r7.x = instanceData[v3.x].directivityCameraVec.x;
  r7.y = instanceData[v3.x].directivityCameraVec.y;
  r7.z = instanceData[v3.x].CutOcclusion;
  r7.w = instanceData[v3.x].directivityFlag;
  r8.x = instanceData[v3.x].directivityCameraVec.z;
  r8.y = instanceData[v3.x].directivityRate;
  r8.z = instanceData[v3.x].directivityReverse;
  r8.w = instanceData[v3.x].directivityAlphaReverse;
  r9.x = instanceData[v3.x].uselengthFade;
  r9.y = instanceData[v3.x].lengthFadeReverse;
  r9.z = instanceData[v3.x].lengthFadeAlphaDistance;
  r9.w = instanceData[v3.x].lengthFadeMin;
  r5.z = instanceData[v3.x].lengthFadeMax;
  r5.w = instanceData[v3.x].lengthFadePower;
  r10.xy = v0.xy / g_TargetUvParam.zw;
  r11.xy = (int2)v0.xy;
  r11.zw = float2(0,0);
  r10.z = g_GeometryBuffer01.Load(r11.xyw).z;
  r10.w = g_ZBuffer.Load(r11.xyz).x;
  r11.x = 1 / g_Proj._m00;
  r11.y = 1 / g_Proj._m11;
  r10.w = r10.w * g_CameraParam.y + g_CameraParam.x;
  r10.xy = r10.xy * float2(2,-2) + float2(-1,1);
  r10.xy = r10.xy * r10.ww;
  r11.xy = r10.xy * r11.xy;
  r11.z = -r10.w;
  r11.w = 1;
  r12.x = dot(r11.xyzw, g_ViewInverseMatrix._m00_m10_m20_m30);
  r12.y = dot(r11.xyzw, g_ViewInverseMatrix._m01_m11_m21_m31);
  r12.z = dot(r11.xyzw, g_ViewInverseMatrix._m02_m12_m22_m32);
  r12.w = 1;
  r0.x = dot(r12.xyzw, r0.xyzw);
  r0.y = dot(r12.xyzw, r1.xyzw);
  r0.z = dot(r12.xyzw, r2.xyzw);
  r0.w = -r0.x + r6.y;
  r0.w = -0.5 + r0.w;
  r1.x = 0.5 + r0.x;
  r1.y = 0.5 + -r0.y;
  r1.xy = r1.xy + -r6.xz;
  r1.z = r0.y + r6.w;
  r1.z = -0.5 + r1.z;
  r1.y = min(r1.y, r1.z);
  r1.x = min(r1.x, r1.y);
  r0.w = min(r1.x, r0.w);
  r0.w = cmp(r0.w < 0);
  if (r0.w != 0) discard;
  r1.xyz = float3(0.5,0.5,0.5) + -abs(r0.xyz);
  r2.xyz = cmp(r1.xyz < float3(0,0,0));
  r0.w = (int)r2.y | (int)r2.x;
  r0.w = (int)r2.z | (int)r0.w;
  if (r0.w != 0) discard;
  r2.xy = cmp(float2(0.5,0.5) < r4.zw);
  r1.xyz = r1.xyz + r1.xyz;
  r0.w = min(r1.x, r1.y);
  r0.w = min(r0.w, r1.z);
  r0.w = max(0, r0.w);
  r0.w = r0.w * -2 + 1;
  r0.w = 1 + -r0.w;
  r0.w = min(1, r0.w);
  r0.w = r4.x * r0.w;
  r0.w = r2.x ? r0.w : r4.x;
  r0.z = dot(r0.xyz, r0.xyz);
  r0.z = sqrt(r0.z);
  r0.z = 0.5 + -r0.z;
  r0.z = r0.z + r0.z;
  r0.z = max(0, r0.z);
  r0.z = 1 + -r0.z;
  r0.z = r0.z * r0.z;
  r0.z = -r0.z * r0.z + 1;
  r0.z = r0.w * r0.z;
  r0.z = r2.y ? r0.z : r0.w;
  r1.xy = cmp(float2(0,0) != r7.zw);
  r0.w = r0.z * r10.z;
  r0.z = r1.x ? r0.w : r0.z;
  r1.xzw = g_CameraVec.xyz + -r12.xyz;
  r2.xy = cmp(float2(0,0) != r8.zw);
  r7.z = r8.x;
  r0.w = dot(r7.xyz, r1.xzw);
  r2.z = dot(r1.xzw, r1.xzw);
  r2.w = rsqrt(r2.z);
  r1.xzw = r2.www * r1.xzw;
  r1.x = dot(r7.xyz, r1.xzw);
  r0.w = saturate(r2.x ? abs(r0.w) : r1.x);
  r0.w = log2(r0.w);
  r0.w = r8.y * r0.w;
  r0.w = exp2(r0.w);
  r1.x = 1 + -r0.w;
  r0.w = r2.y ? r1.x : r0.w;
  r0.w = r0.z * r0.w;
  r0.z = r1.y ? r0.w : r0.z;
  r0.w = cmp(0.5 < r9.x);
  r1.x = sqrt(r2.z);
  r1.x = r1.x + -r9.z;
  r1.y = 1 / r9.z;
  r1.x = saturate(r1.x * r1.y);
  r1.y = r1.x * -2 + 3;
  r1.x = r1.x * r1.x;
  r1.x = r1.y * r1.x;
  r1.x = max(0.00100000005, r1.x);
  r1.x = log2(r1.x);
  r1.x = r5.w * r1.x;
  r1.x = exp2(r1.x);
  r1.y = cmp(0 != r9.y);
  r1.z = 1 + -r1.x;
  r1.x = r1.y ? r1.z : r1.x;
  r1.x = max(r1.x, r9.w);
  r1.x = min(r1.x, r5.z);
  r1.x = r1.x * r0.z;
  r0.z = r0.w ? r1.x : r0.z;
  r1.xyz = ddx_fine(r12.yzx);
  r2.xyz = ddy_fine(r12.zxy);
  r4.xzw = r2.xyz * r1.xyz;
  r1.xyz = r2.zxy * r1.yzx + -r4.xzw;
  r0.w = dot(r1.xyz, r1.xyz);
  r0.w = rsqrt(r0.w);
  r1.xyz = r1.xyz * r0.www;
  r0.w = cmp(0 != r5.y);
  r1.x = saturate(dot(r3.xyz, r1.xyz));
  r1.x = max(0.00999999978, r1.x);
  r1.x = log2(r1.x);
  r1.x = r4.y * r1.x;
  r1.x = exp2(r1.x);
  r1.x = r1.x * r0.z;
  r0.z = r0.w ? r1.x : r0.z;
  r0.w = cmp(0.5 < r3.w);
  if (r0.w != 0) {
    r0.w = r0.z * r5.x;
    r1.xyz = float3(0,0,0);
  } else {
    r2.x = instanceData[v3.x].colormatrix._m00;
    r2.y = instanceData[v3.x].colormatrix._m10;
    r2.z = instanceData[v3.x].colormatrix._m20;
    r2.w = instanceData[v3.x].colormatrix._m30;
    r3.x = instanceData[v3.x].colormatrix._m01;
    r3.y = instanceData[v3.x].colormatrix._m11;
    r3.z = instanceData[v3.x].colormatrix._m21;
    r3.w = instanceData[v3.x].colormatrix._m31;
    r4.x = instanceData[v3.x].colormatrix._m02;
    r4.y = instanceData[v3.x].colormatrix._m12;
    r4.z = instanceData[v3.x].colormatrix._m22;
    r4.w = instanceData[v3.x].colormatrix._m32;
    r6.x = instanceData[v3.x].uvScroll.x;
    r6.y = instanceData[v3.x].uvScroll.y;
    r6.z = instanceData[v3.x].uvTiling.x;
    r6.w = instanceData[v3.x].uvTiling.y;
    r0.xy = r6.xy + r0.xy;
    r0.xy = float2(0.5,0.5) + r0.xy;
    r0.xy = r0.xy * r6.zw;
    r6.xyzw = g_AlbedTexture.Sample(g_AlbedTextureSampler_s, r0.xy).xyzw;
    r5.xyz = r6.xyz * r5.xxx;
    r5.w = 1;
    r1.x = dot(r5.xyzw, r2.xyzw);
    r1.y = dot(r5.xyzw, r3.xyzw);
    r1.z = dot(r5.xyzw, r4.xyzw);
    r0.w = r6.w * r0.z;
  }
  r1.w = r0.z * r0.w;
  r0.x = r0.z * r0.w + -9.99999975e-05;
  r0.x = cmp(r0.x < 0);
  if (r0.x != 0) discard;
  o0.xyzw = r1.xyzw;
  o0 = max(0, o0);
  return;
}