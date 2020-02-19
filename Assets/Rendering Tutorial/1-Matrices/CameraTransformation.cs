using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraTransformation : Transformation {
    public float FocalLength = 1;

    // Perspective camera:  (x,y,z) -> (x/z, y/z, 0) by setting w=z
    // [1 0 0 0] [x]   [x]    [x/z]
    // [0 1 0 0] [y] = [y] -> [y/z]
    // [0 0 0 0] [z]   [0]    [0]
    // [0 0 1 0] [1]   [z]
    public override Matrix4x4 Matrix {
        get {
            Matrix4x4 matrix = new Matrix4x4();
            matrix.SetRow(0, new Vector4(FocalLength, 0, 0, 0));
            matrix.SetRow(1, new Vector4(0, FocalLength, 0, 0));
            matrix.SetRow(2, new Vector4(0, 0, 0, 0));
            matrix.SetRow(3, new Vector4(0, 0, 1, 0));
            return matrix;
        }
    }

    // Orthographic camera:  z-coordinate becomes zero
    // [1 0 0 0]
    // [0 1 0 0]
    // [0 0 0 0]
    // [0 0 0 1]
    // public override Matrix4x4 Matrix {
    //     get {
    //         Matrix4x4 matrix = new Matrix4x4();
    //         matrix.SetRow(0, new Vector4(1, 0, 0, 0));
    //         matrix.SetRow(1, new Vector4(0, 1, 0, 0));
    //         matrix.SetRow(2, new Vector4(0, 0, 0, 0));
    //         matrix.SetRow(3, new Vector4(0, 0, 0, 1));
    //         return matrix;
    //     }
    // }
}
