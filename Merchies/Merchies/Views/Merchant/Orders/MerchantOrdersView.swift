import SwiftUI
import Foundation

struct MerchantOrdersView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var orderViewModel = OrderViewModel()
    @StateObject private var notificationService = OrderNotificationService()
    @State private var selectedFilter: OrderFilter
    @State private var selectedSortOption: OrderSortOption = .dateDesc
    @State private var searchText = ""
    @State private var showingOrderDetail: Order? = nil
    @State private var isRefreshing = false
    
    init(initialFilter: OrderFilter = .all) {
        self._selectedFilter = State(initialValue: initialFilter)
    }
    
    enum OrderFilter: String, CaseIterable {
        case all = "All Orders"
        case todaysOrders = "Today's Orders"
        case pendingPickup = "Pending Pickup"
        case pickedUp = "Picked Up"
        case pendingPayment = "Pending Payment"
        case cancelled = "Cancelled"
        case todaysCompleted = "Today's Completed"
        
        static var visibleCases: [OrderFilter] {
            return [.all, .todaysOrders, .pendingPickup, .pickedUp, .pendingPayment, .cancelled]
        }
        
        var status: OrderStatus? {
            switch self {
            case .all, .todaysOrders, .todaysCompleted: return nil
            case .pendingPickup: return .pendingPickup
            case .pickedUp: return .pickedUp
            case .pendingPayment: return .pendingPayment
            case .cancelled: return .cancelled
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .blue
            case .todaysOrders: return .cyan
            case .todaysCompleted: return .green
            case .pendingPickup: return .orange
            case .pickedUp: return .green
            case .pendingPayment: return .purple
            case .cancelled: return .red
            }
        }
    }
    
    enum OrderSortOption: String, CaseIterable {
        case dateDesc = "Date (Newest First)"
        case dateAsc = "Date (Oldest First)"
        case amountDesc = "Amount (Highest First)"
        case amountAsc = "Amount (Lowest First)"
        case statusDesc = "Status (Pending First)"
    }
    
    var filteredAndSortedOrders: [Order] {
        // Use real-time orders from notification service if available, fallback to orderViewModel
        let orders = notificationService.recentOrders.isEmpty ? orderViewModel.orders : notificationService.recentOrders
        var filtered = orders
        
        // Apply status filter
        if let filterStatus = selectedFilter.status {
            filtered = filtered.filter { $0.status == filterStatus }
        }
        
        // Apply today's orders filter
        if selectedFilter == .todaysOrders {
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
            filtered = filtered.filter { order in
                order.createdAt >= today && order.createdAt < tomorrow
            }
        }
        
        // Apply today's completed orders filter
        if selectedFilter == .todaysCompleted {
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
            filtered = filtered.filter { order in
                order.createdAt >= today && order.createdAt < tomorrow && order.status == .pickedUp
            }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { order in
                // Search in order ID, item names, or transaction ID
                let orderIdMatch = order.id?.localizedCaseInsensitiveContains(searchText) ?? false
                let transactionMatch = order.transactionId?.localizedCaseInsensitiveContains(searchText) ?? false
                let itemMatch = order.items.contains { item in
                    item.productTitle?.localizedCaseInsensitiveContains(searchText) ?? false
                }
                return orderIdMatch || transactionMatch || itemMatch
            }
        }
        
        // Apply sorting
        switch selectedSortOption {
        case .dateDesc:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        case .dateAsc:
            return filtered.sorted { $0.createdAt < $1.createdAt }
        case .amountDesc:
            return filtered.sorted { $0.amount > $1.amount }
        case .amountAsc:
            return filtered.sorted { $0.amount < $1.amount }
        case .statusDesc:
            return filtered.sorted { order1, order2 in
                let priority1 = statusPriority(order1.status)
                let priority2 = statusPriority(order2.status)
                if priority1 != priority2 {
                    return priority1 > priority2
                }
                return order1.createdAt > order2.createdAt
            }
        }
    }
    
    var orderStats: (total: Int, pending: Int, revenue: Double, pendingRevenue: Double) {
        let orders = notificationService.recentOrders.isEmpty ? orderViewModel.orders : notificationService.recentOrders
        let total = orders.count
        let pending = orders.filter { $0.status == .pendingPickup }.count
        let revenue = orders.filter { $0.status == .pickedUp }.reduce(0) { $0 + $1.amount }
        let pendingRevenue = orders.filter { $0.status == .pendingPickup }.reduce(0) { $0 + $1.amount }
        return (total, pending, revenue, pendingRevenue)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Header
                orderStatsHeader
                
                // Search and Filters
                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search orders...", text: $searchText)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Filter Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(OrderFilter.visibleCases, id: \.self) { filter in
                                OrderFilterChip(
                                    title: filter.rawValue,
                                    count: countForFilter(filter),
                                    isSelected: selectedFilter == filter,
                                    color: filter.color
                                ) {
                                    selectedFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Sort Options
                    HStack {
                        Text("Sort by:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Menu {
                            ForEach(OrderSortOption.allCases, id: \.self) { option in
                                Button(action: {
                                    selectedSortOption = option
                                }) {
                                    HStack {
                                        Text(option.rawValue)
                                        if selectedSortOption == option {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedSortOption.rawValue)
                                    .font(.caption)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                // Orders List
                if orderViewModel.isLoading && orderViewModel.orders.isEmpty {
                    loadingView
                } else if filteredAndSortedOrders.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredAndSortedOrders) { order in
                                MerchantOrderCard(order: order) {
                                    showingOrderDetail = order
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .refreshable {
                        await refreshOrders()
                    }
                }
            }
            .navigationTitle("Orders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await refreshOrders()
                        }
                    }
                }
            }
            .sheet(item: $showingOrderDetail) { order in
                MerchantOrderDetailView(order: order) {
                    loadOrders()
                }
            }
            .onAppear {
                loadOrders()
                startRealTimeUpdates()
            }
            .onDisappear {
                notificationService.stopListening()
            }
        }
    }
    
    // MARK: - Stats Header
    
    private var orderStatsHeader: some View {
        HStack {
            OrderStatCard(
                title: "Total Orders",
                value: "\(orderStats.total)",
                icon: "bag.fill",
                color: .blue
            )
            
            OrderStatCard(
                title: "Pending",
                value: "\(orderStats.pending)",
                icon: "clock.fill",
                color: .orange
            )
            
            OrderStatCard(
                title: "Revenue",
                value: "$\(String(format: "%.0f", orderStats.revenue))",
                icon: "dollarsign.circle.fill",
                color: .green
            )
            
            OrderStatCard(
                title: "Pending $",
                value: "$\(String(format: "%.0f", orderStats.pendingRevenue))",
                icon: "hourglass",
                color: .purple
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Loading and Empty States
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            
            Text("Loading orders...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: orderViewModel.orders.isEmpty ? "bag.badge.plus" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(orderViewModel.orders.isEmpty ? "No Orders Yet" : "No Orders Found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(orderViewModel.orders.isEmpty ?
                 "Orders from fans will appear here when they make purchases at your events." :
                 "Try adjusting your search or filter criteria")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Functions
    
    private func loadOrders() {
        guard let user = authViewModel.user else { return }
        orderViewModel.fetchOrdersForBand(bandId: user.uid)
    }
    
    private func refreshOrders() async {
        isRefreshing = true
        loadOrders()
        
        // Add a small delay to show the refresh animation
        try? await Task.sleep(nanoseconds: 500_000_000)
        isRefreshing = false
    }
    
    private func startRealTimeUpdates() {
        guard let user = authViewModel.user else { return }
        notificationService.startListening(for: user.uid)
    }
    
    private func countForFilter(_ filter: OrderFilter) -> Int {
        let orders = notificationService.recentOrders.isEmpty ? orderViewModel.orders : notificationService.recentOrders
        switch filter {
        case .all:
            return orders.count
        case .todaysOrders:
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
            return orders.filter { order in
                order.createdAt >= today && order.createdAt < tomorrow
            }.count
        case .todaysCompleted:
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
            return orders.filter { order in
                order.createdAt >= today && order.createdAt < tomorrow && order.status == .pickedUp
            }.count
        case .pendingPickup:
            return orders.filter { $0.status == .pendingPickup }.count
        case .pickedUp:
            return orders.filter { $0.status == .pickedUp }.count
        case .pendingPayment:
            return orders.filter { $0.status == .pendingPayment }.count
        case .cancelled:
            return orders.filter { $0.status == .cancelled }.count
        }
    }
    
    private func statusPriority(_ status: OrderStatus) -> Int {
        switch status {
        case .pendingPayment: return 4
        case .pendingPickup: return 3
        case .pickedUp: return 2
        case .cancelled: return 1
        }
    }
}

// MARK: - Merchant Order Card

struct MerchantOrderCard: View {
    let order: Order
    let onTap: () -> Void
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Header Row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Order #\(order.id?.suffix(6) ?? "??????")")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(Self.dateFormatter.string(from: order.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("$\(String(format: "%.2f", order.amount))")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        MerchantOrderStatusBadge(status: order.status)
                    }
                }
                
                // Order Items Summary
                HStack {
                    Image(systemName: "bag")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text("\(order.totalItems) item\(order.totalItems == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let firstItem = order.items.first {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(firstItem.productTitle ?? "Product \(firstItem.productId.suffix(6))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        if order.items.count > 1 {
                            Text("+ \(order.items.count - 1) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if order.status == .pendingPickup {
                        HStack(spacing: 4) {
                            Image(systemName: "qrcode")
                                .font(.caption2)
                            Text("Ready")
                                .font(.caption2)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                
                // Payment Info
                if let transactionId = order.transactionId {
                    HStack {
                        Image(systemName: "creditcard")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text("Payment: \(transactionId.suffix(8).uppercased())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(order.paymentStatus.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Merchant Order Status Badge

struct MerchantOrderStatusBadge: View {
    let status: OrderStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.systemImageName)
                .font(.caption2)
            Text(status.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(colorForStatus)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(colorForStatus.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var colorForStatus: Color {
        switch status {
        case .pendingPayment: return .blue
        case .pendingPickup: return .orange
        case .pickedUp: return .green
        case .cancelled: return .red
        }
    }
}

// MARK: - Order Filter Chip

struct OrderFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.3) : color.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color : color.opacity(0.1))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Order Stat Card (Smaller version for multiple stats)

struct OrderStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}