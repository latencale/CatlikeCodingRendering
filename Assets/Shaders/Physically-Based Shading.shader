
Shader "Custom/Physically-Based Shading"{
	
	Properties{
		_Tint ("Tint", Color) = (1,1,1,1) //颜色
		_MainTex ("Albedo", 2D) = "white" {} //主纹理
		[Gamma] _Metallic ("Metallic", Range(0,1)) = 0 //金属度
		_Smoothness ("Smoothness", Range(0, 1)) = 0.5 //高光的平滑度
	}

	SubShader{

		Pass{
			Tags{//渲染控制：定义渲染队列、光照模式等关键行为
				"LightMode" = "ForwardBase"				
			}

			CGPROGRAM

			#pragma target 3.0

			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram

			#include "UnityPBSLighting.cginc"

			float4 _Tint;
			sampler2D _MainTex;//sampler2D纹理读取器
			float4 _MainTex_ST;//ST代表缩放(Scale)和平移(Translation)
			float _Metallic;
			float _Smoothness;

			struct Interpolators{
				float4 position : POSITION;
				float2 uv : TEXCOORD0;//主纹理
				float3 normal : TEXCOORD1;//第二套纹理
				float3 worldPos : TEXCOORD2;
				//SV代表系统值，POSITION代表顶点位置,TEXCOORD代表纹理坐标
			};
			//NOTE:可以定义数据结构

			struct VertexData{
				float4 position : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			Interpolators MyVertexProgram(VertexData v){
				Interpolators i;
				i.position = UnityObjectToClipPos(v.position);
				// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
				//模型空间转换到裁剪空间
				i.worldPos = mul(unity_ObjectToWorld,v.position);
				i.uv = TRANSFORM_TEX(v.uv, _MainTex);
				//使用宏简写，i.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
				i.normal = UnityObjectToWorldNormal(v.normal);
				//i.normal = mul(transpose((float3x3)unity_WorldToObject), v.normal);
				//mul(A,B)矩阵乘法,unity_ObjectToWorld模型空间转换到世界空间,unity_WorldToObject世界空间转换到模型空间
				return i;
				
			}

			float4 MyFragmentProgram(Interpolators i) : SV_TARGET{
				//TARGET是默认的着色器目标，帧缓冲区（屏幕）
				
				i.normal = normalize(i.normal);//在不同单位长度行向量之间进行线性插值，会更短
				float3 lightDir = _WorldSpaceLightPos0.xyz;//环境光的方向
				//_WorldSpaceLightPos0代表光源的位置
				float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);//我的视角
				//_WorldSpaceCameraPos代表相机的位置
				float3 lightColor = _LightColor0.rgb;//光的颜色
				//_LightColor0代表光的颜色
				float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;//反照率：物体的颜色
				float3 specularTint ;//镜面反射颜色
				float oneMinusReflectivity ;
				albedo = DiffuseAndSpecularFromMetallic(
					albedo, _Metallic, specularTint, oneMinusReflectivity
				);
				
				UnityLight light;
				light.color = lightColor;
				light.dir = lightDir;
				light.ndotl = DotClamped(i.normal, lightDir);
				UnityIndirect indirectLight;
				indirectLight.diffuse = 0;
				indirectLight.specular = 0;

				return UNITY_BRDF_PBS(albedo, specularTint,
					oneMinusReflectivity, _Smoothness,
					i.normal, viewDir,
					light, indirectLight); 
			}

			ENDCG//结束标志
		}
	}
}