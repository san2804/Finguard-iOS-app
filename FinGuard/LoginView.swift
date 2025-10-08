import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isResetMode = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer(minLength: 40)

                    Image("finguard-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 90)
                        .accessibilityLabel("FinGuard")

                    Text(isResetMode ? "Reset Password" : "Welcome Back")
                        .font(.title3.weight(.bold))
                        .padding(.bottom, 6)

                    // Email
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .fieldStyle()

                    // Password (hidden in reset mode)
                    if !isResetMode {
                        HStack {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                            }
                            Button { showPassword.toggle() } label: {
                                Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .fieldStyle()
                    }

                    // Error
                    if let msg = auth.errorMessage, !msg.isEmpty {
                        Text(msg)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Action button
                    Button {
                        if isResetMode {
                            Task { await auth.sendPasswordReset(email: email) }
                        } else {
                            Task { await auth.signIn(email: email, password: password) }
                        }
                    } label: {
                        HStack {
                            if auth.isLoading { ProgressView().tint(.white) }
                            Text(isResetMode ? "Send Reset Link" : "Sign In")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSubmit ? Color.blue : Color.gray.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canSubmit || auth.isLoading)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)

                    // Toggle reset/login
                    if !isResetMode {
                        Button("Forgot password?") { withAnimation { isResetMode = true } }
                            .font(.footnote)
                            .padding(.top, 4)
                    } else {
                        Button("Back to Login") { withAnimation { isResetMode = false } }
                            .font(.footnote)
                            .padding(.top, 4)
                    }

                    Spacer()

                    // Sign up
                    NavigationLink(destination: SignUpView().environmentObject(auth)) {
                        HStack {
                            Text("Don’t have an account?")
                            Text("Sign up").fontWeight(.semibold).foregroundStyle(.blue)
                        }
                        .font(.footnote)
                    }
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var canSubmit: Bool {
        isResetMode ? email.isValidEmail
                    : (email.isValidEmail && password.count >= 6)
    }
}

// Styling + Email validation
private extension View {
    func fieldStyle() -> some View {
        self
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray5), lineWidth: 1))
            )
            .foregroundStyle(.primary)
    }
}

private extension String {
    var isValidEmail: Bool {
        let regex = #"^\S+@\S+\.\S+$"#
        return range(of: regex, options: .regularExpression) != nil
    }
}
