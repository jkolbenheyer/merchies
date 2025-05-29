import SwiftUI
import Foundation

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack {
            Text("Settings")
                .font(.largeTitle)
                .padding()
            
            Spacer()
            
            Button(action: {
                authViewModel.signOut()
            }) {
                Text("Sign Out")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(AppConstants.UI.standardCornerRadius)
            }
            .padding(.bottom, 50)
        }
    }
}

