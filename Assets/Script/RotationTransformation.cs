using UnityEngine;

public class RotationTransformation : Transformation
{
    public Vector3 rotation;

    public override Matrix4x4 Matrix
    {
        get{
            float radX = rotation.x * Mathf.Deg2Rad;
            float radY = rotation.y * Mathf.Deg2Rad;
            float radZ = rotation.z * Mathf.Deg2Rad;//角度转弧度
            float sinX = Mathf.Sin(radX);
            float sinY = Mathf.Sin(radY);
            float sinZ = Mathf.Sin(radZ);
            float cosX = Mathf.Cos(radX);
            float cosY = Mathf.Cos(radY);
            float cosZ = Mathf.Cos(radZ);

            Matrix4x4 matrix= new Matrix4x4();
            matrix.SetRow(0, new Vector4(
                cosY * cosZ,
                cosX * sinZ + sinX * sinY * cosZ,
                sinX * sinZ - cosX * sinY * cosZ,
                0f
                ));
            matrix.SetRow(1, new Vector4(
                -cosY * sinZ,
                cosX * cosZ - sinX * sinY * sinZ,
                sinX * cosZ + cosX * sinY * sinZ,
                0f
            ));
            matrix.SetRow(2, new Vector4(
                sinY,
                -sinX * cosY,
                cosX * cosY,
                0f
            ));
            matrix.SetRow(3, new Vector4(0f,0f,0f,1f) );

            return matrix;
        }
    }
}
