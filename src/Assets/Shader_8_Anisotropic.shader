Shader "Custom/Shader_8_Anisotropic"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (0.86, 0.39, 0.39, 1)
         _SpecularColor("Specular Color", Color) = (1, 1, 1, 1)
        _AmbientRate("Ambient Rate", Range(0, 1)) = 0.2
        _RoughnessX("Roughness X", Range(0, 1)) = 0.8
        _RoughnessY("Roughness Y", Range(0, 1)) = 0.2
        _Metallic("Metallic", Range(0, 1)) = 0.5
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
                float4 tangent : TANGENT;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float3 position : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _SpecularColor;
                half _AmbientRate;
                half _RoughnessX;
                half _RoughnessY;
                half _Metallic;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);
                OUT.tangent = float4(TransformObjectToWorldNormal(float3(IN.tangent.xyz)).xyz, IN.tangent.w) ;
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
//                return FresnelReflectanceAverageDielectric(co, f0, f90);// SîgPîgïΩãœÇÃñ≥ãﬂéó
//                return f0 + (f90-f0) * pow(1 - co, 5);// Schlickãﬂéó
                return f0 + (f90-f0) * exp(-6 * co);// FarCry3ãﬂéó
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

            // "Moving Frostbite to Physically Based Rendering 3.0"
            float V_SmithGGXCorrelated(float NdotL, float NdotV, float alphaG2) 
            { 
	            // Original formulation of G_SmithGGX Correlated 
	            // lambda_v = (-1 + sqrt(alphaG2 * (1-NdotL2) / NdotL2 + 1)) * 0.5f; 
	            // lambda_l = (-1 + sqrt(alphaG2 * (1-NdotV2) / NdotV2 + 1)) * 0.5f; 
	            // G_SmithGGXCorrelated = 1 / (1 + lambda_v + lambda_l); 
	            // V_SmithGGXCorrelated = G_SmithGGXCorrelated / (4.0f * NdotL * NdotV); 

	            // Caution: the "NdotL *" and "NdotV *" are explicitely inversed, this is not a mistake. 
	            float Lambda_GGXV = NdotL * sqrt((-NdotV * alphaG2 + NdotV) * NdotV + alphaG2); 
	            float Lambda_GGXL = NdotV * sqrt((-NdotL * alphaG2 + NdotL) * NdotL + alphaG2); 
	            return 0.5f / (Lambda_GGXV + Lambda_GGXL);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light = GetMainLight();
                half3 normal = normalize(IN.normal);// ääÇÁÇ©Ç…Ç∑ÇÈÇΩÇﬂÇ…ê≥ãKâªÇµíºÇ∑
                half3 binormal = normalize(cross(normal, IN.tangent.xyz) * IN.tangent.w);
                half3 tangent = cross(binormal, normal) * IN.tangent.w;

                half3 view_direction = normalize(TransformViewToWorld(float3(0,0,0)) - IN.position);
//                half3 view_direction = TransformViewToWorldNormal(float3(0,0,1));// í∏ì_ÇÃà íuÇå©Ç»Ç¢ãﬂéó
                half3 half_vector = normalize(light.direction + view_direction);
                half VdotN = max(0.000001, dot(view_direction, normal));
                half LdotN = max(0.000001, dot(light.direction, normal));
                half HdotN = max(0.000001, dot(half_vector, normal));

                half alphaX = _RoughnessX * _RoughnessX;
                half alphaY = _RoughnessY * _RoughnessY;
                half XdotH = dot(tangent, half_vector);
                half YdotH = dot(binormal, half_vector);

                half3 ambient = _BaseColor.rgb;
                half3 lambert = _BaseColor.rgb * LdotN;
                half3 specular = _SpecularColor * exp(-(XdotH*XdotH/(alphaX*alphaX) + YdotH*YdotH/(alphaY*alphaY))/(HdotN * HdotN))
                     / sqrt(LdotN * VdotN) / (4 * PI * alphaX * alphaY);

                half3 color = light.color * 
                    lerp(lerp(lambert, ambient, _AmbientRate), specular, _Metallic);
                return half4(color, 1);

            }
            ENDHLSL
        }
    }
}
