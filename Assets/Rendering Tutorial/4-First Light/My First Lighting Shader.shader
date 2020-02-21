// Now, the vertex data is: {position, normal, uv}
// The normal vector is given in object-space, and needs to be transformed
//   to world-space for calculations in the fragment shader. It's the classic
//   "transformation-does-not-preserve-scaling" problem:
// 
// https://songho.ca/opengl/gl_normaltransform.html
// A triangle has normal n = [nx;ny;nz;nw]. (column vector)
// For any point on the triangle's plane,
//   dot(n,[x;y;z;w]) = 0            (plane equation)
//   [nx,ny,nz,nw]*[x;y;z;w] = 0.    (row vector * column vector)
// Now let's apply the transformation: 
//   transpose(n) * inv(M) * M * [x;y;z;w] = 0.
//   {     new normal     }  { new vertex }
// 
//   transpose(inv(M)) * n    =>    now it's a column vector
//
// ObjectToWorldNormal    built-in function that does this transformation
//  (but can't find docs)
//
// Bidirectional reflectance distribution function (BRDF) defines how light is
//   reflected at an opaque surface.
// There's also BTDF (transmittance). (It's like reflection and refraction?)
//
// This tutorial goes over Phong / Blinn-Phong lighting model and starts with
//   the math, but then replaces it with a built-in function...
// 
// Diffuse:
//   Light hits a surface, refracts internally many times, and reflects at all
//     directions equally. Dot product with the surface normal:
//       dot(diffuse_color, normal)
//   diffuse = lightColor * albedo * DotClamped(lightDir, normal)
//
// Clamp [0,1]:
//    max(0, x)
//    saturate(x)
//    DotClamped(a,b)    built-in function
//
// _WorldSpaceLightPos0    position of the "current" light
// _LightColor0
// 
// https://en.wikipedia.org/wiki/Albedo
// Albedo: measure of diffuse radiation out of the total radiation received.
//   It's a value from 0 to 1.
//
// Specular:
//   Surfaces appear shiny because light reflects off of it.
//   Let's say a ray "D" hits a surface with normal "N". The reflected vector
//     "R" is D - 2*dot(D,N)*N. The amount of the reflected ray that is seen
//     is dot(R, dirToEye).
//   The Blinn-Phong reflection model instead uses the half-vector, which is
//       halfVector = (-D + dirToEye) / 2
//       dot(halfVector, normal)    instead of dot(R, dirToEye)
// 
// Smoothness:
//   The smoother the surface, the more mirror-like it is (more precise reflections).
//     pow( dot(halfVector,normal), smoothness)
//   
// Energy conservation:
//   When adding two colors, it's common to go over 1 (so it appears white).
//   We know our light is composed of diffuse and specular components, so
//     "conserve energy" by doing something like: a*diffuse + (1-a)*specular
//
// EnergyConservationBetweenDiffuseAndSpecular    built-in function
//
//
// 
// Up to now we were using the "specular workflow" for creating materials.
// The "metallic workflow" uses a value to indicate how "metallic" a material is.
// DiffuseAndSpecularFromMetallic    built-in function
//
// UNITY_BRDF_PBS    physically-based shading
//   still has diffuse and specular, but calculates it differently
//   there are many different versions of BRDF
Shader "Custom/My First Lighting Shader"
{
    Properties
    {
        _Tint ("Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Albedo", 2D) = "white" {} // albedo = what color is diffuse reflection color
        [Gamma] _Metallic ("Metallic", Range(0,1)) = 0
        _Smoothness ("Smoothness", Range(0,1)) = 0.5
    }

    SubShader
    {
        // Physically-Based Shading
        Pass
        {
            CGPROGRAM

            #pragma target 3.0

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #include "UnityPBSLighting.cginc"

            float4 _Tint;
            sampler2D _MainTex;
            float4 _MainTex_ST;

            float _Metallic;
            float _Smoothness;

            struct VertexData {
                float4 position : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD1;
            };
            
            struct Interpolators {
                float4 position : SV_POSITION;
                float3 normal : TEXCOORD0;
                float2 uv : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };

            Interpolators MyVertexProgram (VertexData v) {
                Interpolators i;
                i.position = UnityObjectToClipPos(v.position);
                
                // Transforming normal vector from object space to world space:
                //   Be careful of scaling!
                i.normal = UnityObjectToWorldNormal(v.normal);
                i.uv = TRANSFORM_TEX(v.uv, _MainTex);

                i.worldPos = mul(unity_ObjectToWorld, v.position);
                return i;
            }

            float4 MyFragmentProgram (Interpolators i) : SV_TARGET {
                // Interpolating between unit vectors does not result in another unit vector.
                // But it is also costly to renormalize here.
                i.normal = normalize(i.normal);
                
                // vector from point on surface to camera
                // Unity can also interpolate the view direction.
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                float3 lightDir = _WorldSpaceLightPos0.xyz;

                float3 lightColor = _LightColor0.rgb;
                float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;

                float3 specularTint;
                float oneMinusReflectivity;
                albedo = DiffuseAndSpecularFromMetallic(
                    albedo, _Metallic, specularTint, oneMinusReflectivity
                );

                UnityLight light;
                light.color = lightColor;
                light.dir = lightDir;
                light.ndotl = DotClamped(i.normal, lightDir);  // diffuse term

                UnityIndirect indirectLight;
                indirectLight.diffuse = 0;  // ambient light
                indirectLight.specular = 0;  // environment reflections

                return UNITY_BRDF_PBS(
                    albedo, specularTint,
                    oneMinusReflectivity, _Smoothness,
                    i.normal, viewDir,
                    light, indirectLight
                );
            }
            

            ENDCG
        }
    }
}
// Shader "Custom/My First Lighting Shader"
// {
//     Properties
//     {
//         _Tint ("Tint", Color) = (1, 1, 1, 1)
//         _MainTex ("Albedo", 2D) = "white" {} // albedo = what color is diffuse reflection color
//         [Gamma] _Metallic ("Metallic", Range(0,1)) = 0
//         _Smoothness ("Smoothness", Range(0,1)) = 0.5
//     }

//     SubShader
//     {
//         // Metallic workflow
//         Pass
//         {
//             CGPROGRAM

//             #pragma vertex MyVertexProgram
//             #pragma fragment MyFragmentProgram

//             #include "UnityStandardBRDF.cginc"  // also includes "UnityCG.cginc"
//             #include "UnityStandardUtils.cginc"

//             float4 _Tint;
//             sampler2D _MainTex;
//             float4 _MainTex_ST;

//             float _Metallic;
//             float _Smoothness;

//             struct VertexData {
//                 float4 position : POSITION;
//                 float3 normal : NORMAL;
//                 float2 uv : TEXCOORD1;
//             };
            
//             struct Interpolators {
//                 float4 position : SV_POSITION;
//                 float3 normal : TEXCOORD0;
//                 float2 uv : TEXCOORD1;
//                 float3 worldPos : TEXCOORD2;
//             };

//             Interpolators MyVertexProgram (VertexData v) {
//                 Interpolators i;
//                 i.position = UnityObjectToClipPos(v.position);
                
//                 // Transforming normal vector from object space to world space:
//                 //   Be careful of scaling!
//                 i.normal = UnityObjectToWorldNormal(v.normal);
//                 i.uv = TRANSFORM_TEX(v.uv, _MainTex);

//                 i.worldPos = mul(unity_ObjectToWorld, v.position);
//                 return i;
//             }

//             float4 MyFragmentProgram (Interpolators i) : SV_TARGET {
//                 // Interpolating between unit vectors does not result in another unit vector.
//                 // But it is also costly to renormalize here.
//                 i.normal = normalize(i.normal);
                
//                 // vector from point on surface to camera
//                 // Unity can also interpolate the view direction.
//                 float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

//                 float3 lightDir = _WorldSpaceLightPos0.xyz;

//                 float3 lightColor = _LightColor0.rgb;
//                 float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;

//                 float3 specularTint;
//                 float oneMinusReflectivity;
//                 albedo = DiffuseAndSpecularFromMetallic(
//                     albedo, _Metallic, specularTint, oneMinusReflectivity
//                 );

//                 float3 diffuse = 
//                     albedo * lightColor * DotClamped(lightDir, i.normal);

//                 // Blinn-Phong
//                 float3 halfVector = normalize(lightDir + viewDir);
//                 float3 specular = specularTint * lightColor * 
//                     pow(DotClamped(halfVector, i.normal), _Smoothness*100);

//                 return float4(diffuse + specular, 1);
//             }
            

//             ENDCG
//         }
//     }
// }

// Shader "Custom/My First Lighting Shader"
// {
//     Properties
//     {
//         _Tint ("Tint", Color) = (1, 1, 1, 1)
//         _MainTex ("Albedo", 2D) = "white" {} // albedo = what color is diffuse reflection color
//         _SpecularTint ("Specular", Color) = (0.5, 0.5, 0.5)
//         _Smoothness ("Smoothness", Range(0,1)) = 0.5
//     }

//     SubShader
//     {
//         // Specular workflow
//         Pass
//         {
//             // Not needed anymore??
//             // Tags
//             // {
//             //     "LightMode" = "ForwardBase"
//             // }

//             CGPROGRAM

//             #pragma vertex MyVertexProgram
//             #pragma fragment MyFragmentProgram

//             #include "UnityStandardBRDF.cginc"  // also includes "UnityCG.cginc"
//             #include "UnityStandardUtils.cginc"

//             float4 _Tint;
//             sampler2D _MainTex;
//             float4 _MainTex_ST;

//             float4 _SpecularTint;
//             float _Smoothness;

//             struct VertexData {
//                 float4 position : POSITION;
//                 float3 normal : NORMAL;
//                 float2 uv : TEXCOORD1;
//             };
            
//             struct Interpolators {
//                 float4 position : SV_POSITION;
//                 float3 normal : TEXCOORD0;
//                 float2 uv : TEXCOORD1;
//                 float3 worldPos : TEXCOORD2;
//             };

//             Interpolators MyVertexProgram (VertexData v) {
//                 Interpolators i;
//                 i.position = UnityObjectToClipPos(v.position);
                
//                 // Transforming normal vector from object space to world space:
//                 //   Be careful of scaling!
//                 i.normal = UnityObjectToWorldNormal(v.normal);
//                 i.uv = TRANSFORM_TEX(v.uv, _MainTex);

//                 i.worldPos = mul(unity_ObjectToWorld, v.position);
//                 return i;
//             }

//             float4 MyFragmentProgram (Interpolators i) : SV_TARGET {
//                 // Interpolating between unit vectors does not result in another unit vector.
//                 // But it is also costly to renormalize here.
//                 i.normal = normalize(i.normal);
                
//                 // Clamp [0,1]
//                 // return max(0, dot(float3(0,1,0), i.normal));
//                 // return saturate(dot(float3(0,1,0), i.normal));                
//                 // return DotClamped(float3(0,1,0), i.normal);

//                 // vector from point on surface to camera
//                 // Unity can also interpolate the view direction.
//                 float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

//                 float3 lightDir = _WorldSpaceLightPos0.xyz;

//                 float3 lightColor = _LightColor0.rgb;
//                 float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;

//                 // make diffuse + specular = 1
//                 // albedo *= 1 - _SpecularTint.rgb;

//                 // use the strongest component of the specular tint
//                 // albedo *= 1 - max(_SpecularTint.r,
//                 //               max(_SpecularTint.g,
//                 //                   _SpecularTint.b));

//                 // UnityStandardUtils
//                 float oneMinusReflectivity; // is an output variable; needed for other computations
//                 albedo = EnergyConservationBetweenDiffuseAndSpecular(
//                     albedo, _SpecularTint.rgb, oneMinusReflectivity
//                 );

//                 float3 diffuse = albedo * lightColor * DotClamped(lightDir, i.normal);

//                 // saturate = clamp between 0 and 1 :)
//                 // reflect(D,N) = D-2*N*dot(N,D)
//                 // float3 reflectionDir = reflect(-lightDir, i.normal);
//                 // return pow(DotClamped(viewDir, reflectionDir), _Smoothness*100);
                
//                 // Blinn-Phong
//                 //   halfway between the light direction and the view direction
//                 float3 halfVector = normalize(lightDir + viewDir);
//                 float3 specular = _SpecularTint.rgb * lightColor * 
//                     pow(DotClamped(halfVector, i.normal), _Smoothness*100);

//                 // return float4(specular, 1);
//                 // return float4(reflectionDir * 0.5 + 0.5, 1);

                
//                 return float4(diffuse + specular, 1);
//             }
            

//             ENDCG
//         }
//     }
// }