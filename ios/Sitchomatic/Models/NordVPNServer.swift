import Foundation

nonisolated struct NordVPNServer: Codable, Sendable {
    let id: Int
    let hostname: String
    let station: String
    let load: Int
    let status: String?
    let technologies: [NordTechnology]?

    var publicKey: String? {
        technologies?
            .first(where: { $0.identifier == "wireguard_udp" })?
            .metadata?
            .first(where: { $0.name == "public_key" })?
            .value
    }

    var hasOpenVPNTCP: Bool {
        technologies?.contains(where: { $0.identifier == "openvpn_tcp" }) ?? false
    }

    var hasOpenVPNUDP: Bool {
        technologies?.contains(where: { $0.identifier == "openvpn_udp" }) ?? false
    }

    nonisolated struct NordTechnology: Codable, Sendable {
        let id: Int?
        let identifier: String
        let metadata: [NordMetadata]?
    }

    nonisolated struct NordMetadata: Codable, Sendable {
        let name: String
        let value: String
    }
}
