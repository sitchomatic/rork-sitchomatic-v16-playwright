import SwiftUI

struct DashboardView: View {
    @State private var orchestrator = PlaywrightOrchestrator.shared
    @State private var engine = ConcurrentAutomationEngine.shared
    @State private var pool = WebViewPool.shared
    @State private var crashProtection = CrashProtectionService.shared
    @State private var logger = DebugLogger.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                systemStatusCard
                engineStatusCard
                poolStatusCard
                memoryStatusCard
                recentLogsCard
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
    }

    private var systemStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("System Status", systemImage: "gauge.with.dots.needle.50percent")
                .font(.headline)

            VStack(spacing: 8) {
                statusRow("Orchestrator", value: orchestrator.isReady ? "Ready" : "Inactive", color: orchestrator.isReady ? .green : .red)
                statusRow("Mode", value: "Permanent Dual", color: .cyan)
                statusRow("Speed", value: orchestrator.currentSpeedMode.displayName, color: .orange)
                statusRow("Network", value: orchestrator.connectionStatus.displayName, color: orchestrator.connectionStatus == .connected ? .green : .red)
                statusRow("Proxies", value: "\(orchestrator.activeProxyCount)", color: .blue)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var engineStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Engine", systemImage: "bolt.horizontal.fill")
                .font(.headline)

            VStack(spacing: 8) {
                statusRow("State", value: engine.state.rawValue.capitalized, color: engine.isRunning ? .green : .secondary)
                statusRow("Sessions", value: "\(engine.sessions.count)", color: .blue)
                statusRow("Succeeded", value: "\(engine.succeededCount)", color: .green)
                statusRow("Failed", value: "\(engine.failedCount)", color: .red)
                statusRow("Wave", value: "\(engine.currentWave)/\(engine.totalWaves)", color: .purple)
                if engine.isRunning {
                    ProgressView(value: engine.overallProgress)
                        .tint(.cyan)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var poolStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("WebView Pool", systemImage: "square.stack.3d.up")
                .font(.headline)

            Text(pool.diagnosticSummary)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var memoryStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Memory", systemImage: "memorychip")
                .font(.headline)

            Text(crashProtection.diagnosticSummary)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)

            HStack {
                Circle()
                    .fill(crashProtection.isMemorySafeForNewSession ? .green : crashProtection.isMemoryCritical ? .red : .orange)
                    .frame(width: 8, height: 8)
                Text(crashProtection.isMemorySafeForNewSession ? "Safe" : crashProtection.isMemoryCritical ? "Critical" : "High")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var recentLogsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent Logs", systemImage: "list.bullet.rectangle")
                .font(.headline)

            if orchestrator.sessionLog.isEmpty {
                Text("No log entries yet")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(orchestrator.sessionLog.suffix(10).reversed()) { entry in
                    Text(entry.formatted)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func statusRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}
