// Shader [name] {} 
//   A Shader block contains the name that will be shown in menus.
// A SubShader block groups together shader variants.
//   A sub-shader needs at least one Pass block (shader pass).
//   A shader pass contains a vertex program and a fragment program.
//
// Shader include files:
//   UnityCG.cginc
//   UnityShaderVariables.cginc
//   UnityInstancing.cginc
//   HLSLSupport.cginc
//
// 
Shader "Unlit/My First Shader"
{

    SubShader
    {
        Pass
        {
            CGPROGRAM

#pragma vertex MyVertexProgram
#pragma fragment MyFragmentProgram

#include "UnityCG.cginc"

float4 MyVertexProgram (float4 position : POSITION) : SV_POSITION  // SV = system value, POSITION = final vertex position
{
    return UnityObjectToClipPos(position);  // Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
    // return position;  // returns the object-space vertex position (just mesh data)
    // return 0;  // interpreted as float4(0,0,0,0)
}

float4 MyFragmentProgram (float4 position : SV_POSITION) : SV_TARGET  // the default shader target: where the final color should be written to
{
    return 0;
}

            ENDCG
        }
    }
}


// Shader "Unlit/My First Shader"
// {
//     Properties
//     {
//         _MainTex ("Texture", 2D) = "white" {}
//     }
//     SubShader
//     {
//         Tags { "RenderType"="Opaque" }
//         LOD 100

//         Pass
//         {
//             CGPROGRAM
//             #pragma vertex vert
//             #pragma fragment frag
//             // make fog work
//             #pragma multi_compile_fog

//             #include "UnityCG.cginc"

//             struct appdata
//             {
//                 float4 vertex : POSITION;
//                 float2 uv : TEXCOORD0;
//             };

//             struct v2f
//             {
//                 float2 uv : TEXCOORD0;
//                 UNITY_FOG_COORDS(1)
//                 float4 vertex : SV_POSITION;
//             };

//             sampler2D _MainTex;
//             float4 _MainTex_ST;

//             v2f vert (appdata v)
//             {
//                 v2f o;
//                 o.vertex = UnityObjectToClipPos(v.vertex);
//                 o.uv = TRANSFORM_TEX(v.uv, _MainTex);
//                 UNITY_TRANSFER_FOG(o,o.vertex);
//                 return o;
//             }

//             fixed4 frag (v2f i) : SV_Target
//             {
//                 // sample the texture
//                 fixed4 col = tex2D(_MainTex, i.uv);
//                 // apply fog
//                 UNITY_APPLY_FOG(i.fogCoord, col);
//                 return col;
//             }
//             ENDCG
//         }
//     }
// }
