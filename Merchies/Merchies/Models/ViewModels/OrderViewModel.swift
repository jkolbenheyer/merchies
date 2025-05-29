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
        isLoading = true
        error = nil
        
        firestoreService.fetchOrders(for: userId) { [weak self] orders, error in
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
        
        // Generate QR code for pickup
        let qrCode = "QR_\(UUID().uuidString)"
        
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
                    self?.error = error.localizedDescription
                    completion(nil)
                    return
                }
                
                // Add the new order to the local array if we have orders loaded
                if let orderId = orderId {
                    var newOrderWithId = newOrder
                    newOrderWithId.id = orderId
                    self?.orders.insert(newOrderWithId, at: 0) // Add to beginning
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
