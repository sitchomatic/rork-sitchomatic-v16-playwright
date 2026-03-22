import Foundation
import WebKit

@MainActor
final class WebViewPool {
    static let shared = WebViewPool()

    private var inUseCount: Int = 0
    private let logger = DebugLogger.shared
    private(set) var processTerminationCount: Int = 0
    private var preWarmedViews: [WKWebView] = []
    private let maxPreWarmed: Int = 3
    private(set) var preWarmCount: Int = 0
    private let hardCapActiveWebViews: Int = 24
    private var peakActiveCount: Int = 0
    private var totalCreated: Int = 0
    private var totalReleased: Int = 0
    private var trackedSessions: [String: TrackedWebView] = [:]
    private let staleSessionTimeoutSeconds: TimeInterval = 300
    private var staleSessionReaperTask: Task<Void, Never>?
    private var leakDetectionTask: Task<Void, Never>?
    private var consecutiveProcessTerminations: Int = 0
    private var lastProcessTerminationTime: Date = .distantPast

    private struct TrackedWebView {
        let id: String
        let createdAt: Date
        weak var webView: WKWebView?
    }

    var activeCount: Int { inUseCount }
    var preWarmedCount: Int { preWarmedViews.count }

    private init() {}

    func preWarm(count: Int = 2, stealthEnabled: Bool = true) {
        guard inUseCount + preWarmedViews.count < hardCapActiveWebViews else { return }
        if CrashProtectionService.shared.shouldReduceConcurrency { return }

        let toCreate = min(count, maxPreWarmed - preWarmedViews.count, hardCapActiveWebViews - inUseCount - preWarmedViews.count)
        guard toCreate > 0 else { return }

        for _ in 0..<toCreate {
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .nonPersistent()
            config.preferences.javaScriptCanOpenWindowsAutomatically = true
            config.defaultWebpagePreferences.allowsContentJavaScript = true

            let wv = WKWebView(frame: CGRect(origin: .zero, size: CGSize(width: 390, height: 844)), configuration: config)
            wv.customUserAgent = generateUserAgent()
            preWarmedViews.append(wv)
        }
        preWarmCount += toCreate
        totalCreated += toCreate
    }

    func acquire(
        stealthEnabled: Bool = true,
        viewportSize: CGSize = CGSize(width: 390, height: 844),
        networkConfig: ActiveNetworkConfig = .direct,
        target: ProxyTarget = .joe
    ) async -> WKWebView {
        if CrashProtectionService.shared.isMemoryEmergency {
            drainPreWarmed()
            reapStaleSessions()
            _ = await CrashProtectionService.shared.waitForMemoryToDrop(timeout: 15)
        } else if CrashProtectionService.shared.isMemoryCritical {
            drainPreWarmed()
            reapStaleSessions()
            _ = await CrashProtectionService.shared.waitForMemoryToDrop(timeout: 10)
        }

        if inUseCount >= hardCapActiveWebViews {
            reapStaleSessions()
            reapDeallocatedSessions()
            for _ in 0..<30 {
                try? await Task.sleep(for: .milliseconds(500))
                if inUseCount < hardCapActiveWebViews { break }
            }
            if inUseCount >= hardCapActiveWebViews {
                drainPreWarmed()
                reapDeallocatedSessions()
            }
        }

        if let preWarmed = acquirePreWarmed() {
            return preWarmed
        }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        if case .socks5(let host, let port) = networkConfig {
            if let proxyConfig = ProxyConfigurationHelper.createProxyConfiguration(host: host, port: port) {
                config.websiteDataStore.proxyConfigurations = [proxyConfig]
            }
        }

        let wv = WKWebView(frame: CGRect(origin: .zero, size: viewportSize), configuration: config)
        wv.customUserAgent = generateUserAgent()

        let trackId = "acq_\(UUID().uuidString.prefix(8))"
        inUseCount += 1
        totalCreated += 1
        peakActiveCount = max(peakActiveCount, inUseCount)
        trackedSessions[trackId] = TrackedWebView(id: trackId, createdAt: Date(), webView: wv)
        startStaleSessionReaperIfNeeded()
        return wv
    }

    func release(_ webView: WKWebView, wipeData: Bool = true) {
        guard inUseCount > 0 else {
            safeCleanupWebView(webView, wipeData: wipeData)
            return
        }
        inUseCount -= 1
        totalReleased += 1

        let matchingKey = trackedSessions.first(where: { $0.value.webView === webView })?.key
        if let key = matchingKey {
            trackedSessions.removeValue(forKey: key)
        }

        safeCleanupWebView(webView, wipeData: wipeData)
    }

    func handleMemoryPressure() {
        drainPreWarmed()
        reapStaleSessions()
        reapDeallocatedSessions()
    }

    func emergencyPurgeAll() {
        drainPreWarmed()
        reapStaleSessions()
        reapDeallocatedSessions()
        if inUseCount > hardCapActiveWebViews {
            forceResetCount()
        }
    }

    func reportProcessTermination() {
        processTerminationCount += 1
        let now = Date()
        let timeSinceLast = now.timeIntervalSince(lastProcessTerminationTime)
        lastProcessTerminationTime = now

        if timeSinceLast < 30 {
            consecutiveProcessTerminations += 1
        } else {
            consecutiveProcessTerminations = 1
        }

        if consecutiveProcessTerminations >= 3 {
            drainPreWarmed()
            URLCache.shared.removeAllCachedResponses()
            consecutiveProcessTerminations = 0
        }
    }

    func drainPreWarmed() {
        for wv in preWarmedViews {
            wv.stopLoading()
            wv.configuration.userContentController.removeAllUserScripts()
        }
        preWarmedViews.removeAll()
    }

    func forceResetCount() {
        inUseCount = 0
        trackedSessions.removeAll()
    }

    var diagnosticSummary: String {
        "Active: \(inUseCount)/\(hardCapActiveWebViews) | PreWarmed: \(preWarmedViews.count) | Peak: \(peakActiveCount) | Created: \(totalCreated) | Released: \(totalReleased) | Crashes: \(processTerminationCount)"
    }

    enum ProxyTarget: String, Sendable {
        case joe
        case ignition
    }

    private func acquirePreWarmed() -> WKWebView? {
        guard !preWarmedViews.isEmpty else { return nil }
        let wv = preWarmedViews.removeFirst()
        inUseCount += 1
        peakActiveCount = max(peakActiveCount, inUseCount)
        let trackId = "pw_\(UUID().uuidString.prefix(8))"
        trackedSessions[trackId] = TrackedWebView(id: trackId, createdAt: Date(), webView: wv)
        startStaleSessionReaperIfNeeded()
        return wv
    }

    private func safeCleanupWebView(_ webView: WKWebView, wipeData: Bool) {
        webView.stopLoading()
        if wipeData {
            let dataStore = webView.configuration.websiteDataStore
            dataStore.proxyConfigurations = []
            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { }
            webView.configuration.userContentController.removeAllUserScripts()
            HTTPCookieStorage.shared.removeCookies(since: .distantPast)
        }
        webView.navigationDelegate = nil
    }

    private func reapStaleSessions() {
        let now = Date()
        for (key, tracked) in trackedSessions {
            if now.timeIntervalSince(tracked.createdAt) > staleSessionTimeoutSeconds {
                if let wv = tracked.webView { safeCleanupWebView(wv, wipeData: true) }
                trackedSessions.removeValue(forKey: key)
                if inUseCount > 0 { inUseCount -= 1 }
                totalReleased += 1
            }
        }
    }

    private func reapDeallocatedSessions() {
        for (key, tracked) in trackedSessions where tracked.webView == nil {
            trackedSessions.removeValue(forKey: key)
            if inUseCount > 0 { inUseCount -= 1 }
            totalReleased += 1
        }
    }

    private func startStaleSessionReaperIfNeeded() {
        guard staleSessionReaperTask == nil else { return }
        staleSessionReaperTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(90))
                guard !Task.isCancelled, let self else { return }
                self.reapStaleSessions()
                self.reapDeallocatedSessions()
                if self.trackedSessions.isEmpty && self.inUseCount == 0 {
                    self.staleSessionReaperTask = nil
                    return
                }
            }
        }
    }

    private func generateUserAgent() -> String {
        let osVersions = ["17_5_1", "17_6", "18_0", "18_1", "18_2", "18_3"]
        let osVersion = osVersions.randomElement()!
        let majorMinor = osVersion.replacingOccurrences(of: "_", with: ".").components(separatedBy: ".").prefix(2).joined(separator: ".")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(osVersion) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(majorMinor) Mobile/15E148 Safari/605.1.15"
    }
}
