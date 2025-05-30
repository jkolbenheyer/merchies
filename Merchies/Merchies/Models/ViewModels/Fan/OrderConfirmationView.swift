import SwiftUI
import Foundation

struct OrderConfirmationView: View {
    let orderId: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.green)
                .padding(.top, 50)
            
            Text("Order Confirmed!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your order has been placed successfully.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if !orderId.isEmpty {
                VStack(alignment: .center, spacing: 5) {
                    Text("Order ID:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text(orderId)
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
            }
            
            // QR Code for pickup
            VStack {
                Text("Show this QR code at the pickup booth")
                    .font(.headline)
                
                if let qrImage = QRService.generateQRCode(from: orderId) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding()
                } else {
                    Text("Could not generate QR code")
                        .foregroundColor(.red)
                }
            }
            .padding()
            
            Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(width: 200)
            .padding()
            .background(Color.purple)
            .cornerRadius(10)
            .padding(.bottom, 40)
        }
        .padding()
    }
}   
