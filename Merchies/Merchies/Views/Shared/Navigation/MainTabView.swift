import SwiftUI
import Foundation

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var orderViewModel = OrderViewModel()
    
    var body: some View {
        TabView {
            switch authViewModel.userRole {
            case .fan:
                FanDashboardView()
                    .tabItem {
                        Label("Discover", systemImage: "music.note")
                    }
                    .environmentObject(authViewModel)
                    .environmentObject(orderViewModel)
                
                OrderHistoryView()
                    .tabItem {
                        Label("Orders", systemImage: "bag")
                    }
                    .environmentObject(authViewModel)
                    .environmentObject(orderViewModel)
                
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
                
                MerchantOrdersView(initialFilter: .all)
                    .tabItem {
                        Label("Orders", systemImage: "bag.fill")
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
