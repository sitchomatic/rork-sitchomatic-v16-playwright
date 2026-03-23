import SwiftUI
import UIKit

struct FullTimelineView: View {
    let session: ConcurrentSession

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    timelineHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    if session.logEntries.isEmpty {
                        ContentUnavailableView(
                            "No Timeline",
                            systemImage: "clock.arrow.circlepath",
                            description: Text("This session has no recorded log entries yet.")
                        )
                        .padding(.top, 40)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(session.logEntries.enumerated()), id: \.element.id) { index, entry in
                                timelineNode(entry: entry, index: index, isLast: index == session.logEntries.count - 1)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Full Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var timelineHeader: some View {
        VStack(spacing: 12) {
            HStack {
                if let result = session.dualResult {
                    Image(systemName: result.outcome.iconName)
                        .font(.title2)
                        .foregroundStyle(outcomeColor(result.outcome))
                } else {
                    Image(systemName: session.phase.iconName)
                        .font(.title2)
                        .foregroundStyle(.cyan)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.credential.username)
                        .font(.headline)
                    Text("\(session.logEntries.count) events \u{2022} \(session.elapsedFormatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let result = session.dualResult {
                    Text(result.outcome.longName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(outcomeColor(result.outcome))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(outcomeColor(result.outcome).opacity(0.12), in: .capsule)
                }
            }

            if session.joeScreenshot != nil || session.ignitionScreenshot != nil {
                HStack(spacing: 10) {
                    timelineScreenshot(label: "JOE", data: session.joeScreenshot, outcome: session.dualResult?.joeOutcome)
                    timelineScreenshot(label: "IGN", data: session.ignitionScreenshot, outcome: session.dualResult?.ignitionOutcome)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func timelineScreenshot(label: String, data: Data?, outcome: DualLoginOutcome?) -> some View {
        Group {
            if let data, let uiImage = UIImage(data: data) {
                Color(.tertiarySystemFill)
                    .frame(height: 100)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 4) {
                            if let outcome {
                                Image(systemName: outcome.iconName)
                                    .font(.system(size: 7))
                                    .foregroundStyle(outcomeColor(outcome))
                            }
                            Text(label)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.7), in: .capsule)
                        .padding(6)
                    }
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 100)
                    .overlay {
                        Text(label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.quaternary)
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func timelineNode(entry: SessionLogLine, index: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(categoryColor(entry.category))
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .fill(.white)
                            .frame(width: 4, height: 4)
                    }

                if !isLast {
                    Rectangle()
                        .fill(categoryColor(entry.category).opacity(0.25))
                        .frame(width: 2)
                        .frame(minHeight: 36)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(categoryLabel(entry.category))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(categoryColor(entry.category))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(categoryColor(entry.category).opacity(0.12), in: .capsule)

                    Text(timeString(entry.timestamp))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    if index > 0 {
                        let delta = entry.timestamp.timeIntervalSince(session.logEntries[index - 1].timestamp)
                        Text("+\(String(format: "%.1f", delta))s")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(entry.message)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if entry.category == .result, let result = session.dualResult {
                    HStack(spacing: 10) {
                        resultBadge("Joe", outcome: result.joeOutcome)
                        resultBadge("Ign", outcome: result.ignitionOutcome)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, isLast ? 0 : 12)
        }
    }

    private func resultBadge(_ label: String, outcome: DualLoginOutcome) -> some View {
        HStack(spacing: 4) {
            Image(systemName: outcome.iconName)
                .font(.system(size: 8))
                .foregroundStyle(outcomeColor(outcome))
            Text("\(label): \(outcome.shortName)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(outcomeColor(outcome).opacity(0.08), in: .capsule)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SS"
        return f.string(from: date)
    }

    private func categoryLabel(_ cat: SessionLogLine.Category) -> String {
        switch cat {
        case .phase: "PHASE"
        case .action: "ACTION"
        case .network: "NET"
        case .error: "ERROR"
        case .result: "RESULT"
        }
    }

    private func categoryColor(_ cat: SessionLogLine.Category) -> Color {
        switch cat {
        case .phase: .purple
        case .action: .cyan
        case .network: .blue
        case .error: .red
        case .result: .green
        }
    }

    private func outcomeColor(_ outcome: DualLoginOutcome) -> Color {
        switch outcome {
        case .success: .green
        case .noAccount: .indigo
        case .permDisabled: .red
        case .tempDisabled: .orange
        case .unsure: .purple
        case .error: .yellow
        }
    }
}
