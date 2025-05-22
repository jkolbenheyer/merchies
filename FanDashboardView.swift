import SwiftUI
import CoreLocation

struct FanDashboardView: View {
    @StateObject private var locationService = LocationService()
    @StateObject private var eventViewModel = EventViewModel()
    @StateObject private var productViewModel = ProductViewModel()
    @StateObject private var cartViewModel = CartViewModel()
    @StateObject private var orderViewModel = OrderViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var showingCart = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    if locationService.inEventGeofence, let event = locationService.currentEvent {
                        // Inside an event geofence
                        VStack {
                            Text("You're at")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text(event.name)
                                .font(.title)
                                .fontWeight(.bold)
                                .padding(.bottom, 5)
                            
                            Text(event.venueName)
                                .font(.headline)
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(15)
                        .padding(.horizontal)
                        
                        // Products grid
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ], spacing: 16) {
                                ForEach(productViewModel.products) { product in
                                    ProductCardView(product: product, cartViewModel: cartViewModel)
                                }
                            }
                            .padding()
                        }
                    } else if eventViewModel.events.isEmpty {
                        // No nearby events
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
                                .padding(.horizontal)
                            
                            Button(action: {
                                // Request location and refresh
                                locationService.requestPermission()
                                if let location = locationService.currentLocation {
                                    eventViewModel.fetchNearbyEvents(
                                        latitude: location.coordinate.latitude,
                                        longitude: location.coordinate.longitude
                                    )
                                }
                            }) {
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
                    } else {
                        // List nearby events
                        Text("Nearby Events")
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top)
                        
                        List(eventViewModel.events) { event in
                            Button(action: {
                                // Simulate entering this event's geofence
                                locationService.inEventGeofence = true
                                locationService.currentEvent = event
                                
                                // Load products for this event
                                if let eventId = event.id {
                                    productViewModel.fetchProducts(for: eventId)
                                }
                            }) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(event.name)
                                        .font(.headline)
                                    
                                    Text(event.venueName)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    
                                    // Format date
                                    let formatter = DateFormatter()
                                    formatter.dateStyle = .medium
                                    formatter.timeStyle = .short
                                    
                                    Text(formatter.string(from: event.startDate))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // Loading overlay
                if productViewModel.isLoading || eventViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .navigationTitle("MerchPit")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCart = true
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "cart")
                                .font(.system(size: 20))
                            
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
            .sheet(isPresented: $showingCart) {
                CartView(cartViewModel: cartViewModel, orderViewModel: orderViewModel)
            }
            .onAppear {
                // Request location permission
                locationService.requestPermission()
                
                // Start location updates
                locationService.startUpdatingLocation()
                
                // Load events when location available
                if let location = locationService.currentLocation {
                    eventViewModel.fetchNearbyEvents(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                }
                
                // Load user's orders
                if let user = authViewModel.user {
                    orderViewModel.fetchOrders(for: user.uid)
                }
            }
            .onDisappear {
                locationService.stopUpdatingLocation()
            }
        }
    }
}

                    }
                }
            }
            .navigationTitle("Order History")
            .sheet(item: $selectedOrder) { order in
                OrderDetailView(order: order)
            }
            .onAppear {
                if let user = authViewModel.user {
                    orderViewModel.fetchOrders(for: user.uid)
                }
            }
            .refreshable {
                if let user = authViewModel.user {
                    orderViewModel.fetchOrders(for: user.uid)
                }
            }
        }
    }
}

