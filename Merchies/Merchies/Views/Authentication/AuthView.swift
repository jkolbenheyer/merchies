import SwiftUI
import Foundation
import AuthenticationServices

struct AuthView: View {
    @State private var isSignIn = true
    @State private var email = ""
    @State private var password = ""
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(spacing: 20) {
                        // Merchies logo
                        Image("MerchiesLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .padding(.top, 50)

                        // Authentication options
                        VStack(spacing: 20) {
                            // Apple Sign In (Primary option)
                            Button(action: {
                                authViewModel.signInWithApple()
                            }) {
                                HStack {
                                    Image(systemName: "apple.logo")
                                        .font(.title2)
                                    Text("Sign in with Apple")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(Color.black)
                                .cornerRadius(8)
                            }
                            
                            HStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.5))
                                    .frame(height: 1)
                                Text("or")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.5))
                                    .frame(height: 1)
                            }
                            .padding(.vertical, 8)
                            
                            // Email/Password form
                            VStack(spacing: 15) {
                                TextField("Email", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)

                                SecureField(isSignIn ? "Password" : "Create Password", text: $password)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)

                                Button(action: {
                                    if isSignIn {
                                        authViewModel.signInWithEmail(email: email, password: password)
                                    } else {
                                        authViewModel.createAccount(email: email, password: password)
                                    }
                                }) {
                                    Text(isSignIn ? "Sign In with Email" : "Create Account with Email")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.cyan)
                                        .cornerRadius(8)
                                }
                                .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)
                            }

                            Button(action: {
                                isSignIn.toggle()
                                email = ""
                                password = ""
                            }) {
                                Text(isSignIn ? "Need an account? Sign Up" : "Already have an account? Sign In")
                                    .foregroundColor(.cyan)
                            }
                            .padding(.top, 10)

                            if isSignIn {
                                Button("Forgot Password?") {
                                    if !email.isEmpty {
                                        authViewModel.sendPasswordReset(email: email) { _ in }
                                    }
                                }
                                .foregroundColor(.cyan)
                                .padding(.top, 5)
                            }
                        }
                        .padding(.horizontal)

                        Spacer()
                    }
                }

                if authViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                        .frame(width: 80, height: 80)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                }
            }
            .navigationBarHidden(true)
        }
    }
}
