import Foundation
import Network

@MainActor
class LocalProxyConnection {
    let id: UUID
    private let clientConnection: NWConnection
    private var upstreamConnection: NWConnection?
    private let upstream: ProxyConfig?
    private let queue: DispatchQueue
    private weak var server: LocalProxyServer?
    private let logger = DebugLogger.shared

    private var isCancelled: Bool = false
    private var bytesUploaded: UInt64 = 0
    private var bytesDownloaded: UInt64 = 0
    private var hadError: Bool = false
    private var targetHost: String = ""
    private var targetPort: UInt16 = 0
    private var timeoutWork: DispatchWorkItem?
    private let timeoutSeconds: TimeInterval

    init(
        id: UUID,
        clientConnection: NWConnection,
        upstream: ProxyConfig?,
        queue: DispatchQueue,
        server: LocalProxyServer,
        timeoutSeconds: TimeInterval
    ) {
        self.id = id
        self.clientConnection = clientConnection
        self.upstream = upstream
        self.queue = queue
        self.server = server
        self.timeoutSeconds = timeoutSeconds
    }

    func start() {
        startTimeout()

        clientConnection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self, !self.isCancelled else { return }
                switch state {
                case .ready:
                    self.readSOCKS5Greeting()
                case .failed:
                    self.finish(error: true, errorType: .connection)
                case .cancelled:
                    self.finish(error: false, errorType: .none)
                default:
                    break
                }
            }
        }
        clientConnection.start(queue: queue)
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        cancelTimeout()
        clientConnection.cancel()
        upstreamConnection?.cancel()
    }

    private func readSOCKS5Greeting() {
        server?.updateConnectionInfo(id: id, targetHost: "", targetPort: 0, state: .handshaking)

        clientConnection.receive(minimumIncompleteLength: 2, maximumLength: 257) { [weak self] data, _, _, error in
            Task { @MainActor [weak self] in
                guard let self, !self.isCancelled else { return }
                if error != nil { self.finish(error: true, errorType: .handshake); return }
                guard let data, data.count >= 2, data[0] == 0x05 else {
                    self.finish(error: true, errorType: .handshake)
                    return
                }

                let response = Data([0x05, 0x00])
                self.clientConnection.send(content: response, completion: .contentProcessed { [weak self] sendError in
                    Task { @MainActor [weak self] in
                        guard let self, !self.isCancelled else { return }
                        if sendError != nil { self.finish(error: true, errorType: .handshake); return }
                        self.readSOCKS5Request()
                    }
                })
            }
        }
    }

    private func readSOCKS5Request() {
        clientConnection.receive(minimumIncompleteLength: 4, maximumLength: 512) { [weak self] data, _, _, error in
            Task { @MainActor [weak self] in
                guard let self, !self.isCancelled else { return }
                if error != nil { self.finish(error: true, errorType: .handshake); return }
                guard let data, data.count >= 4, data[0] == 0x05, data[1] == 0x01 else {
                    self.sendSOCKS5Error(0x07)
                    return
                }

                let addressType = data[3]
                var host: String = ""
                var port: UInt16 = 0

                switch addressType {
                case 0x01:
                    guard data.count >= 10 else { self.finish(error: true, errorType: .handshake); return }
                    host = "\(data[4]).\(data[5]).\(data[6]).\(data[7])"
                    port = UInt16(data[8]) << 8 | UInt16(data[9])
                case 0x03:
                    guard data.count >= 5 else { self.finish(error: true, errorType: .handshake); return }
                    let domainLength = Int(data[4])
                    guard data.count >= 5 + domainLength + 2 else { self.finish(error: true, errorType: .handshake); return }
                    host = String(data: data[5..<(5 + domainLength)], encoding: .utf8) ?? ""
                    let portOffset = 5 + domainLength
                    port = UInt16(data[portOffset]) << 8 | UInt16(data[portOffset + 1])
                case 0x04:
                    guard data.count >= 22 else { self.finish(error: true, errorType: .handshake); return }
                    port = UInt16(data[20]) << 8 | UInt16(data[21])
                    host = "ipv6"
                default:
                    self.sendSOCKS5Error(0x08)
                    return
                }

                guard !host.isEmpty, port > 0 else {
                    self.sendSOCKS5Error(0x01)
                    return
                }

                self.targetHost = host
                self.targetPort = port
                self.server?.updateConnectionInfo(id: self.id, targetHost: host, targetPort: port, state: .handshaking)

                if let upstream = self.upstream {
                    self.connectViaUpstream(upstream, targetHost: host, targetPort: port, originalRequest: data)
                } else {
                    self.connectDirect(host: host, port: port)
                }
            }
        }
    }

    private func connectDirect(host: String, port: UInt16) {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port)
        )
        let connection = NWConnection(to: endpoint, using: .tcp)
        upstreamConnection = connection

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self, !self.isCancelled else { return }
                switch state {
                case .ready:
                    self.cancelTimeout()
                    self.sendSOCKS5Success()
                case .failed:
                    self.sendSOCKS5Error(0x05)
                default:
                    break
                }
            }
        }
        connection.start(queue: queue)
    }

    private func connectViaUpstream(_ upstream: ProxyConfig, targetHost: String, targetPort: UInt16, originalRequest: Data) {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(upstream.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(upstream.port))
        )
        let connection = NWConnection(to: endpoint, using: .tcp)
        upstreamConnection = connection

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self, !self.isCancelled else { return }
                switch state {
                case .ready:
                    self.performUpstreamSOCKS5Handshake(connection, targetHost: targetHost, targetPort: targetPort, upstream: upstream)
                case .failed:
                    self.sendSOCKS5Error(0x05)
                default:
                    break
                }
            }
        }
        connection.start(queue: queue)
    }

    private func performUpstreamSOCKS5Handshake(_ connection: NWConnection, targetHost: String, targetPort: UInt16, upstream: ProxyConfig) {
        let greeting: Data
        if upstream.hasAuth {
            greeting = Data([0x05, 0x02, 0x00, 0x02])
        } else {
            greeting = Data([0x05, 0x01, 0x00])
        }

        connection.send(content: greeting, completion: .contentProcessed { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self, !self.isCancelled else { return }
                if error != nil { self.sendSOCKS5Error(0x01); return }

                connection.receive(minimumIncompleteLength: 2, maximumLength: 16) { [weak self] data, _, _, recvError in
                    Task { @MainActor [weak self] in
                        guard let self, !self.isCancelled else { return }
                        if recvError != nil { self.sendSOCKS5Error(0x01); return }
                        guard let data, data.count >= 2, data[0] == 0x05 else {
                            self.sendSOCKS5Error(0x01)
                            return
                        }

                        let method = data[1]
                        if method == 0x02, let username = upstream.username, let password = upstream.password {
                            var authPacket = Data([0x01])
                            let uBytes = Array(username.utf8)
                            authPacket.append(UInt8(uBytes.count))
                            authPacket.append(contentsOf: uBytes)
                            let pBytes = Array(password.utf8)
                            authPacket.append(UInt8(pBytes.count))
                            authPacket.append(contentsOf: pBytes)

                            connection.send(content: authPacket, completion: .contentProcessed { [weak self] error in
                                Task { @MainActor [weak self] in
                                    guard let self, !self.isCancelled else { return }
                                    if error != nil { self.sendSOCKS5Error(0x01); return }

                                    connection.receive(minimumIncompleteLength: 2, maximumLength: 4) { [weak self] authData, _, _, authError in
                                        Task { @MainActor [weak self] in
                                            guard let self, !self.isCancelled else { return }
                                            if authError != nil || authData == nil || (authData?.count ?? 0) < 2 || authData?[1] != 0x00 {
                                                self.sendSOCKS5Error(0x01)
                                                return
                                            }
                                            self.sendUpstreamConnectRequest(connection, targetHost: targetHost, targetPort: targetPort)
                                        }
                                    }
                                }
                            })
                        } else if method == 0x00 {
                            self.sendUpstreamConnectRequest(connection, targetHost: targetHost, targetPort: targetPort)
                        } else {
                            self.sendSOCKS5Error(0x01)
                        }
                    }
                }
            }
        })
    }

    private func sendUpstreamConnectRequest(_ connection: NWConnection, targetHost: String, targetPort: UInt16) {
        var request = Data([0x05, 0x01, 0x00, 0x03])
        let hostBytes = Array(targetHost.utf8)
        request.append(UInt8(hostBytes.count))
        request.append(contentsOf: hostBytes)
        request.append(UInt8(targetPort >> 8))
        request.append(UInt8(targetPort & 0xFF))

        connection.send(content: request, completion: .contentProcessed { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self, !self.isCancelled else { return }
                if error != nil { self.sendSOCKS5Error(0x01); return }

                connection.receive(minimumIncompleteLength: 4, maximumLength: 512) { [weak self] data, _, _, recvError in
                    Task { @MainActor [weak self] in
                        guard let self, !self.isCancelled else { return }
                        if recvError != nil { self.sendSOCKS5Error(0x01); return }
                        guard let data, data.count >= 4, data[0] == 0x05, data[1] == 0x00 else {
                            self.sendSOCKS5Error(data?[1] ?? 0x01)
                            return
                        }
                        self.cancelTimeout()
                        self.sendSOCKS5Success()
                    }
                }
            }
        })
    }

    private func sendSOCKS5Success() {
        let response = Data([0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        clientConnection.send(content: response, completion: .contentProcessed { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self, !self.isCancelled else { return }
                if error != nil { self.finish(error: true, errorType: .handshake); return }
                self.server?.updateConnectionInfo(id: self.id, targetHost: self.targetHost, targetPort: self.targetPort, state: .relaying)
                self.startRelaying()
            }
        })
    }

    private func sendSOCKS5Error(_ rep: UInt8) {
        let response = Data([0x05, rep, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        clientConnection.send(content: response, completion: .contentProcessed { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.finish(error: true, errorType: .handshake)
            }
        })
    }

    private func startRelaying() {
        readFromClient()
        readFromUpstream()
    }

    private func readFromClient() {
        guard !isCancelled else { return }
        clientConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self, !self.isCancelled else { return }
                if let data, !data.isEmpty {
                    self.bytesUploaded += UInt64(data.count)
                    self.server?.updateConnectionBytes(id: self.id, bytes: self.bytesUploaded + self.bytesDownloaded)
                    self.upstreamConnection?.send(content: data, completion: .contentProcessed { [weak self] error in
                        Task { @MainActor [weak self] in
                            guard let self, !self.isCancelled else { return }
                            if error != nil { self.finish(error: true, errorType: .relay); return }
                            self.readFromClient()
                        }
                    })
                } else if isComplete || error != nil {
                    self.finish(error: error != nil, errorType: error != nil ? .relay : .none)
                } else {
                    self.readFromClient()
                }
            }
        }
    }

    private func readFromUpstream() {
        guard !isCancelled, let upstream = upstreamConnection else { return }
        upstream.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self, !self.isCancelled else { return }
                if let data, !data.isEmpty {
                    self.bytesDownloaded += UInt64(data.count)
                    self.server?.updateConnectionBytes(id: self.id, bytes: self.bytesUploaded + self.bytesDownloaded)
                    self.clientConnection.send(content: data, completion: .contentProcessed { [weak self] error in
                        Task { @MainActor [weak self] in
                            guard let self, !self.isCancelled else { return }
                            if error != nil { self.finish(error: true, errorType: .relay); return }
                            self.readFromUpstream()
                        }
                    })
                } else if isComplete || error != nil {
                    self.finish(error: error != nil, errorType: error != nil ? .relay : .none)
                } else {
                    self.readFromUpstream()
                }
            }
        }
    }

    private func finish(error: Bool, errorType: ConnectionErrorType) {
        guard !isCancelled else { return }
        isCancelled = true
        cancelTimeout()
        hadError = error || hadError
        clientConnection.cancel()
        upstreamConnection?.cancel()

        let totalBytes = bytesUploaded + bytesDownloaded
        server?.connectionFinished(
            id: id,
            bytesRelayed: totalBytes,
            bytesUp: bytesUploaded,
            bytesDown: bytesDownloaded,
            hadError: hadError,
            errorType: errorType,
            targetHost: targetHost
        )
    }

    private func startTimeout() {
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, !self.isCancelled else { return }
                self.finish(error: true, errorType: .connection)
            }
        }
        timeoutWork = work
        queue.asyncAfter(deadline: .now() + timeoutSeconds, execute: work)
    }

    private func cancelTimeout() {
        timeoutWork?.cancel()
        timeoutWork = nil
    }
}
