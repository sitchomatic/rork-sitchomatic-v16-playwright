import Foundation
import WebKit

nonisolated enum ConnectionStatus: String, Sendable {
    case connected
    case connecting
    case disconnected
    case error

    var displayName: String {
        switch self {
        case .connected: "Connected"
        case .connecting: "Connecting..."
        case .disconnected: "Disconnected"
        case .error: "Error"
        }
    }

    var iconName: String {
        switch self {
        case .connected: "wifi"
        case .connecting: "wifi.exclamationmark"
        case .disconnected: "wifi.slash"
        case .error: "exclamationmark.triangle"
        }
    }
}

nonisolated struct ProxyEndpoint: Sendable {
    let host: String
    let port: Int
}

nonisolated enum ActiveNetworkConfig: Sendable {
    case direct
    case socks5(host: String, port: Int)

    var label: String {
        switch self {
        case .direct: "Direct"
        case .socks5(let host, let port): "SOCKS5(\(host):\(port))"
        }
    }
}

@Observable
@MainActor
final class SimpleNetworkManager {
    static let shared = SimpleNetworkManager()

    private(set) var connectionStatus: ConnectionStatus = .disconnected
    private(set) var statusMessage: String = "Not connected"
    private(set) var proxyCount: Int = 0
    private(set) var currentNetworkConfig: ActiveNetworkConfig = .direct

    private var proxyEndpoints: [String: ProxyEndpoint] = [:]
    private var wireProxyBridges: [WireProxyBridge] = []
    private let logger = DebugLogger.shared
    private var socks5Proxies: [(host: String, port: Int)] = []
    private var currentIndex: Int = 0
    private var rotationTask: Task<Void, Never>?

    var quickStatusLine: String {
        "\(connectionStatus.displayName) | Proxies: \(proxyCount) | Config: \(currentNetworkConfig.label)"
    }

    private init() {}

    func connect() async {
        connectionStatus = .connecting
        statusMessage = "Connecting..."

        if !socks5Proxies.isEmpty {
            do {
                try await connectSOCKS5()
                connectionStatus = .connected
                statusMessage = "Connected via SOCKS5"
            } catch {
                connectionStatus = .error
                statusMessage = "Connection failed: \(error.localizedDescription)"
            }
        } else {
            connectionStatus = .connected
            statusMessage = "Connected (direct)"
            currentNetworkConfig = .direct
        }
    }

    func disconnect() {
        for bridge in wireProxyBridges {
            bridge.disconnect()
        }
        wireProxyBridges.removeAll()
        proxyEndpoints.removeAll()
        proxyCount = 0
        connectionStatus = .disconnected
        statusMessage = "Disconnected"
        currentNetworkConfig = .direct
        rotationTask?.cancel()
        rotationTask = nil
    }

    func proxyEndpoint(forSessionID sessionID: String) -> ProxyEndpoint? {
        if let cached = proxyEndpoints[sessionID] {
            return cached
        }

        guard !wireProxyBridges.isEmpty else { return nil }

        let bridge = wireProxyBridges[abs(sessionID.hashValue) % wireProxyBridges.count]
        let endpoint = ProxyEndpoint(host: "127.0.0.1", port: bridge.localPort)
        proxyEndpoints[sessionID] = endpoint
        return endpoint
    }

    func networkConfiguration(forSessionID sessionID: String) -> ActiveNetworkConfig {
        if let endpoint = proxyEndpoint(forSessionID: sessionID) {
            return .socks5(host: endpoint.host, port: endpoint.port)
        }
        return currentNetworkConfig
    }

    func clearProxyEndpoint(forSessionID sessionID: String) {
        proxyEndpoints.removeValue(forKey: sessionID)
    }

    func configureSOCKS5Proxies(_ proxies: [(host: String, port: Int)]) {
        socks5Proxies = proxies
        logger.log("Configured \(proxies.count) SOCKS5 proxies", category: .network, level: .info)
    }

    func addWireProxyBridge(_ bridge: WireProxyBridge) {
        wireProxyBridges.append(bridge)
        proxyCount = wireProxyBridges.count
        logger.log("Added WireProxy bridge (total: \(proxyCount))", category: .network, level: .info)
    }

    func rotateToNextProxy() async {
        guard !wireProxyBridges.isEmpty else { return }
        currentIndex = (currentIndex + 1) % wireProxyBridges.count
        proxyEndpoints.removeAll()
        logger.log("Rotated to proxy index \(currentIndex)", category: .network, level: .debug)
    }

    private func connectSOCKS5() async throws {
        guard let first = socks5Proxies.first else { return }
        currentNetworkConfig = .socks5(host: first.host, port: first.port)
        proxyCount = socks5Proxies.count
    }
}
