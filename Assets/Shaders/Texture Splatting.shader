
Shader "Custom/Texcture Splatting"{
	
	Properties{
		_MainTex ("Splat Map", 2D) = "white" 
		[NoScaleOffset] _Texture1 ("Texture 1",2D) = "white"
		[NoScaleOffset] _Texture2 ("Texture 2",2D) = "white"
		[NoScaleOffset] _Texture3 ("Texture 3",2D) = "white"
		[NoScaleOffset] _Texture4 ("Texture 4",2D) = "white"
		//[NoScaleOffset] 隐藏平铺(Tiling)和偏移(Offset)
	}

	SubShader{

		Pass{
			CGPROGRAM

			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram

			#include "UnityCG.cginc"

			sampler2D _MainTex;//sampler2D纹理读取器
			float4 _MainTex_ST;//ST代表缩放(Scale)和平移(Translation)
			sampler2D _Texture1, _Texture2, _Texture3, _Texture4;

			struct Interpolators{
				float4 position : POSITION;
				float2 uv : TEXCOORD0;
				float2 uvSplat : TEXCOORD1;
				//SV代表系统值，POSITION代表顶点位置,TEXCOORD0代表纹理坐标
			};
			//NOTE:可以定义数据结构

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
				//使用宏简写，i.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
				i.uvSplat = v.uv;
				return i;
				
			}

			float4 MyFragmentProgram(Interpolators i) : SV_TARGET{
				//TARGET是默认的着色器目标，帧缓冲区（屏幕）
				float4 splat = tex2D(_MainTex, i.uvSplat);

				return tex2D(_Texture1, i.uv) * splat.r +
					tex2D(_Texture2, i.uv) * splat.g +
					tex2D(_Texture3, i.uv) * splat.b +
					tex2D(_Texture4, i.uv) * (1 - splat.r - splat.g - splat.b); 
					//RGBA.当然也可以用Alpha通道
			}

			ENDCG//结束标志
		}
	}
}