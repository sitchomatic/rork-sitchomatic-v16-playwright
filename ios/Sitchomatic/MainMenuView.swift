import SwiftUI

struct MainMenuView: View {
    let onLogout: () -> Void
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "gauge.with.dots.needle.50percent")
            }
            .tag(0)

            NavigationStack {
                DualRunView()
            }
            .tabItem {
                Label("Run", systemImage: "bolt.horizontal.fill")
            }
            .tag(1)

            NavigationStack {
                CredentialManagerView()
            }
            .tabItem {
                Label("Credentials", systemImage: "person.2.fill")
            }
            .tag(2)

            NavigationStack {
                DebugContainerView()
            }
            .tabItem {
                Label("Debug", systemImage: "ant.fill")
            }
            .tag(3)

            NavigationStack {
                SettingsView(onLogout: onLogout)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(4)
        }
        .tint(.cyan)
    }
}
