import SwiftUI
import MapKit
import CoreLocation
import Firebase
import FirebaseFirestore

struct CreateEventView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var locationService = LocationService()
    @StateObject private var eventViewModel = EventViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // Form fields
    @State private var eventName = ""
    @State private var venueName = ""
    @State private var address = ""
    @State private var eventDescription = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600 * 4) // 4 hours later
    @State private var geofenceRadius: Double = 100 // meters

    // Product selection
    @State private var selectedProducts: [Product] = []
    @State private var showingProductPicker = false

    // Map and location
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showingLocationPicker = false
    @State private var searchText = ""

    // UI states
    @State private var showingSuccess = false
    @State private var isCreating = false

    var body: some View {
        NavigationView {
            Form {
                // Basic Event Information
                Section(header: Text("Event Details")) {
                    TextField("Event Name", text: $eventName)
                    TextField("Venue Name", text: $venueName)
                    TextField("Event Description (Optional)", text: $eventDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Date and Time
                Section(header: Text("Schedule")) {
                    DatePicker("Start Date & Time", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End Date & Time", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: startDate) { newStartDate in
                            if endDate <= newStartDate {
                                endDate = newStartDate.addingTimeInterval(3600) // 1 hour later
                            }
                        }
                }
                
                // Location and Geofencing
                Section(header: Text("Location & Geofencing")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Address")
                                .font(.subheadline)
                            Text(address.isEmpty ? "Tap to set location" : address)
                                .foregroundColor(address.isEmpty ? .gray : .primary)
                        }
                        Spacer()
                        Button("Set Location") {
                            showingLocationPicker = true
                        }
                        .foregroundColor(.purple)
                    }
                    
                    if selectedLocation != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Geofence Radius")
                                .font(.subheadline)
                            
                            HStack {
                                Slider(value: $geofenceRadius, in: 50...500, step: 10) { Text("Radius") }
                                Text("\(Int(geofenceRadius))m")
                                    .frame(width: 50)
                                    .font(.caption)
                            }
                            
                            Text("Fans within \(Int(geofenceRadius)) meters can access your merch store")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Map(coordinateRegion: .constant(MKCoordinateRegion(
                            center: selectedLocation!,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        )), annotationItems: [LocationAnnotation(coordinate: selectedLocation!)]) { location in
                            MapAnnotation(coordinate: location.coordinate) {
                                VStack {
                                    Circle()
                                        .fill(Color.purple)
                                        .frame(width: 20, height: 20)
                                    Circle()
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                                        .frame(width: 40, height: 40)
                                }
                            }
                        }
                        .frame(height: 150)
                        .cornerRadius(8)
                        .disabled(true)
                    }
                }

                // Products Section
                Section(header: Text("Products")) {
                    if selectedProducts.isEmpty {
                        Text("No products added yet")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(selectedProducts) { product in
                            Text(product.title)
                        }
                    }
                    Button("Add Products") {
                        showingProductPicker = true
                    }
                    .foregroundColor(.purple)
                }
                
                // Preview Section
                if !eventName.isEmpty && !venueName.isEmpty && selectedLocation != nil {
                    Section(header: Text("Event Preview")) {
                        EventPreviewCard(
                            eventName: eventName,
                            venueName: venueName,
                            startDate: startDate,
                            endDate: endDate,
                            address: address
                        )
                    }
                }
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") { createEvent() }
                        .disabled(!isFormValid || isCreating)
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(
                    selectedLocation: $selectedLocation,
                    address: $address,
                    region: $region
                )
            }
            .sheet(isPresented: $showingProductPicker) {
                // Replace with your product picker implementation
                ProductPickerView(selectedProducts: $selectedProducts)
            }
            .alert("Event Created!", isPresented: $showingSuccess) {\n                Button("OK") { presentationMode.wrappedValue.dismiss() }
            } message: {
                Text("Your event has been created successfully. Fans will be able to discover it when they're nearby!")
            }
            .alert(item: Binding<ErrorAlert?>(
                get: { eventViewModel.error != nil ? ErrorAlert(message: eventViewModel.error!) : nil },
                set: { _ in eventViewModel.error = nil }
            )) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay(
                Group {
                    if isCreating {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                            Text("Creating Event...")
                                .font(.headline)
                                .padding(.top)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                    }
                }
            )
        }
    }

    private var isFormValid: Bool {
        !eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !venueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedLocation != nil &&
        endDate > startDate
    }

    private func createEvent() {
        guard let user = authViewModel.user,
              let location = selectedLocation else { return }

        isCreating = true

        let newEvent = Event(
            name: eventName.trimmingCharacters(in: .whitespacesAndNewlines),
            venueName: venueName.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address,
            startDate: startDate,
            endDate: endDate,
            latitude: location.latitude,
            longitude: location.longitude,
            geofenceRadius: geofenceRadius,
            active: true,
            merchantIds: [user.uid]
        )

        eventViewModel.createEvent(newEvent) { success in
            isCreating = false
            if success {
                showingSuccess = true
            }
        }
    }
}
