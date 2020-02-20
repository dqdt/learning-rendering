// Shader [name] {} 
//   A `Shader` block contains the name that will be shown in menus.
// A `Properties` block exposes values in the editor.
//   [_PropertyName] ([PropertyNameInEditor], [Type]) = [DefaultValue]
//   When we assign a shader to a material, that material will now have 
//     these properties in the editor.
//   The naming convention for property names is to start with an underscore,
//     followed by a capitalized letter, then lowercase after that.
// A SubShader block is used to group together shader variants.
//   A sub-shader needs at least one Pass block (shader pass).
//   A shader pass contains a vertex program and a fragment program.
//
// Shader include files:
//   UnityCG.cginc
//   UnityShaderVariables.cginc
//   UnityInstancing.cginc
//   HLSLSupport.cginc
// More at: https://docs.unity3d.com/Manual/SL-BuiltinIncludes.html
//
// Semantics: 
//   POSITION    : input vertex position? object-space position [x,y,z,w]
//                 SV : system value
//   SV_POSITION : output of vertex program - the final vertex position
//   SV_TARGET   : output of fragment program - default shader target is the framebuffer
//   TEXCOORD0, TEXCOORD1, .. : there are no semantics for interpolated data, so people
//                              just use TEXCOORDx to label interpolated data (for compatibility reasons ??)
//
// The vertex and fragment "functions" have parameters that can be input or output
//   ("in" and "out" in GLSL), and each of them labeled with a semantic (a name 
//    that's common between the vertex and fragment shaders, so the data persists (?)).
// But the return value of these functions will always be the final vertex position or the pixel color (??)
// ACTUALLY, nO. We can have a struct and put semantics on the struct members...
//
// Textures:
//   Add a _MainTex property and assign a texture to it in the editor.
//   Access the texture in the shaders with sampler2D _MainTex.
//   In the editor there are Tiling and Offset parameters to scale and translate the texture.
// Mipmaps and Filtering:
//   Mipmaps: when you are close to an object, need higher resolution texture.
//     When farther away, lower res is passable. Mipmaps are resized versions of the texture.
//   Want to get the texture color for some (u,v) value:
//     The texture is an image, and doesn't have infinite resolution.
//     No filtering: Nearest pixel
//     Bilinear filtering: Interpolate between nearest pixels
//     Trilinear filtering: Interpolate between mipmap levels as well
Shader "Unlit/My First Shader"
{
    Properties
    {
        _Tint ("Tint", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}  // convention is to name the main texture _MainTex
        // _SecondProperty ("x", int) = 0
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
            sampler2D _MainTex;
            float4 _MainTex_ST; // _ST means "Scale and Translation"
                                // It's actually for texture tiling and offset.
                                // .xy is scaling
                                // .zw is offset
            // How it's meant to be used (?):
            //     uv = uv * _MainTex_ST.xy + _MainTex_ST.zw
            // 
            // Why it's called scale: Similar to sin(f*x) where f is the frequency.
            
            struct Interpolators
            {
                float4 position: SV_POSITION;
                float2 uv: TEXCOORD0;
            };

            struct VertexData
            {
                float4 position: POSITION;
                float2 uv: TEXCOORD0;
            };

            Interpolators MyVertexProgram (VertexData v)
            {
                Interpolators i;
                i.position = UnityObjectToClipPos(v.position);  
                i.uv = TRANSFORM_TEX(v.uv, _MainTex);  // does the same thing
                                                       // #define TRANSFORM_TEX(tex,name) (tex.xy * name##_ST.xy + name##_ST.zw)
                // i.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                return i;
            }

            float4 MyFragmentProgram (Interpolators i) : SV_TARGET
            {
                return tex2D(_MainTex, i.uv) * _Tint;
                // return float4(i.uv, 1, 1);
                // return float4(i.localPosition + 0.5, 1) * _Tint;
            }

            ENDCG
        }
    }
    // SubShader
    // {
    //     Pass
    //     {
    //         CGPROGRAM

    //         #pragma vertex MyVertexProgram
    //         #pragma fragment MyFragmentProgram

    //         #include "UnityCG.cginc"

    //         float4 _Tint;

            

    //         float4 MyVertexProgram (
    //             float4 position : POSITION,
    //             out float3 localPosition: TEXCOORD0
    //         ) : SV_POSITION 
    //         {
    //             localPosition = position.xyz;
    //             // Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
    //             return UnityObjectToClipPos(position);  
    //             // return position;  // returns the object-space vertex position (just mesh data)
    //             // return 0;  // interpreted as float4(0,0,0,0)
    //         }

    //         float4 MyFragmentProgram (
    //             float4 position : SV_POSITION,
    //             float3 localPosition : TEXCOORD0
    //         ) : SV_TARGET
    //         {
    //             return float4(localPosition, 1);
    //             // return _Tint;
    //             // return float4(1,1,0,1);
    //             // return 0;
    //         }

    //         ENDCG
    //     }
    // }
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
