import SwiftUI
import CoreLocation
import Foundation
import FirebaseFirestore
import FirebaseStorage

struct FanDashboardView: View {
    @StateObject private var locationService  = LocationService()
    @StateObject private var eventViewModel   = EventViewModel()
    @StateObject private var productViewModel = ProductViewModel()
    @StateObject private var cartViewModel    = CartViewModel()
    @EnvironmentObject var orderViewModel     : OrderViewModel
    @EnvironmentObject var authViewModel      : AuthViewModel

    @State private var showingCart           = false
    @State private var simulateLocation      = false
    @State private var selectedProduct       : Product? = nil
    @State private var selectedDetailSizes: Set<String> = []
    @State private var loadedDetailImage: UIImage?
    @State private var isLoadingDetailImage = false

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
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // Main content
                    contentView
                        .padding(.horizontal)
                }
                .padding(.top)
            }
            .refreshable {
                // Refresh events and their product counts
                refreshNearbyEvents()
            }
            .navigationTitle("Merchies")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        // Reset location simulation and go back to nearby events
                        locationService.inEventGeofence = false
                        locationService.currentEvent = nil
                        productViewModel.products.removeAll()
                    }
                }
                
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
                        // Product image with Firebase Storage support
                        Group {
                            if let loadedImage = loadedDetailImage {
                                Image(uiImage: loadedImage)
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fill)
                                    .frame(height: 200)
                                    .cornerRadius(8)
                                    .clipped()
                            } else if isLoadingDetailImage {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                    ProgressView()
                                        .scaleEffect(1.2)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                }
                                .frame(height: 200)
                            } else {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.purple.opacity(0.2))
                                        .cornerRadius(8)
                                    Image(systemName: "tshirt")
                                        .font(.largeTitle)
                                        .foregroundColor(.purple)
                                }
                                .frame(height: 200)
                            }
                        }
                        .padding()

                        // Title & price
                        Text(product.title)
                            .font(.title)
                            .fontWeight(.bold)
                        Text(String(format: "$%.2f", product.price))
                            .font(.title2)
                            .foregroundColor(.purple)

                        // Size picker - only show available sizes, sorted
                        VStack(alignment: .leading) {
                            let availableSizes = product.sizes
                                .filter { size in
                                    let inventory = product.inventory[size] ?? 0
                                    return inventory > 0
                                }
                                .sorted { lhs, rhs in
                                    // Custom sorting for clothing sizes
                                    let sizeOrder = ["XXS", "XS", "S", "M", "L", "XL", "XXL", "XXXL"]
                                    let lhsIndex = sizeOrder.firstIndex(of: lhs) ?? Int.max
                                    let rhsIndex = sizeOrder.firstIndex(of: rhs) ?? Int.max
                                    if lhsIndex != Int.max && rhsIndex != Int.max {
                                        return lhsIndex < rhsIndex
                                    }
                                    return lhs < rhs // Fallback to alphabetical
                                }
                            
                            if availableSizes.isEmpty {
                                Text("Out of stock")
                                    .font(.headline)
                                    .foregroundColor(.red)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Select Size\(selectedDetailSizes.isEmpty ? "" : "s")")
                                        .font(.headline)
                                    
                                    if !selectedDetailSizes.isEmpty {
                                        Text("Selected: \(selectedDetailSizes.count) size\(selectedDetailSizes.count == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                            .fontWeight(.medium)
                                    }
                                    
                                    HStack(spacing: 12) {
                                        ForEach(availableSizes, id: \.self) { size in
                                            let isSelected = selectedDetailSizes.contains(size)
                                            
                                            Button(action: {
                                                if isSelected {
                                                    selectedDetailSizes.remove(size)
                                                } else {
                                                    selectedDetailSizes.insert(size)
                                                }
                                            }) {
                                                Text(size)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(isSelected ? .white : .primary)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                                                    .cornerRadius(8)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        Spacer()

                        // Add to Cart button
                        Button(action: {
                            if !selectedDetailSizes.isEmpty {
                                // Add each selected size to cart
                                for size in selectedDetailSizes {
                                    cartViewModel.addToCart(product: product, size: size)
                                }
                                selectedProduct = nil
                                selectedDetailSizes.removeAll()
                                loadedDetailImage = nil
                            }
                        }) {
                            let availableSizes = product.sizes.filter { size in
                                let inventory = product.inventory[size] ?? 0
                                return inventory > 0
                            }
                            
                            HStack {
                                if availableSizes.isEmpty {
                                    Text("Out of Stock")
                                } else if selectedDetailSizes.isEmpty {
                                    Text("Select Size")
                                } else {
                                    Text("Add to Cart")
                                    Text("(\(selectedDetailSizes.count))")
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                availableSizes.isEmpty ? Color.gray :
                                !selectedDetailSizes.isEmpty ? Color.blue : Color.gray
                            )
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(selectedDetailSizes.isEmpty || product.sizes.filter { size in
                            let inventory = product.inventory[size] ?? 0
                            return inventory > 0
                        }.isEmpty)
                        .padding(.horizontal)
                    }
                    .padding()
                    .navigationTitle("Product Details")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                selectedProduct = nil
                                selectedDetailSizes.removeAll()
                                loadedDetailImage = nil
                            }
                        }
                    }
                    .onAppear {
                        loadDetailProductImage(for: product)
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
                    .onTapGesture {
                        selectedProduct = product
                        selectedDetailSizes.removeAll()
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
                    FanEventCard(event: event)
                        .id(event.id) // Add ID to force refresh when event data changes
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
                if cartViewModel.totalItemCount > 0 {
                    Text("\(cartViewModel.totalItemCount)")
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
    
    // MARK: - Helper Functions
    
    private func refreshNearbyEvents() {
        if simulateLocation {
            // Refresh test events
            eventViewModel.fetchNearbyEvents(
                latitude: testLatitude,
                longitude: testLongitude
            )
        } else {
            // Refresh real location events
            if let loc = locationService.currentLocation {
                eventViewModel.fetchNearbyEvents(
                    latitude: loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude
                )
            }
        }
    }
}

// MARK: - Fan Event Card with Real Images
struct FanEventCard: View {
    let event: Event
    @State private var loadedEventImage: UIImage?
    @State private var isLoadingEventImage = false
    @State private var actualProductCount: Int = 0
    @State private var isLoadingProductCount = false
    @State private var refreshTimer: Timer?
    
    // Date formatter for this component
    private static let eventDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()
    
    var body: some View {
        HStack(spacing: 12) {
            // Event Image with Safe Firebase Storage Loading
            Group {
                if let loadedImage = loadedEventImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .cornerRadius(12)
                        .clipped()
                } else if isLoadingEventImage {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .cornerRadius(12)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        )
                } else {
                    Rectangle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .cornerRadius(12)
                        .overlay(
                            Image(systemName: "calendar")
                                .font(.title2)
                                .foregroundColor(.purple)
                        )
                }
            }
            
            // Event Details
            VStack(alignment: .leading, spacing: 6) {
                Text(event.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(event.venueName)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(Self.eventDateFormatter.string(from: event.startDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(event.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(event.isActive ? Color.green : (event.isUpcoming ? Color.orange : Color.gray))
                        .frame(width: 6, height: 6)
                    Text(event.isActive ? "Live Now" : (event.isUpcoming ? "Upcoming" : "Ended"))
                        .font(.caption2)
                        .foregroundColor(event.isActive ? .green : (event.isUpcoming ? .orange : .gray))
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if actualProductCount > 0 || isLoadingProductCount {
                        Group {
                            if isLoadingProductCount {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                    Text("Loading...")
                                        .font(.caption2)
                                }
                            } else {
                                Text("\(actualProductCount) product\(actualProductCount == 1 ? "" : "s")")
                                    .font(.caption2)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onAppear {
            loadEventImage()
            fetchActualProductCount()
            // Set up a timer to refresh product count every 30 seconds for real-time updates
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
                fetchActualProductCount()
            }
            
            // Add observer for when app becomes active
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                fetchActualProductCount()
            }
        }
        .onDisappear {
            // Clean up timer and observers when view disappears
            refreshTimer?.invalidate()
            refreshTimer = nil
            NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        }
        .onChange(of: event.imageUrl) { _ in
            loadEventImage()
        }
        .onChange(of: event.productIds.count) { _ in
            // Refresh product count when event.productIds changes
            fetchActualProductCount()
        }
    }
    
    private func loadEventImage() {
        guard let imageUrl = event.imageUrl, !imageUrl.isEmpty else {
            return
        }
        
        // If we already have a loaded image for this URL, don't reload
        if loadedEventImage != nil {
            return
        }
        
        isLoadingEventImage = true
        
        // Safe Firebase Storage loading with URL type detection
        if imageUrl.contains("firebasestorage.googleapis.com") {
            // Use Firebase Storage reference for Firebase URLs
            do {
                let storageRef = Storage.storage().reference(forURL: imageUrl)
                storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        self.isLoadingEventImage = false
                        if let error = error {
                            print("Error loading event image: \(error.localizedDescription)")
                        } else if let data = data, let image = UIImage(data: data) {
                            self.loadedEventImage = image
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingEventImage = false
                    print("Invalid Firebase Storage URL: \(error.localizedDescription)")
                }
            }
        } else {
            // Use URLSession for regular HTTP URLs
            guard let url = URL(string: imageUrl) else {
                DispatchQueue.main.async {
                    self.isLoadingEventImage = false
                }
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    self.isLoadingEventImage = false
                    if let error = error {
                        print("Error loading event image: \(error.localizedDescription)")
                    } else if let data = data, let image = UIImage(data: data) {
                        self.loadedEventImage = image
                    }
                }
            }.resume()
        }
    }
    
    private func fetchActualProductCount() {
        guard let eventId = event.id else {
            actualProductCount = 0
            return
        }
        
        // Don't start a new fetch if one is already in progress
        if isLoadingProductCount {
            return
        }
        
        isLoadingProductCount = true
        
        // Use FirestoreService to get actual products linked to this event
        let firestoreService = FirestoreService()
        firestoreService.fetchProductsForEvent(eventId: eventId) { products, error in
            DispatchQueue.main.async {
                self.isLoadingProductCount = false
                
                if let error = error {
                    print("🏷️ Error fetching products for event '\(self.event.name)': \(error.localizedDescription)")
                    // Fallback to event.productIds.count if available
                    if !self.event.productIds.isEmpty {
                        self.actualProductCount = self.event.productIds.count
                        print("🏷️ Using fallback count: \(self.actualProductCount)")
                    } else {
                        self.actualProductCount = 0
                    }
                } else {
                    let count = products?.count ?? 0
                    print("🏷️ Event '\(self.event.name)' real-time product count: \(count)")
                    self.actualProductCount = count
                    
                    // Log discrepancy for debugging if needed
                    if count != self.event.productIds.count {
                        print("🏷️ ⚠️ Discrepancy: Real-time count (\(count)) != event.productIds count (\(self.event.productIds.count))")
                    }
                }
            }
        }
    }
}

// MARK: - FanDashboardView Extension for Product Details
extension FanDashboardView {
    // Product Detail Image Loading
    private func loadDetailProductImage(for product: Product) {
        guard !product.imageUrl.isEmpty else {
            return
        }
        
        // Reset previous image
        loadedDetailImage = nil
        isLoadingDetailImage = true
        
        // Safe Firebase Storage loading with URL type detection
        if product.imageUrl.contains("firebasestorage.googleapis.com") {
            // Use Firebase Storage reference for Firebase URLs
            do {
                let storageRef = Storage.storage().reference(forURL: product.imageUrl)
                storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        self.isLoadingDetailImage = false
                        if let error = error {
                            print("Error loading detail product image: \(error.localizedDescription)")
                        } else if let data = data, let image = UIImage(data: data) {
                            self.loadedDetailImage = image
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingDetailImage = false
                    print("Invalid Firebase Storage URL: \(error.localizedDescription)")
                }
            }
        } else {
            // Use URLSession for regular HTTP URLs
            guard let url = URL(string: product.imageUrl) else {
                DispatchQueue.main.async {
                    self.isLoadingDetailImage = false
                }
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    self.isLoadingDetailImage = false
                    if let error = error {
                        print("Error loading detail product image: \(error.localizedDescription)")
                    } else if let data = data, let image = UIImage(data: data) {
                        self.loadedDetailImage = image
                    }
                }
            }.resume()
        }
    }
}
