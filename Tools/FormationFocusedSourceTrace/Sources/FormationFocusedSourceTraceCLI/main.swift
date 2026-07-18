import BirdFlowMetal
import CryptoKit
import Foundation

enum CLIError: Error, CustomStringConvertible {
    case usage(String)

    var description: String {
        switch self {
        case .usage(let message): return message
        }
    }
}

func value(after flag: String, in arguments: [String]) throws -> String? {
    guard let index = arguments.firstIndex(of: flag) else { return nil }
    guard index + 1 < arguments.count else {
        throw CLIError.usage("Missing value after \(flag)")
    }
    return arguments[index + 1]
}

func vector(
    after flag: String,
    in arguments: [String],
    fallback: SIMD3<Double>
) throws -> SIMD3<Double> {
    guard let raw = try value(after: flag, in: arguments) else {
        return fallback
    }
    let components = raw.split(separator: ",")
    guard components.count == 3,
          let x = Double(components[0]),
          let y = Double(components[1]),
          let z = Double(components[2]) else {
        throw CLIError.usage("\(flag) requires x,y,z")
    }
    return SIMD3(x, y, z)
}

func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data)
        .map { String(format: "%02x", $0) }
        .joined()
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard let archive = try value(after: "--archive", in: arguments),
          let referencePath = try value(after: "--reference", in: arguments)
    else {
        throw CLIError.usage("--archive and --reference are required")
    }
    let chordCells = try value(after: "--chord-cells", in: arguments).map {
        guard let parsed = Int($0) else {
            throw CLIError.usage("Invalid --chord-cells value: \($0)")
        }
        return parsed
    } ?? 18
    let cycles = try value(after: "--cycles", in: arguments).map {
        guard let parsed = Int($0) else {
            throw CLIError.usage("Invalid --cycles value: \($0)")
        }
        return parsed
    } ?? 5
    let directionIndex = try value(
        after: "--direction-index",
        in: arguments
    ).map {
        guard let parsed = Int($0) else {
            throw CLIError.usage("Invalid --direction-index value: \($0)")
        }
        return parsed
    } ?? 5
    let flyer = try value(after: "--flyer", in: arguments).map {
        guard let parsed = FormationFlyerID(rawValue: $0) else {
            throw CLIError.usage("--flyer must be leader or follower")
        }
        return parsed
    } ?? .leader
    let followerOffset = try vector(
        after: "--follower-offset-chords",
        in: arguments,
        fallback: SIMD3(0, 0, -3)
    )
    let subcellOffset = try vector(
        after: "--subcell-offset-cells",
        in: arguments,
        fallback: SIMD3(0.25, 0.25, 0.75)
    )
    let phaseOffset = try value(after: "--phase-offset", in: arguments).map {
        guard let parsed = Double($0) else {
            throw CLIError.usage("Invalid --phase-offset value: \($0)")
        }
        return parsed
    } ?? 0.25
    let referenceData = try Data(
        contentsOf: URL(fileURLWithPath: referencePath)
    )
    let reference = try JSONDecoder().decode(
        FormationFlightSubcellBoundarySourceReport.self,
        from: referenceData
    )
    let report = try MetalFormationFlightValidator
        .runFocusedBoundarySourceTemporalTrace(
            configuration: FormationFlightConfiguration(
                chordCells: chordCells,
                cycles: cycles,
                followerOffsetChords: followerOffset,
                followerPhaseOffsetCycles: phaseOffset
            ),
            subcellOffsetCells: subcellOffset,
            flyer: flyer,
            directionIndex: directionIndex,
            referenceReport: reference,
            referenceReportSHA256: sha256Hex(referenceData),
            archiveDirectory: URL(fileURLWithPath: archive)
        )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(report))
    FileHandle.standardOutput.write(Data("\n".utf8))
    if !report.gates.passed { exit(2) }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
