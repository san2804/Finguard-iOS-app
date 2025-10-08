//
//  SignUpView.swift
//  FinGuard
//

import SwiftUI
import PhotosUI   // for profile image picking

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthViewModel

    // MARK: - Form fields
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    // MARK: - Profile image
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: UIImage?

    // MARK: - UI state
    @State private var showPassword = false
    @State private var showConfirmPassword = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        // MARK: - Header
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        Image("finguard-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 70)
                            .padding(.top, 10)
                        Text("Create Your Account")
                            .font(.title3.weight(.bold))

                        // MARK: - Profile Picker
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            ZStack {
                                if let image = profileImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 30))
                                                .foregroundColor(.gray)
                                        )
                                }
                            }
                        }
                        .onChange(of: selectedItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    profileImage = uiImage
                                }
                            }
                        }

                        // MARK: - Form
                        VStack(spacing: 14) {
                            TextField("Full name", text: $fullName)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .fieldStyle()

                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .fieldStyle()

                            // Password
                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("Password", text: $password)
                                    } else {
                                        SecureField("Password", text: $password)
                                    }
                                }
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .fieldStyle()

                            // Confirm Password
                            HStack {
                                Group {
                                    if showConfirmPassword {
                                        TextField("Confirm Password", text: $confirmPassword)
                                    } else {
                                        SecureField("Confirm Password", text: $confirmPassword)
                                    }
                                }
                                Button {
                                    showConfirmPassword.toggle()
                                } label: {
                                    Image(systemName: showConfirmPassword ? "eye.fill" : "eye.slash.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .fieldStyle()
                        }
                        .padding(.horizontal, 20)

                        // MARK: - Error Messages
                        VStack(alignment: .leading, spacing: 6) {
                            if !email.isEmpty && !email.isValidEmail {
                                Text("Please enter a valid email.")
                                    .font(.footnote)
                                    .foregroundColor(.red)
                            }
                            if !password.isEmpty && password.count < 6 {
                                Text("Password must be at least 6 characters.")
                                    .font(.footnote)
                                    .foregroundColor(.red)
                            }
                            if !confirmPassword.isEmpty && confirmPassword != password {
                                Text("Passwords don’t match.")
                                    .font(.footnote)
                                    .foregroundColor(.red)
                            }
                            if let msg = auth.errorMessage, !msg.isEmpty {
                                Text(msg)
                                    .font(.footnote)
                                    .foregroundColor(.red)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                        // MARK: - Create Account Button
                        Button {
                            Task {
                                await auth.signUp(email: email, password: password, displayName: fullName)
                                if auth.isSignedIn {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                if auth.isLoading { ProgressView().tint(.white) }
                                Text("Create Account")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canSubmit ? Color.green : Color.gray.opacity(0.4))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!canSubmit || auth.isLoading)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)

                        // MARK: - Sign In Link
                        HStack {
                            Text("Already have an account?")
                            Button("Sign In") {
                                dismiss()
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                        }
                        .font(.footnote)
                        .padding(.bottom, 30)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Validation
    private var canSubmit: Bool {
        email.isValidEmail &&
        password.count >= 6 &&
        confirmPassword == password &&
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Field Style Modifier
private extension View {
    func fieldStyle() -> some View {
        self
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
            )
            .foregroundStyle(.primary)
    }
}

// MARK: - Email validation
private extension String {
    var isValidEmail: Bool {
        let regex = #"^\S+@\S+\.\S+$"#
        return range(of: regex, options: .regularExpression) != nil
    }
}

// MARK: - Preview
#Preview {
    SignUpView()
        .environmentObject(AuthViewModel())
}
