// CreateEventView.swift - FIXED VERSION WITH SIMPLIFIED EXPRESSIONS
import SwiftUI
import MapKit
import CoreLocation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Foundation

struct CreateEventView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var locationService = LocationService()
    @StateObject private var eventViewModel = EventViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // Image upload service as regular property
    private let imageUploadService = ImageUploadService()
    
    // Form fields
    @State private var eventName = ""
    @State private var venueName = ""
    @State private var address = ""
    @State private var eventDescription = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600 * 4) // 4 hours later
    @State private var geofenceRadius: Double = 100.0 // meters - default radius
    
    // Image handling
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isUploadingImage = false
    @State private var uploadedImageURL: String?
    
    // Map and location
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showingLocationPicker = false
    
    // UI states
    @State private var showingSuccess = false
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                eventImageSection
                eventDetailsSection
                scheduleSection
                locationAndGeofencingSection
                previewSection
            }
            .navigationTitle("Create Event")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createEvent()
                    }
                    .disabled(!isFormValid || isCreating || isUploadingImage)
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
            .sheet(isPresented: $showingImagePicker) {
                LegacyImagePickerSheet(selectedImage: $selectedImage, isPresented: $showingImagePicker)
            }
            .alert("Event Created!", isPresented: $showingSuccess) {
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Your event has been created successfully. Fans within \(Int(geofenceRadius)) meters will be able to discover your merchandise!")
            }
            .alert(item: errorBinding) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay(loadingOverlay)
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var eventImageSection: some View {
        Section(header: Text("Event Image")) {
            if #available(iOS 14.0, *) {
                PhotoPickerView(selectedImage: $selectedImage, title: "Event Image")
            } else {
                legacyImagePicker
            }
            
            if isUploadingImage {
                imageUploadingIndicator
            }
        }
    }
    
    @ViewBuilder
    private var legacyImagePicker: some View {
        VStack {
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
            } else {
                Button("Select Event Image") {
                    showingImagePicker = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
            }
        }
    }
    
    @ViewBuilder
    private var imageUploadingIndicator: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Uploading image...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var eventDetailsSection: some View {
        Section(header: Text("Event Details")) {
            TextField("Event Name", text: $eventName)
            TextField("Venue Name", text: $venueName)
            TextField("Event Description (Optional)", text: $eventDescription, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    @ViewBuilder
    private var scheduleSection: some View {
        Section(header: Text("Schedule")) {
            DatePicker("Start Date & Time", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
            DatePicker("End Date & Time", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                .onChange(of: startDate) { newStartDate in
                    if endDate <= newStartDate {
                        endDate = newStartDate.addingTimeInterval(3600)
                    }
                }
        }
    }
    
    @ViewBuilder
    private var locationAndGeofencingSection: some View {
        Section(header: Text("Location & Geofencing")) {
            addressSelectionRow
            
            if selectedLocation != nil {
                geofencingControls
                geofencePreviewMap
            }
        }
    }
    
    @ViewBuilder
    private var addressSelectionRow: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Address")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(address.isEmpty ? "Tap to set location" : address)
                    .foregroundColor(address.isEmpty ? .gray : .primary)
                    .font(.body)
            }
            Spacer()
            Button("Set Location") {
                showingLocationPicker = true
            }
            .foregroundColor(.purple)
            .font(.subheadline)
            .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var geofencingControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            Text("Geofencing Settings")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Define the area where fans can access your merchandise")
                .font(.caption)
                .foregroundColor(.secondary)
            
            radiusControls
            radiusExamples
        }
    }
    
    @ViewBuilder
    private var radiusControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Detection Radius")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(geofenceRadius)) meters")
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(4)
            }
            
            HStack {
                Text("50m")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Slider(value: $geofenceRadius, in: 50...500, step: 10)
                    .accentColor(.purple)
                
                Text("500m")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text(geofenceRadiusDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
    }
    
    @ViewBuilder
    private var radiusExamples: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Coverage Examples:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            ForEach(geofenceExamples, id: \.radius) { example in
                HStack {
                    Circle()
                        .fill(example.radius == Int(geofenceRadius) ? Color.purple : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                    
                    Text("\(example.radius)m")
                        .font(.caption2)
                        .foregroundColor(example.radius == Int(geofenceRadius) ? .purple : .secondary)
                        .fontWeight(example.radius == Int(geofenceRadius) ? .semibold : .regular)
                        .frame(width: 30, alignment: .leading)
                    
                    Text(example.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }
    
    @ViewBuilder
    private var geofencePreviewMap: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Geofence Preview")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if let location = selectedLocation {
                GeofenceMapPreview(
                    location: location,
                    venueName: venueName,
                    geofenceRadius: geofenceRadius
                )
            }
        }
    }
    
    @ViewBuilder
    private var additionalDetailsSection: some View {
        // Remove this section - not needed
        EmptyView()
    }
    
    @ViewBuilder
    private var previewSection: some View {
        if !eventName.isEmpty && !venueName.isEmpty && selectedLocation != nil {
            Section(header: Text("Event Preview")) {
                EventPreviewCard(
                    eventName: eventName,
                    venueName: venueName,
                    startDate: startDate,
                    endDate: endDate,
                    address: address,
                    eventImage: selectedImage,
                    geofenceRadius: geofenceRadius
                )
            }
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if isCreating {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                
                Text(isUploadingImage ? "Uploading image..." : "Creating Event...")
                    .font(.headline)
                
                if !isUploadingImage {
                    Text("Setting up geofence...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !venueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedLocation != nil &&
        endDate > startDate
    }
    
    private var errorBinding: Binding<ErrorAlert?> {
        Binding<ErrorAlert?>(
            get: { eventViewModel.error != nil ? ErrorAlert(message: eventViewModel.error!) : nil },
            set: { _ in eventViewModel.clearError() }
        )
    }
    
    private var geofenceRadiusDescription: String {
        switch Int(geofenceRadius) {
        case 50...100:
            return "Perfect for small venues like cafes or small clubs"
        case 101...200:
            return "Good for medium venues like theaters or restaurants"
        case 201...350:
            return "Ideal for large venues like concert halls or stadiums"
        case 351...500:
            return "Great for festivals or large outdoor events"
        default:
            return "Custom radius for your specific needs"
        }
    }
    
    private var geofenceExamples: [(radius: Int, description: String)] {
        [
            (50, "Small cafe/club"),
            (100, "Restaurant/bar"),
            (200, "Concert venue"),
            (350, "Stadium/arena"),
            (500, "Festival grounds")
        ]
    }
    
    // MARK: - Methods
    
    private func createEvent() {
        guard let user = authViewModel.user,
              let location = selectedLocation else { return }
        
        isCreating = true
        
        // If there's an image, upload it first
        if let image = selectedImage {
            isUploadingImage = true
            let tempEventId = UUID().uuidString
            
            imageUploadService.uploadImage(image, type: .event, id: tempEventId) { result in
                DispatchQueue.main.async {
                    self.isUploadingImage = false
                    
                    switch result {
                    case .success(let imageURL):
                        self.uploadedImageURL = imageURL
                        self.createEventWithImage(user: user, location: location, imageURL: imageURL)
                    case .failure(let error):
                        self.isCreating = false
                        self.eventViewModel.error = "Failed to upload image: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            createEventWithImage(user: user, location: location, imageURL: nil)
        }
    }
    
    private func createEventWithImage(user: User, location: CLLocationCoordinate2D, imageURL: String?) {
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
            merchantIds: [user.uid],
            imageUrl: imageURL,
            productIds: [],
            description: eventDescription.isEmpty ? nil : eventDescription,
            eventType: nil,
            maxCapacity: nil,
            ticketPrice: nil
        )
        
        eventViewModel.createEvent(newEvent) { success, errorMessage in
            DispatchQueue.main.async {
                self.isCreating = false
                if success {
                    self.showingSuccess = true
                } else if let errorMessage = errorMessage {
                    self.eventViewModel.error = errorMessage
                }
            }
        }
    }
}

// MARK: - Geofence Map Preview Component
struct GeofenceMapPreview: View {
    let location: CLLocationCoordinate2D
    let venueName: String
    let geofenceRadius: Double
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: .constant(mapRegion), annotationItems: [LocationAnnotation(coordinate: location)]) { locationAnnotation in
                MapAnnotation(coordinate: locationAnnotation.coordinate) {
                    ZStack {
                        // Geofence circle (approximate visual)
                        Circle()
                            .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        // Center point
                        VStack(spacing: 2) {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 12, height: 12)
                            
                            Text(venueName.isEmpty ? "Event" : venueName)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .frame(height: 180)
            .cornerRadius(12)
            .disabled(true)
            
            // Map overlay with radius info
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Text("\(Int(geofenceRadius))m")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("radius")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }
    
    private var mapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: location,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
    }
}

// MARK: - Event Preview Card
struct EventPreviewCard: View {
    let eventName: String
    let venueName: String
    let startDate: Date
    let endDate: Date
    let address: String
    let eventImage: UIImage?
    let geofenceRadius: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Event image if available
            if let eventImage = eventImage {
                Image(uiImage: eventImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .cornerRadius(8)
                    .clipped()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(eventName)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(venueName)
                    .font(.subheadline)
                    .foregroundColor(.purple)
                
                if !address.isEmpty {
                    Label(address, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label(formatDateRange(start: startDate, end: endDate), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Geofencing info
                HStack {
                    Label("\(Int(geofenceRadius))m detection radius", systemImage: "location.circle")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("Fans within range can shop")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, eventImage != nil ? 0 : 16)
        }
        .padding(eventImage != nil ? 0 : 16)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let calendar = Calendar.current
        if calendar.isDate(start, inSameDayAs: end) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            
            return "\(dateFormatter.string(from: start)), \(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))"
        } else {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }
}

// MARK: - Location Picker
struct LocationPickerView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var address: String
    @Binding var region: MKCoordinateRegion
    @Environment(\.presentationMode) var presentationMode
    
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @StateObject private var locationService = LocationService()
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                SearchBar(text: $searchText, onSearchButtonClicked: searchForLocation)
                    .padding(.horizontal)
                
                // Map
                Map(coordinateRegion: $region, annotationItems: selectedLocation != nil ? [LocationAnnotation(coordinate: selectedLocation!)] : []) { location in
                    MapAnnotation(coordinate: location.coordinate) {
                        VStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.purple)
                                .font(.title)
                            Circle()
                                .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                                .frame(width: 50, height: 50)
                        }
                    }
                }
                .onTapGesture {
                    selectLocation(region.center)
                }
                
                // Search results
                if !searchResults.isEmpty {
                    List(searchResults, id: \.self) { item in
                        Button(action: {
                            selectLocationFromSearch(item)
                        }) {
                            VStack(alignment: .leading) {
                                Text(item.name ?? "Unknown Location")
                                    .font(.headline)
                                if let address = item.placemark.title {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(maxHeight: 200)
                }
                
                Spacer()
                
                // Selected location info
                if selectedLocation != nil {
                    VStack {
                        Text("Selected Location")
                            .font(.headline)
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(selectedLocation == nil)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Center on user's location if available
            if let userLocation = locationService.currentLocation {
                region = MKCoordinateRegion(
                    center: userLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }
    }
    
    private func searchForLocation() {
        guard !searchText.isEmpty else { return }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let response = response {
                searchResults = response.mapItems
            }
        }
    }
    
    private func selectLocation(_ coordinate: CLLocationCoordinate2D) {
        selectedLocation = coordinate
        
        // Reverse geocode to get address
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                let components = [
                    placemark.name,
                    placemark.thoroughfare,
                    placemark.locality,
                    placemark.administrativeArea
                ].compactMap { $0 }
                
                address = components.joined(separator: ", ")
            }
        }
    }
    
    private func selectLocationFromSearch(_ mapItem: MKMapItem) {
        let coordinate = mapItem.placemark.coordinate
        selectedLocation = coordinate
        address = mapItem.placemark.title ?? ""
        
        // Update region to center on selected location
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        searchResults = []
        searchText = ""
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    var onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search for venue or address", text: $text)
                    .onSubmit {
                        onSearchButtonClicked()
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            if !text.isEmpty {
                Button("Search") {
                    onSearchButtonClicked()
                }
                .foregroundColor(.purple)
            }
        }
    }
}

// MARK: - Supporting Models
struct LocationAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
