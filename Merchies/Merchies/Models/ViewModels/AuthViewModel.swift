// Models/ViewModels/AuthViewModel.swift
import Foundation
import Firebase
import FirebaseAuth
import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit

enum AuthState {
    case signedIn
    case signedOut
}

class AuthViewModel: NSObject, ObservableObject {
    @Published var user: User?
    @Published var authState: AuthState = .signedOut
    @Published var userRole: UserRole = .fan
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var profileImageUpdateTrigger = UUID()
    
    private var handle: AuthStateDidChangeListenerHandle?
    
    // Apple Sign In
    private var currentNonce: String?
    
    override init() {
        super.init()
        setupAuthListener()
    }
    
    func setupAuthListener() {
        handle = Auth.auth().addStateDidChangeListener { (auth: Auth, user: User?) in
            self.user = user
            self.authState = user != nil ? .signedIn : .signedOut
            
            if let user = user {
                self.fetchUserRole(userId: user.uid)
            }
        }
    }
    
    func fetchUserRole(userId: String) {
        isLoading = true
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).getDocument { (document: DocumentSnapshot?, error: Error?) in
            self.isLoading = false
            
            if let error = error {
                self.error = "Error fetching user role: \(error.localizedDescription)"
                return
            }
            
            if let document = document, document.exists,
               let roleString = document.data()?["role"] as? String,
               let role = UserRole(rawValue: roleString) {
                self.userRole = role
            } else {
                // Default to fan role
                self.userRole = .fan
                // Create user document if it doesn't exist
                db.collection("users").document(userId).setData([
                    "role": UserRole.fan.rawValue,
                    "createdAt": Timestamp(date: Date())
                ]) { (error: Error?) in
                    if let error = error {
                        self.error = "Error creating user profile: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    func signInWithEmail(email: String, password: String) {
        isLoading = true
        error = nil
        
        Auth.auth().signIn(withEmail: email, password: password) { (result: AuthDataResult?, error: Error?) in
            self.isLoading = false
            
            if let error = error {
                self.error = error.localizedDescription
                return
            }
        }
    }
    
    func createAccount(email: String, password: String) {
        isLoading = true
        error = nil
        
        Auth.auth().createUser(withEmail: email, password: password) { (result: AuthDataResult?, error: Error?) in
            self.isLoading = false
            
            if let error = error {
                self.error = error.localizedDescription
                return
            }
            
            // User created successfully, now create their profile
            if let user = result?.user {
                let db = Firestore.firestore()
                db.collection("users").document(user.uid).setData([
                    "email": email,
                    "role": UserRole.fan.rawValue,
                    "createdAt": Timestamp(date: Date())
                ]) { (error: Error?) in
                    if let error = error {
                        self.error = "Error creating user profile: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    func sendPasswordReset(email: String, completion: @escaping (_ success: Bool) -> Void) {
        isLoading = true
        error = nil
        
        Auth.auth().sendPasswordReset(withEmail: email) { (error: Error?) in
            self.isLoading = false
            
            if let error = error {
                self.error = error.localizedDescription
                completion(false)
                return
            }
            
            completion(true)
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch let error {
            self.error = error.localizedDescription
        }
    }
    
    func refreshUser() {
        print("🔍 AuthViewModel: Starting user refresh...")
        user?.reload { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error refreshing user: \(error.localizedDescription)")
                } else {
                    // Manually trigger the user update since reload doesn't trigger the auth state listener
                    let refreshedUser = Auth.auth().currentUser
                    print("🔍 AuthViewModel: User photoURL after refresh: \(refreshedUser?.photoURL?.absoluteString ?? "none")")
                    self?.user = refreshedUser
                    // Trigger profile image update in UI
                    self?.profileImageUpdateTrigger = UUID()
                    print("✅ User data refreshed successfully, new trigger: \(self?.profileImageUpdateTrigger.uuidString ?? "unknown")")
                }
            }
        }
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}

// MARK: - Apple Sign In Delegates

extension AuthViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            
            // Initialize a Firebase credential
            let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                      idToken: idTokenString,
                                                      rawNonce: nonce)
            
            // Sign in with Firebase
            isLoading = true
            Auth.auth().signIn(with: credential) { (authResult, error) in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.error = error.localizedDescription
                        return
                    }
                    
                    // Handle successful sign in
                    if let user = authResult?.user {
                        // Check if this is a new user
                        if let isNewUser = authResult?.additionalUserInfo?.isNewUser, isNewUser {
                            // Create user profile for new Apple Sign In users
                            let displayName = self.formatPersonName(appleIDCredential.fullName)
                            self.createUserProfile(
                                user: user,
                                displayName: displayName,
                                email: appleIDCredential.email
                            )
                        } else {
                            // For existing users, update their Firebase Auth profile if needed
                            self.updateExistingUserProfile(user: user, credential: appleIDCredential)
                        }
                    }
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    // User canceled the authorization attempt
                    self.error = nil
                case .failed:
                    self.error = "Authorization failed"
                case .invalidResponse:
                    self.error = "Invalid response"
                case .notHandled:
                    self.error = "Authorization not handled"
                case .unknown:
                    self.error = "Unknown authorization error"
                @unknown default:
                    self.error = "Unknown authorization error"
                }
            } else {
                self.error = error.localizedDescription
            }
        }
    }
    
    private func formatPersonName(_ personName: PersonNameComponents?) -> String? {
        guard let personName = personName else { return nil }
        
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        let formattedName = formatter.string(from: personName)
        
        return formattedName.isEmpty ? nil : formattedName
    }
    
    private func createUserProfile(user: User, displayName: String?, email: String?) {
        let db = Firestore.firestore()
        let userData: [String: Any] = [
            "email": email ?? user.email ?? "",
            "display_name": displayName ?? user.displayName ?? "",
            "role": "fan", // Default role for new users
            "created_at": FieldValue.serverTimestamp(),
            "last_active_at": FieldValue.serverTimestamp(),
            "is_email_verified": user.isEmailVerified,
            "band_ids": []
        ]
        
        // Update Firebase Auth profile with display name
        if let displayName = displayName {
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            changeRequest.commitChanges { error in
                if let error = error {
                    print("Error updating Firebase Auth profile: \(error.localizedDescription)")
                }
            }
        }
        
        db.collection("users").document(user.uid).setData(userData, merge: true) { error in
            if let error = error {
                print("Error creating user profile: \(error.localizedDescription)")
            } else {
                print("User profile created successfully")
                self.fetchUserRole(userId: user.uid)
            }
        }
    }
    
    private func updateExistingUserProfile(user: User, credential: ASAuthorizationAppleIDCredential) {
        // For existing users, we might want to update their display name if it's not set
        // but we're cautious not to overwrite existing data
        if user.displayName == nil || user.displayName?.isEmpty == true {
            if let displayName = formatPersonName(credential.fullName) {
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                changeRequest.commitChanges { error in
                    if let error = error {
                        print("Error updating existing user profile: \(error.localizedDescription)")
                    } else {
                        print("Updated existing user display name")
                        
                        // Also update Firestore
                        let db = Firestore.firestore()
                        db.collection("users").document(user.uid).updateData([
                            "display_name": displayName,
                            "last_active_at": FieldValue.serverTimestamp()
                        ]) { error in
                            if let error = error {
                                print("Error updating Firestore profile: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
    }
}

extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}
