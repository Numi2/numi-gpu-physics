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

struct GPUMeasuredWingKeyframe {
    float4 phase;
    float4 leftAngles;
    float4 leftRates;
    float4 rightAngles;
    float4 rightRates;
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

struct GPUMeasuredWingSurfaceParameters {
    uint4 counts;
    uint4 pointCounts;
    float4 rootAndHalfThickness;
    float4 timingAndBounds;
};

struct GPUPreparedMeasuredWingPoint {
    float4 position;
    float4 velocity;
};

struct GPUTranslatingSphereParameters {
    float4 initialCenterAndRadius;
    float4 geometryVelocity;
    // xyz is the reference wall velocity. w selects uniform (0),
    // tangential-only (1), or normal-only (2) validation projection.
    float4 wallVelocity;
};

inline float3 translatingSphereWallVelocity(
    constant GPUTranslatingSphereParameters& parameters,
    float3 relative
) {
    float3 wall = parameters.wallVelocity.xyz;
    uint mode = uint(max(parameters.wallVelocity.w, 0.0f) + 0.5f);
    if (mode == 0u) {
        return wall;
    }
    float3 normal = relative / max(length(relative), 1.0e-6f);
    float3 normalWall = dot(wall, normal) * normal;
    return mode == 1u ? wall - normalWall : normalWall;
}

struct GPUForceTorque {
    float4 force;
    float4 torque;
};

/// Diagnostic-only partial reduction record. `comparisonValue` maps every
/// non-finite population to negative infinity so the host can locate the
/// first invalid value without copying the direction-major population field.
struct GPUPopulationMinimum {
    float comparisonValue;
    float rawValue;
    uint linearIndex;
    uint nonFinite;
};

/// One direction of a diagnostic-only TRT collision decomposition. Float4 and
/// uint4 fields keep the layout identical to the Swift readback structure.
struct GPUTRTCollisionTerm {
    float4 values0;
    float4 values1;
    float4 boundaryValues0;
    float4 boundaryContributions;
    uint4 metadata;
    uint4 boundaryMetadata;
};

struct GPUTRTCollisionSummary {
    float4 macroscopic;
    float4 relaxation;
    float4 limiter;
    uint4 metadata;
};

/// Diagnostic-only conservation ledger. Each float4 stores mass in x and
/// lattice momentum in yzw. The capture kernel writes one record per cell;
/// a second kernel reduces deterministic blocks of 256 cells.
struct GPUSymmetricLimiterLedger {
    float4 observedGlobal;
    float4 boundaryGlobal;
    float4 farFieldGlobal;
    float4 collisionGlobal;
    float4 limiterGlobal;
    float4 spongeGlobal;
    float4 collisionControl;
    float4 limiterControl;
    float4 spongeControl;
    float4 boundaryActivated;
    float4 spongeActivated;
    // x/y: limiter L1 and squared L2 correction; z/w: unlimited TRT
    // collision L1 and squared L2 increment. Diagnostic-only.
    float4 limiterNorms;
    float4 limiterControlNorms;
    uint4 counts;
    uint4 activatedCounts;
};

struct GPUControlVolumeBounds {
    uint4 minimum;
    uint4 maximumExclusive;
};

struct GPUControlVolumeBudget {
    float4 oldFluidMomentum;
    float4 newFluidMomentum;
    // xyz is outward flux; w counts solid links crossing the control surface.
    float4 outwardMomentumFlux;
    float4 topologyReservoirCorrection;
};

struct GPURunSample {
    float4 timeAndPosition;
    float4 orientation;
    float4 linearVelocity;
    float4 angularVelocityBody;
    float4 force;
    float4 torque;
    uint4 step;
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
    float tipTwist;
    float tipTwistRate;
};

struct MeasuredWingKinematicState {
    float4 angles;
    float4 rates;
};

inline MeasuredWingKinematicState measuredWingKinematics(
    device const GPUMeasuredWingKeyframe* keyframes,
    uint count,
    float frequency,
    float phase,
    bool left
) {
    uint low = 0u;
    uint high = count;
    while (low < high) {
        uint middle = low + (high - low) / 2u;
        if (keyframes[middle].phase.x <= phase) {
            low = middle + 1u;
        }
        else {
            high = middle;
        }
    }
    uint upper = low == count ? 0u : low;
    uint lower = upper == 0u ? count - 1u : upper - 1u;
    float phase0 = keyframes[lower].phase.x;
    float phase1 = upper == 0u ? 1.0f : keyframes[upper].phase.x;
    float adjustedPhase = upper == 0u && phase < phase0
        ? phase + 1.0f
        : phase;
    float interval = phase1 - phase0;
    float fraction = (adjustedPhase - phase0) / interval;
    float seconds = interval / frequency;
    float t2 = fraction * fraction;
    float t3 = t2 * fraction;
    float h00 = 2.0f * t3 - 3.0f * t2 + 1.0f;
    float h10 = t3 - 2.0f * t2 + fraction;
    float h01 = -2.0f * t3 + 3.0f * t2;
    float h11 = t3 - t2;
    float4 angles0 = left
        ? keyframes[lower].leftAngles
        : keyframes[lower].rightAngles;
    float4 rates0 = left
        ? keyframes[lower].leftRates
        : keyframes[lower].rightRates;
    float4 angles1 = left
        ? keyframes[upper].leftAngles
        : keyframes[upper].rightAngles;
    float4 rates1 = left
        ? keyframes[upper].leftRates
        : keyframes[upper].rightRates;

    MeasuredWingKinematicState result;
    result.angles = h00 * angles0
        + h10 * seconds * rates0
        + h01 * angles1
        + h11 * seconds * rates1;
    result.rates = (
        (6.0f * t2 - 6.0f * fraction) * angles0
        + (3.0f * t2 - 4.0f * fraction + 1.0f) * seconds * rates0
        + (-6.0f * t2 + 6.0f * fraction) * angles1
        + (3.0f * t2 - 2.0f * fraction) * seconds * rates1
    ) / seconds;
    return result;
}

inline WingFrame makeWingFrame(
    float side,
    float stroke,
    float strokeRate,
    float deviation,
    float deviationRate,
    float pitch,
    float pitchRate,
    float tipTwist,
    float tipTwistRate,
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
    float3 spanAfterStroke = rotateAroundAxis(
        side * bodyY,
        bodyX,
        signedStroke
    );
    float3 normalAfterStroke = rotateAroundAxis(
        side * bodyZ,
        bodyX,
        signedStroke
    );
    float3 span = rotateAroundAxis(
        spanAfterStroke,
        normalAfterStroke,
        deviation
    );
    float3 chordBeforePitch = rotateAroundAxis(
        bodyX,
        normalAfterStroke,
        deviation
    );
    float3 chord = rotateAroundAxis(chordBeforePitch, span, pitch);
    float3 normal = rotateAroundAxis(normalAfterStroke, span, pitch);

    WingFrame frame;
    frame.root = root;
    frame.chord = normalize(chord);
    frame.span = normalize(span);
    frame.normal = normalize(normal);
    frame.relativeAngularVelocity = bodyX * (side * strokeRate)
        + normalAfterStroke * deviationRate
        + frame.span * pitchRate;
    frame.tipTwist = tipTwist;
    frame.tipTwistRate = tipTwistRate;
    return frame;
}

kernel void prepareBirdGeometry(
    device GPUPreparedBirdGeometry* prepared [[buffer(0)]],
    constant GPUBirdParameters& bird [[buffer(1)]],
    constant GPUBirdBodyState& body [[buffer(2)]],
    device const GPUMeasuredWingKeyframe* measuredKeyframes [[buffer(3)]],
    constant GPUUniforms& uniforms [[buffer(4)]],
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

    float4 leftAngles = float4(stroke, 0.0f, pitch, 0.0f);
    float4 leftRates = float4(strokeRate, 0.0f, pitchRate, 0.0f);
    float4 rightAngles = leftAngles;
    float4 rightRates = leftRates;
    if (bird.wingKinematics1.w > 0.5f) {
        uint count = uint(bird.wingKinematics1.z);
        float cyclePhase = fmod(
            uniforms.timeStepAndScales.x * bird.wingKinematics0.x,
            1.0f
        );
        cyclePhase = cyclePhase < 0.0f ? cyclePhase + 1.0f : cyclePhase;
        MeasuredWingKinematicState leftMeasured = measuredWingKinematics(
            measuredKeyframes,
            count,
            bird.wingKinematics0.x,
            cyclePhase,
            true
        );
        MeasuredWingKinematicState rightMeasured = measuredWingKinematics(
            measuredKeyframes,
            count,
            bird.wingKinematics0.x,
            cyclePhase,
            false
        );
        leftAngles = leftMeasured.angles;
        leftRates = leftMeasured.rates;
        rightAngles = rightMeasured.angles;
        rightRates = rightMeasured.rates;
    }

    WingFrame left = makeWingFrame(
        1.0f,
        leftAngles.x,
        leftRates.x,
        leftAngles.y,
        leftRates.y,
        leftAngles.z,
        leftRates.z,
        leftAngles.w,
        leftRates.w,
        bird,
        body
    );
    WingFrame right = makeWingFrame(
        -1.0f,
        rightAngles.x,
        rightRates.x,
        rightAngles.y,
        rightRates.y,
        rightAngles.z,
        rightRates.z,
        rightAngles.w,
        rightRates.w,
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
    prepared[0].leftChord = float4(left.chord, left.tipTwist);
    prepared[0].leftSpan = float4(left.span, 0);
    prepared[0].leftNormal = float4(left.normal, 0);
    prepared[0].leftAngularVelocity = float4(
        left.relativeAngularVelocity,
        left.tipTwistRate
    );
    prepared[0].rightRoot = float4(right.root, 0);
    prepared[0].rightChord = float4(right.chord, right.tipTwist);
    prepared[0].rightSpan = float4(right.span, 0);
    prepared[0].rightNormal = float4(right.normal, 0);
    prepared[0].rightAngularVelocity = float4(
        right.relativeAngularVelocity,
        right.tipTwistRate
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
            frame.tipTwist = prepared.leftChord.w;
            frame.tipTwistRate = prepared.leftAngularVelocity.w;
        }
        else {
            frame.root = prepared.rightRoot.xyz;
            frame.chord = prepared.rightChord.xyz;
            frame.span = prepared.rightSpan.xyz;
            frame.normal = prepared.rightNormal.xyz;
            frame.relativeAngularVelocity = prepared.rightAngularVelocity.xyz;
            frame.tipTwist = prepared.rightChord.w;
            frame.tipTwistRate = prepared.rightAngularVelocity.w;
        }
        float3 relative = world - frame.root;
        float3 localUntwisted = float3(
            dot(relative, frame.chord),
            dot(relative, frame.span),
            dot(relative, frame.normal)
        );
        float spanFraction = clamp(
            localUntwisted.y / max(bird.wingGeometry0.x, 1.0e-6f),
            0.0f,
            1.0f
        );
        float twist = frame.tipTwist * spanFraction;
        float twistCosine = cos(twist);
        float twistSine = sin(twist);
        float3 local = float3(
            twistCosine * localUntwisted.x
                + twistSine * localUntwisted.z,
            localUntwisted.y,
            -twistSine * localUntwisted.x
                + twistCosine * localUntwisted.z
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
                )
                + cross(
                    frame.span * (spanFraction * frame.tipTwistRate),
                    world - (frame.root + frame.span * localUntwisted.y)
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

struct PrescribedWingBoundaryCoordinates {
    float radial;
    float normal;
    float chord;
    float radialRootViolation;
    float radialTipViolation;
    float normalViolation;
    float leadingViolation;
    float trailingViolation;
};

inline PrescribedWingBoundaryCoordinates prescribedWingBoundaryCoordinates(
    float3 world,
    constant GPUFlappingWingParameters& wing,
    device const GPUPreparedFlappingWing& prepared,
    constant GPUUniforms& uniforms
) {
    float3 relative = world - prepared.root.xyz;
    float radial = dot(relative, prepared.span.xyz);
    float normal = dot(relative, prepared.normal.xyz);
    float chord = dot(relative, prepared.chord.xyz);
    float radius = wing.geometry.x;
    float chordMean = wing.rootAndChord.w;
    float halfThickness = 0.5f * max(
        wing.geometry.y,
        uniforms.originAndCellSize.w
    );
    float radialFraction = clamp(radial / radius, 0.0f, 1.0f);
    float betaBase = max(
        radialFraction * (1.0f - radialFraction),
        0.0f
    );
    float localChord = chordMean
        * wing.geometry.w
        * pow(betaBase, wing.geometry.z);
    float leadingEdge = -0.25f * chordMean;

    PrescribedWingBoundaryCoordinates result;
    result.radial = radial;
    result.normal = normal;
    result.chord = chord;
    result.radialRootViolation = -radial;
    result.radialTipViolation = radial - radius;
    result.normalViolation = abs(normal) - halfThickness;
    result.leadingViolation = leadingEdge - chord;
    result.trailingViolation = chord - (leadingEdge + localChord);
    return result;
}

inline float prescribedWingMaximumViolation(
    PrescribedWingBoundaryCoordinates value
) {
    return max(
        max(value.radialRootViolation, value.radialTipViolation),
        max(
            value.normalViolation,
            max(value.leadingViolation, value.trailingViolation)
        )
    );
}

/// Bracketed intersection with the complete analytic beta-planform surface.
/// The returned q is measured from fluid to solid, matching the published
/// interpolated bounce-back convention.
inline float prescribedWingLinkFraction(
    float3 fluidWorld,
    float3 solidWorld,
    constant GPUFlappingWingParameters& wing,
    device const GPUPreparedFlappingWing& prepared,
    constant GPUUniforms& uniforms
) {
    float lower = 0.0f;
    float upper = 1.0f;
    // Ten iterations bound the wall location to < 0.001 cell. This complete
    // implicit solve also handles root/tip corners without assuming that the
    // same face is closest at both lattice nodes.
    for (uint iteration = 0u; iteration < 10u; ++iteration) {
        float midpoint = 0.5f * (lower + upper);
        float3 sample = mix(fluidWorld, solidWorld, midpoint);
        float violation = prescribedWingMaximumViolation(
            prescribedWingBoundaryCoordinates(
                sample,
                wing,
                prepared,
                uniforms
            )
        );
        if (violation > 0.0f) {
            lower = midpoint;
        }
        else {
            upper = midpoint;
        }
    }
    return clamp(0.5f * (lower + upper), 1.0e-4f, 1.0f);
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
    device float* boundaryLinks [[buffer(6)]],
    device float4* coveredFluidMomentum [[buffer(7)]],
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
        // Far-field cells cannot participate in a boundary link because the
        // sphere includes a two-cell guard. Keep a positive implicit value so
        // accidental use still classifies the cell as fluid.
        wallVelocity[gid] = float4(0, 0, 0, radius);
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
    ), isWing ? -1.0f : 1.0f);

    if (isWing) {
        if (uniforms.flags.z != 0u && !wasSolid) {
            float previousDensity = 0.0f;
            float3 previousMomentum = float3(0);
            for (uint q = 0u; q < Q; ++q) {
                float previous = boundaryLinks[
                    q * uniforms.grid.w + gid
                ];
                previousDensity += previous;
                previousMomentum += previous * float3(C[q]);
            }
            // The link table below reuses these distribution slots. Preserve
            // the just-covered fluid state in the existing macroscopic field
            // allocation so momentum exchange remains exact without another
            // full-grid buffer.
            coveredFluidMomentum[gid] = float4(
                previousMomentum,
                previousDensity
            );
        }
        for (uint q = 1u; q < Q; ++q) {
            int3 neighborCell = int3(cell) + C[q];
            if (any(neighborCell < int3(0))
                || any(neighborCell >= int3(size))) {
                continue;
            }
            float3 neighborWorld = world
                + float3(C[q]) * uniforms.originAndCellSize.w;
            PrescribedWingBoundaryCoordinates neighbor =
                prescribedWingBoundaryCoordinates(
                    neighborWorld,
                    wing,
                    prepared,
                    uniforms
                );
            if (prescribedWingMaximumViolation(neighbor) > 0.0f) {
                boundaryLinks[q * uniforms.grid.w + gid] =
                    prescribedWingLinkFraction(
                        neighborWorld,
                        world,
                        wing,
                        prepared,
                        uniforms
                    );
            }
        }
    }
}

/// Interpolates the complete compact measured surface once per step. Position
/// and velocity come from the same periodic linear segment, so moving-wall
/// momentum cannot drift from the geometry phase.
kernel void prepareMeasuredWingSurface(
    device const float4* sourcePoints [[buffer(0)]],
    device const float* phases [[buffer(1)]],
    device GPUPreparedMeasuredWingPoint* prepared [[buffer(2)]],
    constant GPUMeasuredWingSurfaceParameters& surface [[buffer(3)]],
    constant GPUUniforms& uniforms [[buffer(4)]],
    uint gid [[thread_position_in_grid]]
) {
    uint pointCount = surface.pointCounts.z;
    uint frameCount = surface.counts.z;
    if (gid >= pointCount) {
        return;
    }

    float phase = unitCyclePhase(
        uniforms.timeStepAndScales.x,
        surface.timingAndBounds.x
    );
    uint first = frameCount - 1u;
    uint second = 0u;
    float adjustedPhase = phase < phases[0] ? phase + 1.0f : phase;
    float phaseSpan = phases[0] + 1.0f - phases[first];
    for (uint frame = 0u; frame + 1u < frameCount; ++frame) {
        if (phase >= phases[frame] && phase < phases[frame + 1u]) {
            first = frame;
            second = frame + 1u;
            adjustedPhase = phase;
            phaseSpan = phases[second] - phases[first];
            break;
        }
    }
    float blend = (adjustedPhase - phases[first]) / phaseSpan;
    float3 firstPoint = sourcePoints[first * pointCount + gid].xyz;
    float3 secondPoint = sourcePoints[second * pointCount + gid].xyz;
    float3 delta = secondPoint - firstPoint;
    prepared[gid].position = float4(
        surface.rootAndHalfThickness.xyz + mix(firstPoint, secondPoint, blend),
        0
    );
    prepared[gid].velocity = float4(
        delta * (surface.timingAndBounds.y / phaseSpan)
            * uniforms.timeStepAndScales.z,
        0
    );
}

struct MeasuredTriangleClosestPoint {
    float3 position;
    float3 barycentric;
};

inline MeasuredTriangleClosestPoint measuredTriangleClosestPoint(
    float3 point,
    float3 a,
    float3 b,
    float3 c
) {
    float3 ab = b - a;
    float3 ac = c - a;
    float3 ap = point - a;
    float d1 = dot(ab, ap);
    float d2 = dot(ac, ap);
    if (d1 <= 0.0f && d2 <= 0.0f) {
        return { a, float3(1, 0, 0) };
    }

    float3 bp = point - b;
    float d3 = dot(ab, bp);
    float d4 = dot(ac, bp);
    if (d3 >= 0.0f && d4 <= d3) {
        return { b, float3(0, 1, 0) };
    }

    float vc = d1 * d4 - d3 * d2;
    if (vc <= 0.0f && d1 >= 0.0f && d3 <= 0.0f) {
        float v = d1 / (d1 - d3);
        return { a + v * ab, float3(1.0f - v, v, 0) };
    }

    float3 cp = point - c;
    float d5 = dot(ab, cp);
    float d6 = dot(ac, cp);
    if (d6 >= 0.0f && d5 <= d6) {
        return { c, float3(0, 0, 1) };
    }

    float vb = d5 * d2 - d1 * d6;
    if (vb <= 0.0f && d2 >= 0.0f && d6 <= 0.0f) {
        float w = d2 / (d2 - d6);
        return { a + w * ac, float3(1.0f - w, 0, w) };
    }

    float va = d3 * d6 - d5 * d4;
    if (va <= 0.0f && (d4 - d3) >= 0.0f && (d5 - d6) >= 0.0f) {
        float w = (d4 - d3) / ((d4 - d3) + (d5 - d6));
        return { b + w * (c - b), float3(0, 1.0f - w, w) };
    }

    float inverse = 1.0f / max(va + vb + vc, 1.0e-20f);
    float v = vb * inverse;
    float w = vc * inverse;
    return {
        a + ab * v + ac * w,
        float3(1.0f - v - w, v, w)
    };
}

inline void considerMeasuredTriangle(
    float3 world,
    uint ia,
    uint ib,
    uint ic,
    device const GPUPreparedMeasuredWingPoint* prepared,
    thread float& bestDistanceSquared,
    thread float3& bestVelocity
) {
    MeasuredTriangleClosestPoint closest = measuredTriangleClosestPoint(
        world,
        prepared[ia].position.xyz,
        prepared[ib].position.xyz,
        prepared[ic].position.xyz
    );
    float distanceSquared = length_squared(world - closest.position);
    if (distanceSquared < bestDistanceSquared) {
        bestDistanceSquared = distanceSquared;
        bestVelocity = closest.barycentric.x * prepared[ia].velocity.xyz
            + closest.barycentric.y * prepared[ib].velocity.xyz
            + closest.barycentric.z * prepared[ic].velocity.xyz;
    }
}

kernel void clearMeasuredWingSurface(
    device uchar* solid [[buffer(0)]],
    device float4* wallVelocity [[buffer(1)]],
    device atomic_uint* distanceKeys [[buffer(2)]],
    constant GPUUniforms& uniforms [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= uniforms.grid.w) {
        return;
    }
    solid[gid] = uchar(0);
    wallVelocity[gid] = float4(0, 0, 0, 16.0f);
    atomic_store_explicit(&distanceKeys[gid], UINT_MAX, memory_order_relaxed);
}

/// One thread owns one structured surface triangle and visits only its small
/// expanded voxel AABB. The 20 high bits encode quantized distance and the 12
/// low bits encode triangle identity, making the atomic minimum deterministic.
kernel void rasterizeMeasuredWingSurface(
    device const GPUPreparedMeasuredWingPoint* prepared [[buffer(0)]],
    device atomic_uint* distanceKeys [[buffer(1)]],
    constant GPUMeasuredWingSurfaceParameters& surface [[buffer(2)]],
    constant GPUUniforms& uniforms [[buffer(3)]],
    uint triangle [[thread_position_in_grid]]
) {
    uint chordCount = surface.counts.x;
    uint spanCount = surface.counts.y;
    uint triangleCount = 2u * (chordCount - 1u) * (spanCount - 1u);
    if (triangle >= triangleCount || triangle >= 4096u) {
        return;
    }
    uint quad = triangle >> 1u;
    uint chord = quad % (chordCount - 1u);
    uint span = quad / (chordCount - 1u);
    uint lowerLeft = chord + chordCount * span;
    uint lowerRight = lowerLeft + 1u;
    uint upperLeft = lowerLeft + chordCount;
    uint upperRight = upperLeft + 1u;
    uint ia = (triangle & 1u) == 0u ? lowerLeft : upperRight;
    uint ib = (triangle & 1u) == 0u ? lowerRight : upperLeft;
    uint ic = (triangle & 1u) == 0u ? upperLeft : lowerRight;
    float3 a = prepared[ia].position.xyz;
    float3 b = prepared[ib].position.xyz;
    float3 c = prepared[ic].position.xyz;
    float cellSize = uniforms.originAndCellSize.w;
    float guard = surface.rootAndHalfThickness.w + 2.0f * cellSize;
    float3 lowerWorld = min(a, min(b, c)) - guard;
    float3 upperWorld = max(a, max(b, c)) + guard;
    int3 lower = int3(floor(
        (lowerWorld - uniforms.originAndCellSize.xyz) / cellSize - 0.5f
    ));
    int3 upper = int3(ceil(
        (upperWorld - uniforms.originAndCellSize.xyz) / cellSize - 0.5f
    ));
    lower = clamp(lower, int3(0), int3(uniforms.grid.xyz) - 1);
    upper = clamp(upper, int3(0), int3(uniforms.grid.xyz) - 1);
    for (int z = lower.z; z <= upper.z; ++z) {
        for (int y = lower.y; y <= upper.y; ++y) {
            for (int x = lower.x; x <= upper.x; ++x) {
                uint3 cell = uint3(x, y, z);
                float3 world = cellPosition(cell, uniforms);
                MeasuredTriangleClosestPoint closest =
                    measuredTriangleClosestPoint(world, a, b, c);
                float distanceCells = length(world - closest.position) / cellSize;
                uint distanceBin = min(
                    uint(round(distanceCells * 65536.0f)),
                    0xFFFFFu
                );
                uint key = (distanceBin << 12u) | triangle;
                uint gid = flatten(cell, uniforms.grid.xyz);
                atomic_fetch_min_explicit(
                    &distanceKeys[gid], key, memory_order_relaxed
                );
            }
        }
    }
}

/// Resolves the winning triangle into occupancy, the matching interpolated
/// wall velocity, and signed distance used by the following link pass.
kernel void resolveMeasuredWingSurface(
    device uchar* solid [[buffer(0)]],
    device float4* wallVelocity [[buffer(1)]],
    device const uchar* solidPrevious [[buffer(2)]],
    constant GPUMeasuredWingSurfaceParameters& surface [[buffer(3)]],
    device const GPUPreparedMeasuredWingPoint* prepared [[buffer(4)]],
    device const atomic_uint* distanceKeys [[buffer(5)]],
    constant GPUUniforms& uniforms [[buffer(6)]],
    device const float* previousPopulations [[buffer(7)]],
    device float4* coveredFluidMomentum [[buffer(8)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= uniforms.grid.w) {
        return;
    }
    bool wasSolid = uniforms.flags.z != 0u && solidPrevious[gid] != 0;
    uint key = atomic_load_explicit(&distanceKeys[gid], memory_order_relaxed);
    if (key == UINT_MAX) {
        return;
    }
    uint chordCount = surface.counts.x;
    uint triangle = key & 0xFFFu;
    uint quad = triangle >> 1u;
    uint chord = quad % (chordCount - 1u);
    uint span = quad / (chordCount - 1u);
    uint lowerLeft = chord + chordCount * span;
    uint lowerRight = lowerLeft + 1u;
    uint upperLeft = lowerLeft + chordCount;
    uint upperRight = upperLeft + 1u;
    uint ia = (triangle & 1u) == 0u ? lowerLeft : upperRight;
    uint ib = (triangle & 1u) == 0u ? lowerRight : upperLeft;
    uint ic = (triangle & 1u) == 0u ? upperLeft : lowerRight;
    uint3 cell = unflatten(gid, uniforms.grid.xyz);
    float3 world = cellPosition(cell, uniforms);
    MeasuredTriangleClosestPoint closest = measuredTriangleClosestPoint(
        world,
        prepared[ia].position.xyz,
        prepared[ib].position.xyz,
        prepared[ic].position.xyz
    );
    float3 bestVelocity = closest.barycentric.x * prepared[ia].velocity.xyz
        + closest.barycentric.y * prepared[ib].velocity.xyz
        + closest.barycentric.z * prepared[ic].velocity.xyz;
    float signedDistance = length(world - closest.position)
        - surface.rootAndHalfThickness.w;
    bool isWing = signedDistance <= 0.0f;
    solid[gid] = isWing ? uchar(1) : uchar(0);
    wallVelocity[gid] = float4(
        bestVelocity,
        signedDistance / uniforms.originAndCellSize.w
    );
    if (isWing && uniforms.flags.z != 0u && !wasSolid) {
        float previousDensity = 0.0f;
        float3 previousMomentum = float3(0);
        for (uint q = 0u; q < Q; ++q) {
            float previous = previousPopulations[q * uniforms.grid.w + gid];
            previousDensity += previous;
            previousMomentum += previous * float3(C[q]);
        }
        coveredFluidMomentum[gid] = float4(previousMomentum, previousDensity);
    }
}

/// Runs after sampleMeasuredWingSurface in a separate encoder, providing a
/// command-buffer synchronization point before neighbor implicit values are
/// consumed. Fractions are linearly reconstructed from signed distances.
kernel void buildMeasuredWingSurfaceLinks(
    device const uchar* solid [[buffer(0)]],
    device const float4* wallVelocity [[buffer(1)]],
    device float* boundaryLinks [[buffer(2)]],
    constant GPUUniforms& uniforms [[buffer(3)]],
    uint3 cell [[thread_position_in_grid]]
) {
    uint3 size = uniforms.grid.xyz;
    if (any(cell >= size)) {
        return;
    }
    uint gid = flatten(cell, size);
    if (solid[gid] == 0) {
        return;
    }
    float solidDistance = min(wallVelocity[gid].w, 0.0f);
    for (uint q = 1u; q < Q; ++q) {
        int3 neighborCell = int3(cell) + C[q];
        if (any(neighborCell < int3(0))
            || any(neighborCell >= int3(size))) {
            continue;
        }
        uint neighbor = flatten(uint3(neighborCell), size);
        if (solid[neighbor] == 0) {
            float fluidDistance = max(wallVelocity[neighbor].w, 0.0f);
            boundaryLinks[q * uniforms.grid.w + gid] = clamp(
                fluidDistance / max(fluidDistance - solidDistance, 1.0e-6f),
                1.0e-4f,
                1.0f
            );
        }
    }
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

/// Reconstructs diagnostic moments from a restored population field without
/// advancing or mutating the numerical state.
kernel void extractMacroscopicFields(
    device const float* populations [[buffer(0)]],
    device float* density [[buffer(1)]],
    device float4* velocity [[buffer(2)]],
    constant GPUUniforms& uniforms [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= uniforms.grid.w) {
        return;
    }
    float rho = 0.0f;
    float3 momentum = float3(0);
    for (uint q = 0; q < Q; ++q) {
        float value = populations[q * uniforms.grid.w + gid];
        rho += value;
        momentum += value * float3(C[q]);
    }
    rho = max(rho, 1.0e-8f);
    density[gid] = rho;
    velocity[gid] = float4(momentum / rho, 0);
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

/// Initializes a compact translating-body topology canonical. Solid nodes are
/// initialized in the wall frame so the first measured step contains only the
/// production moving-boundary response, not an artificial start-up mismatch.
kernel void initializeTranslatingSphereTopology(
    device float* populations [[buffer(0)]],
    device uchar* solidA [[buffer(1)]],
    device uchar* solidB [[buffer(2)]],
    device float4* wallVelocity [[buffer(3)]],
    device float* density [[buffer(4)]],
    device float4* velocity [[buffer(5)]],
    constant GPUTranslatingSphereParameters& parameters [[buffer(6)]],
    constant GPUUniforms& uniforms [[buffer(7)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= uniforms.grid.w) {
        return;
    }

    uint3 cell = unflatten(gid, uniforms.grid.xyz);
    float3 relative = float3(cell) + 0.5f
        - parameters.initialCenterAndRadius.xyz;
    float radius = parameters.initialCenterAndRadius.w;
    bool isSphere = dot(relative, relative) <= radius * radius;
    uchar part = isSphere ? uchar(1) : uchar(0);
    float3 wall = translatingSphereWallVelocity(parameters, relative);
    float3 initialVelocity = isSphere
        ? wall
        : uniforms.farFieldLattice.xyz;

    solidA[gid] = part;
    solidB[gid] = part;
    wallVelocity[gid] = float4(wall, 0);
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

/// Moves the canonical sphere across lattice cells while preserving the exact
/// pre-geometry fluid state of newly covered nodes. Halfway link fractions are
/// intentional: this test isolates cover/uncover accounting from curved-wall
/// interpolation and vortex/kinematics complexity.
kernel void buildTranslatingSphereTopology(
    device uchar* solidCurrent [[buffer(0)]],
    device float4* wallVelocity [[buffer(1)]],
    device const uchar* solidPrevious [[buffer(2)]],
    constant GPUTranslatingSphereParameters& parameters [[buffer(3)]],
    constant GPUUniforms& uniforms [[buffer(4)]],
    device float* boundaryLinks [[buffer(5)]],
    device float4* coveredFluidMomentum [[buffer(6)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= uniforms.grid.w) {
        return;
    }

    uint3 cell = unflatten(gid, uniforms.grid.xyz);
    float3 center = parameters.initialCenterAndRadius.xyz
        + parameters.geometryVelocity.xyz * uniforms.timeStepAndScales.x;
    float3 relative = float3(cell) + 0.5f - center;
    float radius = parameters.initialCenterAndRadius.w;
    bool isSphere = dot(relative, relative) <= radius * radius;
    bool wasSolid = uniforms.flags.z != 0u && solidPrevious[gid] != 0;

    if (isSphere && !wasSolid) {
        float densityBefore = 0.0f;
        float3 momentumBefore = float3(0);
        for (uint q = 0; q < Q; ++q) {
            float value = boundaryLinks[q * uniforms.grid.w + gid];
            densityBefore += value;
            momentumBefore += value * float3(C[q]);
        }
        coveredFluidMomentum[gid] = float4(
            momentumBefore,
            densityBefore
        );
    }

    solidCurrent[gid] = isSphere ? uchar(1) : uchar(0);
    float3 wall = translatingSphereWallVelocity(parameters, relative);
    wallVelocity[gid] = float4(wall, 0);
    if (isSphere) {
        for (uint q = 1; q < Q; ++q) {
            boundaryLinks[q * uniforms.grid.w + gid] = 0.5f;
        }
    }
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
    float limiterActivation = 0.0f;
    float limiterMaximumRestriction = 0.0f;

    if (gid < uniforms.grid.w) {
        uint3 size = uniforms.grid.xyz;
        uint3 cell = unflatten(gid, size);
        float3 world = cellPosition(cell, uniforms);
        bool wasSolid = solidPrevious[gid] != 0;
        bool isSolid = solidCurrent[gid] != 0;
        bool captureFields = uniforms.flags.y != 0u;
        bool prescribedComponentSelection =
            uniforms.caseParameters.w < -0.5f;
        uint prescribedLoadComponent = prescribedComponentSelection
            ? uint(max(uniforms.caseParameters.x, 0.0f) + 0.5f)
            : 0u;
        uint prescribedLinkForceMode = prescribedComponentSelection
            ? uint(max(uniforms.caseParameters.y, 0.0f) + 0.5f)
            : 6u;
        bool includeLinkExchange = !prescribedComponentSelection
            || prescribedLoadComponent != 2u;
        bool includeTopologyImpulse = !prescribedComponentSelection
            || prescribedLoadComponent != 1u;

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
            if (accumulateLoads && !wasSolid && includeTopologyImpulse) {
                float previousDensity = 0.0f;
                float3 previousMomentum = float3(0);
                if (uniforms.caseParameters.w < -0.5f) {
                    float4 preserved = velocity[gid];
                    previousMomentum = preserved.xyz;
                    previousDensity = preserved.w;
                }
                else {
                    for (uint q = 0; q < Q; ++q) {
                        float previous = populationsIn[
                            q * uniforms.grid.w + gid
                        ];
                        previousDensity += previous;
                        previousMomentum += previous * float3(C[q]);
                    }
                }
                float3 conversionImpulse = prescribedLinkForceMode == 6u
                    ? previousMomentum
                    : previousMomentum - previousDensity * wall;
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
                if (accumulateLoads
                    && includeTopologyImpulse
                    && prescribedLinkForceMode == 6u) {
                    // Exact moving-domain balance. The uncovered target skips
                    // pull streaming, so populations that would have entered
                    // it from persistent fluid neighbors are suppressed while
                    // the old solid equilibrium also streams outward to those
                    // neighbors. Both stencil contributions and the refill
                    // momentum belong to the topology impulse.
                    float3 topologyForceOnBody = -momentum;
                    for (uint q = 1u; q < Q; ++q) {
                        int3 neighborCell = int3(cell) + C[q];
                        if (!inside(neighborCell, size)) {
                            continue;
                        }
                        uint neighbor = flatten(uint3(neighborCell), size);
                        bool persistentFluidNeighbor =
                            solidPrevious[neighbor] == 0
                            && solidCurrent[neighbor] == 0;
                        if (!persistentFluidNeighbor) {
                            continue;
                        }
                        float oldSolidOutgoing = populationsIn[
                            q * uniforms.grid.w + gid
                        ];
                        float suppressedNeighborIncoming = populationsIn[
                            OPP[q] * uniforms.grid.w + neighbor
                        ];
                        topologyForceOnBody -= (
                            oldSolidOutgoing + suppressedNeighborIncoming
                        ) * float3(C[q]);
                    }
                    forceOnBodyLattice += topologyForceOnBody;
                    float3 topologyForcePhysical = topologyForceOnBody
                        * uniforms.timeStepAndScales.w;
                    cellTorquePhysical += cross(
                        world - body.position.xyz,
                        topologyForcePhysical
                    );
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
                            float3 direction = float3(C[q]);
                            float linkFraction = 0.5f;
                            float3 wall = wallVelocity[source].xyz;
                            uint farther = 0u;
                            bool interpolatedBoundary =
                                uniforms.caseParameters.w < -0.5f;
                            if (interpolatedBoundary) {
                                linkFraction = clamp(
                                    populationsIn[
                                        q * uniforms.grid.w + source
                                    ],
                                    1.0e-4f,
                                    1.0f
                                );
                                // Rigid velocity is affine in position, so
                                // interpolation gives the velocity at the
                                // actual link-wall intersection exactly.
                                wall = mix(
                                    wallVelocity[gid].xyz,
                                    wallVelocity[source].xyz,
                                    linkFraction
                                );
                                if (linkFraction <= 0.5f) {
                                    int3 fartherCell = int3(cell) + C[q];
                                    if (inside(fartherCell, size)) {
                                        farther = flatten(
                                            uint3(fartherCell),
                                            size
                                        );
                                    }
                                    if (!inside(fartherCell, size)
                                        || solidCurrent[farther] != 0) {
                                        // The published near-wall branch
                                        // requires the next fluid node. A
                                        // pathological concave/corner link
                                        // falls back completely to the locked
                                        // halfway rule instead of mixing two
                                        // inconsistent boundary locations.
                                        interpolatedBoundary = false;
                                        linkFraction = 0.5f;
                                        wall = wallVelocity[source].xyz;
                                    }
                                }
                            }
                            float wallCorrection = 2.0f
                                * W[q]
                                * uniforms.farFieldLattice.w
                                * dot(
                                    direction,
                                    wall
                                )
                                / CS2;
                            value = reflected + wallCorrection;
                            if (interpolatedBoundary) {
                                if (linkFraction <= 0.5f) {
                                    float fartherOutgoing = populationsIn[
                                        OPP[q] * uniforms.grid.w + farther
                                    ];
                                    value = 2.0f * linkFraction * reflected
                                        + (1.0f - 2.0f * linkFraction)
                                            * fartherOutgoing
                                        + wallCorrection;
                                }
                                else {
                                    float previousIncoming = populationsIn[
                                        q * uniforms.grid.w + gid
                                    ];
                                    value = (reflected + wallCorrection)
                                            / (2.0f * linkFraction)
                                        + (2.0f * linkFraction - 1.0f)
                                            * previousIncoming
                                            / (2.0f * linkFraction);
                                }
                            }

                            // C[q] points from the solid source to this cell.
                            uint selectedPart = uint(
                                uniforms.caseParameters.z + 0.5f
                            );
                            if (accumulateLoads
                                && includeLinkExchange
                                && (selectedPart == 0u
                                || selectedPart == uint(sourcePart))) {
                                float3 linkForceLattice;
                                if (prescribedLinkForceMode == 0u) {
                                    // Wen et al. Eq. (5): evaluate momentum in
                                    // the local wall frame. Retained as an
                                    // explicit diagnostic estimator.
                                    linkForceLattice = -(
                                        value * (direction - wall)
                                        - reflected
                                            * (-direction - wall)
                                    );
                                }
                                else if (prescribedLinkForceMode == 1u
                                    || prescribedLinkForceMode == 6u) {
                                    // Wen et al. Eq. (4), evaluated with the
                                    // incoming population already reconstructed
                                    // at the interpolated wall. Mode 6 is the
                                    // production conservative moving-domain
                                    // estimator and adds exact topology terms
                                    // in the cover/uncover branches above.
                                    linkForceLattice = -(
                                        value + reflected
                                    ) * direction;
                                }
                                else if (prescribedLinkForceMode == 2u) {
                                    linkForceLattice = -2.0f
                                        * reflected
                                        * direction;
                                }
                                else if (prescribedLinkForceMode == 3u) {
                                    linkForceLattice = -wallCorrection
                                        * direction;
                                }
                                else if (prescribedLinkForceMode == 4u) {
                                    float interpolationResidual = value
                                        - reflected
                                        - wallCorrection;
                                    linkForceLattice = -interpolationResidual
                                        * direction;
                                }
                                else if (prescribedLinkForceMode == 5u) {
                                    linkForceLattice = (value - reflected)
                                        * wall;
                                }
                                else {
                                    linkForceLattice = float3(0);
                                }
                                forceOnBodyLattice += linkForceLattice;
                                float3 linkForcePhysical = linkForceLattice
                                    * uniforms.timeStepAndScales.w;
                                float3 boundaryPoint = world
                                    - linkFraction
                                    * direction
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
            bool symmetricPositivityLimiter =
                uniforms.caseParameters.w < -1.5f;

            // Preserve the production/control arithmetic literally. Even an
            // algebraically equivalent regrouping perturbs the low-margin c16
            // trajectory before the diagnostic limiter first activates.
            if (!symmetricPositivityLimiter) {
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
            }
            else {
                float symmetricIncrements[19];
                float antisymmetricIncrements[19];
                float symmetricScale = 1.0f;

                for (uint q = 0; q < Q; ++q) {
                    uint qo = OPP[q];
                    float fPlus = 0.5f * (f[q] + f[qo]);
                    float fMinus = 0.5f * (f[q] - f[qo]);
                    float eqPlus = 0.5f * (feq[q] + feq[qo]);
                    float eqMinus = 0.5f * (feq[q] - feq[qo]);
                    float symmetricIncrement = -omegaPlus
                        * (fPlus - eqPlus);
                    float antisymmetricIncrement = -omegaMinus
                        * (fMinus - eqMinus);
                    symmetricIncrements[q] = symmetricIncrement;
                    antisymmetricIncrements[q] = antisymmetricIncrement;

                    if (symmetricIncrement < 0.0f) {
                        float base = f[q] + antisymmetricIncrement;
                        float populationFloor = max(
                            1.0e-12f,
                            1.0e-6f * max(feq[q], 0.0f)
                        );
                        if (base + symmetricIncrement < populationFloor) {
                            float candidate = clamp(
                                (base - populationFloor)
                                    / max(-symmetricIncrement, 1.0e-30f),
                                0.0f,
                                1.0f
                            );
                            symmetricScale = min(symmetricScale, candidate);
                        }
                    }
                }

                if (symmetricScale < 1.0f) {
                    limiterActivation = 1.0f;
                    limiterMaximumRestriction = 1.0f - symmetricScale;
                }

                for (uint q = 0; q < Q; ++q) {
                    float post;
                    if (symmetricScale < 1.0f) {
                        post = f[q]
                            + symmetricScale * symmetricIncrements[q]
                            + antisymmetricIncrements[q];
                    }
                    else {
                        // A treatment cell that did not activate must remain
                        // bit-identical to the production/control collision.
                        uint qo = OPP[q];
                        float fPlus = 0.5f * (f[q] + f[qo]);
                        float fMinus = 0.5f * (f[q] - f[qo]);
                        float eqPlus = 0.5f * (feq[q] + feq[qo]);
                        float eqMinus = 0.5f * (feq[q] - feq[qo]);
                        post = f[q]
                            - omegaPlus * (fPlus - eqPlus)
                            - omegaMinus * (fMinus - eqMinus);
                    }

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

    groupForces[threadIndex] = float4(
        cellForcePhysical,
        limiterActivation
    );
    groupTorques[threadIndex] = float4(
        cellTorquePhysical,
        limiterMaximumRestriction
    );
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Lane zero uses the original ascending 256-cell summation order, keeping
    // the first reduction level deterministic while avoiding global cell loads.
    if (threadIndex == 0u) {
        float3 force = float3(0);
        float3 torque = float3(0);
        float activationCount = 0.0f;
        float maximumRestriction = 0.0f;
        for (uint index = 0; index < threadsPerThreadgroup; ++index) {
            force += groupForces[index].xyz;
            torque += groupTorques[index].xyz;
            activationCount += groupForces[index].w;
            maximumRestriction = max(
                maximumRestriction,
                groupTorques[index].w
            );
        }
        partialLoads[threadgroupPosition].force = float4(
            force,
            activationCount
        );
        partialLoads[threadgroupPosition].torque = float4(
            torque,
            maximumRestriction
        );
    }
}

/// Reconstructs one ordinary-fluid TRT update from the production step's
/// input and output fields. The locked diagnostic requires every pull source
/// to be fluid; source flags make that precondition explicit instead of
/// silently duplicating the curved-wall operator here.
kernel void captureTRTCollisionDecomposition(
    device const float* populationsIn [[buffer(0)]],
    device const float* populationsOut [[buffer(1)]],
    device const uchar* solidCurrent [[buffer(2)]],
    device const float4* wallVelocity [[buffer(3)]],
    device GPUTRTCollisionTerm* terms [[buffer(4)]],
    device GPUTRTCollisionSummary* summary [[buffer(5)]],
    constant GPUUniforms& uniforms [[buffer(6)]],
    constant uint& targetGID [[buffer(7)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid != 0u || targetGID >= uniforms.grid.w) {
        return;
    }

    uint3 size = uniforms.grid.xyz;
    uint3 target = unflatten(targetGID, size);
    float f[19];
    uint sourceIndices[19];
    uint sourceSolid[19];
    uint sourceOutside[19];
    float4 boundaryValues[19];
    float4 boundaryContributions[19];
    uint4 boundaryMetadata[19];
    uint solidSourceCount = 0u;
    uint outsideSourceCount = 0u;
    float rho = 0.0f;
    float3 momentum = float3(0);

    for (uint q = 0u; q < Q; ++q) {
        boundaryValues[q] = float4(0);
        boundaryContributions[q] = float4(0);
        boundaryMetadata[q] = uint4(0);
        int3 sourceCell = int3(target) - C[q];
        bool outside = !inside(sourceCell, size);
        uint source = 0xffffffffu;
        bool isSolidSource = false;
        float value;
        if (outside) {
            value = equilibrium(
                q,
                uniforms.farFieldLattice.w,
                uniforms.farFieldLattice.xyz
            );
            outsideSourceCount += 1u;
        }
        else {
            source = flatten(uint3(sourceCell), size);
            isSolidSource = solidCurrent[source] != 0;
            if (isSolidSource) {
                solidSourceCount += 1u;
                float reflected = populationsIn[
                    OPP[q] * uniforms.grid.w + targetGID
                ];
                float3 direction = float3(C[q]);
                float linkFraction = 0.5f;
                float3 wall = wallVelocity[source].xyz;
                uint farther = 0u;
                bool interpolatedBoundary =
                    uniforms.caseParameters.w < -0.5f;
                if (interpolatedBoundary) {
                    linkFraction = clamp(
                        populationsIn[q * uniforms.grid.w + source],
                        1.0e-4f,
                        1.0f
                    );
                    wall = mix(
                        wallVelocity[targetGID].xyz,
                        wallVelocity[source].xyz,
                        linkFraction
                    );
                    if (linkFraction <= 0.5f) {
                        int3 fartherCell = int3(target) + C[q];
                        if (inside(fartherCell, size)) {
                            farther = flatten(uint3(fartherCell), size);
                        }
                        if (!inside(fartherCell, size)
                            || solidCurrent[farther] != 0) {
                            interpolatedBoundary = false;
                            linkFraction = 0.5f;
                            wall = wallVelocity[source].xyz;
                        }
                    }
                }
                float wallCorrection = 2.0f
                    * W[q]
                    * uniforms.farFieldLattice.w
                    * dot(direction, wall)
                    / CS2;
                value = reflected + wallCorrection;
                float auxiliaryPopulation = 0.0f;
                float reflectedContribution = reflected;
                float auxiliaryContribution = 0.0f;
                float wallContribution = wallCorrection;
                uint auxiliaryIndex = 0xffffffffu;
                uint branch = 1u;
                if (interpolatedBoundary) {
                    if (linkFraction <= 0.5f) {
                        float fartherOutgoing = populationsIn[
                            OPP[q] * uniforms.grid.w + farther
                        ];
                        reflectedContribution = 2.0f
                            * linkFraction * reflected;
                        auxiliaryPopulation = fartherOutgoing;
                        auxiliaryContribution = (1.0f
                            - 2.0f * linkFraction) * fartherOutgoing;
                        wallContribution = wallCorrection;
                        value = reflectedContribution
                            + auxiliaryContribution
                            + wallContribution;
                        auxiliaryIndex = farther;
                        branch = 2u;
                    }
                    else {
                        float previousIncoming = populationsIn[
                            q * uniforms.grid.w + targetGID
                        ];
                        reflectedContribution = reflected
                            / (2.0f * linkFraction);
                        auxiliaryPopulation = previousIncoming;
                        auxiliaryContribution = (2.0f * linkFraction
                            - 1.0f) * previousIncoming
                            / (2.0f * linkFraction);
                        wallContribution = wallCorrection
                            / (2.0f * linkFraction);
                        value = reflectedContribution
                            + auxiliaryContribution
                            + wallContribution;
                        auxiliaryIndex = targetGID;
                        branch = 3u;
                    }
                }
                boundaryValues[q] = float4(
                    reflected,
                    linkFraction,
                    auxiliaryPopulation,
                    wallCorrection
                );
                boundaryContributions[q] = float4(
                    reflectedContribution,
                    auxiliaryContribution,
                    wallContribution,
                    value
                );
                boundaryMetadata[q] = uint4(
                    1u,
                    branch,
                    auxiliaryIndex,
                    interpolatedBoundary ? 1u : 0u
                );
            }
            else {
                value = populationsIn[q * uniforms.grid.w + source];
            }
        }
        f[q] = value;
        sourceIndices[q] = source;
        sourceSolid[q] = isSolidSource ? 1u : 0u;
        sourceOutside[q] = outside ? 1u : 0u;
        rho += value;
        momentum += value * float3(C[q]);
    }

    rho = max(rho, 1.0e-8f);
    float3 velocity = momentum / rho;
    float feq[19];
    for (uint q = 0u; q < Q; ++q) {
        feq[q] = equilibrium(q, rho, velocity);
    }

    float omegaPlus = uniforms.latticeAndSponge.x;
    float omegaMinus = uniforms.latticeAndSponge.y;
    float sponge = spongeFactor(
        target,
        size,
        uniforms.latticeAndSponge.w,
        uniforms.latticeAndSponge.z
    );
    bool symmetricPositivityLimiter =
        uniforms.caseParameters.w < -1.5f;
    float symmetricScale = 1.0f;
    if (symmetricPositivityLimiter) {
        for (uint q = 0u; q < Q; ++q) {
            uint qo = OPP[q];
            float symmetricNonequilibrium = 0.5f * (f[q] + f[qo])
                - 0.5f * (feq[q] + feq[qo]);
            float antisymmetricNonequilibrium = 0.5f * (f[q] - f[qo])
                - 0.5f * (feq[q] - feq[qo]);
            float symmetricIncrement = -omegaPlus
                * symmetricNonequilibrium;
            float antisymmetricIncrement = -omegaMinus
                * antisymmetricNonequilibrium;
            if (symmetricIncrement < 0.0f) {
                float base = f[q] + antisymmetricIncrement;
                float populationFloor = max(
                    1.0e-12f,
                    1.0e-6f * max(feq[q], 0.0f)
                );
                if (base + symmetricIncrement < populationFloor) {
                    float candidate = clamp(
                        (base - populationFloor)
                            / max(-symmetricIncrement, 1.0e-30f),
                        0.0f,
                        1.0f
                    );
                    symmetricScale = min(symmetricScale, candidate);
                }
            }
        }
    }
    float maximumPredictionError = 0.0f;
    for (uint q = 0u; q < Q; ++q) {
        uint qo = OPP[q];
        float symmetricNonequilibrium = 0.5f * (f[q] + f[qo])
            - 0.5f * (feq[q] + feq[qo]);
        float antisymmetricNonequilibrium = 0.5f * (f[q] - f[qo])
            - 0.5f * (feq[q] - feq[qo]);
        float symmetricIncrement = -omegaPlus
            * symmetricNonequilibrium;
        float antisymmetricIncrement = -omegaMinus
            * antisymmetricNonequilibrium;
        float predicted = f[q]
            + (symmetricPositivityLimiter
                ? symmetricScale * symmetricIncrement
                : symmetricIncrement)
            + antisymmetricIncrement;
        if (sponge > 0.0f) {
            float far = equilibrium(
                q,
                uniforms.farFieldLattice.w,
                uniforms.farFieldLattice.xyz
            );
            predicted = mix(predicted, far, sponge);
        }
        float actual = populationsOut[q * uniforms.grid.w + targetGID];
        maximumPredictionError = max(
            maximumPredictionError,
            abs(predicted - actual)
        );
        terms[q].values0 = float4(
            f[q],
            feq[q],
            symmetricNonequilibrium,
            antisymmetricNonequilibrium
        );
        terms[q].values1 = float4(
            symmetricIncrement,
            antisymmetricIncrement,
            predicted,
            actual
        );
        terms[q].boundaryValues0 = boundaryValues[q];
        terms[q].boundaryContributions = boundaryContributions[q];
        terms[q].metadata = uint4(
            q,
            sourceIndices[q],
            sourceSolid[q],
            sourceOutside[q]
        );
        terms[q].boundaryMetadata = boundaryMetadata[q];
    }

    summary[0].macroscopic = float4(rho, velocity);
    summary[0].relaxation = float4(
        omegaPlus,
        omegaMinus,
        sponge,
        maximumPredictionError
    );
    summary[0].limiter = float4(
        symmetricScale,
        symmetricPositivityLimiter ? 1.0f : 0.0f,
        symmetricScale < 1.0f ? 1.0f : 0.0f,
        0.0f
    );
    summary[0].metadata = uint4(
        targetGID,
        solidSourceCount,
        outsideSourceCount,
        solidCurrent[targetGID] != 0 ? 1u : 0u
    );
}

inline bool insideControlVolume(
    int3 cell,
    constant GPUControlVolumeBounds& bounds
) {
    return all(cell >= int3(bounds.minimum.xyz))
        && all(cell < int3(bounds.maximumExclusive.xyz));
}

/// Reconstructs the exact stationary-sphere treatment step without mutating
/// solver state. Internal streaming cancels only after global reduction;
/// boundary and far-field terms explicitly pair each reconstructed incoming
/// population with the outgoing population it replaces.
kernel void captureSymmetricLimiterLedger(
    device const float* populationsIn [[buffer(0)]],
    device const float* populationsOut [[buffer(1)]],
    device const uchar* solidCurrent [[buffer(2)]],
    device const float4* wallVelocity [[buffer(3)]],
    device GPUSymmetricLimiterLedger* ledgers [[buffer(4)]],
    constant GPUUniforms& uniforms [[buffer(5)]],
    constant GPUControlVolumeBounds& bounds [[buffer(6)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= uniforms.grid.w) {
        return;
    }

    GPUSymmetricLimiterLedger ledger;
    ledger.observedGlobal = float4(0);
    ledger.boundaryGlobal = float4(0);
    ledger.farFieldGlobal = float4(0);
    ledger.collisionGlobal = float4(0);
    ledger.limiterGlobal = float4(0);
    ledger.spongeGlobal = float4(0);
    ledger.collisionControl = float4(0);
    ledger.limiterControl = float4(0);
    ledger.spongeControl = float4(0);
    ledger.boundaryActivated = float4(0);
    ledger.spongeActivated = float4(0);
    ledger.limiterNorms = float4(0);
    ledger.limiterControlNorms = float4(0);
    ledger.counts = uint4(0);
    ledger.activatedCounts = uint4(0);

    uint3 size = uniforms.grid.xyz;
    uint3 cell = unflatten(gid, size);
    if (solidCurrent[gid] != 0) {
        // Geometry deliberately reuses dormant solid population slots for
        // link fractions before this diagnostic executes. They are not fluid
        // mass and must not enter the observed population balance.
        ledgers[gid] = ledger;
        return;
    }

    for (uint q = 0u; q < Q; ++q) {
        float delta = populationsOut[q * uniforms.grid.w + gid]
            - populationsIn[q * uniforms.grid.w + gid];
        ledger.observedGlobal += float4(delta, delta * float3(C[q]));
    }

    float f[19];
    float rho = 0.0f;
    float3 momentum = float3(0);
    uint boundaryLinkCount = 0u;
    uint farFieldLinkCount = 0u;
    bool interiorDomain = cell.x > 0u
        && cell.y > 0u
        && cell.z > 0u
        && cell.x + 1u < size.x
        && cell.y + 1u < size.y
        && cell.z + 1u < size.z;

    for (uint q = 0u; q < Q; ++q) {
        int3 sourceCell = int3(cell) - C[q];
        float value;
        bool useFarField = false;
        if (!interiorDomain && !inside(sourceCell, size)) {
            if (uniforms.flags.w != 0u) {
                sourceCell.x = sourceCell.x < 0
                    ? int(size.x) - 1
                    : (sourceCell.x >= int(size.x) ? 0 : sourceCell.x);
                sourceCell.y = sourceCell.y < 0
                    ? int(size.y) - 1
                    : (sourceCell.y >= int(size.y) ? 0 : sourceCell.y);
                sourceCell.z = sourceCell.z < 0
                    ? int(size.z) - 1
                    : (sourceCell.z >= int(size.z) ? 0 : sourceCell.z);
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
            float outgoing = populationsIn[
                OPP[q] * uniforms.grid.w + gid
            ];
            float massDelta = value - outgoing;
            float3 direction = float3(C[q]);
            ledger.farFieldGlobal += float4(
                massDelta,
                (value + outgoing) * direction
            );
            farFieldLinkCount += 1u;
        }
        else {
            uint source = flatten(uint3(sourceCell), size);
            if (solidCurrent[source] != 0) {
                float reflected = populationsIn[
                    OPP[q] * uniforms.grid.w + gid
                ];
                float3 direction = float3(C[q]);
                float linkFraction = 0.5f;
                float3 wall = wallVelocity[source].xyz;
                uint farther = 0u;
                bool interpolatedBoundary =
                    uniforms.caseParameters.w < -0.5f;
                if (interpolatedBoundary) {
                    linkFraction = clamp(
                        populationsIn[q * uniforms.grid.w + source],
                        1.0e-4f,
                        1.0f
                    );
                    wall = mix(
                        wallVelocity[gid].xyz,
                        wallVelocity[source].xyz,
                        linkFraction
                    );
                    if (linkFraction <= 0.5f) {
                        int3 fartherCell = int3(cell) + C[q];
                        if (inside(fartherCell, size)) {
                            farther = flatten(uint3(fartherCell), size);
                        }
                        if (!inside(fartherCell, size)
                            || solidCurrent[farther] != 0) {
                            interpolatedBoundary = false;
                            linkFraction = 0.5f;
                            wall = wallVelocity[source].xyz;
                        }
                    }
                }
                float wallCorrection = 2.0f
                    * W[q]
                    * uniforms.farFieldLattice.w
                    * dot(direction, wall)
                    / CS2;
                value = reflected + wallCorrection;
                if (interpolatedBoundary) {
                    if (linkFraction <= 0.5f) {
                        float fartherOutgoing = populationsIn[
                            OPP[q] * uniforms.grid.w + farther
                        ];
                        value = 2.0f * linkFraction * reflected
                            + (1.0f - 2.0f * linkFraction)
                                * fartherOutgoing
                            + wallCorrection;
                    }
                    else {
                        float previousIncoming = populationsIn[
                            q * uniforms.grid.w + gid
                        ];
                        value = (reflected + wallCorrection)
                                / (2.0f * linkFraction)
                            + (2.0f * linkFraction - 1.0f)
                                * previousIncoming
                                / (2.0f * linkFraction);
                    }
                }
                float massDelta = value - reflected;
                ledger.boundaryGlobal += float4(
                    massDelta,
                    (value + reflected) * direction
                );
                boundaryLinkCount += 1u;
            }
            else {
                value = populationsIn[q * uniforms.grid.w + source];
            }
        }
        f[q] = value;
        rho += value;
        momentum += value * float3(C[q]);
    }

    rho = max(rho, 1.0e-8f);
    float3 velocity = momentum / rho;
    float feq[19];
    for (uint q = 0u; q < Q; ++q) {
        feq[q] = equilibrium(q, rho, velocity);
    }
    float omegaPlus = uniforms.latticeAndSponge.x;
    float omegaMinus = uniforms.latticeAndSponge.y;
    float sponge = spongeFactor(
        cell,
        size,
        uniforms.latticeAndSponge.w,
        uniforms.latticeAndSponge.z
    );
    float symmetricIncrements[19];
    float antisymmetricIncrements[19];
    float symmetricScale = 1.0f;
    for (uint q = 0u; q < Q; ++q) {
        uint qo = OPP[q];
        float fPlus = 0.5f * (f[q] + f[qo]);
        float fMinus = 0.5f * (f[q] - f[qo]);
        float eqPlus = 0.5f * (feq[q] + feq[qo]);
        float eqMinus = 0.5f * (feq[q] - feq[qo]);
        float symmetricIncrement = -omegaPlus * (fPlus - eqPlus);
        float antisymmetricIncrement = -omegaMinus * (fMinus - eqMinus);
        symmetricIncrements[q] = symmetricIncrement;
        antisymmetricIncrements[q] = antisymmetricIncrement;
        if (symmetricIncrement < 0.0f) {
            float base = f[q] + antisymmetricIncrement;
            float populationFloor = max(
                1.0e-12f,
                1.0e-6f * max(feq[q], 0.0f)
            );
            if (base + symmetricIncrement < populationFloor) {
                float candidate = clamp(
                    (base - populationFloor)
                        / max(-symmetricIncrement, 1.0e-30f),
                    0.0f,
                    1.0f
                );
                symmetricScale = min(symmetricScale, candidate);
            }
        }
    }

    bool activated = symmetricScale < 1.0f;
    bool inControl = insideControlVolume(int3(cell), bounds);
    for (uint q = 0u; q < Q; ++q) {
        uint qo = OPP[q];
        float fPlus = 0.5f * (f[q] + f[qo]);
        float fMinus = 0.5f * (f[q] - f[qo]);
        float eqPlus = 0.5f * (feq[q] + feq[qo]);
        float eqMinus = 0.5f * (feq[q] - feq[qo]);
        float unlimited = f[q]
            - omegaPlus * (fPlus - eqPlus)
            - omegaMinus * (fMinus - eqMinus);
        float limited = activated
            ? f[q]
                + symmetricScale * symmetricIncrements[q]
                + antisymmetricIncrements[q]
            : unlimited;
        float actual = populationsOut[q * uniforms.grid.w + gid];
        float collisionDelta = unlimited - f[q];
        float limiterDelta = limited - unlimited;
        float spongeDelta = actual - limited;
        float3 direction = float3(C[q]);
        float4 collisionTerm = float4(
            collisionDelta,
            collisionDelta * direction
        );
        float4 limiterTerm = float4(
            limiterDelta,
            limiterDelta * direction
        );
        float4 spongeTerm = float4(
            spongeDelta,
            spongeDelta * direction
        );
        ledger.collisionGlobal += collisionTerm;
        ledger.limiterGlobal += limiterTerm;
        ledger.spongeGlobal += spongeTerm;
        float4 limiterNorm = float4(
            abs(limiterDelta),
            limiterDelta * limiterDelta,
            abs(collisionDelta),
            collisionDelta * collisionDelta
        );
        ledger.limiterNorms += limiterNorm;
        if (inControl) {
            ledger.collisionControl += collisionTerm;
            ledger.limiterControl += limiterTerm;
            ledger.spongeControl += spongeTerm;
            ledger.limiterControlNorms += limiterNorm;
        }
    }

    if (activated) {
        ledger.boundaryActivated = ledger.boundaryGlobal;
        ledger.spongeActivated = ledger.spongeGlobal;
    }
    ledger.counts = uint4(
        activated ? 1u : 0u,
        boundaryLinkCount,
        farFieldLinkCount,
        sponge > 0.0f ? 1u : 0u
    );
    ledger.activatedCounts = uint4(
        activated ? boundaryLinkCount : 0u,
        activated && sponge > 0.0f ? 1u : 0u,
        inControl && sponge > 0.0f ? 1u : 0u,
        inControl && activated ? 1u : 0u
    );
    ledgers[gid] = ledger;
}

kernel void reduceSymmetricLimiterLedger(
    device const GPUSymmetricLimiterLedger* input [[buffer(0)]],
    device GPUSymmetricLimiterLedger* output [[buffer(1)]],
    constant uint& inputCount [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    uint start = gid * 256u;
    if (start >= inputCount) {
        return;
    }
    GPUSymmetricLimiterLedger total;
    total.observedGlobal = float4(0);
    total.boundaryGlobal = float4(0);
    total.farFieldGlobal = float4(0);
    total.collisionGlobal = float4(0);
    total.limiterGlobal = float4(0);
    total.spongeGlobal = float4(0);
    total.collisionControl = float4(0);
    total.limiterControl = float4(0);
    total.spongeControl = float4(0);
    total.boundaryActivated = float4(0);
    total.spongeActivated = float4(0);
    total.limiterNorms = float4(0);
    total.limiterControlNorms = float4(0);
    total.counts = uint4(0);
    total.activatedCounts = uint4(0);
    uint end = min(start + 256u, inputCount);
    for (uint index = start; index < end; ++index) {
        total.observedGlobal += input[index].observedGlobal;
        total.boundaryGlobal += input[index].boundaryGlobal;
        total.farFieldGlobal += input[index].farFieldGlobal;
        total.collisionGlobal += input[index].collisionGlobal;
        total.limiterGlobal += input[index].limiterGlobal;
        total.spongeGlobal += input[index].spongeGlobal;
        total.collisionControl += input[index].collisionControl;
        total.limiterControl += input[index].limiterControl;
        total.spongeControl += input[index].spongeControl;
        total.boundaryActivated += input[index].boundaryActivated;
        total.spongeActivated += input[index].spongeActivated;
        total.limiterNorms += input[index].limiterNorms;
        total.limiterControlNorms += input[index].limiterControlNorms;
        total.counts += input[index].counts;
        total.activatedCounts += input[index].activatedCounts;
    }
    output[gid] = total;
}

/// Captures P(n) and the exact streaming flux before geometry reuses dormant
/// solid distribution slots for its link table.
kernel void measureControlVolumeMomentumBeforeStep(
    device const float* populationsBefore [[buffer(0)]],
    device const uchar* solidBefore [[buffer(1)]],
    device GPUControlVolumeBudget* partialBudgets [[buffer(2)]],
    constant GPUControlVolumeBounds& bounds [[buffer(3)]],
    constant GPUUniforms& uniforms [[buffer(4)]],
    uint gid [[thread_position_in_grid]],
    uint threadIndex [[thread_index_in_threadgroup]],
    uint threadgroupPosition [[threadgroup_position_in_grid]],
    uint threadsPerThreadgroup [[threads_per_threadgroup]]
) {
    threadgroup float4 groupOldMomentum[256];
    threadgroup float4 groupOutwardFlux[256];

    float3 oldMomentum = float3(0);
    float3 outwardFlux = float3(0);
    float solidCrossingLinkCount = 0.0f;

    if (gid < uniforms.grid.w) {
        uint3 cell = unflatten(gid, uniforms.grid.xyz);
        if (insideControlVolume(int3(cell), bounds)) {
            bool wasSolid = solidBefore[gid] != 0;

            for (uint q = 0; q < Q; ++q) {
                float3 direction = float3(C[q]);
                if (!wasSolid) {
                    float value = populationsBefore[
                        q * uniforms.grid.w + gid
                    ];
                    oldMomentum += value * direction;
                }
                if (q == 0u) {
                    continue;
                }

                int3 destination = int3(cell) + C[q];
                if (!insideControlVolume(destination, bounds)) {
                    if (wasSolid) {
                        solidCrossingLinkCount += 1.0f;
                    }
                    else {
                        float value = populationsBefore[
                            q * uniforms.grid.w + gid
                        ];
                        outwardFlux += value * direction;
                    }
                }

                int3 sourceCell = int3(cell) - C[q];
                if (!insideControlVolume(sourceCell, bounds)) {
                    uint source = flatten(uint3(sourceCell), uniforms.grid.xyz);
                    if (solidBefore[source] != 0) {
                        solidCrossingLinkCount += 1.0f;
                    }
                    else {
                        float value = populationsBefore[
                            q * uniforms.grid.w + source
                        ];
                        outwardFlux -= value * direction;
                    }
                }
            }
        }
    }

    groupOldMomentum[threadIndex] = float4(oldMomentum, 0);
    groupOutwardFlux[threadIndex] = float4(
        outwardFlux,
        solidCrossingLinkCount
    );
    threadgroup_barrier(mem_flags::mem_threadgroup);

    if (threadIndex == 0u) {
        float4 oldTotal = float4(0);
        float4 fluxTotal = float4(0);
        for (uint index = 0; index < threadsPerThreadgroup; ++index) {
            oldTotal += groupOldMomentum[index];
            fluxTotal += groupOutwardFlux[index];
        }
        partialBudgets[threadgroupPosition].oldFluidMomentum = oldTotal;
        partialBudgets[threadgroupPosition].newFluidMomentum = float4(0);
        partialBudgets[threadgroupPosition].outwardMomentumFlux = fluxTotal;
        partialBudgets[threadgroupPosition].topologyReservoirCorrection =
            float4(0);
    }
}

/// Captures P(n+1) after the fused stream/collision step. Geometry preserves
/// the old density of every newly covered cell in coveredFluidMomentum.w, so
/// the moving-occupancy reservoir correction does not reread overwritten
/// distribution slots or reuse the force accumulator.
kernel void measureControlVolumeMomentumAfterStep(
    device const float* populationsAfter [[buffer(0)]],
    device const uchar* solidBefore [[buffer(1)]],
    device const uchar* solidAfter [[buffer(2)]],
    device const float4* wallVelocity [[buffer(3)]],
    device const float4* coveredFluidMomentum [[buffer(4)]],
    device GPUControlVolumeBudget* partialBudgets [[buffer(5)]],
    constant GPUControlVolumeBounds& bounds [[buffer(6)]],
    constant GPUUniforms& uniforms [[buffer(7)]],
    uint gid [[thread_position_in_grid]],
    uint threadIndex [[thread_index_in_threadgroup]],
    uint threadgroupPosition [[threadgroup_position_in_grid]],
    uint threadsPerThreadgroup [[threads_per_threadgroup]]
) {
    threadgroup float4 groupNewMomentum[256];
    threadgroup float4 groupTopologyCorrection[256];
    float3 newMomentum = float3(0);
    float3 topologyCorrection = float3(0);
    float newlyUncoveredCount = 0.0f;
    float newlyCoveredCount = 0.0f;

    if (gid < uniforms.grid.w) {
        uint3 cell = unflatten(gid, uniforms.grid.xyz);
        if (insideControlVolume(int3(cell), bounds)) {
            bool wasSolid = solidBefore[gid] != 0;
            bool isSolid = solidAfter[gid] != 0;
            if (!isSolid) {
                for (uint q = 0; q < Q; ++q) {
                    float value = populationsAfter[
                        q * uniforms.grid.w + gid
                    ];
                    newMomentum += value * float3(C[q]);
                }
            }
            if (wasSolid && !isSolid) {
                topologyCorrection += newMomentum;
                newlyUncoveredCount = 1.0f;
            }
            else if (!wasSolid && isSolid) {
                topologyCorrection -= coveredFluidMomentum[gid].w
                    * wallVelocity[gid].xyz;
                newlyCoveredCount = 1.0f;
            }
        }
    }

    groupNewMomentum[threadIndex] = float4(
        newMomentum,
        newlyUncoveredCount
    );
    groupTopologyCorrection[threadIndex] = float4(
        topologyCorrection,
        newlyCoveredCount
    );
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (threadIndex == 0u) {
        float4 newTotal = float4(0);
        float4 topologyTotal = float4(0);
        for (uint index = 0; index < threadsPerThreadgroup; ++index) {
            newTotal += groupNewMomentum[index];
            topologyTotal += groupTopologyCorrection[index];
        }
        partialBudgets[threadgroupPosition].oldFluidMomentum = float4(0);
        partialBudgets[threadgroupPosition].newFluidMomentum = newTotal;
        partialBudgets[threadgroupPosition].outwardMomentumFlux = float4(0);
        partialBudgets[threadgroupPosition].topologyReservoirCorrection =
            topologyTotal;
    }
}

kernel void reduceControlVolumeMomentumBudget(
    device const GPUControlVolumeBudget* input [[buffer(0)]],
    device GPUControlVolumeBudget* output [[buffer(1)]],
    constant uint& inputCount [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    uint start = gid * 256u;
    if (start >= inputCount) {
        return;
    }
    float4 oldMomentum = float4(0);
    float4 newMomentum = float4(0);
    float4 outwardFlux = float4(0);
    float4 topologyCorrection = float4(0);
    uint end = min(start + 256u, inputCount);
    for (uint index = start; index < end; ++index) {
        oldMomentum += input[index].oldFluidMomentum;
        newMomentum += input[index].newFluidMomentum;
        outwardFlux += input[index].outwardMomentumFlux;
        topologyCorrection += input[index].topologyReservoirCorrection;
    }
    output[gid].oldFluidMomentum = oldMomentum;
    output[gid].newFluidMomentum = newMomentum;
    output[gid].outwardMomentumFlux = outwardFlux;
    output[gid].topologyReservoirCorrection = topologyCorrection;
}

kernel void storeControlVolumeMomentumBeforeSample(
    device const GPUControlVolumeBudget* total [[buffer(0)]],
    device GPUControlVolumeBudget* history [[buffer(1)]],
    constant uint& sampleIndex [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid == 0u) {
        history[sampleIndex].oldFluidMomentum = total[0].oldFluidMomentum;
        history[sampleIndex].outwardMomentumFlux =
            total[0].outwardMomentumFlux;
        history[sampleIndex].newFluidMomentum = float4(0);
        history[sampleIndex].topologyReservoirCorrection = float4(0);
    }
}

kernel void storeControlVolumeMomentumAfterSample(
    device const GPUControlVolumeBudget* total [[buffer(0)]],
    device GPUControlVolumeBudget* history [[buffer(1)]],
    constant uint& sampleIndex [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid == 0u) {
        history[sampleIndex].newFluidMomentum = total[0].newFluidMomentum;
        history[sampleIndex].topologyReservoirCorrection =
            total[0].topologyReservoirCorrection;
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
    float activationCount = 0.0f;
    float maximumRestriction = 0.0f;
    uint end = min(start + 256u, inputCount);
    for (uint index = start; index < end; ++index) {
        force += input[index].force.xyz;
        torque += input[index].torque.xyz;
        activationCount += input[index].force.w;
        maximumRestriction = max(
            maximumRestriction,
            input[index].torque.w
        );
    }

    output[gid].force = float4(force, activationCount);
    output[gid].torque = float4(torque, maximumRestriction);
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

/// Stores the compact record after the optional body integration dispatch, so
/// each sample's pose and load refer to the same completed solver step.
kernel void storeRunSample(
    device GPURunSample* samples [[buffer(0)]],
    constant GPUBirdBodyState& body [[buffer(1)]],
    device const GPUForceTorque& load [[buffer(2)]],
    constant uint4& indices [[buffer(3)]],
    constant float& time [[buffer(4)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid != 0u) {
        return;
    }
    uint sampleIndex = indices.x;
    samples[sampleIndex].timeAndPosition = float4(time, body.position.xyz);
    samples[sampleIndex].orientation = body.orientation;
    samples[sampleIndex].linearVelocity = body.linearVelocity;
    samples[sampleIndex].angularVelocityBody = body.angularVelocityBody;
    samples[sampleIndex].force = load.force;
    samples[sampleIndex].torque = load.torque;
    samples[sampleIndex].step = uint4(indices.y, indices.z, 0, 0);
}

/// Audit-only sparse readback. Production keeps the link fractions in dormant
/// solid-node distribution slots; this gathers just the boundary entries that
/// the CPU geometry audit requests instead of copying the full Q*N buffer.
kernel void gatherFloatValues(
    device const float* values [[buffer(0)]],
    device const uint* indices [[buffer(1)]],
    device float* gathered [[buffer(2)]],
    constant uint& count [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid < count) {
        gathered[gid] = values[indices[gid]];
    }
}

/// Reduces all direction-major populations to one deterministic minimum per
/// 256-lane threadgroup. Ties select the lowest linear population index.
kernel void reducePopulationMinimum(
    device const float* populations [[buffer(0)]],
    device GPUPopulationMinimum* partials [[buffer(1)]],
    constant uint& populationCount [[buffer(2)]],
    uint gid [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint group [[threadgroup_position_in_grid]]
) {
    threadgroup float comparisonValues[256];
    threadgroup float rawValues[256];
    threadgroup uint indices[256];
    threadgroup uint nonFiniteFlags[256];

    float raw = as_type<float>(0x7f800000u);
    float comparison = raw;
    uint index = 0xffffffffu;
    uint nonFinite = 0u;
    if (gid < populationCount) {
        raw = populations[gid];
        index = gid;
        nonFinite = isfinite(raw) ? 0u : 1u;
        comparison = nonFinite == 0u
            ? raw
            : as_type<float>(0xff800000u);
    }
    comparisonValues[tid] = comparison;
    rawValues[tid] = raw;
    indices[tid] = index;
    nonFiniteFlags[tid] = nonFinite;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = 128u; stride > 0u; stride >>= 1u) {
        if (tid < stride) {
            uint other = tid + stride;
            bool replace = comparisonValues[other] < comparisonValues[tid]
                || (comparisonValues[other] == comparisonValues[tid]
                    && indices[other] < indices[tid]);
            if (replace) {
                comparisonValues[tid] = comparisonValues[other];
                rawValues[tid] = rawValues[other];
                indices[tid] = indices[other];
                nonFiniteFlags[tid] = nonFiniteFlags[other];
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0u) {
        partials[group] = {
            comparisonValues[0],
            rawValues[0],
            indices[0],
            nonFiniteFlags[0]
        };
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
