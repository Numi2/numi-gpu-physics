import Foundation

public enum MeasuredBirdSurfaceSequenceError: Error, CustomStringConvertible {
    case invalidDataset(String)

    public var description: String {
        switch self {
        case .invalidDataset(let message):
            return "Invalid measured-bird surface sequence: \(message)"
        }
    }
}

public struct MeasuredBirdSurfaceComponent: Sendable, Equatable {
    public let name: String
    public let partIdentifier: UInt8
    public let evidenceClass: String
    public let vertexOffset: Int
    public let vertexCount: Int
    public let triangleOffset: Int
    public let triangleCount: Int
}

public struct MeasuredBirdSurfacePointState: Sendable {
    public let positionMeters: SIMD3<Float>
    public let velocityMetersPerSecond: SIMD3<Float>
}

/// Mean position and velocity of one segmented surface component.
///
/// For the Deetjen complete-surface sequence the body component centroid is
/// the measured-derived translation track used by the through-flight mode. It
/// is deliberately computed from the registered surface instead of inventing
/// a separate body trajectory.
public struct MeasuredBirdSurfaceComponentState: Sendable, Equatable {
    public let positionMeters: SIMD3<Float>
    public let velocityMetersPerSecond: SIMD3<Float>
}

public struct MeasuredBirdSurfaceSequence: Sendable {
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let scientificTier: String
    public let sourceDatasetDOI: String
    public let sourceArticleDOI: String
    public let sourceLicense: String
    public let sourceSurfaceSHA256: String
    public let sourceMuscleModelSHA256: String
    public let manifestSHA256: String
    public let sampleRateHertz: Float
    public let frameNumbers: [Int]
    public let frameTimesSeconds: [Float]
    public let verticesMeters: [SIMD3<Float>]
    public let triangleIndices: [UInt16]
    public let trianglePartIdentifiers: [UInt8]
    public let components: [MeasuredBirdSurfaceComponent]
    public let completeBirdSurfaceReady: Bool
    public let quantitativeForceAcceptanceReady: Bool

    public var frameCount: Int { frameTimesSeconds.count }
    public var vertexCount: Int { verticesMeters.count / frameCount }
    public var triangleCount: Int { triangleIndices.count / 3 }

    public var minimumPositionMeters: SIMD3<Float> {
        verticesMeters.reduce(
            SIMD3<Float>(repeating: .infinity)
        ) { partial, point in
            SIMD3<Float>(
                min(partial.x, point.x),
                min(partial.y, point.y),
                min(partial.z, point.z)
            )
        }
    }

    public var maximumPositionMeters: SIMD3<Float> {
        verticesMeters.reduce(
            SIMD3<Float>(repeating: -.infinity)
        ) { partial, point in
            SIMD3<Float>(
                max(partial.x, point.x),
                max(partial.y, point.y),
                max(partial.z, point.z)
            )
        }
    }

    public var maximumPointSpeedMetersPerSecond: Float {
        var maximum: Float = 0
        for frame in 0..<(frameCount - 1) {
            let duration = frameTimesSeconds[frame + 1]
                - frameTimesSeconds[frame]
            let firstOffset = frame * vertexCount
            let secondOffset = (frame + 1) * vertexCount
            for vertex in 0..<vertexCount {
                let delta = verticesMeters[secondOffset + vertex]
                    - verticesMeters[firstOffset + vertex]
                maximum = max(maximum, length(delta) / duration)
            }
        }
        return maximum
    }

    public func vertex(frame: Int, index: Int) -> SIMD3<Float> {
        precondition(frame >= 0 && frame < frameCount)
        precondition(index >= 0 && index < vertexCount)
        return verticesMeters[frame * vertexCount + index]
    }

    public func triangle(_ index: Int) -> SIMD3<UInt32> {
        precondition(index >= 0 && index < triangleCount)
        let offset = 3 * index
        return SIMD3<UInt32>(
            UInt32(triangleIndices[offset]),
            UInt32(triangleIndices[offset + 1]),
            UInt32(triangleIndices[offset + 2])
        )
    }

    public func state(
        timeSeconds: Float,
        vertexIndex: Int
    ) -> MeasuredBirdSurfacePointState {
        precondition(vertexIndex >= 0 && vertexIndex < vertexCount)
        let interval = interpolationInterval(timeSeconds: timeSeconds)
        let first = vertex(frame: interval.first, index: vertexIndex)
        let second = vertex(frame: interval.second, index: vertexIndex)
        let delta = second - first
        return MeasuredBirdSurfacePointState(
            positionMeters: first + interval.blend * delta,
            velocityMetersPerSecond: delta / interval.duration
        )
    }

    public func componentState(
        timeSeconds: Float,
        partIdentifier: UInt8
    ) -> MeasuredBirdSurfaceComponentState {
        guard let component = components.first(where: {
            $0.partIdentifier == partIdentifier
        }) else {
            preconditionFailure(
                "surface component \(partIdentifier) is not present"
            )
        }
        var position = SIMD3<Float>.zero
        var velocity = SIMD3<Float>.zero
        let end = component.vertexOffset + component.vertexCount
        for vertexIndex in component.vertexOffset..<end {
            let point = state(
                timeSeconds: timeSeconds,
                vertexIndex: vertexIndex
            )
            position += point.positionMeters
            velocity += point.velocityMetersPerSecond
        }
        let inverseCount = 1 / Float(component.vertexCount)
        return MeasuredBirdSurfaceComponentState(
            positionMeters: position * inverseCount,
            velocityMetersPerSecond: velocity * inverseCount
        )
    }

    public func bodyState(
        timeSeconds: Float
    ) -> MeasuredBirdSurfaceComponentState {
        componentState(timeSeconds: timeSeconds, partIdentifier: 1)
    }

    func packedPoints() -> [SIMD4<Float>] {
        verticesMeters.map { SIMD4<Float>($0, 0) }
    }

    func interpolationInterval(
        timeSeconds: Float
    ) -> (first: Int, second: Int, blend: Float, duration: Float) {
        if timeSeconds <= frameTimesSeconds[0] {
            let duration = frameTimesSeconds[1] - frameTimesSeconds[0]
            return (0, 1, 0, duration)
        }
        let last = frameCount - 1
        if timeSeconds >= frameTimesSeconds[last] {
            let duration = frameTimesSeconds[last] - frameTimesSeconds[last - 1]
            return (last - 1, last, 1, duration)
        }
        var lower = 0
        var upper = last
        while lower + 1 < upper {
            let middle = lower + (upper - lower) / 2
            if timeSeconds < frameTimesSeconds[middle] {
                upper = middle
            } else {
                lower = middle
            }
        }
        let duration = frameTimesSeconds[upper] - frameTimesSeconds[lower]
        return (
            lower,
            upper,
            (timeSeconds - frameTimesSeconds[lower]) / duration,
            duration
        )
    }
}

public enum MeasuredBirdSurfaceSequenceLoader {
    private struct WireSource: Decodable {
        let datasetDOI: String
        let articleDOI: String
        let license: String
        let surfaceSHA256: String
        let muscleModelSHA256: String
    }

    private struct WireFrames: Decodable {
        let count: Int
        let sampleRateHertz: Float
        let frameNumbers: [Int]
        let timesSeconds: [Float]
        let interpolation: String
        let endpointVelocity: String
        let periodic: Bool
    }

    private struct WireComponent: Decodable {
        let name: String
        let partIdentifier: UInt8
        let evidenceClass: String
        let vertexOffset: Int
        let vertexCount: Int
        let triangleOffset: Int
        let triangleCount: Int
    }

    private struct WireTopology: Decodable {
        let vertexCount: Int
        let triangleCount: Int
        let indexType: String
        let metalTriangleIdentifierLimit: Int
        let fixedAcrossFrames: Bool
        let components: [WireComponent]
    }

    private struct WireBinaryMember: Decodable {
        let file: String
        let format: String
        let layout: String
        let bytes: Int
        let sha256: String
    }

    private struct WireBinary: Decodable {
        let positions: WireBinaryMember
        let triangles: WireBinaryMember
    }

    private struct WireCoordinateFrame: Decodable {
        let units: String
    }

    private struct WireReadiness: Decodable {
        let completeBirdSurfaceReady: Bool
        let cpuParityRequired: Bool
        let metalReplayReady: Bool
        let quantitativeForceAcceptanceReady: Bool
    }

    private struct WireManifest: Decodable {
        let schemaVersion: Int
        let datasetIdentifier: String
        let scientificTier: String
        let source: WireSource
        let frames: WireFrames
        let coordinateFrame: WireCoordinateFrame
        let topology: WireTopology
        let binary: WireBinary
        let readiness: WireReadiness
    }

    public static func load(
        manifestURL: URL
    ) throws -> MeasuredBirdSurfaceSequence {
        let manifestData: Data
        let wire: WireManifest
        do {
            manifestData = try Data(contentsOf: manifestURL)
            wire = try JSONDecoder().decode(WireManifest.self, from: manifestData)
        } catch {
            throw invalid("unable to decode \(manifestURL.lastPathComponent): \(error)")
        }
        guard wire.schemaVersion == 1 else {
            throw invalid("schemaVersion must be 1")
        }
        guard wire.scientificTier == "derived-measured-complete-surface" else {
            throw invalid("scientificTier is not a complete derived surface")
        }
        guard wire.coordinateFrame.units == "meters" else {
            throw invalid("coordinate units must be meters")
        }
        guard wire.frames.count >= 2,
              wire.frames.count == wire.frames.frameNumbers.count,
              wire.frames.count == wire.frames.timesSeconds.count,
              wire.frames.sampleRateHertz.isFinite,
              wire.frames.sampleRateHertz > 0,
              wire.frames.interpolation == "piecewise-linear-nonperiodic",
              wire.frames.endpointVelocity == "one-sided-adjacent-frame",
              !wire.frames.periodic else {
            throw invalid("frame timing contract is invalid")
        }
        guard zip(
            wire.frames.timesSeconds,
            wire.frames.timesSeconds.dropFirst()
        ).allSatisfy({ pair in
            pair.0.isFinite && pair.1.isFinite && pair.0 < pair.1
        }) else {
            throw invalid("frame times must be finite and strictly increasing")
        }
        guard wire.topology.vertexCount > 0,
              wire.topology.vertexCount <= Int(UInt16.max),
              wire.topology.triangleCount > 0,
              wire.topology.triangleCount
                <= wire.topology.metalTriangleIdentifierLimit,
              wire.topology.metalTriangleIdentifierLimit <= 4096,
              wire.topology.indexType == "uint16-little-endian",
              wire.topology.fixedAcrossFrames else {
            throw invalid("indexed topology exceeds its fixed Metal contract")
        }
        guard wire.readiness.completeBirdSurfaceReady,
              wire.readiness.cpuParityRequired,
              !wire.readiness.quantitativeForceAcceptanceReady else {
            throw invalid("scientific readiness boundary is inconsistent")
        }

        let positionsURL = try siblingURL(
            named: wire.binary.positions.file,
            manifestURL: manifestURL
        )
        let trianglesURL = try siblingURL(
            named: wire.binary.triangles.file,
            manifestURL: manifestURL
        )
        let positionsData = try lockedData(
            at: positionsURL,
            record: wire.binary.positions,
            expectedFormat: "float32-little-endian",
            expectedLayout: "frame-major, vertex-major, xyz"
        )
        let trianglesData = try lockedData(
            at: trianglesURL,
            record: wire.binary.triangles,
            expectedFormat: "uint16-little-endian",
            expectedLayout: "triangle-major, three global vertex indices"
        )
        let expectedPositionBytes = wire.frames.count
            * wire.topology.vertexCount * 3 * MemoryLayout<Float>.stride
        let expectedTriangleBytes = wire.topology.triangleCount
            * 3 * MemoryLayout<UInt16>.stride
        guard positionsData.count == expectedPositionBytes,
              trianglesData.count == expectedTriangleBytes else {
            throw invalid("binary scalar count does not match manifest topology")
        }

        let positionScalars = decodeFloat32LittleEndian(positionsData)
        guard positionScalars.allSatisfy(\.isFinite) else {
            throw invalid("position stream contains a nonfinite value")
        }
        let vertices = stride(
            from: 0, to: positionScalars.count, by: 3
        ).map {
            SIMD3<Float>(
                positionScalars[$0],
                positionScalars[$0 + 1],
                positionScalars[$0 + 2]
            )
        }
        let triangleIndices = decodeUInt16LittleEndian(trianglesData)
        guard triangleIndices.allSatisfy({
            Int($0) < wire.topology.vertexCount
        }) else {
            throw invalid("triangle stream contains an out-of-range vertex")
        }

        let components = wire.topology.components.map {
            MeasuredBirdSurfaceComponent(
                name: $0.name,
                partIdentifier: $0.partIdentifier,
                evidenceClass: $0.evidenceClass,
                vertexOffset: $0.vertexOffset,
                vertexCount: $0.vertexCount,
                triangleOffset: $0.triangleOffset,
                triangleCount: $0.triangleCount
            )
        }
        try validateComponents(
            components,
            vertexCount: wire.topology.vertexCount,
            triangleCount: wire.topology.triangleCount,
            indices: triangleIndices
        )
        var partIdentifiers = [UInt8](
            repeating: 0,
            count: wire.topology.triangleCount
        )
        for component in components {
            let triangleEnd = component.triangleOffset
                + component.triangleCount
            for triangle in component.triangleOffset..<triangleEnd {
                partIdentifiers[triangle] = component.partIdentifier
            }
        }

        return MeasuredBirdSurfaceSequence(
            schemaVersion: wire.schemaVersion,
            datasetIdentifier: wire.datasetIdentifier,
            scientificTier: wire.scientificTier,
            sourceDatasetDOI: wire.source.datasetDOI,
            sourceArticleDOI: wire.source.articleDOI,
            sourceLicense: wire.source.license,
            sourceSurfaceSHA256: wire.source.surfaceSHA256,
            sourceMuscleModelSHA256: wire.source.muscleModelSHA256,
            manifestSHA256: CheckpointArchive.sha256(manifestData),
            sampleRateHertz: wire.frames.sampleRateHertz,
            frameNumbers: wire.frames.frameNumbers,
            frameTimesSeconds: wire.frames.timesSeconds,
            verticesMeters: vertices,
            triangleIndices: triangleIndices,
            trianglePartIdentifiers: partIdentifiers,
            components: components,
            completeBirdSurfaceReady: wire.readiness.completeBirdSurfaceReady,
            quantitativeForceAcceptanceReady:
                wire.readiness.quantitativeForceAcceptanceReady
        )
    }

    private static func validateComponents(
        _ components: [MeasuredBirdSurfaceComponent],
        vertexCount: Int,
        triangleCount: Int,
        indices: [UInt16]
    ) throws {
        guard components.map(\.name) == [
            "body", "leftWing", "rightWing", "tail",
        ], components.map(\.partIdentifier) == [1, 2, 3, 4] else {
            throw invalid("component names and part identifiers must be canonical")
        }
        var nextVertex = 0
        var nextTriangle = 0
        for component in components {
            guard component.vertexOffset == nextVertex,
                  component.triangleOffset == nextTriangle,
                  component.vertexCount > 0,
                  component.triangleCount > 0 else {
                throw invalid("component ranges must be positive and contiguous")
            }
            let vertexEnd = component.vertexOffset + component.vertexCount
            let triangleEnd = component.triangleOffset + component.triangleCount
            guard vertexEnd <= vertexCount, triangleEnd <= triangleCount else {
                throw invalid("component range exceeds topology")
            }
            for triangle in component.triangleOffset..<triangleEnd {
                for corner in 0..<3 {
                    let vertex = Int(indices[3 * triangle + corner])
                    guard vertex >= component.vertexOffset, vertex < vertexEnd else {
                        throw invalid("triangle crosses a component vertex range")
                    }
                }
            }
            nextVertex = vertexEnd
            nextTriangle = triangleEnd
        }
        guard nextVertex == vertexCount, nextTriangle == triangleCount else {
            throw invalid("component ranges do not cover the topology exactly")
        }
    }

    private static func siblingURL(
        named name: String,
        manifestURL: URL
    ) throws -> URL {
        guard !name.isEmpty,
              URL(fileURLWithPath: name).lastPathComponent == name,
              !name.contains(".."),
              !name.contains("/") else {
            throw invalid("unsafe binary member path: \(name)")
        }
        return manifestURL.deletingLastPathComponent()
            .appendingPathComponent(name)
    }

    private static func lockedData(
        at url: URL,
        record: WireBinaryMember,
        expectedFormat: String,
        expectedLayout: String
    ) throws -> Data {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw invalid("unable to read \(url.lastPathComponent): \(error)")
        }
        guard record.format == expectedFormat,
              record.layout == expectedLayout,
              record.bytes == data.count,
              record.sha256 == CheckpointArchive.sha256(data) else {
            throw invalid("binary lock mismatch for \(url.lastPathComponent)")
        }
        return data
    }

    private static func decodeFloat32LittleEndian(_ data: Data) -> [Float] {
        data.withUnsafeBytes { bytes in
            stride(from: 0, to: data.count, by: 4).map { offset in
                let bits = UInt32(littleEndian: bytes.loadUnaligned(
                    fromByteOffset: offset,
                    as: UInt32.self
                ))
                return Float(bitPattern: bits)
            }
        }
    }

    private static func decodeUInt16LittleEndian(_ data: Data) -> [UInt16] {
        data.withUnsafeBytes { bytes in
            stride(from: 0, to: data.count, by: 2).map { offset in
                UInt16(littleEndian: bytes.loadUnaligned(
                    fromByteOffset: offset,
                    as: UInt16.self
                ))
            }
        }
    }

    private static func invalid(
        _ message: String
    ) -> MeasuredBirdSurfaceSequenceError {
        .invalidDataset(message)
    }
}

private func length(_ vector: SIMD3<Float>) -> Float {
    sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}
