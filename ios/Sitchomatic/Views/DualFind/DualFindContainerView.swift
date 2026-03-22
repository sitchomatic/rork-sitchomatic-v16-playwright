import SwiftUI

struct DualFindContainerView: View {
    @State private var orchestrator = PlaywrightOrchestrator.shared
    @State private var isSearching: Bool = false
    @State private var searchURL: String = ""
    @State private var searchSelector: String = ""
    @State private var results: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Dual Find", systemImage: "magnifyingglass.circle.fill")
                        .font(.headline)

                    TextField("URL to search", text: $searchURL)
                        .font(.system(size: 13, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("CSS Selector", text: $searchSelector)
                        .font(.system(size: 13, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        Task { await performSearch() }
                    } label: {
                        HStack {
                            if isSearching {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(isSearching ? "Searching..." : "Search")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.cyan)
                        .foregroundStyle(.black)
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .disabled(searchURL.isEmpty || searchSelector.isEmpty || isSearching)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(.rect(cornerRadius: 16))

                if !results.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Results (\(results.count))")
                            .font(.headline)

                        ForEach(results, id: \.self) { result in
                            Text(result)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(.rect(cornerRadius: 8))
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(cornerRadius: 16))
                }
            }
            .padding()
        }
        .navigationTitle("Dual Find")
    }

    private func performSearch() async {
        isSearching = true
        results.removeAll()

        do {
            if !orchestrator.isReady {
                try await orchestrator.startSession()
            }

            let page = try await orchestrator.newPage()
            try await page.goto(searchURL)

            let count = try await page.locator(searchSelector).count()
            results.append("Found \(count) element(s) matching '\(searchSelector)'")

            if count > 0 {
                let text = try await page.locator(searchSelector).first().textContent()
                results.append("First element text: \(String(text.prefix(200)))")

                let isVis = try await page.locator(searchSelector).first().isVisible()
                results.append("First element visible: \(isVis)")
            }

            orchestrator.closePage(page)
        } catch {
            results.append("Error: \(error.localizedDescription)")
        }

        isSearching = false
    }
}
