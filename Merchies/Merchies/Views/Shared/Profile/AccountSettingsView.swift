import SwiftUI

struct AccountSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var notificationsEnabled = true
    @State private var emailNotifications = true
    @State private var pushNotifications = true
    @State private var locationTracking = true
    @State private var marketingEmails = false
    @State private var showingDeleteAlert = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    
    var body: some View {
        Form {
            // Account Information
            Section(header: Text("Account Information")) {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(authViewModel.user?.email ?? "Not available")
                        .foregroundColor(.secondary)
                }
                
                NavigationLink("Change Password") {
                    ChangePasswordView()
                }
                
                NavigationLink("Edit Profile") {
                    EditProfileView()
                }
            }
            
            // Notification Settings
            Section(header: Text("Notifications")) {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                
                if notificationsEnabled {
                    Toggle("Email Notifications", isOn: $emailNotifications)
                        .disabled(!notificationsEnabled)
                    
                    Toggle("Push Notifications", isOn: $pushNotifications)
                        .disabled(!notificationsEnabled)
                }
            }
            
            // Privacy Settings
            Section(header: Text("Privacy & Data")) {
                Toggle("Location Tracking", isOn: $locationTracking)
                
                Toggle("Marketing Emails", isOn: $marketingEmails)
                
                NavigationLink("Download My Data") {
                    DataExportView()
                }
            }
            
            // Legal & Support
            Section(header: Text("Legal & Support")) {
                Button("Privacy Policy") {
                    showingPrivacyPolicy = true
                }
                
                Button("Terms of Service") {
                    showingTermsOfService = true
                }
                
                NavigationLink("Help & Support") {
                    HelpSupportView()
                }
                
                NavigationLink("Contact Us") {
                    ContactUsView()
                }
            }
            
            // Danger Zone
            Section(header: Text("Danger Zone")) {
                Button("Delete Account") {
                    showingDeleteAlert = true
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Account Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone and will permanently delete all your data.")
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            WebView(url: "https://yourapp.com/privacy")
        }
        .sheet(isPresented: $showingTermsOfService) {
            WebView(url: "https://yourapp.com/terms")
        }
    }
    
    private func deleteAccount() {
        // In real app, this would delete the user account
        authViewModel.signOut()
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section(header: Text("Change Password")) {
                SecureField("Current Password", text: $currentPassword)
                SecureField("New Password", text: $newPassword)
                SecureField("Confirm New Password", text: $confirmPassword)
            }
            
            Section(footer: Text("Password must be at least 8 characters long")) {
                Button("Update Password") {
                    updatePassword()
                }
                .disabled(!isFormValid)
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Password Updated", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            Text("Your password has been successfully updated.")
        }
    }
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 8
    }
    
    private func updatePassword() {
        // Mock password update
        if newPassword != confirmPassword {
            errorMessage = "Passwords do not match"
            return
        }
        
        if newPassword.count < 8 {
            errorMessage = "Password must be at least 8 characters"
            return
        }
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            showingSuccess = true
            errorMessage = nil
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
        }
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var displayName = ""
    @State private var bio = ""
    @State private var showingSuccess = false
    
    var body: some View {
        Form {
            Section(header: Text("Profile Information")) {
                TextField("Display Name", text: $displayName)
                
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            Section {
                Button("Save Changes") {
                    saveProfile()
                }
                .disabled(displayName.isEmpty)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            displayName = authViewModel.user?.displayName ?? ""
        }
        .alert("Profile Updated", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            Text("Your profile has been successfully updated.")
        }
    }
    
    private func saveProfile() {
        // Mock profile save
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            showingSuccess = true
        }
    }
}

// MARK: - Data Export View

struct DataExportView: View {
    @State private var isExporting = false
    @State private var exportComplete = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.badge.arrow.up")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("Export Your Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Download a copy of all your data including orders, favorites, and account information.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if isExporting {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Preparing your data...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if exportComplete {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    
                    Text("Export Complete!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("Check your email for the download link.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Button("Export My Data") {
                    startExport()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding()
        .navigationTitle("Data Export")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func startExport() {
        isExporting = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isExporting = false
            exportComplete = true
        }
    }
}

// MARK: - Help & Support View

struct HelpSupportView: View {
    var body: some View {
        List {
            Section("Frequently Asked Questions") {
                NavigationLink("How do I place an order?") {
                    FAQDetailView(question: "How do I place an order?", answer: "To place an order, find an event near you, browse the available products, select your size and quantity, then proceed to checkout.")
                }
                
                NavigationLink("How do I pick up my order?") {
                    FAQDetailView(question: "How do I pick up my order?", answer: "Show your QR code at the merchandise booth during the event. Your order will be ready for pickup.")
                }
                
                NavigationLink("Can I cancel my order?") {
                    FAQDetailView(question: "Can I cancel my order?", answer: "Orders can be cancelled up to 2 hours before the event starts. Go to your order history and select cancel.")
                }
            }
            
            Section("Contact") {
                Link("Email Support", destination: URL(string: "mailto:support@yourapp.com")!)
                Link("Call Support", destination: URL(string: "tel:+1234567890")!)
            }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FAQDetailView: View {
    let question: String
    let answer: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(question)
                .font(.headline)
            
            Text(answer)
                .font(.body)
        }
        .padding()
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Contact Us View

struct ContactUsView: View {
    @State private var subject = ""
    @State private var message = ""
    @State private var showingSuccess = false
    
    var body: some View {
        Form {
            Section(header: Text("Contact Information")) {
                TextField("Subject", text: $subject)
                TextField("Message", text: $message, axis: .vertical)
                    .lineLimit(5...10)
            }
            
            Section {
                Button("Send Message") {
                    sendMessage()
                }
                .disabled(subject.isEmpty || message.isEmpty)
            }
        }
        .navigationTitle("Contact Us")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Message Sent", isPresented: $showingSuccess) {
            Button("OK") { 
                subject = ""
                message = ""
            }
        } message: {
            Text("Thank you for your message. We'll get back to you soon!")
        }
    }
    
    private func sendMessage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            showingSuccess = true
        }
    }
}

// MARK: - Web View (Placeholder)

struct WebView: View {
    let url: String
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Web content would load here")
                Text("URL: \(url)")
            }
            .navigationTitle("Legal Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}