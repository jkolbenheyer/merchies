// Models/ViewModels/AuthViewModel.swift
import Foundation
import Firebase
import FirebaseAuth
import SwiftUI
import Combine

enum AuthState {
    case signedIn
    case signedOut
}

class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var authState: AuthState = .signedOut
    @Published var userRole: UserRole = .fan
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private var handle: AuthStateDidChangeListenerHandle?
    
    init() {
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
    
    func signInWithApple() {
        // Implement Apple Sign-In logic here
        // This would use ASAuthorizationAppleIDProvider and integrate with Firebase Auth
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
    
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
