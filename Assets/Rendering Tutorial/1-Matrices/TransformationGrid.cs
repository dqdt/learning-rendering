using System.Collections;
using System.Collections.Generic;
using UnityEngine;




public class TransformationGrid : MonoBehaviour {
    public Transform Prefab;
    public int N;             // Number of points on each axis
    Transform[] grid;

    List<Transformation> transformations;
    Matrix4x4 transformationMatrix;        // The combined transformation matrix

    // The mapping from (x,y,z) indices to world coordinates: 
    //   x,y,z in [0,N-1] 
    //                         Y
    // (0,N-1) (1,N-1) (2,N-1) ^    ... (N-1,N-1)
    // (0,N-2) (1,N-2) (2,N-2) |    ... (N-1,N-2)
    //                         +---> X
    // (0,1)   (1,1)   (2,1)        ... (N-1,1)
    // (0,0)   (1,0)   (2,0)        ... (N-1,0)
    //
    //   [0 1 2 .. N-1] - (N-1)/2
    // = [-(N-1)/2 .. (N-1).2]     in equal steps
    Vector3 GetCoordinates(int x, int y, int z) {
        return new Vector3(
            x - (N - 1) * 0.5f,
            y - (N - 1) * 0.5f,
            z - (N - 1) * 0.5f
        );
    }

    Transform CreateGridPoint(int x, int y, int z) {
        Transform point = Instantiate<Transform>(Prefab);
        point.localPosition = GetCoordinates(x, y, z);
        point.GetComponent<MeshRenderer>().material.color =
            new Color((float)x / N, (float)y / N, (float)z / N);
        return point;
    }

    // Vector3 TransformPoint(int x, int y, int z) {
    //     Vector3 coordinates = GetCoordinates(x, y, z);
    //     for (int i = 0; i < transformations.Count; i++) {
    //         coordinates = transformations[i].Apply(coordinates);
    //     }
    //     return coordinates;
    // }
    Vector3 TransformPoint(int x, int y, int z) {
        Vector3 coordinates = GetCoordinates(x, y, z);
        return transformationMatrix.MultiplyPoint(coordinates);
    }

    void UpdateTransformationMatrix() {
        // Returns all components of Type type in the GameObject into List results.
        GetComponents<Transformation>(transformations);

        transformationMatrix = Matrix4x4.identity;
        for (int i = 0; i < transformations.Count; i++) {
            transformationMatrix = transformations[i].Matrix * transformationMatrix;
        }
    }

    void Awake() {
        grid = new Transform[N * N * N];
        {   // Instantiate a cube for each point on the grid.
            int i = 0;
            for (int z = 0; z < N; z++) {
                for (int y = 0; y < N; y++) {
                    for (int x = 0; x < N; x++) {
                        grid[i++] = CreateGridPoint(x, y, z);
                    }
                }
            }
        }

        transformations = new List<Transformation>();
    }

    void Start() {

    }

    void Update() {


        UpdateTransformationMatrix();
        int i = 0;
        for (int z = 0; z < N; z++) {
            for (int y = 0; y < N; y++) {
                for (int x = 0; x < N; x++) {
                    grid[i++].localPosition = TransformPoint(x, y, z);
                }
            }
        }

    }
}
