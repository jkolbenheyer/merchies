// EditEventView.swift

import SwiftUI
import MapKit
import CoreLocation
import PhotosUI
import FirebaseStorage

struct EditEventView: View {
    @StateObject var vm: SingleEventViewModel
    @Environment(\.presentationMode) var presentationMode

    // Form state
    @State private var eventDescription = ""
    @State private var maxCapacity      = ""
    @State private var ticketPrice      = ""

    // Image Picker
    @State private var pickedItem: PhotosPickerItem?
    @State private var uiImage: UIImage?

    // Map & Geofence
    @State private var region               = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span:   MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var address              = ""
    @State private var showingLocationPicker = false

    // UI state
    @State private var showingSuccess = false

    var body: some View {
        NavigationView {
            Form {
                // MARK: – General
                Section("General") {
                    TextField("Name",    text: $vm.event.name)
                    TextField("Venue",   text: $vm.event.venueName)
                    TextField("Address", text: $vm.event.address)
                    Toggle("Active", isOn: $vm.event.active)
                }

                // MARK: – Event Image (Optional)
                Section("Event Image (Optional)") {
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
                                vm.uploadImage(data) { _ in }
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

                // MARK: – Timing
                Section("Timing") {
                    DatePicker("Starts", selection: $vm.event.startDate)
                    DatePicker("Ends",   selection: $vm.event.endDate)
                        .onChange(of: vm.event.startDate) { newStart in
                            if vm.event.endDate <= newStart {
                                vm.event.endDate = newStart.addingTimeInterval(3600)
                            }
                        }
                }

                // MARK: – Location & Geofencing
                Section("Location & Geofencing") {
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
                                Slider(value: $vm.event.geofenceRadius,
                                       in: 50...500, step: 10) { Text("Radius") }
                                Text("\(Int(vm.event.geofenceRadius)) m")
                                    .frame(width: 50)
                                    .font(.caption)
                            }
                            Text("Fans within \(Int(vm.event.geofenceRadius)) m can access your merch store")
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
                                    Circle().fill(Color.purple).frame(width: 20, height: 20)
                                    Circle().stroke(Color.purple.opacity(0.3), lineWidth: 2)
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
                if !vm.event.name.isEmpty && !vm.event.venueName.isEmpty && selectedLocation != nil {
                    Section("Event Preview") {
                        EventPreviewCard(
                            eventName: vm.event.name,
                            venueName: vm.event.venueName,
                            startDate: vm.event.startDate,
                            endDate: vm.event.endDate,
                            address: address
                        )
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.save { success in
                            if success { showingSuccess = true }
                        }
                    }
                    .disabled(!isFormValid || vm.isLoading)
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
            .alert("Event Updated!", isPresented: $showingSuccess) {
                Button("OK") { presentationMode.wrappedValue.dismiss() }
            } message: {
                Text("Your changes have been saved.")
            }
            .overlay {
                if vm.isLoading {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("Saving…")
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        .scaleEffect(1.5)
                }
            }
            .onAppear {
                let coord = CLLocationCoordinate2D(
                    latitude: vm.event.latitude,
                    longitude: vm.event.longitude
                )
                selectedLocation = coord
                address          = vm.event.address
                region            = MKCoordinateRegion(
                    center: coord,
                    span:   MKCoordinateSpan(latitudeDelta: 0.01,
                                             longitudeDelta: 0.01)
                )
            }
        }
    }

    private var isFormValid: Bool {
        !vm.event.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !vm.event.venueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedLocation != nil &&
        vm.event.endDate > vm.event.startDate
    }
}
