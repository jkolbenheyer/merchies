import SwiftUI

struct AuthView: View {
    @State private var isSignIn = true
    @State private var email = ""
    @State private var password = ""
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                // Black background
                Color.black
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Logo image
                        Image("MerchiesLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 100)
                            .padding(.top, 50)
                        
                        // Form
                        VStack(spacing: 15) {
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            if isSignIn {
                                SecureField("Password", text: $password)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            } else {
                                SecureField("Create Password", text: $password)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            
                            // Primary button
                            Button(action: {
                                if isSignIn {
                                    authViewModel.signInWithEmail(email: email, password: password)
                                } else {
                                    authViewModel.createAccount(email: email, password: password)
                                }
                            }) {
                                Text(isSignIn ? "Sign In" : "Create Account")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .cornerRadius(8)
                            }
                            .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)
                            
                            // Sign in with Apple button
                            Button(action: {
                                authViewModel.signInWithApple()
                            }) {
                                HStack {
                                    Image(systemName: "apple.logo")
                                    Text("Sign in with Apple")
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.black)
                                .cornerRadius(8)
                            }
                            
                            // Toggle between sign in and create account
                            Button(action: {
                                isSignIn.toggle()
                                // Clear fields when switching modes
                                email = ""
                                password = ""
                            }) {
                                Text(isSignIn ? "Need an account? Sign Up" : "Already have an account? Sign In")
                                    .foregroundColor(.purple)
                            }
                            .padding(.top, 10)
                            
                            if isSignIn {
                                Button("Forgot Password?") {
                                    if !email.isEmpty {
                                        authViewModel.sendPasswordReset(email: email) { success in
                                            // Show success message
                                        }
                                    }
                                }
                                .foregroundColor(.purple)
                                .padding(.top, 5)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                }
                .navigationBarHidden(true)
                
                .overlay(
                    Group {
                        if authViewModel.isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(10)
                                .frame(width: 80, height: 80)
                        }
                    }
                )
            }
        }
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
            .environmentObject(AuthViewModel())
    }
}
