#!/usr/bin/env python3
"""Static cross-language audit that does not require Apple's Metal compiler."""

from __future__ import annotations

import pathlib
import re
import sys
from fractions import Fraction

ROOT = pathlib.Path(__file__).resolve().parents[1]
SHADER = ROOT / "Sources/BirdFlowMetal/Metal/BirdFlow.metal"
SWIFT_FILES = (
    ROOT / "Sources/BirdFlowMetal/BirdFlowSimulation.swift",
    ROOT / "Sources/BirdFlowMetal/MetalShearWaveValidation.swift",
    ROOT / "Sources/BirdFlowMetal/MetalMovingWallValidation.swift",
    ROOT / "Sources/BirdFlowMetal/MetalSphereValidation.swift",
    ROOT / "Sources/BirdFlowMetal/MetalWingValidation.swift",
)
CORE = ROOT / "Sources/BirdFlowCore/D3Q19.swift"
GPU_DATA = ROOT / "Sources/BirdFlowMetal/GPUData.swift"

REQUIRED_KERNELS = {
    "buildBirdGeometry",
    "prepareBirdGeometry",
    "initializePopulations",
    "initializeShearWave",
    "initializePlanarChannel",
    "initializeSphereCase",
    "initializeFixedWingCase",
    "updatePlanarWallVelocity",
    "stepFluidTRT",
    "reduceForceTorque",
    "integrateBirdBody",
}


def fail(message: str) -> None:
    print(f"static-audit: {message}", file=sys.stderr)
    raise SystemExit(1)


def extract_ints(block: str) -> list[int]:
    return [int(token) for token in re.findall(r"(?<![A-Za-z0-9_.])-?\d+", block)]


def extract_fractions(block: str) -> list[Fraction]:
    return [
        Fraction(numerator) / Fraction(denominator)
        for numerator, denominator in re.findall(
            r"(-?\d+(?:\.\d+)?)f?\s*/\s*(-?\d+(?:\.\d+)?)f?",
            block,
        )
    ]


def extract_braced_body(source: str, declaration: str) -> str:
    start = source.find(declaration)
    if start < 0:
        fail(f"unable to locate declaration: {declaration}")
    brace = source.find("{", start)
    if brace < 0:
        fail(f"unable to locate body for: {declaration}")

    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    fail(f"unterminated body for: {declaration}")
    return ""


def main() -> int:
    shader = SHADER.read_text(encoding="utf-8")
    swift = "\n".join(path.read_text(encoding="utf-8") for path in SWIFT_FILES)
    core = CORE.read_text(encoding="utf-8")
    gpu_data = GPU_DATA.read_text(encoding="utf-8")

    kernels = set(re.findall(r"\bkernel\s+void\s+(\w+)\s*\(", shader))
    if kernels != REQUIRED_KERNELS:
        fail(
            "Metal entry points differ from the expected set: "
            f"expected={sorted(REQUIRED_KERNELS)}, actual={sorted(kernels)}"
        )

    pipelines = set(re.findall(
        r'pipeline\(\s*named:\s*"([^"]+)"\s*\)',
        swift,
        re.S,
    ))
    if pipelines != REQUIRED_KERNELS:
        fail(
            "Swift pipeline names differ from Metal entry points: "
            f"pipelines={sorted(pipelines)}"
        )

    c_block = re.search(
        r"constant\s+int3\s+C\[19\]\s*=\s*\{(.*?)\};",
        shader,
        re.S,
    )
    opp_block = re.search(
        r"constant\s+uint\s+OPP\[19\]\s*=\s*\{(.*?)\};",
        shader,
        re.S,
    )
    weight_block = re.search(
        r"constant\s+float\s+W\[19\]\s*=\s*\{(.*?)\};",
        shader,
        re.S,
    )
    if c_block is None or opp_block is None or weight_block is None:
        fail("unable to locate D3Q19 tables in Metal source")

    directions = re.findall(r"int3\(([^)]+)\)", c_block.group(1))
    opposites = extract_ints(opp_block.group(1))
    if len(directions) != 19 or len(opposites) != 19:
        fail(
            f"invalid table lengths: directions={len(directions)}, "
            f"opposites={len(opposites)}"
        )

    parsed = [tuple(int(v.strip()) for v in entry.split(",")) for entry in directions]
    for q, opposite in enumerate(opposites):
        if not 0 <= opposite < 19 or opposites[opposite] != q:
            fail(f"opposite table is not involutive at direction {q}")
        if parsed[opposite] != tuple(-v for v in parsed[q]):
            fail(f"opposite direction mismatch at direction {q}")

    if "public static let count = 19" not in core:
        fail("Swift D3Q19 direction count is not 19")

    swift_c_block = re.search(
        r"public\s+static\s+let\s+directions:.*?=\s*\[(.*?)\]",
        core,
        re.S,
    )
    swift_weight_block = re.search(
        r"public\s+static\s+let\s+weights:.*?=\s*\[(.*?)\]",
        core,
        re.S,
    )
    swift_opp_block = re.search(
        r"public\s+static\s+let\s+opposite:.*?=\s*\[(.*?)\]",
        core,
        re.S,
    )
    if swift_c_block is None or swift_weight_block is None or swift_opp_block is None:
        fail("unable to locate Swift D3Q19 tables")

    swift_direction_entries = re.findall(
        r"SIMD3<Int32>\(([^)]+)\)", swift_c_block.group(1)
    )
    swift_directions = [
        tuple(int(value.strip()) for value in entry.split(","))
        for entry in swift_direction_entries
    ]
    swift_weights = extract_fractions(swift_weight_block.group(1))
    metal_weights = extract_fractions(weight_block.group(1))
    swift_opposites = extract_ints(swift_opp_block.group(1))
    if swift_directions != parsed:
        fail("Swift and Metal D3Q19 direction tables differ")
    if swift_weights != metal_weights or len(swift_weights) != 19:
        fail("Swift and Metal D3Q19 weight tables differ")
    if swift_opposites != opposites:
        fail("Swift and Metal D3Q19 opposite tables differ")

    if shader.count("{") != shader.count("}"):
        fail("Metal source has unbalanced braces")

    shared_structs = {
        "GPUUniforms": [
            "grid", "originAndCellSize", "timeStepAndScales",
            "latticeAndSponge", "farFieldLattice", "gravity",
            "caseParameters", "flags",
        ],
        "GPUBirdParameters": [
            "bodyRadiiAndMass", "inertia", "wingGeometry0",
            "wingGeometry1", "tailGeometry", "wingKinematics0",
            "wingKinematics1",
        ],
        "GPUBirdBodyState": [
            "position", "orientation", "linearVelocity",
            "angularVelocityBody",
        ],
        "GPUPreparedBirdGeometry": [
            "bodyPosition", "orientation", "linearVelocity", "omegaBodyWorld",
            "leftRoot", "leftChord", "leftSpan", "leftNormal",
            "leftAngularVelocity", "rightRoot", "rightChord", "rightSpan",
            "rightNormal", "rightAngularVelocity",
        ],
        "GPUForceTorque": ["force", "torque"],
    }
    for struct_name, expected_fields in shared_structs.items():
        metal_body = extract_braced_body(shader, f"struct {struct_name}")
        swift_body = extract_braced_body(gpu_data, f"struct {struct_name}")
        metal_fields = re.findall(
            r"\b(?:float4|uint4)\s+(\w+)\s*;", metal_body
        )
        swift_fields = re.findall(
            r"\bvar\s+(\w+)\s*:\s*SIMD4<", swift_body
        )
        if metal_fields != expected_fields or swift_fields != expected_fields:
            fail(
                f"shared struct {struct_name} differs across Swift/Metal: "
                f"Swift={swift_fields}, Metal={metal_fields}"
            )

    expected_swift_bindings = {
        "private func encodeInitialization()": 6,
        "private func encodeShearInitialization()": 4,
        "private func encodePlanarInitialization()": 7,
        "private func encodeCanonicalInitialization()": 7,
        "private func encodePlanarWallUpdate(": 2,
        "private func encodeGeometryPreparation(": 4,
        "private func encodeGeometry(": 6,
        "private func encodeFluidStep(": 10,
        "private func encodeShearFluidStep(": 10,
        "private func encodePlanarFluidStep(": 10,
        "private func encodeCanonicalFluidStep(": 10,
        "private func encodeReduction(": 3,
        "private func encodePlanarReduction(": 3,
        "private func encodeCanonicalReduction(": 3,
        "private func encodeBodyIntegration(": 4,
    }
    for declaration, count in expected_swift_bindings.items():
        body = extract_braced_body(swift, declaration)
        buffer_indices = [
            int(value)
            for value in re.findall(
                r"encoder\.setBuffer\(.*?index:\s*(\d+)\s*\)",
                body,
                re.S,
            )
        ]
        byte_indices = [
            int(value)
            for value in re.findall(
                r"encoder\.setBytes\(.*?index:\s*(\d+)\s*\)",
                body,
                re.S,
            )
        ]
        indices = sorted(buffer_indices + byte_indices)
        if indices != list(range(count)):
            fail(
                f"Swift binding indices for {declaration} are not contiguous: "
                f"{indices}"
            )

    expected_buffers = {
        "buildBirdGeometry": 6,
        "prepareBirdGeometry": 4,
        "initializePopulations": 6,
        "initializeShearWave": 4,
        "initializePlanarChannel": 7,
        "initializeSphereCase": 7,
        "initializeFixedWingCase": 7,
        "updatePlanarWallVelocity": 2,
        "stepFluidTRT": 10,
        "reduceForceTorque": 3,
        "integrateBirdBody": 4,
    }
    for kernel, count in expected_buffers.items():
        match = re.search(
            rf"kernel\s+void\s+{kernel}\s*\((.*?)\)\s*\{{",
            shader,
            re.S,
        )
        if match is None:
            fail(f"unable to inspect signature for {kernel}")
        indices = sorted(int(value) for value in re.findall(r"\[\[buffer\((\d+)\)\]\]", match.group(1)))
        if indices != list(range(count)):
            fail(f"{kernel} buffer indices are not contiguous: {indices}")

    binding_contracts = {
        "prepareBirdGeometry": (
            "private func encodeGeometryPreparation(",
            ["preparedGeometryBuffer", "birdParametersBuffer", "bodyStateBuffer", "uniforms"],
            ["prepared", "bird", "body", "uniforms"],
        ),
        "buildBirdGeometry": (
            "private func encodeGeometry(",
            ["targetMask", "wallVelocity", "currentSolidMask", "birdParametersBuffer", "preparedGeometryBuffer", "uniforms"],
            ["solid", "wallVelocity", "solidPrevious", "bird", "prepared", "uniforms"],
        ),
        "initializePopulations": (
            "private func encodeInitialization()",
            ["populationsA", "currentSolidMask", "wallVelocity", "density", "velocity", "uniforms"],
            ["populationsA", "solid", "wallVelocity", "density", "velocity", "uniforms"],
        ),
        "initializeShearWave": (
            "private func encodeShearInitialization()",
            ["populationsA", "density", "velocity", "uniforms"],
            ["populations", "density", "velocity", "uniforms"],
        ),
        "initializePlanarChannel": (
            "private func encodePlanarInitialization()",
            ["populationsA", "solidMaskA", "solidMaskB", "wallVelocity", "density", "velocity", "uniforms"],
            ["populations", "solidA", "solidB", "wallVelocity", "density", "velocity", "uniforms"],
        ),
        "initializeSphereCase": (
            "private func encodeCanonicalInitialization()",
            ["populationsA", "solidMaskA", "solidMaskB", "wallVelocity", "density", "velocity", "uniforms"],
            ["populations", "solidA", "solidB", "wallVelocity", "density", "velocity", "uniforms"],
        ),
        "initializeFixedWingCase": (
            "private func encodeCanonicalInitialization()",
            ["populationsA", "solidMaskA", "solidMaskB", "wallVelocity", "density", "velocity", "uniforms"],
            ["populations", "solidA", "solidB", "wallVelocity", "density", "velocity", "uniforms"],
        ),
        "updatePlanarWallVelocity": (
            "private func encodePlanarWallUpdate(",
            ["wallVelocity", "uniforms"],
            ["wallVelocity", "uniforms"],
        ),
        "stepFluidTRT": (
            "private func encodeFluidStep(",
            ["currentPopulations", "nextPopulations", "currentSolidMask", "nextSolidMask", "wallVelocity", "density", "velocity", "reductionA", "bodyStateBuffer", "uniforms"],
            ["populationsIn", "populationsOut", "solidPrevious", "solidCurrent", "wallVelocity", "density", "velocity", "partialLoads", "body", "uniforms"],
        ),
        "reduceForceTorque": (
            "private func encodeReduction(",
            ["input", "output", "count32"],
            ["input", "output", "inputCount"],
        ),
        "integrateBirdBody": (
            "private func encodeBodyIntegration(",
            ["bodyStateBuffer", "birdParametersBuffer", "loadBuffer", "uniforms"],
            ["body", "bird", "totalLoad", "uniforms"],
        ),
    }
    for kernel, (declaration, expected_swift, expected_metal) in binding_contracts.items():
        swift_body = extract_braced_body(swift, declaration)
        swift_pairs = re.findall(
            r"encoder\.setBuffer\(\s*(\w+)\s*,.*?index:\s*(\d+)\s*\)",
            swift_body,
            re.S,
        ) + re.findall(
            r"encoder\.setBytes\(\s*&?(\w+)\s*,.*?index:\s*(\d+)\s*\)",
            swift_body,
            re.S,
        )
        swift_names = [
            name for name, _ in sorted(swift_pairs, key=lambda pair: int(pair[1]))
        ]

        signature = re.search(
            rf"kernel\s+void\s+{kernel}\s*\((.*?)\)\s*\{{",
            shader,
            re.S,
        )
        if signature is None:
            fail(f"unable to inspect binding names for {kernel}")
        metal_pairs = re.findall(
            r"\b(\w+)\s*\[\[buffer\((\d+)\)\]\]",
            signature.group(1),
        )
        metal_names = [
            name for name, _ in sorted(metal_pairs, key=lambda pair: int(pair[1]))
        ]
        if swift_names != expected_swift or metal_names != expected_metal:
            fail(
                f"binding contract differs for {kernel}: "
                f"Swift={swift_names}, Metal={metal_names}"
            )

    shear_step_body = extract_braced_body(
        swift,
        "private func encodeShearFluidStep(",
    )
    shear_step_pairs = re.findall(
        r"encoder\.setBuffer\(\s*(\w+)\s*,.*?index:\s*(\d+)\s*\)",
        shear_step_body,
        re.S,
    ) + re.findall(
        r"encoder\.setBytes\(\s*&?(\w+)\s*,.*?index:\s*(\d+)\s*\)",
        shear_step_body,
        re.S,
    )
    shear_step_names = [
        name
        for name, _ in sorted(
            shear_step_pairs,
            key=lambda pair: int(pair[1]),
        )
    ]
    expected_shear_step = [
        "currentPopulations", "nextPopulations", "solidMaskA",
        "solidMaskB", "wallVelocity", "density", "velocity",
        "partialLoads", "bodyState", "uniforms",
    ]
    if shear_step_names != expected_shear_step:
        fail(
            "alternate shear-wave stepFluidTRT bindings differ: "
            f"Swift={shear_step_names}"
        )

    planar_step_body = extract_braced_body(
        swift,
        "private func encodePlanarFluidStep(",
    )
    planar_step_pairs = re.findall(
        r"encoder\.setBuffer\(\s*(\w+)\s*,.*?index:\s*(\d+)\s*\)",
        planar_step_body,
        re.S,
    ) + re.findall(
        r"encoder\.setBytes\(\s*&?(\w+)\s*,.*?index:\s*(\d+)\s*\)",
        planar_step_body,
        re.S,
    )
    planar_step_names = [
        name
        for name, _ in sorted(
            planar_step_pairs,
            key=lambda pair: int(pair[1]),
        )
    ]
    expected_planar_step = [
        "currentPopulations", "nextPopulations", "solidMaskA",
        "solidMaskB", "wallVelocity", "density", "velocity",
        "reductionA", "bodyState", "uniforms",
    ]
    if planar_step_names != expected_planar_step:
        fail(
            "alternate planar-wall stepFluidTRT bindings differ: "
            f"Swift={planar_step_names}"
        )

    canonical_step_body = extract_braced_body(
        swift,
        "private func encodeCanonicalFluidStep(",
    )
    canonical_step_pairs = re.findall(
        r"encoder\.setBuffer\(\s*(\w+)\s*,.*?index:\s*(\d+)\s*\)",
        canonical_step_body,
        re.S,
    ) + re.findall(
        r"encoder\.setBytes\(\s*&?(\w+)\s*,.*?index:\s*(\d+)\s*\)",
        canonical_step_body,
        re.S,
    )
    canonical_step_names = [
        name
        for name, _ in sorted(
            canonical_step_pairs,
            key=lambda pair: int(pair[1]),
        )
    ]
    expected_canonical_step = [
        "currentPopulations", "nextPopulations", "solidMaskA",
        "solidMaskB", "wallVelocity", "density", "velocity",
        "reductionA", "bodyState", "uniforms",
    ]
    if canonical_step_names != expected_canonical_step:
        fail(
            "alternate static-canonical stepFluidTRT bindings differ: "
            f"Swift={canonical_step_names}"
        )

    print(
        "static-audit: kernels, pipelines, shared layouts, cross-language "
        "D3Q19 tables, named buffer contracts, and braces are consistent"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
