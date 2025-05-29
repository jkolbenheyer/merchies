import SwiftUI
import Foundation

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
                    .environmentObject(authViewModel)
                
                OrderHistoryView()
                    .tabItem {
                        Label("Orders", systemImage: "bag")
                    }
                    .environmentObject(authViewModel)
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
                    .environmentObject(authViewModel)
                
            case .merchant:
                MerchantDashboardView()
                    .tabItem {
                        Label("Store", systemImage: "tag")
                    }
                    .environmentObject(authViewModel)
                
                OrderScannerView()
                    .tabItem {
                        Label("Scan", systemImage: "qrcode.viewfinder")
                    }
                    .environmentObject(authViewModel)
                
                MerchantSettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .environmentObject(authViewModel)
                
            case .admin, .superAdmin:
                AdminDashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar")
                    }
                    .environmentObject(authViewModel)
                
                UserManagementView()
                    .tabItem {
                        Label("Users", systemImage: "person.2")
                    }
                    .environmentObject(authViewModel)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .environmentObject(authViewModel)
            }
        }
    }
}
