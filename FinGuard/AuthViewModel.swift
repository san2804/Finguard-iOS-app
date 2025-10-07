import Foundation
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var user: User?  // Firebase user

    init() {
        // Listen to auth state changes
        Auth.auth().addStateDidChangeListener { _, user in
            self.user = user
        }
    }

    func signIn(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."
            return
        }
        isLoading = true; defer { isLoading = false }
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.user = result.user
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        isLoading = true; defer { isLoading = false }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.user = result.user
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func sendPasswordReset(email: String) async {
        do { try await Auth.auth().sendPasswordReset(withEmail: email) }
        catch { errorMessage = error.localizedDescription }
    }

    func signOut() {
        try? Auth.auth().signOut()
        self.user = nil
    }
}
