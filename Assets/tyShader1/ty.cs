//
// Spray - particle system
//
using UnityEngine;
using UnityEngine.Rendering;
using System;

namespace WaterTian
{
    [ExecuteInEditMode]
    [AddComponentMenu("WaterTian/ty")]
    public partial class ty : MonoBehaviour
    {
        #region Basic Properties

        [SerializeField]
        int _maxParticles = 10000;

        public int maxParticles
        {
            get
            {
                // Returns actual number of particles.
                if (_bulkMesh == null || _bulkMesh.copyCount < 1) return 0;
                return (_maxParticles / _bulkMesh.copyCount + 1) * _bulkMesh.copyCount;
            }
        }

        #endregion

        #region Emitter Parameters

        [SerializeField]
        Vector3 _emitterCenter = Vector3.zero;

        public Vector3 emitterCenter
        {
            get { return _emitterCenter; }
            set { _emitterCenter = value; }
        }

        // 流量
        [SerializeField, Range(0, 1)]
        float _throttle = 1.0f;
        public float throttle
        {
            get { return _throttle; }
            set { _throttle = value; }
        }

        #endregion

        #region Particle Life Parameters

        [SerializeField]
        float _life = 4.0f;

        public float life
        {
            get { return _life; }
            set { _life = value; }
        }

        [SerializeField, Range(0, 1)]
        float _lifeRandomness = 0.6f;

        public float lifeRandomness
        {
            get { return _lifeRandomness; }
            set { _lifeRandomness = value; }
        }

        #endregion

        #region Velocity Parameters

        [SerializeField]
        Vector3 _startVelocity = Vector3.forward * 4.0f;

        public Vector3 startVelocity
        {
            get { return _startVelocity; }
            set { _startVelocity = value; }
        }

        #endregion


        // 加速度
        #region Acceleration Parameters

        [SerializeField]
        Vector3 _acceleration = Vector3.zero;

        public Vector3 acceleration
        {
            get { return _acceleration; }
            set { _acceleration = value; }
        }

        [SerializeField, Range(0, 10)]
        float _accelerationDrag = 0.1f;

        public float accelerationDra
        {
            get { return _accelerationDrag; }
            set { _accelerationDrag = value; }
        }

        #endregion


        #region Noise Parameters
        // 频率
        [SerializeField]
        float _noiseFrequency = 0.2f;

        public float noiseFrequency
        {
            get { return _noiseFrequency; }
            set { _noiseFrequency = value; }
        }

        // 振幅
        [SerializeField]
        float _noiseAmplitude = 1.0f;

        public float noiseAmplitude
        {
            get { return _noiseAmplitude; }
            set { _noiseAmplitude = value; }
        }

        [SerializeField]
        float _noiseMotion = 1.0f;

        public float noiseMotion
        {
            get { return _noiseMotion; }
            set { _noiseMotion = value; }
        }

        #endregion

        // realsense
        #region Realsense


        //Texture2D _DepthTexture;
        //public Texture2D DepthTexture
        //{
        //    get { return _DepthTexture; }
        //    set { _DepthTexture = value; }
        //}
        [SerializeField]
        GameObject _DepthTextureObj;
        public GameObject DepthTextureObj
        {
            get { return _DepthTextureObj; }
            set { _DepthTextureObj = value; }
        }




        Texture2D _DepthMap;

        #endregion

        #region Render Settings

        [SerializeField]
        Mesh[] _shapes = new Mesh[1];

        [SerializeField]
        float _scale = 1.0f;

        public float scale
        {
            get { return _scale; }
            set { _scale = value; }
        }

        [SerializeField]
        Vector3 _scaleG = Vector3.one;

        public Vector3 scaleG
        {
            get { return _scaleG; }
            set { _scaleG = value; }
        }


        [SerializeField]
        Material _material;
        bool _owningMaterial; // whether owning the material

        public Material sharedMaterial
        {
            get { return _material; }
            set { _material = value; }
        }

        public Material material
        {
            get
            {
                if (!_owningMaterial)
                {
                    _material = Instantiate<Material>(_material);
                    _owningMaterial = true;
                }
                return _material;
            }
            set
            {
                if (_owningMaterial) Destroy(_material, 0.1f);
                _material = value;
                _owningMaterial = false;
            }
        }

        [SerializeField]
        ShadowCastingMode _castShadows;

        public ShadowCastingMode shadowCastingMode
        {
            get { return _castShadows; }
            set { _castShadows = value; }
        }

        [SerializeField]
        bool _receiveShadows = false;

        public bool receiveShadows
        {
            get { return _receiveShadows; }
            set { _receiveShadows = value; }
        }

        #endregion


        #region Built-in Resources

        [SerializeField] Shader _kernelShader;
        [SerializeField] Shader _debugShader;

        #endregion

        #region Private Variables And Properties

        Vector3 _noiseOffset;
        RenderTexture _positionBuffer1;
        RenderTexture _positionBuffer2;
        RenderTexture _velocityBuffer1;
        RenderTexture _velocityBuffer2;
        tyMesh _bulkMesh;
        Material _kernelMaterial;
        Material _debugMaterial;
        bool _needsReset = true;

        static float deltaTime
        {
            get
            {
                var isEditor = !Application.isPlaying || Time.frameCount < 2;
                return isEditor ? 1.0f / 10 : Time.deltaTime;
            }
        }

        #endregion

        #region Misc Settings

        [SerializeField]
        bool _debug;

        #endregion


        //// start


        #region Resource Management

        public void NotifyConfigChange()
        {
            _needsReset = true;
        }

        Material CreateMaterial(Shader shader)
        {
            var material = new Material(shader);
            material.hideFlags = HideFlags.DontSave;
            return material;
        }

        RenderTexture CreateBuffer()
        {
            var width = _bulkMesh.copyCount;
            var height = _maxParticles / width + 1;
            var buffer = new RenderTexture(width, height, 0, RenderTextureFormat.ARGBFloat);
            buffer.hideFlags = HideFlags.DontSave;
            buffer.filterMode = FilterMode.Point;
            buffer.wrapMode = TextureWrapMode.Repeat;
            return buffer;
        }

        void UpdateKernelShader()
        {
            var m = _kernelMaterial;

            m.SetVector("_EmitterPos", _emitterCenter);

            var invLifeMax = 1.0f / Mathf.Max(_life, 0.01f);
            var invLifeMin = invLifeMax / Mathf.Max(1 - _lifeRandomness, 0.01f);
            m.SetVector("_LifeParams", new Vector2(invLifeMin, invLifeMax));
            m.SetVector("_StartVelocity", _startVelocity);

            var drag = Mathf.Exp(-_accelerationDrag * deltaTime);
            var aparams = new Vector4(_acceleration.x, _acceleration.y, _acceleration.z, drag);
            m.SetVector("_Acceleration", aparams);


            m.SetVector("_NoiseParams", new Vector2(_noiseFrequency, _noiseAmplitude));

            // Move the noise field backward in the direction of the
            // acceleration vector, or simply pull up when no acceleration.
            if (_acceleration == Vector3.zero)
                _noiseOffset += Vector3.up * _noiseMotion * deltaTime;
            else
                _noiseOffset += _acceleration.normalized * _noiseMotion * deltaTime;

            m.SetVector("_NoiseOffset", _noiseOffset);

            m.SetVector("_Config", new Vector2(_throttle,deltaTime));

            SetDepth();
        }


        void SetDepth()
        {
            WebCamTexture _DepthTexture = _DepthTextureObj.GetComponent<WebCam>().cameraTexture;
            if (!_DepthTexture) return;

            var _d = _DepthTexture.GetPixels32();
            //Debug.Log(_d.Length);
            //Debug.Log(_DepthTexture.width);
            //Debug.Log(_DepthTexture.height);

            //UInt16[] _d16 = new UInt16[_d.Length / 2];

            //for (int i = 0; i < _d.Length; i += 2)
            //{
            //    var temp = BitConverter.ToUInt16(_d,i);
            //    _d16[i / 2] = temp;
            //}

            //Debug.Log(_d16.Length);

            //Debug.Log(_depthMap.GetRawTextureData<Color32>().Length);


            var width = _bulkMesh.copyCount;
            var height = _maxParticles / width + 1;
            _DepthMap = new Texture2D(width, height, TextureFormat.RGBAFloat,false)
            {
                hideFlags = HideFlags.DontSave,
                filterMode = FilterMode.Point,
                wrapMode = TextureWrapMode.Repeat,
            };

            var _dm = _DepthMap.GetPixels32();
            //Debug.Log(_dm.Length);

            var colors = new Color[_dm.Length];
            var _i = 0;
            for (int i = 0; i < _dm.Length; i ++)
            {
                if (i > _d.Length) _i = i % _d.Length;

                var _x = _i % _DepthTexture.width - _DepthTexture.width/2;
                var _y = Mathf.Floor(_i / _DepthTexture.height) - _DepthTexture.height / 2;
                var _z = 0;

                if (_i < _d.Length) _z = _d[_i].r;


                colors[i] = new Color(_x, _y, _z, 1);

                _i++;
            }

            _DepthMap.SetPixels(colors);
            _DepthMap.Apply();


            _kernelMaterial.SetTexture("_DepthBuffer", _DepthMap);

        }

        void ResetResources()
        {
            if (_bulkMesh == null)
                _bulkMesh = new tyMesh(_shapes);
            else
                _bulkMesh.Rebuild(_shapes);

            if (_positionBuffer1) DestroyImmediate(_positionBuffer1);
            if (_positionBuffer2) DestroyImmediate(_positionBuffer2);
            if (_velocityBuffer1) DestroyImmediate(_velocityBuffer1);
            if (_velocityBuffer2) DestroyImmediate(_velocityBuffer2);

            _positionBuffer1 = CreateBuffer();
            _positionBuffer2 = CreateBuffer();
            _velocityBuffer1 = CreateBuffer();
            _velocityBuffer2 = CreateBuffer();

            if (!_kernelMaterial) _kernelMaterial = CreateMaterial(_kernelShader);
            if (!_debugMaterial) _debugMaterial = CreateMaterial(_debugShader);

            // Warming up
            InitializeAndPrewarmBuffers();

            _needsReset = false;
        }

        void InitializeAndPrewarmBuffers()
        {
            _noiseOffset = Vector3.zero;

            UpdateKernelShader();

            Graphics.Blit(null, _positionBuffer2, _kernelMaterial, 0);
            Graphics.Blit(null, _velocityBuffer2, _kernelMaterial, 1);

            for (var i = 0; i < 8; i++)
            {
                SwapBuffersAndInvokeKernels();
                UpdateKernelShader();
            }
        }

        void SwapBuffersAndInvokeKernels()
        {
            // Swap the buffers.
            var tempPosition = _positionBuffer1;
            var tempVelocity = _velocityBuffer1;

            _positionBuffer1 = _positionBuffer2;
            _velocityBuffer1 = _velocityBuffer2;

            _positionBuffer2 = tempPosition;
            _velocityBuffer2 = tempVelocity;

            // Invoke the position update kernel.
            _kernelMaterial.SetTexture("_PositionBuffer", _positionBuffer1);
            _kernelMaterial.SetTexture("_VelocityBuffer", _velocityBuffer1);
            Graphics.Blit(null, _positionBuffer2, _kernelMaterial, 2);

            // Invoke the velocity and rotation update kernel
            // with the updated position.
            _kernelMaterial.SetTexture("_PositionBuffer", _positionBuffer2);
            Graphics.Blit(null, _velocityBuffer2, _kernelMaterial, 3);
        }

        #endregion

        #region MonoBehaviour Functions


        void Reset()
        {
            _needsReset = true;
        }

        void OnDestroy()
        {
            if (_bulkMesh != null) _bulkMesh.Release();
            if (_positionBuffer1) DestroyImmediate(_positionBuffer1);
            if (_positionBuffer2) DestroyImmediate(_positionBuffer2);
            if (_velocityBuffer1) DestroyImmediate(_velocityBuffer1);
            if (_velocityBuffer2) DestroyImmediate(_velocityBuffer2);
            if (_kernelMaterial) DestroyImmediate(_kernelMaterial);
            if (_debugMaterial) DestroyImmediate(_debugMaterial);
        }

        void Update()
        {
            
            if (_needsReset) ResetResources();

            if (Application.isPlaying)
            {
                UpdateKernelShader();
                SwapBuffersAndInvokeKernels();
            }
            else
            {
                InitializeAndPrewarmBuffers();
            }


            // Make a material property block for the following drawcalls.
            var props = new MaterialPropertyBlock();
            props.SetTexture("_PositionBuffer", _positionBuffer2);
            props.SetTexture("_VelocityBuffer", _velocityBuffer2);
            props.SetFloat("_Scale", _scale);
            props.SetVector("_ScaleG", _scaleG);

            // Temporary variables
            var mesh = _bulkMesh.mesh;
            var position = transform.position;
            var rotation = transform.rotation;
            var material = _material;
            var uv = new Vector2(0.5f / _positionBuffer2.width, 0);

            // Draw a bulk mesh repeatedly.
            for (var i = 0; i < _positionBuffer2.height; i++)
            {
                uv.y = (0.5f + i) / _positionBuffer2.height;
                props.SetVector("_BufferOffset", uv);
                Graphics.DrawMesh(
                    mesh, position, rotation,
                    material, 0, null, 0, props,
                    _castShadows, _receiveShadows);
            }
        }

        void OnGUI()
        {
            if (_debug && Event.current.type.Equals(EventType.Repaint))
            {
                if (_debugMaterial && _positionBuffer2 && _velocityBuffer2)
                {
                    var w = _positionBuffer2.width;
                    var h = _positionBuffer2.height;

                    var rect = new Rect(0, 0, w, h);
                    Graphics.DrawTexture(rect, _positionBuffer2, _debugMaterial);

                    rect.y += h;
                    Graphics.DrawTexture(rect, _velocityBuffer2, _debugMaterial);

                    rect.y += h;
                    Graphics.DrawTexture(rect, _DepthMap, _debugMaterial);

                    

                }
            }


            //print(_DepthTextureObject.GetComponent<RsStreamTextureRenderer>().texture);
        }

        void OnDrawGizmosSelected()
        {
            Gizmos.color = Color.yellow;
            Gizmos.matrix = transform.localToWorldMatrix;
            Gizmos.DrawWireCube(_emitterCenter, Vector3.one);
        }

        #endregion
    }
}
