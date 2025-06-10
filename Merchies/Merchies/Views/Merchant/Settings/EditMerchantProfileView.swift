import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore

struct EditMerchantProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var displayName: String = ""
    @State private var phoneNumber: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isUploading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Photo")) {
                    HStack {
                        // Current/Selected Photo
                        Group {
                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } else {
                                ProfilePictureView(user: authViewModel.user, size: 80)
                            }
                        }
                        
                        Spacer()
                        
                        // Photo Picker
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text("Change Photo")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .onChange(of: selectedPhoto) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    profileImage = UIImage(data: data)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Basic Information")) {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(authViewModel.user?.email ?? "")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Display Name")
                        TextField("Enter display name", text: $displayName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Phone Number")
                        TextField("Enter phone number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Account Information")) {
                    HStack {
                        Text("Account Type")
                        Spacer()
                        Text("Merchant")
                            .foregroundColor(.purple)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Member Since")
                        Spacer()
                        if let createdAt = authViewModel.user?.metadata.creationDate {
                            Text(DateFormatter.shortDate.string(from: createdAt))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Notifications")) {
                    NotificationSettingsView()
                }
                
                Section(header: Text("Business Settings")) {
                    NavigationLink("Payment Settings") {
                        PaymentSettingsView()
                    }
                    
                    NavigationLink("Store Preferences") {
                        StorePreferencesView()
                    }
                    
                    NavigationLink("Tax Information") {
                        TaxInformationView()
                    }
                }
                
                Section {
                    Button("Save Changes") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(isUploading)
                    .foregroundColor(isUploading ? .gray : .purple)
                    
                    if isUploading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Saving...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Profile Update", isPresented: $showAlert) {
                Button("OK") {
                    if alertMessage.contains("successfully") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadCurrentProfile()
            }
        }
    }
    
    // MARK: - Methods
    
    private func loadCurrentProfile() {
        // First refresh user data to get latest profile info
        authViewModel.user?.reload { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error refreshing user data in edit profile: \(error.localizedDescription)")
                } else {
                    print("✅ User data refreshed in edit profile")
                    print("🔍 PhotoURL: \(self.authViewModel.user?.photoURL?.absoluteString ?? "none")")
                }
                
                // Load current profile data
                self.displayName = self.authViewModel.user?.displayName ?? ""
                self.phoneNumber = self.authViewModel.user?.phoneNumber ?? ""
            }
        }
    }
    
    private func saveProfile() async {
        isUploading = true
        
        do {
            var updates: [String: Any] = [:]
            var photoURL: String? = nil
            
            // Upload new profile image if selected
            if let profileImage = profileImage {
                print("🔍 Uploading new profile image...")
                photoURL = try await uploadProfileImage(profileImage)
                updates["photo_url"] = photoURL
                print("✅ Profile image uploaded: \(photoURL ?? "nil")")
            }
            
            // Update display name if changed
            if displayName != (authViewModel.user?.displayName ?? "") {
                updates["display_name"] = displayName
                print("🔍 Updating display name: \(displayName)")
            }
            
            // Update phone number if changed
            if phoneNumber != (authViewModel.user?.phoneNumber ?? "") {
                updates["phone_number"] = phoneNumber
            }
            
            // Update last active timestamp
            updates["last_active_at"] = FieldValue.serverTimestamp()
            
            // Save to Firestore first
            if !updates.isEmpty {
                print("🔍 Saving to Firestore...")
                try await Firestore.firestore()
                    .collection("users")
                    .document(authViewModel.user?.uid ?? "")
                    .updateData(updates)
                print("✅ Firestore updated successfully")
            }
            
            // Update Firebase Auth profile
            print("🔍 Updating Firebase Auth profile...")
            let changeRequest = authViewModel.user?.createProfileChangeRequest()
            
            if !displayName.isEmpty {
                changeRequest?.displayName = displayName
            }
            
            if let photoURL = photoURL {
                changeRequest?.photoURL = URL(string: photoURL)
            }
            
            try await changeRequest?.commitChanges()
            print("✅ Firebase Auth profile updated")
            
            // Force reload the user to get updated profile
            try await authViewModel.user?.reload()
            print("✅ User profile reloaded")
            
            await MainActor.run {
                // Clear the selected image since it's now saved
                self.profileImage = nil
                alertMessage = "Profile updated successfully!"
            }
            
        } catch {
            print("❌ Failed to update profile: \(error)")
            await MainActor.run {
                alertMessage = "Failed to update profile: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isUploading = false
            showAlert = true
        }
    }
    
    private func uploadProfileImage(_ image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.badURL)
        }
        
        let userId = authViewModel.user?.uid ?? UUID().uuidString
        let fileName = "profile_\(userId)_\(Date().timeIntervalSince1970).jpg"
        let storageRef = Storage.storage().reference()
            .child("profiles")
            .child(fileName)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
}

// MARK: - Supporting Views

struct NotificationSettingsView: View {
    @State private var emailNotifications = true
    @State private var pushNotifications = true
    @State private var orderNotifications = true
    @State private var marketingEmails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Email Notifications", isOn: $emailNotifications)
            Toggle("Push Notifications", isOn: $pushNotifications)
            Toggle("Order Updates", isOn: $orderNotifications)
            Toggle("Marketing Emails", isOn: $marketingEmails)
        }
    }
}

struct PaymentSettingsView: View {
    var body: some View {
        Form {
            Section(header: Text("Stripe Account")) {
                HStack {
                    Text("Status")
                    Spacer()
                    Text("Connected")
                        .foregroundColor(.green)
                }
                
                Button("Manage Stripe Account") {
                    // Open Stripe dashboard
                }
            }
            
            Section(header: Text("Payout Settings")) {
                HStack {
                    Text("Payout Schedule")
                    Spacer()
                    Text("Weekly")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Bank Account")
                    Spacer()
                    Text("****1234")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Payment Settings")
    }
}

struct StorePreferencesView: View {
    @State private var storeName = ""
    @State private var storeDescription = ""
    @State private var defaultCurrency = "USD"
    
    var body: some View {
        Form {
            Section(header: Text("Store Information")) {
                TextField("Store Name", text: $storeName)
                TextField("Store Description", text: $storeDescription, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            Section(header: Text("Preferences")) {
                Picker("Default Currency", selection: $defaultCurrency) {
                    Text("USD").tag("USD")
                    Text("EUR").tag("EUR")
                    Text("GBP").tag("GBP")
                }
            }
        }
        .navigationTitle("Store Preferences")
    }
}

struct TaxInformationView: View {
    @State private var taxId = ""
    @State private var businessAddress = ""
    
    var body: some View {
        Form {
            Section(header: Text("Tax Information")) {
                TextField("Tax ID / EIN", text: $taxId)
                TextField("Business Address", text: $businessAddress, axis: .vertical)
                    .lineLimit(2...4)
            }
            
            Section(footer: Text("Tax information is used for generating invoices and tax reporting.")) {
                EmptyView()
            }
        }
        .navigationTitle("Tax Information")
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}