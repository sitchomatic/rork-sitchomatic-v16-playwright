import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated: Bool = UserDefaults.standard.bool(forKey: "sitchomatic.authenticated")

    var body: some View {
        if isAuthenticated {
            MainMenuView(onLogout: {
                isAuthenticated = false
                UserDefaults.standard.set(false, forKey: "sitchomatic.authenticated")
            })
        } else {
            LoginContentView(onLogin: {
                isAuthenticated = true
                UserDefaults.standard.set(true, forKey: "sitchomatic.authenticated")
            })
        }
    }
}
