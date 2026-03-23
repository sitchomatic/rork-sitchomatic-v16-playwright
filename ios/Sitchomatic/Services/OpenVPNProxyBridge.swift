import Foundation
import Network
import Observation

@Observable
@MainActor
class OpenVPNProxyBridge {
    static let shared = OpenVPNProxyBridge()

    private(set) var isActive: Bool = false
    private(set) var statusMessage: String = "Stopped"

    private let logger = DebugLogger.shared

    func start(proxy: ProxyConfig) {
        isActive = true
        statusMessage = "Active via \(proxy.displayString)"
        logger.log("OpenVPNBridge: started with \(proxy.displayString)", category: .vpn, level: .info)
    }

    func stop() {
        isActive = false
        statusMessage = "Stopped"
        logger.log("OpenVPNBridge: stopped", category: .vpn, level: .info)
    }
}

@MainActor
class OpenVPNSOCKS5Handler {
    let id: UUID
    private let clientConnection: NWConnection
    private let queue: DispatchQueue
    private weak var server: LocalProxyServer?
    private let logger = DebugLogger.shared
    private var isCancelled: Bool = false

    init(id: UUID, clientConnection: NWConnection, queue: DispatchQueue, server: LocalProxyServer) {
        self.id = id
        self.clientConnection = clientConnection
        self.queue = queue
        self.server = server
    }

    func start() {
        clientConnection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self, !self.isCancelled else { return }
                if case .ready = state {
                    self.logger.log("OpenVPNSOCKS5: connection ready", category: .vpn, level: .debug)
                }
            }
        }
        clientConnection.start(queue: queue)
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        clientConnection.cancel()
        server?.tunnelConnectionFinished(id: id)
    }
}
