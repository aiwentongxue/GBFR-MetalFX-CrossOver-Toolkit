#include "../Includes/Common.hlsl"

Texture2D<float4> sourceTexture : register(t0);
SamplerState pointSampler : register(s0);

// Based on "D3D11_REQ_TEXTURE1D_U_DIMENSION"
#define MAX_2D_MIP_LEVELS 15

float4 main(float4 pos : SV_Position) : SV_Target0
{
  uint2 size;
  uint levels; // TODO: hardcode this in by permutation to optimize the shader?
  sourceTexture.GetDimensions(0, size.x, size.y, levels);
  levels = min(levels, MAX_2D_MIP_LEVELS); // Here to aid the compiler into better unrolling/looping

  float2 uv = pos.xy / float2(size);

  float4 color = 0.0;
  bool4 validColor = false;
  uint level = 0;

  // Sample mips until we find one that isn't nan (on each individual channel)
#if 0 // Not sure if this is good, seems like not to me, it also just doesn't seem to work (it skips the loop? Makes no sense as returning a color in the loop ignores the call)
  [unroll(MAX_2D_MIP_LEVELS)]
#else
  [loop] // Note: this might send false warnings
#endif
  do
  {
    // Point sampler is good here, despite not being so obvious.
    // The results are still pixellated when the nans cover a large part of the screen, but that's usually not the case, this is meant to hide small nans around.
    // If we wanted to cover larger areas, we could reconstrct the mip chain backwards without nans with a smoother output.
    float4 tempColor = sourceTexture.SampleLevel(pointSampler, uv, level);

    // Tests
    //if (any(IsNaN_Strict(tempColor))) return 1;
    //if (any(isnan(tempColor))) return 1;

    // If a channel is still NaN, try to replace it
    if (!validColor.r && !IsNaN_Strict(tempColor.r))
    {
      color.r = tempColor.r;
      validColor.r = true;
    }
    if (!validColor.g && !IsNaN_Strict(tempColor.g))
    {
      color.g = tempColor.g;
      validColor.g = true;
    }
    if (!validColor.b && !IsNaN_Strict(tempColor.b))
    {
      color.b = tempColor.b;
      validColor.b = true;
    }
    if (!validColor.a && !IsNaN_Strict(tempColor.a))
    {
      color.a = tempColor.a;
      validColor.a = true;
    }

    // Stop if all channels are resolved
    if (all(validColor))
      break;

    level++;
  } while (level < levels);

#if 1 // Optionally saturate alpha, which is almost always wanted (e.g. emulating UNORM behaviour on FLOAT)
  color.a = saturate(color.a);
#endif

  // Test mips:
	//return sourceTexture.Load(int3(pos.xy, 0));
	//return sourceTexture.SampleLevel(pointSampler, uv, 0);
	//return sourceTexture.SampleLevel(pointSampler, uv, uint(DVS1 * levels + 0.5));

	return color;
}