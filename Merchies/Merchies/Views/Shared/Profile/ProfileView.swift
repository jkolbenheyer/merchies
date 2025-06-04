import SwiftUI
import Foundation
import FirebaseStorage

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
                    profileViewModel.loadProfileData(userId: userId)
                }
            }
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Picture/Avatar
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(profileInitials)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                )
            
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
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
    
    // MARK: - Quick Stats
    
    private var quickStatsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Events\nAttended",
                value: "\(profileViewModel.eventsAttended.count)",
                icon: "calendar",
                color: .purple
            )
            
            StatCard(
                title: "Total\nSpent",
                value: "$\(String(format: "%.0f", profileViewModel.totalSpent))",
                icon: "dollarsign.circle",
                color: .green
            )
            
            StatCard(
                title: "Items\nPurchased",
                value: "\(profileViewModel.totalItemsPurchased)",
                icon: "bag",
                color: .blue
            )
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
            
            // Favorite Products
            NavigationLink(destination: FavoriteProductsView()) {
                ProfileSectionRow(
                    title: "Favorite Products",
                    subtitle: "Your liked items",
                    icon: "heart",
                    color: .red
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
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
