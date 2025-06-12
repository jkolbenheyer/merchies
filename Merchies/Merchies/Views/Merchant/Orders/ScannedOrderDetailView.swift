import SwiftUI
import Foundation

struct ScannedOrderDetailView: View {
    // Input parameters
    let order: Order
    let onComplete: () -> Void

    // Local state & services
    @State private var isConfirming = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @StateObject private var orderViewModel = OrderViewModel()
    @Environment(\.presentationMode) private var presentationMode

    // Static formatter to avoid `let` inside the body
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()

    var body: some View {
        NavigationView {
            VStack {
                // MARK: — Status Header
                VStack(spacing: 10) {
                    if order.status == .pendingPickup {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("Ready for Pickup")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.bottom, 5)

                    } else if order.status == .pickedUp {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        Text("Already Picked Up")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.bottom, 5)

                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text("Cancelled")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.bottom, 5)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    order.status == .pendingPickup ? Color.orange.opacity(0.1) :
                    order.status == .pickedUp     ? Color.green.opacity(0.1) :
                                                    Color.red.opacity(0.1)
                )
                .cornerRadius(10)
                .padding()

                // MARK: — Order Details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Order #\(order.id?.suffix(6) ?? "")")
                        .font(.headline)

                    Text("Ordered: \(Self.dateFormatter.string(from: order.createdAt))")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    HStack {
                        Text("Total: $\(String(format: "%.2f", order.amount))")
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
                    .padding(.top, 5)
                    
                    if let transactionId = order.transactionId {
                        Text("Transaction: \(transactionId.suffix(8).uppercased())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)

                // MARK: — Line Items
                List {
                    Section(header: Text("Order Items (\(order.totalItems) items)")) {
                        ForEach(order.items, id: \.productId) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.productTitle ?? "Product \(item.productId.suffix(6))")
                                        .font(.headline)
                                        .lineLimit(2)
                                    Spacer()
                                    Text("Qty: \(item.qty)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.cyan)
                                }
                                
                                HStack {
                                    Text("Size: \(item.size)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if let price = item.productPrice {
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("$\(String(format: "%.2f", price)) each")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("$\(String(format: "%.2f", item.totalPrice))")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.cyan)
                                        }
                                    }
                                }
                                
                                if item.qty > 1 {
                                    Text("\(item.qty) × \(item.productTitle ?? "Product")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: — Actions
                if order.status == .pendingPickup {
                    Button("Confirm Pickup") {
                        isConfirming = true
                    }
                    .buttonStyle(ActionButtonStyle(color: .cyan))
                    .padding()

                } else {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                        onComplete()
                    }
                    .buttonStyle(ActionButtonStyle(color: .gray))
                    .padding()
                }
            }
            .navigationTitle("Order Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                        onComplete()
                    }
                }
            }
            .alert(isPresented: $isConfirming) {
                Alert(
                    title: Text("Confirm Pickup"),
                    message: Text("Are you sure you want to mark this order as picked up?"),
                    primaryButton: .default(Text("Yes")) {
                        guard let orderId = order.id, !orderId.isEmpty else {
                            print("❌ ScannedOrderDetailView: Cannot update order - missing or empty order ID")
                            // Show error to user
                            DispatchQueue.main.async {
                                self.errorMessage = "Error: Order ID is missing. Please try scanning the QR code again."
                                self.showingError = true
                            }
                            return
                        }
                        
                        print("🔄 ScannedOrderDetailView: Updating order status for orderId: \(orderId)")
                        orderViewModel.updateOrderStatus(
                            orderId: orderId,
                            status: .pickedUp
                        ) { success in
                            if success {
                                print("✅ ScannedOrderDetailView: Order status updated successfully")
                                // Haptic feedback
                                UINotificationFeedbackGenerator()
                                    .notificationOccurred(.success)

                                // Dismiss & notify parent
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    presentationMode.wrappedValue.dismiss()
                                    onComplete()
                                }
                            } else {
                                print("❌ ScannedOrderDetailView: Failed to update order status")
                                DispatchQueue.main.async {
                                    self.errorMessage = "Failed to update order status. Please try again."
                                    self.showingError = true
                                }
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
}

// MARK: — Reusable button style
private struct ActionButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
