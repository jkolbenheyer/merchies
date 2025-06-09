import Foundation
import FirebaseFirestore
import Combine
import SwiftUI

@MainActor
class MerchantProfileViewModel: ObservableObject {
    @Published var totalRevenue: Double = 0
    @Published var totalOrders: Int = 0
    @Published var totalProductsSold: Int = 0
    @Published var activeEvents: [Event] = []
    @Published var recentEvents: [Event] = []
    @Published var topProducts: [MerchantProductSalesData] = []
    @Published var recentOrders: [Order] = []
    @Published var salesData: [SalesDataPoint] = []
    @Published var eventAnalytics: [String: MerchantEventAnalytics] = [:]
    @Published var bandNames: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let firestoreService = FirestoreService()
    private let db = Firestore.firestore()
    
    func loadMerchantData(userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load merchant's bands
            await loadMerchantBands(userId: userId)
            
            // Load events hosted by this merchant
            await loadMerchantEvents(userId: userId)
            
            // Load recent orders for merchant's events
            await loadMerchantOrders(userId: userId)
            
        } catch {
            errorMessage = "Failed to load merchant data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func loadAnalytics(for timeRange: TimeRange) async {
        let (startDate, endDate) = timeRange.dateRange
        
        do {
            // Calculate analytics for the time range
            await calculateAnalytics(from: startDate, to: endDate)
            await generateSalesData(from: startDate, to: endDate)
            await loadTopProducts(from: startDate, to: endDate)
            
        } catch {
            errorMessage = "Failed to load analytics: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Private Methods
    
    private func loadMerchantBands(userId: String) async {
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            if let userData = userDoc.data(),
               let bandIds = userData["band_ids"] as? [String] {
                
                // Load band names
                var names: [String] = []
                for bandId in bandIds {
                    let bandDoc = try await db.collection("bands").document(bandId).getDocument()
                    if let bandData = bandDoc.data(),
                       let bandName = bandData["name"] as? String {
                        names.append(bandName)
                    }
                }
                bandNames = names
            }
        } catch {
            print("Error loading merchant bands: \(error)")
        }
    }
    
    private func loadMerchantEvents(userId: String) async {
        do {
            // Find events where this user is in merchant_ids
            let snapshot = try await db.collection("events")
                .whereField("merchant_ids", arrayContains: userId)
                .order(by: "start_date", descending: true)
                .getDocuments()
            
            let events = snapshot.documents.compactMap { doc -> Event? in
                try? doc.data(as: Event.self)
            }
            
            activeEvents = events.filter { $0.isActive || $0.isUpcoming }
            recentEvents = events
            
            // Load analytics for each event
            for event in events {
                if let eventId = event.id {
                    eventAnalytics[eventId] = await loadEventAnalytics(eventId: eventId)
                }
            }
            
        } catch {
            print("Error loading merchant events: \(error)")
        }
    }
    
    private func loadMerchantOrders(userId: String) async {
        do {
            // Get all orders for events hosted by this merchant
            let eventIds = recentEvents.compactMap { $0.id }
            guard !eventIds.isEmpty else { return }
            
            // Note: We'll need to update Firestore rules to allow this query
            let snapshot = try await db.collection("orders")
                .whereField("event_id", in: eventIds)
                .order(by: "created_at", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            recentOrders = snapshot.documents.compactMap { doc -> Order? in
                try? doc.data(as: Order.self)
            }
            
        } catch {
            print("Error loading merchant orders: \(error)")
            // Fallback: load orders without event filtering
            await loadOrdersFallback()
        }
    }
    
    private func loadOrdersFallback() async {
        do {
            // Load recent orders (less precise but still useful)
            let snapshot = try await db.collection("orders")
                .order(by: "created_at", descending: true)
                .limit(to: 20)
                .getDocuments()
            
            recentOrders = snapshot.documents.compactMap { doc -> Order? in
                try? doc.data(as: Order.self)
            }
        } catch {
            print("Error loading orders fallback: \(error)")
        }
    }
    
    private func calculateAnalytics(from startDate: Date, to endDate: Date) async {
        let filteredOrders = recentOrders.filter { order in
            order.createdAt >= startDate && order.createdAt <= endDate
        }
        
        totalOrders = filteredOrders.count
        totalRevenue = filteredOrders.reduce(0) { $0 + $1.amount }
        totalProductsSold = filteredOrders.reduce(0) { $0 + $1.totalItems }
    }
    
    private func generateSalesData(from startDate: Date, to endDate: Date) async {
        let calendar = Calendar.current
        var dataPoints: [SalesDataPoint] = []
        
        // Generate daily data points for the range
        var currentDate = startDate
        while currentDate <= endDate {
            let dayOrders = recentOrders.filter { order in
                calendar.isDate(order.createdAt, inSameDayAs: currentDate)
            }
            
            let dayRevenue = dayOrders.reduce(0) { $0 + $1.amount }
            dataPoints.append(SalesDataPoint(date: currentDate, amount: dayRevenue))
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        salesData = dataPoints
    }
    
    private func loadTopProducts(from startDate: Date, to endDate: Date) async {
        let filteredOrders = recentOrders.filter { order in
            order.createdAt >= startDate && order.createdAt <= endDate
        }
        
        var productSales: [String: (quantity: Int, revenue: Double)] = [:]
        
        // Aggregate product sales
        for order in filteredOrders {
            for item in order.items {
                let key = item.productId
                let currentData = productSales[key] ?? (quantity: 0, revenue: 0)
                productSales[key] = (
                    quantity: currentData.quantity + item.qty,
                    revenue: currentData.revenue + (item.productPrice ?? 0) * Double(item.qty)
                )
            }
        }
        
        // Load product details and create MerchantProductSalesData
        var salesData: [MerchantProductSalesData] = []
        for (productId, salesInfo) in productSales {
            do {
                let productDoc = try await db.collection("products").document(productId).getDocument()
                if let product = try? productDoc.data(as: Product.self) {
                    salesData.append(MerchantProductSalesData(
                        product: product,
                        quantitySold: salesInfo.quantity,
                        revenue: salesInfo.revenue
                    ))
                }
            } catch {
                print("Error loading product \(productId): \(error)")
            }
        }
        
        // Sort by revenue descending
        topProducts = salesData.sorted { $0.revenue > $1.revenue }
    }
    
    private func loadEventAnalytics(eventId: String) async -> MerchantEventAnalytics {
        let eventOrders = recentOrders.filter { order in
            order.eventId == eventId
        }
        
        let totalRevenue = eventOrders.reduce(0) { $0 + $1.amount }
        let totalOrders = eventOrders.count
        let totalItems = eventOrders.reduce(0) { $0 + $1.totalItems }
        
        return MerchantEventAnalytics(
            totalRevenue: totalRevenue,
            totalOrders: totalOrders,
            totalItems: totalItems
        )
    }
    
    // MARK: - Utility Methods
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Supporting Data Structures moved to MerchantProfileView to avoid redeclaration