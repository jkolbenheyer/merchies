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
                
                OrderHistoryView()
                    .tabItem {
                        Label("Orders", systemImage: "bag")
                    }
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
                
            case .merchant:
                MerchantDashboardView()
                    .tabItem {
                        Label("Store", systemImage: "tag")
                    }
                
                OrderScannerView()
                    .tabItem {
                        Label("Scan", systemImage: "qrcode.viewfinder")
                    }
                
                MerchantSettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                
            case .admin:
                AdminDashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar")
                    }
                
                UserManagementView()
                    .tabItem {
                        Label("Users", systemImage: "person.2")
                    }
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
        }
    }
}
    