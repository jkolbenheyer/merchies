import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Fan Profile ViewModel

class FanProfileViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var eventsAttended: [Event] = []
    @Published var totalSpent: Double = 0.0
    @Published var totalItemsPurchased: Int = 0
    @Published var favoriteArtists: [String] = []
    @Published var isLoading = false
    
    private let firestoreService = FirestoreService()
    
    func loadProfileData(userId: String) {
        print("🔍 FanProfileViewModel.loadProfileData: Starting load for userId: \(userId)")
        isLoading = true
        
        // Clear existing data to ensure fresh load
        orders = []
        eventsAttended = []
        totalSpent = 0.0
        totalItemsPurchased = 0
        favoriteArtists = []
        
        // Load orders first, then events attended (since events depend on orders)
        loadOrders(userId: userId)
    }
    
    func refreshProfileData(userId: String) {
        print("🔄 FanProfileViewModel.refreshProfileData: Refreshing profile data for userId: \(userId)")
        loadProfileData(userId: userId)
    }
    
    private func loadOrders(userId: String) {
        print("🔍 FanProfileViewModel.loadOrders: Calling fetchOrders for userId: \(userId)")
        firestoreService.fetchOrders(for: userId) { [weak self] orders, error in
            DispatchQueue.main.async {
                if let orders = orders {
                    print("✅ FanProfileViewModel.loadOrders: Received \(orders.count) orders")
                    print("🔍 Order details:")
                    for (index, order) in orders.enumerated() {
                        print("   Order \(index + 1): ID=\(order.id ?? "nil"), Amount=$\(order.amount), Status=\(order.status), Items=\(order.items.count), EventId=\(order.eventId ?? "nil")")
                    }
                    self?.orders = orders
                    self?.calculateSpendingStats()
                    // Load events attended AFTER orders are loaded
                    self?.loadEventsAttended(userId: userId)
                } else if let error = error {
                    print("❌ FanProfileViewModel.loadOrders: Failed to load orders: \(error.localizedDescription)")
                    self?.isLoading = false
                }
            }
        }
    }
    
    private func loadEventsAttended(userId: String) {
        print("🔍 FanProfileViewModel.loadEventsAttended: Starting to load events for userId: \(userId)")
        
        // Get unique event IDs from orders
        let eventIds = Set(orders.compactMap { $0.eventId })
        print("🔍 FanProfileViewModel.loadEventsAttended: Found \(eventIds.count) unique event IDs from \(orders.count) orders")
        print("🔍 Event IDs: \(Array(eventIds))")
        
        // If no event IDs found, set loading to false and return empty array
        if eventIds.isEmpty {
            print("⚠️ FanProfileViewModel.loadEventsAttended: No event IDs found in orders")
            DispatchQueue.main.async {
                self.eventsAttended = []
                self.isLoading = false
            }
            return
        }
        
        var loadedEvents: [Event] = []
        var loadErrors: [String] = []
        let group = DispatchGroup()
        
        for eventId in eventIds {
            group.enter()
            print("🔍 FanProfileViewModel.loadEventsAttended: Fetching event with ID: \(eventId)")
            firestoreService.fetchSingleEvent(eventId: eventId) { event, error in
                defer { group.leave() }
                
                if let event = event {
                    print("✅ FanProfileViewModel.loadEventsAttended: Successfully loaded event: \(event.name)")
                    loadedEvents.append(event)
                } else if let error = error {
                    print("❌ FanProfileViewModel.loadEventsAttended: Failed to load event \(eventId): \(error.localizedDescription)")
                    loadErrors.append("Event \(eventId): \(error.localizedDescription)")
                } else {
                    print("❌ FanProfileViewModel.loadEventsAttended: Event \(eventId) not found")
                    loadErrors.append("Event \(eventId): Not found")
                }
            }
        }
        
        group.notify(queue: .main) {
            print("🔍 FanProfileViewModel.loadEventsAttended: Loading complete. Successfully loaded \(loadedEvents.count) out of \(eventIds.count) events")
            if !loadErrors.isEmpty {
                print("⚠️ FanProfileViewModel.loadEventsAttended: Errors encountered:")
                for error in loadErrors {
                    print("   - \(error)")
                }
            }
            
            let sortedEvents = loadedEvents.sorted { $0.startDate > $1.startDate }
            print("🔍 FanProfileViewModel.loadEventsAttended: Final events being set:")
            for (index, event) in sortedEvents.enumerated() {
                print("   Event \(index + 1): \(event.name) - ID: \(event.id ?? "nil") - Start: \(event.startDate) - Venue: \(event.venueName)")
            }
            
            self.eventsAttended = sortedEvents
            self.isLoading = false
        }
    }
    
    private func calculateSpendingStats() {
        totalSpent = orders.reduce(0) { $0 + $1.amount }
        totalItemsPurchased = orders.reduce(0) { total, order in
            total + order.items.reduce(0) { $0 + $1.qty }
        }
        
        // Calculate favorite artists based on spending
        var artistSpending: [String: Double] = [:]
        for order in orders {
            artistSpending[order.bandId, default: 0] += order.amount
        }
        
        favoriteArtists = artistSpending.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
}

// MARK: - Supporting Data Models

struct EventAttendance {
    let event: Event
    let orders: [Order]
    let totalSpent: Double
    let itemsPurchased: Int
}

struct SpendingByMonth {
    let month: String
    let amount: Double
}

struct FavoriteArtist {
    let bandId: String
    let bandName: String
    let totalSpent: Double
    let eventsAttended: Int
}