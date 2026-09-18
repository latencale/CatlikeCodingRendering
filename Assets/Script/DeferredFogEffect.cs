using UnityEngine;
using System;

[ExecuteInEditMode]
public class DeferredFogEffect : MonoBehaviour
{
    public Shader defferedFog;

    [NonSerialized] //非序列化：不出现在Inspector中、不被保存
    Material fogMaterial;

    [NonSerialized]
    Camera deferredCamera;

    [NonSerialized]
    Vector3[] frustumCorners; //视锥体角点：存储摄像机视锥体的8个角在世界坐标的位置

    [NonSerialized]
    Vector4[] vectorArray;

    //Unity会检查摄像机是否有该method，并在场景渲染结束后调用
    [ImageEffectOpaque] //在不透明物体渲染完成之后，透明物体渲染完成之前执行
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {//源纹理，目标纹理
        if (fogMaterial == null)
        {
            deferredCamera = GetComponent<Camera>();
            frustumCorners = new Vector3[4]; // 近平面的4个角点
            vectorArray = new Vector4[4];
            fogMaterial = new Material(defferedFog);
        }
        deferredCamera.CalculateFrustumCorners(
            new Rect(0f, 0f, 1f, 1f), //整个视口
            deferredCamera.farClipPlane, //距离
            deferredCamera.stereoActiveEye, //眼睛
            frustumCorners //输出数组
        );
        //计算出书锥体远平面的四个角点坐标

        vectorArray[0] = frustumCorners[0];//左下
        vectorArray[1] = frustumCorners[3];//右下
        vectorArray[2] = frustumCorners[1];//左上
        vectorArray[3] = frustumCorners[2];//右上
        fogMaterial.SetVectorArray("_FrustumCorners", vectorArray);
        //从C#向shader传递一个向量数组（只接受vector4）
        Graphics.Blit(source, destination, fogMaterial);
        //图像后处理，将source经过材质处理，复制到destination
    }
}
