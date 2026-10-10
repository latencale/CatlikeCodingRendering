#if !defined(MY_LIGHTMAPPING_INCLUDED)
#define MY_LIGHTMAPPING_INCLUDED

#include "UnityPBSLighting.cginc"
#include "UnityMetaPass.cginc"

float4 _Color;
sampler2D _MainTex, _DetailTex, _DetailMask;
float4 _MainTex_ST, _DetailTex_ST;

sampler2D _MetallicMap;
float _Metallic;
float _Smoothness;

sampler2D _EmissionMap;
float3 _Emission;

struct VertexData {
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
    float2 uv2 : TEXCOORD2;
};

struct Interpolators {
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;
};

Interpolators MyLightmappingVertexProgram(VertexData v){
    Interpolators i;
    i.pos = UnityMetaVertexPosition(
        v.vertex, v.uv1, v.uv2, unity_LightmapST, unity_DynamicLightmapST
    );//顶点的坐标转换为uv坐标：两套uv分别用于 静态光照贴图 和 动态光照贴图
    i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
    i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
    return i;
}

//计算金属度
float GetMetallic(Interpolators i)
{
#if defined(_METALLIC_MAP)
    return tex2D(_MetallicMap, i.uv.xy).r ;
#else
    return _Metallic;
#endif
}


float GetSmoothness(Interpolators i)
{
    float smoothness = 1;
#if defined(_SMOOTHNESS_ALBEDO)
    smoothness = tex2D(_MainTex, i.uv.xy).a;
#elif defined(_SMOOTHNESS_METALLIC) && defined(_METALLIC_MAP)  
    smoothness = tex2D(_MetallicMap, i.uv.xy).a ;
    //金属贴图中 r通道存储金属度，a通道存储光滑度
#endif
    return smoothness * _Smoothness;

}

float3 GetEmission(Interpolators i)
{
#if defined(_EMISSION_MAP)
    return tex2D(_EmissionMap, i.uv.xy) * _Emission;
#else
    return _Emission;
#endif
}

float GetDetailMask(Interpolators i)
{
#if defined(_DETAIL_MASK)
    return tex2D(_DetailMask, i.uv.xy).a;
#else
    return 1;
#endif
}

float3 GetAlbedo(Interpolators i)
{
    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb; //反照率：物体的颜色
#if defined(_DETAIL_ALBEDO_MAP)
    float3 details = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;; //细节贴图
    albedo = lerp(albedo, albedo * details, GetDetailMask(i));
#endif
    return albedo;
}

float4 MyLightmappingFragmentProgram(Interpolators i) : SV_TARGET{
    UnityMetaInput surfaceData;//存储烘焙时需要的信息
    surfaceData.Emission = GetEmission(i);
    float oneMinusReflectivity;
    surfaceData.Albedo = DiffuseAndSpecularFromMetallic(
        GetAlbedo(i), GetMetallic(i),
        surfaceData.SpecularColor, oneMinusReflectivity 
    );
    float roughness = SmoothnessToRoughness(GetSmoothness(i)) * 0.5;
    surfaceData.Albedo += surfaceData.SpecularColor * roughness;
    //由于烘焙不嫩烘焙出镜面反射，将一部分镜面反射的反射能量算入漫反射

    return UnityMetaFragment(surfaceData);
    //UnityMetaInput转float4
}
#endif