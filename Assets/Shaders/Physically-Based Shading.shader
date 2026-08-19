
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

			#pragma multi_compile _ VERTEXLIGHT_ON

			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram

			#define FORWARD_BASE_PASS

			#include "My Lighting.cginc"

			
			ENDCG
		}

		Pass{
			Tags{
				"LightMode" = "ForwardAdd"	//额外光源			
			}

			Blend One One // 启用叠加混合模式
			//语法：Blend [SourceFactor] [DestinationFactor]
			//One 表示因子=1
			ZWrite Off//关闭Z-Buffer

			CGPROGRAM 

			#pragma target 3.0
			
			#pragma multi_compile_fwdadd
			//#pragma multi_compile DIRECTIONAL DIRECTIONAL_COOKIE  POINT POINT_COOKIE SPOT
			//为当前Pass生成多个Shader Variants,
			//DIRECTIONAL方向光，POINT点光源,SPOT聚光灯，COOKIE遮罩，

			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram

			#include "My Lighting.cginc"

			
			ENDCG
		}
	}
}