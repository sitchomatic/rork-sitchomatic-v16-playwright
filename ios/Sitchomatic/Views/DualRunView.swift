import SwiftUI
import UIKit

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
            SessionProofSheet(session: session)
        }
    }

    private var controlPanel: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: engine.state.iconName)
                            .foregroundStyle(engine.isRunning ? .cyan : .secondary)
                        Text(engine.state.rawValue.capitalized)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    }
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

            if engine.retryableCount > 0 && !engine.isRunning {
                Button {
                    retryFailed()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("RETRY \(engine.retryableCount) FAILED")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .overlay(Capsule().stroke(.orange, lineWidth: 1))
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

            HStack {
                Text("Health: \(String(format: "%.0f%%", engine.healthScore * 100))")
                    .foregroundStyle(engine.healthScore > 0.7 ? .green : engine.healthScore > 0.4 ? .orange : .red)
                Spacer()
                Text("Concurrency: \(engine.effectiveConcurrency)")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 11, design: .monospaced))
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sessions")
                    .font(.headline)
                Spacer()
                Text("\(engine.succeededCount)/\(engine.sessions.count)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            ForEach(engine.sessions) { session in
                Button {
                    selectedSession = session
                } label: {
                    sessionRow(session)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func sessionRow(_ session: ConcurrentSession) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: session.phase.iconName)
                    .foregroundStyle(phaseColor(session.phase))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.credential.username)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(session.phase.displayName)
                            .foregroundStyle(phaseColor(session.phase))
                        Text(session.proxyInfo)
                            .foregroundStyle(.tertiary)
                    }
                    .font(.system(size: 11))
                    .lineLimit(1)
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

            if session.joeScreenshot != nil || session.ignitionScreenshot != nil {
                HStack(spacing: 6) {
                    proofThumb(label: "JOE", data: session.joeScreenshot, outcome: session.dualResult?.joeOutcome)
                    proofThumb(label: "IGN", data: session.ignitionScreenshot, outcome: session.dualResult?.ignitionOutcome)
                }
            }

            if let result = session.dualResult {
                HStack(spacing: 8) {
                    resultChip(result.joeOutcome, label: "Joe")
                    resultChip(result.ignitionOutcome, label: "Ign")
                    Spacer()
                    Text(String(format: "%.1fs", result.duration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private func proofThumb(label: String, data: Data?, outcome: DualLoginOutcome?) -> some View {
        Group {
            if let data, let uiImage = UIImage(data: data) {
                Color(.tertiarySystemFill)
                    .frame(height: 50)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 6))
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(outcomeColor(outcome))
                                .frame(width: 4, height: 4)
                            Text(label)
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.6))
                        .clipShape(.rect(cornerRadius: 3))
                        .padding(3)
                    }
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 50)
                    .overlay {
                        Text(label)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func resultChip(_ outcome: DualLoginOutcome, label: String) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(outcomeColor(outcome))
                .frame(width: 5, height: 5)
            Text("\(label): \(outcome.rawValue)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
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

    private func retryFailed() {
        engine.retryFailed(
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

    private func outcomeColor(_ outcome: DualLoginOutcome?) -> Color {
        guard let outcome else { return .gray }
        switch outcome {
        case .success: return .green
        case .permDisabled: return .red
        case .tempDisabled: return .orange
        case .networkError: return .yellow
        case .crashed: return .red
        case .unsure: return .purple
        }
    }
}
