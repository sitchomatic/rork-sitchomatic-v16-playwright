import Foundation
import Network

@MainActor
class ProxyHealthMonitor {
    static let shared = ProxyHealthMonitor()

    private var healthCheckTimer: Timer?
    private var upstream: ProxyConfig?
    private var failoverCallback: (() -> Void)?
    private let logger = DebugLogger.shared
    private var consecutiveFailures: Int = 0
    private let failureThreshold: Int = 3

    func startMonitoring(upstream: ProxyConfig?, onFailover: @escaping () -> Void) {
        stopMonitoring()
        self.upstream = upstream
        self.failoverCallback = onFailover
        self.consecutiveFailures = 0

        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performHealthCheck()
            }
        }
    }

    func stopMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        failoverCallback = nil
    }

    func updateUpstream(_ proxy: ProxyConfig?) {
        upstream = proxy
        consecutiveFailures = 0
    }

    private func performHealthCheck() async {
        guard let upstream else { return }

        let reachable = await checkReachability(host: upstream.host, port: upstream.port)
        if reachable {
            consecutiveFailures = 0
        } else {
            consecutiveFailures += 1
            logger.log("ProxyHealth: upstream \(upstream.displayString) unreachable (\(consecutiveFailures)/\(failureThreshold))", category: .proxy, level: .warning)
            if consecutiveFailures >= failureThreshold {
                logger.log("ProxyHealth: triggering failover", category: .proxy, level: .error)
                failoverCallback?()
                consecutiveFailures = 0
            }
        }
    }

    nonisolated private func checkReachability(host: String, port: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            let endpoint = Network.NWEndpoint.hostPort(
                host: Network.NWEndpoint.Host(host),
                port: Network.NWEndpoint.Port(integerLiteral: UInt16(port))
            )
            let connection = Network.NWConnection(to: endpoint, using: .tcp)
            let queue = DispatchQueue(label: "proxy-health-check")
            var completed = false
            let lock = NSLock()

            func finish(_ result: Bool) {
                lock.lock()
                defer { lock.unlock() }
                guard !completed else { return }
                completed = true
                continuation.resume(returning: result)
            }

            let timeout = DispatchWorkItem { [weak connection] in
                connection?.cancel()
                finish(false)
            }
            queue.asyncAfter(deadline: .now() + 5, execute: timeout)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    timeout.cancel()
                    connection.cancel()
                    finish(true)
                case .failed, .cancelled:
                    timeout.cancel()
                    finish(false)
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }
}
