#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"


float4 _Tint;
sampler2D _MainTex, _DetailTex, _DetailMask; //sampler2D纹理读取器
float4 _MainTex_ST, _DetailTex_ST; //ST代表缩放(Scale)和平移(Translation)

sampler2D _MetallicMap; //金属度贴图
float _Metallic;
float _Smoothness;

sampler2D _NormalMap, _DetailNormalMap; //法线贴图
float _BumpScale, _DetailBumpScale;//凹凸

sampler2D _EmissionMap; //自发光贴图
float3 _Emission; //自发光颜色

sampler2D _OcclusionMap; //遮挡贴图
float _OcclusionStrength; //遮挡强度

float _AlphaCutoff; //透明度裁剪阈值

struct Interpolators
{
    float4 pos : POSITION;
    float4 uv : TEXCOORD0; //主uv 和 细节uv
    float3 normal : TEXCOORD1; //第二套纹理
    
#if defined(BINORMAL_PER_FRAGMENT)//在片元着色器进行运算
    float4 tangent : TEXCOORD2;//切线空间
#else//在顶点着色器进行运算，与Unity标准着色器一致
    float3 tangent : TEXCOORD2;
    float3 binormal : TEXCOORD3;
#endif
    float3 worldPos : TEXCOORD4;
				//SV代表系统值，POSITION代表顶点位置,TEXCOORD代表纹理坐标
    
    SHADOW_COORDS(5)
    //用于存储阴影贴图采样坐标的成员变量，5为编号，即float4 _ShadowCoord : TEXCOORD5;
    
    #if defined(VERTEXLIGHT_ON)
        float3 vertexLightColor : TEXCOORD6; //顶点光照颜色
    #endif
};

struct VertexData
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
};

struct FragmentOutput
{
#if defined(DEFERRED_PASS)
    float4 gBuffer0 : SV_Target0;
    float4 gBuffer1 : SV_Target1;
    float4 gBuffer2 : SV_Target2;
    float4 gBuffer3 : SV_Target3;
#else
    float4 color : SV_Target;
#endif
};

//四个顶点光源
void ComputeVertexLightColor(inout Interpolators i)
{
#if defined(VERTEXLIGHT_ON)
/*    float3 lightPos = float3(
        unity_4LightPosX0.x, unity_4LightPosY0.x, unity_4LightPosZ0.x
    );//第一个光源的坐标
    float3 lightVec = lightPos - i.worldPos;
    float3 lightDir = normalize(lightVec);
    float ndotl = DotClamped(i.normal, lightDir);
    float attenuation = 1 / (1 + dot(lightVec, lightVec) * unity_4LightAtten0.x);//衰减
    //在VERTEXLIGHT_ON定义后，有前四个非重要的光源的位置untiy_4LightPosX0,Y0,Z0，颜色unity_LightColor[4]，衰减unity_4LightAtten0
    i.vertexLightColor = unity_LightColor[0].rgb * ndotl * attenuation;
*/
    i.vertexLightColor = Shade4PointLights(
        unity_4LightPosX0,unity_4LightPosY0, unity_4LightPosZ0,//位置
		unity_LightColor[0].rgb, unity_LightColor[1].rgb,
		unity_LightColor[2].rgb, unity_LightColor[3].rgb,//灯光颜色
		unity_4LightAtten0, i.worldPos, i.normal//衰减系数，顶点位置，顶点法线
);
#endif
}

//创造复法线
float3 CreateBinormal(float3 normal, float3 tangent, float binormalSign)
{
    return cross(normal, tangent.xyz) *
        (binormalSign * unity_WorldTransformParams.w);
        //i.tangent.w在模型被镜像时是-1， unity_WorldTransformParams.w在世界空间被镜像时是-1

}

Interpolators MyVertexProgram(VertexData v)
{
    Interpolators i;
    i.pos = UnityObjectToClipPos(v.vertex);
				// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
				//模型空间转换到裁剪空间
    i.worldPos = mul(unity_ObjectToWorld, v.vertex);
    i.normal = UnityObjectToWorldNormal(v.normal);
				//i.normal = mul(transpose((float3x3)unity_WorldToObject), v.normal);
				//mul(A,B)矩阵乘法,unity_ObjectToWorld模型空间转换到世界空间,unity_WorldToObject世界空间转换到模型空间

#if defined(BINORMAL_PER_FRAGMENT)
    i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
#else
    i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
    i.binormal = CreateBinormal(i.normal, i.tangent, v.tangent.w);
#endif

    i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				//使用宏简写，i.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
    i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);

    TRANSFER_SHADOW(i);
    //计算阴影贴图的采样坐标，并将结果存储到传递结构体 i 的 _ShadowCoord 成员中。
    
    ComputeVertexLightColor(i);
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
#if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
    #if defined(_EMISSION_MAP)
        return tex2D(_EmissionMap, i.uv.xy) * _Emission;
    #else
        return _Emission;
    #endif
#else
    return 0;
#endif
}

float GetOcclusion(Interpolators i)
{
#if defined(_OCCLUSION_MAP)
    return lerp(1, tex2D(_OcclusionMap,i.uv.xy).g, _OcclusionStrength);
#else
    return 1;
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
    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb; //反照率：物体的颜色
#if defined(_DETAIL_ALBEDO_MAP)
    float3 details = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;; //细节贴图
    albedo = lerp(albedo, albedo * details, GetDetailMask(i));
#endif
    return albedo;
}

float3 GetTangentSpaceNormal(Interpolators i)
{
    float3 normal = float3(0, 0, 1);
    
#if defined(_NORMAL_MAP)
    normal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
#endif   
    
#if defined(_DETAIL_NORMAL_MAP)
    float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
    //从法线贴图中获取法线向量，并将其从纹理空间转换为切线空间
    detailNormal = lerp(float3(0, 0, 1), detailNormal, GetDetailMask(i));
    normal =BlendNormals(normal, detailNormal);
#endif
    return normal;
}

float GetAlpha(Interpolators i)
{
    float alpha = _Tint.a;
#if !defined(_SMOOTHNESS_ALBEDO) //仅当不使用纹理的A通道判断平滑度时使用纹理
    alpha *= tex2D(_MainTex, i.uv.xy).a;    
#endif
    return alpha;
}   

//创造直接光
UnityLight CreateLight(inout Interpolators i)
{
    UnityLight light;
    
#if defined(DEFERRED_PASS)
    light.dir = float3(0, 1, 0);
    light.color = 0;
#else  
    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT) 
            light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos); //环境光的方向
        #else   
            light.dir = _WorldSpaceLightPos0.xyz;
        #endif
    
        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
        //插入计算正确衰减因子的代码，（变量名，包含阴影的插值器，世界坐标位置）
            //该宏会自定义该变量
    
        light.color = _LightColor0.rgb * attenuation; //光的颜色
#endif
    
    return light;
}

//盒体投影
float3 BoxProjection(float3 direction, float3 position, float4 cubemapPosition, float3 boxMin, float3 boxMax)
{                   //反射方向、采样位置、立方体贴图中心位置、盒子边界
#if UNITY_SPECCUBE_BOX_PROJECTION    
    UNITY_BRANCH //使用分支
    if (cubemapPosition.w > 0)
    {
        float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
        //世界空间中的盒子边界，转换为以当前采样点position为原点的局部空间坐标
        float scalar = min(min(factors.x, factors.y), factors.z); //到达盒子的时间，由最先被撞到的面决定
        direction = direction * scalar + (position - cubemapPosition); //立方体贴图中心到盒子边界的向量
    }
#endif
    return direction;
}

//创造间接光
UnityIndirect CreateIndirectLight(Interpolators i, float3 viewDir)
{
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;
    
#if defined(VERTEXTLIGHT_ON)
    indirectLight.diffuse = i.vertexLightColor;
#endif
    
#if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
    indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
     //ShadeSH9于计算 9 阶球谐函数（第 0 到第 2 阶）的环境光照
     float3 reflectionDir = reflect(-viewDir, i.normal);  
    
    /*
    float roughness = 1 - _Smoothness;
    roughness *= 1.7 - 0.7 * roughness;//粗糙度与mipmap的关系函数：1.7 * r - 0.7 * r^2
    float4 envSample = UNITY_SAMPLE_TEXCUBE_LOD(
        unity_SpecCube0, reflectionDir, roughness * UNITY_SPECCUBE_LOD_STEPS
    );//环境采样,光滑度越低，mipmap较高，生成更模糊的图像。
    //UNTIY_SPECCUBE_LOD_STEPS用于表示反射模糊程度的立方体贴图（Cubemap）的 Mipmap 层级数量
    indirectLight.specular = DecodeHDR(envSample, unity_SpecCube0_HDR);
    //将采样从HDR格式转化为RGB，使用DecodeHDR函数
    */
    
    Unity_GlossyEnvironmentData envData;//已过时
    envData.roughness = 1 - GetSmoothness(i);
    envData.reflUVW = BoxProjection(reflectionDir, i.worldPos, 
        unity_SpecCube0_ProbePosition, 
        unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
    );
    float3 probe0 = Unity_GlossyEnvironment(//旧版的环境镜面反射采样函数
        UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
    );//宏，将反射探针数据传给函数，与反射探针关联给HDR解码数据，环境数据
    envData.reflUVW = BoxProjection(reflectionDir, i.worldPos,
        unity_SpecCube1_ProbePosition,
        unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax
    );
    
    #if UNITY_SPECCUBE_BLENDING
        float interpolator = unity_SpecCube0_BoxMin.w;
        UNITY_BRANCH
        if(interpolator < 0.99999){
            float3 probe1 = Unity_GlossyEnvironment(
                UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0), unity_SpecCube1_HDR,envData
            );
            //UNITY_PASS_TEXCUBE_SAMPLER()传递第二个反射探针的立方体贴图纹理和采样器,1是第二个探针的纹理数据，0是采样器
            indirectLight.specular = lerp(probe1, probe0, unity_SpecCube0_BoxMin.w);
        }
        else //之在第0个盒子里
            indirectLight.specular = probe0;
    #else
        indirectLight = probe0;
    #endif
    
    float occlusion = GetOcclusion(i);
    indirectLight.diffuse *= occlusion;
    indirectLight.specular *= occlusion;
    //环境光遮蔽（AO）
    
    #if defined(DEFERRED_PASS) && UNITY_ENABLE_REFLECTION_BUFFERS
        indirectLight.specular = 0;
    #endif
#endif
    
    return indirectLight;
}

//初始化片元法线:从法线贴图采样的搭配切线空间法线，转化到世界空间法线
void IntializeFragmentNormal(inout Interpolators i)
{
    float3 tangentSpaceNormal = GetTangentSpaceNormal(i);
    
#if defined(BINORMAL_PER_FRAGMENT)
    float3 binormal = CreateBinormal(i.normal,i.tangent.xyz,i.tangent.w);
#else
    float3 binormal = i.binormal;
#endif
    
    i.normal = normalize(
        tangentSpaceNormal.x * i.tangent + 
        tangentSpaceNormal.y * binormal +
        tangentSpaceNormal.z * i.normal
    );
}

FragmentOutput MyFragmentProgram(Interpolators i) : SV_TARGET
{				
    float alpha = GetAlpha(i);
#if defined(_RENDERING_CUTOUT)//只在裁剪渲染时使用，完全不透明则不使用
    clip(alpha - _AlphaCutoff); //裁剪掉透明度小于_alphaCutoff的片元
    //clip函数用于丢弃片元，如果alpha小于_alphaCutoff，则丢弃该片元，避免渲染透明部分
#endif
    
    IntializeFragmentNormal(i);
    
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos); //我的视角
				//_WorldSpaceCameraPos代表相机的位置

    float3 specularTint; //镜面反射颜色
    float oneMinusReflectivity;
    float3 albedo = DiffuseAndSpecularFromMetallic(
					GetAlbedo(i), GetMetallic(i), specularTint, oneMinusReflectivity
				);
    //预乘Alpha：先光照再预乘，高光和环境光会错误的乘Alpha，使颜色失真
#if defined(_RENDERING_TRANSPARENT)
    albedo *= alpha; //使透明度生效
    alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
#endif
    
    //光照计算：漫反射+镜面反射+自发光
    float4 color = UNITY_BRDF_PBS(albedo, specularTint,
					oneMinusReflectivity, GetSmoothness(i),
					i.normal, viewDir,
					CreateLight(i), CreateIndirectLight(i, viewDir));
    color.rgb += GetEmission(i);
    //将透明度写入，设置透明
#if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
    color.a = alpha; 
#endif
    
    FragmentOutput output;
#if defined(DEFERRED_PASS)
    #if !defined(UNITY_HDR_ON)
        color.rgb = exp2(-color.rgb); //自发光
    #endif
    output.gBuffer0.rgb = albedo; //漫反射
    output.gBuffer0.a = GetOcclusion(i); //表面遮挡
    output.gBuffer1.rgb = specularTint; //高光
    output.gBuffer1.a = GetSmoothness(i); //平滑度
    output.gBuffer2 = float4(i.normal * 0.5 + 0.5, 1); //法线
    output.gBuffer3= color;
#else
    output.color = color;
#endif
    return output;
}

#endif