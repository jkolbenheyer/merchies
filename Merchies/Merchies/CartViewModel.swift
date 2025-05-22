import Foundation

class CartViewModel: ObservableObject {
    @Published var cartItems: [CartItem] = []
    @Published var total: Double = 0.0
    
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
        cartItems.remove(at: index)
        calculateTotal()
    }
    
    func updateQuantity(at index: Int, quantity: Int) {
        if index < cartItems.count {
            let item = cartItems[index]
            if let inventory = item.product.inventory[item.size], quantity <= inventory && quantity > 0 {
                cartItems[index].quantity = quantity
                calculateTotal()
            }
        }
    }
    
    func clearCart() {
        cartItems.removeAll()
        total = 0.0
    }
    
    private func calculateTotal() {
        total = cartItems.reduce(0) { $0 + ($1.product.price * Double($1.quantity)) }
    }
}

struct CartItem: Identifiable {
    let id = UUID()
    let product: Product
    let size: String
    var quantity: Int
}

// STEP 13: Create OrderViewModel.swift
// OrderViewModel.swift
import Foundation
import FirebaseFirestore

class OrderViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private let firestoreService = FirestoreService()
    
    func fetchOrders(for userId: String) {
        isLoading = true
        
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
    
    func createOrder(from cartItems: [CartItem], userId: String, bandId: String, total: Double, completion: @escaping (String?) -> Void) {
        isLoading = true
        
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
                
                completion(orderId)
            }
        }
    }
    
    func updateOrderStatus(orderId: String, status: OrderStatus, completion: @escaping (Bool) -> Void) {
        isLoading = true
        
        firestoreService.updateOrderStatus(orderId: orderId, status: status) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(false)
                    return
                }
                
                // Update the local order status
                if let index = self?.orders.firstIndex(where: { $0.id == orderId }) {
                    self?.orders[index].status = status
                }
                
                completion(true)
            }
        }
    }
}
