#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"


float4 _Tint;
sampler2D _MainTex, _DetailTex; //sampler2D纹理读取器
float4 _MainTex_ST, _DetailTex_ST; //ST代表缩放(Scale)和平移(Translation)
float _Metallic;
float _Smoothness;
sampler2D _NormalMap, _DetailNormalMap; //法线贴图
float _BumpScale, _DetailBumpScale;

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
			//NOTE:可以定义数据结构

struct VertexData
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    float2 uv : TEXCOORD0;
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

//创造直接光
UnityLight CreateLight(inout Interpolators i)
{
    UnityLight light;
    
    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT) 
        light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos); //环境光的方向
    #else   
        light.dir = _WorldSpaceLightPos0.xyz;
    #endif
    
    UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
    //插入计算正确衰减因子的代码，（变量名，包含阴影的插值器，世界坐标位置）
        //该宏会自定义该变量
    
    light.color = _LightColor0.rgb * attenuation; //光的颜色
    light.ndotl = DotClamped(i.normal, light.dir);//法线与光线方向的点积
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
        float scalar = min(min(factors.x, factors.y), factors.z); //道道盒子的时间，由最先被撞到的面决定
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
    
#if defined(FORWARD_BASE_PASS)
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
    envData.roughness = 1 - _Smoothness;
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
    else{ //之在第0个盒子里
        indirectLight.specular = probe0;
#else
    indirectLight = probe0;
#endif
    
}
#endif
    
    return indirectLight;
}

void IntializeFragmentNormal(inout Interpolators i)
{
    float3 mainNormal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy),_BumpScale);
    float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
    //i.normal.xy = tex2D(_NormalMap, i.uv).wy * 2 - 1;
    //i.normal.xy *= _BumpScale;
    //i.normal.z = sqrt(1 - saturate(dot(i.normal.xy, i.normal.xy)));
    //法线贴图纹理用DXT5nm，而非RGB。DXT5nm仅存储法线的x,y分量
    
    float3 tangentSpaceNormal = BlendNormals(mainNormal, detailNormal);
    //i.normal = float3(mainNormal.xy + detailNormal.xy, mainNormal.z * detailNormal.z);//白化混合
    //i.normal = float3(mainNormal.xy / mainNormal.z + detailNormal.xy / detailNormal.z,1);
    
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

float4 MyFragmentProgram(Interpolators i) : SV_TARGET
{				
    IntializeFragmentNormal(i);
    
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos); //我的视角
				//_WorldSpaceCameraPos代表相机的位置
    float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb; //反照率：物体的颜色
    albedo *= tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
    float3 specularTint; //镜面反射颜色
    float oneMinusReflectivity;
    albedo = DiffuseAndSpecularFromMetallic(
					albedo, _Metallic, specularTint, oneMinusReflectivity
				);
    
    return UNITY_BRDF_PBS(albedo, specularTint,
					oneMinusReflectivity, _Smoothness,
					i.normal, viewDir,
					CreateLight(i), CreateIndirectLight(i, viewDir));
}

#endif