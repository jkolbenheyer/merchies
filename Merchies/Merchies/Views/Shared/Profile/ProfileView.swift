import SwiftUI
import Foundation

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                if let user = authViewModel.user {
                    Text("Email: \(user.email ?? "No email")")
                        .padding()
                }
                
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
            .navigationTitle("Your Profile")
        }
    }
}





