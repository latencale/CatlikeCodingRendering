
Shader "Custom/Texture With Detail"{
	
	Properties{
		_Tint ("Tint", Color) = (1,1,1,1)
		_MainTex ("Texture", 2D) = "white" 
		_DetailTex ("Detail Texture", 2D) = "gray"{}
	}

	SubShader{

		Pass{
			CGPROGRAM

			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram

			#include "UnityCG.cginc"

			float4 _Tint;
			sampler2D _MainTex, _DetailTex;//sampler2D纹理读取器
			float4 _MainTex_ST, _DetailTex_ST;//ST代表缩放(Scale)和平移(Translation)

			struct Interpolators{
				float4 position : POSITION;
				float2 uv : TEXCOORD0;
				float2 uvDetail : TEXCOORD1;
			};

			struct VertexData{
				float4 position : POSITION;
				float2 uv : TEXCOORD0;
			};

			Interpolators MyVertexProgram(VertexData v){
				
				Interpolators i;
				i.position = UnityObjectToClipPos(v.position);
				// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
				//模型空间转换到裁剪空间
				i.uv = TRANSFORM_TEX(v.uv, _MainTex);
				i.uvDetail = TRANSFORM_TEX(v.uv, _DetailTex	);
				//使用宏简写，i.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
				
				return i;
				
			}

			float4 MyFragmentProgram(Interpolators i) : SV_TARGET{
				//TARGET是默认的着色器目标，帧缓冲区（屏幕）
				
				float4 color = tex2D(_MainTex, i.uv) * _Tint;
				color *= tex2D(_DetailTex, i.uvDetail) * unity_ColorSpaceDouble;
				//unity_ColorSpaceDouble在不同颜色空间(伽马空间和线性空间)，都能得到正确得到颜色混合结果
				return color;
			}

			ENDCG
		}
	}
}