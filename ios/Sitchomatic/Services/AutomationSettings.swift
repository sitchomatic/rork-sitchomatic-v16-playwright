import Foundation

@Observable
@MainActor
final class AutomationSettings {
    static let shared = AutomationSettings()

    var speedMode: SpeedMode = .balanced
    var maxConcurrentPairs: Int = 6
    var autoRetryOnFailure: Bool = true
    var maxRetryAttempts: Int = 3
    var captureScreenshotsOnFailure: Bool = true
    var enableTracing: Bool = true
    var interWaveDelaySeconds: Double = 2.0
    var joeURL: String = AutomationSite.joe.defaultLoginURL
    var ignitionURL: String = AutomationSite.ignition.defaultLoginURL
    var availableSites: [AutomationSite] { AutomationSite.allCases }
    var stealthEnabled: Bool = true
    var fingerprintRotation: Bool = true

    private let persistenceKey = "sitchomatic.v16.automationSettings"

    private init() {
        load()
        applyDefaultURLsIfNeeded()
    }

    func save() {
        applyDefaultURLsIfNeeded()
        let dict: [String: Any] = [
            "speedMode": speedMode.rawValue,
            "maxConcurrentPairs": maxConcurrentPairs,
            "autoRetryOnFailure": autoRetryOnFailure,
            "maxRetryAttempts": maxRetryAttempts,
            "captureScreenshotsOnFailure": captureScreenshotsOnFailure,
            "enableTracing": enableTracing,
            "interWaveDelaySeconds": interWaveDelaySeconds,
            "joeURL": joeURL,
            "ignitionURL": ignitionURL,
            "stealthEnabled": stealthEnabled,
            "fingerprintRotation": fingerprintRotation
        ]
        UserDefaults.standard.set(dict, forKey: persistenceKey)
    }

    func loginURL(for site: AutomationSite) -> String {
        switch site {
        case .joe:
            normalizedURL(joeURL, fallback: .joe)
        case .ignition:
            normalizedURL(ignitionURL, fallback: .ignition)
        }
    }

    func setLoginURL(_ value: String, for site: AutomationSite) {
        switch site {
        case .joe:
            joeURL = normalizedURL(value, fallback: .joe)
        case .ignition:
            ignitionURL = normalizedURL(value, fallback: .ignition)
        }
    }

    func resetLoginURLsToDefaults() {
        joeURL = AutomationSite.joe.defaultLoginURL
        ignitionURL = AutomationSite.ignition.defaultLoginURL
        save()
    }

    private func load() {
        guard let dict = UserDefaults.standard.dictionary(forKey: persistenceKey) else { return }
        if let raw = dict["speedMode"] as? String, let mode = SpeedMode(rawValue: raw) { speedMode = mode }
        if let val = dict["maxConcurrentPairs"] as? Int { maxConcurrentPairs = val }
        if let val = dict["autoRetryOnFailure"] as? Bool { autoRetryOnFailure = val }
        if let val = dict["maxRetryAttempts"] as? Int { maxRetryAttempts = val }
        if let val = dict["captureScreenshotsOnFailure"] as? Bool { captureScreenshotsOnFailure = val }
        if let val = dict["enableTracing"] as? Bool { enableTracing = val }
        if let val = dict["interWaveDelaySeconds"] as? Double { interWaveDelaySeconds = val }
        if let val = dict["joeURL"] as? String { joeURL = val }
        if let val = dict["ignitionURL"] as? String { ignitionURL = val }
        if let val = dict["stealthEnabled"] as? Bool { stealthEnabled = val }
        if let val = dict["fingerprintRotation"] as? Bool { fingerprintRotation = val }
    }

    private func applyDefaultURLsIfNeeded() {
        joeURL = normalizedURL(joeURL, fallback: .joe)
        ignitionURL = normalizedURL(ignitionURL, fallback: .ignition)
    }

    private func normalizedURL(_ value: String, fallback site: AutomationSite) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? site.defaultLoginURL : trimmedValue
    }
}
