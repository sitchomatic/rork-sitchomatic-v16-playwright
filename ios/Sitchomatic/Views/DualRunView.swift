import SwiftUI
import UIKit

struct DualRunView: View {
    @State private var engine = ConcurrentAutomationEngine.shared
    @State private var settings = AutomationSettings.shared
    @State private var credentials: [LoginCredential] = PersistenceService.shared.loadCredentials()
    @State private var selectedSession: ConcurrentSession?
    @State private var sessionFilter: SessionVisibilityFilter = .all

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                controlPanel
                progressSection
                categoryBreakdownSection
                sessionSection
                if !engine.isRunning && engine.state != .completed {
                    configSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dual Run")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedSession) { session in
            SessionProofSheet(session: session)
        }
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: engine.state.iconName)
                            .foregroundStyle(engine.isRunning ? .cyan : .secondary)
                        Text(engine.state.displayName)
                            .font(.headline)
                    }

                    Text("\(enabledCredentialCount) enabled credentials \u{2022} \(settings.maxConcurrentPairs) max pairs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if engine.isRunning {
                    HStack(spacing: 10) {
                        Button {
                            if engine.state == .paused {
                                engine.resume()
                            } else {
                                engine.pause()
                            }
                        } label: {
                            Image(systemName: engine.state == .paused ? "play.fill" : "pause.fill")
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            engine.stop()
                        } label: {
                            Image(systemName: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                    .tint(.cyan)
                } else {
                    Button {
                        startDualRun()
                    } label: {
                        Label("Start Dual Run", systemImage: "bolt.horizontal.fill")
                            .font(.headline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .disabled(enabledCredentialCount == 0)
                }
            }

            HStack(spacing: 10) {
                metricPill(title: "Health", value: engine.healthScore.formatted(.percent.precision(.fractionLength(0))), tint: healthColor)
                metricPill(title: "Wave", value: "\(engine.currentWave)/\(max(engine.totalWaves, 1))", tint: .cyan)
                metricPill(title: "Runtime", value: engine.elapsedFormatted, tint: .secondary)
            }

            if engine.retryableCount > 0 && !engine.isRunning {
                Button {
                    retryFailed()
                } label: {
                    Label("Retry \(engine.retryableCount) Failed", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Overview")
                    .font(.headline)
                Spacer()
                Text(engine.isRunning ? "Active" : "Ready")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(engine.isRunning ? .cyan : .secondary)
            }

            ProgressView(value: engine.overallProgress)
                .tint(.cyan)

            HStack(spacing: 12) {
                summaryTile(title: "Success", value: "\(engine.succeededCount)", tint: .green)
                summaryTile(title: "Failed", value: "\(engine.failedCount)", tint: .red)
                summaryTile(title: "Active", value: "\(engine.activeCount)", tint: .cyan)
            }

            HStack(spacing: 10) {
                summaryTile(title: "Queued", value: "\(engine.queuedCount)", tint: .secondary)
                summaryTile(title: "Concurrency", value: "\(engine.effectiveConcurrency)", tint: .blue)
                summaryTile(title: "Speed", value: settings.speedMode.displayName, tint: .orange)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
    }

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Result Categories")
                .font(.headline)

            let columns: [GridItem] = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(DualLoginOutcome.allCases, id: \.self) { outcome in
                    categoryTile(outcome: outcome)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
    }

    private func categoryTile(outcome: DualLoginOutcome) -> some View {
        let count: Int = {
            switch outcome {
            case .success: engine.succeededCount
            case .noAccount: engine.noAccountCount
            case .permDisabled: engine.permDisabledCount
            case .tempDisabled: engine.tempDisabledCount
            case .unsure: engine.unsureCount
            case .error: engine.errorCount
            }
        }()

        return HStack(spacing: 6) {
            Image(systemName: outcome.iconName)
                .font(.caption2)
                .foregroundStyle(outcomeColor(outcome))
            VStack(alignment: .leading, spacing: 1) {
                Text(outcome.shortName)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("\(count)")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(outcomeColor(outcome))
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(outcomeColor(outcome).opacity(0.08), in: .rect(cornerRadius: 10))
    }

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Results")
                        .font(.headline)
                    Text("Every result includes its Playwright proof screenshots.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(filteredSessions.count) shown")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SessionVisibilityFilter.allCases, id: \.self) { filter in
                        filterChip(filter: filter, count: count(for: filter), isSelected: sessionFilter == filter) {
                            sessionFilter = filter
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0)

            if filteredSessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "rectangle.stack.badge.play",
                    description: Text("Start a dual run to see live activity, proof screenshots, and per-site outcomes here.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.regularMaterial, in: .rect(cornerRadius: 20))
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredSessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: ConcurrentSession) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    if let result = session.dualResult {
                        Image(systemName: result.outcome.iconName)
                            .foregroundStyle(outcomeColor(result.outcome))
                    } else {
                        Image(systemName: session.phase.iconName)
                            .foregroundStyle(phaseColor(session.phase))
                    }
                }
                .frame(width: 22)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(session.credential.username)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if session.isFlaggedForReview {
                            Image(systemName: "flag.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }

                    HStack(spacing: 8) {
                        if let result = session.dualResult {
                            Text(result.outcome.shortName)
                                .foregroundStyle(outcomeColor(result.outcome))
                        } else {
                            Text(session.phase.displayName)
                                .foregroundStyle(phaseColor(session.phase))
                        }
                        Text("Wave \(session.waveIndex + 1)")
                            .foregroundStyle(.secondary)
                        Text(session.proxyInfo)
                            .foregroundStyle(.tertiary)
                    }
                    .font(.caption)
                    .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    if session.phase.isActive {
                        ProgressView(value: session.progress)
                            .tint(.cyan)
                            .frame(width: 70)
                    }

                    Text(session.elapsedFormatted)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if session.joeScreenshot != nil || session.ignitionScreenshot != nil {
                HStack(spacing: 8) {
                    proofThumb(label: "JOE", data: session.joeScreenshot, outcome: session.dualResult?.joeOutcome)
                    proofThumb(label: "IGN", data: session.ignitionScreenshot, outcome: session.dualResult?.ignitionOutcome)
                }
            }

            HStack(spacing: 8) {
                if let result = session.dualResult {
                    resultChip(result.joeOutcome, label: "Joe")
                    resultChip(result.ignitionOutcome, label: "Ign")
                    Spacer()
                    Text(result.duration.formatted(.number.precision(.fractionLength(1))))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("s")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else if let errorMessage = session.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                    Spacer()
                } else {
                    Text("Tap for detailed proof")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }

            if session.phase.isTerminal {
                HStack(spacing: 10) {
                    if session.phase == .failed {
                        Button {
                            engine.enqueueRetry(session.credential)
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .controlSize(.small)
                    }

                    Button {
                        UIPasteboard.general.string = session.credential.username
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .controlSize(.small)

                    Button {
                        session.toggleFlagged()
                    } label: {
                        Label(
                            session.isFlaggedForReview ? "Unflag" : "Flag",
                            systemImage: session.isFlaggedForReview ? "flag.slash.fill" : "flag.fill"
                        )
                        .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.yellow)
                    .controlSize(.small)

                    Spacer()
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: .rect(cornerRadius: 18))
        .onTapGesture {
            selectedSession = session
        }
    }

    private func proofThumb(label: String, data: Data?, outcome: DualLoginOutcome?) -> some View {
        Group {
            if let data, let uiImage = UIImage(data: data) {
                Color(.tertiarySystemFill)
                    .frame(height: 58)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(outcomeColor(outcome))
                                .frame(width: 5, height: 5)
                            Text(label)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.64), in: .capsule)
                        .padding(6)
                    }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 58)
                    .overlay {
                        Text(label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.quaternary)
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func resultChip(_ outcome: DualLoginOutcome, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: outcome.iconName)
                .font(.system(size: 8))
                .foregroundStyle(outcomeColor(outcome))
            Text("\(label): \(outcome.shortName)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration")
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
        .onChange(of: settings.speedMode) { _, _ in settings.save() }
        .onChange(of: settings.maxConcurrentPairs) { _, _ in settings.save() }
        .onChange(of: settings.joeURL) { _, _ in settings.save() }
        .onChange(of: settings.ignitionURL) { _, _ in settings.save() }
    }

    private func metricPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.secondary.opacity(0.08), in: .capsule)
    }

    private func summaryTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.secondary.opacity(0.08), in: .rect(cornerRadius: 14))
    }

    private func filterChip(filter: SessionVisibilityFilter, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: filter.iconName)
                    .font(.system(size: 9))
                Text(filter.title)
                Text("\(count)")
                    .foregroundStyle(isSelected ? .cyan : .secondary)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? .cyan.opacity(0.14) : .secondary.opacity(0.08), in: .capsule)
            .overlay {
                Capsule()
                    .stroke(isSelected ? .cyan : .secondary.opacity(0.24), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .cyan : .secondary)
    }

    private var filteredSessions: [ConcurrentSession] {
        let sessions: [ConcurrentSession]
        switch sessionFilter {
        case .all:
            sessions = engine.sessions
        case .active:
            sessions = engine.sessions.filter { $0.phase.isActive || $0.phase == .queued }
        case .success:
            sessions = engine.sessions.filter { $0.dualResult?.outcome == .success }
        case .noAccount:
            sessions = engine.sessions.filter { $0.dualResult?.outcome == .noAccount }
        case .permDisabled:
            sessions = engine.sessions.filter { $0.dualResult?.outcome == .permDisabled }
        case .tempDisabled:
            sessions = engine.sessions.filter { $0.dualResult?.outcome == .tempDisabled }
        case .unsure:
            sessions = engine.sessions.filter { $0.dualResult?.outcome == .unsure }
        case .error:
            sessions = engine.sessions.filter { $0.dualResult?.outcome == .error }
        }

        return sessions.sorted { lhs, rhs in
            if lhs.phase.isActive != rhs.phase.isActive {
                return lhs.phase.isActive
            }
            if lhs.phase == .failed && rhs.phase != .failed {
                return true
            }
            return lhs.index < rhs.index
        }
    }

    private func count(for filter: SessionVisibilityFilter) -> Int {
        switch filter {
        case .all: engine.sessions.count
        case .active: engine.sessions.filter { $0.phase.isActive || $0.phase == .queued }.count
        case .success: engine.sessions.filter { $0.dualResult?.outcome == .success }.count
        case .noAccount: engine.sessions.filter { $0.dualResult?.outcome == .noAccount }.count
        case .permDisabled: engine.sessions.filter { $0.dualResult?.outcome == .permDisabled }.count
        case .tempDisabled: engine.sessions.filter { $0.dualResult?.outcome == .tempDisabled }.count
        case .unsure: engine.sessions.filter { $0.dualResult?.outcome == .unsure }.count
        case .error: engine.sessions.filter { $0.dualResult?.outcome == .error }.count
        }
    }

    private var enabledCredentialCount: Int {
        credentials.filter(\.isEnabled).count
    }

    private var healthColor: Color {
        if engine.healthScore > 0.7 { return .green }
        if engine.healthScore > 0.4 { return .orange }
        return .red
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
        return "Selectors: \(usernameSelector) \u{2022} \(passwordSelector) \u{2022} \(submitSelector)"
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
        case .noAccount: return .indigo
        case .permDisabled: return .red
        case .tempDisabled: return .orange
        case .unsure: return .purple
        case .error: return .yellow
        }
    }
}
