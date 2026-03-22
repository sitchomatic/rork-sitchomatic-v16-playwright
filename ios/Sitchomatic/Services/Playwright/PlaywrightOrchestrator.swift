import Foundation
import WebKit
import Network

nonisolated struct PairedPageResult: Sendable {
    let joePage: PlaywrightPage
    let ignitionPage: PlaywrightPage
    let sharedProxySessionID: String
    let sharedProxyEndpoint: String
}

nonisolated enum DualLoginOutcome: String, Sendable {
    case success
    case permDisabled
    case tempDisabled
    case unsure
    case networkError
    case crashed

    var isTerminal: Bool {
        self == .permDisabled
    }

    var shouldRetry: Bool {
        self == .tempDisabled || self == .networkError || self == .crashed
    }
}

nonisolated struct DualLoginResult: Sendable {
    let credential: LoginCredential
    let outcome: DualLoginOutcome
    let joeOutcome: DualLoginOutcome
    let ignitionOutcome: DualLoginOutcome
    let joeScreenshot: Data?
    let ignitionScreenshot: Data?
    let joeTrace: [TraceEntry]
    let ignitionTrace: [TraceEntry]
    let duration: TimeInterval
    let proxyUsed: String
    let errorMessage: String?

    static func combine(
        credential: LoginCredential,
        joeOutcome: DualLoginOutcome,
        ignitionOutcome: DualLoginOutcome,
        joeScreenshot: Data?,
        ignitionScreenshot: Data?,
        joeTrace: [TraceEntry],
        ignitionTrace: [TraceEntry],
        duration: TimeInterval,
        proxyUsed: String
    ) -> DualLoginResult {
        let combined: DualLoginOutcome
        let errorMsg: String?

        switch (joeOutcome, ignitionOutcome) {
        case (.success, .success):
            combined = .success
            errorMsg = nil
        case (.permDisabled, _), (_, .permDisabled):
            combined = .permDisabled
            errorMsg = "Permanent disable detected"
        case (.tempDisabled, _), (_, .tempDisabled):
            combined = .tempDisabled
            errorMsg = "Temporary disable detected"
        case (.crashed, _), (_, .crashed):
            combined = .crashed
            errorMsg = "WebView crash during login"
        case (.networkError, _), (_, .networkError):
            combined = .networkError
            errorMsg = "Network error during login"
        default:
            combined = .unsure
            errorMsg = "Mixed results — joe: \(joeOutcome.rawValue), ignition: \(ignitionOutcome.rawValue)"
        }

        return DualLoginResult(
            credential: credential,
            outcome: combined,
            joeOutcome: joeOutcome,
            ignitionOutcome: ignitionOutcome,
            joeScreenshot: joeScreenshot,
            ignitionScreenshot: ignitionScreenshot,
            joeTrace: joeTrace,
            ignitionTrace: ignitionTrace,
            duration: duration,
            proxyUsed: proxyUsed,
            errorMessage: errorMsg
        )
    }
}

nonisolated struct CredentialWaveAssignment: Sendable {
    let credential: LoginCredential
    let waveIndex: Int
    let slotIndex: Int
    let proxySessionID: String
}

nonisolated enum OrchestratorError: Error, LocalizedError, Sendable {
    case maxPagesReached(Int)
    case sessionNotStarted
    case pageNotFound
    case noProxyAvailable
    case webViewPoolExhausted
    case credentialPairFailed(String)
    case backgroundTaskExpired
    case emergencyShutdown(String)

    var errorDescription: String? {
        switch self {
        case .maxPagesReached(let max): "Maximum \(max) concurrent pages reached"
        case .sessionNotStarted: "Session not started — call startSession() first"
        case .pageNotFound: "Page not found in current session"
        case .noProxyAvailable: "No proxy available for paired page creation"
        case .webViewPoolExhausted: "WebView pool exhausted — all slots in use"
        case .credentialPairFailed(let reason): "Credential pair failed: \(reason)"
        case .backgroundTaskExpired: "Background task expired — session terminated"
        case .emergencyShutdown(let reason): "Emergency shutdown: \(reason)"
        }
    }
}

nonisolated enum SessionLogCategory: String, Sendable {
    case system
    case page
    case network
    case error
    case dualMode
    case proxy
    case stealth
    case trace
    case recovery
    case background
    case speed
}

nonisolated struct SessionLogEntry: Sendable, Identifiable {
    let id: UUID = UUID()
    let timestamp: Date
    let category: SessionLogCategory
    let message: String

    var formatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return "[\(formatter.string(from: timestamp))] [\(category.rawValue)] \(message)"
    }
}

@Observable
@MainActor
final class PlaywrightOrchestrator {

    // MARK: - Public State

    private(set) var pages: [PlaywrightPage] = []
    private(set) var isReady: Bool = false
    private(set) var statusMessage: String = "Idle"
    private(set) var globalTracingEnabled: Bool = true
    private(set) var sessionLog: [SessionLogEntry] = []
    private(set) var activePairedSessions: Int = 0
    private(set) var totalPairedSessionsRun: Int = 0
    private(set) var totalCredentialsProcessed: Int = 0
    private(set) var lastDualResults: [DualLoginResult] = []
    private(set) var proxySessionMap: [String: String] = [:]

    // MARK: - Private State

    private let pool: WebViewPool = .shared
    private let networkManager: SimpleNetworkManager = .shared
    private let crashProtection: CrashProtectionService = .shared
    private let fileStorage: PersistentFileStorageService = .shared
    private let logger: DebugLogger = .shared
    private let backgroundService: BackgroundTaskService = .shared

    private let defaultViewportSize: CGSize = CGSize(width: 390, height: 844)
    private let maxConcurrentPages: Int = 24
    private let maxConcurrentPairs: Int = 12
    private var sessionStartTime: Date?
    private var pageCounter: Int = 0
    private var credentialProxyMap: [String: String] = [:]
    private var activeSpeedMode: SpeedMode = .balanced
    private var recoveryAttempts: [String: Int] = [:]
    private let maxRecoveryAttempts: Int = 3

    static let shared = PlaywrightOrchestrator()

    private init() {}

    // MARK: - Session Lifecycle

    func startSession(speedMode: SpeedMode = .balanced) async throws {
        guard !isReady else {
            log(.system, "Session already active — reusing")
            return
        }

        statusMessage = "Starting session..."
        sessionStartTime = Date()
        sessionLog.removeAll()
        pages.removeAll()
        pageCounter = 0
        activePairedSessions = 0
        lastDualResults.removeAll()
        credentialProxyMap.removeAll()
        recoveryAttempts.removeAll()
        activeSpeedMode = speedMode

        log(.system, "Sitchomatic v16 Playwright Edition — session starting")
        log(.speed, "Speed mode: \(speedMode.displayName) (typing: \(speedMode.typingDelayMs)ms, action: \(speedMode.actionDelayMs)ms, post-submit: \(speedMode.postSubmitWaitMs)ms)")

        backgroundService.beginBackgroundTask(identifier: "sitchomatic.session") { [weak self] in
            Task { @MainActor in
                self?.log(.background, "Background task expiring — saving state")
                self?.emergencyPersistState()
            }
        }

        if networkManager.connectionStatus == .disconnected {
            statusMessage = "Connecting network..."
            log(.network, "Network disconnected — initiating connection")
            await networkManager.connect()
            log(.network, "Network status: \(networkManager.connectionStatus.displayName)")
        }

        crashProtection.startMonitoring()
        log(.recovery, "Crash protection monitoring active")

        isReady = true
        statusMessage = "Ready — Dual Mode"
        log(.system, "Orchestrator ready — permanent Dual Mode — network: \(networkManager.connectionStatus.displayName)")
    }

    func endSession() {
        guard isReady else { return }
        log(.system, "Session ending — \(pages.count) pages open, \(activePairedSessions) active pairs")

        for page in pages {
            if page.tracingEnabled {
                let trace = page.stopTracing()
                saveTraceToFile(trace, pageID: page.id)
            }
            pool.release(page.webView, wipeData: true)
        }

        pages.removeAll()
        pageCounter = 0
        activePairedSessions = 0
        isReady = false
        statusMessage = "Session ended"

        backgroundService.endBackgroundTask(identifier: "sitchomatic.session")

        if let start = sessionStartTime {
            let duration = Date().timeIntervalSince(start)
            log(.system, "Session duration: \(String(format: "%.1f", duration))s — \(totalPairedSessionsRun) paired sessions, \(totalCredentialsProcessed) credentials")
        }
        sessionStartTime = nil
    }

    // MARK: - Single Page (for DualFind, FlowRecorder, general use)

    func newPage(viewport: CGSize? = nil, forceNewFingerprint: Bool = true) async throws -> PlaywrightPage {
        guard isReady else {
            throw OrchestratorError.sessionNotStarted
        }
        guard pages.count < maxConcurrentPages else {
            throw OrchestratorError.maxPagesReached(maxConcurrentPages)
        }

        if crashProtection.isMemoryCritical {
            log(.recovery, "Memory critical before page creation — running cleanup")
            pool.handleMemoryPressure()
            _ = await crashProtection.waitForMemoryToDrop(timeout: 5)
        }

        let effectiveViewport = viewport ?? defaultViewportSize
        statusMessage = "Creating page \(pageCounter)..."

        let sessionID = "page-\(pageCounter)-\(UUID().uuidString.prefix(6))"
        let webView = await pool.acquire(
            stealthEnabled: true,
            viewportSize: effectiveViewport,
            networkConfig: networkManager.currentNetworkConfig,
            target: .joe
        )

        injectEnhancedStealth(into: webView)

        let proxyEndpoint = networkManager.proxyEndpoint(forSessionID: sessionID)
        if let ep = proxyEndpoint {
            log(.proxy, "Page \(pageCounter) → proxy \(ep.host):\(ep.port)")
        } else {
            log(.proxy, "Page \(pageCounter) → direct connection")
        }

        let pageID = UUID()
        let page = PlaywrightPage(
            webView: webView,
            id: pageID,
            defaultTimeout: 30.0,
            orchestrator: self
        )

        if globalTracingEnabled {
            page.startTracing()
            log(.trace, "Auto-tracing started for page \(pageCounter)")
        }

        pages.append(page)
        pageCounter += 1
        statusMessage = "Ready — \(pages.count) page(s)"
        log(.page, "Page created (id: \(pageID.uuidString.prefix(8)), viewport: \(Int(effectiveViewport.width))x\(Int(effectiveViewport.height)), stealth: ON)")

        return page
    }

    // MARK: - Paired Page Creation (CORE v16 — Permanent Dual Mode)

    func newPairedPage(credential: LoginCredential) async throws -> PairedPageResult {
        guard isReady else {
            throw OrchestratorError.sessionNotStarted
        }
        guard pages.count + 2 <= maxConcurrentPages else {
            throw OrchestratorError.maxPagesReached(maxConcurrentPages)
        }
        guard activePairedSessions < maxConcurrentPairs else {
            throw OrchestratorError.maxPagesReached(maxConcurrentPairs)
        }

        if crashProtection.isMemoryCritical {
            log(.recovery, "Memory critical before paired page creation — aggressive cleanup")
            pool.handleMemoryPressure()
            pool.drainPreWarmed()
            _ = await crashProtection.waitForMemoryToDrop(timeout: 8)
            if crashProtection.isMemoryEmergency {
                throw OrchestratorError.emergencyShutdown("Memory emergency — cannot create paired pages")
            }
        }

        let credentialKey = credential.id.uuidString
        let sharedProxySessionID: String
        if let existingSessionID = credentialProxyMap[credentialKey] {
            sharedProxySessionID = existingSessionID
            log(.proxy, "Reusing proxy session \(existingSessionID) for credential \(credential.displayName)")
        } else {
            sharedProxySessionID = "dual-\(credentialKey.prefix(8))-\(UUID().uuidString.prefix(4))"
            credentialProxyMap[credentialKey] = sharedProxySessionID
            log(.proxy, "New shared proxy session \(sharedProxySessionID) for credential \(credential.displayName)")
        }

        let sharedProxyEndpoint: String
        if let ep = networkManager.proxyEndpoint(forSessionID: sharedProxySessionID) {
            sharedProxyEndpoint = "\(ep.host):\(ep.port)"
        } else {
            sharedProxyEndpoint = "direct"
            log(.proxy, "WARNING: No proxy available — paired pages will use direct connection")
        }

        proxySessionMap[credentialKey] = sharedProxyEndpoint
        statusMessage = "Creating paired pages for \(credential.displayName)..."

        log(.dualMode, "Creating paired pages — credential: \(credential.displayName), proxy: \(sharedProxyEndpoint)")

        let networkConfig = networkManager.currentNetworkConfig

        async let joeWebViewTask: WKWebView = pool.acquire(
            stealthEnabled: true,
            viewportSize: defaultViewportSize,
            networkConfig: networkConfig,
            target: .joe
        )
        async let ignitionWebViewTask: WKWebView = pool.acquire(
            stealthEnabled: true,
            viewportSize: defaultViewportSize,
            networkConfig: networkConfig,
            target: .joe
        )

        let joeWebView = await joeWebViewTask
        let ignitionWebView = await ignitionWebViewTask

        injectEnhancedStealth(into: joeWebView)
        injectEnhancedStealth(into: ignitionWebView)

        applySharedProxy(to: joeWebView, sessionID: sharedProxySessionID)
        applySharedProxy(to: ignitionWebView, sessionID: sharedProxySessionID)

        let joePageID = UUID()
        let ignitionPageID = UUID()

        let joePage = PlaywrightPage(
            webView: joeWebView,
            id: joePageID,
            defaultTimeout: 30.0,
            orchestrator: self
        )
        let ignitionPage = PlaywrightPage(
            webView: ignitionWebView,
            id: ignitionPageID,
            defaultTimeout: 30.0,
            orchestrator: self
        )

        joePage.startTracing()
        ignitionPage.startTracing()

        pages.append(joePage)
        pages.append(ignitionPage)
        pageCounter += 2
        activePairedSessions += 1
        totalPairedSessionsRun += 1

        statusMessage = "Ready — \(pages.count) pages (\(activePairedSessions) pairs)"

        log(.dualMode, "Paired pages created — joe: \(joePageID.uuidString.prefix(8)), ignition: \(ignitionPageID.uuidString.prefix(8)), shared proxy: \(sharedProxyEndpoint)")
        log(.stealth, "Both pages have unique fingerprints via pool rotation + enhanced stealth injection")

        return PairedPageResult(
            joePage: joePage,
            ignitionPage: ignitionPage,
            sharedProxySessionID: sharedProxySessionID,
            sharedProxyEndpoint: sharedProxyEndpoint
        )
    }

    // MARK: - Dual Login Execution (runs both Joe + Ignition in parallel)

    func executeDualLogin(
        credential: LoginCredential,
        joeURL: String,
        ignitionURL: String,
        joeFlow: @escaping @Sendable @MainActor (PlaywrightPage, LoginCredential, SpeedMode) async throws -> DualLoginOutcome,
        ignitionFlow: @escaping @Sendable @MainActor (PlaywrightPage, LoginCredential, SpeedMode) async throws -> DualLoginOutcome
    ) async -> DualLoginResult {
        let startTime = Date()
        let speed = activeSpeedMode

        log(.dualMode, "Dual login starting — credential: \(credential.displayName)")

        let pair: PairedPageResult
        do {
            pair = try await newPairedPage(credential: credential)
        } catch {
            log(.error, "Failed to create paired pages: \(error.localizedDescription)")
            return DualLoginResult(
                credential: credential,
                outcome: .networkError,
                joeOutcome: .networkError,
                ignitionOutcome: .networkError,
                joeScreenshot: nil,
                ignitionScreenshot: nil,
                joeTrace: [],
                ignitionTrace: [],
                duration: Date().timeIntervalSince(startTime),
                proxyUsed: "none",
                errorMessage: error.localizedDescription
            )
        }

        var joeOutcome: DualLoginOutcome = .unsure
        var ignitionOutcome: DualLoginOutcome = .unsure
        var joeScreenshot: Data?
        var ignitionScreenshot: Data?

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                do {
                    joeOutcome = try await joeFlow(pair.joePage, credential, speed)
                } catch is CancellationError {
                    joeOutcome = .crashed
                } catch {
                    joeOutcome = .unsure
                    self.log(.error, "Joe flow error: \(error.localizedDescription)")
                }
                joeScreenshot = try? await pair.joePage.screenshot()
            }

            group.addTask { @MainActor in
                do {
                    ignitionOutcome = try await ignitionFlow(pair.ignitionPage, credential, speed)
                } catch is CancellationError {
                    ignitionOutcome = .crashed
                } catch {
                    ignitionOutcome = .unsure
                    self.log(.error, "Ignition flow error: \(error.localizedDescription)")
                }
                ignitionScreenshot = try? await pair.ignitionPage.screenshot()
            }
        }

        let joeTrace = pair.joePage.tracingEnabled ? pair.joePage.stopTracing() : []
        let ignitionTrace = pair.ignitionPage.tracingEnabled ? pair.ignitionPage.stopTracing() : []

        let duration = Date().timeIntervalSince(startTime)

        let result = DualLoginResult.combine(
            credential: credential,
            joeOutcome: joeOutcome,
            ignitionOutcome: ignitionOutcome,
            joeScreenshot: joeScreenshot,
            ignitionScreenshot: ignitionScreenshot,
            joeTrace: joeTrace,
            ignitionTrace: ignitionTrace,
            duration: duration,
            proxyUsed: pair.sharedProxyEndpoint
        )

        if result.outcome != .success {
            saveFailureArtifacts(result: result)
        }

        closePairedPages(joe: pair.joePage, ignition: pair.ignitionPage)
        totalCredentialsProcessed += 1
        lastDualResults.append(result)

        log(.dualMode, "Dual login complete — credential: \(credential.displayName), outcome: \(result.outcome.rawValue), joe: \(joeOutcome.rawValue), ignition: \(ignitionOutcome.rawValue), duration: \(String(format: "%.1f", duration))s")

        return result
    }

    // MARK: - Wave Execution (multiple credentials concurrently)

    func executeCredentialWave(
        credentials: [LoginCredential],
        concurrency: Int = 6,
        joeURL: String,
        ignitionURL: String,
        joeFlow: @escaping @Sendable @MainActor (PlaywrightPage, LoginCredential, SpeedMode) async throws -> DualLoginOutcome,
        ignitionFlow: @escaping @Sendable @MainActor (PlaywrightPage, LoginCredential, SpeedMode) async throws -> DualLoginOutcome,
        onProgress: ((Int, Int, DualLoginResult) -> Void)? = nil
    ) async -> [DualLoginResult] {
        let effectiveConcurrency = min(concurrency, maxConcurrentPairs, credentials.count)
        let waveCount = (credentials.count + effectiveConcurrency - 1) / effectiveConcurrency

        log(.dualMode, "Wave execution starting — \(credentials.count) credentials, concurrency: \(effectiveConcurrency), waves: \(waveCount)")

        var allResults: [DualLoginResult] = []
        var completedCount = 0

        for waveIdx in 0..<waveCount {
            guard isReady else {
                log(.error, "Orchestrator no longer ready — aborting wave execution")
                break
            }

            if crashProtection.shouldReduceConcurrency {
                log(.recovery, "Memory pressure — reducing wave concurrency")
                try? await Task.sleep(for: .seconds(3))
            }

            let startIdx = waveIdx * effectiveConcurrency
            let endIdx = min(startIdx + effectiveConcurrency, credentials.count)
            let waveCredentials = Array(credentials[startIdx..<endIdx])

            log(.dualMode, "Wave \(waveIdx + 1)/\(waveCount) — \(waveCredentials.count) credentials")

            let waveResults: [DualLoginResult] = await withTaskGroup(of: DualLoginResult.self) { group in
                for cred in waveCredentials {
                    group.addTask { @MainActor in
                        await self.executeDualLogin(
                            credential: cred,
                            joeURL: joeURL,
                            ignitionURL: ignitionURL,
                            joeFlow: joeFlow,
                            ignitionFlow: ignitionFlow
                        )
                    }
                }

                var results: [DualLoginResult] = []
                for await result in group {
                    results.append(result)
                    completedCount += 1
                    onProgress?(completedCount, credentials.count, result)
                }
                return results
            }

            allResults.append(contentsOf: waveResults)

            if waveIdx < waveCount - 1 {
                let interWaveDelay = activeSpeedMode.actionDelayMs
                log(.speed, "Inter-wave delay: \(interWaveDelay)ms")
                try? await Task.sleep(for: .milliseconds(interWaveDelay))
            }
        }

        let succeeded = allResults.filter { $0.outcome == .success }.count
        let failed = allResults.filter { !$0.outcome.shouldRetry && $0.outcome != .success }.count
        let retryable = allResults.filter { $0.outcome.shouldRetry }.count

        log(.dualMode, "Wave execution complete — \(succeeded) succeeded, \(failed) failed, \(retryable) retryable out of \(allResults.count) total")

        return allResults
    }

    // MARK: - Page Management

    func closePage(_ page: PlaywrightPage) {
        if page.tracingEnabled {
            let trace = page.stopTracing()
            if !trace.isEmpty {
                saveTraceToFile(trace, pageID: page.id)
            }
        }

        pool.release(page.webView, wipeData: true)
        pages.removeAll { $0.id == page.id }
        statusMessage = pages.isEmpty ? "Ready — no pages" : "Ready — \(pages.count) page(s)"
        log(.page, "Page closed (id: \(page.id.uuidString.prefix(8)))")
    }

    func closeAllPages() {
        for page in pages {
            if page.tracingEnabled {
                let trace = page.stopTracing()
                saveTraceToFile(trace, pageID: page.id)
            }
            pool.release(page.webView, wipeData: true)
        }
        pages.removeAll()
        pageCounter = 0
        activePairedSessions = 0
        statusMessage = "Ready — no pages"
        log(.page, "All pages closed")
    }

    private func closePairedPages(joe: PlaywrightPage, ignition: PlaywrightPage) {
        pool.release(joe.webView, wipeData: true)
        pool.release(ignition.webView, wipeData: true)
        pages.removeAll { $0.id == joe.id || $0.id == ignition.id }
        activePairedSessions = max(0, activePairedSessions - 1)
        statusMessage = pages.isEmpty ? "Ready — no pages" : "Ready — \(pages.count) page(s) (\(activePairedSessions) pairs)"
    }

    // MARK: - Tracing

    func enableGlobalTracing() {
        globalTracingEnabled = true
        for page in pages where !page.tracingEnabled {
            page.startTracing()
        }
        log(.trace, "Global tracing enabled for all pages")
    }

    func disableGlobalTracing() -> [[TraceEntry]] {
        globalTracingEnabled = false
        var allTraces: [[TraceEntry]] = []
        for page in pages where page.tracingEnabled {
            allTraces.append(page.stopTracing())
        }
        let totalEntries = allTraces.flatMap { $0 }.count
        log(.trace, "Global tracing disabled — collected \(totalEntries) entries across \(allTraces.count) pages")
        return allTraces
    }

    // MARK: - Crash Recovery

    func recoverCrashedPage(_ crashedPage: PlaywrightPage, credential: LoginCredential?) async throws -> PlaywrightPage {
        let credKey = credential?.id.uuidString ?? "unknown"
        let attempts = recoveryAttempts[credKey] ?? 0

        guard attempts < maxRecoveryAttempts else {
            log(.recovery, "Max recovery attempts (\(maxRecoveryAttempts)) reached for \(credKey) — giving up")
            throw OrchestratorError.credentialPairFailed("Max recovery attempts exceeded")
        }

        recoveryAttempts[credKey] = attempts + 1
        log(.recovery, "Recovering crashed page (attempt \(attempts + 1)/\(maxRecoveryAttempts)) for \(credKey)")

        pool.reportProcessTermination()
        closePage(crashedPage)

        let backoffMs = min(1000 * (attempts + 1), 5000)
        log(.recovery, "Backoff delay: \(backoffMs)ms before replacement")
        try await Task.sleep(for: .milliseconds(backoffMs))

        let replacement = try await newPage(forceNewFingerprint: true)
        log(.recovery, "Replacement page created — id: \(replacement.id.uuidString.prefix(8))")

        return replacement
    }

    func recoverCrashedPair(credential: LoginCredential) async throws -> PairedPageResult {
        let credKey = credential.id.uuidString
        let attempts = recoveryAttempts[credKey] ?? 0

        guard attempts < maxRecoveryAttempts else {
            throw OrchestratorError.credentialPairFailed("Max recovery attempts exceeded for paired pages")
        }

        recoveryAttempts[credKey] = attempts + 1
        log(.recovery, "Recovering crashed pair (attempt \(attempts + 1)/\(maxRecoveryAttempts)) for \(credential.displayName)")

        credentialProxyMap.removeValue(forKey: credKey)

        let backoffMs = min(2000 * (attempts + 1), 10000)
        try await Task.sleep(for: .milliseconds(backoffMs))

        return try await newPairedPage(credential: credential)
    }

    // MARK: - Speed Mode

    func setSpeedMode(_ mode: SpeedMode) {
        activeSpeedMode = mode
        log(.speed, "Speed mode changed to: \(mode.displayName)")
    }

    var currentSpeedMode: SpeedMode { activeSpeedMode }

    // MARK: - Convenience: Quick Script

    func quickRun(_ block: (PlaywrightPage) async throws -> Void) async throws {
        let wasReady = isReady
        if !wasReady {
            try await startSession()
        }

        let page = try await newPage()

        do {
            try await block(page)
        } catch {
            closePage(page)
            if !wasReady { endSession() }
            throw error
        }

        closePage(page)
        if !wasReady { endSession() }
    }

    // MARK: - Network Status

    var networkStatusSummary: String {
        networkManager.quickStatusLine
    }

    var activeProxyCount: Int {
        networkManager.proxyCount
    }

    var connectionStatus: ConnectionStatus {
        networkManager.connectionStatus
    }

    // MARK: - Diagnostics

    var diagnosticSummary: String {
        let uptime: String
        if let start = sessionStartTime {
            let seconds = Int(Date().timeIntervalSince(start))
            uptime = "\(seconds / 60)m \(seconds % 60)s"
        } else {
            uptime = "N/A"
        }

        return """
        Sitchomatic v16 | Mode: Permanent Dual | Speed: \(activeSpeedMode.displayName)
        Pages: \(pages.count)/\(maxConcurrentPages) | Pairs: \(activePairedSessions)/\(maxConcurrentPairs)
        Credentials Processed: \(totalCredentialsProcessed) | Paired Runs: \(totalPairedSessionsRun)
        Network: \(networkManager.connectionStatus.displayName) | Proxies: \(networkManager.proxyCount)
        Pool: \(pool.diagnosticSummary)
        Memory: \(crashProtection.isMemorySafeForNewSession ? "OK" : crashProtection.isMemoryCritical ? "CRITICAL" : "HIGH")
        Uptime: \(uptime)
        Log entries: \(sessionLog.count)
        """
    }

    // MARK: - Private: Enhanced Stealth Injection

    private func injectEnhancedStealth(into webView: WKWebView) {
        let stealthJS = """
        (function() {
            if (window.__sitchoV16Stealth) return;
            window.__sitchoV16Stealth = true;

            // Canvas fingerprint randomization
            var origToDataURL = HTMLCanvasElement.prototype.toDataURL;
            HTMLCanvasElement.prototype.toDataURL = function(type) {
                var ctx = this.getContext('2d');
                if (ctx) {
                    var imgData = ctx.getImageData(0, 0, Math.min(this.width, 16), Math.min(this.height, 16));
                    for (var i = 0; i < imgData.data.length; i += 4) {
                        imgData.data[i] = imgData.data[i] ^ (Math.random() * 2 | 0);
                    }
                    ctx.putImageData(imgData, 0, 0);
                }
                return origToDataURL.apply(this, arguments);
            };

            // WebGL fingerprint randomization
            var origGetParameter = WebGLRenderingContext.prototype.getParameter;
            WebGLRenderingContext.prototype.getParameter = function(param) {
                if (param === 37445) return 'Apple Inc.';
                if (param === 37446) return 'Apple GPU';
                return origGetParameter.apply(this, arguments);
            };

            // AudioContext fingerprint randomization
            if (window.AudioContext || window.webkitAudioContext) {
                var AC = window.AudioContext || window.webkitAudioContext;
                var origCreateOscillator = AC.prototype.createOscillator;
                AC.prototype.createOscillator = function() {
                    var osc = origCreateOscillator.apply(this, arguments);
                    var origConnect = osc.connect;
                    osc.connect = function(dest) {
                        if (dest.constructor.name === 'AnalyserNode') {
                            return osc;
                        }
                        return origConnect.apply(this, arguments);
                    };
                    return osc;
                };
            }

            // Navigator property randomization
            Object.defineProperty(navigator, 'hardwareConcurrency', {
                get: function() { return [4, 6, 8][Math.floor(Math.random() * 3)]; }
            });
            Object.defineProperty(navigator, 'deviceMemory', {
                get: function() { return [4, 6, 8][Math.floor(Math.random() * 3)]; }
            });

            // Prevent WebDriver detection
            Object.defineProperty(navigator, 'webdriver', {
                get: function() { return false; }
            });

            // Chrome runtime spoof
            window.chrome = { runtime: {}, loadTimes: function() { return {}; }, csi: function() { return {}; } };

            // Permissions API spoof
            if (navigator.permissions) {
                var origQuery = navigator.permissions.query;
                navigator.permissions.query = function(params) {
                    if (params.name === 'notifications') {
                        return Promise.resolve({ state: 'prompt', onchange: null });
                    }
                    return origQuery.apply(this, arguments);
                };
            }

            // Plugins/MimeTypes spoof for mobile
            Object.defineProperty(navigator, 'plugins', {
                get: function() { return []; }
            });
            Object.defineProperty(navigator, 'mimeTypes', {
                get: function() { return []; }
            });
        })();
        """

        let userScript = WKUserScript(
            source: stealthJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        webView.configuration.userContentController.addUserScript(userScript)
    }

    // MARK: - Private: Shared Proxy Application

    private func applySharedProxy(to webView: WKWebView, sessionID: String) {
        guard let endpoint = networkManager.proxyEndpoint(forSessionID: sessionID) else {
            return
        }

        let proxyConfig = ProxyConfigurationHelper.createProxyConfiguration(
            host: endpoint.host,
            port: endpoint.port
        )
        if let proxyConfig {
            webView.configuration.websiteDataStore.proxyConfigurations = [proxyConfig]
        }
    }

    // MARK: - Private: Failure Artifact Saving

    private func saveFailureArtifacts(result: DualLoginResult) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let credName = result.credential.displayName.replacingOccurrences(of: " ", with: "_")
        let prefix = "failures/\(credName)_\(timestamp)"

        if let joeScreenshot = result.joeScreenshot {
            fileStorage.save(data: joeScreenshot, filename: "\(prefix)_joe.png")
        }
        if let ignitionScreenshot = result.ignitionScreenshot {
            fileStorage.save(data: ignitionScreenshot, filename: "\(prefix)_ignition.png")
        }

        if !result.joeTrace.isEmpty || !result.ignitionTrace.isEmpty {
            let traceData = formatTraceForExport(
                joeTrace: result.joeTrace,
                ignitionTrace: result.ignitionTrace,
                credential: result.credential,
                outcome: result.outcome
            )
            if let data = traceData.data(using: .utf8) {
                fileStorage.save(data: data, filename: "\(prefix)_trace.json")
            }
        }

        log(.trace, "Failure artifacts saved for \(credName) — outcome: \(result.outcome.rawValue)")
    }

    private func saveTraceToFile(_ trace: [TraceEntry], pageID: UUID) {
        guard !trace.isEmpty else { return }
        let lines = trace.map { $0.formatted }
        let content = lines.joined(separator: "\n")
        if let data = content.data(using: .utf8) {
            fileStorage.save(data: data, filename: "traces/\(pageID.uuidString.prefix(8))_trace.log")
        }
    }

    private func formatTraceForExport(
        joeTrace: [TraceEntry],
        ignitionTrace: [TraceEntry],
        credential: LoginCredential,
        outcome: DualLoginOutcome
    ) -> String {
        let json: [String: Any] = [
            "version": "v16",
            "credential": credential.displayName,
            "outcome": outcome.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "joeTraceCount": joeTrace.count,
            "ignitionTraceCount": ignitionTrace.count,
            "joeTrace": joeTrace.map { ["ts": $0.formatted, "cat": $0.category.rawValue, "msg": $0.message] },
            "ignitionTrace": ignitionTrace.map { ["ts": $0.formatted, "cat": $0.category.rawValue, "msg": $0.message] }
        ]
        _ = json.count
        if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    // MARK: - Private: Emergency State Persistence

    private func emergencyPersistState() {
        let state: [String: Any] = [
            "sessionActive": isReady,
            "pagesCount": pages.count,
            "activePairs": activePairedSessions,
            "totalProcessed": totalCredentialsProcessed,
            "speedMode": activeSpeedMode.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        if let data = try? JSONSerialization.data(withJSONObject: state),
           let str = String(data: data, encoding: .utf8) {
            logger.log("Emergency state saved: \(str)", category: .automation, level: .critical)
        }
    }

    // MARK: - Private: Logging

    func log(_ category: SessionLogCategory, _ message: String) {
        let entry = SessionLogEntry(
            timestamp: Date(),
            category: category,
            message: message
        )
        sessionLog.append(entry)

        let logLevel: DebugLogger.LogLevel = category == .error ? .error : category == .recovery ? .warning : .debug
        let logCategory: DebugLogger.LogCategory
        switch category {
        case .system, .background: logCategory = .automation
        case .page, .stealth: logCategory = .webView
        case .network, .proxy: logCategory = .network
        case .error, .recovery: logCategory = .automation
        case .dualMode, .speed: logCategory = .automation
        case .trace: logCategory = .webView
        }
        logger.log("[\(category.rawValue)] \(message)", category: logCategory, level: logLevel)
    }
}
