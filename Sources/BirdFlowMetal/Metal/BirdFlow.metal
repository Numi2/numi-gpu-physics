#include <metal_stdlib>
using namespace metal;

constant uint Q = 19;
constant float CS2 = 1.0f / 3.0f;

constant int3 C[19] = {
    int3(0, 0, 0),
    int3(1, 0, 0), int3(-1, 0, 0),
    int3(0, 1, 0), int3(0, -1, 0),
    int3(0, 0, 1), int3(0, 0, -1),
    int3(1, 1, 0), int3(-1, -1, 0),
    int3(1, -1, 0), int3(-1, 1, 0),
    int3(1, 0, 1), int3(-1, 0, -1),
    int3(1, 0, -1), int3(-1, 0, 1),
    int3(0, 1, 1), int3(0, -1, -1),
    int3(0, 1, -1), int3(0, -1, 1)
};

constant uint OPP[19] = {
    0,
    2, 1,
    4, 3,
    6, 5,
    8, 7,
    10, 9,
    12, 11,
    14, 13,
    16, 15,
    18, 17
};

constant float W[19] = {
    1.0f / 3.0f,
    1.0f / 18.0f, 1.0f / 18.0f,
    1.0f / 18.0f, 1.0f / 18.0f,
    1.0f / 18.0f, 1.0f / 18.0f,
    1.0f / 36.0f, 1.0f / 36.0f,
    1.0f / 36.0f, 1.0f / 36.0f,
    1.0f / 36.0f, 1.0f / 36.0f,
    1.0f / 36.0f, 1.0f / 36.0f,
    1.0f / 36.0f, 1.0f / 36.0f,
    1.0f / 36.0f, 1.0f / 36.0f
};

struct GPUUniforms {
    uint4 grid;
    float4 originAndCellSize;
    float4 timeStepAndScales;
    float4 latticeAndSponge;
    float4 farFieldLattice;
    float4 gravity;
    float4 caseParameters;
    uint4 flags;
};

struct GPUBirdParameters {
    float4 bodyRadiiAndMass;
    float4 inertia;
    float4 wingGeometry0;
    float4 wingGeometry1;
    float4 tailGeometry;
    float4 wingKinematics0;
    float4 wingKinematics1;
};

struct GPUBirdBodyState {
    float4 position;
    float4 orientation;
    float4 linearVelocity;
    float4 angularVelocityBody;
};

struct GPUPreparedBirdGeometry {
    float4 bodyPosition;
    float4 orientation;
    float4 linearVelocity;
    float4 omegaBodyWorld;
    float4 leftRoot;
    float4 leftChord;
    float4 leftSpan;
    float4 leftNormal;
    float4 leftAngularVelocity;
    float4 rightRoot;
    float4 rightChord;
    float4 rightSpan;
    float4 rightNormal;
    float4 rightAngularVelocity;
};

struct GPUFlappingWingParameters {
    float4 rootAndChord;
    float4 geometry;
    float4 kinematics0;
    float4 kinematics1;
};

struct GPUPreparedFlappingWing {
    float4 root;
    float4 chord;
    float4 span;
    float4 normal;
    float4 angularVelocity;
    float4 state;
};

struct GPUForceTorque {
    float4 force;
    float4 torque;
};

inline uint flatten(uint3 p, uint3 size) {
    return p.x + size.x * (p.y + size.y * p.z);
}

inline uint3 unflatten(uint index, uint3 size) {
    uint xy = size.x * size.y;
    uint z = index / xy;
    uint remainder = index - z * xy;
    uint y = remainder / size.x;
    uint x = remainder - y * size.x;
    return uint3(x, y, z);
}

inline float3 cellPosition(uint3 cell, constant GPUUniforms& uniforms) {
    return uniforms.originAndCellSize.xyz
        + (float3(cell) + 0.5f) * uniforms.originAndCellSize.w;
}

inline float4 quaternionConjugate(float4 q) {
    return float4(-q.xyz, q.w);
}

inline float4 quaternionMultiply(float4 a, float4 b) {
    return float4(
        a.w * b.xyz + b.w * a.xyz + cross(a.xyz, b.xyz),
        a.w * b.w - dot(a.xyz, b.xyz)
    );
}

inline float4 quaternionNormalize(float4 q) {
    float n2 = dot(q, q);
    return n2 > 1.0e-20f ? q * rsqrt(n2) : float4(0, 0, 0, 1);
}

inline float3 quaternionRotate(float4 q, float3 v) {
    float3 t = 2.0f * cross(q.xyz, v);
    return v + q.w * t + cross(q.xyz, t);
}

inline float3 quaternionUnrotate(float4 q, float3 v) {
    return quaternionRotate(quaternionConjugate(q), v);
}

inline float3 rotateAroundAxis(float3 value, float3 axis, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return value * c
        + cross(axis, value) * s
        + axis * dot(axis, value) * (1.0f - c);
}

inline float equilibrium(uint q, float rho, float3 velocity) {
    float3 direction = float3(C[q]);
    float cu = dot(direction, velocity);
    float u2 = dot(velocity, velocity);
    return W[q] * rho
        * (1.0f + 3.0f * cu + 4.5f * cu * cu - 1.5f * u2);
}

inline float sdEllipsoid(float3 p, float3 radii) {
    float k0 = length(p / radii);
    float k1 = length(p / (radii * radii));
    return k1 > 1.0e-12f
        ? k0 * (k0 - 1.0f) / k1
        : -min(radii.x, min(radii.y, radii.z));
}

inline float sdTaperedWing(
    float3 local,
    float span,
    float rootChord,
    float tipChord,
    float thickness,
    float sweep
) {
    float spanFraction = clamp(local.y / max(span, 1.0e-6f), 0.0f, 1.0f);
    float chord = mix(rootChord, tipChord, spanFraction);
    float chordCenter = -sweep * spanFraction;

    float dx = abs(local.x - chordCenter) - 0.5f * chord;
    float dy = max(-local.y, local.y - span);
    float dz = abs(local.z) - 0.5f * thickness;
    float3 q = float3(dx, dy, dz);
    return length(max(q, float3(0)))
        + min(max(q.x, max(q.y, q.z)), 0.0f);
}

inline float sdTail(
    float3 bodyLocal,
    float3 bodyRadii,
    float4 tailGeometry
) {
    float tailLength = tailGeometry.x;
    float halfWidth = tailGeometry.y;
    float thickness = tailGeometry.z;

    float xFromRoot = -(bodyLocal.x + bodyRadii.x);
    float fraction = clamp(xFromRoot / max(tailLength, 1.0e-6f), 0.0f, 1.0f);
    float localHalfWidth = mix(0.35f * halfWidth, halfWidth, fraction);

    float dx = max(-xFromRoot, xFromRoot - tailLength);
    float dy = abs(bodyLocal.y) - localHalfWidth;
    float dz = abs(bodyLocal.z + 0.15f * bodyRadii.z) - 0.5f * thickness;
    float3 q = float3(dx, dy, dz);
    return length(max(q, float3(0)))
        + min(max(q.x, max(q.y, q.z)), 0.0f);
}

struct WingFrame {
    float3 root;
    float3 chord;
    float3 span;
    float3 normal;
    float3 relativeAngularVelocity;
};

inline WingFrame makeWingFrame(
    float side,
    float stroke,
    float strokeRate,
    float pitch,
    float pitchRate,
    constant GPUBirdParameters& bird,
    constant GPUBirdBodyState& body
) {
    float4 orientation = quaternionNormalize(body.orientation);
    float3 bodyX = quaternionRotate(orientation, float3(1, 0, 0));
    float3 bodyY = quaternionRotate(orientation, float3(0, 1, 0));
    float3 bodyZ = quaternionRotate(orientation, float3(0, 0, 1));

    float3 rootLocal = float3(
        bird.wingGeometry1.y,
        side * bird.wingGeometry1.z,
        bird.wingGeometry1.w
    );
    float3 root = body.position.xyz
        + quaternionRotate(orientation, rootLocal);

    float signedStroke = side * stroke;
    float3 span = rotateAroundAxis(side * bodyY, bodyX, signedStroke);
    float3 normal = rotateAroundAxis(side * bodyZ, bodyX, signedStroke);
    float3 chord = rotateAroundAxis(bodyX, span, pitch);
    normal = rotateAroundAxis(normal, span, pitch);

    WingFrame frame;
    frame.root = root;
    frame.chord = normalize(chord);
    frame.span = normalize(span);
    frame.normal = normalize(normal);
    frame.relativeAngularVelocity = bodyX * (side * strokeRate)
        + frame.span * pitchRate;
    return frame;
}

kernel void prepareBirdGeometry(
    device GPUPreparedBirdGeometry* prepared [[buffer(0)]],
    constant GPUBirdParameters& bird [[buffer(1)]],
    constant GPUBirdBodyState& body [[buffer(2)]],
    constant GPUUniforms& uniforms [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid != 0u) {
        return;
    }

    float angularFrequency = 2.0f
        * 3.14159265358979323846f
        * bird.wingKinematics0.x;
    float phase = angularFrequency * uniforms.timeStepAndScales.x;
    float stroke = bird.wingKinematics0.z
        + bird.wingKinematics0.y * sin(phase);
    float strokeRate = angularFrequency
        * bird.wingKinematics0.y
        * cos(phase);
    float pitch = bird.wingKinematics0.w
        + bird.wingKinematics1.x
        * sin(phase + bird.wingKinematics1.y);
    float pitchRate = angularFrequency
        * bird.wingKinematics1.x
        * cos(phase + bird.wingKinematics1.y);

    WingFrame left = makeWingFrame(
        1.0f,
        stroke,
        strokeRate,
        pitch,
        pitchRate,
        bird,
        body
    );
    WingFrame right = makeWingFrame(
        -1.0f,
        stroke,
        strokeRate,
        pitch,
        pitchRate,
        bird,
        body
    );
    float4 orientation = quaternionNormalize(body.orientation);

    prepared[0].bodyPosition = body.position;
    prepared[0].orientation = orientation;
    prepared[0].linearVelocity = body.linearVelocity;
    float bodyRadius = length(bird.bodyRadiiAndMass.xyz);
    float tailRadius = length(float3(
        bird.bodyRadiiAndMass.x + bird.tailGeometry.x,
        max(bird.bodyRadiiAndMass.y, bird.tailGeometry.y),
        bird.bodyRadiiAndMass.z + 0.5f * bird.tailGeometry.z
    ));
    float rootRadius = length(float3(
        bird.wingGeometry1.y,
        bird.wingGeometry1.z,
        bird.wingGeometry1.w
    ));
    float wingRadius = rootRadius
        + bird.wingGeometry0.x
        + abs(bird.wingGeometry1.x)
        + 0.5f * max(bird.wingGeometry0.y, bird.wingGeometry0.z)
        + 0.5f * bird.wingGeometry0.w;
    float geometryRadius = max(bodyRadius, max(tailRadius, wingRadius))
        + 2.0f * uniforms.originAndCellSize.w;
    prepared[0].omegaBodyWorld = float4(
        quaternionRotate(orientation, body.angularVelocityBody.xyz),
        geometryRadius
    );
    prepared[0].leftRoot = float4(left.root, 0);
    prepared[0].leftChord = float4(left.chord, 0);
    prepared[0].leftSpan = float4(left.span, 0);
    prepared[0].leftNormal = float4(left.normal, 0);
    prepared[0].leftAngularVelocity = float4(
        left.relativeAngularVelocity,
        0
    );
    prepared[0].rightRoot = float4(right.root, 0);
    prepared[0].rightChord = float4(right.chord, 0);
    prepared[0].rightSpan = float4(right.span, 0);
    prepared[0].rightNormal = float4(right.normal, 0);
    prepared[0].rightAngularVelocity = float4(
        right.relativeAngularVelocity,
        0
    );
}

kernel void buildBirdGeometry(
    device uchar* solid [[buffer(0)]],
    device float4* wallVelocity [[buffer(1)]],
    device const uchar* solidPrevious [[buffer(2)]],
    constant GPUBirdParameters& bird [[buffer(3)]],
    device const GPUPreparedBirdGeometry& prepared [[buffer(4)]],
    constant GPUUniforms& uniforms [[buffer(5)]],
    uint3 cell [[thread_position_in_grid]]
) {
    uint3 size = uniforms.grid.xyz;
    if (any(cell >= size)) {
        return;
    }

    uint gid = flatten(cell, size);
    float3 world = cellPosition(cell, uniforms);
    float3 relativeBody = world - prepared.bodyPosition.xyz;
    bool wasSolid = uniforms.flags.z != 0u && solidPrevious[gid] != 0;
    float geometryRadius = prepared.omegaBodyWorld.w;
    if (!wasSolid && dot(relativeBody, relativeBody) > geometryRadius * geometryRadius) {
        solid[gid] = uchar(0);
        wallVelocity[gid] = float4(0);
        return;
    }
    float3 bodyLocal = quaternionUnrotate(
        prepared.orientation,
        relativeBody
    );
    float3 baseVelocity = prepared.linearVelocity.xyz
        + cross(prepared.omegaBodyWorld.xyz, relativeBody);

    float bestDistance = sdEllipsoid(
        bodyLocal,
        bird.bodyRadiiAndMass.xyz
    );
    float3 bestVelocity = baseVelocity;
    uint bestPart = 1;

    for (uint wing = 0; wing < 2; ++wing) {
        WingFrame frame;
        if (wing == 0u) {
            frame.root = prepared.leftRoot.xyz;
            frame.chord = prepared.leftChord.xyz;
            frame.span = prepared.leftSpan.xyz;
            frame.normal = prepared.leftNormal.xyz;
            frame.relativeAngularVelocity = prepared.leftAngularVelocity.xyz;
        }
        else {
            frame.root = prepared.rightRoot.xyz;
            frame.chord = prepared.rightChord.xyz;
            frame.span = prepared.rightSpan.xyz;
            frame.normal = prepared.rightNormal.xyz;
            frame.relativeAngularVelocity = prepared.rightAngularVelocity.xyz;
        }
        float3 relative = world - frame.root;
        float3 local = float3(
            dot(relative, frame.chord),
            dot(relative, frame.span),
            dot(relative, frame.normal)
        );
        float distance = sdTaperedWing(
            local,
            bird.wingGeometry0.x,
            bird.wingGeometry0.y,
            bird.wingGeometry0.z,
            bird.wingGeometry0.w,
            bird.wingGeometry1.x
        );

        if (distance < bestDistance) {
            bestDistance = distance;
            bestVelocity = baseVelocity
                + cross(
                    frame.relativeAngularVelocity,
                    world - frame.root
                );
            bestPart = wing == 0 ? 2 : 3;
        }
    }

    float tailDistance = sdTail(
        bodyLocal,
        bird.bodyRadiiAndMass.xyz,
        bird.tailGeometry
    );
    if (tailDistance < bestDistance) {
        bestDistance = tailDistance;
        bestVelocity = baseVelocity;
        bestPart = 4;
    }

    bool isSolid = bestDistance <= 0.0f;
    // Occupancy and body-part identity share one byte: 0 is fluid, 1...4
    // identify body, left wing, right wing, and tail respectively.
    solid[gid] = isSolid ? uchar(bestPart) : uchar(0);
    wallVelocity[gid] = float4(
        bestVelocity * uniforms.timeStepAndScales.z,
        0
    );
}

inline float unitCyclePhase(float time, float cycleSteps) {
    float phase = fmod(time / cycleSteps, 1.0f);
    return phase < 0.0f ? phase + 1.0f : phase;
}

inline float2 prescribedStrokeKinematics(
    float phase,
    constant GPUFlappingWingParameters& wing
) {
    const float pi = 3.14159265358979323846f;
    float amplitude = wing.kinematics0.y;
    float duration = wing.kinematics0.z;
    float halfDuration = 0.5f * duration;
    float maximumRate = wing.kinematics1.z;
    float angle;
    float rate;

    if (phase < halfDuration) {
        float argument = pi * (phase + halfDuration) / duration;
        angle = amplitude + maximumRate * duration / pi
            * (sin(argument) - 1.0f);
        rate = maximumRate * cos(argument);
    }
    else if (phase < 0.5f - halfDuration) {
        float atTransitionEnd = amplitude
            - maximumRate * duration / pi;
        angle = atTransitionEnd
            - maximumRate * (phase - halfDuration);
        rate = -maximumRate;
    }
    else if (phase < 0.5f + halfDuration) {
        float start = 0.5f - halfDuration;
        float atTransitionStart = -amplitude
            + maximumRate * duration / pi;
        float argument = pi * (phase - start) / duration;
        angle = atTransitionStart
            - maximumRate * duration / pi * sin(argument);
        rate = -maximumRate * cos(argument);
    }
    else if (phase < 1.0f - halfDuration) {
        float atTransitionEnd = -amplitude
            + maximumRate * duration / pi;
        angle = atTransitionEnd
            + maximumRate * (phase - (0.5f + halfDuration));
        rate = maximumRate;
    }
    else {
        float start = 1.0f - halfDuration;
        float atTransitionStart = amplitude
            - maximumRate * duration / pi;
        float argument = pi * (phase - start) / duration;
        angle = atTransitionStart
            + maximumRate * duration / pi * sin(argument);
        rate = maximumRate * cos(argument);
    }
    return float2(angle, rate);
}

inline float2 prescribedPitchKinematics(
    float phase,
    constant GPUFlappingWingParameters& wing
) {
    const float pi = 3.14159265358979323846f;
    float duration = wing.kinematics0.w;
    float halfDuration = 0.5f * duration;
    float low = wing.kinematics1.x;
    float high = wing.kinematics1.y;
    float delta = high - low;
    float x;
    float start;
    float change;

    if (phase < halfDuration || phase >= 1.0f - halfDuration) {
        float wrapped = phase < halfDuration ? phase + 1.0f : phase;
        x = (wrapped - (1.0f - halfDuration)) / duration;
        start = high;
        change = -delta;
    }
    else if (phase >= 0.5f - halfDuration
        && phase < 0.5f + halfDuration) {
        x = (phase - (0.5f - halfDuration)) / duration;
        start = low;
        change = delta;
    }
    else {
        return phase < 0.5f
            ? float2(low, 0.0f)
            : float2(high, 0.0f);
    }

    float blend = x - sin(2.0f * pi * x) / (2.0f * pi);
    float rate = change / duration
        * (1.0f - cos(2.0f * pi * x));
    return float2(start + change * blend, rate);
}

/// Builds the rigid frame once per time step. Keeping all trigonometry here
/// prevents millions of redundant sin/cos evaluations in the voxel pass.
kernel void preparePrescribedFlappingWing(
    device GPUPreparedFlappingWing* prepared [[buffer(0)]],
    constant GPUFlappingWingParameters& wing [[buffer(1)]],
    constant GPUUniforms& uniforms [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid != 0u) {
        return;
    }

    float cycleSteps = wing.kinematics0.x;
    float phase = unitCyclePhase(
        uniforms.timeStepAndScales.x,
        cycleSteps
    );
    float2 stroke = prescribedStrokeKinematics(phase, wing);
    float2 pitch = prescribedPitchKinematics(phase, wing);
    float3 rotationAxis = float3(0, 0, 1);
    float3 span = float3(cos(stroke.x), sin(stroke.x), 0);
    float3 tangent = cross(rotationAxis, span);
    // The paper's pitch angle is measured opposite Metal's right-hand
    // rotation about the outward span axis.
    float3 chord = rotateAroundAxis(tangent, span, -pitch.x);
    float3 normal = normalize(cross(span, chord));
    float inverseCycleSteps = 1.0f / cycleSteps;
    float3 angularVelocity = rotationAxis
            * (stroke.y * inverseCycleSteps)
        - span * (pitch.y * inverseCycleSteps);

    prepared[0].root = wing.rootAndChord;
    prepared[0].chord = float4(normalize(chord), 0);
    prepared[0].span = float4(normalize(span), 0);
    prepared[0].normal = float4(normal, 0);
    prepared[0].angularVelocity = float4(angularVelocity, 0);
    prepared[0].state = float4(
        stroke.x,
        pitch.x,
        stroke.y * inverseCycleSteps,
        pitch.y * inverseCycleSteps
    );
}

/// Voxelizes the analytic beta-planform wing. The bounding-sphere and slab
/// checks reject almost every cell before the only pow() in this kernel.
kernel void buildPrescribedFlappingWing(
    device uchar* solid [[buffer(0)]],
    device float4* wallVelocity [[buffer(1)]],
    device const uchar* solidPrevious [[buffer(2)]],
    constant GPUFlappingWingParameters& wing [[buffer(3)]],
    device const GPUPreparedFlappingWing& prepared [[buffer(4)]],
    constant GPUUniforms& uniforms [[buffer(5)]],
    uint3 cell [[thread_position_in_grid]]
) {
    uint3 size = uniforms.grid.xyz;
    if (any(cell >= size)) {
        return;
    }

    uint gid = flatten(cell, size);
    float3 world = cellPosition(cell, uniforms);
    float3 relative = world - prepared.root.xyz;
    bool wasSolid = uniforms.flags.z != 0u && solidPrevious[gid] != 0;
    float chordMean = wing.rootAndChord.w;
    float radius = wing.geometry.x
        + 1.5f * chordMean
        + 2.0f * uniforms.originAndCellSize.w;
    if (!wasSolid && dot(relative, relative) > radius * radius) {
        solid[gid] = uchar(0);
        wallVelocity[gid] = float4(0);
        return;
    }

    float chordCoordinate = dot(relative, prepared.chord.xyz);
    float radialCoordinate = dot(relative, prepared.span.xyz);
    float normalCoordinate = dot(relative, prepared.normal.xyz);
    float halfThickness = 0.5f * max(
        wing.geometry.y,
        uniforms.originAndCellSize.w
    );
    bool inRadialSlab = radialCoordinate >= 0.0f
        && radialCoordinate <= wing.geometry.x;
    bool inNormalSlab = abs(normalCoordinate) <= halfThickness;
    bool isWing = false;
    if (inRadialSlab && inNormalSlab) {
        float radialFraction = clamp(
            radialCoordinate / wing.geometry.x,
            0.0f,
            1.0f
        );
        float betaBase = max(
            radialFraction * (1.0f - radialFraction),
            0.0f
        );
        float localChord = chordMean
            * wing.geometry.w
            * pow(betaBase, wing.geometry.z);
        float leadingEdge = -0.25f * chordMean;
        float trailingEdge = leadingEdge + localChord;
        isWing = chordCoordinate >= leadingEdge
            && chordCoordinate <= trailingEdge;
    }

    solid[gid] = isWing ? uchar(1) : uchar(0);
    // This value is also retained for just-uncovered nodes, whose refill state
    // must follow the instantaneous prescribed rigid motion.
    wallVelocity[gid] = float4(cross(
        prepared.angularVelocity.xyz,
        relative
    ), 0);
}

kernel void initializePopulations(
    device float* populationsA [[buffer(0)]],
    device const uchar* solid [[buffer(1)]],
    device const float4* wallVelocity [[buffer(2)]],
    device float* density [[buffer(3)]],
    device float4* velocity [[buffer(4)]],
    constant GPUUniforms& uniforms [[buffer(5)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= uniforms.grid.w) {
        return;
    }

    float3 initialVelocity = solid[gid] != 0
        ? wallVelocity[gid].xyz
        : uniforms.farFieldLattice.xyz;

    for (uint q = 0; q < Q; ++q) {
        float value = equilibrium(q, 1.0f, initialVelocity);
        uint index = q * uniforms.grid.w + gid;
        populationsA[index] = value;
    }

    density[gid] = 1.0f;
    velocity[gid] = float4(initialVelocity, 0);
}

/// Deterministic periodic shear-wave initialization used by the canonical
/// validation harness. The subsequent evolution is performed by the same
/// `stepFluidTRT` kernel as the articulated-bird solver.
kernel void initializeShearWave(
    device float* populations [[buffer(0)]],
    device float* density [[buffer(1)]],
    device float4* velocity [[buffer(2)]],
    constant GPUUniforms& uniforms [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= uniforms.grid.w) {
        return;
    }

    uint3 cell = unflatten(gid, uniforms.grid.xyz);
    float phase = 2.0f
        * 3.14159265358979323846f
        * float(cell.y)
        / float(uniforms.grid.y);
    float3 initialVelocity = float3(
        uniforms.caseParameters.x * sin(phase),
        0,
        0
    );
    for (uint q = 0; q < Q; ++q) {
        populations[q * uniforms.grid.w + gid] = equilibrium(
            q,
            1.0f,
            initialVelocity
        );
    }
    density[gid] = 1.0f;
    velocity[gid] = float4(initialVelocity, 0);
}

inline float planarTopWallSpeed(constant GPUUniforms& uniforms) {
    bool oscillating = uniforms.caseParameters.w > 0.5f;
    return oscillating
        ? uniforms.caseParameters.x
            * cos(
                uniforms.caseParameters.y
                    * uniforms.timeStepAndScales.x
            )
        : uniforms.caseParameters.x;
}

/// Initializes a periodic-xz channel with halfway walls represented by the
/// first and last y planes. Part 1 is the stationary lower wall and part 2 is
/// the translating or oscillating upper wall.
kernel void initializePlanarChannel(
    device float* populations [[buffer(0)]],
    device uchar* solidA [[buffer(1)]],
    device uchar* solidB [[buffer(2)]],
    device float4* wallVelocity [[buffer(3)]],
    device float* density [[buffer(4)]],
    device float4* velocity [[buffer(5)]],
    constant GPUUniforms& uniforms [[buffer(6)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= uniforms.grid.w) {
        return;
    }

    uint3 cell = unflatten(gid, uniforms.grid.xyz);
    bool lowerWall = cell.y == 0u;
    bool upperWall = cell.y + 1u == uniforms.grid.y;
    uchar part = lowerWall ? uchar(1) : (upperWall ? uchar(2) : uchar(0));
    float3 wall = upperWall
        ? float3(planarTopWallSpeed(uniforms), 0, 0)
        : float3(0);
    solidA[gid] = part;
    solidB[gid] = part;
    wallVelocity[gid] = float4(wall, 0);

    float3 initialVelocity = part != 0 ? wall : float3(0);
    for (uint q = 0; q < Q; ++q) {
        populations[q * uniforms.grid.w + gid] = equilibrium(
            q,
            1.0f,
            initialVelocity
        );
    }
    density[gid] = 1.0f;
    velocity[gid] = float4(initialVelocity, 0);
}

/// Initializes uniform external flow around a fixed voxelized sphere. The
/// sphere is body part 1 so the production momentum-exchange path can isolate
/// its force and torque from any future canonical-case geometry.
kernel void initializeSphereCase(
    device float* populations [[buffer(0)]],
    device uchar* solidA [[buffer(1)]],
    device uchar* solidB [[buffer(2)]],
    device float4* wallVelocity [[buffer(3)]],
    device float* density [[buffer(4)]],
    device float4* velocity [[buffer(5)]],
    constant GPUUniforms& uniforms [[buffer(6)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= uniforms.grid.w) {
        return;
    }

    uint3 cell = unflatten(gid, uniforms.grid.xyz);
    float3 center = float3(
        uniforms.caseParameters.y * float(uniforms.grid.x),
        0.5f * float(uniforms.grid.y),
        0.5f * float(uniforms.grid.z)
    );
    float3 relative = float3(cell) + 0.5f - center;
    bool isSphere = dot(relative, relative)
        <= uniforms.caseParameters.x * uniforms.caseParameters.x;
    uchar part = isSphere ? uchar(1) : uchar(0);
    float3 initialVelocity = isSphere
        ? float3(0)
        : uniforms.farFieldLattice.xyz;

    solidA[gid] = part;
    solidB[gid] = part;
    wallVelocity[gid] = float4(0);
    for (uint q = 0; q < Q; ++q) {
        populations[q * uniforms.grid.w + gid] = equilibrium(
            q,
            1.0f,
            initialVelocity
        );
    }
    density[gid] = 1.0f;
    velocity[gid] = float4(initialVelocity, 0);
}

/// Initializes uniform external flow around the fixed rectangular validation
/// wing. The nominally thin plate is regularized as a one-cell voxel surface,
/// matching the production occupancy/bounce-back representation rather than
/// introducing a separate immersed-surface operator.
kernel void initializeFixedWingCase(
    device float* populations [[buffer(0)]],
    device uchar* solidA [[buffer(1)]],
    device uchar* solidB [[buffer(2)]],
    device float4* wallVelocity [[buffer(3)]],
    device float* density [[buffer(4)]],
    device float4* velocity [[buffer(5)]],
    constant GPUUniforms& uniforms [[buffer(6)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= uniforms.grid.w) {
        return;
    }

    uint3 cell = unflatten(gid, uniforms.grid.xyz);
    float3 center = float3(
        0.3f * float(uniforms.grid.x),
        0.5f * float(uniforms.grid.y) + 0.5f,
        0.5f * float(uniforms.grid.z)
    );
    float3 relative = float3(cell) + 0.5f - center;
    bool isWing = abs(relative.x) <= uniforms.caseParameters.x
        && abs(relative.z) <= uniforms.caseParameters.y
        && abs(relative.y) <= 0.5f;
    uchar part = isWing ? uchar(1) : uchar(0);
    float3 initialVelocity = isWing
        ? float3(0)
        : uniforms.farFieldLattice.xyz;

    solidA[gid] = part;
    solidB[gid] = part;
    wallVelocity[gid] = float4(0);
    for (uint q = 0; q < Q; ++q) {
        populations[q * uniforms.grid.w + gid] = equilibrium(
            q,
            1.0f,
            initialVelocity
        );
    }
    density[gid] = 1.0f;
    velocity[gid] = float4(initialVelocity, 0);
}

/// Updates only the N_x by N_z upper-wall plane, avoiding a full-volume
/// geometry pass for the planar canonical case.
kernel void updatePlanarWallVelocity(
    device float4* wallVelocity [[buffer(0)]],
    constant GPUUniforms& uniforms [[buffer(1)]],
    uint gid [[thread_position_in_grid]]
) {
    uint planeCount = uniforms.grid.x * uniforms.grid.z;
    if (gid >= planeCount) {
        return;
    }
    uint x = gid % uniforms.grid.x;
    uint z = gid / uniforms.grid.x;
    uint3 cell = uint3(x, uniforms.grid.y - 1u, z);
    uint index = flatten(cell, uniforms.grid.xyz);
    wallVelocity[index] = float4(planarTopWallSpeed(uniforms), 0, 0, 0);
}

inline bool inside(int3 p, uint3 size) {
    return p.x >= 0
        && p.y >= 0
        && p.z >= 0
        && p.x < int(size.x)
        && p.y < int(size.y)
        && p.z < int(size.z);
}

inline float spongeFactor(
    uint3 cell,
    uint3 size,
    float width,
    float strength
) {
    uint dx = min(cell.x, size.x - 1u - cell.x);
    uint dy = min(cell.y, size.y - 1u - cell.y);
    uint dz = min(cell.z, size.z - 1u - cell.z);
    float distance = float(min(dx, min(dy, dz)));
    if (distance >= width) {
        return 0.0f;
    }
    float normalizedDistance = clamp(
        (width - distance) / max(width, 1.0f),
        0.0f,
        1.0f
    );
    return strength * normalizedDistance * normalizedDistance;
}

kernel void stepFluidTRT(
    device const float* populationsIn [[buffer(0)]],
    device float* populationsOut [[buffer(1)]],
    device const uchar* solidPrevious [[buffer(2)]],
    device const uchar* solidCurrent [[buffer(3)]],
    device const float4* wallVelocity [[buffer(4)]],
    device float* density [[buffer(5)]],
    device float4* velocity [[buffer(6)]],
    device GPUForceTorque* partialLoads [[buffer(7)]],
    constant GPUBirdBodyState& body [[buffer(8)]],
    constant GPUUniforms& uniforms [[buffer(9)]],
    uint gid [[thread_position_in_grid]],
    uint threadIndex [[thread_index_in_threadgroup]],
    uint threadgroupPosition [[threadgroup_position_in_grid]],
    uint threadsPerThreadgroup [[threads_per_threadgroup]]
) {
    // The host always launches complete 256-lane groups. Padded lanes still
    // participate in the barrier and contribute a zero load when load
    // accumulation is enabled. Canonical steady cases disable this work on
    // intermediate steps through gravity.w, which is otherwise unused.
    threadgroup float4 groupForces[256];
    threadgroup float4 groupTorques[256];
    bool accumulateLoads = uniforms.gravity.w != 0.0f;
    float3 cellForcePhysical = float3(0);
    float3 cellTorquePhysical = float3(0);

    if (gid < uniforms.grid.w) {
        uint3 size = uniforms.grid.xyz;
        uint3 cell = unflatten(gid, size);
        float3 world = cellPosition(cell, uniforms);
        bool wasSolid = solidPrevious[gid] != 0;
        bool isSolid = solidCurrent[gid] != 0;
        bool captureFields = uniforms.flags.y != 0u;

        if (isSolid) {
            float3 wall = wallVelocity[gid].xyz;
            for (uint q = 0; q < Q; ++q) {
                populationsOut[q * uniforms.grid.w + gid] = equilibrium(
                    q,
                    1.0f,
                    wall
                );
            }
            if (captureFields) {
                density[gid] = 1.0f;
                velocity[gid] = float4(wall, 0);
            }

            // A newly covered node transfers the difference between its
            // previous fluid momentum and the moving-solid equilibrium.
            if (accumulateLoads && !wasSolid) {
                float previousDensity = 0.0f;
                float3 previousMomentum = float3(0);
                for (uint q = 0; q < Q; ++q) {
                    float previous = populationsIn[
                        q * uniforms.grid.w + gid
                    ];
                    previousDensity += previous;
                    previousMomentum += previous * float3(C[q]);
                }
                float3 conversionImpulse = previousMomentum
                    - previousDensity * wall;
                cellForcePhysical = conversionImpulse
                    * uniforms.timeStepAndScales.w;
                cellTorquePhysical = cross(
                    world - body.position.xyz,
                    cellForcePhysical
                );
            }
        }
        else {
            float f[19];
            float rho = 0.0f;
            float3 momentum = float3(0);
            float3 forceOnBodyLattice = float3(0);

            if (wasSolid) {
                // Refill a newly uncovered node from the local moving-boundary
                // state retained by the geometry pass.
                float3 refillVelocity = wallVelocity[gid].xyz;
                for (uint q = 0; q < Q; ++q) {
                    float value = equilibrium(q, 1.0f, refillVelocity);
                    f[q] = value;
                    rho += value;
                    momentum += value * float3(C[q]);
                }
            }
            else {
                bool interiorDomain = cell.x > 0u
                    && cell.y > 0u
                    && cell.z > 0u
                    && cell.x + 1u < size.x
                    && cell.y + 1u < size.y
                    && cell.z + 1u < size.z;
                for (uint q = 0; q < Q; ++q) {
                    int3 sourceCell = int3(cell) - C[q];
                    float value;
                    bool useFarField = false;

                    if (!interiorDomain && !inside(sourceCell, size)) {
                        if (uniforms.flags.w != 0u) {
                            sourceCell.x = sourceCell.x < 0
                                ? int(size.x) - 1
                                : (sourceCell.x >= int(size.x)
                                    ? 0
                                    : sourceCell.x);
                            sourceCell.y = sourceCell.y < 0
                                ? int(size.y) - 1
                                : (sourceCell.y >= int(size.y)
                                    ? 0
                                    : sourceCell.y);
                            sourceCell.z = sourceCell.z < 0
                                ? int(size.z) - 1
                                : (sourceCell.z >= int(size.z)
                                    ? 0
                                    : sourceCell.z);
                        }
                        else {
                            useFarField = true;
                        }
                    }

                    if (useFarField) {
                        value = equilibrium(
                            q,
                            uniforms.farFieldLattice.w,
                            uniforms.farFieldLattice.xyz
                        );
                    }
                    else {
                        uint source = flatten(uint3(sourceCell), size);
                        uchar sourcePart = solidCurrent[source];
                        if (sourcePart != 0) {
                            float reflected = populationsIn[
                                OPP[q] * uniforms.grid.w + gid
                            ];
                            float wallCorrection = 2.0f
                                * W[q]
                                * uniforms.farFieldLattice.w
                                * dot(
                                    float3(C[q]),
                                    wallVelocity[source].xyz
                                )
                                / CS2;
                            value = reflected + wallCorrection;

                            // C[q] points from the solid source to this cell.
                            uint selectedPart = uint(
                                uniforms.caseParameters.z + 0.5f
                            );
                            if (accumulateLoads
                                && (selectedPart == 0u
                                || selectedPart == uint(sourcePart))) {
                                // Evaluate momentum relative to the local wall
                                // frame. This Galilean-invariant form reduces
                                // moving-interface force bias while collapsing
                                // exactly to conventional momentum exchange for
                                // a stationary boundary.
                                float3 direction = float3(C[q]);
                                float3 wall = wallVelocity[source].xyz;
                                float3 linkForceLattice = -(
                                    value * (direction - wall)
                                    - reflected * (-direction - wall)
                                );
                                forceOnBodyLattice += linkForceLattice;
                                float3 linkForcePhysical = linkForceLattice
                                    * uniforms.timeStepAndScales.w;
                                float3 boundaryPoint = world
                                    - 0.5f
                                    * float3(C[q])
                                    * uniforms.originAndCellSize.w;
                                cellTorquePhysical += cross(
                                    boundaryPoint - body.position.xyz,
                                    linkForcePhysical
                                );
                            }
                        }
                        else {
                            value = populationsIn[
                                q * uniforms.grid.w + source
                            ];
                        }
                    }

                    f[q] = value;
                    rho += value;
                    momentum += value * float3(C[q]);
                }
            }

            rho = max(rho, 1.0e-8f);
            float3 macroscopicVelocity = momentum / rho;

            float feq[19];
            for (uint q = 0; q < Q; ++q) {
                feq[q] = equilibrium(q, rho, macroscopicVelocity);
            }

            float omegaPlus = uniforms.latticeAndSponge.x;
            float omegaMinus = uniforms.latticeAndSponge.y;
            float sponge = spongeFactor(
                cell,
                size,
                uniforms.latticeAndSponge.w,
                uniforms.latticeAndSponge.z
            );
            float capturedDensity = 0.0f;
            float3 capturedMomentum = float3(0);

            for (uint q = 0; q < Q; ++q) {
                uint qo = OPP[q];
                float fPlus = 0.5f * (f[q] + f[qo]);
                float fMinus = 0.5f * (f[q] - f[qo]);
                float eqPlus = 0.5f * (feq[q] + feq[qo]);
                float eqMinus = 0.5f * (feq[q] - feq[qo]);
                float post = f[q]
                    - omegaPlus * (fPlus - eqPlus)
                    - omegaMinus * (fMinus - eqMinus);

                if (sponge > 0.0f) {
                    float far = equilibrium(
                        q,
                        uniforms.farFieldLattice.w,
                        uniforms.farFieldLattice.xyz
                    );
                    post = mix(post, far, sponge);
                }
                populationsOut[q * uniforms.grid.w + gid] = post;
                if (captureFields) {
                    capturedDensity += post;
                    capturedMomentum += post * float3(C[q]);
                }
            }

            if (captureFields) {
                capturedDensity = max(capturedDensity, 1.0e-8f);
                density[gid] = capturedDensity;
                velocity[gid] = float4(
                    capturedMomentum / capturedDensity,
                    0
                );
            }

            if (accumulateLoads) {
                cellForcePhysical = forceOnBodyLattice
                    * uniforms.timeStepAndScales.w;
            }
        }
    }

    // This branch is uniform across the dispatch. Avoiding the threadgroup
    // barrier and serial 256-lane sum materially reduces bandwidth-bound
    // steady validation while the coupled solver keeps the default-on path.
    if (!accumulateLoads) {
        return;
    }

    groupForces[threadIndex] = float4(cellForcePhysical, 0);
    groupTorques[threadIndex] = float4(cellTorquePhysical, 0);
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Lane zero uses the original ascending 256-cell summation order, keeping
    // the first reduction level deterministic while avoiding global cell loads.
    if (threadIndex == 0u) {
        float3 force = float3(0);
        float3 torque = float3(0);
        for (uint index = 0; index < threadsPerThreadgroup; ++index) {
            force += groupForces[index].xyz;
            torque += groupTorques[index].xyz;
        }
        partialLoads[threadgroupPosition].force = float4(force, 0);
        partialLoads[threadgroupPosition].torque = float4(torque, 0);
    }
}

kernel void reduceForceTorque(
    device const GPUForceTorque* input [[buffer(0)]],
    device GPUForceTorque* output [[buffer(1)]],
    constant uint& inputCount [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    uint start = gid * 256u;
    if (start >= inputCount) {
        return;
    }

    float3 force = float3(0);
    float3 torque = float3(0);
    uint end = min(start + 256u, inputCount);
    for (uint index = start; index < end; ++index) {
        force += input[index].force.xyz;
        torque += input[index].torque.xyz;
    }

    output[gid].force = float4(force, 0);
    output[gid].torque = float4(torque, 0);
}

/// Records a reduced moving-boundary load without synchronizing the CPU. A
/// complete cycle is only a few thousand records, so this removes phase
/// aliasing at negligible bandwidth cost.
kernel void storeForceTorqueSample(
    device const GPUForceTorque* totalLoad [[buffer(0)]],
    device GPUForceTorque* history [[buffer(1)]],
    constant uint& sampleIndex [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid == 0u) {
        history[sampleIndex] = totalLoad[0];
    }
}

kernel void integrateBirdBody(
    device GPUBirdBodyState* body [[buffer(0)]],
    constant GPUBirdParameters& bird [[buffer(1)]],
    device const GPUForceTorque* totalLoad [[buffer(2)]],
    constant GPUUniforms& uniforms [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid != 0 || uniforms.flags.x == 0u) {
        return;
    }

    float dt = uniforms.timeStepAndScales.y;
    float mass = bird.bodyRadiiAndMass.w;
    float3 force = totalLoad[0].force.xyz;
    float3 torqueWorld = totalLoad[0].torque.xyz;

    float3 linearVelocity = body[0].linearVelocity.xyz;
    linearVelocity += (force / mass + uniforms.gravity.xyz) * dt;
    body[0].position = float4(
        body[0].position.xyz + linearVelocity * dt,
        0
    );
    body[0].linearVelocity = float4(linearVelocity, 0);

    float4 orientation = quaternionNormalize(body[0].orientation);
    float3 torqueBody = quaternionUnrotate(orientation, torqueWorld);
    float3 omegaBody = body[0].angularVelocityBody.xyz;
    float3 inertia = bird.inertia.xyz;
    float3 angularMomentum = inertia * omegaBody;
    float3 angularAcceleration = (
        torqueBody - cross(omegaBody, angularMomentum)
    ) / inertia;
    omegaBody += angularAcceleration * dt;

    float4 omegaQuaternion = float4(omegaBody, 0);
    float4 derivative = quaternionMultiply(
        orientation,
        omegaQuaternion
    );
    orientation = quaternionNormalize(
        orientation + 0.5f * dt * derivative
    );

    body[0].orientation = orientation;
    body[0].angularVelocityBody = float4(omegaBody, 0);
}
