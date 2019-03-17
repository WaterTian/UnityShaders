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
// Rotation buffer format:
// .xyzw = particle rotation
//
Shader "Hidden/Kvant/Spray/Kernel"
{
    Properties
    {
        _PositionBuffer ("-", 2D) = ""{}
        _VelocityBuffer ("-", 2D) = ""{}
        _RotationBuffer ("-", 2D) = ""{}
    }

    CGINCLUDE

    #include "UnityCG.cginc"
    #include "SimplexNoiseGrad3D.cginc"

    sampler2D _PositionBuffer;
    sampler2D _VelocityBuffer;
    sampler2D _RotationBuffer;

    float3 _EmitterPos;
    float3 _EmitterSize;
    float2 _LifeParams;   // 1/min, 1/max
    float4 _Direction;    // x, y, z, spread
    float2 _SpeedParams;  // speed, randomness
    float4 _Acceleration; // x, y, z, drag
    float3 _SpinParams;   // spin*2, speed-to-spin*2, randomness
    float2 _NoiseParams;  // freq, amp
    float3 _NoiseOffset;
    float4 _Config;       // throttle, random seed, dT, time

    // PRNG function
    float nrand(float2 uv, float salt)
    {
        uv += float2(salt, _Config.y);
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

    // Particle generator functions
    float4 new_particle_position(float2 uv)
    {
        float t = _Config.w;

        // Random position
        float3 p = float3(nrand(uv, t), nrand(uv, t + 1), nrand(uv, t + 2));
        p = (p - (float3)0.5) * _EmitterSize + _EmitterPos;

        // Throttling: discards particle emission by adding offset.
        float4 offs = float4(1e8, 1e8, 1e8, -1) * (uv.x > _Config.x);

        return float4(p, 0.5) + offs;
    }

    float4 new_particle_velocity(float2 uv)
    {
        // Random vector
        float3 v = float3(nrand(uv, 6), nrand(uv, 7), nrand(uv, 8));
        v = (v - (float3)0.5) * 2;

        // Spreading
        v = lerp(_Direction.xyz, v, _Direction.w);

        // Speed
        v = normalize(v) * _SpeedParams.x;
        v *= 1.0 - nrand(uv, 9) * _SpeedParams.y;

        //return float4(v, 0);
		return float4(0, 0, 0, 0);
    }

    float4 new_particle_rotation(float2 uv)
    {
        // Uniform random unit quaternion
        // http://www.realtimerendering.com/resources/GraphicsGems/gemsiii/urot.c
        float r = nrand(uv, 3);
        float r1 = sqrt(1.0 - r);
        float r2 = sqrt(r);
        float t1 = UNITY_PI * 2 * nrand(uv, 4);
        float t2 = UNITY_PI * 2 * nrand(uv, 5);
        //return float4(sin(t1) * r1, cos(t1) * r1, sin(t2) * r2, cos(t2) * r2);
        return float4(0,0,0,1);
    }

    // Deterministic random rotation axis
    float3 get_rotation_axis(float2 uv)
    {
        // Uniformaly distributed points
        // http://mathworld.wolfram.com/SpherePointPicking.html
        float u = nrand(uv, 10) * 2 - 1;
        float theta = nrand(uv, 11) * UNITY_PI * 2;
        float u2 = sqrt(1 - u * u);
        return float3(u2 * cos(theta), u2 * sin(theta), u);
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

    // Pass 2: initial rotation
    float4 frag_init_rotation(v2f_img i) : SV_Target
    {
        return new_particle_rotation(i.uv);
    }

    // Pass 3: position update
    float4 frag_update_position(v2f_img i) : SV_Target
    {
        float4 p = tex2D(_PositionBuffer, i.uv);
        float3 v = tex2D(_VelocityBuffer, i.uv).xyz;

        // Decaying
        float dt = _Config.z;
        p.w -= lerp(_LifeParams.x, _LifeParams.y, nrand(i.uv, 12)) * dt;

        if (p.w > -0.5)
        {
            // Applying the velocity
            p.xyz += v *0.01;
            return p;
        }
        else
        {
            // Respawn
            return new_particle_position(i.uv);
        }
    }

    // Pass 4: velocity update
    float4 frag_update_velocity(v2f_img i) : SV_Target
    {
        float4 p = tex2D(_PositionBuffer, i.uv);
        float3 v = tex2D(_VelocityBuffer, i.uv).xyz;

        if (p.w < 0.5)
        {
            // Drag
            //v *= _Acceleration.w; // dt is pre-applied in script

            // Constant acceleration
            float dt = _Config.z;
            //v += _Acceleration.xyz * dt;

            // Acceleration by turbulent noise
            float3 np = (p.xyz ) * _NoiseParams.x;
            float3 n1 = snoise_grad(np);
            float3 n2 = snoise_grad(np + float3(0, 13.28, 0));
            v += cross(n1, n2)  * dt;

            return float4(v, 0);
        }
        else
        {
            // Respawn
            return new_particle_velocity(i.uv);
        }
    }

	float4 eulerToQuaternion(float3 el) {
		// Assuming the angles are in radians.
		float c1 = cos(el.x / 2);
		float s1 = sin(el.x / 2);
		float c2 = cos(el.y / 2);
		float s2 = sin(el.y / 2);
		float c3 = cos(el.z / 2);
		float s3 = sin(el.z / 2);
		float c1c2 = c1 * c2;
		float s1s2 = s1 * s2;
		float w = c1c2 * c3 - s1s2 * s3;
		float x = c1c2 * s3 + s1s2 * c3;
		float y = s1 * c2*c3 + c1 * s2*s3;
		float z = c1 * s2*c3 - s1 * c2*s3;
		return float4(x, y, z, w);
	}
	float4 multQuat(float4 q1, float4 q2) {
		return float4(
			q1.w * q2.x + q1.x * q2.w + q1.z * q2.y - q1.y * q2.z,
			q1.w * q2.y + q1.y * q2.w + q1.x * q2.z - q1.z * q2.x,
			q1.w * q2.z + q1.z * q2.w + q1.y * q2.x - q1.x * q2.y,
			q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z
			);
	}

    // Pass 5: rotation update
    float4 frag_update_rotation(v2f_img i) : SV_Target
    {
		float4 p = tex2D(_PositionBuffer, i.uv);
        float4 r = tex2D(_RotationBuffer, i.uv);
        float3 v = tex2D(_VelocityBuffer, i.uv).xyz;




		if (p.w < 0.5)
		{

			////// �����ٶȼ���Y�����ת
			//float rotY = atan2(v.x, v.z)*3.14/180;
			////// �����ٶȼ���X�����ת
			//float rotX = -asin(v.y / (length(v.xyz) + 1e-8))*3.14 / 180;
			//float4 dq = eulerToQuaternion(float3(rotX, rotY, 0));

			float3 vFrom = float3(0,0,0);

			float r1 = dot(vFrom,v) + 1;
			float3 v1 = cross(vFrom, v);
			float4 dq = float4(v1, r1);

			// Applying the quaternion and normalize the result.
			return normalize(qmul(normalize(dq), r));

			//return dq;
		}
		else
		{
			return float4(0, 0, 0, 1);
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
            #pragma fragment frag_init_rotation
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
        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert_img
            #pragma fragment frag_update_rotation
            ENDCG
        }
    }
}
