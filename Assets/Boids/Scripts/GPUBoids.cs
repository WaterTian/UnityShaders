using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace BoidsSimulationOnGPU
{
    public class GPUBoids : MonoBehaviour
    {
        // Boid数据结构
        [System.Serializable]
        struct BoidData
        {
            public Vector3 Velocity; // 速度
            public Vector3 Position; // 位置
        }
        // 线索组线索大小
        const int SIMULATION_BLOCK_SIZE = 256;

        #region Boids Parameters
        // 最大オブジェクト数
        [Range(256, 32768*2)]
        public int MaxObjectNum = 16384;

        // 应用耦合的其它个体的半径
        public float CohesionNeighborhoodRadius = 2.0f;
        // 与其他对象应用排列的半径
        public float AlignmentNeighborhoodRadius = 2.0f;
        // 与其他个体应用分离的半径
        public float SeparateNeighborhoodRadius = 1.0f;

        // 速度の最大値
        public float MaxSpeed = 5.0f;
        // 操舵力の最大値
        public float MaxSteerForce = 0.5f;

        // 結合する力の重み
        public float CohesionWeight = 1.0f;
        // 整列する力の重み
        public float AlignmentWeight = 1.0f;
        // 分离的力量的分量
        public float SeparateWeight = 3.0f;

        // 壁を避ける力の重み
        public float AvoidWallWeight = 10.0f;

        // 墙体中心座標   
        public Vector3 WallCenter = Vector3.zero;
        // 墙体大小
        public Vector3 WallSize = new Vector3(32.0f, 32.0f, 32.0f);
        #endregion

        #region Built-in Resources
        // 进行Boids模拟的ComputeShader的参照
        public ComputeShader BoidsCS;
        #endregion

        #region Private Resources
        // 保存了Boid操舵力（Force）的缓冲器
        ComputeBuffer _boidForceBuffer;
        // 存储了Boid的基本数据(速度,位置, Transform等)的缓冲器
        ComputeBuffer _boidDataBuffer;
        #endregion

        #region Accessors
        // 获取存储了Boid基本数据的缓冲器
        public ComputeBuffer GetBoidDataBuffer()
        {
            return this._boidDataBuffer != null ? this._boidDataBuffer : null;
        }

        // 获取对象数量
        public int GetMaxObjectNum()
        {
            return this.MaxObjectNum;
        }

        // 返回模拟区域的中心坐标
        public Vector3 GetSimulationAreaCenter()
        {
            return this.WallCenter;
        }

        // 返回模拟区域中的框的大小
        public Vector3 GetSimulationAreaSize()
        {
            return this.WallSize;
        }
        #endregion

        #region MonoBehaviour Functions
        void Start()
        {
            //初始化缓冲器
            InitBuffer();
        }

        void Update()
        {
            // 模拟
            Simulation();
        }

        void OnDestroy()
        {
            // 丢弃缓冲器
            ReleaseBuffer();
        }

        void OnDrawGizmos()
        {
            // 在线框中绘制模拟区域作为调试
            Gizmos.color = Color.cyan;
            Gizmos.DrawWireCube(WallCenter, WallSize);
        }
        #endregion

        #region Private Functions
        // 缓冲初期化
        void InitBuffer()
        {
            //初期化
            _boidForceBuffer = new ComputeBuffer(MaxObjectNum,Marshal.SizeOf(typeof(Vector3)));
            _boidDataBuffer = new ComputeBuffer(MaxObjectNum, Marshal.SizeOf(typeof(BoidData)));

            // 初始化Boid数据, Force缓冲器
            var forceArr = new Vector3[MaxObjectNum];
            var boidDataArr = new BoidData[MaxObjectNum];

            for (var i = 0; i < MaxObjectNum; i++)
            {
                forceArr[i] = Vector3.zero;
                boidDataArr[i].Position = Random.insideUnitSphere * 1.0f;
                boidDataArr[i].Velocity = Random.insideUnitSphere * 0.1f;
            }
            _boidForceBuffer.SetData(forceArr);
            _boidDataBuffer.SetData(boidDataArr);
            forceArr = null;
            boidDataArr = null;
        }

        //模拟
        void Simulation()
        {
            ComputeShader cs = BoidsCS;

            // print("supportsComputeShaders:"+ SystemInfo.supportsComputeShaders);
            // print(cs.FindKernel("ForceCS"));

            int id = -1;

            // 求一个线索组的数目る
            int threadGroupSize = Mathf.CeilToInt(MaxObjectNum / SIMULATION_BLOCK_SIZE);

            // 操舵力を計算
            id = cs.FindKernel("ForceCS"); // 获取内核ID
            cs.SetInt("_MaxBoidObjectNum", MaxObjectNum);
            cs.SetFloat("_CohesionNeighborhoodRadius", CohesionNeighborhoodRadius);
            cs.SetFloat("_AlignmentNeighborhoodRadius", AlignmentNeighborhoodRadius);
            cs.SetFloat("_SeparateNeighborhoodRadius", SeparateNeighborhoodRadius);
            cs.SetFloat("_MaxSpeed", MaxSpeed);
            cs.SetFloat("_MaxSteerForce", MaxSteerForce);
            cs.SetFloat("_SeparateWeight", SeparateWeight);
            cs.SetFloat("_CohesionWeight", CohesionWeight);
            cs.SetFloat("_AlignmentWeight", AlignmentWeight);
            cs.SetVector("_WallCenter", WallCenter);
            cs.SetVector("_WallSize", WallSize);
            cs.SetFloat("_AvoidWallWeight", AvoidWallWeight);
            cs.SetBuffer(id, "_BoidDataBufferRead", _boidDataBuffer);
            cs.SetBuffer(id, "_BoidForceBufferWrite", _boidForceBuffer);
            cs.Dispatch(id, threadGroupSize, 1, 1); // ComputeShaderを実行

            // 从操舵力计算速度和位置
            id = cs.FindKernel("IntegrateCS"); // 获取内核ID
            cs.SetFloat("_DeltaTime", Time.deltaTime);
            cs.SetBuffer(id, "_BoidForceBufferRead", _boidForceBuffer);
            cs.SetBuffer(id, "_BoidDataBufferWrite", _boidDataBuffer);
            cs.Dispatch(id, threadGroupSize, 1, 1); // ComputeShaderを実行
        }

        // 释放缓冲器
        void ReleaseBuffer()
        {
            if (_boidDataBuffer != null)
            {
                _boidDataBuffer.Release();
                _boidDataBuffer = null;
            }

            if (_boidForceBuffer != null)
            {
                _boidForceBuffer.Release();
                _boidForceBuffer = null;
            }
        }
        #endregion
    } // class
} // namespace