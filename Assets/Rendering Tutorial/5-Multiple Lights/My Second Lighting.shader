// We needed to change the render state for a Pass.
//   The render state is passed to the "rendering engine".
// https://docs.unity3d.com/Manual/SL-Pass.html
//
// Ghostly lighting effect:
//   if there is only one pass and the blend mode is 
//     Blend One One
//   render the lighting but not the surface of the mesh
//
// Draw call batches:
//   Objects are rendered with the base pass.
//   then there's an additive pass for each light
//  
//   two lights = twice the number of batches?
//   shadows also need a batch
//   the skybox also needs a batch
//   need a batch to clear the screen , Z buffer, stencil
// See the batches on the Window/Analysis/Frame Debugger. Step through each draw call.
//
// Dynamic batching can group objects in a single draw call when there's a single light,
//   but not when there's more than one light.
// Generally,
//   it helps to draw closer objects first
//   avoid GPU state changes: batch cubes and spheres, and draw meshes separately
//   group objects that use the same material
//
//
// Point lights:
//   attenuation 1/r^2    or    1/(1+r^2)
//   Point light has a range; objects farther than the max range won't be lit
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
//   cone shape
//   considered a vertex light
// 
// Cookies:
//   a texture for light sources. The light "emits" this texture.
//   spotlight cookie:         should be a circle
//   directional light cookie: texture should tile seamlessly
//   point light cookie:       texture should wrap around a sphere (import settings)
//
//
// per-pixel vs per-vertex lighting:
//   for each vertex
//     for each light
//       compute color for this vertex (and interpolate)  --  happens in vertex shader
// 
//   for each fragment
//     for each light
//       compute color for this pixel  --  happens in fragment shader
//
// Set the max Pixel Light Count in Project Settings/Quality/Rendering settings.
//   Limits the number of draw calls by limiting the lighting quality.
//   For each object, there's a ForwardBase pass, and additional ForwardAdd passes for
//     each light. https://docs.unity3d.com/Manual/RenderTech-ForwardRendering.html
//     (Link gives a surface-level description)
//   Unity will apply the "most significant" lights up to the Pixel Light Count limit.
//   The remaining lights will not contribute. But there are other ways to include
//     the remaining lights: 
//
// Changing a light's "Render Mode"
//   important / not important => this light is always / never a pixel light  
//
// Vertex light:
//   Compute the color for a vertex, which will be interpolated.
//   Only point lights are considered for the vertex light values.
//
// There's vertex lighting, where unity picks the four "most significant" light
//   sources affecting a vertex. We can combine these and set it as the vertex
//   ambient color.
// Shade4PointLights
// 
// Spherical harmonics:
//   When we have used up all of the allowed pixel/vertex light slots, 
//     we can create a function to describe the incoming light at all directions.
//   https://brilliant.org/wiki/spherical-harmonics/
//   "Spherical harmonics are a set of functions used to represent functions on
//    the surface of the sphere S2. It is a higher-dimensional analogy of Fourier
//    series."
//   Unity only uses the first three bands (constant, linear, quadratic) so it only
//     has very low frequency basis functions.
//   There are nine parameters and Unity can compute this function quickly (?)  not going into detail...
//    
// ShadeSH9(float(normal, 1))    built-in function
//   "GET" the spherical harmonics function value from the normal vector.
//   https://answers.unity.com/questions/1331293/shadesh9-always-zero.html
//     ShadeSH9 IS NONZERO ONLY DURING THE ForwardBase pass!!!
//     It will not pick up the skybox unless the scene is baked ?!!?!
// Add the spherical harmonics as part of the indirect light.
//   Now when you reduce the max number of pixel lights, it will fallback to spherical
//     harmonics and the lighting detail is reduced, but not completely removed.
// 
//
// Observations in the Frame Debugger:
//   If there are point/spot lights, there will be unity_4LightPos vectors available.
//     The order in which lights appear in the float4's depends on the vertex position.
//   If there are no point/spot lights, it will not be included (or shown in the debugger, at least).
//   If there are four or fewer vertex lights, then nothing is moved to the spherical harmonics.
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
            Tags { "LightMode" = "ForwardBase" }
            
            CGPROGRAM
            #pragma target 3.0

            // Unity looks for a base pass with VERTEXLIGHT_ON keyword.
            // On the base pass, it will apply vertex lighting.
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
            Tags { "LightMode" = "ForwardAdd" }
            Blend One One  // Change the blend mode. Default is One Zero.
            ZWrite Off  // Disable writing to Z-buffer

            CGPROGRAM
            #pragma target 3.0
            // unity will compile multiple variants of this shader, one for each in this list
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
