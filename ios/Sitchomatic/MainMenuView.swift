import SwiftUI

struct MainMenuView: View {
    let onLogout: () -> Void

    @State private var selectedTab: AppTab = .dashboard
    @State private var logger = DebugLogger.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "gauge.with.dots.needle.50percent", value: .dashboard) {
                NavigationStack {
                    DashboardView(selectedTab: $selectedTab)
                }
            }

            Tab("Run", systemImage: "bolt.horizontal.fill", value: .run) {
                NavigationStack {
                    DualRunView()
                }
            }

            Tab("Credentials", systemImage: "person.2.fill", value: .credentials) {
                NavigationStack {
                    CredentialManagerView()
                }
            }

            Tab("Debug", systemImage: "ant.fill", value: .debug) {
                NavigationStack {
                    DebugContainerView()
                }
            }
            .badge(logger.recentErrors.isEmpty ? 0 : logger.recentErrors.count)

            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                NavigationStack {
                    SettingsView(onLogout: onLogout)
                }
            }
        }
        .tint(.cyan)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}
