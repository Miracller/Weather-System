Shader "PBRCustom/Snow_layered_code"
{
    Properties 
    {
        _BaseMap ("Base Texture", 2D) = "white" {}
        _BaseColor ("Example Colour", Color) = (0, 0.66, 0.73, 1)
        _Smoothness ("Smoothness", Float) = 0.5
     
        [Toggle(_ALPHATEST_ON)] _EnableAlphaTest("Enable Alpha Cutoff", Float) = 0.0
        _Cutoff ("Alpha Cutoff", Float) = 0.5
     
        [Toggle(_NORMALMAP)] _EnableBumpMap("Enable Normal/Bump Map", Float) = 0.0
        _BumpMap ("Normal/Bump Texture", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1
        _BumpMapSnow ("Bump Texture for Snow", 2D) = "bump" {}

     
        [Toggle(_EMISSION)] _EnableEmission("Enable Emission", Float) = 0.0
        _EmissionMap ("Emission Texture", 2D) = "white" {}
        _EmissionColor ("Emission Colour", Color) = (0, 0, 0, 0)
        
        [Toggle(_METALLICSPECGLOSSMAP)] _EnableMetallic("Enable Metallic", Float) = 0.0
        _MetallicGlossMap ("Metallic/Gloss Texture", 2D) = "white" {}
        
        [Toggle(_OCCLUSIONMAP)] _EnableOcclusion("Enable Occlusion", Float) = 0.0
        _OcclusionMap ("Occusion Texture", 2D) = "gray" {}

        _MSRTex("Metallic Specular Roughness Texture", 2D) = "gray" {}
        _SmoothIntensity("Smooth Intensity", Range(0, 1)) = 1.0 


        [Header(Snow Parameters)]
        [Header(Snow Noise1)]
        _SnowLayerLevel("Snow Layer Level", Float) = 5.0
        _Buildup_Noise_Size("Buildup Noise Size", Float) = 50
        _Snow_Blend_Distance("Snow Blend Distance", Range(0, 1)) = 0.05
        _Snow_Amount("Snow Amount", Range(0, 1)) = 0.5
        [Header(Snow Noise2)]
        _Snow_Color_Noise_Size("Snow Color Noise Size", Float) = 250
        _Snow_Color_Noise_Strength("Snow Color Noise Strength", Range(0, 1)) = 0.22

    }
    
    SubShader
    {
        // SubShader Tags
        Tags 
        { 
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline"
            "IgnoreProjector" = "True"
        }

        // UniversalForward Pass
        Pass
        {
            Name "ForwardTest"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            HLSLPROGRAM
            #pragma target 2.0

            // Shader Stages
            #pragma vertex vert
            #pragma fragment frag

            // Material Keywords
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature _RECEIVE_SHADOWS_OFF
            #pragma shader_feature _METALLICSPECGLOSSMAP
            #pragma shader_feature _OCCLUSIONMAP

            // URP Keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "shared/my_utils.hlsl"
            #include "shared/snow_noise.hlsl"

            CBUFFER_START(UnityPerMaterial)
            // float4 _BaseMap_ST; // Texture tiling & offset inspector values
            // float4 _BaseColor;
            // float _BumpScale;
            // float4 _EmissionColor;
            // float _Smoothness;
            // float _Cutoff;
                float4 _MSRTex_ST;
                float4 _BumpMapSnow_ST;
            CBUFFER_END
            
            float _SmoothIntensity;
            float _SnowLayerLevel;
            TEXTURE2D(_MSRTex);       SAMPLER(sampler_MSRTex);
            TEXTURE2D(_BumpMapSnow);  SAMPLER(sampler_BumpMapSnow);

            struct Attributes {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float4 color        : COLOR;
                float2 uv           : TEXCOORD0;
                float2 lightmapUV   : TEXCOORD1;
            };
             
            struct Varyings {
                float4 positionCS               : SV_POSITION;
                float4 color                    : COLOR;
                float2 uv                       : TEXCOORD0;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
                // Note this macro is using TEXCOORD1
                #ifdef REQUIRES_WORLD_SPACE_POS_INTERPOLATOR
                    float3 positionWS               : TEXCOORD2;
                #endif
                    float3 normalWS                 : TEXCOORD3;
                #ifdef _NORMALMAP
                    float4 tangentWS                : TEXCOORD4;
                #endif
                float3 vDirWS                : TEXCOORD5;
                half4 fogFactorAndVertexLight   : TEXCOORD6;
                // x: fogFactor, yzw: vertex light
                #ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
                    float4 shadowCoord              : TEXCOORD7;
                #endif
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                // Vertex Position
                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = positionInputs.positionCS;
                #ifdef REQUIRES_WORLD_SPACE_POS_INTERPOLATOR
                    OUT.positionWS = positionInputs.positionWS;
                #endif
                // UVs & Vertex Color
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.color = IN.color;

                // View Direction
                OUT.vDirWS = GetWorldSpaceViewDir(positionInputs.positionWS);

                // Normals & Tangents
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.normalWS =  normalInputs.normalWS;
                #ifdef _NORMALMAP
                    real sign = IN.tangentOS.w * GetOddNegativeScale();
                    OUT.tangentWS = float4(normalInputs.tangentWS.xyz, sign);
                #endif

                // Vertex Lighting & Fog
                half3 vertexLight = VertexLighting(positionInputs.positionWS, normalInputs.normalWS);
                half fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
                OUT.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

                 // Baked Lighting & SH (used for Ambient if there is no baked)
                OUTPUT_LIGHTMAP_UV(IN.lightmapUV, unity_LightmapST, OUT.lightmapUV);
                OUTPUT_SH(OUT.normalWS.xyz, OUT.vertexSH);
                
                // Shadow Coord
                #ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
                    OUT.shadowCoord = GetShadowCoord(positionInputs);
                #endif
                
                return OUT;
            }

            InputData InitializeInputData(Varyings IN, half3 normalTS){
                InputData inputData = (InputData)0;
                #if defined(REQUIRES_WORLD_SPACE_POS_INTERPOLATOR)
                    inputData.positionWS = IN.positionWS;
                #endif
                half3 viewDirWS = SafeNormalize(IN.vDirWS);
                
                // TBN : Tangent Normal to World Normal
                #ifdef _NORMALMAP
                    float sgn = IN.tangentWS.w; // should be either +1 or -1
                    float3 bitangent = sgn * cross(IN.normalWS.xyz, IN.tangentWS.xyz);
                    inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(IN.tangentWS.xyz, bitangent.xyz, IN.normalWS.xyz));
                #else
                    inputData.normalWS = IN.normalWS;
                #endif
             
                inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
                inputData.viewDirectionWS = viewDirWS;

                // shadow coord
                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    inputData.shadowCoord = IN.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
                #else
                    inputData.shadowCoord = float4(0, 0, 0, 0);
                #endif
             
                inputData.fogCoord = IN.fogFactorAndVertexLight.x;
                inputData.vertexLighting = IN.fogFactorAndVertexLight.yzw;
                inputData.bakedGI = SAMPLE_GI(IN.lightmapUV, IN.vertexSH, inputData.normalWS);
                return inputData;
            }

            SurfaceData InitializeSurface(Varyings IN, float4 baseCol, float3 normalTS) // SurfaceData
            {
                // By casting 0 to SurfaceData, we automatically set all the contents to 0.
                SurfaceData surfaceData = (SurfaceData) 0;
                // float4 albedoAlpha = SampleAlbedoAlpha(IN.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
                float4 albedoAlpha = baseCol;
                surfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);
                surfaceData.albedo = baseCol.rgb;// * _BaseColor.rgb * IN.color.rgb;

                // Change: sample metallic and occlusion maps here -- TODO
                half4 specGloss = SampleMetallicSpecGloss(IN.uv, albedoAlpha.a);
                half4 var_MSRTex = SAMPLE_TEXTURE2D(_MSRTex, sampler_MSRTex, IN.uv);
                surfaceData.metallic = 0;
                surfaceData.specular = 0;
                surfaceData.smoothness = 0.5;
                // surfaceData.normalTS = SampleNormal(IN.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
                surfaceData.normalTS = normalTS;
                surfaceData.emission = SampleEmission(IN.uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
                surfaceData.occlusion = SampleOcclusion(IN.uv);
                return surfaceData;
            }
            

            void frag(Varyings IN,
                 out float4 col : SV_TARGET0)
            {
                float noise = 0;
                float lerpB = 0;
                SnowNoise_simple(IN.uv, noise);
                SnowNoise_simple2(IN.uv, lerpB);

                float4 red = float4(1,0,0,1);
                float4 blue = float4(0,0,1,1);

                float snow_layer_level = _SnowLayerLevel;
                float lerp_factor = saturate(1.0 - (IN.positionWS.y - snow_layer_level));
                
                // noise mask
                noise = lerp(1, lerpB, noise); 
                
                // perpare data
                float4 var_BaseMap = SampleAlbedoAlpha(IN.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
                float3 var_BumpMap = SampleNormal(IN.uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
                // _BumpMapSnow ("Bump Texture for Snow", 2D) = "bump" {}
                float3 var_BumpMapSnow = SampleNormal(IN.uv, TEXTURE2D_ARGS(_BumpMapSnow, sampler_BumpMapSnow), _BumpScale);

                // using data
                float3 base_col = lerp(var_BaseMap.rgb, noise, lerp_factor);
                float3 normal_lerp = lerp(var_BumpMap.rgb, var_BumpMapSnow.rgb, lerp_factor);
                
                SurfaceData surfaceData = InitializeSurface(IN, float4(base_col, var_BaseMap.a), normal_lerp);
                InputData inputData = InitializeInputData(IN, surfaceData.normalTS);

                
                col = UniversalFragmentPBR(inputData, surfaceData);
                 
                col.rgb = MixFog(col.rgb, inputData.fogCoord);
                col.a = saturate(col.a);
            }
            

            ENDHLSL
        }

        // ShadowCaster Pass
        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Universal Pipeline keywords

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        // DepthOnly Pass
        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            ColorMask R
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        // DepthNormals Pass
        // This pass is used when drawing to a _CameraNormalsTexture texture
        Pass
        {
            Name "DepthNormals"
            Tags
            {
                "LightMode" = "DepthNormals"
            }

            // -------------------------------------
            // Render State Commands
            ZWrite On
            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            // -------------------------------------
            // Shader Stages
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PARALLAXMAP
            #pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE

            // -------------------------------------
            // Universal Pipeline keywords
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

            // -------------------------------------
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
            ENDHLSL
        }
    }
}
