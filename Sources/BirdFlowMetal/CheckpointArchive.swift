import BirdFlowCore
import Compression
import CryptoKit
import Foundation

public enum BirdFlowCheckpointError: Error, CustomStringConvertible {
  case invalidArchive(String)
  case checksumMismatch(String)
  case compressionFailed

  public var description: String {
    switch self {
    case .invalidArchive(let message):
      return "Invalid BirdFlow checkpoint: \(message)"
    case .checksumMismatch(let name):
      return "BirdFlow checkpoint checksum failed for \(name)."
    case .compressionFailed:
      return "BirdFlow checkpoint LZFSE compression failed."
    }
  }
}

struct BirdFlowCheckpointManifest: Codable {
  static let schemaVersion = 1

  var schema: Int
  var configuration: SimulationConfiguration
  var bird: BirdParameters
  var step: UInt64
  var timeSeconds: Float
  var body: BirdBodyState
  var load: ForceTorque
  var geometry: BirdGeometryFrame
  var populationBytes: Int
  var solidMaskBytes: Int
  var populationSHA256: String
  var solidMaskSHA256: String
}

enum CheckpointArchive {
  static let manifestName = "manifest.json"
  static let populationsName = "populations.lzfse"
  static let maskName = "solid-mask.lzfse"

  static func write(
    manifest: BirdFlowCheckpointManifest,
    populations: Data,
    solidMask: Data,
    to destination: URL
  ) throws {
    let manager = FileManager.default
    let temporary = destination.deletingLastPathComponent()
      .appendingPathComponent(".\(destination.lastPathComponent)-\(UUID().uuidString)")
    try manager.createDirectory(
      at: temporary,
      withIntermediateDirectories: true
    )
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      try encoder.encode(manifest).write(
        to: temporary.appendingPathComponent(manifestName),
        options: .atomic
      )
      try compress(populations).write(
        to: temporary.appendingPathComponent(populationsName),
        options: .atomic
      )
      try compress(solidMask).write(
        to: temporary.appendingPathComponent(maskName),
        options: .atomic
      )
      if manager.fileExists(atPath: destination.path) {
        try manager.removeItem(at: destination)
      }
      try manager.moveItem(at: temporary, to: destination)
    } catch {
      try? manager.removeItem(at: temporary)
      throw error
    }
  }

  static func read(
    from source: URL
  ) throws -> (BirdFlowCheckpointManifest, Data, Data) {
    let decoder = JSONDecoder()
    let manifest = try decoder.decode(
      BirdFlowCheckpointManifest.self,
      from: Data(contentsOf: source.appendingPathComponent(manifestName))
    )
    guard manifest.schema == BirdFlowCheckpointManifest.schemaVersion,
      manifest.populationBytes > 0,
      manifest.solidMaskBytes > 0
    else {
      throw BirdFlowCheckpointError.invalidArchive(
        "unsupported schema or empty numerical state"
      )
    }
    let populations = try decompress(
      Data(contentsOf: source.appendingPathComponent(populationsName)),
      expectedSize: manifest.populationBytes
    )
    let mask = try decompress(
      Data(contentsOf: source.appendingPathComponent(maskName)),
      expectedSize: manifest.solidMaskBytes
    )
    guard sha256(populations) == manifest.populationSHA256 else {
      throw BirdFlowCheckpointError.checksumMismatch(populationsName)
    }
    guard sha256(mask) == manifest.solidMaskSHA256 else {
      throw BirdFlowCheckpointError.checksumMismatch(maskName)
    }
    return (manifest, populations, mask)
  }

  static func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  static func compress(_ source: Data) throws -> Data {
    guard !source.isEmpty else { return Data() }
    var capacity = source.count + 65_536
    for _ in 0..<4 {
      var destination = Data(count: capacity)
      let written = destination.withUnsafeMutableBytes { output in
        source.withUnsafeBytes { input in
          compression_encode_buffer(
            output.bindMemory(to: UInt8.self).baseAddress!,
            capacity,
            input.bindMemory(to: UInt8.self).baseAddress!,
            source.count,
            nil,
            COMPRESSION_LZFSE
          )
        }
      }
      if written > 0 {
        destination.count = written
        return destination
      }
      capacity *= 2
    }
    throw BirdFlowCheckpointError.compressionFailed
  }

  static func decompress(_ source: Data, expectedSize: Int) throws -> Data {
    guard expectedSize > 0 else { return Data() }
    var destination = Data(count: expectedSize)
    let written = destination.withUnsafeMutableBytes { output in
      source.withUnsafeBytes { input in
        compression_decode_buffer(
          output.bindMemory(to: UInt8.self).baseAddress!,
          expectedSize,
          input.bindMemory(to: UInt8.self).baseAddress!,
          source.count,
          nil,
          COMPRESSION_LZFSE
        )
      }
    }
    guard written == expectedSize else {
      throw BirdFlowCheckpointError.invalidArchive(
        "decompressed byte count \(written) did not match \(expectedSize)"
      )
    }
    return destination
  }
}
