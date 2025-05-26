// CreateEventView.swift

import SwiftUI
import MapKit
import CoreLocation
import PhotosUI
import Firebase
import FirebaseFirestore
import FirebaseStorage

struct CreateEventView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var locationManager = LocationManager()
    @StateObject private var eventViewModel = CreateEventViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel

    // Form fields
    @State private var eventName        = ""
    @State private var venueName        = ""
    @State private var address          = ""
    @State private var eventDescription = ""
    @State private var startDate        = Date()
    @State private var endDate          = Date().addingTimeInterval(3600 * 4)
    @State private var geofenceRadius: Double = 100
    @State private var maxCapacity      = ""
    @State private var ticketPrice      = ""

    // Image picker
    @State private var pickedItem: PhotosPickerItem?
    @State private var uiImage: UIImage?

    // Map & Location
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span:   MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showingLocationPicker = false

    // UI state
    @State private var showingSuccess = false
    @State private var isCreating     = false

    var body: some View {
        NavigationView {
            Form {
                // MARK: – Event Details
                Section(header: Text("Event Details")) {
                    TextField("Event Name", text: $eventName)
                    TextField("Venue Name", text: $venueName)
                    TextField("Event Description (Optional)",
                              text: $eventDescription,
                              axis: .vertical)
                        .lineLimit(3...6)
                }

                // MARK: – Event Image (Optional)
                Section(header: Text("Event Image (Optional)")) {
                    PhotosPicker(
                        selection: $pickedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Choose Image")
                        }
                    }
                    .onChange(of: pickedItem) { newItem in
                        guard let item = newItem else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let img  = UIImage(data: data) {
                                uiImage = img
                                eventViewModel.uploadImage(data) { _ in }
                            }
                        }
                    }

                    if let img = uiImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(8)
                    }
                }

                // MARK: – Schedule
                Section(header: Text("Schedule")) {
                    DatePicker("Start Date & Time",
                               selection: $startDate,
                               displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End Date & Time",
                               selection: $endDate,
                               displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: startDate) { newStart in
                            if endDate <= newStart {
                                endDate = newStart.addingTimeInterval(3600)
                            }
                        }
                }

                // MARK: – Location & Geofencing
                Section(header: Text("Location & Geofencing")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Address").font(.subheadline)
                            Text(address.isEmpty ? "Tap to set location" : address)
                                .foregroundColor(address.isEmpty ? .gray : .primary)
                        }
                        Spacer()
                        Button("Set Location") {
                            showingLocationPicker = true
                        }
                        .foregroundColor(.purple)
                    }

                    if let loc = selectedLocation {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Geofence Radius").font(.subheadline)
                            HStack {
                                Slider(value: $geofenceRadius,
                                       in: 50...500,
                                       step: 10) { Text("Radius") }
                                Text("\(Int(geofenceRadius)) m")
                                    .frame(width: 50)
                                    .font(.caption)
                            }
                            Text("Fans within \(Int(geofenceRadius)) m can access your merch store")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Map(coordinateRegion: .constant(
                                MKCoordinateRegion(
                                    center: loc,
                                    span:   MKCoordinateSpan(latitudeDelta: 0.005,
                                                             longitudeDelta: 0.005)
                                )
                            ),
                            annotationItems: [LocationAnnotation(coordinate: loc)]
                        ) { pin in
                            MapAnnotation(coordinate: pin.coordinate) {
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

                // MARK: – Preview
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
                ToolbarItem(placement: .confirmationAction) {
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
            .alert("Event Created!", isPresented: $showingSuccess) {
                Button("OK") { presentationMode.wrappedValue.dismiss() }
            } message: {
                Text("Your event has been created successfully!")
            }
            .overlay {
                if isCreating {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("Creating Event…")
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        .scaleEffect(1.5)
                }
            }
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
              let loc  = selectedLocation else { return }
        isCreating = true

        var newEvent = Event(
            name:           eventName.trimmingCharacters(in: .whitespacesAndNewlines),
            venueName:      venueName.trimmingCharacters(in: .whitespacesAndNewlines),
            address:        address,
            startDate:      startDate,
            endDate:        endDate,
            latitude:       loc.latitude,
            longitude:      loc.longitude,
            geofenceRadius: geofenceRadius,
            active:         true,
            merchantIds:    [user.uid]
        )
        if let url = eventViewModel.imageUrl {
            newEvent.imageUrl = url
        }

        eventViewModel.createEvent(newEvent) { success in
            isCreating = false
            if success { showingSuccess = true }
        }
    }
}

// MARK: – CreateEventViewModel
class CreateEventViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    @Published var imageUrl: String?

    private let firestoreService = FirestoreService()

    func createEvent(_ event: Event, completion: @escaping (Bool) -> Void) {
        isLoading = true; error = nil
        firestoreService.createEvent(event) { [weak self] success, err in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let err = err {
                    self?.error = err.localizedDescription
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }

    func uploadImage(_ data: Data, completion: @escaping (Bool) -> Void) {
        isLoading = true; error = nil
        let imageID = UUID().uuidString
        let ref     = Storage.storage().reference().child("event_images/\(imageID).jpg")
        ref.putData(data, metadata: nil) { [weak self] _, err in
            if let err = err {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.error     = err.localizedDescription
                    completion(false)
                }
                return
            }
            ref.downloadURL { url, err2 in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let url = url {
                        self?.imageUrl = url.absoluteString
                        completion(true)
                    } else {
                        self?.error = err2?.localizedDescription
                        completion(false)
                    }
                }
            }
        }
    }
}

// MARK: – FirestoreService Extension
extension FirestoreService {
    func createEvent(_ event: Event, completion: @escaping (Bool, Error?) -> Void) {
        do {
            let db  = Firestore.firestore()
            let ref = db.collection("events").document()
            var newEvent = event
            newEvent.id = ref.documentID
            try ref.setData(from: newEvent) { error in
                if let error = error { completion(false, error) }
                else { completion(true, nil) }
            }
        } catch {
            completion(false, error)
        }
    }
}

// MARK: – Supporting Types (from original file)
struct LocationAnnotation: Identifiable {
    let id          = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct EventPreviewCard: View {
    let eventName: String
    let venueName: String
    let startDate: Date
    let endDate: Date
    let address: String

    var body: some View {
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
                Label(formatDateRange(start: startDate, end: endDate),
                      systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let calendar = Calendar.current
        if calendar.isDate(start, inSameDayAs: end) {
            let dateStr = formatter.string(from: start).components(separatedBy: ",").first ?? ""
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return "\(dateStr), \(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))"
        }
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

struct LocationPickerView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var address: String
    @Binding var region: MKCoordinateRegion
    @Environment(\.presentationMode) var presentationMode

    @State private var searchText    = ""
    @State private var searchResults = [MKMapItem]()
    @State private var isSearching   = false
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText) {
                    searchForLocation()
                }
                .padding(.horizontal)

                Map(coordinateRegion: $region,
                    annotationItems: selectedLocation != nil
                        ? [LocationAnnotation(coordinate: selectedLocation!)]
                        : []) { pin in
                    MapAnnotation(coordinate: pin.coordinate) {
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
                    let coord = region.center
                    selectLocation(coord)
                }

                if !searchResults.isEmpty {
                    List(searchResults, id: \.self) { item in
                        Button {
                            selectLocationFromSearch(item)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(item.name ?? "Unknown")
                                    .font(.headline)
                                Text(item.placemark.title ?? "")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pick Location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func searchForLocation() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = searchText
        req.region = region
        MKLocalSearch(request: req).start { resp, _ in
            isSearching = false
            searchResults = resp?.mapItems ?? []
        }
    }

    private func selectLocation(_ coordinate: CLLocationCoordinate2D) {
        selectedLocation = coordinate
        let loc = CLLocation(latitude: coordinate.latitude,
                             longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(loc) { places, _ in
            if let p = places?.first {
                address = [p.name, p.thoroughfare, p.locality, p.administrativeArea]
                    .compactMap { $0 }.joined(separator: ", ")
            }
        }
        region.center = coordinate
        searchResults = []
        searchText = ""
    }

    private func selectLocationFromSearch(_ item: MKMapItem) {
        let c = item.placemark.coordinate
        selectedLocation = c
        address = item.placemark.title ?? ""
        region.center = c
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
                    .onSubmit { onSearchButtonClicked() }
                if !text.isEmpty {
                    Button { text = "" }
                    label: { Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary) }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)

            if !text.isEmpty {
                Button("Search") { onSearchButtonClicked() }
                    .foregroundColor(.purple)
            }
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
}

struct CreateEventView_Previews: PreviewProvider {
    static var previews: some View {
        CreateEventView()
            .environmentObject(AuthViewModel())
    }
}
