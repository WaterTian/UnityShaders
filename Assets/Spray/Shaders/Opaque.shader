//
// Opaque surface shader for Spray
//
// Vertex format:
// position.xyz = vertex position
// texcoord0.xy = uv for texturing
// texcoord1.xy = uv for position/rotation buffer
//
// Position buffer format:
// .xyz = particle position
// .w   = life (+0.5 -> -0.5)
//
// Rotation buffer format:
// .xyzw = particle rotation
//
Shader "Kvant/Spray/Opaque PBR"
{
    Properties
    {
        _PositionBuffer ("-", 2D) = "black"{}
        _RotationBuffer ("-", 2D) = "red"{}
        _VelocityBuffer ("-", 2D) = "red"{}

        [KeywordEnum(Single, Animate, Random)]
        _ColorMode ("-", Float) = 0
        _Color     ("-", Color) = (1, 1, 1, 1)
        _Color2    ("-", Color) = (0.5, 0.5, 0.5, 1)

        _Metallic   ("-", Range(0,1)) = 0.5
        _Smoothness ("-", Range(0,1)) = 0.5

        _MainTex      ("-", 2D) = "white"{}
        _NormalMap    ("-", 2D) = "bump"{}
        _NormalScale  ("-", Range(0,2)) = 1
        _OcclusionMap ("-", 2D) = "white"{}
        _OcclusionStr ("-", Range(0,1)) = 1

        [HDR] _Emission ("-", Color) = (0, 0, 0)

        _ScaleMin ("-", Float) = 1
        _ScaleMax ("-", Float) = 1

        _RandomSeed ("-", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        CGPROGRAM

        #pragma surface surf Standard vertex:vert nolightmap addshadow
        #pragma shader_feature _COLORMODE_RANDOM
        #pragma shader_feature _ALBEDOMAP
        #pragma shader_feature _NORMALMAP
        #pragma shader_feature _OCCLUSIONMAP
        #pragma shader_feature _EMISSION
        #pragma target 3.0

        #include "Common.cginc"

        half _Metallic;
        half _Smoothness;

        sampler2D _MainTex;
        sampler2D _NormalMap;
        half _NormalScale;
        sampler2D _OcclusionMap;
        half _OcclusionStr;
        half3 _Emission;

        struct Input
        {
            float2 uv_MainTex;
            half4 color : COLOR;
        };
        
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
        

        void vert(inout appdata_full v)
        {
            float4 uv = float4(v.texcoord1.xy + _BufferOffset, 0, 0);

            float4 p = tex2Dlod(_PositionBuffer, uv);
            float4 r = tex2Dlod(_RotationBuffer, uv);
            float4 pv = tex2Dlod(_VelocityBuffer, uv);
            
            //float4 r = float4(0, 0, 0, 1);
            
            float l = p.w + 0.5;
            float s = calc_scale(uv, l);

            //v.vertex.xyz = rotate_vector(v.vertex.xyz*float3(1,2,5), r) * .1 + p.xyz;
            //v.normal = rotate_vector(v.normal, r);
            
        //#if _NORMALMAP
        //    v.tangent.xyz = rotate_vector(v.tangent.xyz, r);
        //#endif
        
            float3 scl = float3(1,2,5)*0.1; 
        
            // 定义将对象坐标转换为世界坐标的矩阵
            float4x4 object2world = (float4x4)0; 
            // 代入比例值
            object2world._11_22_33_44 = float4(scl.xyz, 1.0);
            // 根据速度计算Y轴的旋转
            float rotY = atan2(pv.x, pv.z);
            // 根据速度计算X轴的旋转
            float rotX = -asin(pv.y / (length(pv.xyz) + 1e-8));
            // 从光学角度（弧度）求回转矩阵
            float4x4 rotMatrix = eulerAnglesToRotationMatrix(float3(rotX, rotY, 0));
            
            
            // 旋转矩阵
            object2world = mul(rotMatrix, object2world);
            // 对矩阵应用位置(平移)
            object2world._14_24_34 += p.xyz;

            // 頂点座標変換
            v.vertex = mul(object2world, v.vertex);
            // 法線座標変換
            v.normal = normalize(mul(object2world, v.normal));
        
        #if _NORMALMAP
            v.tangent.xyz = normalize(mul(object2world, v.tangent.xyz));
        #endif
            v.color = calc_color(uv, l);
        }

        void surf(Input IN, inout SurfaceOutputStandard o)
        {
        #if _ALBEDOMAP
            half4 c = tex2D(_MainTex, IN.uv_MainTex);
            o.Albedo = IN.color.rgb * c.rgb;
        #else
            o.Albedo = IN.color.rgb;
        #endif

        #if _NORMALMAP
            half4 n = tex2D(_NormalMap, IN.uv_MainTex);
            o.Normal = UnpackScaleNormal(n, _NormalScale);
        #endif

        #if _OCCLUSIONMAP
            half4 occ = tex2D(_OcclusionMap, IN.uv_MainTex);
            o.Occlusion = lerp((half4)1, occ, _OcclusionStr);
        #endif

        #if _EMISSION
            o.Emission = _Emission;
        #endif

            o.Metallic = _Metallic;
            o.Smoothness = _Smoothness;
        }

        ENDCG
    }
    CustomEditor "Kvant.SpraySurfaceMaterialEditor"
}
