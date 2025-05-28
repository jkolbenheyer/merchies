import Foundation
import Combine

class ProductViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private let firestoreService = FirestoreService()
    
    func fetchProducts(for eventId: String) {
        isLoading = true
        
        firestoreService.fetchProducts(for: eventId) { [weak self] products, error in
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

    func addProduct(_ product: Product, completion: @escaping (Bool) -> Void) {
        isLoading = true
        
        firestoreService.createProduct(product) { [weak self] id, error in
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

    func deleteProduct(_ productId: String, completion: @escaping (Bool) -> Void) {
        firestoreService.deleteProduct(productId: productId) { [weak self] error in
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
}
