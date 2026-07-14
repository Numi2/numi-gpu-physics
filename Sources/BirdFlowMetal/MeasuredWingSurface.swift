import BirdFlowCore
import Foundation

public enum MeasuredWingSurfaceError: Error, CustomStringConvertible {
    case invalidDataset(String)

    public var description: String {
        switch self {
        case .invalidDataset(let message):
            return "Invalid measured-wing surface dataset: \(message)"
        }
    }
}

public struct MeasuredWingSurfacePointState: Sendable {
    public let positionMeters: SIMD3<Float>
    public let velocityMetersPerSecond: SIMD3<Float>
}

public struct MeasuredWingSurfaceDataset: Sendable {
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let scientificTier: String
    public let sourceDatasetDOI: String
    public let sourceArticleDOI: String
    public let sourceMD5: String
    public let inputSHA256: String
    public let frequencyHz: Float
    public let phases: [Float]
    public let chordCount: Int
    public let spanCount: Int
    public let verticesMeters: [SIMD3<Float>]
    public let shortestPathMeters: [SIMD3<Float>]
    public let maximumRootRelativeRadiusMeters: Float
    public let completeBirdReplayReady: Bool

    public var frameCount: Int { phases.count }
    public var verticesPerFrame: Int { chordCount * spanCount }
    public var pathsPerFrame: Int { spanCount }
    public var pointsPerFrame: Int { verticesPerFrame + pathsPerFrame }

    public var maximumPointSpeedMetersPerSecond: Float {
        var maximum: Float = 0
        for frame in 0..<frameCount {
            let second = (frame + 1) % frameCount
            let span = second == 0
                ? phases[0] + 1 - phases[frame]
                : phases[second] - phases[frame]
            for point in 0..<pointsPerFrame {
                let delta = packedPoint(frame: second, index: point)
                    - packedPoint(frame: frame, index: point)
                let magnitude = sqrt(
                    delta.x * delta.x + delta.y * delta.y + delta.z * delta.z
                )
                maximum = max(
                    maximum,
                    magnitude * frequencyHz / span
                )
            }
        }
        return maximum
    }

    public func vertex(
        frame: Int,
        chord: Int,
        span: Int
    ) -> SIMD3<Float> {
        verticesMeters[
            frame * verticesPerFrame + chord + chordCount * span
        ]
    }

    public func shortestPathPoint(frame: Int, span: Int) -> SIMD3<Float> {
        shortestPathMeters[frame * pathsPerFrame + span]
    }

    public func state(
        phase rawPhase: Float,
        pointIndex: Int
    ) -> MeasuredWingSurfacePointState {
        precondition(pointIndex >= 0 && pointIndex < pointsPerFrame)
        let interval = periodicInterval(phase: rawPhase)
        let first = packedPoint(frame: interval.first, index: pointIndex)
        let second = packedPoint(frame: interval.second, index: pointIndex)
        return MeasuredWingSurfacePointState(
            positionMeters: first + interval.blend * (second - first),
            velocityMetersPerSecond:
                (second - first) * (frequencyHz / interval.span)
        )
    }

    func packedPoints() -> [SIMD4<Float>] {
        var result: [SIMD4<Float>] = []
        result.reserveCapacity(frameCount * pointsPerFrame)
        for frame in 0..<frameCount {
            let vertexStart = frame * verticesPerFrame
            let pathStart = frame * pathsPerFrame
            for index in 0..<verticesPerFrame {
                result.append(SIMD4<Float>(verticesMeters[vertexStart + index], 0))
            }
            for index in 0..<pathsPerFrame {
                result.append(SIMD4<Float>(shortestPathMeters[pathStart + index], 0))
            }
        }
        return result
    }

    private func packedPoint(frame: Int, index: Int) -> SIMD3<Float> {
        if index < verticesPerFrame {
            return verticesMeters[frame * verticesPerFrame + index]
        }
        return shortestPathMeters[
            frame * pathsPerFrame + index - verticesPerFrame
        ]
    }

    private func periodicInterval(
        phase rawPhase: Float
    ) -> (first: Int, second: Int, blend: Float, span: Float) {
        var phase = rawPhase.truncatingRemainder(dividingBy: 1)
        if phase < 0 { phase += 1 }
        for index in 0..<(frameCount - 1)
            where phase >= phases[index] && phase < phases[index + 1] {
            let span = phases[index + 1] - phases[index]
            return (index, index + 1, (phase - phases[index]) / span, span)
        }
        let first = frameCount - 1
        let adjusted = phase < phases[0] ? phase + 1 : phase
        let span = phases[0] + 1 - phases[first]
        return (first, 0, (adjusted - phases[first]) / span, span)
    }
}

public enum MeasuredWingSurfaceDatasetLoader {
    private struct WireSource: Decodable {
        let datasetDOI: String
        let articleDOI: String
        let md5: String
    }

    private struct WireDataset: Decodable {
        let schemaVersion: Int
        let datasetIdentifier: String
        let scientificTier: String
        let source: WireSource
        let frequencyHz: Float
        let phases: [Float]
        let chordCount: Int
        let spanCount: Int
        let verticesMeters: [Float]
        let shortestPathMeters: [Float]
        let maximumRootRelativeRadiusMeters: Float
        let completeBirdReplayReady: Bool
    }

    public static func load(from url: URL) throws -> MeasuredWingSurfaceDataset {
        let data: Data
        let wire: WireDataset
        do {
            data = try Data(contentsOf: url)
            wire = try JSONDecoder().decode(WireDataset.self, from: data)
        } catch {
            throw MeasuredWingSurfaceError.invalidDataset(
                "unable to decode \(url.lastPathComponent): \(error)"
            )
        }
        guard wire.schemaVersion == 1 else {
            throw MeasuredWingSurfaceError.invalidDataset(
                "schemaVersion must be 1, found \(wire.schemaVersion)"
            )
        }
        guard wire.scientificTier == "measured-wing-only" else {
            throw MeasuredWingSurfaceError.invalidDataset(
                "scientificTier must be measured-wing-only"
            )
        }
        guard wire.frequencyHz.isFinite, wire.frequencyHz > 0 else {
            throw MeasuredWingSurfaceError.invalidDataset(
                "frequencyHz must be finite and positive"
            )
        }
        guard wire.chordCount >= 2, wire.spanCount >= 2 else {
            throw MeasuredWingSurfaceError.invalidDataset(
                "chordCount and spanCount must both be at least 2"
            )
        }
        let (quadCount, quadOverflow) = (wire.chordCount - 1)
            .multipliedReportingOverflow(by: wire.spanCount - 1)
        let (triangleCount, triangleOverflow) = quadCount
            .multipliedReportingOverflow(by: 2)
        guard !quadOverflow, !triangleOverflow, triangleCount <= 4096 else {
            throw MeasuredWingSurfaceError.invalidDataset(
                "compact surface must contain at most 4096 triangles"
            )
        }
        let validPhasePairs = zip(
            wire.phases,
            wire.phases.dropFirst()
        ).allSatisfy { pair in
            pair.0.isFinite && pair.1.isFinite
                && pair.0 >= 0 && pair.1 < 1 && pair.0 < pair.1
        }
        guard wire.phases.count >= 2, validPhasePairs else {
            throw MeasuredWingSurfaceError.invalidDataset(
                "phases must be finite, strictly increasing, and in [0, 1)"
            )
        }
        let vertexScalarCount = wire.phases.count
            * wire.chordCount * wire.spanCount * 3
        let pathScalarCount = wire.phases.count * wire.spanCount * 3
        guard wire.verticesMeters.count == vertexScalarCount else {
            throw MeasuredWingSurfaceError.invalidDataset(
                "verticesMeters has \(wire.verticesMeters.count) values; expected \(vertexScalarCount)"
            )
        }
        guard wire.shortestPathMeters.count == pathScalarCount else {
            throw MeasuredWingSurfaceError.invalidDataset(
                "shortestPathMeters has \(wire.shortestPathMeters.count) values; expected \(pathScalarCount)"
            )
        }
        guard wire.verticesMeters.allSatisfy(\.isFinite),
              wire.shortestPathMeters.allSatisfy(\.isFinite),
              wire.maximumRootRelativeRadiusMeters.isFinite,
              wire.maximumRootRelativeRadiusMeters > 0 else {
            throw MeasuredWingSurfaceError.invalidDataset(
                "coordinates and maximum radius must be finite"
            )
        }
        func vectors(_ values: [Float]) -> [SIMD3<Float>] {
            stride(from: 0, to: values.count, by: 3).map {
                SIMD3<Float>(values[$0], values[$0 + 1], values[$0 + 2])
            }
        }
        return MeasuredWingSurfaceDataset(
            schemaVersion: wire.schemaVersion,
            datasetIdentifier: wire.datasetIdentifier,
            scientificTier: wire.scientificTier,
            sourceDatasetDOI: wire.source.datasetDOI,
            sourceArticleDOI: wire.source.articleDOI,
            sourceMD5: wire.source.md5,
            inputSHA256: CheckpointArchive.sha256(data),
            frequencyHz: wire.frequencyHz,
            phases: wire.phases,
            chordCount: wire.chordCount,
            spanCount: wire.spanCount,
            verticesMeters: vectors(wire.verticesMeters),
            shortestPathMeters: vectors(wire.shortestPathMeters),
            maximumRootRelativeRadiusMeters:
                wire.maximumRootRelativeRadiusMeters,
            completeBirdReplayReady: wire.completeBirdReplayReady
        )
    }
}
