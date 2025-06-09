import SwiftUI
import Foundation
import FirebaseStorage
import FirebaseAuth
import Firebase

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var orderViewModel: OrderViewModel
    @StateObject private var profileViewModel = FanProfileViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader
                    
                    // Quick Stats
                    quickStatsSection
                    
                    // Main Sections
                    profileSections
                }
                .padding(.horizontal)
                .padding(.top)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let userId = authViewModel.user?.uid {
                    print("🔍 ProfileView.onAppear: Loading profile data for userId: \(userId)")
                    print("🔍 Current user email: \(authViewModel.user?.email ?? "no email")")
                    print("🔍 Current user photoURL: \(authViewModel.user?.photoURL?.absoluteString ?? "none")")
                    profileViewModel.loadProfileData(userId: userId)
                    
                    // Refresh user data to ensure profile picture updates are reflected
                    authViewModel.user?.reload { error in
                        if let error = error {
                            print("❌ Error refreshing user data: \(error.localizedDescription)")
                        } else {
                            print("✅ User data refreshed successfully")
                            print("🔍 PhotoURL after reload: \(Auth.auth().currentUser?.photoURL?.absoluteString ?? "none")")
                        }
                    }
                } else {
                    print("❌ ProfileView.onAppear: No user ID available")
                }
            }
            .onChange(of: authViewModel.user?.photoURL?.absoluteString) { newPhotoURL in
                print("🔍 ProfileView: photoURL changed to: \(newPhotoURL ?? "none")")
            }
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        NavigationLink(destination: EditProfileView()) {
            VStack(spacing: 16) {
                // Profile Picture/Avatar
                ProfilePictureView(user: authViewModel.user, size: 80)
                
                VStack(spacing: 4) {
                    Text(displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let email = authViewModel.user?.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Fan since \(memberSince)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(TappableCardButtonStyle())
    }
    
    // MARK: - Quick Stats
    
    private var quickStatsSection: some View {
        HStack(spacing: 16) {
            NavigationLink(destination: EventsAttendedView(eventsAttended: profileViewModel.eventsAttended)) {
                StatCard(
                    title: "Events\nAttended",
                    value: "\(profileViewModel.eventsAttended.count)",
                    icon: "calendar",
                    color: .purple
                )
            }
            .buttonStyle(TappableCardButtonStyle())
            
            NavigationLink(destination: PurchaseHistoryView(orders: profileViewModel.orders)) {
                StatCard(
                    title: "Total\nSpent",
                    value: "$\(String(format: "%.0f", profileViewModel.totalSpent))",
                    icon: "dollarsign.circle",
                    color: .green
                )
            }
            .buttonStyle(TappableCardButtonStyle())
            
            NavigationLink(destination: PurchaseHistoryView(orders: profileViewModel.orders)) {
                StatCard(
                    title: "Items\nPurchased",
                    value: "\(profileViewModel.totalItemsPurchased)",
                    icon: "bag",
                    color: .blue
                )
            }
            .buttonStyle(TappableCardButtonStyle())
        }
    }
    
    // MARK: - Profile Sections
    
    private var profileSections: some View {
        VStack(spacing: 16) {
            // Events Attended
            NavigationLink(destination: EventsAttendedView(eventsAttended: profileViewModel.eventsAttended)) {
                ProfileSectionRow(
                    title: "Events Attended",
                    subtitle: "\(profileViewModel.eventsAttended.count) events",
                    icon: "calendar",
                    color: .purple
                )
            }
            
            // Purchase History
            NavigationLink(destination: PurchaseHistoryView(orders: profileViewModel.orders)) {
                ProfileSectionRow(
                    title: "Purchase History",
                    subtitle: "\(profileViewModel.orders.count) orders",
                    icon: "bag",
                    color: .blue
                )
            }
            
            // Payment Methods
            NavigationLink(destination: PaymentMethodsView()) {
                ProfileSectionRow(
                    title: "Payment Methods",
                    subtitle: "Manage cards & payment",
                    icon: "creditcard",
                    color: .orange
                )
            }
            
            // Insights & Analytics
            NavigationLink(destination: FanInsightsView(profileData: profileViewModel)) {
                ProfileSectionRow(
                    title: "Your Insights",
                    subtitle: "Spending & activity stats",
                    icon: "chart.bar",
                    color: .teal
                )
            }
            
            // Account Settings
            NavigationLink(destination: AccountSettingsView()) {
                ProfileSectionRow(
                    title: "Account Settings",
                    subtitle: "Privacy, notifications & more",
                    icon: "gearshape",
                    color: .gray
                )
            }
            
            // Sign Out
            Button(action: {
                authViewModel.signOut()
            }) {
                ProfileSectionRow(
                    title: "Sign Out",
                    subtitle: "Log out of your account",
                    icon: "rectangle.portrait.and.arrow.right",
                    color: .red,
                    showChevron: false
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Computed Properties
    
    private var displayName: String {
        return authViewModel.user?.displayName ?? "Fan"
    }
    
    private var profileInitials: String {
        let name = displayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    private var memberSince: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: authViewModel.user?.metadata.creationDate ?? Date())
    }
    
}

// MARK: - Supporting Components

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

struct ProfileSectionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let showChevron: Bool
    
    init(title: String, subtitle: String, icon: String, color: Color, showChevron: Bool = true) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.showChevron = showChevron
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Profile Picture Component

struct ProfilePictureView: View {
    let user: User?
    let size: CGFloat
    @State private var profileImage: UIImage?
    @State private var isLoading = false
    @State private var currentImageURL: String = ""
    
    private var userImageURL: String {
        return user?.photoURL?.absoluteString ?? ""
    }
    
    var body: some View {
        Group {
            if let profileImage = profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if isLoading {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.6)
                            .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                    )
            } else {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(profileInitials)
                            .font(.system(size: size * 0.3))
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                    )
            }
        }
        .onAppear {
            loadProfileImageIfNeeded()
        }
        .onChange(of: userImageURL) { newURL in
            print("🔍 ProfilePictureView: URL changed from '\(currentImageURL)' to '\(newURL)'")
            if newURL != currentImageURL {
                currentImageURL = newURL
                profileImage = nil
                loadProfileImageIfNeeded()
            }
        }
    }
    
    private var profileInitials: String {
        let name = user?.displayName ?? user?.email ?? "User"
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    private func loadProfileImageIfNeeded() {
        let newURL = userImageURL
        guard !newURL.isEmpty else {
            print("🔍 ProfilePictureView: No photoURL found for user \(user?.uid ?? "unknown")")
            profileImage = nil
            currentImageURL = ""
            return
        }
        
        // Update currentImageURL if it's different
        if currentImageURL != newURL {
            currentImageURL = newURL
        }
        
        loadProfileImage(from: newURL)
    }
    
    private func loadProfileImage(from urlString: String) {
        guard let photoURL = URL(string: urlString) else {
            print("❌ ProfilePictureView: Invalid URL: \(urlString)")
            profileImage = nil
            return
        }
        
        print("🔍 ProfilePictureView: Loading image from URL: \(photoURL.absoluteString)")
        
        // Check if this is a Firebase Storage URL
        if urlString.contains("firebasestorage.googleapis.com") {
            print("🔍 ProfilePictureView: Detected Firebase Storage URL")
            loadFirebaseStorageImage(from: urlString)
        } else {
            print("🔍 ProfilePictureView: Using standard URL loading")
            loadImageWithURLSession(from: photoURL)
        }
    }
    
    private func loadImageWithURLSession(from photoURL: URL) {
        isLoading = true
        
        URLSession.shared.dataTask(with: photoURL) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    print("❌ ProfilePictureView: Error loading image: \(error.localizedDescription)")
                    print("❌ ProfilePictureView: Error code: \((error as NSError).code)")
                    print("❌ ProfilePictureView: Error domain: \((error as NSError).domain)")
                    profileImage = nil
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("🔍 ProfilePictureView: HTTP Status: \(httpResponse.statusCode)")
                    print("🔍 ProfilePictureView: Response headers: \(httpResponse.allHeaderFields)")
                    
                    if let data = data {
                        print("🔍 ProfilePictureView: Received \(data.count) bytes of data")
                        if let image = UIImage(data: data) {
                            print("✅ ProfilePictureView: Successfully loaded profile image from: \(photoURL.absoluteString)")
                            profileImage = image
                        } else {
                            print("❌ ProfilePictureView: Failed to create UIImage from data")
                            print("❌ ProfilePictureView: Data preview: \(String(data: data.prefix(100), encoding: .utf8) ?? "binary data")")
                            profileImage = nil
                        }
                    } else {
                        print("❌ ProfilePictureView: No data received")
                        profileImage = nil
                    }
                } else {
                    print("❌ ProfilePictureView: Invalid response type")
                    profileImage = nil
                }
            }
        }.resume()
    }
    
    private func loadFirebaseStorageImage(from urlString: String) {
        isLoading = true
        
        // First, try to extract the storage path from the URL
        if let url = URL(string: urlString),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let pathQueryItem = components.queryItems?.first(where: { $0.name == "alt" }),
           pathQueryItem.value == "media" {
            
            // Try to get the storage reference from the URL path
            let path = url.path
            print("🔍 ProfilePictureView: Firebase Storage path: \(path)")
            
            // Create a storage reference
            let storage = Storage.storage()
            let storageRef = storage.reference().child(path.replacingOccurrences(of: "/v0/b/", with: "").components(separatedBy: "/o/").last?.removingPercentEncoding ?? path)
            
            storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        print("❌ ProfilePictureView: Firebase Storage error: \(error.localizedDescription)")
                        // Fallback to URLSession
                        self.loadImageWithURLSession(from: url)
                    } else if let data = data, let image = UIImage(data: data) {
                        print("✅ ProfilePictureView: Successfully loaded image from Firebase Storage")
                        self.profileImage = image
                    } else {
                        print("❌ ProfilePictureView: Failed to create image from Firebase Storage data")
                        // Fallback to URLSession
                        self.loadImageWithURLSession(from: url)
                    }
                }
            }
        } else {
            // Fallback to standard URL loading
            print("🔍 ProfilePictureView: Could not parse Firebase Storage URL, using URLSession")
            if let fallbackURL = URL(string: urlString) {
                loadImageWithURLSession(from: fallbackURL)
            }
        }
    }
}

// MARK: - Custom Button Style

struct TappableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
