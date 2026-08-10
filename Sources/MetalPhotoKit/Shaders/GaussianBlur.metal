#include <metal_stdlib>
using namespace metal;

kernel void gaussianBlur(texture2d<float, access::read> inTexture [[texture(0)]],
                          texture2d<float, access::write> outTexture [[texture(1)]],
                          constant float *weights [[buffer(0)]],
                          constant int &radius [[buffer(1)]],
                          constant int2 &direction [[buffer(2)]],
                          uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    int2 bounds = int2(inTexture.get_width() - 1, inTexture.get_height() - 1);
    int2 center = int2(gid);

    float4 sum = inTexture.read(gid) * weights[0];

    for (int i = 1; i <= radius; i++) {
        int2 offset = direction * i;
        sum += inTexture.read(uint2(clamp(center + offset, int2(0), bounds))) * weights[i];
        sum += inTexture.read(uint2(clamp(center - offset, int2(0), bounds))) * weights[i];
    }

    outTexture.write(sum, gid);
}
