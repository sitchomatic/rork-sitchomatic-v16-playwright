import SwiftUI

struct MainMenuView: View {
    let onLogout: () -> Void

    @State private var orchestrator = PlaywrightOrchestrator.shared
    @State private var engine = ConcurrentAutomationEngine.shared
    @State private var settings = AutomationSettings.shared
    @State private var selectedTab: MenuTab = .dashboard

    enum MenuTab: String, CaseIterable {
        case dashboard, credentials, dualRun, dualFind, recorder, debug, settings

        var label: String {
            switch self {
            case .dashboard: "Dashboard"
            case .credentials: "Credentials"
            case .dualRun: "Dual Run"
            case .dualFind: "Dual Find"
            case .recorder: "Recorder"
            case .debug: "Debug"
            case .settings: "Settings"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: "gauge.with.dots.needle.50percent"
            case .credentials: "person.2.fill"
            case .dualRun: "bolt.horizontal.fill"
            case .dualFind: "magnifyingglass.circle.fill"
            case .recorder: "record.circle"
            case .debug: "ant.fill"
            case .settings: "gearshape.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Image("MainMenuWallpaper")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.35), location: 0),
                        .init(color: .black.opacity(0.55), location: 0.4),
                        .init(color: .black.opacity(0.8), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 20) {
                        statusHeader

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(MenuTab.allCases, id: \.self) { tab in
                                menuCard(tab)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Sitchomatic v16")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onLogout()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationDestination(for: MenuTab.self) { tab in
                destinationView(for: tab)
            }
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(orchestrator.isReady ? .green : .red)
                    .frame(width: 10, height: 10)
                Text(orchestrator.isReady ? "Session Active" : "Session Inactive")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("DUAL MODE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.cyan.opacity(0.2))
                    .clipShape(.capsule)
            }

            HStack(spacing: 16) {
                statusPill(icon: "network", value: "\(orchestrator.activeProxyCount)", label: "Proxies")
                statusPill(icon: "globe", value: "\(orchestrator.pages.count)", label: "Pages")
                statusPill(icon: "person.2", value: "\(orchestrator.activePairedSessions)", label: "Pairs")
                statusPill(icon: "checkmark.circle", value: "\(orchestrator.totalCredentialsProcessed)", label: "Done")
            }

            if engine.isRunning {
                VStack(spacing: 4) {
                    ProgressView(value: engine.overallProgress)
                        .tint(.cyan)
                    HStack {
                        Text("Wave \(engine.currentWave)/\(engine.totalWaves)")
                        Spacer()
                        Text("\(engine.succeededCount)✓ \(engine.failedCount)✗")
                        Spacer()
                        Text(engine.elapsedFormatted)
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                }
            }

            if engine.healthScore < 0.5 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("Engine health: \(String(format: "%.0f", engine.healthScore * 100))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.thinMaterial.opacity(0.9))
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func statusPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func menuCard(_ tab: MenuTab) -> some View {
        NavigationLink(value: tab) {
            VStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(.cyan)
                Text(tab.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private func destinationView(for tab: MenuTab) -> some View {
        switch tab {
        case .dashboard:
            DashboardView()
        case .credentials:
            CredentialManagerView()
        case .dualRun:
            DualRunView()
        case .dualFind:
            DualFindContainerView()
        case .recorder:
            FlowRecorderContainerView()
        case .debug:
            DebugContainerView()
        case .settings:
            SettingsView(onLogout: onLogout)
        }
    }
}
