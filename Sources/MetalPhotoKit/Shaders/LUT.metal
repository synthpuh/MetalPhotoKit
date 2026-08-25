#include <metal_stdlib>
using namespace metal;

struct LUTParams {
    float intensity;
};

kernel void lut3D(texture2d<float, access::read> inTexture [[texture(0)]],
                   texture2d<float, access::write> outTexture [[texture(1)]],
                   texture3d<float, access::sample> lutTexture [[texture(2)]],
                   constant LUTParams &params [[buffer(0)]],
                   uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    constexpr sampler lutSampler(coord::normalized, address::clamp_to_edge, filter::linear);

    float4 color = inTexture.read(gid);

    // Texel centers sit at (i + 0.5) / size, not at i / size, so an input of
    // 0.0 or 1.0 must land exactly on the first/last center for the LUT's
    // corner values to come through unmodified.
    float lutSize = float(lutTexture.get_width());
    float3 lutCoord = (color.rgb * (lutSize - 1.0) + 0.5) / lutSize;

    float3 graded = lutTexture.sample(lutSampler, lutCoord).rgb;
    float3 blended = mix(color.rgb, graded, params.intensity);

    outTexture.write(float4(saturate(blended), color.a), gid);
}
