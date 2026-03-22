import SwiftUI

struct DualRunView: View {
    @State private var engine = ConcurrentAutomationEngine.shared
    @State private var settings = AutomationSettings.shared
    @State private var credentials: [LoginCredential] = PersistenceService.shared.loadCredentials()
    @State private var selectedSession: ConcurrentSession?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                controlPanel
                if engine.isRunning || engine.state == .completed || engine.state == .failed {
                    progressSection
                    sessionList
                }
                if !engine.isRunning && engine.state != .completed {
                    configSection
                }
            }
            .padding()
        }
        .navigationTitle("Dual Run")
        .sheet(item: $selectedSession) { session in
            SessionDetailSheet(session: session)
        }
    }

    private var controlPanel: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Engine: \(engine.state.rawValue.capitalized)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    Text("\(credentials.filter { $0.isEnabled }.count) credentials ready")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if engine.isRunning {
                    HStack(spacing: 12) {
                        Button {
                            if engine.state == .paused {
                                engine.resume()
                            } else {
                                engine.pause()
                            }
                        } label: {
                            Image(systemName: engine.state == .paused ? "play.fill" : "pause.fill")
                                .font(.title3)
                        }

                        Button {
                            engine.stop()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    Button {
                        startDualRun()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.horizontal.fill")
                            Text("START DUAL RUN")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.cyan)
                        .clipShape(.capsule)
                    }
                    .disabled(credentials.filter { $0.isEnabled }.isEmpty)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            ProgressView(value: engine.overallProgress)
                .tint(.cyan)

            HStack {
                Label("\(engine.succeededCount)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Label("\(engine.failedCount)", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Label("\(engine.activeCount)", systemImage: "bolt.fill")
                    .foregroundStyle(.cyan)
                Spacer()
                Text("Wave \(engine.currentWave)/\(engine.totalWaves)")
                    .foregroundStyle(.secondary)
                Text(engine.elapsedFormatted)
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12, design: .monospaced))
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sessions")
                .font(.headline)

            ForEach(engine.sessions) { session in
                Button {
                    selectedSession = session
                } label: {
                    HStack {
                        Image(systemName: session.phase.iconName)
                            .foregroundStyle(phaseColor(session.phase))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.credential.username)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(.primary)
                            Text("\(session.phase.displayName) • \(session.proxyInfo)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if session.phase.isActive {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(session.elapsedFormatted)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Configuration", systemImage: "gearshape")
                .font(.headline)

            Picker("Speed Mode", selection: $settings.speedMode) {
                ForEach(SpeedMode.allCases, id: \.self) { mode in
                    Label(mode.displayName, systemImage: mode.iconName).tag(mode)
                }
            }

            Stepper("Concurrent Pairs: \(settings.maxConcurrentPairs)", value: $settings.maxConcurrentPairs, in: 1...12)

            ForEach(settings.availableSites) { site in
                VStack(alignment: .leading, spacing: 6) {
                    Text(site.displayName)
                        .font(.subheadline.weight(.semibold))

                    TextField(site.defaultLoginURL, text: siteURLBinding(for: site))
                        .font(.system(size: 13, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Text(primarySelectorSummary(for: site))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
        .onChange(of: settings.speedMode) { _, _ in settings.save() }
        .onChange(of: settings.maxConcurrentPairs) { _, _ in settings.save() }
        .onChange(of: settings.joeURL) { _, _ in settings.save() }
        .onChange(of: settings.ignitionURL) { _, _ in settings.save() }
    }

    private func startDualRun() {
        credentials = PersistenceService.shared.loadCredentials()
        settings.save()

        engine.startDualRun(
            credentials: credentials,
            joeFlow: { page, credential, speed in
                try await SiteLoginAutomationService.shared.executeLogin(
                    on: page,
                    site: .joe,
                    credential: credential,
                    speedMode: speed,
                    overrideURL: settings.loginURL(for: .joe)
                )
            },
            ignitionFlow: { page, credential, speed in
                try await SiteLoginAutomationService.shared.executeLogin(
                    on: page,
                    site: .ignition,
                    credential: credential,
                    speedMode: speed,
                    overrideURL: settings.loginURL(for: .ignition)
                )
            }
        )
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

    private func phaseColor(_ phase: SessionPhase) -> Color {
        switch phase {
        case .succeeded: .green
        case .failed: .red
        case .cancelled: .gray
        case .queued: .secondary
        default: .cyan
        }
    }
}

struct SessionDetailSheet: View {
    let session: ConcurrentSession

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(session.credential.username, systemImage: "person.fill")
                            .font(.headline)
                        HStack {
                            Label(session.phase.displayName, systemImage: session.phase.iconName)
                            Spacer()
                            Text(session.elapsedFormatted)
                                .font(.system(size: 13, design: .monospaced))
                        }
                        .foregroundStyle(.secondary)
                        Text("Proxy: \(session.proxyInfo)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }

                    if let result = session.dualResult {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dual Result")
                                .font(.subheadline.bold())
                            Text("Combined: \(result.outcome.rawValue)")
                            Text("Joe: \(result.joeOutcome.rawValue)")
                            Text("Ignition: \(result.ignitionOutcome.rawValue)")
                            Text("Duration: \(String(format: "%.1f", result.duration))s")
                        }
                        .font(.system(size: 12, design: .monospaced))
                    }

                    if let error = session.errorMessage {
                        Text(error)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.red)
                            .padding(8)
                            .background(.red.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log (\(session.logEntries.count))")
                            .font(.subheadline.bold())
                        ForEach(session.logEntries) { entry in
                            Text(entry.formatted)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Session Detail")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
