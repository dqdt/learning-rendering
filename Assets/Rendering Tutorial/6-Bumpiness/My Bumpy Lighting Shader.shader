// Bump mapping:
//   Use a height map texture to indicate the height of the surface.
//   Then we can derive the normal/tangent vectors from the height map values.
//
// The texture map has two variables: f(u,v). Consider one dimension for now.
// f'(x) = ( f(x) + f(x+h) ) / h
//
// The tangent vector is:
//   dx = h
//   dy = f(x+h) - f(xh)
// => [1, f'(x)]
// 
// The normal vector is perpendicular to the tangent. [a,b] -> [-b,a]
// => [-f'(x), 1] 
//
// Central difference:
//   f'(x) = ( f(x-h/2) + f(x+h/2) ) / h
//
// Combining the derivatives of two dimensions:
//   tangent_u = d/du f(u,v)
//   tangent_v = d/dv f(u,v)
//   normal = normalize(cross(tangent_v, tangent_u))
//     because unity is left-handed??
// 
// It's cheaper to use a normal map than to compute the derivatives on-demand.
// Create a normal map from a height map in texture Import Settings:
//   Texture Type: Normal map, Create from Grayscale
//
// https://docs.unity3d.com/Manual/StandardShaderMaterialParameterNormalMap.html
// Why the bluey-purple colors in the normal map?
// r,g,b stores the x,y,z values, where z is up (compared to y=up in unity)
//   The normal is usually pointing up, so everything will have a blue component.
//
// Unity uses DXT5 compression for the normal map:
//   https://en.wikipedia.org/wiki/S3_Texture_Compression
//   https://www.fsdeveloper.com/wiki/index.php?title=DXT_compression_explained
//   It's a fixed 3:1 (?) compression ratio.
//   It only stores the X and Y components of the normal vector (because the Z
//     component is always pointing outwards from the surface and can be computed?)
//   X and Y are stored in the G and Alpha channels of the texture, respectively.
//
// The normal map values are in the [0,1] range, and need to be shifted to [-1,1].
//
//
// So we have a texture and its normal map, and a bumpScale variable to vary the
//   "bumpiness". (This scales the X and Y components of the normal, making the Z
//   component scale opposite-ly)
// We can have a detail texture triplet too.
// How to add the detail texture normals? Detail normals should contribute less
//   than the main normals (details is higher frequency, lower amplitude).
// Before, we found that the normal vector is [u1-u2, 1, v1-v2].
// Suppose this vector is scaled after normalization: [s*(u1-u2), s, s*(v1-v2)].
//   We can get back the partial derivatives f'(u) = ( f(u+d) - f(u-d) ) / d = u2-u1 
//     by dividing by "s", which is the y-component of the vector.
//   Then let the normal be the sum of the unscaled partial derivatives:
//     mainNormal.xz / mainNormal.y + detailNormal.xz / detailNormal.y
//   => [Mx/My + Dx/Dy,
//                   1, 
//       Mz/My + Dz/Dy]
//   Since we multiplied .xz by bumpScale, that's a way to tune the amplitudes
//     of the textures relative to each other.
// 
// Whiteout Blending:
//   [Mx+Dx,     [(Mx/My)/Dy + (Dx/Dy)/My,
//    My*Dy,  =>                        1,
//    Mz+Dz]      (Mz/My)/Dy + (Dz/Dy)/My]
// It divides both normals by the same factor. What's the reason for this?
//   When one of the normals is flat (y = 1) then it does not affect the other normal.
//
// 
// How to get the world-space normal vector? (triangles can have any orientation)
//   Tangent vector is part of the mesh's vertex data; it is the U axis, pointing to the right
//   Bitangent or Binormal B = cross(N,T). This is the V axis, pointing forward.
//   Basically, we slap the texture on the triangle, and it has an orientation relative 
//     to the triangle. That's why we need the U vector.
//
// Sometimes a mesh is mirrored (because the model is symmetric).
//   Then the tangent is multiplied by +/- 1 for the flipped/non-flipped versions.
//   This sign is stored in the W channel.
//   This is stored in unity_WorldTransformParams.w ???
//
// Tangent space or tangent basis:  a 3D space on the mesh surface
//
// Vertex data now needs the tangent too:
//   position, uv, normal, tangent
//
// 
// Synched tangent space:
//   meaning that the normal map generation / interpretation is synchonized across different workflows
//   Unity uses mikktspace
//     the binormal is cross(normal.xyz, tangent.xyz) * tangent.w
//       we don't need to renormalize the normal or tangent vectors
//       therre is some distortion but it's not too much?
//
//
// https://forum.unity.com/threads/what-is-tangent-w-how-to-know-whether-its-1-or-1-tangent-w-vs-unity_worldtransformparams-w.468395/
// In OpenGL:
//   u : right
//   v : up
//
// In DirectX:
//   u : right
//   v : down
//
// So using tangent.w makes the code general for both OpenGL and DirectX.
// If a mesh scale is negative, might need to invert the corresponding uv axes.
// If the mesh or texture is mirrored, then the axes also change.
// => All cases are encoded into tangent.w (?)
//  
// unity_WorldTransformParams.w is usually +1. It is -1 when an odd number of
//   scale components are negative. Because it would interfere with tangent.w.
//
// 
Shader "Custom/My Bumpy Lighting Shader"
{
    Properties
    {
        _Tint ("Tint", Color) = (1, 1, 1, 1)

        _MainTex ("Albedo", 2D) = "white" {} // albedo = what color is diffuse reflection color
        [NoScaleOffset] _NormalMap ("Normals", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1

        [Gamma] _Metallic ("Metallic", Range(0,1)) = 0
        _Smoothness ("Smoothness", Range(0,1)) = 0.5

        _DetailTex ("Detail Texture", 2D) = "gray" {}
        [NoScaleOffset] _DetailNormalMap ("Detail Normals", 2D) = "bump" {}
        _DetailBumpScale ("Detail Bump Scale", Float) = 1
    }

    // Include in all CGPROGRAM blocks
    CGINCLUDE
    
    #define BINORMAL_PER_FRAGMENT

    ENDCG

    SubShader
    {
        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            
            CGPROGRAM
            #pragma target 3.0

            #pragma multi_compile _ VERTEXLIGHT_ON

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #define FORWARD_BASE_PASS
            #include "My Bumpy Lighting.cginc"

            ENDCG
        }

        // Another pass to process the second directional light
        Pass
        {
            Tags { "LightMode" = "ForwardAdd" }
            Blend One One  // Change the blend mode. Default is One Zero.
            ZWrite Off  // Disable writing to Z-buffer

            CGPROGRAM
            #pragma target 3.0

            #pragma multi_compile_fwdadd

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram
            
            #include "My Bumpy Lighting.cginc"
            ENDCG
        }
    }
}
