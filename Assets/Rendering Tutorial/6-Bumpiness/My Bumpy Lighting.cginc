#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

float4 _Tint;
sampler2D _MainTex, _DetailTex;
float4 _MainTex_ST, _DetailTex_ST;
// sampler2D _HeightMap;
// float4 _HeightMap_TexelSize;
sampler2D _NormalMap, _DetailNormalMap;
float _BumpScale, _DetailBumpScale;

float _Metallic;
float _Smoothness;

struct VertexData
{
    float4 position : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
};

struct Interpolators
{
    float4 position : SV_POSITION;
    float4 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;

    #if defined(BINORMAL_PER_FRAGMENT)
        float4 tangent : TEXCOORD2;
    #else
        float3 tangent : TEXCOORD2;
        float3 binormal : TEXCOORD3;  // compute in vertex shader or fragment shader?
    #endif                            // but also to save an interpolator slot
    float3 worldPos : TEXCOORD4;

    #if defined(VERTEXLIGHT_ON) 
        float3 vertexLightColor: TEXCOORD5;
    #endif
};

void ComputeVertexLightColor (inout Interpolators i)
{
    #if defined(VERTEXLIGHT_ON)
        // Compute all four vertex lights (if there exist less than four, the
        //   rest will be black (wasted?))
        i.vertexLightColor = Shade4PointLights(
            unity_4LightPosX0,
            unity_4LightPosY0,
            unity_4LightPosZ0,
            unity_LightColor[0].rgb,
            unity_LightColor[1].rgb,
            unity_LightColor[2].rgb,
            unity_LightColor[3].rgb,
            unity_4LightAtten0,
            i.worldPos,
            i.normal
        );
    #endif
}

float3 CreateBinormal(float3 normal, float3 tangent, float binormalSign)
{
    return cross(normal, tangent.xyz) * 
        (binormalSign * unity_WorldTransformParams.w);
}

Interpolators MyVertexProgram (VertexData v)
{
    Interpolators i;
    
    i.position = UnityObjectToClipPos(v.position);

    i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
    i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
    
    // Transforming normal vector from object space to world space:
    //   Be careful of scaling!
    i.normal = UnityObjectToWorldNormal(v.normal);

    #if defined(BINORMAL_PER_FRAGMENT)
        i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
    #else
        i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
        i.binormal = CreateBinormal(i.normal, i.tangent, v.tangent.w);
    #endif

    i.worldPos = mul(unity_ObjectToWorld, v.position);

    ComputeVertexLightColor(i);
    return i;
}

void InitializeFragmentNormal(inout Interpolators i)
{
    // // central difference
    // float2 du = float2(_HeightMap_TexelSize.x * 0.5, 0);
    // float u1 = tex2D(_HeightMap, i.uv - du);
    // float u2 = tex2D(_HeightMap, i.uv + du);
    // // float3 tu = float3(1, u2-u1, 0);

    // float2 dv = float2(0, _HeightMap_TexelSize.y * 0.5);
    // float v1 = tex2D(_HeightMap, i.uv - dv);
    // float v2 = tex2D(_HeightMap, i.uv + dv);
    // // float3 tv = float3(0, v2-v1, 1);

    // // i.normal = cross(tv, tu);  // unity is left-handed
    // i.normal = float3(u1-u2, 1, v1-v2);
    // i.normal = normalize(i.normal);

    // // DXT5: X in alpha channel, Y in G channel
    // i.normal.xy = tex2D(_NormalMap, i.uv).wy * 2 - 1;

    // i.normal.xy *= _BumpScale;  // If we increase the X,Y components, the Z component is less

    // i.normal.z = sqrt(1 - saturate(dot(i.normal.xy, i.normal.xy)));

    // Does the above three lines
    float3 mainNormal = 
        UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
    float3 detailNormal =
        UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);

    // i.normal = (mainNormal + detailNormal) * 0.5;

    // Doesn't make sense to average the main bumps and detail bumps
    //   -- detail bumps should contribute less
    // i.normal = float3(mainNormal.xy / mainNormal.z +
    //                   detailNormal.xy / detailNormal.z, 1);
    
    // Whiteout blending
    // i.normal = float3(mainNormal.xy + detailNormal.xy, 
    //                   mainNormal.z * detailNormal.z);
    // i.normal = normalize(i.normal);

    // i.normal = BlendNormals(mainNormal, detailNormal);

    // i.normal = i.normal.xzy;

    float3 tangentSpaceNormal = BlendNormals(mainNormal, detailNormal);

    // float3 binormal = cross(i.normal, i.tangent.xyz) *
    //     (i.tangent.w * unity_WorldTransformParams.w);

    #if defined(BINORMAL_PER_FRAGMENT)
        float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);
    #else
        float3 binormal = i.binormal;
    #endif

    i.normal = normalize(
        tangentSpaceNormal.x * i.tangent +
        tangentSpaceNormal.y * binormal +
        tangentSpaceNormal.z + i.normal
    );
}

UnityLight CreateLight (Interpolators i)
{
    UnityLight light;

    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
        light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
    #else 
        light.dir = _WorldSpaceLightPos0.xyz;
    #endif
    // float3 lightVec = _WorldSpaceLightPos0.xyz - i.worldPos;
    // float attenuation = 1 / (1 + dot(lightVec, lightVec));

    // the macro defines the "attenuation" variable...
    UNITY_LIGHT_ATTENUATION(attenuation, 0, i.worldPos);

    light.color = _LightColor0.rgb * attenuation;
    light.ndotl = DotClamped(i.normal, light.dir);  // diffuse term
    return light;
}

UnityIndirect CreateIndirectLight (Interpolators i)
{
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;  // ambient light
    indirectLight.specular = 0;  // environment reflections

    #if defined(VERTEXLIGHT_ON)
        indirectLight.diffuse = i.vertexLightColor;  // set ambient color through the vertex color
    #endif

    #if defined(FORWARD_BASE_PASS)
        indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
    #endif

    return indirectLight;
}

float4 MyFragmentProgram (Interpolators i) : SV_TARGET
{
    // Interpolating between unit vectors does not result in another unit vector.
    // But it is also costly to renormalize here.
    // i.normal = normalize(i.normal);
    InitializeFragmentNormal(i);
    
    // vector from point on surface to camera
    // Unity can also interpolate the view direction.
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;
    albedo *= tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;

    float3 specularTint;
    float oneMinusReflectivity;
    albedo = DiffuseAndSpecularFromMetallic(
        albedo, _Metallic, specularTint, oneMinusReflectivity
    );

    return UNITY_BRDF_PBS(
        albedo, specularTint,
        oneMinusReflectivity, _Smoothness,
        i.normal, viewDir,
        CreateLight(i), CreateIndirectLight(i)
    );
}

#endif