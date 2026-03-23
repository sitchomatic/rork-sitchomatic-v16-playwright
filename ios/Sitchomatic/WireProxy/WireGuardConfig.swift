import Foundation

nonisolated struct WireGuardConfig: Sendable {
    let fileName: String
    let interfaceAddress: String
    let interfacePrivateKey: String
    let interfaceDNS: String
    let interfaceMTU: Int?
    let peerPublicKey: String
    let peerPreSharedKey: String?
    let peerEndpoint: String
    let peerAllowedIPs: String
    let peerPersistentKeepalive: Int?
    let rawContent: String

    var serverName: String {
        let name = fileName.replacingOccurrences(of: ".conf", with: "")
        return name.isEmpty ? endpointHost : name
    }

    var endpointHost: String {
        let parts = peerEndpoint.split(separator: ":")
        return parts.count >= 2 ? parts.dropLast().joined(separator: ":") : peerEndpoint
    }

    var endpointPort: UInt16 {
        let parts = peerEndpoint.split(separator: ":")
        guard let last = parts.last, let port = UInt16(last) else { return 51820 }
        return port
    }

    init(
        fileName: String = "",
        interfaceAddress: String = "10.5.0.2/32",
        interfacePrivateKey: String = "",
        interfaceDNS: String = "103.86.96.100, 103.86.99.100",
        interfaceMTU: Int? = nil,
        peerPublicKey: String = "",
        peerPreSharedKey: String? = nil,
        peerEndpoint: String = "",
        peerAllowedIPs: String = "0.0.0.0/0",
        peerPersistentKeepalive: Int? = 25,
        rawContent: String = ""
    ) {
        self.fileName = fileName
        self.interfaceAddress = interfaceAddress
        self.interfacePrivateKey = interfacePrivateKey
        self.interfaceDNS = interfaceDNS
        self.interfaceMTU = interfaceMTU
        self.peerPublicKey = peerPublicKey
        self.peerPreSharedKey = peerPreSharedKey
        self.peerEndpoint = peerEndpoint
        self.peerAllowedIPs = peerAllowedIPs
        self.peerPersistentKeepalive = peerPersistentKeepalive
        self.rawContent = rawContent
    }

    static func parse(from content: String, fileName: String = "") -> WireGuardConfig? {
        var address = ""
        var privateKey = ""
        var dns = "103.86.96.100, 103.86.99.100"
        var mtu: Int?
        var publicKey = ""
        var preSharedKey: String?
        var endpoint = ""
        var allowedIPs = "0.0.0.0/0"
        var keepalive: Int?

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            switch key {
            case "address": address = value
            case "privatekey": privateKey = value
            case "dns": dns = value
            case "mtu": mtu = Int(value)
            case "publickey": publicKey = value
            case "presharedkey": preSharedKey = value.isEmpty ? nil : value
            case "endpoint": endpoint = value
            case "allowedips": allowedIPs = value
            case "persistentkeepalive": keepalive = Int(value)
            default: break
            }
        }

        guard !privateKey.isEmpty, !publicKey.isEmpty, !endpoint.isEmpty else { return nil }

        return WireGuardConfig(
            fileName: fileName,
            interfaceAddress: address,
            interfacePrivateKey: privateKey,
            interfaceDNS: dns,
            interfaceMTU: mtu,
            peerPublicKey: publicKey,
            peerPreSharedKey: preSharedKey,
            peerEndpoint: endpoint,
            peerAllowedIPs: allowedIPs,
            peerPersistentKeepalive: keepalive,
            rawContent: content
        )
    }
}
