#ifndef TONEMAP_HLSLI
#define TONEMAP_HLSLI

#include "./Common.hlsl"
#include "./macleod_boynton.hlsli"
#include "./neutwo.hlsl"
#include "../../Includes/Tonemap.hlsl"
#include "../../Includes/Reinhard.hlsl"

struct ColorGradingConfig
{
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
};

ColorGradingConfig DefaultColorGradingConfig()
{
   ColorGradingConfig config;
   //     1.f,                             // float exposure;
   //     1.f,                             // float highlights;
   //     1.f,                   // float highlight_contrast;
   //     1.f,                              // float shadows;
   //     1.f,                      // float shadow_contrast;
   //     1.f,                             // float contrast;
   //     0.10f * pow(0.f, 10.f),             // float flare;
   //     1.f,                                // float gamma;
   //     1.f,                           // float saturation;
   //     0.2f,                             // float dechroma;
   //     -1.f * (1.f - 1.f),  // float highlight_saturation;
   //     0.f,                                                  // float hue_emulation;
   //     0.f                                                   // float purity_emulation;
   config.Exposure = 1.f;
   config.Highlights = 1.f;
   config.HighlightContrast = 1.f;
   config.Shadows = 1.f;
   config.ShadowContrast = 1.f;
   config.Contrast = 1.f;
   config.Flare = 0.f;
   config.Gamma = 1.f;
   config.Saturation = 1.f;
   config.Dechroma = 0.f;
   config.HighlightSaturation = 0.5f;
   config.HueEmulation = 0.f;
   config.PurityEmulation = 0.f;
   return config;
}

float1 CorrectGamma1(float uncorrected, float gamma = 2.2f)
{
   return gamma_to_linear1(linear_to_gamma1(uncorrected, GCT_MIRROR), GCT_MIRROR, gamma);
}

float3 CorrectGamma(float3 color, float gamma = 2.2f)
{
   return gamma_to_linear(linear_to_gamma(color, GCT_MIRROR), GCT_MIRROR, gamma);
}

float3 CorrectLuminance(float3 color, float incorrect_y, float correct_y, float strength = 1.f)
{
   return color * lerp(1.f, safeDivision(correct_y, incorrect_y, 1), strength);
}

float3 Select(float condition, float3 trueValue, float3 falseValue)
{
   [flatten]
   if (condition)
   {
      return trueValue;
   }
   else
   {
      return falseValue;
   }
}

float3 ApplyVanillaToneMap(float3 untonemapped)
{
   return Tonemap_Uncharted2_Eval(untonemapped,
                                  0.15,  // A
                                  0.5,   // B
                                  0.1,   // C
                                  1.0,   // D
                                  0.004, // E
                                  0.06)  // F
          * 1.37906432;
}

// Exact first derivative of ApplyVanillaToneMap per channel.
// f(x) = k * ((0.15x^2 + 0.05x + 0.004) / (0.15x^2 + 0.5x + 0.06) - 0.0666666701)
// f'(x) = k * (0.0675x^2 + 0.0168x + 0.001) / (0.15x^2 + 0.5x + 0.06)^2
float3 ApplyVanillaToneMapDerivative(float3 x)
{
   float3 numerator = 0.0675 * x * x + 0.0168 * x + 0.001;
   float3 denominator = 0.15 * x * x + 0.5 * x + 0.06;
   return 1.37906432 * numerator / (denominator * denominator);
}

static const float kInflectionPoint = 0.186563;
// static const float kInflectionPoint = 0.28160194f;  // To accommodate B * 0.3f

#define APPLYGBFREXTENDED_GENERATOR(T)                                                                                 \
   T ApplyGBFRExtended(T x, T base)                                                                                    \
   {                                                                                                                   \
      float pivot_x = kInflectionPoint;                                                                                \
                                                                                                                       \
      float3 pivot_x3 = float3(pivot_x, pivot_x, pivot_x);                                                             \
      float pivot_y = ApplyVanillaToneMap(pivot_x3).x;                                                                 \
                                                                                                                       \
      float slope = ApplyVanillaToneMapDerivative(pivot_x3).x;                                                         \
                                                                                                                       \
      /* Line passing through (pivot_x, pivot_y) with matching slope */                                                \
      T offset = pivot_y - slope * pivot_x;                                                                            \
      T extended = slope * x + offset;                                                                                 \
                                                                                                                       \
      return lerp(base, extended, step(pivot_x, x));                                                                   \
   }

APPLYGBFREXTENDED_GENERATOR(float)
APPLYGBFREXTENDED_GENERATOR(float3)
#undef APPLYGBFREXTENDED_GENERATOR

// Inverse of Tonemap_Uncharted2_Eval with optional precomputed white scaling.
// If whiteScalingMode == 0, whiteValue is interpreted as raw white point W.
// If whiteScalingMode == 1, whiteValue is interpreted as precomputed 1 / Tonemap_Uncharted2_Eval(W).
float3 Tonemap_Uncharted2_Inverse(float3 compressedCol, float whiteValue, float a, float b, float c, float d, float e,
                                  float f, uint whiteScalingMode = 0)
{
   float3 colorSigns = float3(compressedCol.x >= 0.0 ? 1.0 : -1.0, compressedCol.y >= 0.0 ? 1.0 : -1.0,
                              compressedCol.z >= 0.0 ? 1.0 : -1.0);

   compressedCol = abs(compressedCol);

   if (whiteScalingMode == 0)
   {
      whiteValue = 1.0 / Tonemap_Uncharted2_Eval(whiteValue, a, b, c, d, e, f).x;
   }

   float3 normalized = compressedCol / whiteValue;

   float3 uncompressed;
   uncompressed.x = Tonemap_Uncharted2_Inverse_Eval(normalized.x, a, b, c, d, e, f);
   uncompressed.y = Tonemap_Uncharted2_Inverse_Eval(normalized.y, a, b, c, d, e, f);
   uncompressed.z = Tonemap_Uncharted2_Inverse_Eval(normalized.z, a, b, c, d, e, f);

   return uncompressed * colorSigns;
}

// Inverse of the Granblue vanilla UC2-form curve:
// y = 1.37906432 * Tonemap_Uncharted2_Eval(x, 0.15, 0.5, 0.1, 1.0, 0.004, 0.06)
float3 Tonemap_Uncharted2_Vanilla_Inverse(float3 compressedCol)
{
   return Tonemap_Uncharted2_Inverse(compressedCol, 1.37906432, 0.15, 0.5, 0.1, 1.0, 0.004, 0.06, 1);
}

float Highlights(float x, float highlights, float mid_gray)
{
   if (highlights == 1.f)
      return x;

   if (highlights > 1.f)
   {
      return max(x, lerp(x, mid_gray * pow(x / mid_gray, highlights), min(x, 1.f)));
   }
   else
   { // highlights < 1.f
      float b = mid_gray * pow(x / mid_gray, 2.f - highlights);
      float t = min(x, 1.f); // clamp extreme influence
      return min(x, safeDivision(x * x, lerp(x, b, t), x));
   }
}

float Shadows(float x, float shadows, float mid_gray)
{
   if (shadows == 1.f)
      return x;

   const float ratio = max(safeDivision(x, mid_gray, 0.f), 0.f);
   const float base_term = x * mid_gray;
   const float base_scale = safeDivision(base_term, ratio, 0.f);

   if (shadows > 1.f)
   {
      float raised = x * (1.f + safeDivision(base_term, pow(ratio, shadows), 0.f));
      float reference = x * (1.f + base_scale);
      return max(x, x + (raised - reference));
   }
   else
   { // shadows < 1.f
      float lowered = x * (1.f - safeDivision(base_term, pow(ratio, 2.f - shadows), 0.f));
      float reference = x * (1.f - base_scale);
      return clamp(x + (lowered - reference), 0.f, x);
   }
}

float ContrastAndFlare(float x, float contrast, float contrast_highlights, float contrast_shadows, float flare,
                       float mid_gray = 0.18f)
{
   if (contrast == 1.f && flare == 0.f && contrast_highlights == 1.f && contrast_shadows == 1.f)
      return x;

   const float x_normalized = x / mid_gray;

   const float split_contrast = Select(x < mid_gray, contrast_shadows, contrast_highlights).x;
   float flare_ratio = safeDivision(x_normalized + flare, x_normalized, 1.f);
   float exponent = contrast * split_contrast * flare_ratio;
   return pow(x_normalized, exponent) * mid_gray;
}

float3 ApplyLuminosityGrading(float3 untonemapped, float lum, ColorGradingConfig config, float mid_gray = 0.18f)
{
   if (config.Exposure == 1.f && config.Shadows == 1.f && config.Highlights == 1.f && config.Contrast == 1.f &&
       config.HighlightContrast == 1.f && config.ShadowContrast == 1.f && config.Flare == 0.f && config.Gamma == 1.f)
   {
      return untonemapped;
   }
   float3 color = untonemapped;

   color *= config.Exposure;
   // gamma
   float lum_gamma_adjusted = Select(lum < 1.f, pow(lum, config.Gamma), lum).x;

   // contrast & flare
   const float lum_contrasted = ContrastAndFlare(lum_gamma_adjusted, config.Contrast, config.HighlightContrast,
                                                 config.ShadowContrast, config.Flare, mid_gray);

   // highlights
   float lum_highlighted = Highlights(lum_contrasted, config.Highlights, mid_gray);

   // shadows
   float lum_shadowed = Shadows(lum_highlighted, config.Shadows, mid_gray);

   const float lum_final = lum_shadowed;

   color = CorrectLuminance(color, lum, lum_final);

   return color;
}

float3 ApplyHueAndPurityGrading(float3 ungraded_bt2020, float3 reference_bt2020, float lum, ColorGradingConfig config,
                                float curve_gamma = 1.f, float2 mb_white_override = float2(-1.f, -1.f),
                                float t_min = 1e-7f)
{
   float3 color_bt2020 = ungraded_bt2020;
   if (config.Saturation == 1.f && config.Dechroma == 0.f && config.HueEmulation == 0.f &&
       config.PurityEmulation == 0.f && config.HighlightSaturation == 0.f)
   {
      return color_bt2020;
   }

   const float kNearWhiteEpsilon = renodx_custom::color::macleod_boynton::MB_NEAR_WHITE_EPSILON;
   const float2 white = (mb_white_override.x >= 0.f && mb_white_override.y >= 0.f)
                            ? mb_white_override
                            : renodx_custom::color::macleod_boynton::MB_White_D65();

   float color_purity01 =
       renodx_custom::color::macleod_boynton::ApplyBT2020(color_bt2020, 1.f, 1.f, mb_white_override, t_min).purityCur01;

   // MB hue + purity emulation (analog of OkLab hue/chrominance section).
   if (config.HueEmulation != 0.f || config.PurityEmulation != 0.f)
   {
      float reference_purity01 =
          renodx_custom::color::macleod_boynton::ApplyBT2020(reference_bt2020, 1.f, 1.f, mb_white_override, t_min)
              .purityCur01;

      float purity_current = color_purity01;
      float purity_ratio = 1.f;
      float3 hue_seed_bt2020 = color_bt2020;

      if (config.HueEmulation != 0.f)
      {
         float3 target_lms =
             mul(renodx_custom::color::macleod_boynton::XYZ_TO_LMS_2006, mul(BT2020_2_XYZ, color_bt2020));
         float3 reference_lms =
             mul(renodx_custom::color::macleod_boynton::XYZ_TO_LMS_2006, mul(BT2020_2_XYZ, reference_bt2020));

         float target_t = target_lms.x + target_lms.y;
         if (target_t > t_min)
         {
            float2 target_direction = renodx_custom::color::macleod_boynton::MB_From_LMS(target_lms) - white;
            float2 reference_direction = renodx_custom::color::macleod_boynton::MB_From_LMS(reference_lms) - white;

            float target_len_sq = dot(target_direction, target_direction);
            float reference_len_sq = dot(reference_direction, reference_direction);

            if (target_len_sq > kNearWhiteEpsilon || reference_len_sq > kNearWhiteEpsilon)
            {
               float2 target_unit =
                   (target_len_sq > kNearWhiteEpsilon) ? target_direction * rsqrt(target_len_sq) : float2(0.f, 0.f);
               float2 reference_unit =
                   (reference_len_sq > kNearWhiteEpsilon) ? reference_direction * rsqrt(reference_len_sq) : target_unit;

               if (target_len_sq <= kNearWhiteEpsilon)
               {
                  target_unit = reference_unit;
               }

               float2 blended_unit = lerp(target_unit, reference_unit, config.HueEmulation);
               float blended_len_sq = dot(blended_unit, blended_unit);
               if (blended_len_sq <= kNearWhiteEpsilon)
               {
                  blended_unit = (config.HueEmulation >= 0.5f) ? reference_unit : target_unit;
                  blended_len_sq = dot(blended_unit, blended_unit);
               }
               blended_unit *= rsqrt(max(blended_len_sq, 1e-20f));

               float seed_len = sqrt(max(target_len_sq, 0.f));
               if (seed_len <= 1e-6f)
               {
                  seed_len = sqrt(max(reference_len_sq, 0.f));
               }
               seed_len = max(seed_len, 1e-6f);

               hue_seed_bt2020 = mul(XYZ_2_BT2020, mul(renodx_custom::color::macleod_boynton::LMS_TO_XYZ_2006,
                                                       renodx_custom::color::macleod_boynton::LMS_From_MB_T(
                                                           white + blended_unit * seed_len, target_t)));

               float purity_post = renodx_custom::color::macleod_boynton::ApplyBT2020(hue_seed_bt2020, 1.f, 1.f,
                                                                                      mb_white_override, t_min)
                                       .purityCur01;
               purity_ratio = safeDivision(purity_current, purity_post, 1.f);
               purity_current = purity_post;
            }
         }
      }

      if (config.PurityEmulation != 0.f)
      {
         float target_purity_ratio = safeDivision(reference_purity01, purity_current, 1.f);
         purity_ratio = lerp(purity_ratio, target_purity_ratio, config.PurityEmulation);
      }

      float applied_purity01 = saturate(purity_current * max(purity_ratio, 0.f));
      color_bt2020 = renodx_custom::color::macleod_boynton::ApplyBT2020(hue_seed_bt2020, applied_purity01, curve_gamma,
                                                                        mb_white_override, t_min)
                         .rgbOut;
      color_purity01 = applied_purity01;
   }

   float purity_scale = 1.f;

   // dechroma
   if (config.Dechroma != 0.f)
   {
      purity_scale *= lerp(1.f, 0.f, saturate(pow(lum / (10000.f / 100.f), (1.f - config.Dechroma))));
   }

   // highlight saturation
   if (config.HighlightSaturation != 0.f)
   {
      float percent_max = saturate(lum * 100.f / 10000.f);
      // positive = 1 to 0, negative = 1 to 2
      float blowout_strength = 100.f;
      float blowout_change = pow(1.f - percent_max, blowout_strength * abs(config.HighlightSaturation));
      if (config.HighlightSaturation < 0)
      {
         blowout_change = (2.f - blowout_change);
      }

      purity_scale *= blowout_change;
   }

   // saturation
   purity_scale *= config.Saturation;

   if (purity_scale != 1.f)
   {
      float scaled_purity01 = saturate(color_purity01 * max(purity_scale, 0.f));
      color_bt2020 = renodx_custom::color::macleod_boynton::ApplyBT2020(color_bt2020, scaled_purity01, curve_gamma,
                                                                        mb_white_override, t_min)
                         .rgbOut;
   }

   return color_bt2020;
}

float3 ApplyCustomGrading(float3 ungraded_bt2020)
{
   float3 graded = ungraded_bt2020;

   const ColorGradingConfig cg_config = {
      EXPOSURE,                            // float exposure;
      HIGHLIGHTS,                          // float highlights;
      HIGHLIGHT_CONTRAST,                  // float highlight_contrast;
      SHADOWS,                             // float shadows;
      SHADOW_CONTRAST,                     // float shadow_contrast;
      CONTRAST,                            // float contrast;
      0.10f * pow(FLARE, 10.f),            // float flare;
      GAMMA,                               // float gamma;
      SATURATION,                          // float saturation;
      DECHROMA,                            // float dechroma;
      -1.f * (HIGHLIGHT_SATURATION - 1.f), // float highlight_saturation;
      HUE_EMULATION,                       // float hue_emulation;
      PURITY_EMULATION                     // float purity_emulation;
   };

   float luminosity = LuminosityFromBT2020LuminanceNormalized(ungraded_bt2020);
   float3 graded_bt2020 = ApplyLuminosityGrading(ungraded_bt2020, luminosity, cg_config, 0.1f);
   graded_bt2020 = ApplyHueAndPurityGrading(graded_bt2020, ungraded_bt2020, luminosity, cg_config);

   graded_bt2020 = max(0, graded_bt2020);
   return graded_bt2020;
}

float3 ApplyGammaCorrection(float3 color_input)
{
   float3 color_corrected;
   if (LumaSettings.GameSettings.Gamma == 1.f)
   {
      color_corrected = CorrectGamma(color_input);
   }
   else if (LumaSettings.GameSettings.Gamma == 2.f)
   {
      float y_in = LuminosityFromBT709LuminanceNormalized(color_input);
      float y_out = CorrectGamma1(max(0, y_in));
      float3 color_corrected_lum = CorrectLuminance(color_input, y_in, y_out);

      float3 color_corrected_ch = CorrectGamma(color_input);

      color_corrected = CorrectPurityMBBT709WithBT2020(color_corrected_lum, color_corrected_ch, 1.f);
   }
   else
   {
      color_corrected = color_input;
   }

   return color_corrected;
}

float3 Uncharted2Extended(float3 color)
{
   float A = 0.15, B = 0.5, C = 0.1, D = 1.0, E = 0.004, F = 0.06;
   float W = 1.37906432;

   float coeffs[6] = { A, B, C, D, E, F };
   float white_precompute = W;

   // Uncharted2::Config::Uncharted2ExtendedConfig uc2_config =
   // Uncharted2::Config::CreateUncharted2ExtendedConfig(coeffs, white_precompute);

   // float3 outputColor = Uncharted2::ApplyExtended(color, uc2_config);
   float3 originalColor;
   float3 outputColor =
       Uncharted2::Tonemap_Uncharted2_Extended(color, false, originalColor, 1, 0.f, 1, white_precompute, coeffs[0],
                                               coeffs[1], coeffs[2], coeffs[3], coeffs[4], coeffs[5]);

   return outputColor;
}

float3 ApplyCustomBloom(float3 render, float3 bloom_texture, float scaling = 0.5f)
{
   if (BLOOM_TYPE == 1 && BLOOM_STRENGTH > 0.f)
   {
      float mid_gray_bloomed = (0.18 + GetLuminance(bloom_texture)) / 0.18;

      float scene_luminance = GetLuminance(render) * mid_gray_bloomed;
      float bloom_blend = saturate(smoothstep(0.f, 0.18f, scene_luminance));
      float3 bloom_scaled = lerp(0.f, bloom_texture, bloom_blend);
      return bloom_texture = lerp(bloom_texture, bloom_scaled, 1.f * scaling);
   }
   else
   {
      return bloom_texture;
   }
}

float3 ApplySaturationBlowoutHueCorrectionHighlightSaturation(float3 tonemapped, float3 hue_reference_color, float y,
                                                              float saturation, float dechroma,
                                                              float hue_correction_strength, float blowout)
{
   float3 color = tonemapped;
   if (saturation != 1.f || dechroma != 0.f || hue_correction_strength != 0.f || blowout != 0.f)
   {
      float3 perceptual_new = Oklab::linear_srgb_to_oklab(color);

      if (hue_correction_strength != 0.f)
      {
         float3 perceptual_old = Oklab::linear_srgb_to_oklab(hue_reference_color);

         // Save chrominance to apply black
         float chrominance_pre_adjust = distance(perceptual_new.yz, 0);

         perceptual_new.yz = lerp(perceptual_new.yz, perceptual_old.yz, hue_correction_strength);

         float chrominance_post_adjust = distance(perceptual_new.yz, 0);

         // Apply back previous chrominance
         perceptual_new.yz *= safeDivision(chrominance_pre_adjust, chrominance_post_adjust, 1);
      }

      if (dechroma != 0.f)
      {
         perceptual_new.yz *= lerp(1.f, 0.f, saturate(pow(y / (10000.f / 100.f), (1.f - dechroma))));
      }

      if (blowout != 0.f)
      {
         float percent_max = saturate(y * 100.f / 10000.f);
         // positive = 1 to 0, negative = 1 to 2
         float blowout_strength = 100.f;
         float blowout_change = pow(1.f - percent_max, blowout_strength * abs(blowout));
         if (blowout < 0)
         {
            blowout_change = (2.f - blowout_change);
         }

         perceptual_new.yz *= blowout_change;
      }

      perceptual_new.yz *= saturation;

      color = Oklab::oklab_to_linear_srgb(perceptual_new);

      // color = renodx::color::bt709::clamp::AP1(color);
   }
   return color;
}

float3 ApplyUserGradingAndToneMap(float3 color_bt709, float3 bloom, float2 grain_uv)
{
   const float paperWhite = UI_NITS;
   const float peakWhite = PEAK_NITS;
   const float peakWhiteRatio = peakWhite / paperWhite;
   float3 gammaCorrectedPeakRatio = peakWhiteRatio;

   ColorGradingLUTTransferFunctionInOutCorrected(gammaCorrectedPeakRatio, VANILLA_ENCODING_TYPE, GAMMA_CORRECTION_TYPE,
                                                 true);
   ColorGradingLUTTransferFunctionInOutCorrected(gammaCorrectedPeakRatio, GAMMA_CORRECTION_TYPE, VANILLA_ENCODING_TYPE,
                                                 true);
   const float peakRatioCorrected = gammaCorrectedPeakRatio.x;

   // bloom = ApplyCustomBloom(color_bt709, bloom, 0.5f);
   if (BLOOM_TYPE == 0 && LumaSettings.DisplayMode != 0)
      bloom = FakeHDR(bloom, 0.05, 0.33f);
   // blow out and hue shift

   float3 purity_and_hue_source = Reinhard::ReinhardPiecewise(color_bt709, 8.f, 0.18f);
   // color_bt709 = ApplyGBFRExtended(untonemapped_bt709, vanilla);
   color_bt709 = Uncharted2Extended(color_bt709);
   color_bt709 = CorrectHueAndPurityMBBT709WithBT2020(color_bt709, purity_and_hue_source, 1.f, 1.f);
   color_bt709 += bloom * BLOOM_STRENGTH;

   float3 color_bt2020 = BT709_To_BT2020(color_bt709);

   color_bt2020 = ApplyCustomGrading(color_bt2020);
   color_bt2020 = renodx::tonemap::neutwo::MaxChannel(color_bt2020, peakRatioCorrected);

   color_bt709 = BT2020_To_BT709(color_bt2020);

   //   color_bt709 = renodx::effects::ApplyFilmGrain(
   //       color_bt709,
   //       grain_uv,
   //       CUSTOM_RANDOM,
   //       CUSTOM_GRAIN_STRENGTH * 0.06f);

   color_bt709 = linear_to_sRGB_gamma(color_bt709, GCT_MIRROR);

   return color_bt709;
}

float3 Tonemap_Bloom(float3 untonemapped)
{
   if (BLOOM_TYPE == 1 && BLOOM_STRENGTH > 0.f)
   {
      float3 tonemapped = untonemapped;
      // tonemapped = renodx::tonemap::neutwo::MaxChannel(tonemapped, UI_NITS / sRGB_WhiteLevelNits, 100.f);
      tonemapped = renodx::tonemap::neutwo::PerChannel(tonemapped, GAME_NITS / sRGB_WhiteLevelNits, 100.f);
      return tonemapped;
   }
   else
   {
      return ApplyVanillaToneMap(untonemapped);
   }
}
#endif // TONEMAP_HLSLI
