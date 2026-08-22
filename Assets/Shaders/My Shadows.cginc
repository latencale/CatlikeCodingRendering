
#if !defined(MY_SHADOWS_INCLUDED)
#define MY_SHADOWS_INCLUDED

#include "UnityCG.cginc"

struct VertexData
{
    float4 position : POSITION;
    float3 normal : NORMAL;
};

#if defined(SHADOWS_CUBE)
    struct Interpolators{
        float4 pos : SV_POSITION;
        float3 lightVec : TEXCOORD0;
    };

    Interpolators MyShadowVertexProgram(VertexData v){
        Interpolators i;
        i.pos = UnityObjectToClipPos(v.position);
        i.lightVec = mul(unity_ObjectToWorld, v.position).xyz - _LightPositionRange.xyz;
        return i;
    }

    float4 MyShadowFragmentProgram(Interpolators i) : SV_TARGET{
        float depth = length(i.lightVec) + unity_LightShadowBias.x;//片元到光源的距离
        // unity_LightShadowBia 存储点光源位置和范围信息，.x 存储阴影偏移，防止‘阴影痤疮’
        depth *= _LightPositionRange.w;//归一化
        //_LightPositionRange.w 存储 点光源范围的倒数
        return UnityEncodeCubeShadowDepth(depth);
        //UnityEncodeCubeShadowDepth(),解码归一化后的深度值，存储到阴影贴图的纹理中
    }
#else
    float4 MyShadowVertexProgram(VertexData v) : SV_POSITION
    {
        float4 position = UnityClipSpaceShadowCasterPos(v.position.xyz, v.normal);
        //从模型空间到裁剪空间，并根据法线方向对顶点位置进行微小的偏移：解决“阴影痤疮”问题
        return UnityApplyLinearShadowBias(position);//偏移(bias)
    }

    half4 MyShadowFragmentProgram() : SV_TARGET
    {
        return 0;
    }
#endif

#endif