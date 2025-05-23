import SwiftUI
import CoreLocation

struct FanDashboardView: View {
    @StateObject private var locationService  = LocationService()
    @StateObject private var eventViewModel   = EventViewModel()
    @StateObject private var productViewModel = ProductViewModel()
    @StateObject private var cartViewModel    = CartViewModel()
    @StateObject private var orderViewModel   = OrderViewModel()
    @EnvironmentObject var authViewModel      : AuthViewModel

    @State private var showingCart           = false
    @State private var simulateLocation      = false
    @State private var selectedProduct       : Product? = nil
    @State private var selectedDetailSize    : String?  = nil

    // Formatter for event dates
    private static let eventDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()

    // Coordinates to simulate
    private let testLatitude: Double  = 40.7128
    private let testLongitude: Double = -74.0060

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Dev toggle card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Development Testing")
                            .font(.headline)
                        Toggle("Simulate Location", isOn: $simulateLocation)
                            .onChange(of: simulateLocation) { sim in
                                if sim {
                                    // Load test events
                                    eventViewModel.fetchNearbyEvents(
                                        latitude: testLatitude,
                                        longitude: testLongitude
                                    )
                                    locationService.inEventGeofence = false
                                    locationService.currentEvent    = nil
                                    productViewModel.products.removeAll()
                                } else {
                                    // Back to real-location mode
                                    locationService.inEventGeofence = false
                                    locationService.currentEvent    = nil
                                    eventViewModel.events.removeAll()
                                    productViewModel.products.removeAll()
                                    if let loc = locationService.currentLocation {
                                        eventViewModel.fetchNearbyEvents(
                                            latitude: loc.coordinate.latitude,
                                            longitude: loc.coordinate.longitude
                                        )
                                    }
                                }
                            }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Main content
                    contentView
                        .padding(.horizontal)
                }
                .padding(.top)
            }
            .navigationTitle("Merchies")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    cartButton
                }
            }
            // Cart sheet
            .sheet(isPresented: $showingCart) {
                CartView(cartViewModel: cartViewModel,
                         orderViewModel: orderViewModel)
            }
            // Product detail sheet
            .sheet(item: $selectedProduct) { product in
                NavigationView {
                    VStack(spacing: 20) {
                        // Gray placeholder background + photo icon
                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                        .frame(height: 200)
                        .padding()

                        // Title & price
                        Text(product.title)
                            .font(.title)
                            .fontWeight(.bold)
                        Text(String(format: "$%.2f", product.price))
                            .font(.title2)
                            .foregroundColor(.purple)

                        // Size picker
                        VStack(alignment: .leading) {
                            Text("Select Size")
                                .font(.headline)
                            HStack(spacing: 12) {
                                ForEach(product.sizes, id: \.self) { size in
                                    Text(size)
                                        .font(.subheadline)
                                        .padding(8)
                                        .background(
                                            selectedDetailSize == size
                                            ? Color.blue.opacity(0.2)
                                            : Color.gray.opacity(0.2)
                                        )
                                        .cornerRadius(4)
                                        .onTapGesture {
                                            selectedDetailSize = size
                                        }
                                }
                            }
                        }
                        .padding(.horizontal)

                        Spacer()

                        // Add to Cart button
                        Button(action: {
                            if let size = selectedDetailSize {
                                cartViewModel.addToCart(product: product, size: size)
                                selectedProduct    = nil
                                selectedDetailSize = nil
                            }
                        }) {
                            Text("Add to Cart")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    selectedDetailSize != nil
                                    ? Color.blue
                                    : Color.gray
                                )
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(selectedDetailSize == nil)
                        .padding(.horizontal)
                    }
                    .padding()
                    .navigationTitle("Product Details")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                selectedProduct    = nil
                                selectedDetailSize = nil
                            }
                        }
                    }
                }
            }
            .onAppear {
                locationService.requestPermission()
                locationService.startUpdatingLocation()
                if !simulateLocation,
                   let loc = locationService.currentLocation {
                    eventViewModel.fetchNearbyEvents(
                        latitude: loc.coordinate.latitude,
                        longitude: loc.coordinate.longitude
                    )
                }
                if let user = authViewModel.user {
                    orderViewModel.fetchOrders(for: user.uid)
                }
            }
            .onDisappear {
                locationService.stopUpdatingLocation()
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
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

    @ViewBuilder
    private func eventHeader(for event: Event) -> some View {
        VStack(spacing: 4) {
            Text("You're at")
                .font(.subheadline)
                .foregroundColor(.white)
            Text(event.name)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(event.venueName)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    @ViewBuilder
    private func productsGrid() -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 16
        ) {
            ForEach(productViewModel.products) { product in
                ProductCardView(product: product, cartViewModel: cartViewModel)
                    .frame(maxWidth: .infinity, minHeight: 280)
                    .onTapGesture {
                        selectedProduct    = product
                        selectedDetailSize = nil
                    }
            }
        }
    }

    @ViewBuilder
    private func noEventsView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No events nearby")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Visit a venue to see available merchandise")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            Button {
                if let loc = locationService.currentLocation {
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
        }
        .padding()
    }

    @ViewBuilder
    private func nearbyEventsList() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nearby Events")
                .font(.title2)
                .fontWeight(.bold)
            ForEach(eventViewModel.events) { event in
                Button {
                    locationService.inEventGeofence = true
                    locationService.currentEvent    = event
                    if let id = event.id {
                        productViewModel.fetchProducts(for: id)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.name)
                            .font(.headline)
                        Text(event.venueName)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(Self.eventDateFormatter.string(from: event.startDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
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
                if cartViewModel.cartItems.count > 0 {
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
