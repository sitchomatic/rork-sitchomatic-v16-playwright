import Foundation

nonisolated struct ProxyConfig: Sendable {
    let host: String
    let port: Int
    let username: String?
    let password: String?

    init(host: String, port: Int, username: String? = nil, password: String? = nil) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
    }

    var displayString: String {
        if let username {
            return "\(username)@\(host):\(port)"
        }
        return "\(host):\(port)"
    }

    var hasAuth: Bool {
        username != nil && password != nil
    }
}
