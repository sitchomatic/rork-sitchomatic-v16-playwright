import SwiftUI
import UIKit

struct DebugContainerView: View {
    @State private var logger = DebugLogger.shared
    @State private var orchestrator = PlaywrightOrchestrator.shared
    @State private var engine = ConcurrentAutomationEngine.shared
    @State private var pool = WebViewPool.shared
    @State private var crashProtection = CrashProtectionService.shared
    @State private var recovery = SessionRecoveryService.shared
    @State private var backgroundService = BackgroundTaskService.shared
    @State private var selectedCategory: DebugLogger.LogCategory?
    @State private var minimumLevel: DebugLogger.LogLevel = .debug
    @State private var searchText: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summarySection
                categoryFilterSection
                levelFilterSection
                logListSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Debug Console")
        .searchable(text: $searchText, prompt: "Search logs")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        logger.clear()
                    } label: {
                        Label("Clear Logs", systemImage: "trash")
                    }

                    Button {
                        UIPasteboard.general.string = logger.exportLog()
                    } label: {
                        Label("Copy All Logs", systemImage: "doc.on.doc")
                    }

                    Button {
                        UIPasteboard.general.string = engine.engineDiagnostics
                    } label: {
                        Label("Copy Engine Diagnostics", systemImage: "gauge.badge.plus")
                    }

                    Button {
                        UIPasteboard.general.string = orchestrator.diagnosticSummary
                    } label: {
                        Label("Copy Orchestrator Diagnostics", systemImage: "stethoscope")
                    }

                    Divider()

                    Button(role: .destructive) {
                        pool.emergencyPurgeAll()
                    } label: {
                        Label("Emergency Purge Pool", systemImage: "exclamationmark.triangle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Diagnostics")
                    .font(.headline)
                Spacer()
                Text("\(filteredEntries.count) lines")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                summaryRow(label: "Engine", value: engine.state.displayName, detail: engine.healthScore.formatted(.percent.precision(.fractionLength(0))), tint: healthColor)
                summaryRow(label: "Memory", value: String(format: "%.0f MB", crashProtection.currentMemoryUsageMB), detail: crashProtection.memoryPressureLevel.rawValue.capitalized, tint: memoryColor)
                summaryRow(label: "Pool", value: "\(pool.activeCount) active", detail: pool.diagnosticSummary, tint: .cyan)
                summaryRow(label: "Recovery", value: recovery.hasResumableCheckpoint() ? "Checkpoint" : "Clear", detail: recovery.diagnosticSummary, tint: recovery.hasResumableCheckpoint() ? .orange : .green)
                summaryRow(label: "Background", value: backgroundLabel, detail: backgroundService.diagnosticSummary, tint: backgroundService.isBackgroundTimeLow ? .orange : .blue)
                summaryRow(label: "Errors", value: "\(logger.recentErrors.count)", detail: orchestrator.networkStatusSummary, tint: logger.recentErrors.isEmpty ? .green : .red)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
    }

    private var categoryFilterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "All", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }

                    ForEach(DebugLogger.LogCategory.allCases, id: \.rawValue) { category in
                        filterChip(title: category.title, isSelected: selectedCategory == category) {
                            selectedCategory = category
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
            }
        }
    }

    private var levelFilterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Minimum Severity")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DebugLogger.LogLevel.allCases, id: \.rawValue) { level in
                        filterChip(title: level.title, isSelected: minimumLevel == level) {
                            minimumLevel = level
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
            }
        }
    }

    private var logListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Log Stream")
                    .font(.headline)
                Spacer()
                Text(searchText.isEmpty ? "Realtime" : "Filtered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if filteredEntries.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Matching Logs" : "No Search Results",
                    systemImage: searchText.isEmpty ? "doc.text.magnifyingglass" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "Adjust severity or category filters to inspect other diagnostic streams." : "Try a different search term or reduce the minimum severity filter.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.regularMaterial, in: .rect(cornerRadius: 20))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredEntries.suffix(300).reversed()) { entry in
                        logEntryCard(entry)
                    }
                }
            }
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? .cyan.opacity(0.16) : .secondary.opacity(0.08), in: .capsule)
                .overlay {
                    Capsule()
                        .stroke(isSelected ? .cyan : .secondary.opacity(0.24), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .cyan : .secondary)
    }

    private func summaryRow(label: String, value: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(tint)
                    .lineLimit(2)
            }

            Spacer()
        }
    }

    private func logEntryCard(_ entry: DebugLogger.LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.level.title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(logColor(entry.level))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(logColor(entry.level).opacity(0.12), in: .capsule)

                Text(entry.category.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Text(entry.message)
                .font(.footnote.monospaced())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
    }

    private var filteredEntries: [DebugLogger.LogEntry] {
        logger.entries
            .filter { entry in
                guard entry.level >= minimumLevel else { return false }
                if let selectedCategory, entry.category != selectedCategory {
                    return false
                }
                if searchText.isEmpty {
                    return true
                }
                let query: String = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else { return true }
                return entry.message.localizedStandardContains(query)
                    || entry.category.title.localizedStandardContains(query)
                    || entry.level.title.localizedStandardContains(query)
            }
    }

    private var healthColor: Color {
        if engine.healthScore > 0.7 { return .green }
        if engine.healthScore > 0.4 { return .orange }
        return .red
    }

    private var memoryColor: Color {
        switch crashProtection.memoryPressureLevel {
        case .safe: .green
        case .elevated: .yellow
        case .critical: .orange
        case .emergency: .red
        }
    }

    private var backgroundLabel: String {
        if backgroundService.remainingBackgroundTime > 900 {
            return "Foreground"
        }
        if backgroundService.remainingBackgroundTime == 0 {
            return "Idle"
        }
        return "\(Int(backgroundService.remainingBackgroundTime))s"
    }

    private func logColor(_ level: DebugLogger.LogLevel) -> Color {
        switch level {
        case .trace: .secondary.opacity(0.55)
        case .debug: .secondary
        case .info: .primary
        case .warning: .orange
        case .error: .red
        case .critical: .red
        }
    }
}
