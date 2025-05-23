// EventProductsViewModel.swift
import Foundation
import Combine
import FirebaseFirestore

class EventProductsViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var availableProducts: [Product] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Fetch Event Products
    func fetchEventProducts(eventId: String) {
        isLoading = true
        error = nil
        
        let db = Firestore.firestore()
        
        // Fetch products that have this eventId in their eventIds array
        db.collection("products")
            .whereField("event_ids", arrayContains: eventId)
            .whereField("active", isEqualTo: true)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.error = "Failed to load products: \(error.localizedDescription)"
                        return
                    }
                    
                    let products = snapshot?.documents.compactMap { document -> Product? in
                        do {
                            return try document.data(as: Product.self)
                        } catch {
                            print("Error parsing product: \(error)")
                            return nil
                        }
                    }
                    
                    self?.products = products ?? []
                }
            }
    }
    
    // MARK: - Fetch Merchant Products
    func fetchMerchantProducts(merchantId: String, excludingEventId: String? = nil) {
        isLoading = true
        error = nil
        
        let db = Firestore.firestore()
        
        db.collection("products")
            .whereField("band_id", isEqualTo: merchantId)
            .order(by: "title")
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.error = "Failed to load available products: \(error.localizedDescription)"
                        return
                    }
                    
                    let products = snapshot?.documents.compactMap { document -> Product? in
                        do {
                            return try document.data(as: Product.self)
                        } catch {
                            print("Error parsing product: \(error)")
                            return nil
                        }
                    }
                    
                    // Filter out products already assigned to this event
                    let filteredProducts = products?.filter { product in
                        guard let eventId = excludingEventId else { return true }
                        return !product.eventIds.contains(eventId)
                    } ?? []
                    
                    self?.availableProducts = filteredProducts
                }
            }
    }
    
    // MARK: - Add Product to Event
    func addProductToEvent(productId: String, eventId: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let batch = db.batch()
        
        // Update product to include event ID
        let productRef = db.collection("products").document(productId)
        batch.updateData([
            "event_ids": FieldValue.arrayUnion([eventId])
        ], forDocument: productRef)
        
        // Update event to include product ID
        let eventRef = db.collection("events").document(eventId)
        batch.updateData([
            "product_ids": FieldValue.arrayUnion([productId])
        ], forDocument: eventRef)
        
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = "Failed to add product to event: \(error.localizedDescription)"
                    completion(false)
                } else {
                    // Successfully added - refresh the products list
                    self?.fetchEventProducts(eventId: eventId)
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Remove Product from Event
    func removeProductFromEvent(productId: String, eventId: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let batch = db.batch()
        
        // Update product to remove event ID
        let productRef = db.collection("products").document(productId)
        batch.updateData([
            "event_ids": FieldValue.arrayRemove([eventId])
        ], forDocument: productRef)
        
        // Update event to remove product ID
        let eventRef = db.collection("events").document(eventId)
        batch.updateData([
            "product_ids": FieldValue.arrayRemove([productId])
        ], forDocument: eventRef)
        
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = "Failed to remove product from event: \(error.localizedDescription)"
                    completion(false)
                } else {
                    // Successfully removed - update local array
                    self?.products.removeAll { $0.id == productId }
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Bulk Add Products to Event
    func addMultipleProductsToEvent(productIds: [String], eventId: String, completion: @escaping (Bool, Int) -> Void) {
        let db = Firestore.firestore()
        let dispatchGroup = DispatchGroup()
        var successCount = 0
        var errorCount = 0
        
        for productId in productIds {
            dispatchGroup.enter()
            
            let batch = db.batch()
            
            // Update product to include event ID
            let productRef = db.collection("products").document(productId)
            batch.updateData([
                "event_ids": FieldValue.arrayUnion([eventId])
            ], forDocument: productRef)
            
            // Update event to include product ID
            let eventRef = db.collection("events").document(eventId)
            batch.updateData([
                "product_ids": FieldValue.arrayUnion([productId])
            ], forDocument: eventRef)
            
            batch.commit { error in
                DispatchQueue.main.async {
                    if error == nil {
                        successCount += 1
                    } else {
                        errorCount += 1
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            let success = errorCount == 0
            if success {
                // Refresh the products list
                self.fetchEventProducts(eventId: eventId)
            } else {
                self.error = "Failed to add \(errorCount) out of \(productIds.count) products"
            }
            completion(success, successCount)
        }
    }
    
    // MARK: - Update Product Inventory
    func updateProductInventory(productId: String, newInventory: [String: Int], completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("products").document(productId).updateData([
            "inventory": newInventory
        ]) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = "Failed to update inventory: \(error.localizedDescription)"
                    completion(false)
                } else {
                    // Update local product if it exists
                    if let index = self?.products.firstIndex(where: { $0.id == productId }) {
                        self?.products[index].inventory = newInventory
                    }
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Toggle Product Active Status
    func toggleProductActiveStatus(productId: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        
        // First get the current status
        db.collection("products").document(productId).getDocument { [weak self] document, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.error = "Failed to get product status: \(error.localizedDescription)"
                    completion(false)
                }
                return
            }
            
            guard let document = document, document.exists,
                  let currentActive = document.data()?["active"] as? Bool else {
                DispatchQueue.main.async {
                    self?.error = "Product not found"
                    completion(false)
                }
                return
            }
            
            // Toggle the status
            let newStatus = !currentActive
            
            db.collection("products").document(productId).updateData([
                "active": newStatus
            ]) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.error = "Failed to update product status: \(error.localizedDescription)"
                        completion(false)
                    } else {
                        // Update local product if it exists
                        if let index = self?.products.firstIndex(where: { $0.id == productId }) {
                            self?.products[index].active = newStatus
                        }
                        completion(true)
                    }
                }
            }
        }
    }
    
    // MARK: - Get Product Analytics for Event
    func getProductAnalytics(eventId: String, completion: @escaping ([ProductAnalytics]?) -> Void) {
        let db = Firestore.firestore()
        
        // Get all orders for this event
        db.collection("orders")
            .whereField("event_id", isEqualTo: eventId)
            .whereField("status", isNotEqualTo: "cancelled")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.error = "Failed to load analytics: \(error.localizedDescription)"
                        completion(nil)
                    }
                    return
                }
                
                var productSales: [String: ProductAnalytics] = [:]
                
                snapshot?.documents.forEach { document in
                    if let order = try? document.data(as: Order.self) {
                        for item in order.items {
                            let productId = item.productId
                            
                            if productSales[productId] == nil {
                                productSales[productId] = ProductAnalytics(
                                    productId: productId,
                                    productTitle: item.productTitle ?? "Unknown Product",
                                    totalSold: 0,
                                    totalRevenue: 0.0,
                                    averageOrderValue: 0.0
                                )
                            }
                            
                            productSales[productId]?.totalSold += item.qty
                            productSales[productId]?.totalRevenue += (item.productPrice ?? 0.0) * Double(item.qty)
                        }
                    }
                }
                
                // Calculate average order values
                for (_, analytics) in productSales {
                    if analytics.totalSold > 0 {
                        productSales[analytics.productId]?.averageOrderValue = analytics.totalRevenue / Double(analytics.totalSold)
                    }
                }
                
                DispatchQueue.main.async {
                    completion(Array(productSales.values).sorted { $0.totalRevenue > $1.totalRevenue })
                }
            }
    }
    
    // MARK: - Clear Error
    func clearError() {
        error = nil
    }
}

// MARK: - Product Analytics Model
struct ProductAnalytics: Identifiable {
    let id = UUID()
    let productId: String
    let productTitle: String
    var totalSold: Int
    var totalRevenue: Double
    var averageOrderValue: Double
    
    var formattedRevenue: String {
        return String(format: "$%.2f", totalRevenue)
    }
    
    var formattedAverageOrderValue: String {
        return String(format: "$%.2f", averageOrderValue)
    }
}
