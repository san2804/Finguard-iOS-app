import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSecure: Bool = true
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(colors: [Color.blue.opacity(0.9), Color.purple.opacity(0.8)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // App Title / Logo
                VStack(spacing: 10) {
                    Image(systemName: "shield.checkerboard")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .padding()
                    
                    Text("FinGuard")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                }
                
                // Input fields
                VStack(spacing: 20) {
                    // Email field
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                    
                    // Password field with toggle
                    HStack {
                        if isSecure {
                            SecureField("Password", text: $password)
                                .padding()
                                .foregroundColor(.white)
                        } else {
                            TextField("Password", text: $password)
                                .padding()
                                .foregroundColor(.white)
                        }
                        
                        Button(action: { isSecure.toggle() }) {
                            Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.trailing, 8)
                    }
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 30)
                
                // Login button
                Button(action: {
                    print("Login tapped")
                }) {
                    Text("Login")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.85))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 30)
                
                // Forgot Password
                Button(action: {
                    print("Forgot password tapped")
                }) {
                    Text("Forgot Password?")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.footnote)
                }
                
                Spacer()
                
                // Sign up option
                HStack {
                    Text("Don’t have an account?")
                        .foregroundColor(.white.opacity(0.9))
                    
                    Button(action: {
                        print("Sign Up tapped")
                    }) {
                        Text("Sign Up")
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                    }
                }
            }
            .padding(.top, 80)
        }
    }
}

#Preview {
    LoginView()
}
