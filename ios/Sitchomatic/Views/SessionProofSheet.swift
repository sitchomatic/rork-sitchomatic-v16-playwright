import SwiftUI
import UIKit

struct SessionProofSheet: View {
    let session: ConcurrentSession
    @State private var showFullTimeline: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sessionHeader
                    screenshotProofSection
                    if let result = session.dualResult {
                        dualResultBreakdown(result)
                    }
                    if let error = session.errorMessage {
                        errorCard(error)
                    }
                    actionBar
                    enhancedTimeline
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Session Proof")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
    }

    private var sessionHeader: some View {
        VStack(spacing: 12) {
            HStack {
                if let result = session.dualResult {
                    Image(systemName: result.outcome.iconName)
                        .font(.system(size: 28))
                        .foregroundStyle(outcomeColor(result.outcome))
                } else {
                    Image(systemName: session.phase.iconName)
                        .font(.system(size: 28))
                        .foregroundStyle(phaseColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(session.credential.username)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                        if session.isFlaggedForReview {
                            Image(systemName: "flag.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                    Text(session.credential.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if let result = session.dualResult {
                        Text(result.outcome.shortName.uppercased())
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(outcomeColor(result.outcome))
                    } else {
                        Text(session.phase.displayName.uppercased())
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(phaseColor)
                    }
                    Text(session.elapsedFormatted)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                metaChip(icon: "network", text: session.proxyInfo)
                metaChip(icon: "square.stack.3d.up", text: "Wave \(session.waveIndex + 1)")
                if session.retryCount > 0 {
                    metaChip(icon: "arrow.clockwise", text: "\(session.retryCount) retries")
                }
            }

            if session.totalSteps > 0 {
                VStack(spacing: 4) {
                    ProgressView(value: session.progress)
                        .tint(phaseColor)
                    Text("\(session.stepsCompleted)/\(session.totalSteps) steps")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemFill))
        .clipShape(.capsule)
    }

    private var screenshotProofSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "camera.viewfinder")
                    .foregroundStyle(.cyan)
                Text("PROOF SCREENSHOTS")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                proofCard(
                    title: "Joe Fortune",
                    data: session.joeScreenshot,
                    outcome: session.dualResult?.joeOutcome
                )
                proofCard(
                    title: "Ignition Casino",
                    data: session.ignitionScreenshot,
                    outcome: session.dualResult?.ignitionOutcome
                )
            }
        }
    }

    private func proofCard(title: String, data: Data?, outcome: DualLoginOutcome?) -> some View {
        VStack(spacing: 0) {
            if let data, let uiImage = UIImage(data: data) {
                Color(.secondarySystemGroupedBackground)
                    .frame(height: 160)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(topLeadingRadius: 12, topTrailingRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 160)
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20))
                            Text("Awaiting Proof")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.tertiary)
                    }
                    .clipShape(.rect(topLeadingRadius: 12, topTrailingRadius: 12))
            }

            HStack(spacing: 4) {
                if let outcome {
                    Image(systemName: outcome.iconName)
                        .font(.system(size: 8))
                        .foregroundStyle(outcomeColor(outcome))
                }
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                Spacer()
                if let outcome {
                    Text(outcome.shortName)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(outcomeColor(outcome))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(bottomLeadingRadius: 12, bottomTrailingRadius: 12))
        }
        .frame(maxWidth: .infinity)
    }

    private func dualResultBreakdown(_ result: DualLoginResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundStyle(.cyan)
                Text("RESULT BREAKDOWN")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                resultRow("Combined", value: result.outcome.longName, icon: result.outcome.iconName, color: outcomeColor(result.outcome))
                resultRow("Joe Fortune", value: result.joeOutcome.longName, icon: result.joeOutcome.iconName, color: outcomeColor(result.joeOutcome))
                resultRow("Ignition", value: result.ignitionOutcome.longName, icon: result.ignitionOutcome.iconName, color: outcomeColor(result.ignitionOutcome))
                resultRow("Duration", value: String(format: "%.2fs", result.duration), icon: "clock", color: .secondary)
                resultRow("Proxy", value: result.proxyUsed, icon: "network", color: .secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private func resultRow(_ label: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color)
            }
        }
    }

    private func errorCard(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(error)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.red)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if session.phase == .failed {
                Button {
                    ConcurrentAutomationEngine.shared.enqueueRetry(session.credential)
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

    private var enhancedTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.cyan)
                Text("TIMELINE (\(session.logEntries.count))")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                if !session.logEntries.isEmpty {
                    Button {
                        showFullTimeline = true
                    } label: {
                        Label("Full Timeline", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.cyan)
                }
            }

            if session.logEntries.isEmpty {
                Text("No log entries recorded")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(session.logEntries.prefix(20).enumerated()), id: \.element.id) { index, entry in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(logCategoryColor(entry.category))
                                    .frame(width: 8, height: 8)
                                if index < min(session.logEntries.count, 20) - 1 {
                                    Rectangle()
                                        .fill(logCategoryColor(entry.category).opacity(0.2))
                                        .frame(width: 1.5)
                                        .frame(minHeight: 20)
                                }
                            }
                            .frame(width: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(entry.category.rawValue.uppercased())
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(logCategoryColor(entry.category))
                                    Text(timeOnly(entry.timestamp))
                                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                    if index > 0 {
                                        let delta = entry.timestamp.timeIntervalSince(session.logEntries[index - 1].timestamp)
                                        Text("+\(String(format: "%.1f", delta))s")
                                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text(entry.message)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                            }
                            .padding(.bottom, 6)
                        }
                    }

                    if session.logEntries.count > 20 {
                        Button {
                            showFullTimeline = true
                        } label: {
                            Text("\(session.logEntries.count - 20) more entries...")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.cyan)
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
        .fullScreenCover(isPresented: $showFullTimeline) {
            FullTimelineView(session: session)
        }
    }

    private func timeOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private var phaseColor: Color {
        switch session.phase {
        case .succeeded: .green
        case .failed: .red
        case .cancelled: .gray
        case .queued: .secondary
        default: .cyan
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

    private func logCategoryColor(_ category: SessionLogLine.Category) -> Color {
        switch category {
        case .phase: .purple
        case .action: .cyan
        case .network: .blue
        case .error: .red
        case .result: .green
        }
    }
}
