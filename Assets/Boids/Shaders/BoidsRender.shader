Shader "Hidden/BoidsSimulationOnGPU/BoidsRender"
{
	Properties
	{
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM
		#pragma surface surf Standard vertex:vert addshadow
		#pragma instancing_options procedural:setup
		
		struct Input
		{
			float2 uv_MainTex;
		};
		// Boid构造体系
		struct BoidData
		{
			float3 velocity; // 速度
			float3 position; // 位置
		};

		#ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
		// Boid数据结构缓冲器
		StructuredBuffer<BoidData> _BoidDataBuffer;
		#endif

		sampler2D _MainTex; // 纹理

		half   _Glossiness; // 光泽
		half   _Metallic;   // 金属特性
		fixed4 _Color;      // 彩色

		float3 _ObjectScale; // Boid对象缩放

		// 将光学角度(弧度)转换为旋转矩阵
		float4x4 eulerAnglesToRotationMatrix(float3 angles)
		{
			float ch = cos(angles.y); float sh = sin(angles.y); // heading
			float ca = cos(angles.z); float sa = sin(angles.z); // attitude
			float cb = cos(angles.x); float sb = sin(angles.x); // bank

			// Ry-Rx-Rz (Yaw Pitch Roll)
			return float4x4(
				ch * ca + sh * sb * sa, -ch * sa + sh * sb * ca, sh * cb, 0,
				cb * sa, cb * ca, -sb, 0,
				-sh * ca + ch * sb * sa, sh * sa + ch * sb * ca, ch * cb, 0,
				0, 0, 0, 1
			);
		}

		// 頂点シェーダ
		void vert(inout appdata_full v)
		{
			#ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED

			// 从实例ID获取Boid的数据
			BoidData boidData = _BoidDataBuffer[unity_InstanceID]; 

			float3 pos = boidData.position.xyz; // Boidの位置を取得
			float3 scl = _ObjectScale;          // Boidのスケールを取得

			// 定义将对象坐标转换为世界坐标的矩阵
			float4x4 object2world = (float4x4)0; 
			// 代入比例值
			object2world._11_22_33_44 = float4(scl.xyz, 1.0);
			// 根据速度计算Y轴的旋转
			float rotY = atan2(boidData.velocity.x, boidData.velocity.z);
			// 根据速度计算X轴的旋转
			float rotX = -asin(boidData.velocity.y / (length(boidData.velocity.xyz) + 1e-8));
			// 从光学角度（弧度）求回转矩阵
			float4x4 rotMatrix = eulerAnglesToRotationMatrix(float3(rotX, rotY, 0));
			// 旋转矩阵
			object2world = mul(rotMatrix, object2world);
			// 对矩阵应用位置(平移)
			object2world._14_24_34 += pos.xyz;

			// 頂点座標変換
			v.vertex = mul(object2world, v.vertex);
			// 法線座標変換
			v.normal = normalize(mul(object2world, v.normal));
			#endif
		}
		
		void setup()
		{
		}

		// サーフェスシェーダ
		void surf (Input IN, inout SurfaceOutputStandard o)
		{
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
		}
		ENDCG
	}
	FallBack "Diffuse"
}