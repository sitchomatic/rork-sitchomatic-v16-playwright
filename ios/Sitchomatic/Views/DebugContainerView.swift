import SwiftUI

struct DebugContainerView: View {
    @State private var logger = DebugLogger.shared
    @State private var orchestrator = PlaywrightOrchestrator.shared
    @State private var pool = WebViewPool.shared
    @State private var crashProtection = CrashProtectionService.shared
    @State private var selectedCategory: DebugLogger.LogCategory?
    @State private var minimumLevel: DebugLogger.LogLevel = .debug

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            logList
        }
        .navigationTitle("Debug Console")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { logger.clear() } label: {
                        Label("Clear Logs", systemImage: "trash")
                    }
                    Button {
                        UIPasteboard.general.string = logger.exportLog()
                    } label: {
                        Label("Copy All", systemImage: "doc.on.doc")
                    }
                    Divider()
                    Button {
                        UIPasteboard.general.string = orchestrator.diagnosticSummary
                    } label: {
                        Label("Copy Diagnostics", systemImage: "stethoscope")
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

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach([DebugLogger.LogCategory.automation, .webView, .network, .proxy, .crash, .persistence], id: \.rawValue) { cat in
                    filterChip(cat.rawValue.capitalized, isSelected: selectedCategory == cat) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.cyan.opacity(0.2) : Color.clear)
                .clipShape(.capsule)
                .overlay(Capsule().stroke(isSelected ? Color.cyan : Color.secondary.opacity(0.3), lineWidth: 1))
        }
        .foregroundStyle(isSelected ? .cyan : .secondary)
    }

    private var logList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                let filtered = filteredEntries
                if filtered.isEmpty {
                    Text("No log entries")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding()
                } else {
                    ForEach(filtered.suffix(500).reversed()) { entry in
                        Text(entry.formatted)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(logColor(entry.level))
                            .padding(.horizontal)
                            .padding(.vertical, 1)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }

    private var filteredEntries: [DebugLogger.LogEntry] {
        var entries = logger.entries(minLevel: minimumLevel)
        if let cat = selectedCategory {
            entries = entries.filter { $0.category == cat }
        }
        return entries
    }

    private func logColor(_ level: DebugLogger.LogLevel) -> Color {
        switch level {
        case .trace: .secondary.opacity(0.5)
        case .debug: .secondary
        case .info: .primary
        case .warning: .orange
        case .error: .red
        case .critical: .red
        }
    }
}
