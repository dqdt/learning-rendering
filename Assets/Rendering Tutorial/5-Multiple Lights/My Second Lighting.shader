// We needed to change the render state for a shader pass.
//   The render state is passed to the "rendering engine".
// https://docs.unity3d.com/Manual/SL-Pass.html
//
// Ghostly lighting effect:
//   if there is only one pass and the blend mode is 
//     Blend One One
//
// Draw call batches:
//   Objects are rendered with the base pass.
//   then there's an additive pass for each light
//  
//   two lights = twice the number of batches?
//   shadows also need a batch
//   the skybox also needs a batch
//   need a batch to clear the screen , Z buffer, stencil
// See the batches on the Window/Analysis/Frame Debugger. You can step through each draw call.
//
// Dynamic batching can save batches when there's a single light, but not two lights.
// Generally,
//   helps to draw closer objects first
//   avoid GPU state changes: batch cubes and spheres, and draw meshes separately
//     objects that use the same material
//
//
// Point lights:
//   attenuation 1/r^2    or    1/(1+r^2)
//   Point light also has a range; objects farther than this range won't be lit,
//     (saving draw calls)
//   Problem when the point light intensity is not zero at its max range:
//     when an object moves in-out of the boundary: object will go from
//     completely-black to partially-lit -- a discontinuity
//
// AutoLight.cginc    ensures that light intensity drops off early
//   UNITY_LIGHT_ATTENUATION
//   needs #define POINT if this light is a point light
//   but don't include it if it's a directional light!!?
// 
// Spot light:
//   cone
// 
// Cookies:
//   a texture for light sources
//   spotlight cookie: should be a circle
//   directional light cookie:  should tile seamlessly
//   point light cookie: the texture should wrap around a sphere
//
//
// per-pixel vs per-vertex lighting:
//   for each fragment
//     for each light
//       compute color for this pixel  --  fragment shader
//
//   for each vertex
//     for each light
//       compute color for this vertex (and interpolate)  --  vertex shader
//
// Set the max Pixel Light Count in Project Settings/Quality/Rendering settings.
// Only point lights can be vertex lights.
//
// Changing a light's "Render Mode"
//   important / not important => this light is always / never a pixel light
//
// 
// Spherical harmonics:
//   When we have used up all of the allowed pixel/vertex light slots, 
//     we can create a function to describe the incoming light at all directions.
//   https://brilliant.org/wiki/spherical-harmonics/
//   "Spherical harmonics are a set of functions used to represent functions on
//    the surface of the sphere S2. It is a higher-dimensional analogy of Fourier
//    series."
//   Unity only uses the first three bands (constant, linear, quadratic).
//   There are nine parameters and Unity can compute them quickly (?)  not going into detail...
// 
// ShadeSH9(float(normal, 1))    built-in function
// Add the spherical harmonics to the indirect light.
//   Now when you reduce the max number of pixel lights, it will fallback to spherical
//     harmonics and the lighting detail is reduced, but not completely removed.
//   
Shader "Custom/My Second Lighting"
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
        Pass
        {
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            
            CGPROGRAM
            #pragma target 3.0

            // On our base pass, it will apply vertex lighting
            //   The color of the first vertex light in the array depends on which light is closest (?)
            #pragma multi_compile _ VERTEXLIGHT_ON

            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram

            #define FORWARD_BASE_PASS
            #include "My Lighting.cginc"

            ENDCG
        }

        // Another pass to process the second directional light
        Pass
        {
            Tags
            {
                "LightMode" = "ForwardAdd"
            }
            Blend One One  // Change the blend mode. Default is One Zero.
            ZWrite Off  // Disable writing to Z-buffer

            CGPROGRAM
            #pragma target 3.0
            // unity will compile multiple versions of this shader, defining one from this list
            // #pragma multi_compile DIRECTIONAL POINT SPOT

            // This includes all of them:
            // POINT DIRECTIONAL SPOT POINT_COOKIE DIRECTIONAL_COOKIE
            #pragma multi_compile_fwdadd
            #pragma vertex MyVertexProgram
            #pragma fragment MyFragmentProgram
            
            // #define POINT
            
            #include "My Lighting.cginc"
            ENDCG
        }
    }
}
