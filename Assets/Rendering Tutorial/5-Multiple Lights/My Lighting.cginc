#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

float4 _Tint;
sampler2D _MainTex;
float4 _MainTex_ST;

float _Metallic;
float _Smoothness;

struct VertexData
{
    float4 position : POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD1;
};

struct Interpolators
{
    float4 position : SV_POSITION;
    float3 normal : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float3 worldPos : TEXCOORD2;

    #if defined(VERTEXLIGHT_ON) 
        float3 vertexLightColor: TEXCOORD3;
    #endif
};

void ComputeVertexLightColor (inout Interpolators i)
{
    #if defined(VERTEXLIGHT_ON)
        
        // UnityShaderVariables stores the four vertex light positions in these float4's
        // float3 lightPos = float3(
        //     unity_4LightPosX0.x,
        //     unity_4LightPosY0.x,
        //     unity_4LightPosZ0.x
        // );

        // float3 lightVec = lightPos - i.worldPos;
        // float3 lightDir = normalize(lightVec);
        // float ndotl = DotClamped(i.normal, lightDir);

        // // This factor helps approximate the light attenuation???
		// float attenuation = 
        //     1 / (1 + dot(lightVec, lightVec) * unity_4LightAtten0.x);

        // // UnityShaderVariables defines an array of vertex light colors
        // i.vertexLightColor = unity_LightColor[0].rgb * attenuation;

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

Interpolators MyVertexProgram (VertexData v)
{
    Interpolators i;
    i.position = UnityObjectToClipPos(v.position);
    
    // Transforming normal vector from object space to world space:
    //   Be careful of scaling!
    i.normal = UnityObjectToWorldNormal(v.normal);
    i.uv = TRANSFORM_TEX(v.uv, _MainTex);

    i.worldPos = mul(unity_ObjectToWorld, v.position);

    ComputeVertexLightColor(i);
    return i;
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
    i.normal = normalize(i.normal);
    
    // vector from point on surface to camera
    // Unity can also interpolate the view direction.
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

    float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;

    float3 specularTint;
    float oneMinusReflectivity;
    albedo = DiffuseAndSpecularFromMetallic(
        albedo, _Metallic, specularTint, oneMinusReflectivity
    );

    // float3 shColor = ShadeSH9(float4(i.normal, 1));
    // return float4(shColor, 1);

    return UNITY_BRDF_PBS(
        albedo, specularTint,
        oneMinusReflectivity, _Smoothness,
        i.normal, viewDir,
        CreateLight(i), CreateIndirectLight(i)
    );
}

#endif