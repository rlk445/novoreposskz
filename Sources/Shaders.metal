#include <metal_stdlib>
using namespace metal;

struct SceneVertexIn {
    float3 position [[attribute(0)]];
    float2 uv       [[attribute(1)]];
};

struct FrameUniforms {
    float4x4 viewProj;
};

struct DrawUniforms {
    float4x4 model;
};

struct SceneVertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex SceneVertexOut scene_vertex(SceneVertexIn in [[stage_in]],
                                   constant FrameUniforms &frame [[buffer(1)]],
                                   constant DrawUniforms &draw [[buffer(2)]]) {
    SceneVertexOut out;
    out.position = frame.viewProj * draw.model * float4(in.position, 1.0);
    out.uv = in.uv;
    return out;
}

// O shader original do Quest só lê RGB e escreve alpha 1.0.
fragment float4 scene_fragment(SceneVertexOut in [[stage_in]],
                               texture2d<float> tex [[texture(0)]],
                               sampler smp [[sampler(0)]]) {
    float3 c = tex.sample(smp, in.uv).rgb;
    return float4(c, 1.0);
}

struct HandVertex {
    float4 position;
    float4 color;
};

struct HandOut {
    float4 position [[position]];
    float4 color;
};

vertex HandOut hand_vertex(uint vid [[vertex_id]],
                           constant HandVertex *verts [[buffer(0)]],
                           constant float4x4 &proj [[buffer(1)]]) {
    HandOut out;
    out.position = proj * verts[vid].position;
    out.color = verts[vid].color;
    return out;
}

fragment float4 hand_fragment(HandOut in [[stage_in]]) {
    return in.color;
}
