import Foundation
import Firebase
import FirebaseFirestore
import UserNotifications
import SwiftUI

class OrderNotificationService: ObservableObject {
    @Published var hasNewOrders = false
    @Published var newOrderCount = 0
    @Published var recentOrders: [Order] = []
    
    private var listener: ListenerRegistration?
    private let firestoreService = FirestoreService()
    private var lastCheckTime = Date()
    
    init() {
        requestNotificationPermission()
    }
    
    deinit {
        stopListening()
    }
    
    // MARK: - Notification Permission
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ OrderNotificationService: Notification permission error: \(error.localizedDescription)")
            } else {
                print(granted ? "✅ OrderNotificationService: Notification permission granted" : "⚠️ OrderNotificationService: Notification permission denied")
            }
        }
    }
    
    // MARK: - Real-time Order Listening
    
    func startListening(for merchantId: String) {
        print("🔄 OrderNotificationService: Starting to listen for orders for merchant: \(merchantId)")
        
        // Stop any existing listener
        stopListening()
        
        let db = Firestore.firestore()
        
        // Listen for new orders for this merchant
        listener = db.collection("orders")
            .whereField("band_id", isEqualTo: merchantId)
            .order(by: "created_at", descending: true)
            .limit(to: 20) // Only get recent orders to avoid overwhelming
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ OrderNotificationService: Error listening for orders: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("❌ OrderNotificationService: No snapshot received")
                    return
                }
                
                self?.processOrderUpdates(snapshot: snapshot)
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        print("🔄 OrderNotificationService: Stopped listening for orders")
    }
    
    // MARK: - Process Order Updates
    
    private func processOrderUpdates(snapshot: QuerySnapshot) {
        print("🔄 OrderNotificationService: Processing \(snapshot.documents.count) order documents")
        
        var newOrders: [Order] = []
        var updatedOrders: [Order] = []
        
        for document in snapshot.documents {
            do {
                var order = try document.data(as: Order.self)
                order.setDocumentID(document.documentID)
                
                // Check if this is a new order (created after our last check)
                if order.createdAt > lastCheckTime {
                    newOrders.append(order)
                    print("📦 OrderNotificationService: New order detected: \(order.id ?? "unknown") - $\(order.amount)")
                } else {
                    // Check if this is an existing order that was updated
                    if let existingOrder = recentOrders.first(where: { $0.id == order.id }),
                       existingOrder.status != order.status {
                        updatedOrders.append(order)
                        print("🔄 OrderNotificationService: Order status updated: \(order.id ?? "unknown") - \(order.status.displayName)")
                    }
                }
                
            } catch {
                print("❌ OrderNotificationService: Error decoding order: \(error.localizedDescription)")
            }
        }
        
        // Update our state
        DispatchQueue.main.async {
            // Update recent orders
            self.recentOrders = snapshot.documents.compactMap { document -> Order? in
                do {
                    var order = try document.data(as: Order.self)
                    order.setDocumentID(document.documentID)
                    return order
                } catch {
                    return nil
                }
            }
            
            // Handle new orders
            if !newOrders.isEmpty {
                self.handleNewOrders(newOrders)
            }
            
            // Handle updated orders
            if !updatedOrders.isEmpty {
                self.handleUpdatedOrders(updatedOrders)
            }
        }
        
        // Update last check time
        lastCheckTime = Date()
    }
    
    // MARK: - Handle New Orders
    
    private func handleNewOrders(_ orders: [Order]) {
        hasNewOrders = true
        newOrderCount = orders.count
        
        print("🎉 OrderNotificationService: \(orders.count) new order(s) received!")
        
        // Send local notification for each new order
        for order in orders {
            sendNotificationForNewOrder(order)
        }
        
        // Provide haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        // Auto-clear the new order indicator after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            self.clearNewOrderIndicator()
        }
    }
    
    // MARK: - Handle Updated Orders
    
    private func handleUpdatedOrders(_ orders: [Order]) {
        print("🔄 OrderNotificationService: \(orders.count) order(s) updated")
        
        // Could add notifications for important status changes here
        for order in orders {
            if order.status == .pickedUp {
                // Send notification for completed orders
                sendNotificationForCompletedOrder(order)
            }
        }
    }
    
    // MARK: - Local Notifications
    
    private func sendNotificationForNewOrder(_ order: Order) {
        let content = UNMutableNotificationContent()
        content.title = "New Order! 🎉"
        content.body = "Order #\(order.id?.suffix(6) ?? "??????") - $\(String(format: "%.2f", order.amount))"
        content.sound = .default
        content.badge = NSNumber(value: newOrderCount)
        
        // Add custom data
        content.userInfo = [
            "orderId": order.id ?? "",
            "type": "new_order",
            "amount": order.amount
        ]
        
        let request = UNNotificationRequest(
            identifier: "new_order_\(order.id ?? UUID().uuidString)",
            content: content,
            trigger: nil // Immediate notification
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ OrderNotificationService: Error sending notification: \(error.localizedDescription)")
            } else {
                print("✅ OrderNotificationService: Notification sent for new order")
            }
        }
    }
    
    private func sendNotificationForCompletedOrder(_ order: Order) {
        let content = UNMutableNotificationContent()
        content.title = "Order Completed ✅"
        content.body = "Order #\(order.id?.suffix(6) ?? "??????") has been picked up"
        content.sound = .default
        
        content.userInfo = [
            "orderId": order.id ?? "",
            "type": "order_completed",
            "amount": order.amount
        ]
        
        let request = UNNotificationRequest(
            identifier: "completed_order_\(order.id ?? UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ OrderNotificationService: Error sending completion notification: \(error.localizedDescription)")
            } else {
                print("✅ OrderNotificationService: Completion notification sent")
            }
        }
    }
    
    // MARK: - Public Methods
    
    func clearNewOrderIndicator() {
        hasNewOrders = false
        newOrderCount = 0
        
        // Clear badge
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    func markOrderAsViewed(_ orderId: String) {
        // This could be enhanced to track which specific orders have been viewed
        print("📖 OrderNotificationService: Order \(orderId) marked as viewed")
    }
    
    // MARK: - Order Statistics
    
    var pendingOrdersCount: Int {
        return recentOrders.filter { $0.status == .pendingPickup }.count
    }
    
    var todaysOrdersCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return recentOrders.filter { order in
            Calendar.current.isDate(order.createdAt, inSameDayAs: today)
        }.count
    }
    
    var todaysRevenue: Double {
        let today = Calendar.current.startOfDay(for: Date())
        return recentOrders
            .filter { order in
                Calendar.current.isDate(order.createdAt, inSameDayAs: today) &&
                order.status == .pickedUp
            }
            .reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Order Alert Banner

struct OrderAlertBanner: View {
    @ObservedObject var notificationService: OrderNotificationService
    @State private var navigateToOrders = false
    
    var body: some View {
        if notificationService.hasNewOrders {
            Button(action: {
                navigateToOrders = true
                notificationService.clearNewOrderIndicator()
            }) {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Order\(notificationService.newOrderCount > 1 ? "s" : "")!")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("\(notificationService.newOrderCount) new order\(notificationService.newOrderCount > 1 ? "s" : "") received")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("View")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(6)
                }
                .padding()
                .background(Color.orange)
                .cornerRadius(10)
                .shadow(radius: 4)
            }
            .buttonStyle(PlainButtonStyle())
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(), value: notificationService.hasNewOrders)
            .background(
                NavigationLink(
                    destination: MerchantOrdersView(initialFilter: .pendingPickup),
                    isActive: $navigateToOrders
                ) {
                    EmptyView()
                }
                .hidden()
            )
        }
    }
}