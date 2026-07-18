import BirdFlowMetal
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

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let chordCells = try value(after: "--chord-cells", in: arguments).map {
        try $0.split(separator: ",").map { token -> Int in
            guard let value = Int(token) else {
                throw CLIError.usage("Invalid --chord-cells value: \(token)")
            }
            return value
        }
    } ?? MetalFormationGeometryCensusValidator.defaultChordCells
    let leaderPhase = try value(after: "--leader-phase", in: arguments).map {
        guard let value = Double($0) else {
            throw CLIError.usage("Invalid --leader-phase value: \($0)")
        }
        return value
    } ?? MetalFormationGeometryCensusValidator.defaultLeaderPhase
    let offsetZ = try value(after: "--offset-z", in: arguments).map {
        guard let value = Double($0) else {
            throw CLIError.usage("Invalid --offset-z value: \($0)")
        }
        return value
    } ?? MetalFormationGeometryCensusValidator.defaultFollowerOffsetChords.z
    let phaseOffset = try value(after: "--phase-offset", in: arguments).map {
        guard let value = Double($0) else {
            throw CLIError.usage("Invalid --phase-offset value: \($0)")
        }
        return value
    } ?? MetalFormationGeometryCensusValidator.defaultFollowerPhaseOffsetCycles
    let output = try value(after: "--output", in: arguments)

    let report = try MetalFormationGeometryCensusValidator.run(
        chordCells: chordCells,
        leaderPhase: leaderPhase,
        followerOffsetChords: SIMD3<Double>(0, 0, offsetZ),
        followerPhaseOffsetCycles: phaseOffset
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    if let output {
        let url = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
    if !report.passed { exit(2) }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
