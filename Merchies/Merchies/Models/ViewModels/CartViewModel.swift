import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - CartItem Model
struct CartItem: Identifiable, Codable {
    let id = UUID()
    let product: Product
    let size: String
    var quantity: Int
}

// MARK: - CartViewModel
class CartViewModel: ObservableObject {
    @Published var cartItems: [CartItem] = []
    @Published var total: Double = 0.0
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private let firestoreService = FirestoreService()
    
    func addToCart(product: Product, size: String) {
        // Check if the item already exists in the cart
        if let index = cartItems.firstIndex(where: { $0.product.id == product.id && $0.size == size }) {
            // Update quantity if we have enough inventory
            if let inventory = product.inventory[size], inventory > cartItems[index].quantity {
                cartItems[index].quantity += 1
                calculateTotal()
            }
        } else {
            // Add new item to cart
            if let inventory = product.inventory[size], inventory > 0 {
                let item = CartItem(product: product, size: size, quantity: 1)
                cartItems.append(item)
                calculateTotal()
            }
        }
    }
    
    func removeFromCart(at index: Int) {
        guard index < cartItems.count else { return }
        cartItems.remove(at: index)
        calculateTotal()
    }
    
    func updateQuantity(at index: Int, quantity: Int) {
        guard index < cartItems.count else { return }
        let item = cartItems[index]
        if let inventory = item.product.inventory[item.size], quantity <= inventory && quantity > 0 {
            cartItems[index].quantity = quantity
            calculateTotal()
        }
    }
    
    func clearCart() {
        cartItems.removeAll()
        total = 0.0
    }
    
    private func calculateTotal() {
        total = cartItems.reduce(0) { $0 + ($1.product.price * Double($1.quantity)) }
    }
    
    // MARK: - Order Creation
    func createOrder(userId: String, bandId: String, eventId: String? = nil, completion: @escaping (String?) -> Void) {
        guard !cartItems.isEmpty else {
            error = "Cart is empty"
            completion(nil)
            return
        }
        
        isLoading = true
        error = nil
        
        // Convert cart items to order items
        let orderItems = cartItems.map { cartItem in
            OrderItem(
                productId: cartItem.product.id ?? "",
                size: cartItem.size,
                qty: cartItem.quantity
            )
        }
        
        // Generate a QR code (in a real app, this would be more secure)
        let qrCode = "QR_\(UUID().uuidString)"
        
        // Create the order
        let newOrder = Order(
            userId: userId,
            bandId: bandId,
            eventId: eventId,
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
                
                // Clear cart after successful order
                self?.clearCart()
                completion(orderId)
            }
        }
    }
}
