import Foundation
import Firebase
import FirebaseFirestore

class FirestoreService {
    private let db = Firestore.firestore()
    
    // MARK: - Products
    
    // Fetch products for an event
    func fetchProducts(for eventId: String, completion: @escaping ([Product]?, Error?) -> Void) {
        // First get bands for this event
        db.collection("events").document(eventId).getDocument { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = snapshot?.data(),
                  let merchantIds = data["merchant_ids"] as? [String] else {
                completion([], nil)
                return
            }
            
            // Then get products for these merchants
            self.db.collection("products")
                .whereField("band_id", in: merchantIds)
                .whereField("active", isEqualTo: true)
                .getDocuments { snapshot, error in
                    if let error = error {
                        completion(nil, error)
                        return
                    }
                    
                    let products = snapshot?.documents.compactMap { document -> Product? in
                        try? document.data(as: Product.self)
                    }
                    
                    completion(products, nil)
                }
        }
    }
    
    // NEW: Fetch products directly for a band/merchant
    func fetchProductsForBand(bandId: String, completion: @escaping ([Product]?, Error?) -> Void) {
        db.collection("products")
            .whereField("band_id", isEqualTo: bandId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let products = snapshot?.documents.compactMap { document -> Product? in
                    try? document.data(as: Product.self)
                }
                
                completion(products, nil)
            }
    }
    
    // NEW: Fetch products for multiple bands
    func fetchProductsForBands(bandIds: [String], completion: @escaping ([Product]?, Error?) -> Void) {
        // Check if we have any band IDs
        if bandIds.isEmpty {
            completion([], nil)
            return
        }
        
        db.collection("products")
            .whereField("band_id", in: bandIds)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let products = snapshot?.documents.compactMap { document -> Product? in
                    try? document.data(as: Product.self)
                }
                
                completion(products, nil)
            }
    }
    
    // Get user's band IDs
    func getUserBandIds(userId: String, completion: @escaping ([String]?, Error?) -> Void) {
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let document = snapshot, document.exists else {
                completion([], nil)
                return
            }
            
            // Get bandIds from the user document
            let data = document.data() ?? [:]
            
            // Handle both string and array formats
            var bandIds: [String] = []
            
            if let bandIdString = data["bandIds"] as? String {
                // If bandIds is stored as a single string
                bandIds = [bandIdString]
            } else if let bandIdArray = data["bandIds"] as? [String] {
                // If bandIds is stored as an array of strings
                bandIds = bandIdArray
            }
            
            completion(bandIds, nil)
        }
    }
    
    func createProduct(_ product: Product, completion: @escaping (String?, Error?) -> Void) {
        do {
            let ref = db.collection("products").document()
            var newProduct = product
            newProduct.id = ref.documentID
            
            try ref.setData(from: newProduct) { error in
                if let error = error {
                    completion(nil, error)
                } else {
                    completion(ref.documentID, nil)
                }
            }
        } catch {
            completion(nil, error)
        }
    }
    
    // MARK: - Orders
    
    func createOrder(_ order: Order, completion: @escaping (String?, Error?) -> Void) {
        do {
            let ref = db.collection("orders").document()
            var newOrder = order
            newOrder.id = ref.documentID
            
            try ref.setData(from: newOrder) { error in
                if let error = error {
                    completion(nil, error)
                } else {
                    completion(ref.documentID, nil)
                }
            }
        } catch {
            completion(nil, error)
        }
    }
    
    func fetchOrders(for userId: String, completion: @escaping ([Order]?, Error?) -> Void) {
        db.collection("orders")
            .whereField("user_id", isEqualTo: userId)
            .order(by: "created_at", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let orders = snapshot?.documents.compactMap { document -> Order? in
                    try? document.data(as: Order.self)
                }
                
                completion(orders, nil)
            }
    }
    
    // NEW: Fetch orders for a band/merchant
    func fetchOrdersForBand(bandId: String, completion: @escaping ([Order]?, Error?) -> Void) {
        db.collection("orders")
            .whereField("band_id", isEqualTo: bandId)
            .order(by: "created_at", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let orders = snapshot?.documents.compactMap { document -> Order? in
                    try? document.data(as: Order.self)
                }
                
                completion(orders, nil)
            }
    }
    
    func updateOrderStatus(orderId: String, status: OrderStatus, completion: @escaping (Error?) -> Void) {
        db.collection("orders").document(orderId).updateData([
            "status": status.rawValue
        ]) { error in
            completion(error)
        }
    }
    
    // MARK: - Events
    
    func fetchNearbyEvents(latitude: Double, longitude: Double, radiusInKm: Double, completion: @escaping ([Event]?, Error?) -> Void) {
        // In a real app, you'd implement a geospatial query here
        // For simplicity, we'll just fetch all active events for now
        db.collection("events")
            .whereField("active", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let events = snapshot?.documents.compactMap { document -> Event? in
                    try? document.data(as: Event.self)
                }
                
                // In a real app, you'd filter events by distance here
                completion(events, nil)
            }
    }
}
