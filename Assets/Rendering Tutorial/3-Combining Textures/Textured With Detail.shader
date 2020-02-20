// Combining textures:
//   _MainTex
//   _DetailTex  // adds smaller details to the main texture
//
//   When you multiply two colors, the result will be darker
//     (both color values are in [0,1], so their product is less)
//   
//   Let's say we scale our DetailTex color values by 2.
//     color = tex2D(_MainTex, uv) * tex2D(_DetailTex, uv) * 2
//     color = tex2D(_MainTex, uv) * tex2D(_DetailTex, uv) * unity_ColorSpaceDouble
//
//   Then a detail color greater or less than 1/2 will brighten or darken
//     the color. (In this tutorial we use a detail texture centered around
//     gray. It's commonly grayscale, but doesn't have to be).
//   
// Gamma vs Linear color space:
//   In gamma space, color intensity is an exponential curve:
//     x ^ gamma
//   In the sRGB color format, the average gamma is 1/2.2
//   Unity assumes colors are stored as sRGB. If the color space is changed to Linear
//     (Edit/Project Settings/Player) then Unity will convert all color values from 
//     gamma to linear before we can do any math using the color values.
//   1) Bypass sRGB Sampling in the texture import settings
//   2) use unity_ColorSpaceDouble which is either 2 or 4.59 depending on the color space
Shader "Custom/Textured With Detail"
{
    Properties
    {
        _Tint ("Tint", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _DetailTex ("Detail Texture", 2D) = "gray" {}
    }

    SubShader
    {
        Pass
        {
            CGPROGRAM
            
            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #include "UnityCG.cginc"

            float4 _Tint;
            sampler2D _MainTex, _DetailTex;
            float4 _MainTex_ST, _DetailTex_ST;
            
            struct Interpolators
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 uvDetail : TEXCOORD1;
            };

            struct VertexData
            {
                float4 position : POSITION;
                float2 uv : TEXCOORD0;
            };

            Interpolators MyVertexProgram (VertexData v)
            {
                Interpolators i;
                i.position = UnityObjectToClipPos(v.position);  
                i.uv = TRANSFORM_TEX(v.uv, _MainTex);
                i.uvDetail = TRANSFORM_TEX(v.uv, _DetailTex);
                return i;
            }

            float4 MyFragmentProgram (Interpolators i) : SV_TARGET
            {
                float4 color = tex2D(_MainTex, i.uv) * _Tint;
                color *= tex2D(_DetailTex, i.uvDetail) * unity_ColorSpaceDouble;
                return color;
            }

            ENDCG
        }
    }
}