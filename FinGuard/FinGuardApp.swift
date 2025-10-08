//
//  FinGuardApp.swift
//  FinGuard
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct FinGuardApp: App {
    @StateObject private var auth = AuthViewModel()
    @AppStorage("useDarkMode") private var useDarkMode: Bool = false 

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .preferredColorScheme(useDarkMode ? .dark : .light)
        }
    }
}

// MARK: - RootView

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var isCheckingAuth = true

    var body: some View {
        Group {
            if isCheckingAuth {
                VStack {
                    ProgressView("Checking session...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                }
            } else if auth.user == nil {
                LoginView()
                    .transition(.opacity)
            } else {
                HomeView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            Task {
                await checkAuthState()
            }
        }
        .animation(.easeInOut, value: auth.user != nil)
    }

    private func checkAuthState() async {
        // Wait briefly to ensure Firebase listener fires
        try? await Task.sleep(nanoseconds: 500_000_000)
        isCheckingAuth = false
    }
}
