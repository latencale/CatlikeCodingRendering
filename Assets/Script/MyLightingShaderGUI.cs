using UnityEngine;
using UnityEngine.Rendering;
using UnityEditor;
public class MyLightingShaderGUI : ShaderGUI
{
    //光滑度的来源
    enum SmoothnessSource
    {
        Uniform, Albedo, Metallic //光滑度、主纹理、金属度贴图
    }

    enum RenderingMode
    {
        Opaque, Cutout, Fade, Transparent //不透明、裁剪、淡入淡出、半透明
    }

    struct RenderingSettings
    {
        public RenderQueue queue;
        //设置材质的渲染队列，根据渲染模式选择几何体、透明测试队列和半透明混合
        //不透明物体(Opaque)的默认渲染队列为RenderQueue.Geometry == 2000；
        //AlphaTest（镂空、栅栏）的渲染队列为RenderQueue.AlphaTest == 2450
        public string renderType;
        //设置材质的渲染类型，根据渲染模式选择不透明或透明裁剪类型
        //渲染类型用于着色器替换和后处理
        public BlendMode srcBlend, dstBlend;
        public bool zWrite;

        //静态数组，包含三种渲染模式的设置
        public static RenderingSettings[] modes = {
            new RenderingSettings()
            {
                queue = RenderQueue.Geometry,
                renderType = "Opaque",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = true
            },
            new RenderingSettings()
            {
                queue = RenderQueue.AlphaTest,
                renderType = "TransparentCutout",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.Zero,
                zWrite = true
            },
            new RenderingSettings()
            {
                queue = RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = BlendMode.SrcAlpha,
                dstBlend = BlendMode.OneMinusSrcAlpha,
                zWrite = false
            },
            new RenderingSettings()
            {
                queue = RenderQueue.Transparent,
                renderType = "Transparent",
                srcBlend = BlendMode.One,
                dstBlend = BlendMode.OneMinusSrcAlpha,
                zWrite = false
            }
        };
}

    Material target;
    MaterialEditor editor;//材质编辑器实例
    MaterialProperty[] properties;//该材质所有可用的属性列表
    static GUIContent staticLabel = new GUIContent();//静态GUI内容实例，用于显示标签和提示信息
    static ColorPickerHDRConfig emissionConfig = new ColorPickerHDRConfig(0f, 99f, 1 / 99f, 3f);//HDR颜色选择器配置，用于发光属性的颜色选择
    //亮度的最小值、最大值、曝光的最小值、最大值
    bool shouldShowAlphaCutoff;//是否显示Alpha裁剪滑块

    //显示材质属性的标签和提示信息
    static GUIContent MakeLabel (MaterialProperty property, string tooltip = null)
    {                           //文本、工具提示（即悬停时的提示）
        staticLabel.text = property.displayName;
        //由于在Shader中定义了_MainTex的displayName为"Albedo"，所以这里显示的标签为"Albedo"。
        staticLabel.tooltip = tooltip;//悬停时的提示
        return staticLabel;
    }

    //重写ShaderGUI的OnGUI方法，用于自定义材质编辑器的界面
    public override void OnGUI(MaterialEditor editor, MaterialProperty[] properties)
    {
        this.target = editor.target as Material;
        //将材质编辑器的目标对象转换为Material类型
        this.editor = editor;
        this.properties = properties;
        DoRenderingMode();
        DoMain();
        DoSecondary();
    }

    //显示渲染模式属性：不透明/裁剪
    void DoRenderingMode()
    {
        RenderingMode mode = RenderingMode.Opaque;
        shouldShowAlphaCutoff = false;
        if (IsKeywordEnabled("_RENDERING_CUTOUT"))
        {
            mode = RenderingMode.Cutout;
            shouldShowAlphaCutoff = true;
        }
        else if(IsKeywordEnabled("_RENDERING_FADE"))
        {
            mode = RenderingMode.Fade;
        }
        else if (IsKeywordEnabled("_RENDERING_TRANSPARENT"))
        {
            mode = RenderingMode.Transparent;
        }

        EditorGUI.BeginChangeCheck();
        mode = (RenderingMode)EditorGUILayout.EnumPopup(
            new GUIContent("Rendering Mode"), mode
        );
        if (EditorGUI.EndChangeCheck())
        {
            RecordAction("Rendering Mode");
            SetKeyword("_RENDERING_CUTOUT", mode == RenderingMode.Cutout);
            SetKeyword("_RENDERING_FADE", mode == RenderingMode.Fade);
            SetKeyword("_RENDERING_TRANSPARENT", mode == RenderingMode.Transparent);
        }

        RenderingSettings settings = RenderingSettings.modes[(int)mode];
        foreach (Material m in editor.targets)//遍历每个材质对象
        //在Project视图中选中多个材质时，editor.targets包含所有选中的材质对象
        { 
            m.renderQueue = (int)settings.queue;
            m.SetOverrideTag("RenderType", settings.renderType);
            m.SetInt("_SrcBlend", (int)settings.srcBlend);
            m.SetInt("_DstBlend", (int)settings.dstBlend);
            m.SetInt("_ZWrite", settings.zWrite ? 1: 0);
        }
    }

    //显示主贴图属性
    void DoMain()
    {
        GUILayout.Label("Main Maps", EditorStyles.boldLabel);//显示标签为"Main Maps"，字体为粗体

        MaterialProperty mainTex = FindProperty("_MainTex");//查找材质属性"_MainTex"
        /*
        GUIContent albedoLabel = new GUIContent(mainTex.displayName, "Albedo (RGB)");
        GUIContent是Unity中用于显示GUI元素的内容类，可以包含文本、图像和提示信息等
        */
        editor.TexturePropertySingleLine(MakeLabel(mainTex, "Albedo (RGB)"), mainTex, FindProperty("_Tint"));
        //显示一个单行的纹理属性编辑器，标签为"Albedo"，绑定的材质属性为"_MainTex"
        //最多绑定三个属性:标签内容GUIContent、纹理属性MaterialProperty、颜色属性MaterialProperty

        if(shouldShowAlphaCutoff)
        {
            DoAlphaCutoff();
        }
        DoMetallic();
        DoSmoothnes();
        DoNormals();
        DoOcclusion();
        DoEmission();
        DoDetailMask();

        editor.TextureScaleOffsetProperty(mainTex);
        //显示纹理缩放和偏移属性编辑器
    }

    //查找材质属性
    MaterialProperty FindProperty(string name)
    {
        return FindProperty(name, properties);
    }

    void DoAlphaCutoff()
    {
        MaterialProperty slider = FindProperty("_AlphaCutoff");
        EditorGUI.indentLevel += 2;
        editor.ShaderProperty(slider, MakeLabel(slider));
        EditorGUI.indentLevel -= 2;
    }

    void DoMetallic()
    {
        MaterialProperty map = FindProperty("_MetallicMap");
        EditorGUI.BeginChangeCheck();//开始检查材质属性是否发生变化
        editor.TexturePropertySingleLine(
            MakeLabel(map, "Metallic (R)"), map,
            map.textureValue ? null :FindProperty("_Metallic")
        );
        if(EditorGUI.EndChangeCheck())//结束检查材质属性是否发生变化
        {
            SetKeyword("_METALLIC_MAP", map.textureValue);
        }
    }

    void DoSmoothnes()
    {
        MaterialProperty sourceProp = FindProperty("_SmoothnessSource");
        SmoothnessSource source = (SmoothnessSource)sourceProp.floatValue;//获取浮点值
        //转换为SmoothnessSource枚举类型
        if (IsKeywordEnabled("_SMOOTHNESS_ALBEDO")){
            source = SmoothnessSource.Albedo;
        }
        else if(IsKeywordEnabled("_SMOOTHNESS_METALLIC"))
        {
            source = SmoothnessSource.Metallic;
        }
        
        MaterialProperty slider = FindProperty("_Smoothness");
        EditorGUI.indentLevel += 2;
        editor.ShaderProperty(slider, MakeLabel(slider));
        //显示一个滑动条属性编辑器
        //ShaderProperty(property, label)
        //ShaderProperty()检查材质属性的类型，Color类型显示颜色选择器，Range类型显示滑动条，Vector类型显示四个浮点数输入框，Float类型显示一个浮点数输入框
        EditorGUI.indentLevel += 1;
        EditorGUI.BeginChangeCheck();
        source = (SmoothnessSource)EditorGUILayout.EnumPopup(
            new GUIContent("Source"), source
        );
        //EnumPopup显示一个枚举下拉框，标签为"Source"，绑定的枚举类型为SmoothnessSource
        if (EditorGUI.EndChangeCheck())
        {
            sourceProp.floatValue = (float)source;

            RecordAction("Smoothness Source");//注册材质属性更改的撤销操作
            SetKeyword("_SMOOTHNESS_ALBEDO", source == SmoothnessSource.Albedo);
            SetKeyword("_SMOOTHNESS_METALLIC", source == SmoothnessSource.Metallic);
        }
        EditorGUI.indentLevel -= 3;
    }
    void DoNormals()
    {
        MaterialProperty map = FindProperty("_NormalMap");
        Texture tex = map.textureValue;
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(MakeLabel(map, "Normal Map"), map, tex ? FindProperty("_BumpScale") : null);
        if (EditorGUI.EndChangeCheck() && tex != map.textureValue)
        {
            SetKeyword("_NORMAL_MAP", map.textureValue);
        }
    }

    void DoOcclusion()
    {
        MaterialProperty map = FindProperty("_OcclusionMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(map, "Occlusion (G)"), map,
            map.textureValue ? FindProperty("_OcclusionStrength") : null
        );
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_OCCLUSION_MAP", map.textureValue);
        }
    }

    void DoEmission()
    {
        MaterialProperty map = FindProperty("_EmissionMap");
        EditorGUI.BeginChangeCheck();//开始检查材质属性是否发生变化
        editor.TexturePropertyWithHDRColor(
            MakeLabel(map, "Emission (RGB)"), map, FindProperty("_Emission"),
            emissionConfig,false
        );
        if (EditorGUI.EndChangeCheck())//结束检查材质属性是否发生变化
        {
            SetKeyword("_EMISSION_MAP", map.textureValue);
        }
    }

    void DoDetailMask()
    {
        MaterialProperty mask = FindProperty("_DetailMask");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(mask, "Detail Mask (A)"), mask
        );
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_DETAIL_MASK", mask.textureValue);
        }
    }

    void DoSecondary()
    {
        GUILayout.Label("Secondary Maps", EditorStyles.boldLabel);

        MaterialProperty detailTex = FindProperty("_DetailTex");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(detailTex, "Albedo (RGB) multiplied by 2"), detailTex
        );
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_DETAIL_ALBEDO_MAP", detailTex.textureValue);
        }

        DoSecondaryNormals();

        editor.TextureScaleOffsetProperty(detailTex);
    }

    void DoSecondaryNormals()
    {
        MaterialProperty map = FindProperty("_DetailNormalMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(map), map,
            map.textureValue ? FindProperty("_DetailBumpScale") : null
        );
        if (EditorGUI.EndChangeCheck())
        {
            SetKeyword("_DETAIL_NORMAL_MAP", map.textureValue);
        }
    }

    //设置关键字
    void SetKeyword(string keyword, bool state)
    {
        if (state)
        {
            foreach(Material m in editor.targets)
            {
                m.EnableKeyword(keyword);
            }
            //遍历添加关键字
        }
        else
        {
            foreach(Material m in editor.targets)
            {
                m.DisableKeyword(keyword);
            }
        }
    }

    //检查关键字是否启用
    bool IsKeywordEnabled(string keyword)
    {
        return target.IsKeywordEnabled(keyword);
        
    }

    void RecordAction(string label)
    {
        editor.RegisterPropertyChangeUndo(label);
        //注册材质属性更改的撤销操作
    }
}
