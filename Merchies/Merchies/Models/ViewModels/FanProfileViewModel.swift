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
        
        // Load orders and calculate stats
        loadOrders(userId: userId)
        loadEventsAttended(userId: userId)
    }
    
    private func loadOrders(userId: String) {
        print("🔍 FanProfileViewModel.loadOrders: Calling fetchOrders for userId: \(userId)")
        firestoreService.fetchOrders(for: userId) { [weak self] orders, error in
            DispatchQueue.main.async {
                if let orders = orders {
                    print("✅ FanProfileViewModel.loadOrders: Received \(orders.count) orders")
                    print("🔍 Order details:")
                    for (index, order) in orders.enumerated() {
                        print("   Order \(index + 1): ID=\(order.id ?? "nil"), Amount=$\(order.amount), Status=\(order.status), Items=\(order.items.count)")
                    }
                    self?.orders = orders
                    self?.calculateSpendingStats()
                } else if let error = error {
                    print("❌ FanProfileViewModel.loadOrders: Failed to load orders: \(error.localizedDescription)")
                }
                self?.isLoading = false
            }
        }
    }
    
    private func loadEventsAttended(userId: String) {
        // Get unique event IDs from orders
        let eventIds = Set(orders.compactMap { $0.eventId })
        
        var loadedEvents: [Event] = []
        let group = DispatchGroup()
        
        for eventId in eventIds {
            group.enter()
            firestoreService.fetchSingleEvent(eventId: eventId) { event, error in
                if let event = event {
                    loadedEvents.append(event)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.eventsAttended = loadedEvents.sorted { $0.startDate > $1.startDate }
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