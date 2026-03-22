import Foundation

@MainActor
final class SessionRecoveryService {
    static let shared = SessionRecoveryService()

    private(set) var lastRecoveryTimestamp: Date?
    private(set) var recoveryCount: Int = 0
    private let logger = DebugLogger.shared

    private init() {}

    func saveCheckpoint(credentialIndex: Int, waveIndex: Int, phase: String) {
        let checkpoint: [String: Any] = [
            "credentialIndex": credentialIndex,
            "waveIndex": waveIndex,
            "phase": phase,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        if let data = try? JSONSerialization.data(withJSONObject: checkpoint) {
            UserDefaults.standard.set(data, forKey: "sitchomatic.v16.checkpoint")
        }
    }

    func loadCheckpoint() -> (credentialIndex: Int, waveIndex: Int, phase: String)? {
        guard let data = UserDefaults.standard.data(forKey: "sitchomatic.v16.checkpoint"),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let credIdx = dict["credentialIndex"] as? Int,
              let waveIdx = dict["waveIndex"] as? Int,
              let phase = dict["phase"] as? String else { return nil }
        return (credIdx, waveIdx, phase)
    }

    func clearCheckpoint() {
        UserDefaults.standard.removeObject(forKey: "sitchomatic.v16.checkpoint")
    }

    func recordRecovery() {
        recoveryCount += 1
        lastRecoveryTimestamp = Date()
        logger.log("Session recovery #\(recoveryCount)", category: .crash, level: .warning)
    }
}
