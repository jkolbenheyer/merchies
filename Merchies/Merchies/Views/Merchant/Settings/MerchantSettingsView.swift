import SwiftUI
import Foundation

struct MerchantSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section {
                    NavigationLink(destination: MerchantProfileView().environmentObject(authViewModel)) {
                        HStack {
                            // Profile Image
                            Group {
                                if let photoURL = authViewModel.user?.photoURL {
                                    AsyncImage(url: photoURL) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        ProgressView()
                                    }
                                } else {
                                    Circle()
                                        .fill(Color.cyan.gradient)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(authViewModel.user?.displayName ?? "Merchant")
                                    .font(.headline)
                                Text(authViewModel.user?.email ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("View Profile & Analytics")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Store Management")) {
                    NavigationLink("Events & Products") {
                        MerchantDashboardView()
                            .environmentObject(authViewModel)
                    }
                    
                    NavigationLink("Order Scanner") {
                        OrderScannerView()
                            .environmentObject(authViewModel)
                    }
                    
                    NavigationLink("Inventory Management") {
                        InventoryManagementView()
                    }
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
                
                Section(header: Text("Support & Legal")) {
                    NavigationLink("Help & Support") {
                        MerchantHelpSupportView()
                    }
                    
                    NavigationLink("Terms of Service") {
                        MerchantTermsOfServiceView()
                    }
                    
                    NavigationLink("Privacy Policy") {
                        MerchantPrivacyPolicyView()
                    }
                }
                
                Section(header: Text("Account")) {
                    NavigationLink("Edit Profile") {
                        EditMerchantProfileView()
                            .environmentObject(authViewModel)
                    }
                    
                    Button(action: {
                        authViewModel.signOut()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Placeholder Views for Navigation

struct InventoryManagementView: View {
    var body: some View {
        Text("Inventory Management")
            .navigationTitle("Inventory")
    }
}

struct MerchantHelpSupportView: View {
    var body: some View {
        Text("Merchant Help & Support")
            .navigationTitle("Help")
    }
}

struct MerchantTermsOfServiceView: View {
    var body: some View {
        Text("Merchant Terms of Service")
            .navigationTitle("Terms")
    }
}

struct MerchantPrivacyPolicyView: View {
    var body: some View {
        Text("Merchant Privacy Policy")
            .navigationTitle("Privacy")
    }
}
