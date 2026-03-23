import Foundation
import Observation

@Observable
@MainActor
class NordVPNService {
    static let shared = NordVPNService()

    private(set) var serviceUsername: String = ""
    private(set) var servicePassword: String = ""
    private(set) var privateKey: String = ""
    private(set) var isConfigured: Bool = false

    private let usernameKey = "sitchomatic.nord.serviceUsername"
    private let passwordKey = "sitchomatic.nord.servicePassword"
    private let privateKeyKey = "sitchomatic.nord.privateKey"

    var hasServiceCredentials: Bool {
        !serviceUsername.isEmpty && !servicePassword.isEmpty
    }

    private init() {
        load()
    }

    func configure(username: String, password: String, privateKey: String) {
        self.serviceUsername = username
        self.servicePassword = password
        self.privateKey = privateKey
        self.isConfigured = !username.isEmpty && !privateKey.isEmpty
        save()
    }

    func clearCredentials() {
        serviceUsername = ""
        servicePassword = ""
        privateKey = ""
        isConfigured = false
        UserDefaults.standard.removeObject(forKey: usernameKey)
        UserDefaults.standard.removeObject(forKey: passwordKey)
        UserDefaults.standard.removeObject(forKey: privateKeyKey)
    }

    private func save() {
        UserDefaults.standard.set(serviceUsername, forKey: usernameKey)
        UserDefaults.standard.set(servicePassword, forKey: passwordKey)
        UserDefaults.standard.set(privateKey, forKey: privateKeyKey)
    }

    private func load() {
        serviceUsername = UserDefaults.standard.string(forKey: usernameKey) ?? ""
        servicePassword = UserDefaults.standard.string(forKey: passwordKey) ?? ""
        privateKey = UserDefaults.standard.string(forKey: privateKeyKey) ?? ""
        isConfigured = !serviceUsername.isEmpty && !privateKey.isEmpty
    }
}

nonisolated struct NordLynxAPIService: Sendable {
    func fetchRecommendations(countryId: Int, technology: String, limit: Int) async throws -> [NordVPNServer] {
        var components = URLComponents(string: "https://api.nordvpn.com/v1/servers/recommendations")
        components?.queryItems = [
            URLQueryItem(name: "filters[servers_technologies][identifier]", value: technology),
            URLQueryItem(name: "filters[country_id]", value: "\(countryId)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        guard let url = components?.url else { return [] }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

        return try JSONDecoder().decode([NordVPNServer].self, from: data)
    }
}
