// Models/ViewModels/OrderViewModel.swift
import Foundation
import FirebaseFirestore
import SwiftUI

class OrderViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private let firestoreService = FirestoreService()
    
    // MARK: - Fetch Orders
    
    func fetchOrders(for userId: String) {
        print("🔄 OrderViewModel.fetchOrders: Starting fetch for userId: \(userId)")
        
        // Clear any previous errors immediately
        DispatchQueue.main.async { [weak self] in
            self?.error = nil
        }
        
        // Delay showing loading state to prevent flickering for fast responses
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if self?.orders.isEmpty == true {
                self?.isLoading = true
            }
        }
        
        // Add safety timeout in case Firestore hangs
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                if self?.isLoading == true {
                    print("⏰ OrderViewModel.fetchOrders: Timeout after 15 seconds")
                    self?.isLoading = false
                    self?.error = "Request timed out. Please check your internet connection and try again."
                }
            }
        }
        
        firestoreService.fetchOrders(for: userId) { [weak self] orders, error in
            DispatchQueue.main.async {
                timeoutTimer.invalidate() // Cancel timeout since we got a response
                self?.isLoading = false
                
                if let error = error {
                    print("❌ OrderViewModel.fetchOrders: Error fetching orders: \(error.localizedDescription)")
                    self?.error = error.localizedDescription
                    return
                }
                
                let fetchedOrders = orders ?? []
                print("✅ OrderViewModel.fetchOrders: Fetched \(fetchedOrders.count) orders")
                for (index, order) in fetchedOrders.enumerated() {
                    print("   Order \(index + 1): ID=\(order.id ?? "nil"), Amount=$\(order.amount), Status=\(order.status.rawValue)")
                }
                
                self?.orders = fetchedOrders
                print("📦 OrderViewModel.fetchOrders: Local orders array now has \(self?.orders.count ?? 0) orders")
            }
        }
    }
    
    func fetchOrdersForBand(bandId: String) {
        isLoading = true
        error = nil
        
        firestoreService.fetchOrdersForBand(bandId: bandId) { [weak self] orders, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                
                self?.orders = orders ?? []
            }
        }
    }
    
    // MARK: - Create Order
    
    func createOrder(from cartItems: [CartItem], userId: String, bandId: String, total: Double, completion: @escaping (String?) -> Void) {
        print("🔄 OrderViewModel: Creating order for userId: \(userId)")
        print("🔄 OrderViewModel: Cart items count: \(cartItems.count)")
        print("🔄 OrderViewModel: Total amount: $\(total)")
        
        isLoading = true
        error = nil
        
        // Convert cart items to order items
        let orderItems = cartItems.map { cartItem in
            OrderItem(
                productId: cartItem.product.id ?? "",
                size: cartItem.size,
                qty: cartItem.quantity,
                productTitle: cartItem.product.title,
                productPrice: cartItem.product.price
            )
        }
        
        // Generate QR code for pickup (will use order ID once created)
        let qrCode = "TEMP_QR_\(UUID().uuidString)"
        
        // Create the order
        let newOrder = Order(
            userId: userId,
            bandId: bandId,
            eventId: nil, // Can be set if order is for specific event
            items: orderItems,
            amount: total,
            status: .pendingPickup,
            qrCode: qrCode,
            createdAt: Date()
        )
        
        firestoreService.createOrder(newOrder) { [weak self] orderId, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("❌ OrderViewModel: Failed to create order: \(error.localizedDescription)")
                    self?.error = error.localizedDescription
                    completion(nil)
                    return
                }
                
                if let orderId = orderId {
                    print("✅ OrderViewModel: Order created with ID: \(orderId)")
                    
                    var newOrderWithId = newOrder
                    newOrderWithId.id = orderId
                    newOrderWithId.qrCode = "QR_\(orderId)" // Use orderId for QR code
                    
                    print("🔄 OrderViewModel: Adding order to local cache")
                    self?.orders.insert(newOrderWithId, at: 0) // Add to beginning
                    print("✅ OrderViewModel: Local orders count now: \(self?.orders.count ?? 0)")
                    
                    // Update the order in Firestore with the proper QR code
                    self?.firestoreService.updateOrderQRCode(orderId: orderId, qrCode: newOrderWithId.qrCode) { updateError in
                        if let updateError = updateError {
                            print("⚠️ Failed to update QR code: \(updateError.localizedDescription)")
                        } else {
                            print("✅ QR code updated successfully")
                        }
                    }
                }
                
                completion(orderId)
            }
        }
    }
    
    // MARK: - Update Order Status
    
    func updateOrderStatus(orderId: String, status: OrderStatus, completion: @escaping (Bool) -> Void) {
        firestoreService.updateOrderStatus(orderId: orderId, status: status) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(false)
                    return
                }
                
                // Update the order in the local array
                if let index = self?.orders.firstIndex(where: { $0.id == orderId }) {
                    self?.orders[index].status = status
                }
                
                completion(true)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func clearError() {
        error = nil
    }
    
    func refreshOrders(for userId: String) {
        fetchOrders(for: userId)
    }
    
    func refreshOrdersForBand(bandId: String) {
        fetchOrdersForBand(bandId: bandId)
    }
    
    // MARK: - Computed Properties
    
    var pendingOrders: [Order] {
        return orders.filter { $0.status == .pendingPickup }
    }
    
    var completedOrders: [Order] {
        return orders.filter { $0.status == .pickedUp }
    }
    
    var cancelledOrders: [Order] {
        return orders.filter { $0.status == .cancelled }
    }
    
    var totalRevenue: Double {
        return completedOrders.reduce(0) { $0 + $1.amount }
    }
    
    var totalPendingRevenue: Double {
        return pendingOrders.reduce(0) { $0 + $1.amount }
    }
}
