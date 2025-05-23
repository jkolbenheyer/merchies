import SwiftUI

struct ScannedOrderDetailView: View {
    // Input parameters
    let order: Order
    let onComplete: () -> Void

    // Local state & services
    @State private var isConfirming = false
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

                    Text("Total: $\(String(format: "%.2f", order.amount))")
                        .font(.headline)
                        .padding(.top, 5)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)

                // MARK: — Line Items
                List {
                    Section(header: Text("Items")) {
                        ForEach(order.items, id: \.productId) { item in
                            HStack {
                                Text("Product: \(item.productId.suffix(6))")
                                Spacer()
                                Text("\(item.size) – Qty: \(item.qty)")
                            }
                        }
                    }
                }

                // MARK: — Actions
                if order.status == .pendingPickup {
                    Button("Confirm Pickup") {
                        isConfirming = true
                    }
                    .buttonStyle(ActionButtonStyle(color: .purple))
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
                        orderViewModel.updateOrderStatus(
                            orderId: order.id ?? "",
                            status: .pickedUp
                        ) { success in
                            if success {
                                // Haptic feedback
                                UINotificationFeedbackGenerator()
                                    .notificationOccurred(.success)

                                // Dismiss & notify parent
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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
