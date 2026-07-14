import Foundation

public enum BirdFlowError: Error, CustomStringConvertible {
    case metalUnavailable
    case deviceUnavailable
    case commandQueueUnavailable
    case resourceMissing(String)
    case shaderCompilationFailed(String)
    case pipelineCreationFailed(String)
    case allocationFailed(bytes: Int)
    case bufferExceedsDeviceLimit(bytes: Int, limit: Int)
    case workingSetExceedsRecommendation(bytes: Int, recommended: Int)
    case invalidAdvanceRequest(steps: Int, batchSize: Int)
    case invalidObservationBufferCount(Int)
    case commandBufferFailed(String)
    case simulationStateInvalidated(String)

    public var description: String {
        switch self {
        case .metalUnavailable:
            return "Metal is unavailable on this platform. BirdFlowMetal requires Apple silicon running macOS 14 or later."
        case .deviceUnavailable:
            return "No Metal GPU device is available."
        case .commandQueueUnavailable:
            return "Metal could not create a command queue."
        case .resourceMissing(let name):
            return "The bundled resource \(name) is missing."
        case .shaderCompilationFailed(let message):
            return "Metal shader compilation failed: \(message)"
        case .pipelineCreationFailed(let name):
            return "Metal could not create compute pipeline \(name)."
        case .allocationFailed(let bytes):
            return "Metal could not allocate \(bytes) bytes."
        case .bufferExceedsDeviceLimit(let bytes, let limit):
            return "A required Metal buffer is \(bytes) bytes, above this device's \(limit)-byte limit."
        case .workingSetExceedsRecommendation(let bytes, let recommended):
            return "The requested grid needs approximately \(bytes) bytes of Metal buffers, above this device's recommended \(recommended)-byte working set. Reduce the resolution scale or use a larger-memory device."
        case .invalidAdvanceRequest(let steps, let batchSize):
            return "Advance requires steps >= 0 and batchSize > 0; received steps=\(steps), batchSize=\(batchSize)."
        case .invalidObservationBufferCount(let count):
            return "Observation buffer count must be between 1 and 4; received \(count)."
        case .commandBufferFailed(let message):
            return "A Metal command buffer failed: \(message)"
        case .simulationStateInvalidated(let message):
            return "The simulation can no longer be advanced or read because a partially encoded/submitted GPU update failed: \(message)"
        }
    }
}
