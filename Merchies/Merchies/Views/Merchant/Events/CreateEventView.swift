// CreateEventView.swift - CORRECTED VERSION
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
    @State private var geofenceRadius: Double = AppConstants.Geofencing.defaultRadius // meters
    @State private var maxCapacity = ""
    @State private var ticketPrice = ""
    
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
    @State private var searchText = ""
    
    // UI states
    @State private var showingSuccess = false
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                // Event Image Section
                Section(header: Text("Event Image")) {
                    if #available(iOS 14.0, *) {
                        PhotoPickerView(selectedImage: $selectedImage, title: "Event Image")
                    } else {
                        // Fallback for older iOS versions
                        VStack {
                            if let selectedImage = selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .cornerRadius(AppConstants.UI.cardCornerRadius)
                            } else {
                                Button("Select Event Image") {
                                    showingImagePicker = true
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(AppConstants.UI.cardCornerRadius)
                            }
                        }
                    }
                    
                    if isUploadingImage {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Uploading image...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
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
                                endDate = newStartDate.addingTimeInterval(3600)
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
                                Slider(value: $geofenceRadius, in: 50...500, step: 10) {
                                    Text("Radius")
                                }
                                Text("\(Int(geofenceRadius))m")
                                    .frame(width: 50)
                                    .font(.caption)
                            }
                            
                            Text("Fans within \(Int(geofenceRadius)) meters can access your merch store")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Mini map preview
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
                        .cornerRadius(AppConstants.UI.standardCornerRadius)
                        .disabled(true)
                    }
                }
                
        
                // Preview Section
                if !eventName.isEmpty && !venueName.isEmpty && selectedLocation != nil {
                    Section(header: Text("Event Preview")) {
                        EventPreviewCard(
                            eventName: eventName,
                            venueName: venueName,
                            startDate: startDate,
                            endDate: endDate,
                            address: address,
                            eventImage: selectedImage
                        )
                    }
                }
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
                if #available(iOS 14.0, *) {
                    // This won't be called on iOS 14+ since we use PhotosPicker directly
                    LegacyImagePickerSheet(selectedImage: $selectedImage, isPresented: $showingImagePicker)
                } else {
                    LegacyImagePickerSheet(selectedImage: $selectedImage, isPresented: $showingImagePicker)
                }
            }
            .alert("Event Created!", isPresented: $showingSuccess) {
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Your event has been created successfully. Fans will be able to discover it when they're nearby!")
            }
            .alert(item: Binding<ErrorAlert?>(
                get: { eventViewModel.error != nil ? ErrorAlert(message: eventViewModel.error!) : nil },
                set: { _ in eventViewModel.clearError() }
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
                            
                            Text(isUploadingImage ? "Uploading image..." : "Creating Event...")
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
            geofenceRadius: Double = geofenceRadius,
            active: true,
            merchantIds: [user.uid],
            imageUrl: imageURL,
            productIds: [],
            description: eventDescription.isEmpty ? nil : eventDescription,
            eventType: nil,
            maxCapacity: maxCapacity.isEmpty ? nil : Int(maxCapacity),
            ticketPrice: ticketPrice.isEmpty ? nil : Double(ticketPrice)
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

// MARK: - Updated Event Preview Card
struct EventPreviewCard: View {
    let eventName: String
    let venueName: String
    let startDate: Date
    let endDate: Date
    let address: String
    let eventImage: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Event image if available
            if let eventImage = eventImage {
                Image(uiImage: eventImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .cornerRadius(AppConstants.UI.standardCornerRadius)
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
            }
            .padding(.horizontal, eventImage != nil ? 0 : 16)
        }
        .padding(eventImage != nil ? 0 : 16)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(AppConstants.UI.cardCornerRadius)
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

// MARK: - Location Picker and Supporting Views (keeping existing implementation)
struct LocationPickerView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var address: String
    @Binding var region: MKCoordinateRegion
    @Environment(\.presentationMode) var presentationMode
    
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @StateObject private var locationService = LocationService()
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                SearchBar(text: $searchText, onSearchButtonClicked: {
                    searchForLocation()
                })
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
                .onTapGesture { location in
                    // Convert tap location to coordinate
                    let coordinate = region.center // This is simplified - in a real app you'd convert the tap position
                    selectLocation(coordinate)
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
                    .cornerRadius(AppConstants.UI.standardCornerRadius)
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
        
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            
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
            .cornerRadius(AppConstants.UI.standardCornerRadius)
            
            if !text.isEmpty {
                Button("Search") {
                    onSearchButtonClicked()
                }
                .foregroundColor(.purple)
            }
        }
    }
}

// MARK: - Supporting Models and Classes
struct LocationAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
