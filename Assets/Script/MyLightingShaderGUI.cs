using UnityEngine;
using UnityEditor;
public class MyLightingShaderGUI : ShaderGUI
{
    //光滑度的来源
    enum SmoothnessSource
    {
        Uniform, Albedo, Metallic //光滑度、主纹理、金属度贴图
    }

    Material target;
    MaterialEditor editor;//材质编辑器实例
    MaterialProperty[] properties;//该材质所有可用的属性列表
    static GUIContent staticLabel = new GUIContent();//静态GUI内容实例，用于显示标签和提示信息
    static ColorPickerHDRConfig emissionConfig = new ColorPickerHDRConfig(0f, 99f, 1 / 99f, 3f);//HDR颜色选择器配置，用于发光属性的颜色选择
    //亮度的最小值、最大值、曝光的最小值、最大值

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
        DoMain();
        DoSecondary();
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

        DoMetallic();
        DoSmoothnes();
        DoNormals();
        DoEmission();

        editor.TextureScaleOffsetProperty(mainTex);
        //显示纹理缩放和偏移属性编辑器
    }

    //查找材质属性
    MaterialProperty FindProperty(string name)
    {
        return FindProperty(name, properties);
    }

    void DoNormals()
    {
        MaterialProperty map = FindProperty("_NormalMap");
        editor.TexturePropertySingleLine(MakeLabel(map, "Normal Map"), map, map.textureValue ? FindProperty("_BumpScale") : null);
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
        EditorGUI.indentLevel += 1;
        EditorGUI.BeginChangeCheck();
        source = (SmoothnessSource)EditorGUILayout.EnumPopup(new GUIContent("Source"), source);
        if (EditorGUI.EndChangeCheck())
        {
            sourceProp.floatValue = (float)source;

            RecordAction("Smoothness Source");
            SetKeyword("_SMOOTHNESS_ALBEDO", source == SmoothnessSource.Albedo);
            SetKeyword("_SMOOTHNESS_METALLIC", source == SmoothnessSource.Metallic);
        }
        EditorGUI.indentLevel -= 3;
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
    void DoSecondary()
    {
        GUILayout.Label("Secondary Maps", EditorStyles.boldLabel);

        MaterialProperty detailTex = FindProperty("_DetailTex");
        editor.TexturePropertySingleLine(
            MakeLabel(detailTex, "Albedo (RGB) multiplied by 2"), detailTex
        );

        DoSecondaryNormals();

        editor.TextureScaleOffsetProperty(detailTex);
    }

    void DoSecondaryNormals()
    {
        MaterialProperty map = FindProperty("_DetailNormalMap");
        editor.TexturePropertySingleLine(
            MakeLabel(map), map,
            map.textureValue ? FindProperty("_DetailBumpScale") : null
        );
    }

    //设置关键字
    void SetKeyword(string keyword, bool state)
    {
        if (state)
        {
            target.EnableKeyword(keyword);
            //添加关键字
        }
        else
        {
            target.DisableKeyword(keyword);
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
