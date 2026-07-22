#include <metal_stdlib>
using namespace metal;

struct ExposureContrastParams {
    float exposure;
    float contrast;
};

kernel void exposureContrast(texture2d<float, access::read> inTexture [[texture(0)]],
                              texture2d<float, access::write> outTexture [[texture(1)]],
                              constant ExposureContrastParams &params [[buffer(0)]],
                              uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float4 color = inTexture.read(gid);

    float3 exposed = color.rgb * exp2(params.exposure);
    float3 contrasted = (exposed - 0.5) * params.contrast + 0.5;

    outTexture.write(float4(saturate(contrasted), color.a), gid);
}
