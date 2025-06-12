// EventsListView.swift - UPDATED WITH IMAGE SUPPORT
import SwiftUI
import Foundation

struct EventsListView: View {
    @StateObject private var eventViewModel = EventViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingCreateEvent = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                if eventViewModel.isLoading {
                    ProgressView("Loading events...")
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if eventViewModel.events.isEmpty {
                    EmptyEventsView {
                        showingCreateEvent = true
                    }
                } else {
                    VStack(spacing: 0) {
                        // Filter and Sort controls
                        VStack(spacing: 8) {
                            // Filter chips
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(EventFilterOption.allCases, id: \.self) { option in
                                        Button(action: {
                                            eventViewModel.setFilterOption(option)
                                        }) {
                                            HStack(spacing: 4) {
                                                Text(option.rawValue)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                
                                                Text("\(countForFilter(option))")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(eventViewModel.filterOption == option ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))
                                                    .cornerRadius(8)
                                            }
                                            .foregroundColor(eventViewModel.filterOption == option ? .white : .primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(eventViewModel.filterOption == option ? Color.cyan : Color(.systemGray5))
                                            .cornerRadius(16)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            HStack {
                                Text("\(eventViewModel.events.count) events")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Menu {
                                    ForEach(EventSortOption.allCases, id: \.self) { option in
                                        Button(action: {
                                            eventViewModel.setSortOption(option)
                                        }) {
                                            HStack {
                                                Text(option.rawValue)
                                                if eventViewModel.sortOption == option {
                                                    Spacer()
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(.cyan)
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .font(.caption)
                                        Text("Sort")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.cyan.opacity(0.1))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        
                        List {
                            ForEach(eventViewModel.events) { event in
                                EnhancedEventListRow(
                                    event: event,
                                    onArchiveToggle: { eventId in
                                        toggleArchiveStatus(eventId: eventId)
                                    },
                                    onEventTap: {
                                        // Navigation will be handled within the row
                                    }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(action: {
                                        guard let eventId = event.id else { return }
                                        toggleArchiveStatus(eventId: eventId)
                                    }) {
                                        Label(event.archived ? "Restore" : "Archive", 
                                              systemImage: event.archived ? "archivebox" : "archivebox.fill")
                                    }
                                    .tint(event.archived ? .orange : .purple)
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationTitle("My Events")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreateEvent = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateEvent) {
                CreateEventView()
                    .onDisappear {
                        // Refresh events when create sheet closes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if let userId = authViewModel.user?.uid {
                                eventViewModel.fetchMerchantEvents(merchantId: userId)
                            }
                        }
                    }
            }
            .onAppear {
                if let userId = authViewModel.user?.uid {
                    eventViewModel.fetchMerchantEvents(merchantId: userId)
                }
            }
            .refreshable {
                if let userId = authViewModel.user?.uid {
                    eventViewModel.fetchMerchantEvents(merchantId: userId)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func countForFilter(_ filter: EventFilterOption) -> Int {
        switch filter {
        case .all:
            return eventViewModel.activeEventsCount + eventViewModel.archivedEventsCount + eventViewModel.expiredEventsCount + eventViewModel.upcomingEventsCount
        case .active:
            return eventViewModel.activeEventsCount
        case .archived:
            return eventViewModel.archivedEventsCount
        case .upcoming:
            return eventViewModel.upcomingEventsCount
        case .past:
            return eventViewModel.expiredEventsCount
        }
    }
    
    private func toggleArchiveStatus(eventId: String) {
        guard let event = eventViewModel.events.first(where: { $0.id == eventId }) else { return }
        
        if event.archived {
            eventViewModel.unarchiveEvent(eventId: eventId) { success in
                if success {
                    print("✅ Event unarchived successfully")
                }
            }
        } else {
            eventViewModel.archiveEvent(eventId: eventId) { success in
                if success {
                    print("✅ Event archived successfully")
                }
            }
        }
    }
}

// MARK: - Enhanced Event List Row with Image Support
struct EnhancedEventListRow: View {
    let event: Event
    let onArchiveToggle: (String) -> Void
    let onEventTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Main content - tappable for navigation
            NavigationLink(destination: EditEventView(vm: SingleEventViewModel(event: event))) {
                HStack(spacing: 12) {
                    // Event Image
                    AsyncImage(url: event.imageUrl != nil ? URL(string: event.imageUrl!) : nil) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.8)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                                .overlay(
                                    Image(systemName: "calendar")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                )
                        @unknown default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                        }
                    }
                    
                    // Event Details
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(event.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // Archive status badge
                            if event.archived {
                                HStack(spacing: 4) {
                                    Image(systemName: "archivebox.fill")
                                        .font(.caption2)
                                    Text("Archived")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .cornerRadius(8)
                            } else {
                                // Status indicator
                                Circle()
                                    .fill(event.isActive ? Color.green : (event.isUpcoming ? Color.orange : Color.gray))
                                    .frame(width: 12, height: 12)
                            }
                        }
                        
                        Text(event.venueName)
                            .font(.subheadline)
                            .foregroundColor(.cyan)
                            .lineLimit(1)
                        
                        HStack {
                            Label(event.formattedDateRange, systemImage: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(event.productIds.count) products")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !event.address.isEmpty {
                            Label(event.address, systemImage: "location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Enhanced Empty Events View
struct EmptyEventsView: View {
    let onCreateEvent: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Events Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create your first event to start selling merchandise to fans at your venue.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: onCreateEvent) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                    Text("Create Your First Event")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.cyan)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
        }
        .padding()
    }
}

// MARK: - Event Card for Fan Dashboard
struct EventCardView: View {
    let event: Event
    let onEventSelected: () -> Void
    
    var body: some View {
        Button(action: onEventSelected) {
            VStack(alignment: .leading, spacing: 0) {
                // Event Image
                AsyncImage(url: event.imageUrl != nil ? URL(string: event.imageUrl!) : nil) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 150)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(1.2)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 150)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 150)
                            .overlay(
                                VStack {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 30))
                                        .foregroundColor(.gray)
                                    Text(event.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .padding(.top, 8)
                                }
                                .padding()
                            )
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 150)
                    }
                }
                
                // Event Details
                VStack(alignment: .leading, spacing: 8) {
                    Text(event.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    Text(event.venueName)
                        .font(.subheadline)
                        .foregroundColor(.cyan)
                        .lineLimit(1)
                    
                    if !event.address.isEmpty {
                        Label(event.address, systemImage: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Label(event.formattedDateRange, systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack {
                        // Status badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(event.isActive ? Color.green : (event.isUpcoming ? Color.orange : Color.gray))
                                .frame(width: 8, height: 8)
                            
                            Text(event.isActive ? "Live" : (event.isUpcoming ? "Upcoming" : "Ended"))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(event.isActive ? .green : (event.isUpcoming ? .orange : .gray))
                        }
                        
                        Spacer()
                        
                        if event.productIds.count > 0 {
                            Text("\(event.productIds.count) products")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
