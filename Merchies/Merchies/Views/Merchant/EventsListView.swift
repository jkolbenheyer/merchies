// EventsListView.swift - CLEAN VERSION
import SwiftUI

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
                    List {
                        ForEach(eventViewModel.events) { event in
                            NavigationLink(destination: EventProductsView(event: event)) {
                                EventListRow(event: event)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
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
}

// MARK: - Event List Row
struct EventListRow: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(event.isActive ? Color.green : (event.isUpcoming ? Color.orange : Color.gray))
                    .frame(width: 12, height: 12)
            }
            
            Text(event.venueName)
                .font(.subheadline)
                .foregroundColor(.cyan)
            
            HStack {
                Label(event.formattedDateRange, systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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
        .padding(.vertical, 4)
    }
}

// MARK: - Empty Events View
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
