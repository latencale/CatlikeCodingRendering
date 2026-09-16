
Shader "Custom/Physically-Based Shading"{
	
	Properties{
		_Tint ("Tint", Color) = (1,1,1,1) //颜色
		_MainTex ("Albedo", 2D) = "white" {} //主纹理
		
		[NoScaleOffset] _NormalMap ("Normals", 2D) = "bump"{} //法线贴图
		//[NoScaleOffset]特性：隐藏平铺tiling和偏移offset
		_BumpScale ("Bump Scale", Float) = 1 //法线贴图的强度
		
		[NoScaleOffset] _MetallicMap("Metallic", 2D) = "white" {} //金属度贴图
		[Gamma] _Metallic ("Metallic", Range(0,1)) = 0 //金属度
		_Smoothness ("Smoothness", Range(0, 1)) = 0.5 //高光的平滑度
		[HideInSpector] _SmoothnessSource ("Smoothness Source", Float) = 0 //高光平滑度来源，0=从金属度贴图获取，1=从Albedo贴图的Alpha通道获取

		_DetailTex ("Detail Albedo", 2D) = "gray" {} //细节纹理
		[NoScaleOffset] _DetailNormalMap ("Detail Normals", 2D) = "bump"{} //细节法线贴图
		_DetailBumpScale ("Detail Bump Scale",Float) = 1 //细节法线贴图强度
	
		[NoScaleOffset] _EmissionMap ("Emission", 2D) = "black" {} //自发光贴图
		_Emission ("Emission", Color) = (0,0,0) //自发光强度

		[NoScaleOffset] _OcclusionMap ("Occlusion", 2D) = "white" {} //遮挡贴图
		_OcclusionStrength ("Occlusion Strength", Range(0,1)) = 1 //遮挡强度
	
		[NoScaleOffset] _DetailMask ("Detail Mask", 2D) = "white" {} //细节遮罩贴图

		_AlphaCutoff ("Alpha Cutoff",Range(0,1)) = 0.5 //透明度裁剪阈值
	
		[HideInInspector] _SrcBlend ("_SrcBlend", Float) = 1 //源颜色融合因子
		[HideInInspector] _DstBlend ("_DstBlend", Float) = 0 //目标颜色融合因子
		[HideInInspector] _ZWrite ("_ZWrite", Float) = 1 //深度写入
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

			Blend [_SrcBlend] [_DstBlend]
			//最终颜色 = 源颜色 * SrcAlpha + 目标颜色 * OneMinusSrcAlpha(即1 - SrcAlpha)

			CGPROGRAM 

			#pragma target 3.0

			#pragma multi_compile _ SHADOWS_SCREEN //屏幕空间阴影：将阴影贴图投射并转换到屏幕空间，生成一张屏幕空间的阴影纹理
			#pragma multi_compile _ VERTEXLIGHT_ON //顶点光照：4个
			//生成两个着色器变体(Shader Variants)，‘_’ 是占位符，表示不定义任何关键字的变体，即关闭
			
			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT//透明度裁剪 透明度渐隐 透明度
			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC //高光平滑度来源
			#pragma shader_feature _NORMAL_MAP//法线贴图
			#pragma shader_feature _EMISSION_MAP //自发光贴图
			#pragma shader_feature _OCCLUSION_MAP//遮挡贴图
			#pragma shader_feature _DETAIL_MASK //细节遮罩贴图
			#pragma shader_feature _DETAIL_ALBEDO_MAP //细节纹理
			#pragma shader_feature _DETAIL_NORMAL_MAP //细节法线贴图


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

			Blend [_SrcBlend] One // 启用叠加混合模式，必须用
			//语法：Blend [SourceFactor] [DestinationFactor]
			//One 表示因子=1
			ZWrite [_ZWrite] //根据_ZWrite的数值开关z-buffer

			CGPROGRAM 

			#pragma target 3.0
			
			#pragma multi_compile_fwdadd_fullshadows
			// _fwdadd: DIRECTIONAL DIRECTIONAL_COOKIE  POINT POINT_COOKIE SPOT
			// _fullshadows:生成带阴影的额外光源变体
			//为当前Pass生成多个Shader Variants,
			//DIRECTIONAL方向光，POINT点光源,SPOT聚光灯，COOKIE遮罩，
			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC 
			#pragma shader_feature _NORMAL_MAP
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _DETAIL_ALBEDO_MAP
			#pragma shader_feature _DETAIL_NORMAL_MAP

			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram

			#include "My Lighting.cginc"

			
			ENDCG
		}

		Pass{
			Tags{
				"LightMode" = "Deferred"	
			}

			CGPROGRAM 

			#pragma target 3.0
			#pragma exclude_renderers nomrt //不支持多个渲染目标时，排除
			
			#pragma shader_feature _ _RENDERING_CUTOUT
			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC 
			#pragma shader_feature _NORMAL_MAP
			#pragma shader_feature _EMISSION_MAP 
			#pragma shader_feature _OCCLUSION_MAP
			#pragma shader_feature _DETAIL_MASK 
			#pragma shader_feature _DETAIL_ALBEDO_MAP 
			#pragma shader_feature _DETAIL_NORMAL_MAP 

			#pragma multi_compile _ UNITY_HDR_ON

			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram

			#define DEFERRED_PASS

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

			#pragma shader_feature _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
			#pragma shader_feature _SMOOTHNESS_ALBEDO	
			#pragma shader_feature _SEMITRANSPARENT_SHADOWS

			#pragma vertex MyShadowVertexProgram
			#pragma fragment MyShadowFragmentProgram

			#include "My Shadows.cginc"

			ENDCG
		}
	}
	CustomEditor "MyLightingShaderGUI"
}