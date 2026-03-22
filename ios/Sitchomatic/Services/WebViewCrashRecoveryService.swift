import Foundation

@MainActor
final class WebViewCrashRecoveryService {
    static let shared = WebViewCrashRecoveryService()

    private(set) var totalRecoveries: Int = 0
    private(set) var lastRecoveryDate: Date?
    private let logger = DebugLogger.shared
    private let maxRecoveriesPerMinute: Int = 5
    private var recentRecoveries: [Date] = []

    private init() {}

    var canRecover: Bool {
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        recentRecoveries = recentRecoveries.filter { $0 > oneMinuteAgo }
        return recentRecoveries.count < maxRecoveriesPerMinute
    }

    func recordRecovery(pageID: String, phase: String) {
        totalRecoveries += 1
        lastRecoveryDate = Date()
        recentRecoveries.append(Date())
        logger.log("WebView crash recovery #\(totalRecoveries) — page: \(pageID), phase: \(phase)", category: .crash, level: .warning)
    }

    func reset() {
        totalRecoveries = 0
        lastRecoveryDate = nil
        recentRecoveries.removeAll()
    }
}
