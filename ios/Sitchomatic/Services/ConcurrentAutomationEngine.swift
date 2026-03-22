import Foundation
import WebKit

nonisolated enum EngineState: String, Sendable {
    case idle, preparing, running, paused, completed, failed, cancelled

    var isActive: Bool { self == .running || self == .paused || self == .preparing }
}

@Observable
@MainActor
final class ConcurrentAutomationEngine {
    static let shared = ConcurrentAutomationEngine()

    private(set) var state: EngineState = .idle
    private(set) var sessions: [ConcurrentSession] = []
    private(set) var engineLog: [SessionLogLine] = []
    private(set) var currentWave: Int = 0
    private(set) var totalWaves: Int = 0
    private(set) var startTime: Date?

    private(set) var isPauseRequested: Bool = false
    private var runTask: Task<Void, Never>?

    private let orchestrator = PlaywrightOrchestrator.shared
    private let networkManager = SimpleNetworkManager.shared
    private let settings = AutomationSettings.shared
    private let backgroundService = BackgroundTaskService.shared
    private let crashRecovery = WebViewCrashRecoveryService.shared
    private let logger = DebugLogger.shared

    var succeededCount: Int { sessions.filter { $0.phase == .succeeded }.count }
    var failedCount: Int { sessions.filter { $0.phase == .failed }.count }
    var cancelledCount: Int { sessions.filter { $0.phase == .cancelled }.count }
    var activeCount: Int { sessions.filter { $0.phase.isActive }.count }
    var queuedCount: Int { sessions.filter { $0.phase == .queued }.count }
    var isRunning: Bool { state.isActive }

    var overallProgress: Double {
        guard !sessions.isEmpty else { return 0 }
        let terminal = sessions.filter { $0.phase.isTerminal }.count
        return Double(terminal) / Double(sessions.count)
    }

    var elapsedFormatted: String {
        guard let start = startTime else { return "0:00" }
        let elapsed = Int(Date().timeIntervalSince(start))
        return String(format: "%d:%02d", elapsed / 60, elapsed % 60)
    }

    private init() {}

    func startDualRun(
        credentials: [LoginCredential],
        joeFlow: @escaping @Sendable @MainActor (PlaywrightPage, LoginCredential, SpeedMode) async throws -> DualLoginOutcome,
        ignitionFlow: @escaping @Sendable @MainActor (PlaywrightPage, LoginCredential, SpeedMode) async throws -> DualLoginOutcome
    ) {
        guard state == .idle || state == .completed || state == .failed || state == .cancelled else { return }

        let concurrency = settings.maxConcurrentPairs
        let enabledCredentials = credentials.filter { $0.isEnabled }
        guard !enabledCredentials.isEmpty else { return }

        state = .preparing
        sessions.removeAll()
        engineLog.removeAll()
        currentWave = 0
        isPauseRequested = false
        startTime = Date()

        totalWaves = (enabledCredentials.count + concurrency - 1) / concurrency

        for (index, cred) in enabledCredentials.enumerated() {
            let waveIndex = index / concurrency
            sessions.append(ConcurrentSession(index: index, waveIndex: waveIndex, credential: cred))
        }

        log(.phase, "Dual run starting — \(enabledCredentials.count) credentials, \(concurrency) concurrent pairs, \(totalWaves) waves")

        backgroundService.beginBackgroundTask(identifier: "sitchomatic.engine") { [weak self] in
            Task { @MainActor in
                self?.log(.error, "Background task expiring — stopping engine")
                self?.stop()
            }
        }

        runTask = Task { @MainActor in
            await self.executeWaves(
                joeFlow: joeFlow,
                ignitionFlow: ignitionFlow
            )
        }
    }

    func pause() {
        guard state == .running else { return }
        isPauseRequested = true
        state = .paused
        log(.phase, "Engine paused")
    }

    func resume() {
        guard state == .paused else { return }
        isPauseRequested = false
        state = .running
        log(.phase, "Engine resumed")
    }

    func stop() {
        runTask?.cancel()

        for session in sessions where !session.phase.isTerminal {
            session.updatePhase(.cancelled)
        }

        orchestrator.closeAllPages()
        state = .cancelled
        backgroundService.endBackgroundTask(identifier: "sitchomatic.engine")
        log(.result, "Engine stopped")
    }

    func reset() {
        stop()
        sessions.removeAll()
        engineLog.removeAll()
        currentWave = 0
        totalWaves = 0
        startTime = nil
        state = .idle
    }

    // MARK: - Private: Wave Execution

    private func executeWaves(
        joeFlow: @escaping @Sendable @MainActor (PlaywrightPage, LoginCredential, SpeedMode) async throws -> DualLoginOutcome,
        ignitionFlow: @escaping @Sendable @MainActor (PlaywrightPage, LoginCredential, SpeedMode) async throws -> DualLoginOutcome
    ) async {
        state = .running

        if !orchestrator.isReady {
            do {
                try await orchestrator.startSession(speedMode: settings.speedMode)
            } catch {
                state = .failed
                log(.error, "Failed to start orchestrator: \(error.localizedDescription)")
                backgroundService.endBackgroundTask(identifier: "sitchomatic.engine")
                return
            }
        }

        if networkManager.connectionStatus == .disconnected {
            log(.network, "Connecting network...")
            await networkManager.connect()
        }

        let waveCount = totalWaves
        for waveIdx in 0..<waveCount {
            guard !Task.isCancelled else { break }

            while isPauseRequested && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard !Task.isCancelled else { break }

            currentWave = waveIdx + 1
            let waveSessions = sessions.filter { $0.waveIndex == waveIdx }
            log(.phase, "Wave \(waveIdx + 1)/\(waveCount) — \(waveSessions.count) paired sessions")

            await withTaskGroup(of: Void.self) { group in
                for session in waveSessions {
                    group.addTask { @MainActor in
                        await self.executePairedSession(
                            session,
                            joeFlow: joeFlow,
                            ignitionFlow: ignitionFlow
                        )
                    }
                }
            }

            let waveSucceeded = waveSessions.filter { $0.phase == .succeeded }.count
            let waveFailed = waveSessions.filter { $0.phase == .failed }.count
            log(.result, "Wave \(waveIdx + 1) complete — \(waveSucceeded) succeeded, \(waveFailed) failed")

            if waveIdx < waveCount - 1 && !Task.isCancelled {
                let delay = settings.interWaveDelaySeconds
                log(.phase, "Inter-wave delay: \(String(format: "%.1f", delay))s")
                try? await Task.sleep(for: .seconds(delay))
            }
        }

        if !Task.isCancelled {
            state = .completed
            log(.result, "Run complete — \(succeededCount)/\(sessions.count) succeeded, \(failedCount) failed")
        }

        backgroundService.endBackgroundTask(identifier: "sitchomatic.engine")
    }

    private func executePairedSession(
        _ session: ConcurrentSession,
        joeFlow: @escaping @Sendable @MainActor (PlaywrightPage, LoginCredential, SpeedMode) async throws -> DualLoginOutcome,
        ignitionFlow: @escaping @Sendable @MainActor (PlaywrightPage, LoginCredential, SpeedMode) async throws -> DualLoginOutcome
    ) async {
        session.updatePhase(.launching)

        let result = await orchestrator.executeDualLogin(
            credential: session.credential,
            joeURL: settings.joeURL,
            ignitionURL: settings.ignitionURL,
            joeFlow: joeFlow,
            ignitionFlow: ignitionFlow
        )

        session.updateProxy(result.proxyUsed)
        session.setDualResult(result)

        if let joeScreen = result.joeScreenshot { session.setJoeScreenshot(joeScreen) }
        if let ignScreen = result.ignitionScreenshot { session.setIgnitionScreenshot(ignScreen) }

        switch result.outcome {
        case .success:
            session.updatePhase(.succeeded)
        case .permDisabled, .tempDisabled, .networkError, .crashed, .unsure:
            session.setError(result.errorMessage ?? result.outcome.rawValue)
            session.updatePhase(.failed)
        }

        session.log(.result, "Dual result: \(result.outcome.rawValue) (joe: \(result.joeOutcome.rawValue), ignition: \(result.ignitionOutcome.rawValue), \(String(format: "%.1f", result.duration))s)")
    }

    private func log(_ category: SessionLogLine.Category, _ message: String) {
        engineLog.append(SessionLogLine(timestamp: Date(), category: category, message: message))
        logger.log("[Engine] \(message)", category: .automation, level: category == .error ? .error : .info)
    }
}
