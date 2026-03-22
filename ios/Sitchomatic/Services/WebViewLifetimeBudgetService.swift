import Foundation

@MainActor
final class WebViewLifetimeBudgetService {
    static let shared = WebViewLifetimeBudgetService()

    private(set) var totalWebViewsCreated: Int = 0
    private(set) var totalWebViewsDestroyed: Int = 0
    private(set) var peakConcurrent: Int = 0
    private let maxLifetimeWebViews: Int = 500
    private let maxConcurrent: Int = 24
    private let logger = DebugLogger.shared

    private init() {}

    var currentConcurrent: Int { totalWebViewsCreated - totalWebViewsDestroyed }
    var lifetimeBudgetRemaining: Int { maxLifetimeWebViews - totalWebViewsCreated }
    var isOverBudget: Bool { totalWebViewsCreated >= maxLifetimeWebViews }
    var isConcurrentLimitReached: Bool { currentConcurrent >= maxConcurrent }

    func recordCreation() -> Bool {
        guard !isOverBudget else {
            logger.log("WebView lifetime budget EXHAUSTED (\(totalWebViewsCreated)/\(maxLifetimeWebViews))", category: .webView, level: .critical)
            return false
        }
        totalWebViewsCreated += 1
        peakConcurrent = max(peakConcurrent, currentConcurrent)
        return true
    }

    func recordDestruction() {
        totalWebViewsDestroyed += 1
    }

    func reset() {
        totalWebViewsCreated = 0
        totalWebViewsDestroyed = 0
        peakConcurrent = 0
    }

    var diagnosticSummary: String {
        "Lifetime: \(totalWebViewsCreated)/\(maxLifetimeWebViews) | Concurrent: \(currentConcurrent)/\(maxConcurrent) | Peak: \(peakConcurrent)"
    }
}
