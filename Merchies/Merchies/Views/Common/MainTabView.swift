import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        TabView {
            switch authViewModel.userRole {
            case .fan:
                FanDashboardView()
                    .tabItem {
                        Label("Discover", systemImage: "music.note")
                    }
                    .environmentObject(authViewModel) // Add this line
                
                OrderHistoryView()
                    .tabItem {
                        Label("Orders", systemImage: "bag")
                    }
                    .environmentObject(authViewModel) // Add this line
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
                    .environmentObject(authViewModel) // Add this line
                
            case .merchant:
                MerchantDashboardView()
                    .tabItem {
                        Label("Store", systemImage: "tag")
                    }
                    .environmentObject(authViewModel) // Add this line
                
                OrderScannerView()
                    .tabItem {
                        Label("Scan", systemImage: "qrcode.viewfinder")
                    }
                    .environmentObject(authViewModel) // Add this line
                
                MerchantSettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .environmentObject(authViewModel) // Add this line
                
            case .admin, .superAdmin:
                AdminDashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar")
                    }
                    .environmentObject(authViewModel) // Add this line
                
                UserManagementView()
                    .tabItem {
                        Label("Users", systemImage: "person.2")
                    }
                    .environmentObject(authViewModel) // Add this line
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .environmentObject(authViewModel) // Add this line
            }
        }
    }
}
