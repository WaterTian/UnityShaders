//
// GPGPU kernels for Spray
//
// Position buffer format:
// .xyz = particle position
// .w   = life (+0.5 -> -0.5)
//
// Velocity buffer format:
// .xyz = particle velocity
//
//
Shader "WaterTian/Spray/Kernel"
{
    Properties
    {
        _PositionBuffer ("-", 2D) = ""{}
        _VelocityBuffer ("-", 2D) = ""{}
        _DepthBuffer ("-", 2D) = ""{}
    }

    CGINCLUDE

    #include "UnityCG.cginc"
    #include "SimplexNoiseGrad3D.cginc"

    sampler2D _PositionBuffer;
    sampler2D _VelocityBuffer;
    sampler2D _DepthBuffer;

    float3 _EmitterPos;
    float2 _LifeParams;   // 1/min, 1/max
    float3 _StartVelocity;    // x, y, z   初始速度
    float4 _Acceleration; // x, y, z, drag  加速度

    float2 _NoiseParams;  // freq, amp  频率 振幅 
    float3 _NoiseOffset;
    float2 _Config;       // throttle, dT

    // PRNG function
    float nrand(float2 uv, float salt)
    {
        //float randomSeed = 0;
        uv += float2(salt, 0);
        return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
    }
    

    // Particle generator functions
    float4 new_particle_position(float2 uv)
    {
        float t = _Config.y;

        // Random position
        float3 p = float3(nrand(uv, t), nrand(uv, t + 1), nrand(uv, t + 2));
        p = (p - (float3)0.5) + _EmitterPos;

        // Throttling: discards particle emission by adding offset.
        float4 offs = float4(1e8, 1e8, 1e8, -1) * (uv.x > _Config.x);

        //return float4(p, 0.5) + offs;

		p = tex2D(_DepthBuffer, uv).xyz;
        return float4(p/10, 0.5);
    }

    float4 new_particle_velocity(float2 uv)
    {
        // Random vector
        float3 v = float3(nrand(uv, 6), nrand(uv, 7), nrand(uv, 8));
        v = (v - (float3)0.5) * 2;
        
        v = lerp(_StartVelocity, v, 0.4);

        return float4(_StartVelocity, 0);
        //return float4(0, 0, 0, 0);
    }
    
    
    // Pass 0: initial position
    float4 frag_init_position(v2f_img i) : SV_Target
    {
        // Crate a new particle and randomize its initial life.
        return new_particle_position(i.uv) - float4(0, 0, 0, nrand(i.uv, 14));
    }

    // Pass 1: initial velocity
    float4 frag_init_velocity(v2f_img i) : SV_Target
    {
        return new_particle_velocity(i.uv);
    }
    
    // Pass 2: position update
    float4 frag_update_position(v2f_img i) : SV_Target
    {
        float4 p = tex2D(_PositionBuffer, i.uv);
        float3 v = tex2D(_VelocityBuffer, i.uv).xyz;

        // Decaying
        float dt = _Config.y;
        p.w -= lerp(_LifeParams.x, _LifeParams.y, nrand(i.uv, 12)) * dt;

        if (p.w > -0.5)
        {
            // Applying the velocity
            p.xyz += v * dt;
            return p;
        }
        else
        {
            // Respawn
            return new_particle_position(i.uv);
        }
    }

    // Pass 3: velocity update
    float4 frag_update_velocity(v2f_img i) : SV_Target
    {
        float4 p = tex2D(_PositionBuffer, i.uv);
        float3 v = tex2D(_VelocityBuffer, i.uv).xyz;

        if (p.w < 0.5)
        {
            float dt = _Config.y;
            
            // 加速度
            v *= _Acceleration.w; // dt is pre-applied in script
            v += _Acceleration.xyz * dt;

            // Acceleration by turbulent noise
            float3 np = (p.xyz + _NoiseOffset) * _NoiseParams.x;
            float3 n1 = snoise_grad(np);
            float3 n2 = snoise_grad(np + float3(0, 13.28, 0));
            v += cross(n1, n2) * _NoiseParams.y * dt;
            //v += n2*0.1;

            return float4(v, 0);
        }
        else
        {
            // Respawn
            return new_particle_velocity(i.uv);
        }
    }
    

    ENDCG

    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment frag_init_position
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment frag_init_velocity
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment frag_update_position
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment frag_update_velocity
            ENDCG
        }
    }
}
