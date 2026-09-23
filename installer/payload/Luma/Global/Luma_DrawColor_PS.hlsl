#include "../Includes/Common.hlsl"

#ifndef COLOR
#define COLOR float4(0, 0, 0, 0)
#endif

float4 main() : SV_Target
{
  return COLOR;
}