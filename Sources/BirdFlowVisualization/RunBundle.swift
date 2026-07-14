import BirdFlowCore
import BirdFlowMetal
import Compression
import CryptoKit
import Foundation

public enum RunBundleError: Error, CustomStringConvertible {
  case writerBackpressure
  case compressionFailed
  case derivedFieldsUnavailable
  case invalidBundle(String)
  case writerFailed(String)

  public var description: String {
    switch self {
    case .writerBackpressure:
      return "Run recording paused because storage could not keep up."
    case .compressionFailed:
      return "Derived-field LZFSE compression failed."
    case .derivedFieldsUnavailable:
      return "No verified derived field is available to save yet."
    case .invalidBundle(let message):
      return "Invalid BirdFlow run bundle: \(message)"
    case .writerFailed(let message):
      return "Run recording paused after a storage error: \(message)"
    }
  }
}

private struct RunBundleManifest: Codable {
  var schema = 1
  var createdAt: Date
  var deviceName: String
  var buildIdentity: String
  var configuration: SimulationConfiguration
  var bird: BirdParameters
  var fileIndex = [
    "samples.bin": "BFRUN001 plus fixed 88-byte every-step force and pose records",
    "visualization.json": "camera and layer settings",
    "derived/": "manual lossless verified Q, vorticity, and validity keyframes",
    "checkpoints/": "manual full solver checkpoints",
  ]
}

public final class RunBundleRecorder: @unchecked Sendable {
  public let directory: URL

  private let queue = DispatchQueue(label: "BirdFlow run bundle writer")
  private let lock = NSLock()
  private var pendingWrites = 0
  private var writerFailure: String?
  private var retainedFailedChunks: [Data] = []
  private let sampleFile: FileHandle

  public init(
    directory: URL,
    configuration: SimulationConfiguration,
    bird: BirdParameters,
    deviceName: String
  ) throws {
    self.directory = directory
    let manager = FileManager.default
    try manager.createDirectory(at: directory, withIntermediateDirectories: true)
    try manager.createDirectory(
      at: directory.appendingPathComponent("derived"),
      withIntermediateDirectories: true
    )
    try manager.createDirectory(
      at: directory.appendingPathComponent("checkpoints"),
      withIntermediateDirectories: true
    )
    let manifest = RunBundleManifest(
      createdAt: Date(),
      deviceName: deviceName,
      buildIdentity: ProcessInfo.processInfo.environment["BIRDFLOW_BUILD_ID"]
        ?? "local-swiftpm",
      configuration: configuration,
      bird: bird
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(manifest).write(
      to: directory.appendingPathComponent("manifest.json"),
      options: .atomic
    )

    let sampleURL = directory.appendingPathComponent("samples.bin")
    _ = manager.createFile(
      atPath: sampleURL.path,
      contents: Data("BFRUN001".utf8)
    )
    sampleFile = try FileHandle(forWritingTo: sampleURL)
    try sampleFile.seekToEnd()
  }

  deinit {
    try? sampleFile.close()
  }

  /// Returns false before enqueueing when the bounded writer queue is full.
  /// The caller retains the samples and pauses rather than creating a gap.
  public func append(_ samples: [RunSample]) -> Bool {
    guard !samples.isEmpty else { return true }
    lock.lock()
    guard writerFailure == nil, pendingWrites < 16 else {
      lock.unlock()
      return false
    }
    pendingWrites += 1
    lock.unlock()
    let data = Self.encode(samples)
    queue.async { [self] in
      do {
        try sampleFile.write(contentsOf: data)
      } catch {
        lock.lock()
        writerFailure = String(describing: error)
        retainedFailedChunks.append(data)
        lock.unlock()
      }
      lock.lock()
      pendingWrites -= 1
      lock.unlock()
    }
    return true
  }

  public var recordingError: RunBundleError? {
    lock.lock()
    defer { lock.unlock() }
    return writerFailure.map(RunBundleError.writerFailed)
  }

  public func finish() throws {
    queue.sync {}
    if let recordingError { throw recordingError }
    try sampleFile.synchronize()
  }

  public func save(settings: VisualizationSettings) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(settings).write(
      to: directory.appendingPathComponent("visualization.json"),
      options: .atomic
    )
  }

  public func checkpointURL(step: UInt64) -> URL {
    directory.appendingPathComponent("checkpoints")
      .appendingPathComponent(String(format: "step-%012llu.bfcp", step))
  }

  public func derivedURL(step: UInt64) -> URL {
    directory.appendingPathComponent("derived")
      .appendingPathComponent(String(format: "step-%012llu.bfdf", step))
  }

  private static func encode(_ samples: [RunSample]) -> Data {
    var data = Data()
    data.reserveCapacity(samples.count * 96)
    for sample in samples {
      data.appendLittleEndian(sample.step)
      data.appendLittleEndian(sample.timeSeconds)
      data.append(sample.body.positionMeters)
      data.append(sample.body.orientationBodyToWorld.simd4)
      data.append(sample.body.linearVelocityMetersPerSecond)
      data.append(sample.body.angularVelocityBodyRadiansPerSecond)
      data.append(sample.aerodynamicLoad.forceNewtons)
      data.append(sample.aerodynamicLoad.torqueNewtonMeters)
    }
    return data
  }
}

struct DerivedFieldManifest: Codable {
  var schema = 1
  var step: UInt64
  var timeSeconds: Float
  var grid: GridSize
  var units = ["vorticity": "s^-1", "qCriterion": "s^-2"]
  var scalarEncoding = "little-endian Float32; vorticity is interleaved XYZW where W is magnitude"
  var compression = "LZFSE lossless"
  var vorticityBytes: Int
  var qBytes: Int
  var validMaskBytes: Int
  var vorticitySHA256: String
  var qSHA256: String
  var validMaskSHA256: String
}

public struct DerivedFieldKeyframe: Sendable {
  public var step: UInt64
  public var timeSeconds: Float
  public var grid: GridSize
  public var vorticity: Data
  public var qCriterion: Data
  public var validMask: Data
}

enum DerivedFieldArchive {
  static func write(
    vorticity: Data,
    qCriterion: Data,
    validMask: Data,
    metadata: GPUFieldFrameMetadata,
    to destination: URL
  ) throws {
    let manager = FileManager.default
    let temporary = destination.deletingLastPathComponent()
      .appendingPathComponent(".\(destination.lastPathComponent)-\(UUID().uuidString)")
    try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      try encoder.encode(
        DerivedFieldManifest(
          step: metadata.snapshot.step,
          timeSeconds: metadata.snapshot.timeSeconds,
          grid: metadata.grid,
          vorticityBytes: vorticity.count,
          qBytes: qCriterion.count,
          validMaskBytes: validMask.count,
          vorticitySHA256: sha256(vorticity),
          qSHA256: sha256(qCriterion),
          validMaskSHA256: sha256(validMask)
        )
      ).write(
        to: temporary.appendingPathComponent("manifest.json"),
        options: .atomic
      )
      try lzfse(vorticity).write(
        to: temporary.appendingPathComponent("vorticity-float4.lzfse"),
        options: .atomic
      )
      try lzfse(qCriterion).write(
        to: temporary.appendingPathComponent("q-float.lzfse"),
        options: .atomic
      )
      try lzfse(validMask).write(
        to: temporary.appendingPathComponent("valid-mask.lzfse"),
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

  static func read(from source: URL) throws -> DerivedFieldKeyframe {
    do {
      let manifest = try JSONDecoder().decode(
        DerivedFieldManifest.self,
        from: Data(contentsOf: source.appendingPathComponent("manifest.json"))
      )
      guard manifest.schema == 1,
        manifest.vorticityBytes == manifest.grid.cellCount * 16,
        manifest.qBytes == manifest.grid.cellCount * 4,
        manifest.validMaskBytes == manifest.grid.cellCount
      else {
        throw RunBundleError.invalidBundle("derived-field sizes are inconsistent")
      }
      let vorticity = try unlzfse(
        Data(contentsOf: source.appendingPathComponent("vorticity-float4.lzfse")),
        size: manifest.vorticityBytes
      )
      let q = try unlzfse(
        Data(contentsOf: source.appendingPathComponent("q-float.lzfse")),
        size: manifest.qBytes
      )
      let valid = try unlzfse(
        Data(contentsOf: source.appendingPathComponent("valid-mask.lzfse")),
        size: manifest.validMaskBytes
      )
      guard sha256(vorticity) == manifest.vorticitySHA256,
        sha256(q) == manifest.qSHA256,
        sha256(valid) == manifest.validMaskSHA256
      else {
        throw RunBundleError.invalidBundle("derived-field checksum mismatch")
      }
      return DerivedFieldKeyframe(
        step: manifest.step,
        timeSeconds: manifest.timeSeconds,
        grid: manifest.grid,
        vorticity: vorticity,
        qCriterion: q,
        validMask: valid
      )
    } catch let error as RunBundleError {
      throw error
    } catch {
      throw RunBundleError.invalidBundle(String(describing: error))
    }
  }

  private static func lzfse(_ source: Data) throws -> Data {
    var capacity = source.count + 65_536
    for _ in 0..<4 {
      var output = Data(count: capacity)
      let written = output.withUnsafeMutableBytes { destination in
        source.withUnsafeBytes { input in
          compression_encode_buffer(
            destination.bindMemory(to: UInt8.self).baseAddress!,
            capacity,
            input.bindMemory(to: UInt8.self).baseAddress!,
            source.count,
            nil,
            COMPRESSION_LZFSE
          )
        }
      }
      if written > 0 {
        output.count = written
        return output
      }
      capacity *= 2
    }
    throw RunBundleError.compressionFailed
  }

  private static func unlzfse(_ source: Data, size: Int) throws -> Data {
    var output = Data(count: size)
    let written = output.withUnsafeMutableBytes { destination in
      source.withUnsafeBytes { input in
        compression_decode_buffer(
          destination.bindMemory(to: UInt8.self).baseAddress!,
          size,
          input.bindMemory(to: UInt8.self).baseAddress!,
          source.count,
          nil,
          COMPRESSION_LZFSE
        )
      }
    }
    guard written == size else {
      throw RunBundleError.invalidBundle("derived-field decompression failed")
    }
    return output
  }

  private static func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}

public enum RunBundleReader {
  public static func settings(from directory: URL) throws -> VisualizationSettings {
    do {
      return try JSONDecoder().decode(
        VisualizationSettings.self,
        from: Data(contentsOf: directory.appendingPathComponent("visualization.json"))
      )
    } catch {
      throw RunBundleError.invalidBundle("visualization settings: \(error)")
    }
  }

  public static func samples(from directory: URL) throws -> [RunSample] {
    let data = try Data(contentsOf: directory.appendingPathComponent("samples.bin"))
    guard data.count >= 8,
      Data(data.prefix(8)) == Data("BFRUN001".utf8),
      (data.count - 8).isMultiple(of: 88)
    else {
      throw RunBundleError.invalidBundle("samples.bin header or record size")
    }
    var offset = 8
    var samples: [RunSample] = []
    samples.reserveCapacity((data.count - 8) / 88)
    while offset < data.count {
      let step = readUInt64(data, &offset)
      let time = readFloat(data, &offset)
      let position = readVector3(data, &offset)
      let orientation = readVector4(data, &offset)
      let linear = readVector3(data, &offset)
      let angular = readVector3(data, &offset)
      let force = readVector3(data, &offset)
      let torque = readVector3(data, &offset)
      samples.append(
        RunSample(
          step: step,
          timeSeconds: time,
          body: BirdBodyState(
            positionMeters: position,
            orientationBodyToWorld: Quaternion(simd4: orientation),
            linearVelocityMetersPerSecond: linear,
            angularVelocityBodyRadiansPerSecond: angular
          ),
          aerodynamicLoad: ForceTorque(
            forceNewtons: force,
            torqueNewtonMeters: torque
          )
        ))
    }
    return samples
  }

  public static func derivedField(from directory: URL) throws -> DerivedFieldKeyframe {
    try DerivedFieldArchive.read(from: directory)
  }

  private static func readUInt32(_ data: Data, _ offset: inout Int) -> UInt32 {
    let result =
      UInt32(data[offset])
      | UInt32(data[offset + 1]) << 8
      | UInt32(data[offset + 2]) << 16
      | UInt32(data[offset + 3]) << 24
    offset += 4
    return result
  }

  private static func readUInt64(_ data: Data, _ offset: inout Int) -> UInt64 {
    let low = UInt64(readUInt32(data, &offset))
    let high = UInt64(readUInt32(data, &offset))
    return low | high << 32
  }

  private static func readFloat(_ data: Data, _ offset: inout Int) -> Float {
    Float(bitPattern: readUInt32(data, &offset))
  }

  private static func readVector3(_ data: Data, _ offset: inout Int) -> SIMD3<Float> {
    SIMD3<Float>(
      readFloat(data, &offset),
      readFloat(data, &offset),
      readFloat(data, &offset)
    )
  }

  private static func readVector4(_ data: Data, _ offset: inout Int) -> SIMD4<Float> {
    SIMD4<Float>(
      readFloat(data, &offset),
      readFloat(data, &offset),
      readFloat(data, &offset),
      readFloat(data, &offset)
    )
  }
}

extension Data {
  fileprivate mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
    var little = value.littleEndian
    Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
  }

  fileprivate mutating func appendLittleEndian(_ value: Float) {
    appendLittleEndian(value.bitPattern)
  }

  fileprivate mutating func append(_ value: SIMD3<Float>) {
    appendLittleEndian(value.x)
    appendLittleEndian(value.y)
    appendLittleEndian(value.z)
  }

  fileprivate mutating func append(_ value: SIMD4<Float>) {
    appendLittleEndian(value.x)
    appendLittleEndian(value.y)
    appendLittleEndian(value.z)
    appendLittleEndian(value.w)
  }
}
