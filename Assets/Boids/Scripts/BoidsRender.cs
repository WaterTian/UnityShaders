using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace BoidsSimulationOnGPU
{
    // 保证GPUBoids组件被触摸到GameObject
    [RequireComponent(typeof(GPUBoids))]
    public class BoidsRender : MonoBehaviour
    {
        #region Paremeters
        // 绘制Boids对象的大小
        public Vector3 ObjectScale = new Vector3(0.1f, 0.2f, 0.5f);
        #endregion

        #region Script References
        // 参照GPUBoids脚本
        public GPUBoids GPUBoidsScript;
        #endregion

        #region Built-in Resources
        // 引用要绘制的网格
        public Mesh InstanceMesh;
        // 引用素材进行绘制
        public Material InstanceRenderMaterial;
        #endregion

        #region Private Variables
        //用于GPU实例的参数（转发至ComputeBuffer）
        //每实例的索引数,实例数,
        //开始索引位置,基本顶点位置,实例开始位置
        uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
        // 用于GPU实例的参数缓冲器
        ComputeBuffer argsBuffer;
        #endregion

        #region MonoBehaviour Functions
        void Start()
        {
            // 初始化参数缓冲器
            argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint),
                ComputeBufferType.IndirectArguments);
        }

        void Update()
        {
            //即时网格
            RenderInstancedMesh();
        }

        void OnDisable()
        {
            // 引数バッファを解放
            if (argsBuffer != null)
                argsBuffer.Release();
            argsBuffer = null;
        }
        #endregion

        #region Private Functions
        void RenderInstancedMesh()
        {
            //绘图材料Null,或, GPUBoids脚本Null,
            //或不支持GPU实例,则不进行处理.
            if (InstanceRenderMaterial == null || GPUBoidsScript == null ||
                !SystemInfo.supportsInstancing)
                return;

            // 获取指定网格的索引数
            uint numIndices = (InstanceMesh != null) ?
                (uint)InstanceMesh.GetIndexCount(0) : 0;
            args[0] = numIndices; // 设置网格索引数
            args[1] = (uint)GPUBoidsScript.GetMaxObjectNum(); // 设置实例数
            argsBuffer.SetData(args); // 设置在缓冲区

            // 将存储Boid数据的缓冲器设置为素材
            InstanceRenderMaterial.SetBuffer("_BoidDataBuffer",
                GPUBoidsScript.GetBoidDataBuffer());
            // 设置背景对象比例
            InstanceRenderMaterial.SetVector("_ObjectScale", ObjectScale);
            // 境界領域を定義
            var bounds = new Bounds
            (
                GPUBoidsScript.GetSimulationAreaCenter(), // 中心
                GPUBoidsScript.GetSimulationAreaSize()    // 大小
            );
            // 在GPU实例中绘制网格
            Graphics.DrawMeshInstancedIndirect
            (
                InstanceMesh,           // 实时网格
                0,                      // submesh 索引
                InstanceRenderMaterial, // 绘制素材
                bounds,                 // 境界領域
                argsBuffer              // 用于GPU实例的参数的缓冲器 
            );
        }
        #endregion
    }
}