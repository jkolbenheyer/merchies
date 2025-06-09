import SwiftUI
import Foundation
import FirebaseStorage

struct PurchaseHistoryView: View {
    let orders: [Order]
    @State private var searchText = ""
    @State private var selectedStatusFilter: OrderStatusFilter = .all
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var showingOrderDetail: Order?
    
    enum OrderStatusFilter: String, CaseIterable {
        case all = "All"
        case pendingPayment = "Payment Pending"
        case pending = "Pending Pickup"
        case pickedUp = "Picked Up"
        case cancelled = "Cancelled"
        
        var orderStatus: OrderStatus? {
            switch self {
            case .all: return nil
            case .pendingPayment: return .pendingPayment
            case .pending: return .pendingPickup
            case .pickedUp: return .pickedUp
            case .cancelled: return .cancelled
            }
        }
    }
    
    enum TimeFilter: String, CaseIterable {
        case all = "All Time"
        case thisYear = "This Year"
        case thisMonth = "This Month"
        case last30Days = "Last 30 Days"
    }
    
    var filteredOrders: [Order] {
        var filtered = orders
        
        // Apply status filter
        if let statusFilter = selectedStatusFilter.orderStatus {
            filtered = filtered.filter { $0.status == statusFilter }
        }
        
        // Apply time filter
        let now = Date()
        let calendar = Calendar.current
        
        switch selectedTimeFilter {
        case .all:
            break
        case .thisYear:
            filtered = filtered.filter { calendar.isDate($0.createdAt, equalTo: now, toGranularity: .year) }
        case .thisMonth:
            filtered = filtered.filter { calendar.isDate($0.createdAt, equalTo: now, toGranularity: .month) }
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            filtered = filtered.filter { $0.createdAt >= thirtyDaysAgo }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { order in
                order.id?.localizedCaseInsensitiveContains(searchText) == true ||
                order.items.contains { item in
                    item.productTitle?.localizedCaseInsensitiveContains(searchText) == true
                }
            }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Stats
            purchaseStatsHeader
            
            // Filters
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
                VStack(spacing: 8) {
                    // Status Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(OrderStatusFilter.allCases, id: \.self) { filter in
                                FilterChip(
                                    title: filter.rawValue,
                                    isSelected: selectedStatusFilter == filter
                                ) {
                                    selectedStatusFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Time Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TimeFilter.allCases, id: \.self) { filter in
                                FilterChip(
                                    title: filter.rawValue,
                                    isSelected: selectedTimeFilter == filter
                                ) {
                                    selectedTimeFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
            
            // Orders List
            if filteredOrders.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredOrders) { order in
                            OrderHistoryCard(order: order) {
                                showingOrderDetail = order
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Purchase History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("🔍 PurchaseHistoryView.onAppear: Displaying \(orders.count) orders")
            print("🔍 Filtered orders count: \(filteredOrders.count)")
            print("🔍 Current filters: Status=\(selectedStatusFilter.rawValue), Time=\(selectedTimeFilter.rawValue)")
            print("🔍 Search text: '\(searchText)'")
        }
        .sheet(item: $showingOrderDetail) { order in
            OrderDetailView(order: order)
        }
    }
    
    // MARK: - Header Stats
    
    private var purchaseStatsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("$\(String(format: "%.0f", totalSpent))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text("Total Spent")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .center, spacing: 4) {
                Text("\(orders.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("Total Orders")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(totalItems)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                
                Text("Items Bought")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bag.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Orders Found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Try adjusting your search or filter criteria")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var totalSpent: Double {
        orders.reduce(0) { $0 + $1.amount }
    }
    
    private var totalItems: Int {
        orders.reduce(0) { total, order in
            total + order.items.reduce(0) { $0 + $1.qty }
        }
    }
}

// MARK: - Order History Card

struct OrderHistoryCard: View {
    let order: Order
    let onTap: () -> Void
    @State private var productImages: [String: UIImage] = [:]
    @State private var isLoadingImages = false
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Order Header with Product Images
                HStack(spacing: 12) {
                    // Product Images Preview (show first few products)
                    HStack(spacing: 4) {
                        ForEach(Array(order.items.prefix(3)), id: \.productId) { item in
                            ProductImageView(
                                productId: item.productId,
                                productImages: $productImages,
                                size: 40
                            )
                        }
                        
                        if order.items.count > 3 {
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(8)
                                
                                Text("+\(order.items.count - 3)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("$\(String(format: "%.2f", order.amount))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        OrderStatusBadge(status: order.status)
                    }
                }
                
                // Order Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Order #\(orderNumber)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(Self.dateFormatter.string(from: order.createdAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack {
                            Text("\(order.totalItems) item\(order.totalItems == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Show first few items with better formatting
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(order.items.prefix(2)), id: \.productId) { item in
                            HStack {
                                Text("• \(item.productTitle ?? "Product")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text("Size \(item.size) × \(item.qty)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if order.items.count > 2 {
                            Text("+ \(order.items.count - 2) more items...")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadProductImages()
        }
    }
    
    private var orderNumber: String {
        order.id?.suffix(6).uppercased() ?? "UNKNOWN"
    }
    
    private func loadProductImages() {
        guard !isLoadingImages else { return }
        isLoadingImages = true
        
        let firestoreService = FirestoreService()
        
        // Get unique product IDs from the order
        let productIds = Array(Set(order.items.map { $0.productId }))
        
        for productId in productIds.prefix(3) { // Only load first 3 images
            firestoreService.fetchProductById(productId: productId) { product, error in
                DispatchQueue.main.async {
                    if let product = product, !product.imageUrl.isEmpty {
                        self.loadImageFromUrl(product.imageUrl, for: productId)
                    }
                }
            }
        }
    }
    
    private func loadImageFromUrl(_ imageUrl: String, for productId: String) {
        // Safe Firebase Storage loading with URL type detection
        if imageUrl.contains("firebasestorage.googleapis.com") {
            // Use Firebase Storage reference for Firebase URLs
            let storageRef = Storage.storage().reference(forURL: imageUrl)
            storageRef.getData(maxSize: 5 * 1024 * 1024) { data, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error loading product image from Firebase: \(error.localizedDescription)")
                    } else if let data = data, let image = UIImage(data: data) {
                        self.productImages[productId] = image
                    }
                }
            }
        } else {
            // Use URLSession for regular HTTP URLs
            guard let url = URL(string: imageUrl) else { return }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    if let data = data, let image = UIImage(data: data) {
                        self.productImages[productId] = image
                    }
                }
            }.resume()
        }
    }
}

// MARK: - Product Image View Component

struct ProductImageView: View {
    let productId: String
    @Binding var productImages: [String: UIImage]
    let size: CGFloat
    
    var body: some View {
        Group {
            if let image = productImages[productId] {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .cornerRadius(8)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: size, height: size)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "tshirt")
                            .font(.system(size: size * 0.4))
                            .foregroundColor(.purple)
                    )
            }
        }
    }
}

// MARK: - Order Status Badge

struct OrderStatusBadge: View {
    let status: OrderStatus
    
    var body: some View {
        let (text, color) = statusInfo
        
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .cornerRadius(4)
    }
    
    private var statusInfo: (String, Color) {
        switch status {
        case .pendingPayment:
            return ("Payment Pending", .blue)
        case .pendingPickup:
            return ("Pending", .orange)
        case .pickedUp:
            return ("Picked Up", .green)
        case .cancelled:
            return ("Cancelled", .red)
        }
    }
}