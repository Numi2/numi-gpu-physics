#include <metal_stdlib>
using namespace metal;

struct SurfaceVertex { float4 position; float4 normal; };
struct ColoredVertex { float4 position; float4 normal; float4 color; };
struct IsoVertex { float4 position; float4 normal; };
struct TracerState { float4 positionAndAge; float4 velocityAndSpeed; };
struct SliceProbeOutput { float4 worldAndScalar; float4 velocity; float4 vorticity; };
struct CameraUniforms { float4x4 viewProjection; float4 eyeAndWidth; };

struct VisualizationUniforms {
    uint4 grid;
    uint4 flags;
    float4 originAndCellSize;
    float4 scalesAndRanges;
    float4 sliceCenterAndOpacity;
    float4 sliceUAndHalfWidth;
    float4 sliceVAndHalfHeight;
    float4 sliceNormalAndRange;
    float4 tracerAndIso;
    float4 displayOptions;
    float4 probeUVAndPadding;
    float4 bodyPosition;
    float4 orientation;
    float4 bodyRadiiAndTail;
    float4 wingGeometry0;
    float4 wingGeometry1;
    float4 leftRoot;
    float4 leftChord;
    float4 leftSpan;
    float4 leftNormal;
    float4 rightRoot;
    float4 rightChord;
    float4 rightSpan;
    float4 rightNormal;
};

struct RasterVertex {
    float4 position [[position]];
    float3 world;
    float3 normal;
    float4 color;
    float2 uv;
};

inline uint flatten(uint3 p, uint3 size) {
    return p.x + size.x * (p.y + size.y * p.z);
}

inline uint3 unflatten(uint index, uint3 size) {
    uint xy = size.x * size.y;
    uint z = index / xy;
    uint remainder = index - z * xy;
    uint y = remainder / size.x;
    return uint3(remainder - y * size.x, y, z);
}

inline float4 quaternionConjugate(float4 q) { return float4(-q.xyz, q.w); }
inline float3 quaternionRotate(float4 q, float3 v) {
    float3 t = 2.0f * cross(q.xyz, v);
    return v + q.w * t + cross(q.xyz, t);
}

inline float3 quaternionUnrotate(float4 q, float3 v) {
    return quaternionRotate(quaternionConjugate(q), v);
}

inline float sdEllipsoid(float3 p, float3 radii) {
    float k0 = length(p / radii);
    float k1 = length(p / (radii * radii));
    return k1 > 1.0e-12f ? k0 * (k0 - 1.0f) / k1 : -min(radii.x, min(radii.y, radii.z));
}

inline float sdWing(float3 world, float4 root, float4 chordAxis, float4 spanAxis,
                    float4 normalAxis, constant VisualizationUniforms& u) {
    float3 relative = world - root.xyz;
    float3 local = float3(dot(relative, chordAxis.xyz), dot(relative, spanAxis.xyz), dot(relative, normalAxis.xyz));
    float t = clamp(local.y / max(u.wingGeometry0.x, 1.0e-6f), 0.0f, 1.0f);
    float chord = mix(u.wingGeometry0.y, u.wingGeometry0.z, t);
    float center = -u.wingGeometry1.x * t;
    float3 q = float3(
        abs(local.x - center) - 0.5f * chord,
        max(-local.y, local.y - u.wingGeometry0.x),
        abs(local.z) - 0.5f * u.wingGeometry0.w
    );
    return length(max(q, float3(0))) + min(max(q.x, max(q.y, q.z)), 0.0f);
}

inline float sdTail(float3 local, constant VisualizationUniforms& u) {
    float x = -(local.x + u.bodyRadiiAndTail.x);
    float t = clamp(x / max(u.bodyRadiiAndTail.w, 1.0e-6f), 0.0f, 1.0f);
    float halfWidth = mix(0.35f * u.wingGeometry1.y, u.wingGeometry1.y, t);
    float3 q = float3(
        max(-x, x - u.bodyRadiiAndTail.w),
        abs(local.y) - halfWidth,
        abs(local.z + 0.15f * u.bodyRadiiAndTail.z) - 0.5f * u.wingGeometry1.z
    );
    return length(max(q, float3(0))) + min(max(q.x, max(q.y, q.z)), 0.0f);
}

inline float birdDistance(float3 world, constant VisualizationUniforms& u) {
    float3 local = quaternionUnrotate(u.orientation, world - u.bodyPosition.xyz);
    float distance = sdEllipsoid(local, u.bodyRadiiAndTail.xyz);
    distance = min(distance, sdTail(local, u));
    distance = min(distance, sdWing(world, u.leftRoot, u.leftChord, u.leftSpan, u.leftNormal, u));
    distance = min(distance, sdWing(world, u.rightRoot, u.rightChord, u.rightSpan, u.rightNormal, u));
    return distance;
}

inline float3 gridCoordinate(float3 world, constant VisualizationUniforms& u) {
    return (world - u.originAndCellSize.xyz) / u.originAndCellSize.w - 0.5f;
}

inline bool sampleInside(float3 g, uint3 size) {
    return all(g >= float3(0)) && all(g <= float3(size - 1u));
}

inline float sampleScalar(device const float* values, float3 g, uint3 size) {
    float3 clamped = clamp(g, float3(0), float3(size - 1u));
    uint3 a = uint3(floor(clamped));
    uint3 b = min(a + 1u, size - 1u);
    float3 t = fract(clamped);
    float c000 = values[flatten(uint3(a.x, a.y, a.z), size)];
    float c100 = values[flatten(uint3(b.x, a.y, a.z), size)];
    float c010 = values[flatten(uint3(a.x, b.y, a.z), size)];
    float c110 = values[flatten(uint3(b.x, b.y, a.z), size)];
    float c001 = values[flatten(uint3(a.x, a.y, b.z), size)];
    float c101 = values[flatten(uint3(b.x, a.y, b.z), size)];
    float c011 = values[flatten(uint3(a.x, b.y, b.z), size)];
    float c111 = values[flatten(uint3(b.x, b.y, b.z), size)];
    return mix(mix(mix(c000, c100, t.x), mix(c010, c110, t.x), t.y),
               mix(mix(c001, c101, t.x), mix(c011, c111, t.x), t.y), t.z);
}

inline float3 sampleVector(device const float4* values, float3 g, uint3 size) {
    float3 clamped = clamp(g, float3(0), float3(size - 1u));
    uint3 a = uint3(floor(clamped));
    uint3 b = min(a + 1u, size - 1u);
    float3 t = fract(clamped);
    float3 c000 = values[flatten(uint3(a.x, a.y, a.z), size)].xyz;
    float3 c100 = values[flatten(uint3(b.x, a.y, a.z), size)].xyz;
    float3 c010 = values[flatten(uint3(a.x, b.y, a.z), size)].xyz;
    float3 c110 = values[flatten(uint3(b.x, b.y, a.z), size)].xyz;
    float3 c001 = values[flatten(uint3(a.x, a.y, b.z), size)].xyz;
    float3 c101 = values[flatten(uint3(b.x, a.y, b.z), size)].xyz;
    float3 c011 = values[flatten(uint3(a.x, b.y, b.z), size)].xyz;
    float3 c111 = values[flatten(uint3(b.x, b.y, b.z), size)].xyz;
    return mix(mix(mix(c000, c100, t.x), mix(c010, c110, t.x), t.y),
               mix(mix(c001, c101, t.x), mix(c011, c111, t.x), t.y), t.z);
}

inline float3 physicalVelocity(device const float4* velocity, float3 g,
                               constant VisualizationUniforms& u) {
    return sampleVector(velocity, g, u.grid.xyz) * u.scalesAndRanges.x;
}

inline float3 vorticityAt(device const float4* velocity, float3 g,
                          constant VisualizationUniforms& u) {
    float inv = 0.5f * u.scalesAndRanges.x / u.originAndCellSize.w;
    float3 dx = (sampleVector(velocity, g + float3(1,0,0), u.grid.xyz)
               - sampleVector(velocity, g - float3(1,0,0), u.grid.xyz)) * inv;
    float3 dy = (sampleVector(velocity, g + float3(0,1,0), u.grid.xyz)
               - sampleVector(velocity, g - float3(0,1,0), u.grid.xyz)) * inv;
    float3 dz = (sampleVector(velocity, g + float3(0,0,1), u.grid.xyz)
               - sampleVector(velocity, g - float3(0,0,1), u.grid.xyz)) * inv;
    return float3(dy.z - dz.y, dz.x - dx.z, dx.y - dy.x);
}

inline float3 sequentialMap(float t) {
    t = clamp(t, 0.0f, 1.0f);
    return clamp(float3(0.18f + 1.1f*t - 0.35f*t*t,
                        0.03f + 1.55f*t - 0.75f*t*t,
                        0.34f + 0.85f*t - 1.0f*t*t), 0.0f, 1.0f);
}

inline float3 divergingMap(float t) {
    t = clamp(t, -1.0f, 1.0f);
    float3 low = float3(0.08f, 0.28f, 0.78f);
    float3 center = float3(0.94f);
    float3 high = float3(0.86f, 0.20f, 0.08f);
    return t < 0 ? mix(center, low, -t) : mix(center, high, t);
}

kernel void samplePressureSurface(
    device const float* density [[buffer(0)]],
    device const float4* velocity [[buffer(1)]],
    device const SurfaceVertex* input [[buffer(2)]],
    device ColoredVertex* output [[buffer(3)]],
    device atomic_uint* maximumPressureBits [[buffer(4)]],
    constant VisualizationUniforms& u [[buffer(5)]],
    uint gid [[thread_position_in_grid]]) {
    (void)velocity;
    SurfaceVertex surface = input[gid];
    float3 world = surface.position.xyz + surface.normal.xyz
        * u.scalesAndRanges.z * u.originAndCellSize.w;
    float rho = sampleScalar(density, gridCoordinate(world, u), u.grid.xyz);
    float pressure = (1.0f / 3.0f) * (rho - 1.0f) * u.scalesAndRanges.y;
    float displayed = ((u.flags.y & 4u) != 0u && u.displayOptions.x > 1.0e-8f)
        ? pressure / u.displayOptions.x : pressure;
    float magnitude = abs(displayed);
    atomic_fetch_max_explicit(maximumPressureBits, as_type<uint>(magnitude), memory_order_relaxed);
    uint bin = min(uint(255.0f * magnitude / u.scalesAndRanges.w), 255u);
    atomic_fetch_add_explicit(maximumPressureBits + 1u + bin, 1u, memory_order_relaxed);
    output[gid].position = surface.position;
    output[gid].normal = surface.normal;
    output[gid].color = float4(divergingMap(displayed / u.scalesAndRanges.w), 1);
}

kernel void renderFlowSlice(
    device const float* density [[buffer(0)]],
    device const float4* velocity [[buffer(1)]],
    constant VisualizationUniforms& u [[buffer(2)]],
    device SliceProbeOutput* probe [[buffer(3)]],
    texture2d<float, access::write> output [[texture(0)]],
    uint2 pixel [[thread_position_in_grid]]) {
    (void)density;
    if (any(pixel >= uint2(output.get_width(), output.get_height()))) return;
    float2 uv = (float2(pixel) + 0.5f) / float2(output.get_width(), output.get_height());
    float3 world = u.sliceCenterAndOpacity.xyz
        + (2.0f * uv.x - 1.0f) * u.sliceUAndHalfWidth.w * u.sliceUAndHalfWidth.xyz
        + (2.0f * uv.y - 1.0f) * u.sliceVAndHalfHeight.w * u.sliceVAndHalfHeight.xyz;
    float3 g = gridCoordinate(world, u);
    if (!sampleInside(g, u.grid.xyz) || birdDistance(world, u) <= u.originAndCellSize.w) {
        output.write(float4(0), pixel);
        return;
    }
    float3 value = physicalVelocity(velocity, g, u);
    float3 curl = vorticityAt(velocity, g, u);
    float scalar;
    bool signedField = u.flags.x == 1u;
    if (u.flags.x == 0u) scalar = length(value);
    else if (signedField) scalar = dot(value, u.sliceNormalAndRange.xyz);
    else scalar = length(curl);
    float3 color = signedField
        ? divergingMap(scalar / u.sliceNormalAndRange.w)
        : sequentialMap(scalar / u.sliceNormalAndRange.w);
    if ((u.flags.y & 2u) != 0u) {
        float2 glyphGrid = float2(24.0f, 24.0f);
        float2 glyphCell = floor(uv * glyphGrid);
        float2 glyphUV = (glyphCell + 0.5f) / glyphGrid;
        float3 glyphWorld = u.sliceCenterAndOpacity.xyz
            + (2.0f * glyphUV.x - 1.0f) * u.sliceUAndHalfWidth.w * u.sliceUAndHalfWidth.xyz
            + (2.0f * glyphUV.y - 1.0f) * u.sliceVAndHalfHeight.w * u.sliceVAndHalfHeight.xyz;
        float3 glyphVelocity = physicalVelocity(velocity, gridCoordinate(glyphWorld, u), u);
        float2 direction = float2(dot(glyphVelocity, u.sliceUAndHalfWidth.xyz),
                                  dot(glyphVelocity, u.sliceVAndHalfHeight.xyz));
        direction /= max(length(direction), 1.0e-8f);
        float2 local = fract(uv * glyphGrid) - 0.5f;
        float along = dot(local, direction);
        float across = abs(local.x * direction.y - local.y * direction.x);
        bool shaft = along > -0.3f && along < 0.25f && across < 0.035f;
        float2 tip = local - 0.25f * direction;
        bool head = dot(tip, direction) < 0.0f && dot(tip, direction) > -0.18f
            && abs(tip.x * direction.y - tip.y * direction.x)
                < -dot(tip, direction) * 0.65f;
        if (shaft || head) color = mix(color, float3(1), 0.82f);
    }
    uint2 probePixel = min(
        uint2(u.probeUVAndPadding.xy * float2(output.get_width(), output.get_height())),
        uint2(output.get_width() - 1u, output.get_height() - 1u)
    );
    if (all(pixel == probePixel)) {
        probe[0].worldAndScalar = float4(world, scalar);
        probe[0].velocity = float4(value, length(value));
        probe[0].vorticity = float4(curl, length(curl));
    }
    output.write(float4(color, u.sliceCenterAndOpacity.w), pixel);
}

kernel void deriveFlowDiagnostics(
    device const float* density [[buffer(0)]],
    device const float4* velocity [[buffer(1)]],
    device float4* vorticity [[buffer(2)]],
    device float* qCriterion [[buffer(3)]],
    device uchar* valid [[buffer(4)]],
    constant VisualizationUniforms& u [[buffer(5)]],
    uint gid [[thread_position_in_grid]]) {
    (void)density;
    if (gid >= u.grid.w) return;
    uint3 cell = unflatten(gid, u.grid.xyz);
    bool boundary = any(cell == 0u) || any(cell + 1u >= u.grid.xyz);
    float3 world = u.originAndCellSize.xyz + (float3(cell) + 0.5f) * u.originAndCellSize.w;
    if (boundary || birdDistance(world, u) <= u.originAndCellSize.w) {
        vorticity[gid] = float4(0);
        qCriterion[gid] = 0;
        valid[gid] = uchar(0);
        return;
    }
    float scale = 0.5f * u.scalesAndRanges.x / u.originAndCellSize.w;
    float3 dx = (velocity[flatten(cell + uint3(1,0,0), u.grid.xyz)].xyz
               - velocity[flatten(cell - uint3(1,0,0), u.grid.xyz)].xyz) * scale;
    float3 dy = (velocity[flatten(cell + uint3(0,1,0), u.grid.xyz)].xyz
               - velocity[flatten(cell - uint3(0,1,0), u.grid.xyz)].xyz) * scale;
    float3 dz = (velocity[flatten(cell + uint3(0,0,1), u.grid.xyz)].xyz
               - velocity[flatten(cell - uint3(0,0,1), u.grid.xyz)].xyz) * scale;
    float3 curl = float3(dy.z - dz.y, dz.x - dx.z, dx.y - dy.x);
    float traceSquare = dx.x*dx.x + dy.y*dy.y + dz.z*dz.z
        + 2.0f * (dx.y*dy.x + dx.z*dz.x + dy.z*dz.y);
    vorticity[gid] = float4(curl, length(curl));
    qCriterion[gid] = -0.5f * traceSquare;
    valid[gid] = uchar(1);
}

kernel void summarizeQCriterion(
    device const float* qCriterion [[buffer(0)]],
    device const uchar* valid [[buffer(1)]],
    device atomic_uint* statistics [[buffer(2)]],
    constant VisualizationUniforms& u [[buffer(3)]],
    uint gid [[thread_position_in_grid]]) {
    if (gid >= u.grid.w || valid[gid] == 0 || qCriterion[gid] <= 0.0f) return;
    float q = qCriterion[gid];
    atomic_fetch_max_explicit(statistics, as_type<uint>(q), memory_order_relaxed);
    uint bin = min(uint(255.0f * q / u.displayOptions.w), 255u);
    atomic_fetch_add_explicit(statistics + 1u + bin, 1u, memory_order_relaxed);
}

inline float3 tracerSeed(uint gid, constant VisualizationUniforms& u) {
    uint count = max(u.flags.z, 1u);
    uint halfCount = max(count / 2u, 1u);
    float3 domain = float3(u.grid.xyz) * u.originAndCellSize.w;
    if (gid < halfCount) {
        uint side = uint(ceil(sqrt(float(halfCount))));
        float y = (float(gid % side) + 0.5f) / float(side);
        float z = (float(gid / side) + 0.5f) / float(side);
        return u.originAndCellSize.xyz + float3(0.88f*domain.x, (0.2f+0.6f*y)*domain.y, (0.2f+0.6f*z)*domain.z);
    }
    uint local = gid - halfCount;
    bool left = (local & 1u) == 0u;
    float fraction = float(local / 2u) / max(float((count-halfCount)/2u), 1.0f);
    float3 root = left ? u.leftRoot.xyz : u.rightRoot.xyz;
    float3 span = left ? u.leftSpan.xyz : u.rightSpan.xyz;
    float3 normal = left ? u.leftNormal.xyz : u.rightNormal.xyz;
    return root + span * u.wingGeometry0.x * mix(0.65f, 1.02f, fraction)
        + normal * u.originAndCellSize.w * 2.0f;
}

kernel void advectTracerRibbons(
    device const float* density [[buffer(0)]],
    device const float4* velocity [[buffer(1)]],
    device TracerState* states [[buffer(2)]],
    device float4* history [[buffer(3)]],
    constant VisualizationUniforms& u [[buffer(4)]],
    uint gid [[thread_position_in_grid]]) {
    (void)density;
    if (gid >= u.flags.z) return;
    uint historyLength = u.flags.w;
    TracerState state = states[gid];
    float dt = u.tracerAndIso.x;
    bool reset = (u.flags.y & 1u) != 0u || state.positionAndAge.w <= 0.0f || dt <= 0.0f;
    float3 position = reset ? tracerSeed(gid, u) : state.positionAndAge.xyz;
    float3 g = gridCoordinate(position, u);
    float3 speed = physicalVelocity(velocity, g, u);
    uint substeps = uint(ceil(length(speed) * dt / max(0.5f*u.originAndCellSize.w, 1.0e-8f)));
    if (substeps > 8u || !sampleInside(g, u.grid.xyz)) reset = true;
    if (reset) {
        position = tracerSeed(gid, u);
        speed = physicalVelocity(velocity, gridCoordinate(position, u), u);
        for (uint i = 0; i < historyLength; ++i) history[gid*historyLength+i] = float4(position, 0);
    } else {
        substeps = max(substeps, 1u);
        float h = dt / float(substeps);
        for (uint step = 0; step < substeps; ++step) {
            float3 k1 = physicalVelocity(velocity, gridCoordinate(position, u), u);
            float3 midpoint = position + 0.5f*h*k1;
            float3 k2 = physicalVelocity(velocity, gridCoordinate(midpoint, u), u);
            position += h*k2;
        }
        if (!sampleInside(gridCoordinate(position, u), u.grid.xyz)
            || birdDistance(position, u) <= u.originAndCellSize.w) {
            position = tracerSeed(gid, u);
            for (uint i = 0; i < historyLength; ++i) history[gid*historyLength+i] = float4(position, 0);
        } else {
            for (uint i = historyLength - 1u; i > 0u; --i)
                history[gid*historyLength+i] = history[gid*historyLength+i-1u];
            float colorValue = (u.flags.y & 8u) != 0u
                ? length(vorticityAt(velocity, gridCoordinate(position, u), u))
                : length(speed);
            history[gid*historyLength] = float4(position, colorValue);
        }
    }
    states[gid].positionAndAge = float4(position, state.positionAndAge.w + dt + 1.0e-6f);
    states[gid].velocityAndSpeed = float4(speed, length(speed));
}

constant ushort3 CUBE_CORNERS[8] = {
    ushort3(0,0,0), ushort3(1,0,0), ushort3(1,1,0), ushort3(0,1,0),
    ushort3(0,0,1), ushort3(1,0,1), ushort3(1,1,1), ushort3(0,1,1)
};
constant ushort2 CUBE_EDGES[12] = {
    ushort2(0,1), ushort2(1,2), ushort2(2,3), ushort2(3,0),
    ushort2(4,5), ushort2(5,6), ushort2(6,7), ushort2(7,4),
    ushort2(0,4), ushort2(1,5), ushort2(2,6), ushort2(3,7)
};

inline uint cubeCellCount(uint3 grid) { return (grid.x-1u)*(grid.y-1u)*(grid.z-1u); }
inline uint3 cubePosition(uint gid, uint3 grid) {
    uint3 size = grid - 1u;
    uint xy = size.x * size.y;
    uint z = gid / xy;
    uint r = gid - z*xy;
    uint y = r / size.x;
    return uint3(r-y*size.x, y, z);
}
inline uint3 cornerOffset(uint c) { return uint3(CUBE_CORNERS[c]); }

kernel void classifyQCriterionCubes(
    device const float* q [[buffer(0)]],
    device const uchar* valid [[buffer(1)]],
    device uint* triangleCounts [[buffer(2)]],
    constant VisualizationUniforms& u [[buffer(3)]],
    device const char* triangleTable [[buffer(4)]],
    uint gid [[thread_position_in_grid]]) {
    if (gid >= cubeCellCount(u.grid.xyz)) return;
    uint3 base = cubePosition(gid, u.grid.xyz);
    float values[8];
    for (uint c=0;c<8;++c) {
        uint index=flatten(base+cornerOffset(c),u.grid.xyz);
        if (valid[index]==0) { triangleCounts[gid]=0; return; }
        values[c]=q[index]-u.tracerAndIso.y;
    }
    uint mask=0u;
    for(uint c=0;c<8;++c)if(values[c]>0.0f)mask|=1u<<c;
    uint entryCount=0u;
    while(entryCount<16u&&triangleTable[mask*16u+entryCount]>=0)++entryCount;
    triangleCounts[gid]=entryCount/3u;
}

kernel void scanTriangleBlocks(
    device const uint* counts [[buffer(0)]],
    device uint* offsets [[buffer(1)]],
    device uint* blockSums [[buffer(2)]],
    constant uint& count [[buffer(3)]],
    uint gid [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint group [[threadgroup_position_in_grid]]) {
    threadgroup uint scratch[256];
    uint own = gid < count ? counts[gid] : 0u;
    scratch[tid]=own;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for(uint stride=1u;stride<256u;stride<<=1u){
        uint add=tid>=stride?scratch[tid-stride]:0u;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        scratch[tid]+=add;
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if(gid<count) offsets[gid]=scratch[tid]-own;
    if(tid==255u) blockSums[group]=scratch[tid];
}

kernel void scanBlockSums(
    device const uint* blockSums [[buffer(0)]],
    device uint* blockOffsets [[buffer(1)]],
    constant uint& blockCount [[buffer(2)]],
    uint gid [[thread_position_in_grid]]) {
    if(gid!=0u)return;
    uint sum=0;
    for(uint i=0;i<blockCount;++i){blockOffsets[i]=sum;sum+=blockSums[i];}
}

kernel void addTriangleBlockOffsets(
    device uint* offsets [[buffer(0)]],
    device const uint* blockOffsets [[buffer(1)]],
    constant uint& count [[buffer(2)]],
    uint gid [[thread_position_in_grid]]) {
    if(gid<count) offsets[gid]+=blockOffsets[gid/256u];
}

struct DrawPrimitivesIndirectArguments {
    uint vertexCount; uint instanceCount; uint vertexStart; uint baseInstance;
};

kernel void prepareQCriterionIndirectDraw(
    device const uint* counts [[buffer(0)]],
    device const uint* offsets [[buffer(1)]],
    device DrawPrimitivesIndirectArguments* arguments [[buffer(2)]],
    device uint* overflow [[buffer(3)]],
    constant uint2& countAndCapacity [[buffer(4)]],
    uint gid [[thread_position_in_grid]]) {
    if(gid!=0u)return;
    uint count=countAndCapacity.x;
    uint total=count==0u?0u:offsets[count-1u]+counts[count-1u];
    bool exceeded=total>countAndCapacity.y;
    overflow[0]=exceeded?1u:0u;
    arguments[0].vertexCount=exceeded?0u:total*3u;
    arguments[0].instanceCount=1u;
    arguments[0].vertexStart=0u;
    arguments[0].baseInstance=0u;
}

inline float3 qGradientAt(
    device const float* q,
    uint3 cell,
    constant VisualizationUniforms& u
) {
    int3 center=int3(cell);
    int3 maximum=int3(u.grid.xyz)-1;
    int3 lowerX=max(center-int3(1,0,0),int3(0));
    int3 upperX=min(center+int3(1,0,0),maximum);
    int3 lowerY=max(center-int3(0,1,0),int3(0));
    int3 upperY=min(center+int3(0,1,0),maximum);
    int3 lowerZ=max(center-int3(0,0,1),int3(0));
    int3 upperZ=min(center+int3(0,0,1),maximum);
    float dx=max(float(upperX.x-lowerX.x)*u.originAndCellSize.w,1.0e-12f);
    float dy=max(float(upperY.y-lowerY.y)*u.originAndCellSize.w,1.0e-12f);
    float dz=max(float(upperZ.z-lowerZ.z)*u.originAndCellSize.w,1.0e-12f);
    return float3(
        (q[flatten(uint3(upperX),u.grid.xyz)]-q[flatten(uint3(lowerX),u.grid.xyz)])/dx,
        (q[flatten(uint3(upperY),u.grid.xyz)]-q[flatten(uint3(lowerY),u.grid.xyz)])/dy,
        (q[flatten(uint3(upperZ),u.grid.xyz)]-q[flatten(uint3(lowerZ),u.grid.xyz)])/dz
    );
}

kernel void emitQCriterionCubes(
    device const float* q [[buffer(0)]],
    device const uchar* valid [[buffer(1)]],
    device const uint* counts [[buffer(2)]],
    device const uint* offsets [[buffer(3)]],
    device IsoVertex* output [[buffer(4)]],
    constant VisualizationUniforms& u [[buffer(5)]],
    device const float4* vorticity [[buffer(6)]],
    device const char* triangleTable [[buffer(7)]],
    uint gid [[thread_position_in_grid]]) {
    (void)valid;
    if(gid>=cubeCellCount(u.grid.xyz)||counts[gid]==0u)return;
    if(offsets[gid]+counts[gid]>uint(u.tracerAndIso.w))return;
    uint3 base=cubePosition(gid,u.grid.xyz);
    float values[8];float3 points[8];float3 gradients[8];float omega[8];
    uint mask=0u;
    for(uint c=0;c<8;++c){
        uint3 cell=base+cornerOffset(c);uint index=flatten(cell,u.grid.xyz);
        values[c]=q[index]-u.tracerAndIso.y;
        points[c]=u.originAndCellSize.xyz+(float3(cell)+0.5f)*u.originAndCellSize.w;
        gradients[c]=qGradientAt(q,cell,u);omega[c]=vorticity[index].w;
        if(values[c]>0.0f)mask|=1u<<c;
    }
    uint triangle=offsets[gid];
    for(uint localTriangle=0u;localTriangle<counts[gid];++localTriangle){
        uint baseVertex=(triangle+localTriangle)*3u;
        for(uint vertexIndex=0u;vertexIndex<3u;++vertexIndex){
            int edgeIndex=int(triangleTable[mask*16u+localTriangle*3u+vertexIndex]);
            ushort2 edge=CUBE_EDGES[uint(edgeIndex)];
            uint a=edge.x,b=edge.y;
            float fraction=clamp(values[a]/(values[a]-values[b]),0.0f,1.0f);
            float3 position=mix(points[a],points[b],fraction);
            float3 normal=normalize(mix(gradients[a],gradients[b],fraction)+float3(1.0e-20f));
            float omegaValue=mix(omega[a],omega[b],fraction);
            output[baseVertex+vertexIndex]={float4(position,1),float4(normal,omegaValue)};
        }
    }
}

vertex RasterVertex coloredSurfaceVertex(
    device const ColoredVertex* vertices [[buffer(0)]],
    constant CameraUniforms& camera [[buffer(1)]],
    uint vid [[vertex_id]]) {
    ColoredVertex source=vertices[vid]; RasterVertex out;
    out.position=camera.viewProjection*source.position;out.world=source.position.xyz;
    out.normal=normalize(source.normal.xyz);out.color=source.color;out.uv=float2(0);return out;
}

vertex RasterVertex isoSurfaceVertex(
    device const IsoVertex* vertices [[buffer(0)]],
    constant CameraUniforms& camera [[buffer(1)]],
    constant VisualizationUniforms& u [[buffer(2)]],
    uint vid [[vertex_id]]) {
    IsoVertex source=vertices[vid];RasterVertex out;
    out.position=camera.viewProjection*source.position;out.world=source.position.xyz;
    float scalar=(u.flags.y&32u)!=0u?source.normal.w:u.tracerAndIso.y;
    float range=(u.flags.y&32u)!=0u?u.displayOptions.z:u.displayOptions.w;
    out.normal=normalize(source.normal.xyz);out.color=float4(sequentialMap(scalar/range),u.tracerAndIso.z);out.uv=float2(0);return out;
}

fragment float4 isoFragment(
    RasterVertex in [[stage_in]],
    constant VisualizationUniforms& u [[buffer(0)]]) {
    if ((u.flags.y & 16u) != 0u
        && dot(in.world-u.sliceCenterAndOpacity.xyz,u.sliceNormalAndRange.xyz)<0.0f)
        discard_fragment();
    float light=0.28f+0.72f*abs(dot(normalize(in.normal),normalize(float3(0.4f,-0.5f,0.75f))));
    return float4(in.color.rgb*light,in.color.a);
}

fragment float4 litFragment(RasterVertex in [[stage_in]]) {
    float light=0.28f+0.72f*abs(dot(normalize(in.normal),normalize(float3(0.4f,-0.5f,0.75f))));
    return float4(in.color.rgb*light,in.color.a);
}

fragment float4 showcaseDoveFragment(
    RasterVertex in [[stage_in]],
    constant CameraUniforms& camera [[buffer(0)]]) {
    float3 normal=normalize(in.normal);
    float3 view=normalize(camera.eyeAndWidth.xyz-in.world);
    float3 key=normalize(float3(0.38f,-0.48f,0.80f));
    float3 fill=normalize(float3(-0.72f,0.22f,0.46f));
    float keyLight=abs(dot(normal,key));
    float fillLight=abs(dot(normal,fill));
    float diffuse=0.25f+0.64f*keyLight+0.13f*fillLight;
    float rim=pow(1.0f-abs(dot(normal,view)),2.35f);
    float3 halfVector=normalize(key+view);
    float specular=pow(abs(dot(normal,halfVector)),38.0f);
    float3 color=in.color.rgb*diffuse;
    color+=rim*mix(float3(0.05f,0.28f,0.48f),in.color.rgb,0.38f);
    color+=0.22f*specular*float3(0.72f,0.90f,1.0f);
    color=1.0f-exp(-1.08f*color);
    return float4(color,in.color.a);
}

fragment float4 showcaseWireFragment(RasterVertex in [[stage_in]]) {
    float intensity=0.025f+0.055f*clamp(in.color.g+in.color.b,0.0f,1.0f);
    return float4(0.48f,0.88f,1.0f,intensity);
}

vertex RasterVertex showcaseBackgroundVertex(uint vid [[vertex_id]]) {
    float2 positions[3]={float2(-1,-1),float2(3,-1),float2(-1,3)};
    RasterVertex out;
    out.position=float4(positions[vid],0.999f,1);
    out.world=float3(0);out.normal=float3(0,0,1);out.color=float4(1);
    out.uv=0.5f*(positions[vid]+1.0f);
    return out;
}

fragment float4 showcaseBackgroundFragment(
    RasterVertex in [[stage_in]],
    constant float4& options [[buffer(0)]]) {
    float2 uv=in.uv;
    float2 centered=uv-0.5f;
    centered.x*=options.y;
    float radial=length(centered);
    float glow=exp(-4.8f*dot(centered-float2(-0.12f,0.02f),centered-float2(-0.12f,0.02f)));
    float horizon=exp(-68.0f*(uv.y-0.43f)*(uv.y-0.43f));
    float pulse=0.5f+0.5f*cos(6.2831853f*options.x);
    float gridX=smoothstep(0.990f,1.0f,cos(94.0f*centered.x));
    float gridY=smoothstep(0.990f,1.0f,cos(94.0f*(uv.y-0.43f)));
    float grid=(gridX+gridY)*horizon*0.032f;
    float vignette=1.0f-smoothstep(0.20f,0.92f,radial);
    float3 base=mix(float3(0.002f,0.007f,0.019f),float3(0.014f,0.048f,0.088f),uv.y);
    base+=glow*float3(0.018f,0.070f,0.105f);
    base+=horizon*(0.014f+0.004f*pulse)*float3(0.10f,0.46f,0.70f);
    base+=grid*float3(0.16f,0.58f,0.82f);
    base*=0.72f+0.28f*vignette;
    return float4(base,1);
}

vertex RasterVertex showcasePostVertex(uint vid [[vertex_id]]) {
    float2 positions[3]={float2(-1,-1),float2(3,-1),float2(-1,3)};
    RasterVertex out;
    out.position=float4(positions[vid],0,1);
    out.world=float3(0);out.normal=float3(0,0,1);out.color=float4(1);
    out.uv=0.5f*(positions[vid]+1.0f);
    return out;
}

inline float showcaseBloomWeight(float3 color) {
    float luminance=dot(color,float3(0.2126f,0.7152f,0.0722f));
    return smoothstep(0.18f,0.82f,luminance);
}

fragment float4 showcaseBloomFragment(
    RasterVertex in [[stage_in]],
    texture2d<float> scene [[texture(0)]]) {
    constexpr sampler s(filter::linear,address::clamp_to_edge);
    float2 texel=1.0f/float2(scene.get_width(),scene.get_height());
    const float weights[3]={0.40262f,0.24420f,0.05449f};
    float3 bloom=float3(0);
    for(int y=-2;y<=2;++y){
        for(int x=-2;x<=2;++x){
            float3 sampleColor=scene.sample(
                s,in.uv+float2(x,y)*texel*4.2f).rgb;
            float weight=weights[abs(x)]*weights[abs(y)];
            bloom+=weight*sampleColor*showcaseBloomWeight(sampleColor);
        }
    }
    return float4(bloom,1);
}

fragment float4 showcaseCompositeFragment(
    RasterVertex in [[stage_in]],
    constant float4& finishing [[buffer(0)]],
    texture2d<float> scene [[texture(0)]],
    texture2d<float> bloom [[texture(1)]]) {
    constexpr sampler s(filter::linear,address::clamp_to_edge);
    float3 base=scene.sample(s,in.uv).rgb;
    float3 glow=bloom.sample(s,in.uv).rgb;
    float3 color=(base+finishing.x*glow)*finishing.y;
    float3 excess=max(color-0.94f,0.0f);
    color=min(color-excess+0.06f*(1.0f-exp(-4.0f*excess)),1.0f);
    float2 centered=in.uv-0.5f;
    float vignette=1.0f-0.10f*smoothstep(0.28f,0.72f,length(centered));
    color*=vignette;
    color=mix(color,color*float3(0.96f,1.01f,1.05f),0.18f);
    return float4(color,1);
}

vertex RasterVertex sliceVertex(
    constant VisualizationUniforms& u [[buffer(0)]],
    constant CameraUniforms& camera [[buffer(1)]],
    uint vid [[vertex_id]]) {
    float2 corners[6]={float2(-1,-1),float2(1,-1),float2(1,1),float2(-1,-1),float2(1,1),float2(-1,1)};
    float2 c=corners[vid];float3 world=u.sliceCenterAndOpacity.xyz+c.x*u.sliceUAndHalfWidth.w*u.sliceUAndHalfWidth.xyz+c.y*u.sliceVAndHalfHeight.w*u.sliceVAndHalfHeight.xyz;
    RasterVertex out;out.position=camera.viewProjection*float4(world,1);out.world=world;out.normal=u.sliceNormalAndRange.xyz;out.color=float4(1);out.uv=0.5f*(c+1.0f);return out;
}

fragment float4 sliceFragment(RasterVertex in [[stage_in]],texture2d<float> texture [[texture(0)]]) {
    constexpr sampler s(filter::linear,address::clamp_to_edge);return texture.sample(s,in.uv);
}

vertex RasterVertex ribbonVertex(
    device const float4* history [[buffer(0)]],
    constant CameraUniforms& camera [[buffer(1)]],
    constant uint& tracerIndex [[buffer(2)]],
    constant uint& historyLength [[buffer(3)]],
    constant VisualizationUniforms& u [[buffer(4)]],
    uint vid [[vertex_id]]) {
    uint segment=min(vid/2u,historyLength-1u);float side=(vid&1u)?1.0f:-1.0f;
    uint base=tracerIndex*historyLength;float3 p=history[base+segment].xyz;
    float3 previous=history[base+(segment>0u?segment-1u:segment)].xyz;
    float3 next=history[base+min(segment+1u,historyLength-1u)].xyz;
    float3 tangent=normalize(next-previous+float3(1.0e-12f,0,0));
    float3 view=normalize(camera.eyeAndWidth.xyz-p);float3 lateral=normalize(cross(view,tangent));
    float age=1.0f-float(segment)/max(float(historyLength-1u),1.0f);float3 world=p+lateral*camera.eyeAndWidth.w*side*age;
    RasterVertex out;out.position=camera.viewProjection*float4(world,1);out.world=world;out.normal=view;
    out.color=float4(sequentialMap(history[base+segment].w/u.displayOptions.z),0.7f*age);out.uv=float2(0);return out;
}

fragment float4 unlitFragment(RasterVertex in [[stage_in]]) { return in.color; }
