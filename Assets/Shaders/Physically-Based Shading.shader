
Shader "Custom/Physically-Based Shading"{
	
	Properties{
		_Tint ("Tint", Color) = (1,1,1,1) //颜色
		_MainTex ("Albedo", 2D) = "white" {} //主纹理
		[NoScaleOffset] _NormalMap ("Normals", 2D) = "bump"{} //法线贴图
		//[NoScaleOffset]特性：隐藏平铺tiling和偏移offset
		_BumpScale ("Bump Scale", Float) = 1 //法线贴图的强度
		[Gamma] _Metallic ("Metallic", Range(0,1)) = 0 //金属度
		_Smoothness ("Smoothness", Range(0, 1)) = 0.5 //高光的平滑度
		_DetailTex ("Detail Texture", 2D) = "gray" {} //细节纹理
		[NoScaleOffset] _DetailNormalMap ("Detail Normals", 2D) = "bump"{} //细节法线贴图
		_DetailBumpScale ("Detail Bump Scale",Float) = 1 //细节法线贴图强度
	}

	CGINCLUDE

	#define BINORMAL_PER_FRAGMENT

	ENDCG

	SubShader{

		Pass{
			Tags{//渲染控制：定义渲染队列、光照模式等关键行为
				"LightMode" = "ForwardBase"			
				//渲染主光源（最亮的方向光） 和 所有环境光/间接光
			}


			CGPROGRAM 

			#pragma target 3.0

			#pragma multi_compile _ SHADOWS_SCREEN //屏幕空间阴影：将阴影贴图投射并转换到屏幕空间，生成一张屏幕空间的阴影纹理
			#pragma multi_compile _ VERTEXLIGHT_ON //顶点光照：4个
			//生成两个着色器变体(Shader Variants)，‘_’ 是占位符，表示不定义任何关键字的变体，即关闭某

			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram

			#define FORWARD_BASE_PASS

			#include "My Lighting.cginc"

			
			ENDCG
		}

		Pass{
			Tags{
				"LightMode" = "ForwardAdd"	
				//渲染额外光源（如点光源，聚光灯 等）			
			}

			Blend One One // 启用叠加混合模式，必须用
			//语法：Blend [SourceFactor] [DestinationFactor]
			//One 表示因子=1
			ZWrite Off//关闭Z-Buffer

			CGPROGRAM 

			#pragma target 3.0
			
			#pragma multi_compile_fwdadd_fullshadows
			// _fwdadd: DIRECTIONAL DIRECTIONAL_COOKIE  POINT POINT_COOKIE SPOT
			// _fullshadows:生成带阴影的额外光源变体
			//为当前Pass生成多个Shader Variants,
			//DIRECTIONAL方向光，POINT点光源,SPOT聚光灯，COOKIE遮罩，

			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram

			#include "My Lighting.cginc"

			
			ENDCG
		}

		Pass{
			Tags{
				"LightMode" = "ShadowCaster"
				//专门渲染阴影贴图
			}

			CGPROGRAM

			#pragma target 3.0

			#pragma multi_compile_shadowcaster
			//添加两个关键字及对应的着色器变体：SHADOWS_DEPTH 和 SHADOWS_CUBE
			//由于 点光源(立方体贴图) 和 方向光/聚光灯(深度贴图) 在着色器代码有差异

			#pragma vertex MyShadowVertexProgram
			#pragma fragment MyShadowFragmentProgram

			#include "My Shadows.cginc"

			ENDCG
		}
	}
}