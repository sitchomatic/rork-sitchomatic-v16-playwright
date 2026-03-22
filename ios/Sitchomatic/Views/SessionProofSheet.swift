import SwiftUI
import UIKit

struct SessionProofSheet: View {
    let session: ConcurrentSession

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
                    logTimeline
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

    // MARK: - Header

    private var sessionHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: session.phase.iconName)
                    .font(.system(size: 28))
                    .foregroundStyle(phaseColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.credential.username)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                    Text(session.credential.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(session.phase.displayName.uppercased())
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(phaseColor)
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

    // MARK: - Screenshot Proof

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
                    Circle()
                        .fill(outcomeColor(outcome))
                        .frame(width: 6, height: 6)
                }
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                Spacer()
                if let outcome {
                    Text(outcome.rawValue)
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

    // MARK: - Dual Result Breakdown

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
                resultRow("Combined", value: result.outcome.rawValue, color: outcomeColor(result.outcome))
                resultRow("Joe Fortune", value: result.joeOutcome.rawValue, color: outcomeColor(result.joeOutcome))
                resultRow("Ignition", value: result.ignitionOutcome.rawValue, color: outcomeColor(result.ignitionOutcome))
                resultRow("Duration", value: String(format: "%.2fs", result.duration), color: .secondary)
                resultRow("Proxy", value: result.proxyUsed, color: .secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private func resultRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    // MARK: - Error Card

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

    // MARK: - Log Timeline

    private var logTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.cyan)
                Text("TIMELINE (\(session.logEntries.count))")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if session.logEntries.isEmpty {
                Text("No log entries recorded")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(session.logEntries) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(logCategoryColor(entry.category))
                                .frame(width: 5, height: 5)
                                .padding(.top, 5)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.formatted)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 12))
            }
        }
    }

    // MARK: - Helpers

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
        case .permDisabled: .red
        case .tempDisabled: .orange
        case .networkError: .yellow
        case .crashed: .red
        case .unsure: .purple
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
