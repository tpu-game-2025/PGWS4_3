Shader "Custom/Shader_9_Fresnel"
{
    Properties
    {
        _Fresnel0("Fresnel0", Range(0, 0.99999)) = 0.8
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normal : NORMAL;
                float3 position : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                half _Fresnel0;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);
                OUT.position = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            half FresnelReflectanceAverageDielectric(float co, float f0)
            {
                float root_f0 = sqrt(f0);
                float n = (1 + root_f0) / (1 - root_f0);
                float n2 = n * n;

                float si2 = 1 - co * co;
                float nb = sqrt(n2 - si2);
                float bn = nb / n2;

                float r_s = (co - nb) / (co + nb);
                float r_p = (co - bn) / (co + bn);
                return 0.5 * (r_s * r_s + r_p * r_p);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 normal = normalize(IN.normal);
                half3 view_direction = normalize(TransformViewToWorld(float3(0,0,0)) - IN.position);
//                half3 view_direction = TransformViewToWorldNormal(float3(0,0,1));// ’¸“_‚ÌˆÊ’u‚ðŒ©‚È‚¢‹ßŽ—
                half3 half_vector = normalize(light.direction + view_direction);
                half VdotH = max(0, dot(view_direction, half_vector));

//                half F = FresnelReflectanceAverageDielectric(VdotH, _Fresnel0);// S”gP”g•½‹Ï‚Ì–³‹ßŽ—
                half F = _Fresnel0 + (1-_Fresnel0) * pow(1 - VdotH, 5);// Schlick‹ßŽ—
//                half F = _Fresnel0 + (1-_Fresnel0) * exp(-6 * VdotH);// FarCry3‹ßŽ—

                half3 color = F;
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}
