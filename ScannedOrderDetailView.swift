import SwiftUI

struct ScannedOrderDetailView: View {
    let order: Order
    let onComplete: () -> Void
    @State private var isConfirming = false
    @StateObject private var orderViewModel = OrderViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                // Order status
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
                    order.status == .pickedUp ? Color.green.opacity(0.1) :
                    Color.red.opacity(0.1)
                )
                .cornerRadius(10)
                .padding()
                
                // Order details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Order #\(order.id?.suffix(6) ?? "")")
                        .font(.headline)
                    
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    Text("Ordered: \(formatter.string(from: order.createdAt))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("Total: $\(String(format: "%.2f", order.amount))")
                        .font(.headline)
                        .padding(.top, 5)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Items list
                List {
                    Section(header: Text("Items")) {
                        ForEach(order.items, id: \.productId) { item in
                            HStack {
                                Text("Product: \(item.productId.suffix(6))")
                                Spacer()
                                Text("\(item.size) - Qty: \(item.qty)")
                            }
                        }
                    }
                }
                
                // Action buttons
                if order.status == .pendingPickup {
                    Button(action: {
                        isConfirming = true
                    }) {
                        Text("Confirm Pickup")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(10)
                    }
                    .padding()
                } else {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                        onComplete()
                    }) {
                        Text("Close")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .cornerRadius(10)
                    }
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
                        // In a real app, you would update the order status in Firestore
                        orderViewModel.updateOrderStatus(orderId: order.id ?? "", status: .pickedUp) { success in
                            if success {
                                // Simulate updating the local order
                                var updatedOrder = order
                                updatedOrder.status = .pickedUp
                                scannedOrder = updatedOrder
                                
                                // Haptic feedback
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                
                                // Dismiss after a short delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    presentationMode.wrappedValue.dismiss()
                                    onComplete()
                                }
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}
