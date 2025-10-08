import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // Persisted preferences
    @AppStorage("currencyCode") private var currencyCode: String = "LKR"
    @AppStorage("useDarkMode")  private var useDarkMode: Bool = false
    @AppStorage("notificationsOn") private var notificationsOn: Bool = true

    private let supportedCurrencies = ["LKR", "USD", "EUR", "INR"]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Account")) {
                    HStack {
                        AvatarView(url: auth.user?.photoURL,
                                   name: auth.user?.displayName ?? "You",
                                   size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.user?.displayName ?? "User").font(.headline)
                            Text(auth.user?.email ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section(header: Text("Preferences"),
                        footer: Text("Currency affects how amounts are formatted across the app.")) {
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(supportedCurrencies, id: \.self) { Text($0).tag($0) }
                    }
                    Toggle("Notifications", isOn: $notificationsOn)
                    Toggle("Dark Mode", isOn: $useDarkMode)
                }

                Section {
                    Button(role: .destructive) {
                        auth.signOut()
                        dismiss() // close settings after sign out
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}
