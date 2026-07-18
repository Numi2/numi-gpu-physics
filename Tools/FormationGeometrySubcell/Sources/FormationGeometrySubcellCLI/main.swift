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
    let divisions = try value(after: "--divisions", in: arguments).map {
        guard let value = Int($0) else {
            throw CLIError.usage("Invalid --divisions value: \($0)")
        }
        return value
    } ?? 4
    guard let output = try value(after: "--output", in: arguments) else {
        throw CLIError.usage("--output is required")
    }
    let report = try MetalFormationGeometrySubcellEnsembleValidator.run(
        offsetDivisionsPerAxis: divisions
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)
    let url = URL(fileURLWithPath: output)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
    if !report.passed { exit(2) }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
