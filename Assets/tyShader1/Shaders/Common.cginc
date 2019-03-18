//
// Common parts of Spray shaders
//




half _ColorMode;
half4 _Color;
half4 _Color2;
float _RandomSeed;
float2 _BufferOffset;

// PRNG function
float nrand(float2 uv, float salt)
{
    uv += float2(salt, _RandomSeed);
    return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
}

// Quaternion multiplication
// http://mathworld.wolfram.com/Quaternion.html
float4 qmul(float4 q1, float4 q2)
{
    return float4(
        q2.xyz * q1.w + q1.xyz * q2.w + cross(q1.xyz, q2.xyz),
        q1.w * q2.w - dot(q1.xyz, q2.xyz)
    );
}



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


// Color function
float4 calc_color(float2 uv, float time01)
{
#if _COLORMODE_RANDOM
    return lerp(_Color, _Color2, nrand(uv, 15));
#else
    return lerp(_Color, _Color2, (1.0 - time01) * _ColorMode);
#endif
}
