#include "Includes/Common.hlsl"

Texture2D<float4> g_Texture0 : register(t0); // TAA/DLSS output
Texture2D<float4> g_Texture1 : register(t1); // Original TAA/DLSS input (for alpha)
SamplerState g_Texture1Sampler_s : register(s1);

// DLSS outputs gamma srgb in SDR and linear BT2020 in HDR
// TAA outputs gamma srgb always

void main(float4 v0: SV_Position0, out float4 o0: SV_Target0)
{
   const int3 uv = int3(v0.xy, 0);
   float2 uv_norm = v0.xy / LumaSettings.SwapchainSize;
   float4 color = g_Texture0.Load(uv);
   float alpha = g_Texture1.SampleLevel(g_Texture1Sampler_s, uv_norm, 0).a;

#if TONEMAP_AFTER_TAA
   // TAA=true path: linearize TAA output for late replay motion blur and tonemap

   // DLSS outputs in BT.2020 gamut when in HDR mode, so convert to linear BT709.
   if (LumaSettings.DisplayMode == 1 && LumaSettings.SRType != 0)
   {
      color.rgb = BT2020_To_BT709(color.rgb);
   }
   else
   {
      color.rgb = gamma_sRGB_to_linear(color.rgb, GCT_MIRROR);
   }

#else
   // Expects gamma output

   if (LumaSettings.DisplayMode == 1 && LumaSettings.SRType != 0)
   {
      color.rgb = BT2020_To_BT709(color.rgb);
      color.rgb = linear_to_sRGB_gamma(color.rgb, GCT_MIRROR);
   }

#endif

   color.a = alpha;
   o0 = color;
}
