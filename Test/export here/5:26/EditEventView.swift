// EditEventView.swift

import SwiftUI
import MapKit
import CoreLocation

struct EditEventView: View {
    @StateObject var vm: SingleEventViewModel
    @Environment(\.presentationMode) var presentationMode

    // MARK: – Form state
    @State private var eventDescription = ""
    @State private var maxCapacity = ""
    @State private var ticketPrice = ""

    // MARK: – Map & geofence
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var address = ""
    @State private var showingLocationPicker = false

    // MARK: – UI state
    @State private var showingSuccess = false

    var body: some View {
        NavigationView {
            Form {
                // Basic Event Information
                Section(header: Text("Event Details")) {
                    TextField("Event Name", text: $vm.event.name)
                    TextField("Venue Name", text: $vm.event.venueName)
                    TextField("Event Description (Optional)", text: $eventDescription, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Date & Time
                Section(header: Text("Schedule")) {
                    DatePicker("Start Date & Time",
                               selection: $vm.event.startDate,
                               displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End Date & Time",
                               selection: $vm.event.endDate,
                               displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: vm.event.startDate) { newStart in
                            if vm.event.endDate <= newStart {
                                vm.event.endDate = newStart.addingTimeInterval(3600)
                            }
                        }
                }

                // Location & Geofencing
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
                                Slider(value: $vm.event.geofenceRadius,
                                       in: 50...500,
                                       step: 10) { Text("Radius") }
                                Text("\(Int(vm.event.geofenceRadius)) m")
                                    .frame(width: 50)
                                    .font(.caption)
                            }
                            Text("Fans within \(Int(vm.event.geofenceRadius)) m can access your merch store")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        // Mini map preview
                        Map(coordinateRegion: .constant(
                                MKCoordinateRegion(
                                  center: loc,
                                  span: MKCoordinateSpan(latitudeDelta: 0.005,
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

               
                // Preview
                if !vm.event.name.isEmpty && !vm.event.venueName.isEmpty && selectedLocation != nil {
                    Section(header: Text("Event Preview")) {
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.save { success in
                            if success {
                                showingSuccess = true
                            }
                        }
                    }
                    .disabled(!isFormValid || vm.isLoading)
                    .fontWeight(.semibold)
                }
            }
            // Location picker sheet
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(
                    selectedLocation: $selectedLocation,
                    address: $address,
                    region: $region
                )
            }
            // Success alert
            .alert("Event Updated!", isPresented: $showingSuccess) {
                Button("OK") { presentationMode.wrappedValue.dismiss() }
            } message: {
                Text("Your changes have been saved.")
            }
            // Error alert
            .alert(item: Binding<ErrorAlert?>(
                get: { vm.error.map { ErrorAlert(message: $0) } },
                set: { _ in vm.error = nil }
            )) { error in
                Alert(title: Text("Error"),
                      message: Text(error.message),
                      dismissButton: .default(Text("OK")))
            }
            // Loading overlay
            .overlay(
                Group {
                    if vm.isLoading {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                            Text("Saving Event…")
                                .font(.headline)
                                .padding(.top)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                    }
                }
            )
            // Initialize map + address when view appears
            .onAppear {
                // load location from vm.event
                let coord = CLLocationCoordinate2D(
                    latitude: vm.event.latitude,
                    longitude: vm.event.longitude
                )
                selectedLocation = coord
                address = vm.event.address
                region = MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01,
                                           longitudeDelta: 0.01)
                )
            }
        }
    }

    // MARK: – Validation
    private var isFormValid: Bool {
        !vm.event.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !vm.event.venueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedLocation != nil &&
        vm.event.endDate > vm.event.startDate
    }
}
