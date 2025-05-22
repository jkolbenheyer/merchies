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
                
                // Successfully added product
                if var product = product, let id = id {
                    product.id = id
                    self?.products.append(product)
                }
                
                completion(true)
            }
        }
    }
}
