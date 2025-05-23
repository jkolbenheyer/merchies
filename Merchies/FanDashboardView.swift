import SwiftUI
import CoreLocation

struct FanDashboardView: View {
    @StateObject private var locationService   = LocationService()
    @StateObject private var eventViewModel    = EventViewModel()
    @StateObject private var productViewModel  = ProductViewModel()
    @StateObject private var cartViewModel     = CartViewModel()
    @StateObject private var orderViewModel    = OrderViewModel()
    @EnvironmentObject var authViewModel       : AuthViewModel

    @State private var showingCart = false
    
    // Development testing states
    @State private var useSimulatedLocation = false
    @State private var simulateInEvent = false
    @State private var selectedEventId: String? = nil

    // ← Move your DateFormatter out of the builder
    private static let eventDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()
    
    // Hardcoded test coordinates - replace with your event coordinates
    private let testLatitude: Double = 40.7128  // New York coordinates
    private let testLongitude: Double = -74.0060 // Replace with your event coordinates

    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    // Development testing controls
                    #if DEBUG
                    devControls
                    #endif
                    
                    if locationService.inEventGeofence,
                       let event = locationService.currentEvent {
                        eventHeader(for: event)
                        productsGrid()

                    } else if eventViewModel.events.isEmpty {
                        noEventsView()

                    } else {
                        nearbyEventsList()
                    }
                }
            }
            .navigationTitle("MerchPit")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    cartButton
                }
            }
            .sheet(isPresented: $showingCart) {
                CartView(cartViewModel: cartViewModel,
                         orderViewModel: orderViewModel)
            }
            .onAppear {
                locationService.requestPermission()
                locationService.startUpdatingLocation()
                
                if useSimulatedLocation {
                    // Use hardcoded location for testing
                    let simulatedLocation = CLLocation(latitude: testLatitude, longitude: testLongitude)
                    locationService.currentLocation = simulatedLocation
                    eventViewModel.fetchNearbyEvents(
                        latitude: testLatitude,
                        longitude: testLongitude
                    )
                } else if let loc = locationService.currentLocation {
                    eventViewModel.fetchNearbyEvents(
                        latitude: loc.coordinate.latitude,
                        longitude: loc.coordinate.longitude
                    )
                }
            }
            .onDisappear {
                locationService.stopUpdatingLocation()
            }
        }
    }
    
    // MARK: - Development Testing Controls
    
    private var devControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Development Testing")
                .font(.headline)
            
            Toggle("Use Simulated Location", isOn: $useSimulatedLocation)
                .onChange(of: useSimulatedLocation) { newValue in
                    if newValue {
                        // Create a simulated location
                        let simulatedLocation = CLLocation(
                            latitude: testLatitude,
                            longitude: testLongitude
                        )
                        // Override the location
                        locationService.currentLocation = simulatedLocation
                        
                        // Fetch events for this location
                        eventViewModel.fetchNearbyEvents(
                            latitude: testLatitude,
                            longitude: testLongitude
                        )
                    }
                }
            
            Toggle("Simulate In Event", isOn: $simulateInEvent)
                .onChange(of: simulateInEvent) { newValue in
                    // Override locationService values for testing
                    locationService.inEventGeofence = newValue
                    
                    // If simulating event and have a selected event
                    if newValue, let selectedId = selectedEventId,
                       let event = eventViewModel.events.first(where: { $0.id == selectedId }) {
                        locationService.currentEvent = event
                        if let eventId = event.id {
                            productViewModel.fetchProducts(for: eventId)
                        }
                    }
                }
            
            if !eventViewModel.events.isEmpty {
                HStack {
                    Text("Select Event:")
                    Picker("", selection: $selectedEventId) {
                        Text("None").tag(nil as String?)
                        ForEach(eventViewModel.events) { event in
                            Text(event.name).tag(event.id)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            
            Button("Refresh Events") {
                eventViewModel.fetchNearbyEvents(
                    latitude: useSimulatedLocation ? testLatitude : locationService.currentLocation?.coordinate.latitude ?? 0,
                    longitude: useSimulatedLocation ? testLongitude : locationService.currentLocation?.coordinate.longitude ?? 0
                )
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(6)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding([.horizontal, .top])
    }

    // MARK: – Subviews

    @ViewBuilder
    private func eventHeader(for event: Event) -> some View {
        VStack {
            Text("You're at")
                .font(.subheadline)
                .foregroundColor(.gray)

            Text(event.name)
                .font(.title).fontWeight(.bold)
                .padding(.bottom, 5)

            Text(event.venueName)
                .font(.headline)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(15)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func productsGrid() -> some View {
        // Wrap in GeometryReader to ensure scrolling works correctly
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(
                    columns: [ GridItem(.flexible()), GridItem(.flexible()) ],
                    spacing: 16
                ) {
                    ForEach(productViewModel.products) { product in
                        ProductCardView(
                            product: product,
                            cartViewModel: cartViewModel
                        )
                        // Set a fixed height to ensure grid works properly
                        .frame(height: 280)
                    }
                }
                .padding()
            }
            // This ensures the ScrollView takes full height
            .frame(minHeight: geometry.size.height)
        }
    }

    @ViewBuilder
    private func noEventsView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No events nearby")
                .font(.title3).fontWeight(.semibold)

            Text("Visit a venue to see available merchandise")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)

            Button {
                locationService.requestPermission()
                if useSimulatedLocation {
                    // Use hardcoded location for testing
                    eventViewModel.fetchNearbyEvents(
                        latitude: testLatitude,
                        longitude: testLongitude
                    )
                } else if let loc = locationService.currentLocation {
                    eventViewModel.fetchNearbyEvents(
                        latitude: loc.coordinate.latitude,
                        longitude: loc.coordinate.longitude
                    )
                }
            } label: {
                Text("Check for Events")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(10)
            }
            .padding()
        }
        .padding()
    }

    @ViewBuilder
    private func nearbyEventsList() -> some View {
        VStack(alignment: .leading) {
            Text("Nearby Events")
                .font(.title2).fontWeight(.bold)
                .padding([.horizontal, .top])

            List(eventViewModel.events) { event in
                Button {
                    locationService.inEventGeofence = true
                    locationService.currentEvent    = event
                    if let id = event.id {
                        productViewModel.fetchProducts(for: id)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(event.name)
                            .font(.headline)
                        Text(event.venueName)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        // ← No local `let` here—call formatter directly
                        Text(Self.eventDateFormatter.string(from: event.startDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var cartButton: some View {
        Button {
            showingCart.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "cart")
                if !cartViewModel.cartItems.isEmpty {
                    Text("\(cartViewModel.cartItems.count)")
                        .font(.caption2)
                        .padding(5)
                        .background(Color.red)
                        .clipShape(Circle())
                        .foregroundColor(.white)
                        .offset(x: 10, y: -10)
                }
            }
        }
    }
}
