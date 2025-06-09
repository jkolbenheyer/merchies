import SwiftUI
import Foundation
import FirebaseFirestore

// MARK: - Supporting Data Structures

struct MerchantProductSalesData {
    let product: Product
    let quantitySold: Int
    let revenue: Double
    
    func formatRevenue() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: revenue)) ?? "$0.00"
    }
}

struct SalesDataPoint {
    let date: Date
    let amount: Double
}

struct MerchantEventAnalytics {
    let totalRevenue: Double
    let totalOrders: Int
    let totalItems: Int
    
    func formatRevenue() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: totalRevenue)) ?? "$0.00"
    }
}

struct MerchantProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var profileViewModel = MerchantProfileViewModel()
    @State private var selectedTimeRange: TimeRange = .thisMonth
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader
                    
                    // Key Metrics Cards
                    metricsGrid
                    
                    // Time Range Selector
                    timeRangeSelector
                    
                    // Sales Chart Section
                    salesChartSection
                    
                    // Events Overview
                    eventsSection
                    
                    // Top Products
                    topProductsSection
                    
                    // Recent Activity
                    recentActivitySection
                }
                .padding()
            }
            .refreshable {
                await refreshData()
            }
            .navigationTitle("Merchant Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditProfile = true
                    }
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditMerchantProfileView()
                    .environmentObject(authViewModel)
            }
            .onAppear {
                Task {
                    await loadProfileData()
                }
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Image
            ZStack {
                Circle()
                    .fill(Color.purple.gradient)
                    .frame(width: 100, height: 100)
                
                if let photoURL = authViewModel.user?.photoURL {
                    AsyncImage(url: photoURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                }
            }
            
            // Merchant Info
            VStack(spacing: 4) {
                Text(authViewModel.user?.displayName ?? "Merchant")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(authViewModel.user?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !profileViewModel.bandNames.isEmpty {
                    Text("Bands: \(profileViewModel.bandNames.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Metrics Grid
    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            MetricCard(
                title: "Total Revenue",
                value: profileViewModel.formatCurrency(profileViewModel.totalRevenue),
                icon: "dollarsign.circle.fill",
                color: .green
            )
            
            MetricCard(
                title: "Orders",
                value: "\(profileViewModel.totalOrders)",
                icon: "bag.fill",
                color: .blue
            )
            
            MetricCard(
                title: "Products Sold",
                value: "\(profileViewModel.totalProductsSold)",
                icon: "tag.fill",
                color: .orange
            )
            
            MetricCard(
                title: "Active Events",
                value: "\(profileViewModel.activeEvents.count)",
                icon: "calendar.circle.fill",
                color: .purple
            )
        }
    }
    
    // MARK: - Time Range Selector
    private var timeRangeSelector: some View {
        HStack {
            Text("Analytics Period")
                .font(.headline)
            
            Spacer()
            
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .onChange(of: selectedTimeRange) { _ in
            Task {
                await profileViewModel.loadAnalytics(for: selectedTimeRange)
            }
        }
    }
    
    // MARK: - Sales Chart Section
    private var salesChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sales Trend")
                .font(.headline)
            
            if profileViewModel.salesData.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No sales data available")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .frame(height: 150)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                SalesChartView(data: profileViewModel.salesData)
                    .frame(height: 200)
            }
        }
    }
    
    // MARK: - Events Section
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Events")
                    .font(.headline)
                Spacer()
                NavigationLink("View All") {
                    EventsListView()
                        .environmentObject(authViewModel)
                }
                .font(.caption)
                .foregroundColor(.purple)
            }
            
            if profileViewModel.recentEvents.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.plus",
                    title: "No Events",
                    message: "Create your first event to start selling"
                )
            } else {
                ForEach(profileViewModel.recentEvents.prefix(3), id: \.id) { event in
                    EventSummaryCard(event: event, analytics: profileViewModel.eventAnalytics[event.id ?? ""])
                }
            }
        }
    }
    
    // MARK: - Top Products Section
    private var topProductsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Selling Products")
                    .font(.headline)
                Spacer()
                Text("(\(selectedTimeRange.displayName))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if profileViewModel.topProducts.isEmpty {
                EmptyStateView(
                    icon: "tag",
                    title: "No Sales Data",
                    message: "Product sales will appear here"
                )
            } else {
                ForEach(profileViewModel.topProducts.prefix(5), id: \.product.id) { productSale in
                    TopProductRow(productSale: productSale)
                }
            }
        }
    }
    
    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
            
            if profileViewModel.recentOrders.isEmpty {
                EmptyStateView(
                    icon: "clock",
                    title: "No Recent Activity",
                    message: "Recent orders will appear here"
                )
            } else {
                ForEach(profileViewModel.recentOrders.prefix(10), id: \.id) { order in
                    RecentOrderRow(order: order)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func loadProfileData() async {
        guard let userId = authViewModel.user?.uid else { return }
        await profileViewModel.loadMerchantData(userId: userId)
        await profileViewModel.loadAnalytics(for: selectedTimeRange)
    }
    
    private func refreshData() async {
        await loadProfileData()
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2)
    }
}

struct EventSummaryCard: View {
    let event: Event
    let analytics: MerchantEventAnalytics?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(event.venueName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(event.isActive ? .green : (event.isUpcoming ? .orange : .gray))
                        .frame(width: 6, height: 6)
                    Text(event.isActive ? "Live" : (event.isUpcoming ? "Upcoming" : "Ended"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let analytics = analytics {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(analytics.formatRevenue())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    Text("\(analytics.totalOrders) orders")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TopProductRow: View {
    let productSale: MerchantProductSalesData
    
    var body: some View {
        HStack {
            // Product Image Placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "tshirt")
                        .foregroundColor(.purple)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(productSale.product.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("\(productSale.quantitySold) sold")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(productSale.formatRevenue())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                Text("$\(String(format: "%.2f", productSale.product.price))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RecentOrderRow: View {
    let order: Order
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Order #\(order.id?.suffix(6) ?? "Unknown")")
                    .font(.caption)
                    .fontWeight(.medium)
                Text(Self.dateFormatter.string(from: order.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(String(format: "%.2f", order.amount))")
                    .font(.caption)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(order.status == .pickedUp ? .green : 
                              order.status == .pendingPickup ? .orange : .blue)
                        .frame(width: 4, height: 4)
                    Text(order.status.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SalesChartView: View {
    let data: [SalesDataPoint]
    
    var body: some View {
        GeometryReader { geometry in
            let maxValue = data.map(\.amount).max() ?? 1
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                
                // Chart
                Path { path in
                    guard !data.isEmpty else { return }
                    
                    let stepX = width / CGFloat(data.count - 1)
                    
                    for (index, point) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = height - (CGFloat(point.amount) / CGFloat(maxValue)) * height
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.purple, lineWidth: 2)
                .padding()
            }
        }
    }
}

// MARK: - Time Range Enum
enum TimeRange: String, CaseIterable {
    case thisWeek = "this_week"
    case thisMonth = "this_month"
    case thisQuarter = "this_quarter"
    case thisYear = "this_year"
    
    var displayName: String {
        switch self {
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .thisQuarter: return "This Quarter"
        case .thisYear: return "This Year"
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (startOfWeek, now)
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (startOfMonth, now)
        case .thisQuarter:
            let startOfQuarter = calendar.dateInterval(of: .quarter, for: now)?.start ?? now
            return (startOfQuarter, now)
        case .thisYear:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return (startOfYear, now)
        }
    }
}