import SwiftUI
import UIKit

struct DashboardView: View {
    @Binding private var selectedTab: AppTab

    @State private var orchestrator = PlaywrightOrchestrator.shared
    @State private var engine = ConcurrentAutomationEngine.shared
    @State private var crashProtection = CrashProtectionService.shared
    @State private var settings = AutomationSettings.shared
    @State private var backgroundService = BackgroundTaskService.shared
    @State private var pool = WebViewPool.shared
    @State private var lifetimeBudget = WebViewLifetimeBudgetService.shared
    @State private var sessionRecovery = SessionRecoveryService.shared
    @State private var selectedSession: ConcurrentSession?
    @State private var sessionFilter: SessionVisibilityFilter = .all
    @State private var credentials: [LoginCredential] = []

    init(selectedTab: Binding<AppTab>) {
        _selectedTab = selectedTab
    }

    var body: some View {
        ZStack {
            Image("MainMenuWallpaper")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.2), location: 0),
                    .init(color: .black.opacity(0.46), location: 0.28),
                    .init(color: .black.opacity(0.88), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    overviewGrid
                    sessionSection
                    toolsSection
                    healthSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Sitchomatic v16")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                connectionBadge
            }
        }
        .navigationDestination(for: DashboardDestination.self) { destination in
            switch destination {
            case .dualFind:
                DualFindContainerView()
            case .recorder:
                FlowRecorderContainerView()
            }
        }
        .sheet(item: $selectedSession) { session in
            SessionProofSheet(session: session)
        }
        .task {
            credentials = PersistenceService.shared.loadCredentials()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Permanent Dual Mode")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                    Text("Run sessions, inspect proof, and jump straight into tools.")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Shared proxy pairs, Playwright proof screenshots, live recovery, and trace-ready diagnostics.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                Button {
                    selectedTab = .run
                } label: {
                    Label("Run", systemImage: "bolt.horizontal.fill")
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }

            HStack(spacing: 10) {
                statusPill(title: "Credentials", value: "\(enabledCredentialCount)", symbol: "person.2.fill", tint: .white)
                statusPill(title: "Pairs", value: "\(orchestrator.activePairedSessions)", symbol: "link", tint: .cyan)
                statusPill(title: "Health", value: healthPercentText, symbol: "heart.fill", tint: healthColor)
            }

            HStack(spacing: 10) {
                quickSwitchButton(title: "Sessions", symbol: "rectangle.stack.fill", tab: .run)
                quickSwitchButton(title: "Credentials", symbol: "person.crop.circle.badge.plus", tab: .credentials)
                quickSwitchButton(title: "Debug", symbol: "waveform.path.ecg.rectangle", tab: .debug)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 22))
    }

    private var overviewGrid: some View {
        let columns: [GridItem] = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            summaryCard(
                title: "Run State",
                value: engine.state.displayName,
                detail: "Wave \(engine.currentWave)/\(max(engine.totalWaves, 1)) • \(engine.elapsedFormatted)",
                symbol: engine.state.iconName,
                tint: .cyan
            )

            summaryCard(
                title: "Results",
                value: "\(engine.succeededCount) / \(engine.sessions.count)",
                detail: "\(engine.failedCount) failed • \(engine.retryableCount) retryable",
                symbol: "checkmark.circle.badge.xmark",
                tint: engine.failedCount > 0 ? .orange : .green
            )

            summaryCard(
                title: "Background",
                value: backgroundTimeLabel,
                detail: "\(backgroundService.activeTaskCount) tasks • \(backgroundService.isBackgroundTimeLow ? "low time" : "stable")",
                symbol: "moon.zzz.fill",
                tint: backgroundService.isBackgroundTimeLow ? .orange : .blue
            )

            summaryCard(
                title: "Recovery",
                value: sessionRecovery.hasResumableCheckpoint() ? "Checkpoint" : "Clear",
                detail: "\(String(format: "%.0f", sessionRecovery.recoverySuccessRate * 100))% success • \(String(format: "%.0f", engine.lastWaveFailureRate * 100))% last fail",
                symbol: sessionRecovery.hasResumableCheckpoint() ? "arrow.clockwise.circle.fill" : "checkmark.seal.fill",
                tint: sessionRecovery.hasResumableCheckpoint() ? .orange : .green
            )
        }
    }

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sessions")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Proof screenshots are attached to every result and session detail.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                Text("\(filteredSessions.count) shown")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }

            HStack(spacing: 8) {
                ForEach(SessionVisibilityFilter.allCases, id: \.self) { filter in
                    Button {
                        sessionFilter = filter
                    } label: {
                        HStack(spacing: 6) {
                            Text(filter.title)
                            Text("\(count(for: filter))")
                                .foregroundStyle(sessionFilter == filter ? .cyan : .white.opacity(0.55))
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(sessionFilter == filter ? .white.opacity(0.16) : .white.opacity(0.06), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
            }

            if filteredSessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "rectangle.stack.badge.play",
                    description: Text("Start a dual run to see live progress, proof screenshots, and outcome breakdowns here.")
                )
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredSessions) { session in
                        Button {
                            selectedSession = session
                        } label: {
                            sessionCard(session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tools")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(orchestrator.networkStatusSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
            }

            HStack(spacing: 12) {
                NavigationLink(value: DashboardDestination.dualFind) {
                    toolCard(title: "Dual Find", subtitle: "Selector search and confirmation", symbol: "magnifyingglass.circle.fill")
                }
                .buttonStyle(.plain)

                NavigationLink(value: DashboardDestination.recorder) {
                    toolCard(title: "Recorder", subtitle: "Capture flows into Playwright actions", symbol: "record.circle.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("System Health")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(healthPercentText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(healthColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(healthColor.opacity(0.18), in: .capsule)
            }

            VStack(spacing: 8) {
                healthRow(label: "Memory", value: String(format: "%.0f MB", crashProtection.currentMemoryUsageMB), status: crashProtection.memoryPressureLevel.rawValue.capitalized, tint: memoryColor)
                healthRow(label: "Pool", value: "\(pool.activeCount)/\(lifetimeBudget.effectiveMaxConcurrent)", status: lifetimeBudget.isOverBudget ? "Over Budget" : "Healthy", tint: lifetimeBudget.isOverBudget ? .red : .green)
                healthRow(label: "Tracing", value: settings.enableTracing ? "Enabled" : "Disabled", status: settings.captureScreenshotsOnFailure ? "Failure shots" : "No fail shots", tint: settings.enableTracing ? .cyan : .secondary)
                healthRow(label: "Checkpoint", value: sessionRecovery.hasResumableCheckpoint() ? "Available" : "None", status: sessionRecovery.diagnosticSummary, tint: sessionRecovery.hasResumableCheckpoint() ? .orange : .secondary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    private func summaryCard(title: String, value: String, detail: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
    }

    private func quickSwitchButton(title: String, symbol: String, tab: AppTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(.white)
    }

    private func statusPill(title: String, value: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.58))
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.08), in: .capsule)
    }

    private var connectionBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(orchestrator.isReady ? .green : .red)
                .frame(width: 8, height: 8)
            Text(orchestrator.isReady ? "LIVE" : "OFF")
                .font(.caption2.weight(.black))
                .foregroundStyle(orchestrator.isReady ? .green : .red)
        }
    }

    private func toolCard(title: String, subtitle: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.cyan)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    private func sessionCard(_ session: ConcurrentSession) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: session.phase.iconName)
                    .font(.headline)
                    .foregroundStyle(phaseColor(session.phase))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.credential.username)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(session.phase.displayName)
                            .foregroundStyle(phaseColor(session.phase))
                        Text("Wave \(session.waveIndex + 1)")
                            .foregroundStyle(.white.opacity(0.52))
                        Text(session.proxyInfo)
                            .foregroundStyle(.white.opacity(0.42))
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
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            if session.joeScreenshot != nil || session.ignitionScreenshot != nil {
                HStack(spacing: 8) {
                    screenshotThumbnail(label: "JOE", data: session.joeScreenshot, outcome: session.dualResult?.joeOutcome)
                    screenshotThumbnail(label: "IGN", data: session.ignitionScreenshot, outcome: session.dualResult?.ignitionOutcome)
                }
            }

            HStack(spacing: 12) {
                if let result = session.dualResult {
                    outcomeBadge("Joe", outcome: result.joeOutcome)
                    outcomeBadge("Ign", outcome: result.ignitionOutcome)
                    Spacer()
                    Text(result.duration.formatted(.number.precision(.fractionLength(1))))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("s")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                } else if let errorMessage = session.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.92))
                        .lineLimit(2)
                    Spacer()
                } else {
                    Text("Tap for proof and full timeline")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.52))
                    Spacer()
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.38))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
    }

    private func screenshotThumbnail(label: String, data: Data?, outcome: DualLoginOutcome?) -> some View {
        Group {
            if let data, let uiImage = UIImage(data: data) {
                Color(.secondarySystemBackground)
                    .frame(height: 76)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(outcomeColor(outcome))
                                .frame(width: 6, height: 6)
                            Text(label)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.68), in: .capsule)
                        .padding(6)
                    }
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.06))
                    .frame(height: 76)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.subheadline)
                            Text(label)
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(.white.opacity(0.25))
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func outcomeBadge(_ title: String, outcome: DualLoginOutcome) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(outcomeColor(outcome))
                .frame(width: 6, height: 6)
            Text("\(title): \(outcome.rawValue)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private func healthRow(label: String, value: String, status: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))
                .frame(width: 76, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(tint)
                    .lineLimit(2)
            }
            Spacer()
        }
    }

    private var filteredSessions: [ConcurrentSession] {
        let base: [ConcurrentSession]
        switch sessionFilter {
        case .all:
            base = engine.sessions
        case .active:
            base = engine.sessions.filter { $0.phase.isActive || $0.phase == .queued }
        case .failed:
            base = engine.sessions.filter { $0.phase == .failed }
        case .succeeded:
            base = engine.sessions.filter { $0.phase == .succeeded }
        }

        return base.sorted { lhs, rhs in
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
        case .all:
            engine.sessions.count
        case .active:
            engine.sessions.filter { $0.phase.isActive || $0.phase == .queued }.count
        case .failed:
            engine.sessions.filter { $0.phase == .failed }.count
        case .succeeded:
            engine.sessions.filter { $0.phase == .succeeded }.count
        }
    }

    private var enabledCredentialCount: Int {
        credentials.filter(\.isEnabled).count
    }

    private var healthPercentText: String {
        engine.healthScore.formatted(.percent.precision(.fractionLength(0)))
    }

    private var healthColor: Color {
        if engine.healthScore > 0.7 { return .green }
        if engine.healthScore > 0.4 { return .orange }
        return .red
    }

    private var backgroundTimeLabel: String {
        if backgroundService.remainingBackgroundTime > 900 {
            return "Foreground"
        }
        if backgroundService.remainingBackgroundTime == 0 {
            return "Idle"
        }
        return "\(Int(backgroundService.remainingBackgroundTime))s"
    }

    private var memoryColor: Color {
        switch crashProtection.memoryPressureLevel {
        case .safe: .green
        case .elevated: .yellow
        case .critical: .orange
        case .emergency: .red
        }
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
