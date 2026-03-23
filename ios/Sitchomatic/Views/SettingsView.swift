import SwiftUI

struct SettingsView: View {
    @State private var settings = AutomationSettings.shared
    @State private var networkManager = SimpleNetworkManager.shared
    @State private var showClearConfirm: Bool = false
    @State private var showResetNetworkConfirm: Bool = false
    @State private var showResetMemoryConfirm: Bool = false
    @State private var showResetWebViewConfirm: Bool = false
    @State private var wireGuardAccessKey: String = ""
    @State private var wireGuardKeyError: String?
    @State private var isMeasuringLatency: Bool = false
    @State private var isRunningHealthCheck: Bool = false

    var body: some View {
        Form {
            SettingsWireGuardSection(
                wireGuardAccessKey: $wireGuardAccessKey,
                wireGuardKeyError: $wireGuardKeyError
            )
            SettingsSpeedModeSection(settings: settings)
            SettingsConcurrencySection(settings: settings)
            SettingsTimingOverridesSection(settings: settings)
            SettingsWebViewPoolSection(
                settings: settings,
                showResetConfirm: $showResetWebViewConfirm
            )
            SettingsStealthSection(settings: settings)
            SettingsMemoryProtectionSection(
                settings: settings,
                showResetConfirm: $showResetMemoryConfirm
            )
            SettingsNetworkConnectionSection(
                networkManager: networkManager,
                hasStoredKey: hasStoredWireGuardAccessKey,
                isMeasuringLatency: $isMeasuringLatency
            )
            SettingsNetworkConfigSection(
                settings: settings,
                networkManager: networkManager,
                showResetConfirm: $showResetNetworkConfirm
            )
            SettingsProxyManagementSection(
                settings: settings,
                networkManager: networkManager,
                isRunningHealthCheck: $isRunningHealthCheck
            )
            SettingsDNSSection(settings: settings)
            SettingsLoggingSection(settings: settings)
            SettingsSiteURLsSection(settings: settings)
            settingsStorageSection
            settingsAboutSection
        }
        .navigationTitle("Settings")
        .task { loadStoredWireGuardAccessKey() }
        .alert("Clear All Data?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                PersistenceService.shared.clearAll()
                PersistentFileStorageService.shared.purgeAll()
            }
        } message: {
            Text("This will delete all credentials, attempts, and stored files.")
        }
        .alert("Reset Network Settings?", isPresented: $showResetNetworkConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { settings.resetNetworkDefaults() }
        } message: {
            Text("Timeouts, DNS, isolation, and reconnect settings will return to defaults.")
        }
        .alert("Reset Memory Thresholds?", isPresented: $showResetMemoryConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { settings.resetMemoryDefaults() }
        } message: {
            Text("All memory thresholds and cooldown settings will return to defaults.")
        }
        .alert("Reset WebView Settings?", isPresented: $showResetWebViewConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { settings.resetWebViewDefaults() }
        } message: {
            Text("Hard cap, stale timeout, pre-warm, and wipe settings will return to defaults.")
        }
    }

    private var settingsStorageSection: some View {
        Section {
            HStack {
                Text("Storage Used")
                Spacer()
                Text(String(format: "%.1f MB", PersistentFileStorageService.shared.storageSizeMB))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("WebView Lifetime Budget")
                Spacer()
                Text(WebViewLifetimeBudgetService.shared.diagnosticSummary)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Button("Clear All Data", role: .destructive) {
                showClearConfirm = true
            }
        } header: {
            Label("Storage", systemImage: "externaldrive")
        }
    }

    private var settingsAboutSection: some View {
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

    private var hasStoredWireGuardAccessKey: Bool {
        !wireGuardAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
}

// MARK: - WireGuard

struct SettingsWireGuardSection: View {
    @Binding var wireGuardAccessKey: String
    @Binding var wireGuardKeyError: String?

    private var trimmed: String {
        wireGuardAccessKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasKey: Bool { !trimmed.isEmpty }

    var body: some View {
        Section {
            SecureField("Single access key", text: $wireGuardAccessKey)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack {
                Text("Status")
                Spacer()
                Label(hasKey ? "Configured" : "Missing", systemImage: hasKey ? "lock.shield.fill" : "shield.slash.fill")
                    .foregroundStyle(hasKey ? .green : .secondary)
                    .labelStyle(.titleAndIcon)
            }

            Button("Save Securely") { saveKey() }
                .disabled(trimmed.isEmpty)

            if hasKey {
                Button("Clear Stored Key", role: .destructive) { clearKey() }
            }

            if let wireGuardKeyError {
                Text(wireGuardKeyError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Label("WireGuard", systemImage: "lock.shield")
        } footer: {
            Text("A single access key is kept in the device Keychain and reused across WireGuard tunnel sessions.")
        }
    }

    private func saveKey() {
        do {
            try WireGuardAccessKeyStore.save(trimmed)
            wireGuardAccessKey = trimmed
            wireGuardKeyError = nil
        } catch {
            wireGuardKeyError = "Unable to save the access key securely"
        }
    }

    private func clearKey() {
        do {
            try WireGuardAccessKeyStore.delete()
            wireGuardAccessKey = ""
            wireGuardKeyError = nil
        } catch {
            wireGuardKeyError = "Unable to clear the stored access key"
        }
    }
}

// MARK: - Speed Mode

struct SettingsSpeedModeSection: View {
    @Bindable var settings: AutomationSettings

    var body: some View {
        Section {
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
        } header: {
            Label("Speed Mode", systemImage: "gauge.with.dots.needle.50percent")
        }
        .onChange(of: settings.speedMode) { _, _ in settings.save() }
    }
}

// MARK: - Concurrency

struct SettingsConcurrencySection: View {
    @Bindable var settings: AutomationSettings

    var body: some View {
        Section {
            Stepper("Max Concurrent Pairs: \(settings.maxConcurrentPairs)", value: $settings.maxConcurrentPairs, in: 1...12)
            Stepper("Max Retry Attempts: \(settings.maxRetryAttempts)", value: $settings.maxRetryAttempts, in: 0...10)
            Toggle("Auto-Retry on Failure", isOn: $settings.autoRetryOnFailure)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Inter-Wave Delay")
                    Spacer()
                    Text(String(format: "%.1fs", settings.interWaveDelaySeconds))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.interWaveDelaySeconds, in: 0...15, step: 0.5)
            }
        } header: {
            Label("Concurrency", systemImage: "arrow.triangle.branch")
        }
        .onChange(of: settings.maxConcurrentPairs) { _, _ in settings.save() }
        .onChange(of: settings.maxRetryAttempts) { _, _ in settings.save() }
        .onChange(of: settings.autoRetryOnFailure) { _, _ in settings.save() }
        .onChange(of: settings.interWaveDelaySeconds) { _, _ in settings.save() }
    }
}

// MARK: - Timing Overrides

struct SettingsTimingOverridesSection: View {
    @Bindable var settings: AutomationSettings

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Navigation Timeout")
                    Spacer()
                    Text(settings.navigationTimeoutOverride > 0 ? String(format: "%.0fs", settings.navigationTimeoutOverride) : "Auto (\(String(format: "%.0fs", settings.speedMode.navigationTimeoutSeconds)))")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.navigationTimeoutOverride, in: 0...120, step: 5)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Selector Timeout")
                    Spacer()
                    Text(settings.selectorTimeoutOverride > 0 ? String(format: "%.0fs", settings.selectorTimeoutOverride) : "Auto (\(String(format: "%.0fs", settings.speedMode.selectorTimeoutSeconds)))")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.selectorTimeoutOverride, in: 0...60, step: 1)
            }
        } header: {
            Label("Timing Overrides", systemImage: "timer")
        } footer: {
            Text("Set to 0 to use speed mode defaults. Override for sites with slow load times.")
        }
        .onChange(of: settings.navigationTimeoutOverride) { _, _ in settings.save() }
        .onChange(of: settings.selectorTimeoutOverride) { _, _ in settings.save() }
    }
}

// MARK: - WebView Pool

struct SettingsWebViewPoolSection: View {
    @Bindable var settings: AutomationSettings
    @Binding var showResetConfirm: Bool

    var body: some View {
        Section {
            Stepper("Hard Cap: \(settings.webViewHardCap)", value: $settings.webViewHardCap, in: 4...48)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Stale Session Timeout")
                    Spacer()
                    Text("\(settings.staleSessionTimeoutSeconds)s")
                        .foregroundStyle(.secondary)
                }
                Stepper("", value: $settings.staleSessionTimeoutSeconds, in: 60...900, step: 30)
                    .labelsHidden()
            }

            Stepper("Pre-Warm Count: \(settings.preWarmCount)", value: $settings.preWarmCount, in: 0...6)
            Toggle("Wipe Data on Release", isOn: $settings.wipeDataOnRelease)
            Toggle("User Agent Rotation", isOn: $settings.userAgentRotation)

            HStack {
                Text("Pool Status")
                Spacer()
                Text(WebViewPool.shared.diagnosticSummary)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Button("Reset WebView Defaults", role: .destructive) {
                showResetConfirm = true
            }
        } header: {
            Label("WebView Pool", systemImage: "square.stack.3d.up")
        } footer: {
            Text("Controls WebView lifecycle, isolation, and memory footprint. Lower hard cap to reduce memory pressure.")
        }
        .onChange(of: settings.webViewHardCap) { _, _ in settings.save() }
        .onChange(of: settings.staleSessionTimeoutSeconds) { _, _ in settings.save() }
        .onChange(of: settings.preWarmCount) { _, _ in settings.save() }
        .onChange(of: settings.wipeDataOnRelease) { _, _ in settings.save() }
        .onChange(of: settings.userAgentRotation) { _, _ in settings.save() }
    }
}

// MARK: - Stealth & Debugging

struct SettingsStealthSection: View {
    @Bindable var settings: AutomationSettings

    var body: some View {
        Section {
            Toggle("Stealth Mode", isOn: $settings.stealthEnabled)
            Toggle("Fingerprint Rotation", isOn: $settings.fingerprintRotation)
            Toggle("Enable Tracing", isOn: $settings.enableTracing)
            Toggle("Screenshots on Failure", isOn: $settings.captureScreenshotsOnFailure)
        } header: {
            Label("Stealth & Debugging", systemImage: "eye.slash")
        }
        .onChange(of: settings.stealthEnabled) { _, _ in settings.save() }
        .onChange(of: settings.fingerprintRotation) { _, _ in settings.save() }
        .onChange(of: settings.enableTracing) { _, _ in settings.save() }
        .onChange(of: settings.captureScreenshotsOnFailure) { _, _ in settings.save() }
    }
}

// MARK: - Memory Protection

struct SettingsMemoryProtectionSection: View {
    @Bindable var settings: AutomationSettings
    @Binding var showResetConfirm: Bool

    var body: some View {
        Section {
            memorySlider(label: "Safe Threshold", value: settings.memorySafeThresholdMB, range: 200...800, color: .green) {
                settings.memorySafeThresholdMB = $0
            }
            memorySlider(label: "Elevated Threshold", value: settings.memoryElevatedThresholdMB, range: 300...900, color: .yellow) {
                settings.memoryElevatedThresholdMB = $0
            }
            memorySlider(label: "Critical Threshold", value: settings.memoryCriticalThresholdMB, range: 400...1200, color: .orange) {
                settings.memoryCriticalThresholdMB = $0
            }
            memorySlider(label: "Emergency Threshold", value: settings.memoryEmergencyThresholdMB, range: 600...1500, color: .red) {
                settings.memoryEmergencyThresholdMB = $0
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Cooldown Base Duration")
                    Spacer()
                    Text(String(format: "%.1fs", settings.cooldownBaseDuration))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.cooldownBaseDuration, in: 1...30, step: 0.5)
            }

            HStack {
                Text("Current")
                Spacer()
                Text(CrashProtectionService.shared.diagnosticSummary)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Button("Reset Memory Defaults", role: .destructive) {
                showResetConfirm = true
            }
        } header: {
            Label("Memory Protection", systemImage: "memorychip")
        } footer: {
            Text("Thresholds auto-reduce after each crash. Lower values = earlier intervention. Raise if your device has ample RAM.")
        }
        .onChange(of: settings.memorySafeThresholdMB) { _, _ in settings.save() }
        .onChange(of: settings.memoryElevatedThresholdMB) { _, _ in settings.save() }
        .onChange(of: settings.memoryCriticalThresholdMB) { _, _ in settings.save() }
        .onChange(of: settings.memoryEmergencyThresholdMB) { _, _ in settings.save() }
        .onChange(of: settings.cooldownBaseDuration) { _, _ in settings.save() }
    }

    private func memorySlider(label: String, value: Int, range: ClosedRange<Double>, color: Color, setter: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value) MB")
                    .foregroundStyle(color)
            }
            Slider(value: Binding(
                get: { Double(value) },
                set: { setter(Int($0)) }
            ), in: range, step: 25)
        }
    }
}

// MARK: - Network Connection

struct SettingsNetworkConnectionSection: View {
    @Bindable var networkManager: SimpleNetworkManager
    let hasStoredKey: Bool
    @Binding var isMeasuringLatency: Bool

    var body: some View {
        Section {
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
                Text(hasStoredKey ? "Single-Key Ready" : "Not Set")
                    .foregroundStyle(hasStoredKey ? .green : .secondary)
            }

            if networkManager.lastLatencyMs != 0 {
                HStack {
                    Text("Last Latency")
                    Spacer()
                    Text(latencyLabel)
                        .foregroundStyle(latencyColor)
                }
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

            Button {
                isMeasuringLatency = true
                Task {
                    await networkManager.measureLatency()
                    isMeasuringLatency = false
                }
            } label: {
                HStack {
                    Text("Measure Latency")
                    Spacer()
                    if isMeasuringLatency { ProgressView() }
                }
            }
            .disabled(isMeasuringLatency)
        } header: {
            Label("Network", systemImage: "network")
        }
    }

    private var latencyLabel: String {
        networkManager.lastLatencyMs > 0 ? "\(networkManager.lastLatencyMs) ms" : "Failed"
    }

    private var latencyColor: Color {
        if networkManager.lastLatencyMs <= 0 { return .red }
        return networkManager.lastLatencyMs < 200 ? .green : .orange
    }
}

// MARK: - Network Configuration

struct SettingsNetworkConfigSection: View {
    @Bindable var settings: AutomationSettings
    @Bindable var networkManager: SimpleNetworkManager
    @Binding var showResetConfirm: Bool

    var body: some View {
        Section {
            sliderRow(label: "Connection Timeout", value: settings.connectionTimeoutSeconds, suffix: "s", format: "%.0f") {
                Slider(value: $settings.connectionTimeoutSeconds, in: 5...120, step: 5)
            }

            sliderRow(label: "Request Timeout", value: settings.requestTimeoutSeconds, suffix: "s", format: "%.0f") {
                Slider(value: $settings.requestTimeoutSeconds, in: 10...300, step: 10)
            }

            Toggle("Strict Network Isolation", isOn: $settings.networkIsolationStrict)
            Toggle("Auto-Reconnect", isOn: $settings.autoReconnect)
            Stepper("Max Network Retries: \(settings.maxNetworkRetries)", value: $settings.maxNetworkRetries, in: 0...10)
            Toggle("Bandwidth Monitoring", isOn: $settings.bandwidthMonitoring)

            if settings.bandwidthMonitoring {
                HStack {
                    Text("Bandwidth")
                    Spacer()
                    Text(networkManager.bandwidthSummary)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Button("Reset Bandwidth Counters") {
                    networkManager.resetBandwidthCounters()
                }
            }

            Button("Reset Network Defaults", role: .destructive) {
                showResetConfirm = true
            }
        } header: {
            Label("Network Configuration", systemImage: "gearshape.2")
        } footer: {
            Text("Strict isolation uses separate WebKit data stores per session. Disable for shared cookie/state scenarios.")
        }
        .onChange(of: settings.connectionTimeoutSeconds) { _, _ in settings.save() }
        .onChange(of: settings.requestTimeoutSeconds) { _, _ in settings.save() }
        .onChange(of: settings.networkIsolationStrict) { _, _ in settings.save() }
        .onChange(of: settings.autoReconnect) { _, _ in settings.save() }
        .onChange(of: settings.maxNetworkRetries) { _, _ in settings.save() }
        .onChange(of: settings.bandwidthMonitoring) { _, _ in settings.save() }
    }

    private func sliderRow<S: View>(label: String, value: Double, suffix: String, format: String, @ViewBuilder slider: () -> S) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: format, value) + suffix)
                    .foregroundStyle(.secondary)
            }
            slider()
        }
    }
}

// MARK: - Proxy Management

struct SettingsProxyManagementSection: View {
    @Bindable var settings: AutomationSettings
    @Bindable var networkManager: SimpleNetworkManager
    @Binding var isRunningHealthCheck: Bool

    var body: some View {
        Section {
            Toggle("Health Check on Connect", isOn: $settings.proxyHealthCheckOnConnect)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Rotation Interval")
                    Spacer()
                    Text(settings.proxyRotationIntervalSeconds > 0 ? "\(settings.proxyRotationIntervalSeconds)s" : "Off")
                        .foregroundStyle(.secondary)
                }
                Stepper("", value: $settings.proxyRotationIntervalSeconds, in: 0...600, step: 30)
                    .labelsHidden()
            }

            if !networkManager.proxyHealthStatus.isEmpty {
                ForEach(Array(networkManager.proxyHealthStatus.sorted(by: { $0.key < $1.key })), id: \.key) { key, health in
                    HStack {
                        Image(systemName: health.iconName)
                            .foregroundStyle(healthColor(for: health))
                        Text(key)
                            .font(.system(size: 12, design: .monospaced))
                        Spacer()
                        Text(health.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                isRunningHealthCheck = true
                Task {
                    await networkManager.runProxyHealthChecks()
                    isRunningHealthCheck = false
                }
            } label: {
                HStack {
                    Text("Run Health Check")
                    Spacer()
                    if isRunningHealthCheck { ProgressView() }
                }
            }
            .disabled(isRunningHealthCheck || networkManager.proxyCount == 0)

            HStack {
                Text("Healthy")
                Spacer()
                Text("\(networkManager.healthyProxyCount)/\(networkManager.proxyCount)")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("Proxy Management", systemImage: "arrow.triangle.swap")
        } footer: {
            Text("Set rotation interval to 0 to disable automatic proxy cycling. Health checks verify bridge connectivity.")
        }
        .onChange(of: settings.proxyHealthCheckOnConnect) { _, _ in settings.save() }
        .onChange(of: settings.proxyRotationIntervalSeconds) { _, _ in settings.save() }
    }

    private func healthColor(for health: ProxyHealth) -> Color {
        switch health {
        case .healthy: .green
        case .degraded: .orange
        case .unreachable: .red
        }
    }
}

// MARK: - DNS

struct SettingsDNSSection: View {
    @Bindable var settings: AutomationSettings

    var body: some View {
        Section {
            Picker("DNS Provider", selection: $settings.dnsPreference) {
                ForEach(DNSPreference.allCases, id: \.self) { pref in
                    Text(pref.displayName).tag(pref)
                }
            }

            if settings.dnsPreference != .system {
                HStack {
                    Text("Primary")
                    Spacer()
                    Text(settings.dnsPreference.primaryAddress)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Secondary")
                    Spacer()
                    Text(settings.dnsPreference.secondaryAddress)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("DNS", systemImage: "globe")
        } footer: {
            Text("DNS preference applies to WireGuard tunnel configurations. System default uses your network's DNS resolver.")
        }
        .onChange(of: settings.dnsPreference) { _, _ in settings.save() }
    }
}

// MARK: - Logging

struct SettingsLoggingSection: View {
    @Bindable var settings: AutomationSettings

    var body: some View {
        Section {
            Picker("Minimum Log Level", selection: $settings.minimumLogLevel) {
                ForEach(DebugLogger.LogLevel.allCases, id: \.rawValue) { level in
                    Text(level.title).tag(level.rawValue)
                }
            }

            Stepper("Log Retention: \(settings.logRetentionLimit)", value: $settings.logRetentionLimit, in: 500...20000, step: 500)

            HStack {
                Text("Current Entries")
                Spacer()
                Text("\(DebugLogger.shared.entries.count)")
                    .foregroundStyle(.secondary)
            }

            Button("Clear Log Buffer") {
                DebugLogger.shared.clear()
            }
        } header: {
            Label("Logging", systemImage: "doc.text")
        }
        .onChange(of: settings.minimumLogLevel) { _, _ in settings.save() }
        .onChange(of: settings.logRetentionLimit) { _, _ in settings.save() }
    }
}

// MARK: - Site URLs

struct SettingsSiteURLsSection: View {
    @Bindable var settings: AutomationSettings

    var body: some View {
        Section {
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
        } header: {
            Label("Site URLs", systemImage: "link")
        }
        .onChange(of: settings.joeURL) { _, _ in settings.save() }
        .onChange(of: settings.ignitionURL) { _, _ in settings.save() }
    }

    private func siteURLBinding(for site: AutomationSite) -> Binding<String> {
        Binding(
            get: { settings.loginURL(for: site) },
            set: { settings.setLoginURL($0, for: site) }
        )
    }

    private func primarySelectorSummary(for site: AutomationSite) -> String {
        let u: String = site.usernameSelectors.first ?? "n/a"
        let p: String = site.passwordSelectors.first ?? "n/a"
        let s: String = site.submitSelectors.first ?? "n/a"
        return "Selectors: \(u) • \(p) • \(s)"
    }
}
