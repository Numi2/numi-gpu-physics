import Foundation

public struct MeasuredBirdForceTarget: Sendable {
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let scientificTier: String
    public let targetSHA256: String
    public let sourceDatasetDOI: String
    public let sourceArticleDOI: String
    public let sourceFlightIdentifier: String
    public let surfaceManifestSHA256: String
    public let forceSampleRateHertz: Double
    public let kinematicsSampleRateHertz: Double
    public let samplesPerKinematicsInterval: Int
    public let firstForceSampleIndexZeroBased: Int
    public let lastForceSampleIndexZeroBased: Int
    public let timesSeconds: [Double]
    public let surfaceFrameCoordinates: [Double]
    public let forceXNewtons: [Double]
    public let forceZNewtons: [Double]
    public let comparisonFirstSourceFrame: Int
    public let comparisonLastSourceFrame: Int
    public let comparisonFirstSampleIndex: Int
    public let comparisonLastSampleIndex: Int

    public var sampleCount: Int { timesSeconds.count }
    public var comparisonSampleCount: Int {
        comparisonLastSampleIndex - comparisonFirstSampleIndex + 1
    }
    public var comparisonFirstTimeSeconds: Double {
        timesSeconds[comparisonFirstSampleIndex]
    }
    public var comparisonLastTimeSeconds: Double {
        timesSeconds[comparisonLastSampleIndex]
    }
}

public enum MeasuredBirdForceTargetLoader {
    private struct WireSource: Decodable {
        let datasetDOI: String
        let articleDOI: String
        let flightIdentifier: String
        let license: String
        let surfaceManifestSHA256: String
    }

    private struct WireCoordinateFrame: Decodable {
        let name: String
        let axes: [String: String]
        let sourceWorldToBirdFlow: [[Double]]
        let storedReactionToExternalMultiplier: Int
        let measuredComponentMapping: [String: String]
    }

    private struct WireCoverage: Decodable {
        let measured: [String]
        let unavailable: [String]
        let unavailableComponentsAreNotZeroFilled: Bool
    }

    private struct WireSynchronization: Decodable {
        let forceSampleRateHertz: Double
        let kinematicsSampleRateHertz: Double
        let samplesPerKinematicsInterval: Int
        let firstForceSampleIndexZeroBased: Int
        let lastForceSampleIndexZeroBased: Int
        let sampleCount: Int
        let durationSeconds: Double
        let surfaceSampling: String
    }

    private struct WireComparisonWindow: Decodable {
        let firstSourceFrame: Int
        let lastSourceFrame: Int
        let firstTargetSampleIndex: Int
        let lastTargetSampleIndex: Int
        let sampleCount: Int
        let firstTimeSeconds: Double
        let lastTimeSeconds: Double
        let preRollSeconds: Double
        let postRollSeconds: Double
        let comparisonRule: String
    }

    private struct WireSamples: Decodable {
        let timesSeconds: [Double]
        let surfaceFrameCoordinates: [Double]
        let forceXNewtons: [Double]
        let forceZNewtons: [Double]
    }

    private struct WireTarget: Decodable {
        let schemaVersion: Int
        let datasetIdentifier: String
        let scientificTier: String
        let source: WireSource
        let coordinateFrame: WireCoordinateFrame
        let componentCoverage: WireCoverage
        let synchronization: WireSynchronization
        let comparisonWindow: WireComparisonWindow
        let samples: WireSamples
        let claimBoundary: String
    }

    public static func load(
        targetURL: URL,
        surface: MeasuredBirdSurfaceSequence
    ) throws -> MeasuredBirdForceTarget {
        let data: Data
        let wire: WireTarget
        do {
            data = try Data(contentsOf: targetURL)
            wire = try JSONDecoder().decode(WireTarget.self, from: data)
        } catch {
            throw invalid(
                "unable to decode \(targetURL.lastPathComponent): \(error)"
            )
        }
        try validateMetadata(wire, surface: surface)
        let synchronization = wire.synchronization
        let samples = wire.samples
        try validateSamples(wire, surface: surface)
        let comparison = wire.comparisonWindow
        try validateComparison(wire)

        return MeasuredBirdForceTarget(
            schemaVersion: wire.schemaVersion,
            datasetIdentifier: wire.datasetIdentifier,
            scientificTier: wire.scientificTier,
            targetSHA256: CheckpointArchive.sha256(data),
            sourceDatasetDOI: wire.source.datasetDOI,
            sourceArticleDOI: wire.source.articleDOI,
            sourceFlightIdentifier: wire.source.flightIdentifier,
            surfaceManifestSHA256: wire.source.surfaceManifestSHA256,
            forceSampleRateHertz: synchronization.forceSampleRateHertz,
            kinematicsSampleRateHertz:
                synchronization.kinematicsSampleRateHertz,
            samplesPerKinematicsInterval:
                synchronization.samplesPerKinematicsInterval,
            firstForceSampleIndexZeroBased:
                synchronization.firstForceSampleIndexZeroBased,
            lastForceSampleIndexZeroBased:
                synchronization.lastForceSampleIndexZeroBased,
            timesSeconds: samples.timesSeconds,
            surfaceFrameCoordinates: samples.surfaceFrameCoordinates,
            forceXNewtons: samples.forceXNewtons,
            forceZNewtons: samples.forceZNewtons,
            comparisonFirstSourceFrame: comparison.firstSourceFrame,
            comparisonLastSourceFrame: comparison.lastSourceFrame,
            comparisonFirstSampleIndex: comparison.firstTargetSampleIndex,
            comparisonLastSampleIndex: comparison.lastTargetSampleIndex
        )
    }

    private static func validateMetadata(
        _ wire: WireTarget,
        surface: MeasuredBirdSurfaceSequence
    ) throws {
        guard wire.schemaVersion == 1,
              wire.datasetIdentifier
                == "deetjen-ob-2018-12-11-f03-measured-force-v1",
              wire.scientificTier
                == "source-processed-measured-two-component-force" else {
            throw invalid("force target schema or scientific tier changed")
        }
        guard wire.source.datasetDOI == surface.sourceDatasetDOI,
              wire.source.articleDOI == surface.sourceArticleDOI,
              wire.source.license == surface.sourceLicense,
              wire.source.flightIdentifier == "2018_12_11_OB_F03",
              wire.source.surfaceManifestSHA256 == surface.manifestSHA256 else {
            throw invalid("force target does not lock the loaded surface")
        }
        let coordinate = wire.coordinateFrame
        guard coordinate.name
                == "BirdFlow laboratory frame relative to frame-zero body origin",
              coordinate.axes == [
                "x": "forward", "y": "left", "z": "up"
              ],
              coordinate.sourceWorldToBirdFlow == [
                [0, 1, 0], [-1, 0, 0], [0, 0, 1]
              ],
              coordinate.storedReactionToExternalMultiplier == -1,
              coordinate.measuredComponentMapping == [
                "forceXNewtons": (
                    "-FxWings (platform horizontal -> source world +y -> "
                        + "BirdFlow +x)"
                ),
                "forceZNewtons": (
                    "-FzWings (platform vertical -> source world +z -> "
                        + "BirdFlow +z)"
                )
              ] else {
            throw invalid("force coordinate transform changed")
        }
        let coverage = wire.componentCoverage
        guard coverage.measured == ["forceXNewtons", "forceZNewtons"],
              coverage.unavailable.contains("forceYNewtons"),
              coverage.unavailableComponentsAreNotZeroFilled else {
            throw invalid("force component-coverage boundary changed")
        }
    }

    private static func validateSamples(
        _ wire: WireTarget,
        surface: MeasuredBirdSurfaceSequence
    ) throws {
        let synchronization = wire.synchronization
        let samples = wire.samples
        let counts = [
            samples.timesSeconds.count,
            samples.surfaceFrameCoordinates.count,
            samples.forceXNewtons.count,
            samples.forceZNewtons.count,
            synchronization.sampleCount
        ]
        guard Set(counts).count == 1,
              synchronization.sampleCount == 287,
              synchronization.forceSampleRateHertz == 2_000,
              synchronization.kinematicsSampleRateHertz
                == Double(surface.sampleRateHertz),
              synchronization.samplesPerKinematicsInterval == 2,
              synchronization.firstForceSampleIndexZeroBased == 191_878,
              synchronization.lastForceSampleIndexZeroBased == 192_164,
              synchronization.lastForceSampleIndexZeroBased
                - synchronization.firstForceSampleIndexZeroBased + 1
                == synchronization.sampleCount,
              abs(synchronization.durationSeconds - 0.143) <= 1e-12,
              synchronization.surfaceSampling.contains("alpha=0.5") else {
            throw invalid("force synchronization contract changed")
        }
        guard samples.timesSeconds.indices.allSatisfy({ index in
            let expected = Double(index)
                / synchronization.forceSampleRateHertz
            let coordinate = Double(index)
                / Double(synchronization.samplesPerKinematicsInterval)
            return samples.timesSeconds[index].isFinite
                && samples.surfaceFrameCoordinates[index].isFinite
                && samples.forceXNewtons[index].isFinite
                && samples.forceZNewtons[index].isFinite
                && abs(samples.timesSeconds[index] - expected) <= 1e-12
                && abs(samples.surfaceFrameCoordinates[index] - coordinate)
                    <= 1e-12
        }) else {
            throw invalid("force sample arrays are nonfinite or misregistered")
        }
        guard surface.frameTimesSeconds.indices.allSatisfy({ index in
            abs(
                samples.timesSeconds[2 * index]
                    - Double(surface.frameTimesSeconds[index])
            ) <= 1e-8
        }) else {
            throw invalid("force samples do not coincide with surface frames")
        }
    }

    private static func validateComparison(_ wire: WireTarget) throws {
        let comparison = wire.comparisonWindow
        let samples = wire.samples
        guard comparison.firstSourceFrame == -1_918,
              comparison.lastSourceFrame == -1_825,
              comparison.firstTargetSampleIndex == 50,
              comparison.lastTargetSampleIndex == 236,
              comparison.sampleCount == 187,
              comparison.sampleCount
                == comparison.lastTargetSampleIndex
                    - comparison.firstTargetSampleIndex + 1,
              comparison.firstTimeSeconds
                == samples.timesSeconds[comparison.firstTargetSampleIndex],
              comparison.lastTimeSeconds
                == samples.timesSeconds[comparison.lastTargetSampleIndex],
              abs(comparison.preRollSeconds - 0.025) <= 1e-12,
              abs(comparison.postRollSeconds - 0.025) <= 1e-12,
              comparison.comparisonRule.contains("pre-roll") else {
            throw invalid("force comparison window changed")
        }
    }

    private static func invalid(
        _ message: String
    ) -> MeasuredBirdSurfaceSequenceError {
        .invalidDataset("measured-force target: " + message)
    }
}
