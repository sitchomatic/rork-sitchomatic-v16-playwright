import Foundation
import Network

@MainActor
class ProxyConnectionPool {
    static let shared = ProxyConnectionPool()

    private var pool: [String: [NWConnection]] = [:]
    private let maxPoolSize: Int = 10
    private let logger = DebugLogger.shared

    func getConnection(host: String, port: UInt16) -> NWConnection? {
        let key = "\(host):\(port)"
        guard var connections = pool[key], !connections.isEmpty else { return nil }
        let conn = connections.removeFirst()
        pool[key] = connections
        return conn
    }

    func returnConnection(_ connection: NWConnection, host: String, port: UInt16) {
        let key = "\(host):\(port)"
        var connections = pool[key] ?? []
        guard connections.count < maxPoolSize else {
            connection.cancel()
            return
        }
        connections.append(connection)
        pool[key] = connections
    }

    func drainPool() {
        for (_, connections) in pool {
            for conn in connections {
                conn.cancel()
            }
        }
        pool.removeAll()
    }

    var totalPooled: Int {
        pool.values.reduce(0) { $0 + $1.count }
    }
}
