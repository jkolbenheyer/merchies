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
                    return AlertItem(message: error)
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

struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}
