Shader "Custom/DeferredShading1" {
	
	Properties {
	}

	SubShader {

		//渲染灯光
		Pass {
			Blend [_SrcBlend] [_DstBlend] 
			ZWrite Off
			
			CGPROGRAM

			#pragma target 3.0
			#pragma vertex VertexProgram
			#pragma fragment FragmentProgram
			
			#pragma exclude_renderers nomrt

			#pragma multi_compile_lightpass //所有可能的光照配置
			#pragma multi_compile _ UNITY_HDR_ON

			#include "MyDeferredShading1.cginc"
			
			ENDCG
		}

		//渲染物体
		Pass {
			Cull Off
			ZTest Always
			ZWrite Off
			
			Stencil{ //(模板)配置 ： 控制像素被绘制/丢弃
				Ref [_StencilNonBackground] //参考值，与模板缓冲区的值进行比较
				ReadMask [_StencilNonBackground] //读取掩码[_StencilNonBackground]
				CompBack Equal //背面比较：相等才通过
				CompFront Equal //正面比较：相等才通过
			}

			CGPROGRAM

			#pragma target 3.0
			#pragma vertex VertexProgram
			#pragma fragment FragmentProgram
			
			#pragma exclude_renderers nomrt
			
			#include "UnityCG.cginc"

			sampler2D _LightBuffer; //存储所有光源叠加后的光照效果
			//过时

			struct VertexData {
				float4 vertex : POSITION;
				float2 uv :TEXCOORD0;
			};

			struct Interpolators {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			Interpolators VertexProgram (VertexData v) {
				Interpolators i;
				i.pos = UnityObjectToClipPos(v.vertex);
				i.uv = v.uv;
				return i;
			}

			float4 FragmentProgram (Interpolators i) : SV_Target {
				return -log2(tex2D(_LightBuffer, i.uv));
			}

			ENDCG
		}
	}
}