using UnityEngine;

public class EmissiveOscillator : MonoBehaviour
{
    MeshRenderer emissiveRenderer;
    Material emissiveMatrial;

    void Start()
    {
        emissiveRenderer = GetComponent<MeshRenderer>();
        emissiveMatrial = emissiveRenderer.material;
    }

    void Update()
    {
        Color c = Color.Lerp(Color.black, Color.white, Mathf.Sin(Time.time * Mathf.PI) * 0.5f + 0.5f);
        emissiveMatrial.SetColor("_Emission", c);
        //如果要纹理也要自发光，要完整更新对象的自发光
        //emissiveRenderer.UpdateGIMaterials();
        //如果只是自发光纯色,调用以下函数，速度更快
        DynamicGI.SetEmissive(emissiveRenderer, c);
    }
}
