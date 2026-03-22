import Foundation

nonisolated enum SpeedMode: String, Sendable, CaseIterable, Codable {
    case speedDemon
    case balanced
    case slowDebug
    case maxConcurrency

    var displayName: String {
        switch self {
        case .speedDemon: "Speed Demon"
        case .balanced: "Balanced"
        case .slowDebug: "Slow Debug"
        case .maxConcurrency: "Max Concurrency"
        }
    }

    var typingDelayMs: Int {
        switch self {
        case .speedDemon: 15
        case .balanced: 50
        case .slowDebug: 150
        case .maxConcurrency: 25
        }
    }

    var actionDelayMs: Int {
        switch self {
        case .speedDemon: 100
        case .balanced: 500
        case .slowDebug: 2000
        case .maxConcurrency: 200
        }
    }

    var postSubmitWaitMs: Int {
        switch self {
        case .speedDemon: 500
        case .balanced: 2000
        case .slowDebug: 5000
        case .maxConcurrency: 1000
        }
    }

    var maxConcurrentPairs: Int {
        switch self {
        case .speedDemon: 8
        case .balanced: 6
        case .slowDebug: 2
        case .maxConcurrency: 12
        }
    }

    var humanVarianceRange: ClosedRange<Int> {
        switch self {
        case .speedDemon: 5...20
        case .balanced: 20...80
        case .slowDebug: 50...200
        case .maxConcurrency: 10...30
        }
    }

    func typingDelayWithVariance() -> Int {
        let variance = Int.random(in: humanVarianceRange)
        return typingDelayMs + variance
    }

    func actionDelayWithVariance() -> Int {
        let variance = Int.random(in: humanVarianceRange)
        return actionDelayMs + variance
    }

    var iconName: String {
        switch self {
        case .speedDemon: "hare.fill"
        case .balanced: "gauge.with.dots.needle.50percent"
        case .slowDebug: "tortoise.fill"
        case .maxConcurrency: "bolt.horizontal.fill"
        }
    }

    var description: String {
        switch self {
        case .speedDemon: "Fastest execution, minimal delays"
        case .balanced: "Human-like timing with moderate delays"
        case .slowDebug: "Extra slow for debugging and observation"
        case .maxConcurrency: "Optimized for maximum parallel sessions"
        }
    }
}
