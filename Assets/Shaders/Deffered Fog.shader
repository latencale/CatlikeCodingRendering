Shader "Custom/Deffered Fog"
{
    Properties
    {
        _MainTex ("Source", 2D) = "white" {}
        
    }
    SubShader
    {
        Cull off  //关闭剔除
        ZTest Always //始终通过深度测试，像素总是被绘制
        ZWrite off //关闭深度缓冲

        Pass{
            CGPROGRAM

            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram

            #pragma multi_compile_fog

            #define FOG_DISTANCE
            #define FOG_SKYBOX

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            sampler2D _CameraDepthTexture; //深度缓冲区纹理，变量名固定
            float3 _FrustumCorners[4];

            struct Interpolators{
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;

                #if defined(FOG_DISTANCE)
                    float3 ray : TEXCOORD1;
                #endif
            };
            
            struct VertexData{
                float4 vertex : POSITION;
                float2 uv :TEXCOORD0;
            };

            Interpolators VertexProgram(VertexData v){
                Interpolators i;
                i.pos = UnityObjectToClipPos(v.vertex);
                i.uv = v.uv;
                #if defined(FOG_DISTANCE)
                    i.ray = _FrustumCorners[v.uv.x + 2 * v.uv.y];
                #endif

                return i;
            }

            float4 FragmentProgram(Interpolators i) : SV_TARGET{
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
                //用SAMPLE_DEPTH_TEXTURE()进行采样
                depth = Linear01Depth(depth);
                //NDC空间下，把非线性的深度值转化为[0,1]的线性深度值
                float viewDistance = depth * _ProjectionParams.z - _ProjectionParams.y;
                // _ProjectionParams是unity内置的全局变量，存储与摄像机投影参数相关信息
                // .x 1.0透视投影/-1.0正交投影、.y 近裁剪面距离、 .z 远裁剪面距离、 .w 远裁剪面距离的倒数 1/far
                #if defined(FOG_DISTANCE)
                    viewDistance = length(i.ray * depth);
                #endif

                UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
                //根据雾效模式，计算出untiyFogFactor
                unityFogFactor = saturate(unityFogFactor);
                #if defined(FOG_SKYBOX)
                    if(depth > 0.9999){ //深度无限时（即天空盒），不进行雾化
                        unityFogFactor = 1;
                     }
                #endif
                //无雾效
                #if !defined(FOG_LINEAR) && !defined(FOG_EXP) && !defined(FOG_EXP2)
                    unityFogFactor = 1;
                #endif

                float3 sourceColor = tex2D(_MainTex, i.uv).rgb;
                float3 foggedColor = lerp(unity_FogColor.rgb, sourceColor, unityFogFactor);
                return float4(foggedColor, 1);
            }

            ENDCG
        }
    }

}
