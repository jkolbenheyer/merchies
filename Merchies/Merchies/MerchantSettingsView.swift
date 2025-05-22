import SwiftUI

struct MerchantSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Merchant Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                List {
                    Section(header: Text("Store Information")) {
                        Text("Edit Store Profile")
                        Text("Event Settings")
                        Text("Payment Details")
                    }
                    
                    Section(header: Text("Account")) {
                        Button(action: {
                            authViewModel.signOut()
                        }) {
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
