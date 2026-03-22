import SwiftUI
import UIKit

struct DashboardView: View {
    @State private var orchestrator = PlaywrightOrchestrator.shared
    @State private var engine = ConcurrentAutomationEngine.shared
    @State private var crashProtection = CrashProtectionService.shared
    @State private var settings = AutomationSettings.shared
    @State private var backgroundService = BackgroundTaskService.shared
    @State private var pool = WebViewPool.shared
    @State private var lifetimeBudget = WebViewLifetimeBudgetService.shared
    @State private var selectedSession: ConcurrentSession?

    var body: some View {
        ZStack {
            Image("MainMenuWallpaper")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.25), location: 0),
                    .init(color: .black.opacity(0.5), location: 0.3),
                    .init(color: .black.opacity(0.88), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 16) {
                    systemStatusBar
                    if engine.isRunning {
                        engineLiveCard
                    }
                    if !engine.sessions.isEmpty {
                        sessionResultsSection
                    }
                    toolsRow
                    healthMetricsCard
                }
                .padding()
            }
        }
        .navigationTitle("Sitchomatic v16")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(orchestrator.isReady ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(orchestrator.isReady ? "LIVE" : "OFF")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(orchestrator.isReady ? .green : .red)
                }
            }
        }
        .sheet(item: $selectedSession) { session in
            SessionProofSheet(session: session)
        }
    }

    // MARK: - System Status Bar

    private var systemStatusBar: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: orchestrator.isReady ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 12))
                        .foregroundStyle(orchestrator.isReady ? .green : .red)
                    Text(orchestrator.isReady ? "Session Active" : "Session Inactive")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                Text("DUAL MODE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.cyan.opacity(0.15))
                    .clipShape(.capsule)
            }

            HStack(spacing: 0) {
                statCell(icon: "network", value: "\(orchestrator.activeProxyCount)", label: "Proxies")
                dividerLine
                statCell(icon: "globe", value: "\(orchestrator.pages.count)", label: "Pages")
                dividerLine
                statCell(icon: "person.2", value: "\(orchestrator.activePairedSessions)", label: "Pairs")
                dividerLine
                statCell(icon: "checkmark.circle", value: "\(orchestrator.totalCredentialsProcessed)", label: "Done")
            }

            if engine.isRunning, engine.healthScore < 0.5 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("Health: \(String(format: "%.0f", engine.healthScore * 100))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.92))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func statCell(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(.white.opacity(0.1))
            .frame(width: 1, height: 28)
    }

    // MARK: - Engine Live Card

    private var engineLiveCard: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: engine.state.iconName)
                        .font(.system(size: 12))
                        .foregroundStyle(.cyan)
                        .symbolEffect(.pulse, isActive: engine.state == .running)
                    Text(engine.state.displayName.uppercased())
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
                Spacer()
                Text(engine.elapsedFormatted)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }

            ProgressView(value: engine.overallProgress)
                .tint(.cyan)

            HStack {
                Label("\(engine.succeededCount)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Label("\(engine.failedCount)", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Spacer()
                Label("\(engine.activeCount)", systemImage: "bolt.fill")
                    .foregroundStyle(.cyan)
                Spacer()
                Text("Wave \(engine.currentWave)/\(engine.totalWaves)")
                    .foregroundStyle(.white.opacity(0.6))
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.92))
        .clipShape(.rect(cornerRadius: 16))
    }

    // MARK: - Session Results with Screenshot Proof

    private var sessionResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SESSIONS")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("\(engine.sessions.count) total")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }

            ForEach(engine.sessions.sorted(by: { sessionSortOrder($0) < sessionSortOrder($1) })) { session in
                Button {
                    selectedSession = session
                } label: {
                    sessionCard(session)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sessionCard(_ session: ConcurrentSession) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: session.phase.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(phaseColor(session.phase))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.credential.username)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(session.phase.displayName)
                            .foregroundStyle(phaseColor(session.phase))
                        Text("W\(session.waveIndex + 1)")
                            .foregroundStyle(.white.opacity(0.4))
                        Text(session.proxyInfo)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
                }

                Spacer()

                if session.phase.isActive {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.cyan)
                }

                Text(session.elapsedFormatted)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }

            if session.joeScreenshot != nil || session.ignitionScreenshot != nil {
                HStack(spacing: 8) {
                    screenshotThumbnail(label: "JOE", data: session.joeScreenshot, outcome: session.dualResult?.joeOutcome)
                    screenshotThumbnail(label: "IGN", data: session.ignitionScreenshot, outcome: session.dualResult?.ignitionOutcome)
                }
            }

            if let result = session.dualResult {
                HStack(spacing: 12) {
                    outcomeBadge("Joe", outcome: result.joeOutcome)
                    outcomeBadge("Ign", outcome: result.ignitionOutcome)
                    Spacer()
                    Text(String(format: "%.1fs", result.duration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            if let error = session.errorMessage {
                Text(error)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial.opacity(0.85))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func screenshotThumbnail(label: String, data: Data?, outcome: DualLoginOutcome?) -> some View {
        Group {
            if let data, let uiImage = UIImage(data: data) {
                Color(.secondarySystemBackground)
                    .frame(height: 70)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(outcomeColor(outcome))
                                .frame(width: 5, height: 5)
                            Text(label)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.65))
                        .clipShape(.rect(cornerRadius: 4))
                        .padding(4)
                    }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.05))
                    .frame(height: 70)
                    .overlay {
                        VStack(spacing: 2) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12))
                            Text(label)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(.white.opacity(0.2))
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func outcomeBadge(_ label: String, outcome: DualLoginOutcome) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(outcomeColor(outcome))
                .frame(width: 6, height: 6)
            Text("\(label): \(outcome.rawValue)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Tools Row

    private var toolsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOOLS")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 12) {
                NavigationLink {
                    DualFindContainerView()
                } label: {
                    toolCard(icon: "magnifyingglass.circle.fill", title: "Dual Find", subtitle: "Search selectors")
                }

                NavigationLink {
                    FlowRecorderContainerView()
                } label: {
                    toolCard(icon: "record.circle", title: "Recorder", subtitle: "Record flows")
                }
            }
        }
    }

    private func toolCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.cyan)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial.opacity(0.8))
        .clipShape(.rect(cornerRadius: 14))
    }

    // MARK: - Health Metrics

    private var healthMetricsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("System Health", systemImage: "heart.text.square")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                healthBadge
            }

            VStack(spacing: 6) {
                healthRow("Memory", value: String(format: "%.0f MB", crashProtection.currentMemoryUsageMB), status: crashProtection.memoryPressureLevel.rawValue.capitalized, color: memoryColor)
                healthRow("Pool", value: "\(pool.activeCount)/\(lifetimeBudget.effectiveMaxConcurrent)", status: lifetimeBudget.isOverBudget ? "Over Budget" : "OK", color: lifetimeBudget.isOverBudget ? .red : .green)
                healthRow("Crashes", value: "\(crashProtection.crashCount)", status: crashProtection.isInCooldown ? "Cooldown" : "Clear", color: crashProtection.crashCount > 3 ? .red : .green)
                healthRow("Speed", value: settings.speedMode.displayName, status: "\(settings.speedMode.typingDelayMs)ms type", color: .cyan)
                healthRow("BG Tasks", value: "\(backgroundService.activeTaskCount)", status: backgroundService.isBackgroundTimeLow ? "Low Time" : "OK", color: backgroundService.isBackgroundTimeLow ? .orange : .green)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.85))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var healthBadge: some View {
        let score = engine.healthScore
        let color: Color = score > 0.7 ? .green : score > 0.4 ? .orange : .red
        return Text(String(format: "%.0f%%", score * 100))
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(.capsule)
    }

    private func healthRow(_ label: String, value: String, status: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text(status)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private var memoryColor: Color {
        switch crashProtection.memoryPressureLevel {
        case .safe: .green
        case .elevated: .yellow
        case .critical: .orange
        case .emergency: .red
        }
    }

    // MARK: - Helpers

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

    private func sessionSortOrder(_ session: ConcurrentSession) -> Int {
        if session.phase.isActive { return 0 }
        if session.phase == .queued { return 1 }
        if session.phase == .failed { return 2 }
        if session.phase == .succeeded { return 3 }
        return 4
    }
}

