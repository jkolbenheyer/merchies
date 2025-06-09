import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import PhotosUI

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
    @StateObject private var imageUploadService = ImageUploadService()
    @State private var displayName = ""
    @State private var bio = ""
    @State private var profileImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingSuccess = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            Section(header: Text("Profile Picture")) {
                VStack(spacing: 16) {
                    // Profile Picture Display
                    Button(action: { showingImagePicker = true }) {
                        ZStack {
                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.purple.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Text(profileInitials)
                                            .font(.title)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.purple)
                                    )
                            }
                            
                            // Camera overlay
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 100, height: 100)
                                .opacity(0.8)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button("Change Profile Picture") {
                        showingImagePicker = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    
                    if profileImage != nil {
                        Button("Remove Picture") {
                            profileImage = nil
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            
            Section(header: Text("Profile Information")) {
                TextField("Display Name", text: $displayName)
                
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            Section {
                Button("Save Changes") {
                    saveProfile()
                }
                .disabled((displayName.isEmpty && profileImage == nil) || isLoading)
                
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Saving...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentProfile()
        }
        .onChange(of: profileImage) { newImage in
            print("🔍 EditProfileView: profileImage changed to: \(newImage != nil ? "UIImage" : "nil")")
        }
        .sheet(isPresented: $showingImagePicker) {
            ProfileImagePickerSheet(
                selectedImage: $profileImage,
                isPresented: $showingImagePicker
            )
        }
        .alert("Profile Updated", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            Text("Your profile has been successfully updated.")
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") {
                errorMessage = nil
            }
        }, message: {
            Text(errorMessage ?? "")
        })
    }
    
    private var profileInitials: String {
        let name = displayName.isEmpty ? (authViewModel.user?.displayName ?? "User") : displayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    private func loadCurrentProfile() {
        displayName = authViewModel.user?.displayName ?? ""
        
        // Try to load existing profile picture from Firebase Auth
        if let photoURL = authViewModel.user?.photoURL {
            loadImageFromURL(photoURL)
        }
        
        // TODO: Load bio and other profile data from Firestore user document
    }
    
    private func loadImageFromURL(_ url: URL) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let data = data, let image = UIImage(data: data) {
                    self.profileImage = image
                }
            }
        }.resume()
    }
    
    private func saveProfile() {
        guard let user = authViewModel.user else { 
            print("❌ EditProfileView: No user found in authViewModel")
            return 
        }
        
        print("🔍 EditProfileView: Starting saveProfile for user: \(user.uid)")
        print("🔍 EditProfileView: Profile image exists: \(profileImage != nil)")
        print("🔍 EditProfileView: Display name: '\(displayName)'")
        
        isLoading = true
        errorMessage = nil
        
        // If we have a new profile image, upload it first
        if profileImage != nil {
            print("🔍 EditProfileView: Has profile image - starting upload process")
            uploadProfileImage(for: user.uid) { [self] result in
                switch result {
                case .success(let imageUrl):
                    print("✅ EditProfileView: Image upload successful, updating profile with URL: \(imageUrl)")
                    updateUserProfile(userId: user.uid, photoURL: imageUrl)
                case .failure(let error):
                    print("❌ EditProfileView: Image upload failed: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            print("🔍 EditProfileView: No profile image - updating profile without photo")
            updateUserProfile(userId: user.uid, photoURL: nil)
        }
    }
    
    private func uploadProfileImage(for userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let image = profileImage else {
            print("❌ EditProfileView: No profile image to upload")
            completion(.failure(ImageUploadError.compressionFailed))
            return
        }
        
        print("🔍 EditProfileView: Starting profile image upload for user: \(userId)")
        imageUploadService.uploadImage(image, type: .profile, id: userId) { result in
            switch result {
            case .success(let imageUrl):
                print("✅ EditProfileView: Profile image uploaded successfully: \(imageUrl)")
                completion(.success(imageUrl))
            case .failure(let error):
                print("❌ EditProfileView: Profile image upload failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    private func updateUserProfile(userId: String, photoURL: String?) {
        print("🔍 EditProfileView: Updating user profile with photoURL: \(photoURL ?? "none")")
        
        // Update Firebase Auth profile
        let changeRequest = authViewModel.user?.createProfileChangeRequest()
        
        // Only update displayName if it's not empty
        if !displayName.isEmpty {
            changeRequest?.displayName = displayName
            print("🔍 EditProfileView: Setting displayName in Firebase Auth: \(displayName)")
        }
        
        if let photoURL = photoURL {
            changeRequest?.photoURL = URL(string: photoURL)
            print("🔍 EditProfileView: Setting photoURL in Firebase Auth: \(photoURL)")
        }
        
        changeRequest?.commitChanges { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ EditProfileView: Failed to update Firebase Auth profile: \(error.localizedDescription)")
                    print("❌ EditProfileView: Error code: \((error as NSError).code)")
                    print("❌ EditProfileView: Error domain: \((error as NSError).domain)")
                    self.isLoading = false
                    self.errorMessage = "Failed to update profile: \(error.localizedDescription)"
                    return
                }
                
                print("✅ EditProfileView: Firebase Auth profile updated successfully")
                print("🔍 EditProfileView: Checking updated photoURL...")
                
                // Verify the update worked
                let updatedUser = Auth.auth().currentUser
                print("🔍 EditProfileView: Current user photoURL: \(updatedUser?.photoURL?.absoluteString ?? "none")")
                print("🔍 EditProfileView: Current user displayName: \(updatedUser?.displayName ?? "none")")
                
                // Update Firestore user document
                self.updateFirestoreProfile(userId: userId, photoURL: photoURL)
            }
        }
    }
    
    private func updateFirestoreProfile(userId: String, photoURL: String?) {
        print("🔍 EditProfileView: Updating Firestore profile with photoURL: \(photoURL ?? "none")")
        
        let db = Firestore.firestore()
        var updateData: [String: Any] = [
            "last_active_at": FieldValue.serverTimestamp()
        ]
        
        // Only update display_name if it's not empty
        if !displayName.isEmpty {
            updateData["display_name"] = displayName
        }
        
        if let photoURL = photoURL {
            updateData["photo_url"] = photoURL
            print("🔍 EditProfileView: Adding photo_url to Firestore: \(photoURL)")
        }
        
        // TODO: Add bio field when we extend the UserProfile model
        
        db.collection("users").document(userId).updateData(updateData) { error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ EditProfileView: Failed to update Firestore: \(error.localizedDescription)")
                    self.errorMessage = "Profile updated but failed to sync: \(error.localizedDescription)"
                } else {
                    print("✅ EditProfileView: Firestore profile updated successfully")
                    self.showingSuccess = true
                    // Refresh the user data in AuthViewModel to trigger UI updates
                    print("🔍 EditProfileView: Calling authViewModel.refreshUser()")
                    self.authViewModel.refreshUser()
                }
            }
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

// MARK: - Profile Image Picker Sheet

struct ProfileImagePickerSheet: View {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingConfirmation = false
    @State private var tempSelectedImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Current/Preview Image
                VStack(spacing: 16) {
                    ZStack {
                        if let image = tempSelectedImage ?? selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    
                    if tempSelectedImage != nil {
                        Text("Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Camera Button
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button(action: { showingCamera = true }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Take Photo")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Photo Library Button
                    Button(action: { showingPhotoLibrary = true }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Choose from Library")
                        }
                        .font(.headline)
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple, lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    
                    // Remove Photo Button (if there's a current image)
                    if selectedImage != nil {
                        Button(action: { 
                            showingConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove Photo")
                            }
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red, lineWidth: 1)
                            )
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Profile Picture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        tempSelectedImage = nil
                        isPresented = false
                    }
                }
                
                if tempSelectedImage != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            print("🔍 ProfileImagePickerSheet: Done button tapped, setting selectedImage")
                            selectedImage = tempSelectedImage
                            print("🔍 ProfileImagePickerSheet: selectedImage set to: \(selectedImage != nil ? "UIImage" : "nil")")
                            tempSelectedImage = nil
                            isPresented = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            ImagePickerView(selectedImage: $tempSelectedImage, sourceType: .camera)
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            if #available(iOS 14.0, *) {
                ModernPhotoPickerView(selectedImage: $tempSelectedImage)
            } else {
                ImagePickerView(selectedImage: $tempSelectedImage, sourceType: .photoLibrary)
            }
        }
        .confirmationDialog("Remove Profile Picture", isPresented: $showingConfirmation) {
            Button("Remove Photo", role: .destructive) {
                selectedImage = nil
                tempSelectedImage = nil
                isPresented = false
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove your profile picture?")
        }
    }
}

// MARK: - Modern Photo Picker (iOS 14+)

@available(iOS 14.0, *)
struct ModernPhotoPickerView: View {
    @Binding var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        Text("Select Photo")
                            .font(.headline)
                            .foregroundColor(.purple)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onChange(of: selectedItem) { newItem in
                    print("🔍 ModernPhotoPickerView: selectedItem changed: \(newItem != nil)")
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            print("✅ ModernPhotoPickerView: Successfully loaded image data")
                            await MainActor.run {
                                selectedImage = image
                                print("🔍 ModernPhotoPickerView: selectedImage set and dismissing")
                                presentationMode.wrappedValue.dismiss()
                            }
                        } else {
                            print("❌ ModernPhotoPickerView: Failed to load image data")
                        }
                    }
                }
            }
            .navigationTitle("Select Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
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