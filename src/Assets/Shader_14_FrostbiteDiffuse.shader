Shader "Custom/Shader_14_FrostbiteDiffuse"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (0.86, 0.39, 0.39, 1)
        _Fresnel0("Fresnel0", Range(0, 1)) = 0.8
        _Roughness("Roughness", Range(0, 1)) = 0.4
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
                half4 _BaseColor;
                half _Fresnel0;
                half _Roughness;
                half _Metallic;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);
                OUT.position = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            half FresnelReflectanceAverageDielectric(float co, float f0, float f90)
            {
                co = min(0.9999, max(0.000001, co));

                float root_f0 = sqrt(f0);
                float root_f90 = sqrt(f90);
                float n = (root_f90 + root_f0) / (root_f90 - root_f0);
                float n2 = n * n;

                float si2 = 1 - co * co;
                float nb = sqrt(n2 - si2);
                float bn = nb / n2;

                float r_s = (co - nb) / (co + nb);
                float r_p = (co - bn) / (co + bn);
                return 0.5 * f90 * (r_s * r_s + r_p * r_p);
            }

            half Fresnel(half f0, half f90, float co)
            {
//                return FresnelReflectanceAverageDielectric(co, f0, f90);// S�gP�g���ς̖��ߎ�
//                return f0 + (f90-f0) * pow(1 - co, 5);// Schlick�ߎ�
                return f0 + (f90-f0) * exp(-6 * co);// FarCry3�ߎ�
            }

            // "Moving Frostbite to Physically Based Rendering 3.0"
            half3 Fr_DisneyDiffuse(half3 albedo, half LdotN, half VdotN, half LdotH, half linearRoughness)
            {
                half energyBias = lerp(0.0, 0.5, linearRoughness);
                half energyFactor = lerp(1.0, 1.0/1.51, linearRoughness);
                half Fd90 = energyBias + 2.0 * LdotH * LdotH * linearRoughness;
                half FL = Fresnel(1, Fd90, LdotN);
                half FV = Fresnel(1, Fd90, VdotN);
                return (albedo * FL * FV * energyFactor);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 normal = normalize(IN.normal);
                half3 view_direction = normalize(TransformViewToWorld(float3(0,0,0)) - IN.position);
//                half3 view_direction = TransformViewToWorldNormal(float3(0,0,1));// ���_�̈ʒu�����Ȃ��ߎ�
                half3 half_vector = normalize(light.direction + view_direction);
                half VdotN = max(0.00001, dot(view_direction, normal));
                half LdotN = max(0.0, dot(light.direction, normal));
                half HdotN = max(0.0, dot(half_vector, normal));
                half LdotH = max(0.0, dot(half_vector, light.direction));

                half3 color = light.color * LdotN
                    * Fr_DisneyDiffuse(_BaseColor, LdotN, VdotN, LdotH, _Roughness * _Roughness) / PI;
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
}
