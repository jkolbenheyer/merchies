import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            switch authViewModel.authState {
            case .signedIn:
                MainTabView()
            case .signedOut:
                AuthView()
            }
        }
        .alert(item: Binding<AlertItem?>(
            get: {
                if let error = authViewModel.error {
                    return AlertItem(title: "Error", message: "Some error message")
                }
                return nil
            },
            set: { _ in authViewModel.error = nil }
        )) { alertItem in
            Alert(
                title: Text("Error"),
                message: Text(alertItem.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
