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
    
    // NEW: Fetch products for a specific event (using event_ids field) - Different name to avoid conflict
    func fetchProductsForEvent(eventId: String, completion: @escaping ([Product]?, Error?) -> Void) {
        db.collection("products")
            .whereField("event_ids", arrayContains: eventId)
            .whereField("active", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Failed to fetch event products: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                let products = snapshot?.documents.compactMap { document -> Product? in
                    try? document.data(as: Product.self)
                }
                
                print("✅ Fetched \(products?.count ?? 0) products for event")
                completion(products, nil)
            }
    }
    
    // NEW: Fetch available products for a merchant (excluding those already in event)
    func fetchAvailableProductsForMerchant(merchantId: String, excludingEventId: String?, completion: @escaping ([Product]?, Error?) -> Void) {
        db.collection("products")
            .whereField("band_id", isEqualTo: merchantId)
            .whereField("active", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Failed to fetch merchant products: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                var products = snapshot?.documents.compactMap { document -> Product? in
                    try? document.data(as: Product.self)
                } ?? []
                
                // Filter out products already in the event if excludingEventId is provided
                if let eventId = excludingEventId {
                    products = products.filter { product in
                        !product.eventIds.contains(eventId)
                    }
                }
                
                print("✅ Fetched \(products.count) available products for merchant")
                completion(products, nil)
            }
    }
    
    // NEW: Add product to event - Different name to avoid conflict
    func linkProductToEvent(productId: String, eventId: String, completion: @escaping (Bool, Error?) -> Void) {
        // Use a batch write to update both documents atomically
        let batch = db.batch()
        
        // Update event's product list
        let eventRef = db.collection("events").document(eventId)
        batch.updateData([
            "product_ids": FieldValue.arrayUnion([productId])
        ], forDocument: eventRef)
        
        // Update product's event list
        let productRef = db.collection("products").document(productId)
        batch.updateData([
            "event_ids": FieldValue.arrayUnion([eventId])
        ], forDocument: productRef)
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                print("❌ Failed to add product to event: \(error.localizedDescription)")
                completion(false, error)
            } else {
                print("✅ Product added to event successfully")
                completion(true, nil)
            }
        }
    }
    
    // NEW: Remove product from event - Different name to avoid conflict
    func unlinkProductFromEvent(productId: String, eventId: String, completion: @escaping (Bool, Error?) -> Void) {
        // Use a batch write to update both documents atomically
        let batch = db.batch()
        
        // Update event's product list
        let eventRef = db.collection("events").document(eventId)
        batch.updateData([
            "product_ids": FieldValue.arrayRemove([productId])
        ], forDocument: eventRef)
        
        // Update product's event list
        let productRef = db.collection("products").document(productId)
        batch.updateData([
            "event_ids": FieldValue.arrayRemove([eventId])
        ], forDocument: productRef)
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                print("❌ Failed to remove product from event: \(error.localizedDescription)")
                completion(false, error)
            } else {
                print("✅ Product removed from event successfully")
                completion(true, nil)
            }
        }
    }
    
    // MARK: - Events
    
    /// Update an existing event document. Merges only the changed fields.
    func updateEvent(_ event: Event, completion: @escaping (Error?) -> Void) {
        guard let id = event.id else {
            completion(NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing event ID"]))
            return
        }
        do {
            let ref = db.collection("events").document(id)
            try ref.setData(from: event, merge: true, completion: completion)
        } catch {
            completion(error)
        }
    }
    
    // NEW: Enhanced update event method - Different name to avoid conflict
    func saveEvent(_ event: Event, completion: @escaping (Bool, Error?) -> Void) {
        guard let eventId = event.id else {
            completion(false, NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Event ID is nil"]))
            return
        }
        
        do {
            try db.collection("events").document(eventId).setData(from: event, merge: true) { error in
                if let error = error {
                    print("❌ Firestore update error: \(error.localizedDescription)")
                    completion(false, error)
                } else {
                    print("✅ Event updated in Firestore successfully")
                    completion(true, nil)
                }
            }
        } catch {
            print("❌ Event encoding error: \(error.localizedDescription)")
            completion(false, error)
        }
    }
    
    // NEW: Create a new event - Different name to avoid conflict
    func saveNewEvent(_ event: Event, completion: @escaping (Bool, Error?) -> Void) {
        do {
            let ref = db.collection("events").document()
            var newEvent = event
            newEvent.id = ref.documentID
            
            print("📝 Creating event in Firestore with imageUrl: \(newEvent.imageUrl ?? "nil")")
            
            try ref.setData(from: newEvent) { error in
                if let error = error {
                    print("❌ Firestore create error: \(error.localizedDescription)")
                    completion(false, error)
                } else {
                    print("✅ Event created in Firestore successfully")
                    completion(true, nil)
                }
            }
        } catch {
            print("❌ Event encoding error: \(error.localizedDescription)")
            completion(false, error)
        }
    }
    
    // NEW: Fetch a single event by ID
    func fetchSingleEvent(eventId: String, completion: @escaping (Event?, Error?) -> Void) {
        db.collection("events").document(eventId).getDocument { snapshot, error in
            if let error = error {
                print("❌ Firestore fetch error: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists,
                  let event = try? snapshot.data(as: Event.self) else {
                print("❌ Event not found or decode error")
                completion(nil, NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Event not found"]))
                return
            }
            
            print("✅ Event fetched successfully")
            completion(event, nil)
        }
    }
    
    // NEW: Fetch events for a specific merchant
    func fetchEventsForMerchant(merchantId: String, completion: @escaping ([Event]?, Error?) -> Void) {
        db.collection("events")
            .whereField("merchant_ids", arrayContains: merchantId)
            .order(by: "start_date", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Failed to fetch merchant events: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                let events = snapshot?.documents.compactMap { document -> Event? in
                    try? document.data(as: Event.self)
                }
                
                print("✅ Fetched \(events?.count ?? 0) events for merchant")
                completion(events, nil)
            }
    }
    
    // NEW: Delete an event
    func deleteEvent(eventId: String, completion: @escaping (Bool, Error?) -> Void) {
        db.collection("events").document(eventId).delete { error in
            if let error = error {
                print("❌ Failed to delete event: \(error.localizedDescription)")
                completion(false, error)
            } else {
                print("✅ Event deleted successfully")
                completion(true, nil)
            }
        }
    }
    
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
}


