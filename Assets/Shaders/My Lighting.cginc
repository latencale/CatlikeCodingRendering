#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED

#include "AutoLight.cginc"
#include "UnityPBSLighting.cginc"

float4 _Tint;
sampler2D _MainTex, _DetailTex; //sampler2D纹理读取器
float4 _MainTex_ST, _DetailTex_ST; //ST代表缩放(Scale)和平移(Translation)
float _Metallic;
float _Smoothness;
sampler2D _NormalMap, _DetailNormalMap; //法线贴图
float _BumpScale, _DetailBumpScale;

struct Interpolators
{
    float4 position : POSITION;
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
    
    #if defined(VERTEXLIGHT_ON)
        float3 vertexLightColor : TEXCOORD5; //
    #endif
};
			//NOTE:可以定义数据结构

struct VertexData
{
    float4 position : POSITION;
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

float3 CreateBinormal(float3 normal, float3 tangent, float binormalSign)
{
    return cross(normal, tangent.xyz) *
        (binormalSign * unity_WorldTransformParams.w);
        //i.tangent.w在模型被镜像时是-1， unity_WorldTransformParams.w在世界空间被镜像时是-1

}

Interpolators MyVertexProgram(VertexData v)
{
    Interpolators i;
    i.position = UnityObjectToClipPos(v.position);
				// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
				//模型空间转换到裁剪空间
    i.worldPos = mul(unity_ObjectToWorld, v.position);
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
        ComputeVertexLightColor(i);
    return i;
				
}

UnityLight CreateLight(inout Interpolators i)
{
    UnityLight light;
    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT) 
        light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos); //环境光的方向
    #else   
        light.dir = _WorldSpaceLightPos0.xyz;
    #endif
    
    UNITY_LIGHT_ATTENUATION(attenuation, 0, i.worldPos);
    //插入计算正确衰减因子的代码，（变量名，与阴影有关，世界坐标位置）
        //该宏会自定义该变量
    light.color = _LightColor0.rgb * attenuation; //光的颜色
    light.ndotl = DotClamped(i.normal, light.dir);//法线与光线方向的点积
    return light;
}

UnityIndirect CreateIndirectLight(Interpolators i)
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
					CreateLight(i), CreateIndirectLight(i));
}

#endif