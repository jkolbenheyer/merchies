import SwiftUI
import Foundation

struct OrderHistoryView: View {
    @EnvironmentObject var orderViewModel: OrderViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedOrder: Order?
    @State private var hasInitiallyLoaded = false
    @State private var qrCodeOrder: Order?
    
    // Date formatter for order list
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()
    
    var body: some View {
        NavigationView {
            Group {
                if orderViewModel.isLoading && !hasInitiallyLoaded && orderViewModel.orders.isEmpty {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading orders...")
                            .foregroundColor(.gray)
                            .padding(.top)
                        
                        Button("Cancel") {
                            orderViewModel.isLoading = false
                        }
                        .padding(.top)
                        .foregroundColor(.purple)
                    }
                } else if let error = orderViewModel.error, orderViewModel.orders.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        Text("Error Loading Orders")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(error)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Try Again") {
                            orderViewModel.clearError()
                            loadOrders()
                        }
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                } else if orderViewModel.orders.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bag")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Orders Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Your order history will appear here after you make your first purchase")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    ZStack {
                        List {
                            ForEach(orderViewModel.orders.sorted { $0.createdAt > $1.createdAt }) { order in
                                OrderRowView(
                                    order: order,
                                    onTapOrder: {
                                        selectedOrder = order
                                    },
                                    onTapQRCode: {
                                        print("🔄 QR Code tapped for order: \(order.id ?? "nil")")
                                        print("🔄 QR Code string: \(order.qrCode)")
                                        qrCodeOrder = order
                                        print("🔄 Set qrCodeOrder to: \(qrCodeOrder?.id ?? "nil")")
                                    }
                                )
                            }
                        }
                        .listStyle(PlainListStyle())
                        .refreshable {
                            refreshOrders()
                        }
                        
                        // Show subtle loading indicator in top right during refresh
                        if orderViewModel.isLoading && !orderViewModel.orders.isEmpty {
                            VStack {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.trailing)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Orders")
            .onAppear {
                if !hasInitiallyLoaded {
                    loadOrders()
                }
            }
            .sheet(item: $selectedOrder) { order in
                OrderDetailView(order: order)
            }
            .sheet(item: $qrCodeOrder) { order in
                QRCodeSheetWrapper(order: order, qrCodeOrder: $qrCodeOrder)
            }
        }
    }
    
    private func loadOrders() {
        guard let user = authViewModel.user else { 
            print("❌ OrderHistoryView: No user found")
            orderViewModel.isLoading = false
            hasInitiallyLoaded = true
            return 
        }
        print("🔄 OrderHistoryView: Loading orders for user: \(user.uid)")
        
        // Add a timeout to prevent infinite loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if orderViewModel.isLoading {
                print("⏰ OrderHistoryView: Fetch timeout after 10 seconds")
                orderViewModel.isLoading = false
                orderViewModel.error = "Failed to load orders. Please try again."
                hasInitiallyLoaded = true
            }
        }
        
        orderViewModel.fetchOrders(for: user.uid)
        hasInitiallyLoaded = true
    }
    
    private func refreshOrders() {
        guard let user = authViewModel.user else { return }
        orderViewModel.refreshOrders(for: user.uid)
    }
}

// Wrapper for QRCodeSheet to handle the binding properly
struct QRCodeSheetWrapper: View {
    let order: Order
    @Binding var qrCodeOrder: Order?
    
    var body: some View {
        QRCodeSheet(
            order: order,
            isPresented: Binding(
                get: { qrCodeOrder != nil },
                set: { if !$0 { qrCodeOrder = nil } }
            )
        )
        .onAppear {
            print("🔄 QRCodeSheetWrapper appeared with order: \(order.id ?? "nil")")
            print("🔄 Order QR code: \(order.qrCode)")
        }
    }
}

struct OrderRowView: View {
    let order: Order
    let onTapOrder: () -> Void
    let onTapQRCode: () -> Void
    
    // Date formatter for order rows
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Order #\(order.id.map { String($0.suffix(6)) } ?? "")")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(Self.dateFormatter.string(from: order.createdAt))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "$%.2f", order.amount))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    statusBadge(for: order.status)
                }
            }
            
            HStack {
                Text("\(order.totalItems) item\(order.totalItems == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if order.status == .pendingPickup {
                    HStack(spacing: 4) {
                        Image(systemName: "qrcode")
                            .font(.caption)
                        Text("Tap for QR code")
                            .font(.caption)
                    }
                    .foregroundColor(.purple)
                    .onTapGesture {
                        onTapQRCode()
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTapOrder()
        }
    }
    
    @ViewBuilder
    private func statusBadge(for status: OrderStatus) -> some View {
        let (bg, fg): (Color, Color) = {
            switch status {
            case .pendingPickup: return (Color.orange.opacity(0.2), .orange)
            case .pickedUp:      return (Color.green.opacity(0.2),  .green)
            case .cancelled:     return (Color.red.opacity(0.2),    .red)
            }
        }()
        
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(bg)
            .foregroundColor(fg)
            .cornerRadius(12)
    }
}
