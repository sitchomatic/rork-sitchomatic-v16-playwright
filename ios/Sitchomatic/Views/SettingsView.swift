import SwiftUI

struct SettingsView: View {
    let onLogout: () -> Void

    @State private var settings = AutomationSettings.shared
    @State private var networkManager = SimpleNetworkManager.shared
    @State private var socks5Input: String = ""
    @State private var showClearConfirm: Bool = false

    var body: some View {
        Form {
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

                VStack(alignment: .leading, spacing: 4) {
                    Text("Typing: \(settings.speedMode.typingDelayMs)ms | Action: \(settings.speedMode.actionDelayMs)ms | Post-Submit: \(settings.speedMode.postSubmitWaitMs)ms")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
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

            Section("URLs") {
                TextField("Joe URL", text: $settings.joeURL)
                    .font(.system(size: 13, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("Ignition URL", text: $settings.ignitionURL)
                    .font(.system(size: 13, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
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
                    Text("Permanent Dual Mode | iOS 26+")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: settings.speedMode) { _, _ in settings.save() }
        .onChange(of: settings.maxConcurrentPairs) { _, _ in settings.save() }
        .onChange(of: settings.autoRetryOnFailure) { _, _ in settings.save() }
        .onChange(of: settings.maxRetryAttempts) { _, _ in settings.save() }
        .onChange(of: settings.enableTracing) { _, _ in settings.save() }
        .onChange(of: settings.captureScreenshotsOnFailure) { _, _ in settings.save() }
        .onChange(of: settings.stealthEnabled) { _, _ in settings.save() }
        .onChange(of: settings.fingerprintRotation) { _, _ in settings.save() }
        .alert("Clear All Data?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                PersistenceService.shared.clearAll()
                PersistentFileStorageService.shared.purgeAll()
            }
        } message: {
            Text("This will delete all credentials, attempts, and stored files.")
        }
    }
}
