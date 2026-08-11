Shader "Custom/Builtin_SimpleWater"
{
    Properties
    {
        [Header(Water Color)]
        _WaterColorDeep ("深水颜色", Color) = (0.05, 0.15, 0.35, 0.6)
        _WaterColorShallow ("浅水颜色", Color) = (0.2, 0.6, 0.8, 0.5)
        
        [Header(Wave Settings)]
        _WaveStrength ("波浪强度", Range(0, 0.1)) = 0.025
        _WaveSpeed ("波浪速度", Range(0, 1.5)) = 0.35
        _WaveScale ("波浪缩放", Range(0.5, 3)) = 1.2
        
        [Header(Texture Flow)]
        _FlowSpeed ("纹理流动速度", Range(0, 0.5)) = 0.08
        _FlowDirection ("纹理流动方向", Range(0, 360)) = 45
        
        [Header(Reflection)]
        _ReflectionCubeMap ("反射立方体贴图", Cube) = "" {}
        _ReflectionStrength ("反射强度", Range(0, 1)) = 0.4
        _ReflectionColor ("反射颜色", Color) = (0.7, 0.8, 1.0, 1.0)
        _FresnelPower ("菲涅尔强度", Range(1, 8)) = 2.5
        
        [Header(Specular)]
        _SpecularColor ("高光颜色", Color) = (0.9, 0.95, 1.0, 1.0)
        _SpecularPower ("高光强度", Range(10, 200)) = 80
        _SpecularAmount ("高光数量", Range(0, 1)) = 0.6
        
        [Header(Transparency)]
        _Transparency ("整体透明度", Range(0.1, 1)) = 0.5
        
        [Header(Texture)]
        _NormalMap ("法线贴图", 2D) = "bump" {}
    }
    
    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
        
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
            sampler2D _NormalMap;
            float4 _NormalMap_ST;
            samplerCUBE _ReflectionCubeMap;
            float4 _WaterColorDeep;
            float4 _WaterColorShallow;
            float4 _ReflectionColor;
            float4 _SpecularColor;
            float _WaveStrength;
            float _WaveSpeed;
            float _WaveScale;
            float _FlowSpeed;
            float _FlowDirection;
            float _ReflectionStrength;
            float _FresnelPower;
            float _Transparency;
            float _SpecularPower;
            float _SpecularAmount;
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 color : COLOR;
            };
            
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float3 worldViewDir : TEXCOORD3;
                float3 reflectDir : TEXCOORD4;
                float vertexAlpha : TEXCOORD5;
            };
            
            v2f vert(appdata v)
            {
                v2f o;
                
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                float time = _Time.y;
                
                // 波浪计算
                float wave1 = sin(worldPos.x * _WaveScale + time * _WaveSpeed) * cos(worldPos.z * _WaveScale * 0.8 + time * _WaveSpeed * 0.7);
                float wave2 = sin(worldPos.z * _WaveScale * 1.3 - time * _WaveSpeed * 0.9) * 0.6;
                float wave3 = sin((worldPos.x + worldPos.z) * _WaveScale * 1.1 + time * _WaveSpeed * 1.2) * 0.4;
                float wave = (wave1 + wave2 + wave3) * _WaveStrength;
                worldPos.y += wave;
                
                o.worldPos = worldPos;
                o.vertex = mul(UNITY_MATRIX_VP, float4(worldPos, 1.0));
                
                // 流动UV
                float rad = _FlowDirection * 3.14159 / 180.0;
                float2 flowDir = float2(cos(rad), sin(rad));
                float2 flowUV = v.uv * _NormalMap_ST.xy + _NormalMap_ST.zw;
                flowUV = flowUV + flowDir * time * _FlowSpeed;
                o.uv = flowUV;
                
                // 世界空间向量
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
                
                // 反射方向
                float3 viewDir = normalize(_WorldSpaceCameraPos - worldPos);
                o.reflectDir = reflect(-viewDir, o.worldNormal);
                
                // 顶点颜色alpha
                o.vertexAlpha = v.color.a;
                
                return o;
            }
            
            half4 frag(v2f i) : SV_Target
            {
                float time = _Time.y;
                
                // 采样法线贴图
                float2 uv1 = i.uv * 1.2 + float2(time * 0.04, time * 0.03);
                float2 uv2 = i.uv * 0.8 - float2(time * 0.03, time * 0.04);
                
                float3 normal1 = tex2D(_NormalMap, uv1).xyz * 2.0 - 1.0;
                float3 normal2 = tex2D(_NormalMap, uv2).xyz * 2.0 - 1.0;
                float3 tangentNormal = normalize(normal1 + normal2);
                
                // 扰动后的法线
                float3 worldNormal = normalize(i.worldNormal + tangentNormal.xzy * 0.3);
                float3 viewDir = normalize(i.worldViewDir);
                
                // 重新计算反射方向
                float3 reflectDir = reflect(-viewDir, worldNormal);
                
                // 菲涅尔
                float fresnel = pow(1.0 - saturate(dot(worldNormal, viewDir)), _FresnelPower);
                fresnel = lerp(0.15, 1.0, fresnel);
                
                // CubeMap采样（加了判断，避免没有贴图时报错）
                float3 cubeMapColor = _ReflectionColor.rgb;
                if (_ReflectionStrength > 0.01)
                {
                    float3 cubeSample = texCUBE(_ReflectionCubeMap, reflectDir).rgb;
                    cubeMapColor = cubeSample * _ReflectionColor.rgb;
                }
                
                // 光照
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float ndotl = saturate(dot(worldNormal, lightDir));
                float3 lightColor = _LightColor0.rgb * ndotl;
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb;
                
                // 高光
                float3 reflectLightDir = reflect(-lightDir, worldNormal);
                float spec = pow(saturate(dot(viewDir, reflectLightDir)), _SpecularPower);
                spec = spec * _SpecularAmount;
                float3 specularColor = _SpecularColor.rgb * spec;
                
                // 水颜色
                float depthFactor = saturate(1.0 - dot(viewDir, worldNormal) * 0.8);
                float3 waterBaseColor = lerp(_WaterColorShallow.rgb, _WaterColorDeep.rgb, depthFactor);
                
                // 反射混合
                float3 reflectColor = cubeMapColor * _ReflectionStrength * fresnel;
                
                // 最终颜色
                float3 finalColor = waterBaseColor * (lightColor + ambient * 0.5);
                finalColor += reflectColor;
                finalColor += specularColor;
                
                // 透明度
                float alpha = lerp(_WaterColorShallow.a, _WaterColorDeep.a, depthFactor);
                alpha = alpha * _Transparency;
                // 叠加顶点颜色的alpha
                alpha = alpha * i.vertexAlpha;
                
                return half4(finalColor, alpha);
            }
            ENDCG
        }
    }
    
    FallBack "Transparent/Diffuse"
}