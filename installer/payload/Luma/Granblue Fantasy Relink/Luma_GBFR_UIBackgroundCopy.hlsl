SamplerState g_Sampler : register(s0);
Texture2D<float4> g_Texture0 : register(t0);

float4 main(float4 pos: SV_Position, float2 uv: TEXCOORD0) : SV_Target0
{
   return g_Texture0.Sample(g_Sampler, uv);
}
