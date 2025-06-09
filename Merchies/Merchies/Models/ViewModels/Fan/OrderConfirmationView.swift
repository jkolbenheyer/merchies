import SwiftUI
import Foundation

struct OrderConfirmationView: View {
    let orderId: String
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var orderViewModel = OrderViewModel()
    @State private var order: Order?
    @State private var isLoading = true
    
    var body: some View {
        if isLoading {
            VStack {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                Text("Loading order details...")
                    .foregroundColor(.secondary)
            }
            .onAppear {
                fetchOrderDetails()
            }
        } else {
            ScrollView {
                VStack(spacing: 25) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.green)
                        .padding(.top, 20)
                    
                    Text("Payment Successful!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your order has been placed and payment processed successfully.")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Order Details Card
                    if let order = order {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Order Details")
                                    .font(.headline)
                                Spacer()
                                Text(order.paymentStatus.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Order ID:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(orderId.suffix(8).uppercased())
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Total Amount:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("$\(String(format: "%.2f", order.amount))")
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            
                            if let transactionId = order.transactionId {
                                HStack {
                                    Text("Transaction ID:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(transactionId.suffix(8).uppercased())
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            HStack {
                                Text("Items:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(order.totalItems) item\(order.totalItems == 1 ? "" : "s")")
                                    .fontWeight(.medium)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // QR Code for pickup
                    VStack(spacing: 12) {
                        Text("Show this QR code at pickup")
                            .font(.headline)
                            .foregroundColor(.purple)
                        
                        Text("Present this to the merchant to collect your order")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        // Generate QR code using the same format as OrderViewModel
                        if let qrImage = QRService.generateQRCode(from: "QR_\(orderId)") {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(radius: 2)
                        } else {
                            Text("Could not generate QR code")
                                .foregroundColor(.red)
                                .padding()
                        }
                    }
                    .padding()
                    .background(Color.purple.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private func fetchOrderDetails() {
        print("🔍 OrderConfirmationView: Fetching details for order ID: \(orderId)")
        // Fetch full order details to show payment information
        orderViewModel.fetchOrderByQRCode(qrCode: "QR_\(orderId)") { fetchedOrder in
            DispatchQueue.main.async {
                if let fetchedOrder = fetchedOrder {
                    print("✅ OrderConfirmationView: Successfully loaded order details")
                    self.order = fetchedOrder
                } else {
                    print("❌ OrderConfirmationView: Failed to load order details")
                }
                self.isLoading = false
            }
        }
    }
}   
