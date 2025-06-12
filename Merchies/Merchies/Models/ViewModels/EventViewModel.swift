import Foundation
import CoreLocation
import FirebaseFirestore
import SwiftUI

enum EventSortOption: String, CaseIterable {
    case eventDateDesc = "Event Date (Newest First)"
    case eventDateAsc = "Event Date (Oldest First)"
    case endDateDesc = "End Date (Latest First)"
    case endDateAsc = "End Date (Earliest First)"
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case statusDesc = "Status (Active First)"
}

enum EventFilterOption: String, CaseIterable {
    case all = "All Events"
    case active = "Active Only"
    case archived = "Archived Only"
    case upcoming = "Upcoming"
    case past = "Past Events"
}

class EventViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var sortOption: EventSortOption = .eventDateDesc
    @Published var filterOption: EventFilterOption = .all
    
    private let firestoreService = FirestoreService()
    private var originalEvents: [Event] = []
    
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
        
        // Remove ordering from Firestore query since we'll sort locally
        db.collection("events")
            .whereField("merchant_ids", arrayContains: merchantId)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.error = error.localizedDescription
                        return
                    }
                    
                    let fetchedEvents = snapshot?.documents.compactMap { document -> Event? in
                        do {
                            var event = try document.data(as: Event.self)
                            // Ensure the document ID is set
                            event.id = document.documentID
                            print("📅 Fetched event: \(event.name) with ID: \(event.id ?? "nil")")
                            return event
                        } catch {
                            print("Error parsing event: \(error)")
                            return nil
                        }
                    } ?? []
                    
                    self?.originalEvents = fetchedEvents
                    self?.sortEvents()
                }
            }
    }
    
    // MARK: - Sorting Methods
    
    func setSortOption(_ option: EventSortOption) {
        sortOption = option
        sortEvents()
    }
    
    func setFilterOption(_ option: EventFilterOption) {
        filterOption = option
        sortEvents()
    }
    
    private func sortEvents() {
        let filteredEvents = filterEvents(originalEvents, by: filterOption)
        events = sortedEvents(filteredEvents, by: sortOption)
    }
    
    private func filterEvents(_ events: [Event], by filter: EventFilterOption) -> [Event] {
        switch filter {
        case .all:
            return events
        case .active:
            return events.filter { !$0.archived && $0.active }
        case .archived:
            return events.filter { $0.archived }
        case .upcoming:
            return events.filter { !$0.archived && $0.isUpcoming }
        case .past:
            return events.filter { !$0.archived && $0.isPast }
        }
    }
    
    private func sortedEvents(_ events: [Event], by option: EventSortOption) -> [Event] {
        switch option {
        case .eventDateDesc:
            return events.sorted { (event1: Event, event2: Event) -> Bool in
                return event1.startDate > event2.startDate
            }
        case .eventDateAsc:
            return events.sorted { (event1: Event, event2: Event) -> Bool in
                return event1.startDate < event2.startDate
            }
        case .endDateDesc:
            return events.sorted { (event1: Event, event2: Event) -> Bool in
                return event1.endDate > event2.endDate
            }
        case .endDateAsc:
            return events.sorted { (event1: Event, event2: Event) -> Bool in
                return event1.endDate < event2.endDate
            }
        case .nameAsc:
            return events.sorted { (event1: Event, event2: Event) -> Bool in
                return event1.name.localizedCaseInsensitiveCompare(event2.name) == .orderedAscending
            }
        case .nameDesc:
            return events.sorted { (event1: Event, event2: Event) -> Bool in
                return event1.name.localizedCaseInsensitiveCompare(event2.name) == .orderedDescending
            }
        case .statusDesc:
            return events.sorted { (event1: Event, event2: Event) -> Bool in
                // Active events first, then upcoming, then ended
                let priority1 = event1.isActive ? 3 : (event1.isUpcoming ? 2 : 1)
                let priority2 = event2.isActive ? 3 : (event2.isUpcoming ? 2 : 1)
                
                if priority1 != priority2 {
                    return priority1 > priority2
                } else {
                    // If same status, sort by event date descending
                    return event1.startDate > event2.startDate
                }
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
    
    // NEW: Archive an event
    func archiveEvent(eventId: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        error = nil
        
        firestoreService.archiveEvent(eventId: eventId) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(false)
                } else if success {
                    // Update the event in the local array
                    if let index = self?.events.firstIndex(where: { $0.id == eventId }) {
                        self?.events[index].archived = true
                    }
                    completion(true)
                } else {
                    self?.error = "Failed to archive event"
                    completion(false)
                }
            }
        }
    }
    
    // NEW: Unarchive an event
    func unarchiveEvent(eventId: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        error = nil
        
        firestoreService.unarchiveEvent(eventId: eventId) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(false)
                } else if success {
                    // Update the event in the local array
                    if let index = self?.events.firstIndex(where: { $0.id == eventId }) {
                        self?.events[index].archived = false
                    }
                    completion(true)
                } else {
                    self?.error = "Failed to unarchive event"
                    completion(false)
                }
            }
        }
    }
    
    // NEW: Auto-archive expired events
    func autoArchiveExpiredEvents(for merchantId: String, completion: @escaping (Int) -> Void) {
        firestoreService.autoArchiveExpiredEvents(for: merchantId) { [weak self] archivedCount, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(0)
                } else {
                    // Refresh events list to reflect archived status
                    self?.fetchMerchantEvents(merchantId: merchantId)
                    completion(archivedCount)
                }
            }
        }
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
    
    // MARK: - Computed Properties
    
    var activeEventsCount: Int {
        return originalEvents.filter { !$0.archived && $0.active }.count
    }
    
    var archivedEventsCount: Int {
        return originalEvents.filter { $0.archived }.count
    }
    
    var expiredEventsCount: Int {
        return originalEvents.filter { !$0.archived && $0.isPast }.count
    }
    
    var upcomingEventsCount: Int {
        return originalEvents.filter { !$0.archived && $0.isUpcoming }.count
    }
}
