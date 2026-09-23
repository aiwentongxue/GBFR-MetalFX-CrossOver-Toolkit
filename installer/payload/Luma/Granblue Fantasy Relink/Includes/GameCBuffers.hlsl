#ifndef LUMA_GAME_CB_STRUCTS
#define LUMA_GAME_CB_STRUCTS

#ifdef __cplusplus
#include "../../../Source/Core/includes/shader_types.h"
#endif

namespace CB
{
struct LumaGameSettings
{
   float GammaCorrection;
   float Exposure;
   float Highlights;
   float HighlightContrast;
   float Shadows;
   float ShadowContrast;
   float Contrast;
   float Flare;
   float Gamma;
   float Saturation;
   float Dechroma;
   float HighlightSaturation;
   float HueEmulation;
   float PurityEmulation;
   int BloomType;
   float BloomStrength;
   int IsTAARunning; // 1 when the engine's TAA frame-graph pass is active this frame
   float RenderScale;
};

struct LumaGameData
{
   float2 JitterOffset;     // Current frame jitter to apply (in NDC, _m20/_m21 space)
   float2 PrevJitterOffset; // Previous frame jitter (for g_PrevProj)
   int IsTAARunning;        // 1 when the engine's TAA frame-graph pass is active this frame
};
}

#endif // LUMA_GAME_CB_STRUCTS
