import SwiftUI
import FirebaseStorage

struct EventsAttendedView: View {
    let eventsAttended: [Event]
    @State private var searchText = ""
    @State private var selectedTimeFilter: TimeFilter = .all
    @Environment(\.presentationMode) var presentationMode
    
    enum TimeFilter: String, CaseIterable {
        case all = "All Time"
        case thisYear = "This Year"
        case thisMonth = "This Month"
        case recent = "Recent"
    }
    
    var filteredEvents: [Event] {
        print("🔍 EventsAttendedView.filteredEvents: Starting with \(eventsAttended.count) events")
        for (index, event) in eventsAttended.enumerated() {
            print("   Event \(index + 1): \(event.name) - Start: \(event.startDate) - Status: \(event.isActive ? "Active" : event.isUpcoming ? "Upcoming" : "Past")")
        }
        
        var filtered = eventsAttended
        
        // Apply time filter
        let now = Date()
        let calendar = Calendar.current
        
        print("🔍 EventsAttendedView.filteredEvents: Applying time filter: \(selectedTimeFilter.rawValue)")
        
        switch selectedTimeFilter {
        case .all:
            print("🔍 EventsAttendedView.filteredEvents: 'All Time' selected - no time filtering")
            break
        case .thisYear:
            let beforeCount = filtered.count
            filtered = filtered.filter { calendar.isDate($0.startDate, equalTo: now, toGranularity: .year) }
            print("🔍 EventsAttendedView.filteredEvents: 'This Year' filter - \(beforeCount) -> \(filtered.count) events")
        case .thisMonth:
            let beforeCount = filtered.count
            filtered = filtered.filter { calendar.isDate($0.startDate, equalTo: now, toGranularity: .month) }
            print("🔍 EventsAttendedView.filteredEvents: 'This Month' filter - \(beforeCount) -> \(filtered.count) events")
        case .recent:
            let beforeCount = filtered.count
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            filtered = filtered.filter { $0.startDate >= threeMonthsAgo }
            print("🔍 EventsAttendedView.filteredEvents: 'Recent' filter - \(beforeCount) -> \(filtered.count) events")
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            let beforeCount = filtered.count
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.venueName.localizedCaseInsensitiveContains(searchText) ||
                $0.address.localizedCaseInsensitiveContains(searchText)
            }
            print("🔍 EventsAttendedView.filteredEvents: Search filter '\(searchText)' - \(beforeCount) -> \(filtered.count) events")
        }
        
        let finalEvents = filtered.sorted { $0.startDate > $1.startDate }
        print("🔍 EventsAttendedView.filteredEvents: Final result: \(finalEvents.count) events after sorting")
        
        return finalEvents
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Stats
            eventStatsHeader
            
            // Filters
            VStack(spacing: 12) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search events...", text: $searchText)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
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
            .padding(.vertical)
            
            // Events List
            if filteredEvents.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredEvents.indices, id: \.self) { index in
                            let event = filteredEvents[index]
                            EventAttendanceCard(event: event)
                                .onAppear {
                                    print("🔍 EventsAttendedView: Rendering event \(index + 1): \(event.name)")
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20) // Add bottom padding to ensure content is visible
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Events Attended")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header Stats
    
    private var eventStatsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(eventsAttended.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
                
                Text("Total Events")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(uniqueVenues)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("Unique Venues")
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
            Image(systemName: eventsAttended.isEmpty ? "calendar.badge.plus" : "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(eventsAttended.isEmpty ? "No Events Attended" : "No Events Found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(eventsAttended.isEmpty ? 
                 "When you attend events and make purchases, they'll appear here." : 
                 "Try adjusting your search or filter criteria")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if eventsAttended.isEmpty {
                Button("Go Back") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.purple)
                .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var uniqueVenues: Int {
        Set(eventsAttended.map { $0.venueName }).count
    }
}

// MARK: - Event Attendance Card

struct EventAttendanceCard: View {
    let event: Event
    @State private var loadedEventImage: UIImage?
    @State private var isLoadingImage = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Event Image
            Group {
                if let image = loadedEventImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .clipped()
                } else if isLoadingImage {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                        )
                } else {
                    Rectangle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "calendar")
                                .foregroundColor(.purple)
                                .font(.title2)
                        )
                }
            }
            
            // Event Details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(event.venueName)
                    .font(.caption)
                    .foregroundColor(.purple)
                    .lineLimit(1)
                
                HStack {
                    Image(systemName: "calendar")
                    Text(formatEventDate(event.startDate))
                    
                    Spacer()
                    
                    EventStatusBadge(event: event, forceAttended: true)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onAppear {
            print("🔍 EventAttendanceCard: onAppear for event '\(event.name)'")
            loadEventImage()
        }
    }
    
    private func loadEventImage() {
        guard let imageUrl = event.imageUrl, !imageUrl.isEmpty else { return }
        
        if loadedEventImage != nil { return }
        
        isLoadingImage = true
        
        if imageUrl.contains("firebasestorage.googleapis.com") {
            do {
                let storageRef = Storage.storage().reference(forURL: imageUrl)
                storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        self.isLoadingImage = false
                        if let data = data, let image = UIImage(data: data) {
                            self.loadedEventImage = image
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingImage = false
                }
            }
        }
    }
    
    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Event Status Badge

struct EventStatusBadge: View {
    let event: Event
    let forceAttended: Bool
    
    init(event: Event, forceAttended: Bool = false) {
        self.event = event
        self.forceAttended = forceAttended
    }
    
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
        if forceAttended {
            return ("Attended", .green)
        } else if event.isPast {
            return ("Attended", .green)
        } else if event.isActive {
            return ("Live", .orange)
        } else {
            return ("Upcoming", .blue)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.purple : Color(.systemGray5))
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}