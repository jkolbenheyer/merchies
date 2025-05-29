import SwiftUI
import Foundation

struct OrderHistoryView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Your Orders")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Spacer()
                Text("Your order history will appear here")
                    .foregroundColor(.gray)
                Spacer()
            }
            .navigationTitle("Orders")
        }
    }
}
