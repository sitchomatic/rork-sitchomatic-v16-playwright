import SwiftUI

struct FlowRecorderContainerView: View {
    @State private var recorder = RecordingSession()
    @State private var showGeneratedCode: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                controlBar

                if !recorder.actions.isEmpty {
                    actionList
                }

                if showGeneratedCode {
                    codePreview
                }
            }
            .padding()
        }
        .navigationTitle("Flow Recorder")
    }

    private var controlBar: some View {
        VStack(spacing: 12) {
            HStack {
                if recorder.isRecording {
                    Circle()
                        .fill(.red)
                        .frame(width: 12, height: 12)
                    Text("Recording (\(recorder.actionCount) actions)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                } else {
                    Circle()
                        .fill(.gray)
                        .frame(width: 12, height: 12)
                    Text("Idle")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }

                Spacer()

                HStack(spacing: 12) {
                    if recorder.isRecording {
                        Button { recorder.stopRecording() } label: {
                            Image(systemName: "stop.fill")
                                .foregroundStyle(.red)
                        }
                    } else {
                        Button { recorder.startRecording() } label: {
                            Image(systemName: "record.circle")
                                .foregroundStyle(.red)
                        }
                    }

                    Button { showGeneratedCode.toggle() } label: {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                    }
                    .disabled(recorder.actions.isEmpty)

                    Button { recorder.clearActions() } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .disabled(recorder.actions.isEmpty)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var actionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recorded Actions")
                .font(.headline)

            ForEach(recorder.actions) { action in
                HStack(spacing: 8) {
                    Image(systemName: action.iconName)
                        .foregroundStyle(.cyan)
                        .frame(width: 20)
                    Text(action.displayDescription)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var codePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Generated Swift Code")
                    .font(.headline)
                Spacer()
                Button {
                    UIPasteboard.general.string = recorder.generatedCode
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 12))
                }
            }

            Text(recorder.generatedCode)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.green)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black)
                .clipShape(.rect(cornerRadius: 12))
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 16))
    }
}
