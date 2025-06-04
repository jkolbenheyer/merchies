import SwiftUI

struct FanInsightsView: View {
    @ObservedObject var profileData: FanProfileViewModel
    @State private var selectedTimeRange: TimeRange = .yearToDate
    @State private var selectedInsightTab: InsightTab = .spending
    
    enum TimeRange: String, CaseIterable {
        case month = "This Month"
        case quarter = "Last 3 Months"
        case yearToDate = "Year to Date"
        case allTime = "All Time"
    }
    
    enum InsightTab: String, CaseIterable {
        case spending = "Spending"
        case events = "Events"
        case products = "Products"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Time Range Selector
            timeRangeSelector
            
            // Tab Selector
            tabSelector
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedInsightTab {
                    case .spending:
                        spendingInsights
                    case .events:
                        eventInsights
                    case .products:
                        productInsights
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Your Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button(range.rawValue) {
                        selectedTimeRange = range
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(selectedTimeRange == range ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedTimeRange == range ? Color.purple : Color(.systemGray5))
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(InsightTab.allCases, id: \.self) { tab in
                Button(tab.rawValue) {
                    selectedInsightTab = tab
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(selectedInsightTab == tab ? .purple : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Rectangle()
                        .fill(selectedInsightTab == tab ? Color.purple.opacity(0.1) : Color.clear)
                )
                .overlay(
                    Rectangle()
                        .fill(selectedInsightTab == tab ? Color.purple : Color.clear)
                        .frame(height: 2),
                    alignment: .bottom
                )
            }
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Spending Insights
    
    private var spendingInsights: some View {
        VStack(spacing: 20) {
            // Total Spending Card
            InsightCard(
                title: "Total Spent",
                value: "$\(String(format: "%.0f", profileData.totalSpent))",
                subtitle: "Across \(profileData.orders.count) orders",
                icon: "dollarsign.circle.fill",
                color: .green
            )
            
            // Average Order Value
            InsightCard(
                title: "Average Order",
                value: "$\(String(format: "%.2f", averageOrderValue))",
                subtitle: "Per transaction",
                icon: "chart.bar.fill",
                color: .blue
            )
            
            // Spending by Month Chart
            if !monthlySpending.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Monthly Spending")
                        .font(.headline)
                    
                    // Simple bar chart implementation
                    VStack(spacing: 8) {
                        ForEach(monthlySpending.prefix(6), id: \.month) { data in
                            HStack {
                                Text(data.month)
                                    .font(.caption)
                                    .frame(width: 40, alignment: .leading)
                                
                                GeometryReader { geometry in
                                    let maxAmount = monthlySpending.map { $0.amount }.max() ?? 1
                                    let barWidth = (data.amount / maxAmount) * geometry.size.width
                                    
                                    HStack {
                                        Rectangle()
                                            .fill(Color.purple)
                                            .frame(width: barWidth, height: 20)
                                        Spacer()
                                    }
                                }
                                .frame(height: 20)
                                
                                Text("$\(Int(data.amount))")
                                    .font(.caption)
                                    .frame(width: 50, alignment: .trailing)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            
            // Top Artists by Spending
            if !topArtistsBySpending.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Artists")
                        .font(.headline)
                    
                    ForEach(Array(topArtistsBySpending.enumerated()), id: \.offset) { index, artist in
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.purple)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading) {
                                Text("Artist \(artist.bandId.suffix(6))")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("$\(String(format: "%.2f", artist.totalSpent))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Event Insights
    
    private var eventInsights: some View {
        VStack(spacing: 20) {
            // Events Attended Card
            InsightCard(
                title: "Events Attended",
                value: "\(profileData.eventsAttended.count)",
                subtitle: "Total events",
                icon: "calendar.circle.fill",
                color: .purple
            )
            
            // Unique Venues
            InsightCard(
                title: "Unique Venues",
                value: "\(uniqueVenues)",
                subtitle: "Different locations",
                icon: "location.circle.fill",
                color: .orange
            )
            
            // Event Types Breakdown
            VStack(alignment: .leading, spacing: 12) {
                Text("Event Types")
                    .font(.headline)
                
                ForEach(eventTypeBreakdown, id: \.type) { breakdown in
                    HStack {
                        Text(breakdown.type)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(breakdown.count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Recent Events
            if !profileData.eventsAttended.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Events")
                        .font(.headline)
                    
                    ForEach(profileData.eventsAttended.prefix(5)) { event in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                Text(event.venueName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(formatEventDate(event.startDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Product Insights
    
    private var productInsights: some View {
        VStack(spacing: 20) {
            // Total Items Purchased
            InsightCard(
                title: "Items Purchased",
                value: "\(profileData.totalItemsPurchased)",
                subtitle: "Total quantity",
                icon: "bag.circle.fill",
                color: .blue
            )
            
            // Average Items per Order
            InsightCard(
                title: "Avg Items/Order",
                value: "\(String(format: "%.1f", averageItemsPerOrder))",
                subtitle: "Items per transaction",
                icon: "chart.pie.fill",
                color: .teal
            )
            
            // Most Popular Product Types
            VStack(alignment: .leading, spacing: 12) {
                Text("Product Categories")
                    .font(.headline)
                
                ForEach(productCategoryBreakdown, id: \.category) { breakdown in
                    HStack {
                        Text(breakdown.category)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(breakdown.count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Size Preferences
            VStack(alignment: .leading, spacing: 12) {
                Text("Size Preferences")
                    .font(.headline)
                
                ForEach(sizePreferences, id: \.size) { preference in
                    HStack {
                        Text("Size \(preference.size)")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(preference.count) items")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.purple)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Computed Properties
    
    private var averageOrderValue: Double {
        guard !profileData.orders.isEmpty else { return 0 }
        return profileData.totalSpent / Double(profileData.orders.count)
    }
    
    private var averageItemsPerOrder: Double {
        guard !profileData.orders.isEmpty else { return 0 }
        return Double(profileData.totalItemsPurchased) / Double(profileData.orders.count)
    }
    
    private var uniqueVenues: Int {
        Set(profileData.eventsAttended.map { $0.venueName }).count
    }
    
    private var monthlySpending: [SpendingByMonth] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        
        var monthlyData: [String: Double] = [:]
        
        for order in profileData.orders {
            let monthKey = formatter.string(from: order.createdAt)
            monthlyData[monthKey, default: 0] += order.amount
        }
        
        return monthlyData.map { SpendingByMonth(month: $0.key, amount: $0.value) }
            .sorted { $0.month < $1.month }
    }
    
    private var topArtistsBySpending: [FavoriteArtist] {
        var artistSpending: [String: Double] = [:]
        
        for order in profileData.orders {
            artistSpending[order.bandId, default: 0] += order.amount
        }
        
        return artistSpending.map { 
            FavoriteArtist(bandId: $0.key, bandName: "Artist \($0.key.suffix(6))", totalSpent: $0.value, eventsAttended: 0)
        }
        .sorted { $0.totalSpent > $1.totalSpent }
        .prefix(5)
        .map { $0 }
    }
    
    private var eventTypeBreakdown: [(type: String, count: Int)] {
        // Mock data since events don't have type in current model
        [
            ("Concerts", profileData.eventsAttended.count / 2),
            ("Festivals", profileData.eventsAttended.count / 3),
            ("Other", profileData.eventsAttended.count - (profileData.eventsAttended.count / 2) - (profileData.eventsAttended.count / 3))
        ].filter { $0.count > 0 }
    }
    
    private var productCategoryBreakdown: [(category: String, count: Int)] {
        // Mock data - in real app would analyze product titles/categories
        [
            ("T-Shirts", profileData.totalItemsPurchased / 2),
            ("Hoodies", profileData.totalItemsPurchased / 4),
            ("Accessories", profileData.totalItemsPurchased / 4)
        ].filter { $0.count > 0 }
    }
    
    private var sizePreferences: [(size: String, count: Int)] {
        var sizeCounts: [String: Int] = [:]
        
        for order in profileData.orders {
            for item in order.items {
                sizeCounts[item.size, default: 0] += item.qty
            }
        }
        
        return sizeCounts.map { (size: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Insight Card Component

struct InsightCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}