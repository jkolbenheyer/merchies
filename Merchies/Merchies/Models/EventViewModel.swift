import Foundation
import CoreLocation
import FirebaseFirestore

class EventViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private let firestoreService = FirestoreService()
    
    func fetchNearbyEvents(latitude: Double, longitude: Double) {
        isLoading = true
        
        // Standard search radius in km
        let searchRadius = 10.0
        
        firestoreService.fetchNearbyEvents(
            latitude: latitude,
            longitude: longitude,
            radiusInKm: searchRadius
        ) { [weak self] events, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                
                self?.events = events ?? []
            }
        }
    }
    
    // NEW: Add this method for merchant event management
    func fetchMerchantEvents(merchantId: String) {
        isLoading = true
        error = nil
        
        let db = Firestore.firestore()
        
        db.collection("events")
            .whereField("merchant_ids", arrayContains: merchantId)
            .order(by: "start_date", descending: false)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.error = error.localizedDescription
                        return
                    }
                    
                    let events = snapshot?.documents.compactMap { document -> Event? in
                        do {
                            return try document.data(as: Event.self)
                        } catch {
                            print("Error parsing event: \(error)")
                            return nil
                        }
                    }
                    
                    self?.events = events ?? []
                }
            }
    }
    
    // NEW: Create a new event
    func createEvent(_ event: Event, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        error = nil
        
        let db = Firestore.firestore()
        
        do {
            let ref = db.collection("events").document()
            var newEvent = event
            newEvent.id = ref.documentID
            
            try ref.setData(from: newEvent) { [weak self] error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.error = error.localizedDescription
                        completion(false, nil)
                    } else {
                        // Add the new event to the local array
                        self?.events.append(newEvent)
                        completion(true, ref.documentID)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = error.localizedDescription
                completion(false, nil)
            }
        }
    }
    
    // NEW: Update an existing event
    func updateEvent(_ event: Event, completion: @escaping (Bool) -> Void) {
        guard let eventId = event.id else {
            error = "Event ID not found"
            completion(false)
            return
        }
        
        isLoading = true
        error = nil
        
        let db = Firestore.firestore()
        
        do {
            try db.collection("events").document(eventId).setData(from: event) { [weak self] error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.error = error.localizedDescription
                        completion(false)
                    } else {
                        // Update the event in the local array
                        if let index = self?.events.firstIndex(where: { $0.id == eventId }) {
                            self?.events[index] = event
                        }
                        completion(true)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = error.localizedDescription
                completion(false)
            }
        }
    }
    
    // NEW: Delete an event
    func deleteEvent(eventId: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        error = nil
        
        let db = Firestore.firestore()
        
        // First, we need to remove this event from all associated products
        db.collection("products")
            .whereField("event_ids", arrayContains: eventId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.error = error.localizedDescription
                        completion(false)
                    }
                    return
                }
                
                let batch = db.batch()
                
                // Remove event ID from all associated products
                snapshot?.documents.forEach { document in
                    batch.updateData([
                        "event_ids": FieldValue.arrayRemove([eventId])
                    ], forDocument: document.reference)
                }
                
                // Delete the event document
                let eventRef = db.collection("events").document(eventId)
                batch.deleteDocument(eventRef)
                
                // Commit the batch
                batch.commit { error in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        
                        if let error = error {
                            self?.error = error.localizedDescription
                            completion(false)
                        } else {
                            // Remove the event from the local array
                            self?.events.removeAll { $0.id == eventId }
                            completion(true)
                        }
                    }
                }
            }
    }
    
    // NEW: Toggle event active status
    func toggleEventStatus(eventId: String, completion: @escaping (Bool) -> Void) {
        guard let eventIndex = events.firstIndex(where: { $0.id == eventId }) else {
            error = "Event not found"
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        let currentStatus = events[eventIndex].active
        let newStatus = !currentStatus
        
        db.collection("events").document(eventId).updateData([
            "active": newStatus
        ]) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(false)
                } else {
                    // Update the local event
                    self?.events[eventIndex].active = newStatus
                    completion(true)
                }
            }
        }
    }
    
    // NEW: Get event by ID
    func fetchEvent(eventId: String, completion: @escaping (Event?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("events").document(eventId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching event: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            guard let document = snapshot, document.exists else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            do {
                let event = try document.data(as: Event.self)
                DispatchQueue.main.async {
                    completion(event)
                }
            } catch {
                print("Error parsing event: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // NEW: Clear error message
    func clearError() {
        error = nil
    }
    
    // NEW: Refresh events (useful for pull-to-refresh)
    func refreshEvents(for merchantId: String? = nil) {
        if let merchantId = merchantId {
            fetchMerchantEvents(merchantId: merchantId)
        } else {
            // If no merchant ID provided, clear the events
            events = []
        }
    }
}
