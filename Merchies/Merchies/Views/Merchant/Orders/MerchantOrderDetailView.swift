import SwiftUI
import Foundation

struct MerchantOrderDetailView: View {
    let order: Order
    let onOrderUpdated: () -> Void
    
    @StateObject private var orderViewModel = OrderViewModel()
    @Environment(\.presentationMode) private var presentationMode
    @State private var showingStatusUpdateAlert = false
    @State private var selectedNewStatus: OrderStatus = .pickedUp
    @State private var isUpdatingStatus = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()
    
    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Order Header
                    orderHeaderSection
                    
                    // Customer & Payment Info
                    customerPaymentSection
                    
                    // Order Items
                    orderItemsSection
                    
                    // Order Timeline/Status
                    orderTimelineSection
                    
                    // Action Buttons
                    if order.status != .pickedUp && order.status != .cancelled {
                        actionButtonsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Order Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Update Order Status", isPresented: $showingStatusUpdateAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Update") {
                    updateOrderStatus()
                }
            } message: {
                Text("Are you sure you want to mark this order as \(selectedNewStatus.displayName.lowercased())?")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Order Header Section
    
    private var orderHeaderSection: some View {
        VStack(spacing: 16) {
            // Status Icon and Title
            VStack(spacing: 8) {
                Image(systemName: order.status.systemImageName)
                    .font(.system(size: 40))
                    .foregroundColor(colorForStatus(order.status))
                
                Text("Order #\(order.id?.suffix(8).uppercased() ?? "UNKNOWN")")
                    .font(.title2)
                    .fontWeight(.bold)
                
                OrderStatusBadge(status: order.status)
            }
            
            // Order Date and Amount
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Order Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(Self.dateFormatter.string(from: order.createdAt))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", order.amount))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Customer & Payment Section
    
    private var customerPaymentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(
                    icon: "person.circle",
                    title: "Customer ID",
                    value: order.userId.suffix(8).uppercased(),
                    color: .blue
                )
                
                if let transactionId = order.transactionId {
                    InfoRow(
                        icon: "creditcard",
                        title: "Transaction ID",
                        value: transactionId.suffix(12).uppercased(),
                        color: .green
                    )
                }
                
                InfoRow(
                    icon: order.paymentStatus.systemImageName,
                    title: "Payment Status",
                    value: order.paymentStatus.displayName,
                    color: colorForPaymentStatus(order.paymentStatus)
                )
                
                if let eventId = order.eventId {
                    InfoRow(
                        icon: "calendar",
                        title: "Event ID",
                        value: eventId.suffix(8).uppercased(),
                        color: .purple
                    )
                }
                
                InfoRow(
                    icon: "qrcode",
                    title: "QR Code",
                    value: order.qrCode,
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Order Items Section
    
    private var orderItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Order Items")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(order.totalItems) item\(order.totalItems == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                ForEach(order.items.indices, id: \.self) { index in
                    let item = order.items[index]
                    MerchantOrderItemRow(item: item)
                    
                    if index < order.items.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Order Timeline Section
    
    private var orderTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Timeline")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                TimelineItem(
                    icon: "plus.circle.fill",
                    title: "Order Created",
                    subtitle: Self.shortDateFormatter.string(from: order.createdAt),
                    isCompleted: true,
                    color: .blue
                )
                
                TimelineItem(
                    icon: "creditcard.fill",
                    title: "Payment \(order.paymentStatus == .succeeded ? "Completed" : order.paymentStatus.displayName)",
                    subtitle: order.paymentStatus == .succeeded ? "Payment processed successfully" : "Awaiting payment confirmation",
                    isCompleted: order.paymentStatus == .succeeded,
                    color: order.paymentStatus == .succeeded ? .green : .orange
                )
                
                TimelineItem(
                    icon: "clock.fill",
                    title: "Ready for Pickup",
                    subtitle: order.status == .pendingPickup || order.status == .pickedUp ? "Order prepared" : "Awaiting preparation",
                    isCompleted: order.status == .pendingPickup || order.status == .pickedUp,
                    color: order.status == .pendingPickup || order.status == .pickedUp ? .orange : .gray
                )
                
                TimelineItem(
                    icon: "checkmark.circle.fill",
                    title: "Picked Up",
                    subtitle: order.status == .pickedUp ? "Order completed" : "Awaiting customer pickup",
                    isCompleted: order.status == .pickedUp,
                    color: order.status == .pickedUp ? .green : .gray
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if order.status == .pendingPickup {
                Button(action: {
                    selectedNewStatus = .pickedUp
                    showingStatusUpdateAlert = true
                }) {
                    HStack {
                        if isUpdatingStatus {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("Mark as Picked Up")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(10)
                }
                .disabled(isUpdatingStatus)
            }
            
            if order.status == .pendingPayment || order.status == .pendingPickup {
                Button(action: {
                    selectedNewStatus = .cancelled
                    showingStatusUpdateAlert = true
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Cancel Order")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
                }
                .disabled(isUpdatingStatus)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func updateOrderStatus() {
        guard let orderId = order.id else {
            errorMessage = "Invalid order ID"
            showingError = true
            return
        }
        
        isUpdatingStatus = true
        
        orderViewModel.updateOrderStatus(orderId: orderId, status: selectedNewStatus) { success in
            DispatchQueue.main.async {
                isUpdatingStatus = false
                
                if success {
                    // Provide haptic feedback
                    if selectedNewStatus == .pickedUp {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    
                    // Notify parent view to refresh
                    onOrderUpdated()
                    
                    // Dismiss after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        presentationMode.wrappedValue.dismiss()
                    }
                } else {
                    errorMessage = "Failed to update order status. Please try again."
                    showingError = true
                }
            }
        }
    }
    
    private func colorForStatus(_ status: OrderStatus) -> Color {
        switch status {
        case .pendingPayment: return .blue
        case .pendingPickup: return .orange
        case .pickedUp: return .green
        case .cancelled: return .red
        }
    }
    
    private func colorForPaymentStatus(_ status: PaymentStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .processing: return .blue
        case .succeeded: return .green
        case .failed, .cancelled: return .red
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
    }
}

struct MerchantOrderItemRow: View {
    let item: OrderItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.productTitle ?? "Product \(item.productId.suffix(6))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text("Size: \(item.size)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Qty: \(item.qty)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let price = item.productPrice {
                    Text("$\(String(format: "%.2f", price))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(String(format: "%.2f", item.totalPrice))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } else {
                    Text("Price N/A")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct TimelineItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let isCompleted: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isCompleted ? color : .gray)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isCompleted ? .primary : .secondary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
        }
        .opacity(isCompleted ? 1.0 : 0.6)
    }
}