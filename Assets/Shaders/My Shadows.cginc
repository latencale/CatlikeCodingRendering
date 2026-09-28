
#if !defined(MY_SHADOWS_INCLUDED)
#define MY_SHADOWS_INCLUDED

#include "UnityCG.cginc"

#if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
    #if defined(_SEMITRANSPARENT_SHADOWS)
        #define SHADOWS_SEMITRANSPARENT 1
        //把SHADOWS_SEMITRANSPARENT替换为1，就像define ll long long 
    #else
        #define _RENDERING_CUTOUT
    #endif
#endif
#if SHADOWS_SEMITRANSPARENT || defined(_RENDERING_CUTOUT)
    #if !defined(_SMOOTHNESS_ALBEDO)
        #define SHADOWS_NEED_UV 1
    #endif
#endif


float4 _Color;
sampler2D _MainTex;
float4 _MainTex_ST;
float _Cutoff;
sampler3D _DitherMaskLOD;
//3D纹理采样器，Unity内置抖动图案图集，用于半透明阴影的抖动裁剪
//16个4*4的像素图标，存在x,y轴；z轴存索引index

struct VertexData
{
    float4 position : POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
};

struct InterpolatorsVertex
{
    float4 position : SV_POSITION;
#if SHADOWS_NEED_UV
    float2 uv : TEXCOORD0;
#endif
#if defined(SHADOWS_CUBE)
    float3 lightVec : TEXCOORD1;
#endif
};

struct Interpolators
{
#if SHADOWS_SEMITRANSPARENT
    UNITY_VPOS_TYPE vpos : VPOS;
    //再半透明模式，声明一个VPOS
    //VPOS：屏幕空间中的像素坐标
#else
    float4 position : SV_POSITION;
#endif
    
#if SHADOWS_NEED_UV
    float2 uv : TEXCOORD0;
#endif
#if defined(SHADOWS_CUBE)
    float3 lightVec : TEXCOORD1;
#endif
};

InterpolatorsVertex MyShadowVertexProgram(VertexData v) 
{
    InterpolatorsVertex i;
#if defined(SHADOWS_CUBE)
     i.position = UnityObjectToClipPos(v.position);
     i.lightVec = mul(unity_ObjectToWorld,v.position).xyz - _LightPositionRange.xyz;
#else
     i.position = UnityClipSpaceShadowCasterPos(v.position.xyz, v.normal);
     //从模型空间到裁剪空间，并根据法线方向对顶点位置进行微小的偏移：解决“阴影痤疮”问题
     i.position = UnityApplyLinearShadowBias(i.position);//偏移(bias)
#endif    
    
#if SHADOWS_NEED_UV
    i.uv = TRANSFORM_TEX(v.uv, _MainTex);
#endif
    return i;
}

float GetAlpha(Interpolators i)
{
    float alpha = _Color.a;
#if SHADOWS_NEED_UV 
    alpha *= tex2D(_MainTex, i.uv.xy).a;
#endif
    return alpha;
}

float4 MyShadowFragmentProgram(Interpolators i) : SV_TARGET{
    float alpha = GetAlpha(i);
    #if defined(_RENDERING_CUTOUT)
        clip(alpha - _Cutoff);
    #endif
    
    #if SHADOWS_SEMITRANSPARENT
        float dither = //抖动
            tex3D(_DitherMaskLOD, float3(i.vpos.xy * 0.25, alpha * 0.9375)).a;
            //tex3D(sampler s,(u,v,w));
            //*0.25代表着屏幕上每四个像素，对应抖动图案中的1个像素；
            //0.9375=15/16，抖动图片一共16张，从0到15
        clip(dither - 0.01);
    #endif
    
#if defined(SHADOWS_CUBE)
    float depth = length(i.lightVec) + unity_LightShadowBias.x;//片元到光源的距离
    // unity_LightShadowBia 存储点光源位置和范围信息，.x 存储阴影偏移，防止‘阴影痤疮’
    depth *= _LightPositionRange.w;//归一化
    //_LightPositionRange.w 存储 点光源范围的倒数
    return UnityEncodeCubeShadowDepth(depth);
    //UnityEncodeCubeShadowDepth(),解码归一化后的深度值，存储到阴影贴图的纹理中
#else
    return 0;
#endif
}

#endif
