
Shader "Custom/My First Shader"{
	
	Properties{//着色器属性
		//命名规范是 ‘_’+ 大写首字母 + 小写
		_Tint ("Tint", Color) = (1,1,1,1)
		_MainTex ("Texture", 2D) = "white" 
	}

	SubShader{//子着色器

		Pass{//通道,子着色器至少有一个通道
			CGPROGRAM//编写着色器的开始标志

			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram
			//pragma是编译指示，通过编译指示告知编译器使用那些程序

			#include "UnityCG.cginc"//调用"UnityCG.cginc"库

			//NOTE:从上到下编译，属性和方法要有顺序

			//着色器中变量名称应与属性名一致
			float4 _Tint;
			sampler2D _MainTex;//sampler2D纹理读取器
			float4 _MainTex_ST;//ST代表缩放(Scale)和平移(Translation)

			struct Interpolators{
				float4 position : POSITION;
				float2 uv : TEXCOORD0;
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

				return i;
				
			}

			float4 MyFragmentProgram(Interpolators i) : SV_TARGET{
				//TARGET是默认的着色器目标，帧缓冲区（屏幕）
				
				return tex2D(_MainTex, i.uv) * _Tint;
			}

			ENDCG//结束标志
		}
	}
}