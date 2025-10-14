Shader "Custom/Shader_16_MyShader"
{
     Properties
    {
        _Fresnel0("Fresnel0",Color )=(1.00,0.71,0.29,1)
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
                float3 normal:NORMAL;
                float3 position:TEXCOORD0;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half3 _Fresnel0;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.normal = TransformObjectToWorldNormal(IN.normal);
                OUT.position=TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                Light light=GetMainLight();
                half3 normal=normalize(IN.normal);
                half3 view_direction=normalize(TransformViewToWorld(float3(0,0,0))-IN.position);
                half3 half_vector=normalize(view_direction+light.direction);
                half VdotH=max(0,dot(view_direction,half_vector));

                half3 F=_Fresnel0+(1.0-_Fresnel0)*pow(1.0-VdotH,5.0);

                return half4 (F,1);
            }
            ENDHLSL
        }
    }
}
