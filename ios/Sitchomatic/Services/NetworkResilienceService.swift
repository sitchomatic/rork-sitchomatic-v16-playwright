import Foundation
import Observation

@Observable
@MainActor
class NetworkResilienceService {
    static let shared = NetworkResilienceService()

    private(set) var averageLatencyMs: Int = 0
    private(set) var latencySamples: [Int] = []
    private(set) var bandwidthSamples: [UInt64] = []
    private(set) var errorCount: Int = 0
    private(set) var totalSamples: Int = 0

    private let maxSamples = 100

    func recordLatencySample(latencyMs: Int, hadError: Bool) {
        latencySamples.append(latencyMs)
        if latencySamples.count > maxSamples {
            latencySamples = Array(latencySamples.suffix(maxSamples))
        }
        if hadError { errorCount += 1 }
        totalSamples += 1
        averageLatencyMs = latencySamples.isEmpty ? 0 : latencySamples.reduce(0, +) / latencySamples.count
    }

    func recordBandwidthSample(bytes: UInt64) {
        bandwidthSamples.append(bytes)
        if bandwidthSamples.count > maxSamples {
            bandwidthSamples = Array(bandwidthSamples.suffix(maxSamples))
        }
    }

    func reset() {
        averageLatencyMs = 0
        latencySamples.removeAll()
        bandwidthSamples.removeAll()
        errorCount = 0
        totalSamples = 0
    }

    var errorRate: Double {
        guard totalSamples > 0 else { return 0 }
        return Double(errorCount) / Double(totalSamples) * 100
    }
}
