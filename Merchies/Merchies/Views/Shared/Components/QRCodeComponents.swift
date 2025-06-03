import SwiftUI

/// A shared sheet view for showing QR codes for order pickup
struct QRCodeSheet: View {
    let order: Order
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Show this QR code at pickup")
                .font(.headline)
                .padding(.top, 30)
                .onAppear {
                    print("🔄 QRCodeSheet appeared for order: \(order.id ?? "nil")")
                    print("🔄 QR Code string: \(order.qrCode)")
                }

            if let qrImage = QRService.generateQRCode(from: order.qrCode) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 250, height: 250)
                    .overlay(
                        Text("QR Code Error")
                            .foregroundColor(.gray)
                    )
            }

            Text("Order #\(order.id.map { String($0.suffix(6)) } ?? "")")
                .font(.title3)
                .fontWeight(.semibold)

            Text("\(order.items.count) item\(order.items.count > 1 ? "s" : "")")
                .foregroundColor(.gray)

            Button("Close") {
                isPresented = false
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
            .background(Color.purple)
            .cornerRadius(10)
            .padding(.bottom, 30)
        }
    }
}