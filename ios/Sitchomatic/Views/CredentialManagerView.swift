import SwiftUI

struct CredentialManagerView: View {
    @State private var credentials: [LoginCredential] = PersistenceService.shared.loadCredentials()
    @State private var showAddSheet: Bool = false
    @State private var newUsername: String = ""
    @State private var newPassword: String = ""
    @State private var bulkText: String = ""
    @State private var showBulkImport: Bool = false

    var body: some View {
        List {
            Section {
                ForEach(credentials) { cred in
                    credentialRow(cred)
                }
                .onDelete(perform: deleteCredentials)
            } header: {
                HStack {
                    Text("\(credentials.count) Credentials")
                    Spacer()
                    Text("\(credentials.filter { $0.isEnabled }.count) enabled")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Credentials")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showAddSheet = true } label: {
                        Label("Add Single", systemImage: "plus")
                    }
                    Button { showBulkImport = true } label: {
                        Label("Bulk Import", systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                Form {
                    TextField("Username / Email", text: $newUsername)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $newPassword)
                }
                .navigationTitle("Add Credential")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            let cred = LoginCredential(username: newUsername, password: newPassword)
                            credentials.append(cred)
                            PersistenceService.shared.saveCredentials(credentials)
                            newUsername = ""
                            newPassword = ""
                            showAddSheet = false
                        }
                        .disabled(newUsername.isEmpty || newPassword.isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showBulkImport) {
            NavigationStack {
                Form {
                    Section("Format: username:password (one per line)") {
                        TextEditor(text: $bulkText)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(minHeight: 200)
                    }
                }
                .navigationTitle("Bulk Import")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showBulkImport = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") {
                            importBulk()
                            showBulkImport = false
                        }
                    }
                }
            }
            .presentationDetents([.large])
        }
    }

    private func credentialRow(_ cred: LoginCredential) -> some View {
        HStack {
            Image(systemName: cred.statusIcon)
                .foregroundStyle(credStatusColor(cred))

            VStack(alignment: .leading, spacing: 2) {
                Text(cred.username)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                HStack(spacing: 8) {
                    Text("\(cred.totalAttempts) attempts")
                    if cred.successCount > 0 {
                        Text("\(cred.successCount) success")
                            .foregroundStyle(.green)
                    }
                    if cred.failCount > 0 {
                        Text("\(cred.failCount) fail")
                            .foregroundStyle(.red)
                    }
                    if let outcome = cred.lastOutcome {
                        Text(outcomeShortName(outcome))
                            .foregroundStyle(outcomeColorFromString(outcome))
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { cred.isEnabled },
                set: { newValue in
                    if let idx = credentials.firstIndex(where: { $0.id == cred.id }) {
                        credentials[idx].isEnabled = newValue
                        PersistenceService.shared.saveCredentials(credentials)
                    }
                }
            ))
            .labelsHidden()
        }
    }

    private func credStatusColor(_ cred: LoginCredential) -> Color {
        guard cred.isEnabled else { return .secondary }
        guard let outcome = cred.lastOutcome else { return .green }
        return outcomeColorFromString(outcome)
    }

    private func outcomeShortName(_ raw: String) -> String {
        switch raw {
        case "success": "Success"
        case "noAccount": "No ACC"
        case "permDisabled": "Perm Disabled"
        case "tempDisabled": "Temp Disabled"
        case "unsure": "Needs Review"
        case "error": "Error Found"
        default: raw
        }
    }

    private func outcomeColorFromString(_ raw: String) -> Color {
        switch raw {
        case "success": .green
        case "noAccount": .indigo
        case "permDisabled": .red
        case "tempDisabled": .orange
        case "unsure": .purple
        case "error": .yellow
        default: .secondary
        }
    }

    private func deleteCredentials(at offsets: IndexSet) {
        credentials.remove(atOffsets: offsets)
        PersistenceService.shared.saveCredentials(credentials)
    }

    private func importBulk() {
        let lines = bulkText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        for line in lines {
            let parts = line.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }
            let username = parts[0].trimmingCharacters(in: .whitespaces)
            let password = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            guard !username.isEmpty, !password.isEmpty else { continue }
            credentials.append(LoginCredential(username: username, password: password))
        }
        PersistenceService.shared.saveCredentials(credentials)
        bulkText = ""
    }
}
