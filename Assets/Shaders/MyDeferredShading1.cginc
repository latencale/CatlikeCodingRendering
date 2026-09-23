#if !defined(MY_DEFERRED_SHADING)
#define MY_DEFFERED_SHADING

#include "UnityPBSLighting.cginc"

UNITY_DECLARE_DEPTH_TEXTURE(_CameraDrpthTexture);

sampler2D _CameraDepthTexture; //GBuffer
sampler2D _CameraGBufferTexture0; //Albedo + 遮罩
sampler2D _CameraGBufferTexture1; //Specular + Smoothness
sampler2D _CameraGBufferTexture2; //世界空间法线

#if defined(POINT_COOKIE)
    samplerCUBE _LightTexture0;
#else
    sampler2D _LightTexture0;
#endif

sampler2D _LightTextureB0; //光源材质
float4x4 unity_WorldToLight; //世界空间到光源空间

#if defined(SHADOWS_SCREEN)
    sampler2D _ShadowMapTexture; //阴影贴图
#endif

float4 _LightColor, _LightDir, _LightPos; //c#里传入的光源颜色和方向
float _LightAsQuad; //全屏四边形

struct VertexData
{
    float4 vertex : POSITION;
    float3 normal : NORMAL; //存储摄像机到远平面的方向向量
};

struct Interpolators
{
    float4 pos : SV_POSITION;
    float4 uv : TEXCOORD0;
    float3 ray : TEXCOORD1;
};

Interpolators VertexProgram(VertexData v)
{
    Interpolators i;
    i.pos = UnityObjectToClipPos(v.vertex);
    i.uv = ComputeScreenPos(i.pos); //在裁剪坐标获取uv
    //得到一个齐次坐标
    i.ray = lerp(UnityObjectToViewPos(v.vertex) * float3(-1, -1, 1), v.normal, _LightAsQuad);
    return i;
}

UnityLight CreateLight(float2 uv, float3 worldPos, float viewZ)
{
    UnityLight light;
    float attenuation = 1;
    float shadowAttenuation = 1;
    float shadowed = false;
    
#if defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
    light.dir = -_LightDir;
    
    #if defined(DIRECTIONAL_COOKIE) //方向光遮罩时，
        float2 uvCookie = mul(unity_WorldToLight, float4(worldPos, 1)).xy;
        attenuation *= tex2Dbias(_LightTexture0, float4(uvCookie, 0, -8)).w;
        //采样mipmap时施加一个偏移，以解决伪影
    #endif
    
    #if defined(SHADOWS_SCREEN)
        shadowed = true;
        shadowAttenuation = tex2D(_ShadowMapTexture, uv).r;
    #endif
#else
    float3 lightVec = _LightPos.xyz - worldPos;
    light.dir = normalize(lightVec);
    
    attenuation *= tex2D(_LightTextureB0,
    (dot(lightVec, lightVec) * _LightPos.w).rr).UNITY_ATTEN_CHANNEL;
    
    #if defined(SPOT)
        float4 uvCookie = mul(unity_WorldToLight, float4(worldPos, 1));
        uvCookie.xy /= uvCookie.w;
        attenuation *= tex2Dbias(_LightTexture0, float4(uvCookie.xy, 0, -8)).w;
        attenuation *= uvCookie.w < 0;
    
        #if defined(SHADOWS_DEPTH)
            shadowed  = true;
            shadowAttenuation = UnitySampleShadowmap(
                mul(unity_WorldToShadow[0], float4(worldPos, 1))
            );
        #endif
    #else
        #if defined(POINT_COOKIE)
            float3 uvCookie =
					mul(unity_WorldToLight, float4(worldPos, 1)).xyz;
				attenuation *=
					texCUBEbias(_LightTexture0, float4(uvCookie, -8)).w;
	    #endif
    
        #if defined(SHADOWS_CUBE)
            shadowed = true;
            shadowAttenuation = UnitySampleShadowmap(-lightVec);
        #endif
    #endif
#endif
    
    if (shadowed)
    {
        float shadowFadeDistance = UnityComputeShadowFadeDistance(worldPos, viewZ);
        // UnityComputeShadowFadeDistance()返回从阴影中心的距离 或 未修改的视图深度
        //阴影接近fade distance时，阴影逐渐淡化
        float shadowFade = UnityComputeShadowFade(shadowFadeDistance);
        //UnityComputeShadowFade()计算出合适的淡出系数
        shadowAttenuation = saturate(shadowAttenuation + shadowFade);
        //实现衰减效果
        
        #if defined(UNITY_FAST_COHERENT_DYNAMIC_BRANCHING) && defined(SHADOWS_SOFT)
			UNITY_BRANCH
			if (shadowFade > 0.99) {
				shadowAttenuation = 1;
			}
        #endif
    }
    
    light.color = _LightColor.rgb * (attenuation * shadowAttenuation);
    return light;
}

float4 FragmentProgram(Interpolators i) : SV_Target
{
    float2 uv = i.uv.xy / i.uv.w;
    
    float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
    depth = Linear01Depth(depth);
    
    float3 rayToFarPlane = i.ray * _ProjectionParams.z / i.ray.z;
    float3 viewPos = rayToFarPlane * depth; //观察空间的位置
    float3 worldPos = mul(unity_CameraToWorld, float4(viewPos, 1)).xyz;
    float3 viewDir = normalize(_WorldSpaceCameraPos - worldPos);   
    
    float3 albedo = tex2D(_CameraGBufferTexture0, uv).rgb;
    float3 specularTint = tex2D(_CameraGBufferTexture1, uv).rgb;
    float3 smoothness = tex2D(_CameraGBufferTexture1, uv).a;
    float3 normal = tex2D(_CameraGBufferTexture2, uv).rgb * 2 - 1;
    float oneMinusReflectivity = 1 - SpecularStrength(specularTint);
    
    UnityLight light = CreateLight(uv, worldPos, viewPos.z);
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;
    
    float4 color = UNITY_BRDF_PBS(
        albedo, specularTint, oneMinusReflectivity, smoothness,
        normal, viewDir, light, indirectLight
    );
#if !defined(UNITY_HDR_ON)//解决LDR的颜色不正确问题
    color = exp2(-color);
#endif   
    
    return color;
}

#endif