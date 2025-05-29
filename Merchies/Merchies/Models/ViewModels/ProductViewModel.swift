import Foundation
import FirebaseFirestore
import SwiftUI
import Combine

class ProductViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private let firestoreService = FirestoreService()
    
    func fetchProducts(for eventId: String) {
        isLoading = true
        
        firestoreService.fetchProducts(for: eventId) { [weak self] (products: [Product]?, error: Error?) in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                
                self?.products = products ?? []
            }
        }
    }

    func addProduct(_ product: Product, completion: @escaping (_ success: Bool) -> Void) {
        isLoading = true
        
        firestoreService.createProduct(product) { [weak self] (id: String?, error: Error?) in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(false)
                    return
                }
                
                if let id = id {
                    var newProduct = product
                    newProduct.id = id
                    self?.products.append(newProduct)
                }
                
                completion(true)
            }
        }
    }

    func deleteProduct(_ productId: String, completion: @escaping (_ success: Bool) -> Void) {
        firestoreService.deleteProduct(productId: productId) { [weak self] (error: Error?) in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(false)
                } else {
                    self?.products.removeAll { $0.id == productId }
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func clearError() {
        error = nil
    }
    
    func refreshProducts(for eventId: String) {
        fetchProducts(for: eventId)
    }
    
    // MARK: - Computed Properties
    
    var activeProducts: [Product] {
        return products.filter { $0.active }
    }
    
    var inactiveProducts: [Product] {
        return products.filter { !$0.active }
    }
    
    var totalInventory: Int {
        return products.reduce(0) { $0 + $1.totalInventory }
    }
}
