//
//  AuthViewModel.swift
//  FinGuard
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Published state
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var user: FirebaseAuth.User?

    // MARK: - Derived (handy for UI)
    var isSignedIn: Bool { user != nil }
    var displayName: String {
        let name = user?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return name }
        // fall back to email’s local part
        if let email = user?.email, let local = email.split(separator: "@").first {
            return String(local)
        }
        return "User"
    }
    var photoURL: URL? { user?.photoURL }

    // MARK: - Listener
    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.user = user
            }
        }
        // pick up existing session on launch
        self.user = Auth.auth().currentUser
    }

    deinit {
        if let h = handle { Auth.auth().removeStateDidChangeListener(h) }
    }

    // MARK: - Auth actions

    func signIn(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required."
            return
        }
        errorMessage = nil
        isLoading = true; defer { isLoading = false }

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.user = result.user
        } catch {
            self.errorMessage = (error as NSError).localizedDescription
        }
    }

    /// Creates the account and sets the user’s display name.
    func signUp(email: String, password: String, displayName: String) async {
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters long."
            return
        }
        errorMessage = nil
        isLoading = true; defer { isLoading = false }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            // Update profile with the display name (optional, but your UI uses it)
            let change = result.user.createProfileChangeRequest()
            change.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            try await change.commitChanges()
            try await result.user.reload()
            self.user = Auth.auth().currentUser
        } catch {
            self.errorMessage = (error as NSError).localizedDescription
        }
    }

    func sendPasswordReset(email: String) async {
        guard !email.isEmpty else {
            errorMessage = "Enter your email address."
            return
        }
        errorMessage = nil
        isLoading = true; defer { isLoading = false }

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            self.errorMessage = (error as NSError).localizedDescription
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
        } catch {
            self.errorMessage = (error as NSError).localizedDescription
        }
    }
}
