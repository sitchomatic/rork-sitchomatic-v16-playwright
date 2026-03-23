import SwiftUI

struct MainMenuView: View {
    @State private var selectedTab: AppTab = .dashboard
    @State private var logger = DebugLogger.shared

    var body: some View {
        ZStack {
            Image("MainMenuWallpaper")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.16), location: 0),
                    .init(color: .black.opacity(0.38), location: 0.28),
                    .init(color: .black.opacity(0.82), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            TabView(selection: $selectedTab) {
                Tab("Dashboard", systemImage: "gauge.with.dots.needle.50percent", value: AppTab.dashboard) {
                    NavigationStack {
                        DashboardView(selectedTab: $selectedTab)
                    }
                }

                Tab("Run", systemImage: "bolt.horizontal.fill", value: AppTab.run) {
                    NavigationStack {
                        DualRunView()
                    }
                }

                Tab("Credentials", systemImage: "person.2.fill", value: AppTab.credentials) {
                    NavigationStack {
                        CredentialManagerView()
                    }
                }

                Tab("Debug", systemImage: "ant.fill", value: AppTab.debug) {
                    NavigationStack {
                        DebugContainerView()
                    }
                }
                .badge(logger.recentErrors.isEmpty ? 0 : logger.recentErrors.count)

                Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                    NavigationStack {
                        SettingsView()
                    }
                }
            }
            .toolbar(.visible, for: .tabBar)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)
        }
        .tint(.cyan)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}
