import SwiftUI

struct SettingsView: View {
    let onLogout: () -> Void

    @State private var settings = AutomationSettings.shared
    @State private var networkManager = SimpleNetworkManager.shared
    @State private var showClearConfirm: Bool = false
    @State private var wireGuardAccessKey: String = ""
    @State private var wireGuardKeyError: String?

    var body: some View {
        Form {
            Section("WireGuard") {
                SecureField("Single access key", text: $wireGuardAccessKey)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack {
                    Text("Status")
                    Spacer()
                    Label(hasStoredWireGuardAccessKey ? "Configured" : "Missing", systemImage: hasStoredWireGuardAccessKey ? "lock.shield.fill" : "shield.slash.fill")
                        .foregroundStyle(hasStoredWireGuardAccessKey ? .green : .secondary)
                        .labelStyle(.titleAndIcon)
                }

                Button("Save Securely") {
                    saveWireGuardAccessKey()
                }
                .disabled(trimmedWireGuardAccessKey.isEmpty)

                if hasStoredWireGuardAccessKey {
                    Button("Clear Stored Key", role: .destructive) {
                        clearWireGuardAccessKey()
                    }
                }

                Text("A single access key is kept in the device Keychain and reused across WireGuard tunnel sessions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let wireGuardKeyError {
                    Text(wireGuardKeyError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Speed Mode") {
                Picker("Preset", selection: $settings.speedMode) {
                    ForEach(SpeedMode.allCases, id: \.self) { mode in
                        HStack {
                            Image(systemName: mode.iconName)
                            VStack(alignment: .leading) {
                                Text(mode.displayName)
                                Text(mode.description)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.inline)

                Text("Typing: \(settings.speedMode.typingDelayMs)ms | Action: \(settings.speedMode.actionDelayMs)ms | Post-Submit: \(settings.speedMode.postSubmitWaitMs)ms")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Section("Concurrency") {
                Stepper("Max Concurrent Pairs: \(settings.maxConcurrentPairs)", value: $settings.maxConcurrentPairs, in: 1...12)
                Stepper("Max Retry Attempts: \(settings.maxRetryAttempts)", value: $settings.maxRetryAttempts, in: 0...10)
                Toggle("Auto-Retry on Failure", isOn: $settings.autoRetryOnFailure)
            }

            Section("Debugging") {
                Toggle("Enable Tracing", isOn: $settings.enableTracing)
                Toggle("Screenshots on Failure", isOn: $settings.captureScreenshotsOnFailure)
                Toggle("Stealth Mode", isOn: $settings.stealthEnabled)
                Toggle("Fingerprint Rotation", isOn: $settings.fingerprintRotation)
            }

            Section("Site URLs") {
                ForEach(settings.availableSites) { site in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(site.displayName)
                            .font(.subheadline.weight(.semibold))

                        TextField(site.defaultLoginURL, text: siteURLBinding(for: site))
                            .font(.system(size: 13, design: .monospaced))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Text(primarySelectorSummary(for: site))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                Button("Reset Default URLs") {
                    settings.resetLoginURLsToDefaults()
                }
            }

            Section("Network") {
                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: networkManager.connectionStatus.iconName)
                        Text(networkManager.connectionStatus.displayName)
                    }
                    .foregroundStyle(networkManager.connectionStatus == .connected ? .green : .red)
                }

                HStack {
                    Text("Proxies")
                    Spacer()
                    Text("\(networkManager.proxyCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Access Key")
                    Spacer()
                    Text(hasStoredWireGuardAccessKey ? "Single-Key Ready" : "Not Set")
                        .foregroundStyle(hasStoredWireGuardAccessKey ? .green : .secondary)
                }

                if networkManager.connectionStatus == .disconnected {
                    Button("Connect") {
                        Task { await networkManager.connect() }
                    }
                } else {
                    Button("Disconnect") {
                        networkManager.disconnect()
                    }
                    .foregroundStyle(.red)
                }
            }

            Section("Storage") {
                HStack {
                    Text("Storage Used")
                    Spacer()
                    Text(String(format: "%.1f MB", PersistentFileStorageService.shared.storageSizeMB))
                        .foregroundStyle(.secondary)
                }

                Button("Clear All Data", role: .destructive) {
                    showClearConfirm = true
                }
            }

            Section {
                Button("Logout", role: .destructive) {
                    onLogout()
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sitchomatic v16 Playwright Edition")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                    Text("Permanent Dual Mode | Site profiles ready for expansion")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .task {
            loadStoredWireGuardAccessKey()
        }
        .onChange(of: settings.speedMode) { _, _ in settings.save() }
        .onChange(of: settings.maxConcurrentPairs) { _, _ in settings.save() }
        .onChange(of: settings.autoRetryOnFailure) { _, _ in settings.save() }
        .onChange(of: settings.maxRetryAttempts) { _, _ in settings.save() }
        .onChange(of: settings.enableTracing) { _, _ in settings.save() }
        .onChange(of: settings.captureScreenshotsOnFailure) { _, _ in settings.save() }
        .onChange(of: settings.stealthEnabled) { _, _ in settings.save() }
        .onChange(of: settings.fingerprintRotation) { _, _ in settings.save() }
        .onChange(of: settings.joeURL) { _, _ in settings.save() }
        .onChange(of: settings.ignitionURL) { _, _ in settings.save() }
        .alert("Clear All Data?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                PersistenceService.shared.clearAll()
                PersistentFileStorageService.shared.purgeAll()
            }
        } message: {
            Text("This will delete all credentials, attempts, and stored files.")
        }
    }

    private var trimmedWireGuardAccessKey: String {
        wireGuardAccessKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasStoredWireGuardAccessKey: Bool {
        !trimmedWireGuardAccessKey.isEmpty
    }

    private func loadStoredWireGuardAccessKey() {
        do {
            wireGuardAccessKey = try WireGuardAccessKeyStore.load() ?? ""
            wireGuardKeyError = nil
        } catch {
            wireGuardAccessKey = ""
            wireGuardKeyError = "Unable to read the stored access key"
        }
    }

    private func saveWireGuardAccessKey() {
        do {
            try WireGuardAccessKeyStore.save(trimmedWireGuardAccessKey)
            wireGuardAccessKey = trimmedWireGuardAccessKey
            wireGuardKeyError = nil
        } catch {
            wireGuardKeyError = "Unable to save the access key securely"
        }
    }

    private func clearWireGuardAccessKey() {
        do {
            try WireGuardAccessKeyStore.delete()
            wireGuardAccessKey = ""
            wireGuardKeyError = nil
        } catch {
            wireGuardKeyError = "Unable to clear the stored access key"
        }
    }

    private func siteURLBinding(for site: AutomationSite) -> Binding<String> {
        Binding(
            get: { settings.loginURL(for: site) },
            set: { settings.setLoginURL($0, for: site) }
        )
    }

    private func primarySelectorSummary(for site: AutomationSite) -> String {
        let usernameSelector: String = site.usernameSelectors.first ?? "n/a"
        let passwordSelector: String = site.passwordSelectors.first ?? "n/a"
        let submitSelector: String = site.submitSelectors.first ?? "n/a"
        return "Selectors: \(usernameSelector) • \(passwordSelector) • \(submitSelector)"
    }
}
