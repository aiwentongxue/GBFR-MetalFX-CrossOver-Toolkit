struct VSOutput
{
   float4 position : SV_Position;
   float2 texcoord : TEXCOORD0;
};

VSOutput main(uint vertexIdx: SV_VertexID)
{
   VSOutput output;
   float2 texcoord = float2(vertexIdx & 1, vertexIdx >> 1);
   output.position = float4((texcoord.x - 0.5f) * 2.0f, -(texcoord.y - 0.5f) * 2.0f, 0.0f, 1.0f);
   output.texcoord = texcoord;
   return output;
}
