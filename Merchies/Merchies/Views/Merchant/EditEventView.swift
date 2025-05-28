// EditEventView.swift

import SwiftUI
import MapKit
import CoreLocation
import PhotosUI
import FirebaseStorage

struct EditEventView: View {
    @StateObject var vm: SingleEventViewModel
    @StateObject private var productViewModel = EventProductsViewModel()
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel

    // Image Picker
    @State private var pickedItem: PhotosPickerItem?
    @State private var uiImage: UIImage?
    @State private var isUploadingImage = false
    @State private var uploadedImageUrl: String?
    
    // Firebase Storage image loading
    @State private var loadedEventImage: UIImage?
    @State private var isLoadingEventImage = false
    @State private var imageLoadError: String?

    // Map & Geofence
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var address = ""
    @State private var showingLocationPicker = false

    // Product management
    @State private var showingAddProducts = false
    @State private var showingCreateProduct = false
    @State private var currentTab = 0
    @State private var refreshTrigger = 0

    // UI state
    @State private var showingSuccess = false

    var body: some View {
        NavigationView {
            TabView(selection: $currentTab) {
                eventDetailsForm()
                    .tabItem {
                        Image(systemName: "info.circle")
                        Text("Details")
                    }
                    .tag(0)

                productsForm()
                    .tabItem {
                        Image(systemName: "tag")
                        Text("Products")
                    }
                    .tag(1)
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveEvent)
                        .disabled(!isFormValid || vm.isLoading || isUploadingImage)
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                EditEventLocationPickerView(
                    selectedLocation: $selectedLocation,
                    address: $address,
                    region: $region
                )
            }
            .sheet(isPresented: $showingAddProducts) {
                EditEventAddProductsView(event: vm.event, viewModel: productViewModel)
                    .onDisappear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            refreshEventData()
                        }
                    }
            }
            .sheet(isPresented: $showingCreateProduct) {
                EditEventCreateProductView()
            }
            .alert("Event Updated!", isPresented: $showingSuccess) {
                Button("OK") { presentationMode.wrappedValue.dismiss() }
            } message: {
                Text("Your changes have been saved.")
            }
            .overlay {
                if vm.isLoading || isUploadingImage {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView(isUploadingImage ? "Uploading Image…" : "Saving…")
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        .scaleEffect(1.5)
                }
            }
            .onAppear {
                setupInitialState()
                loadEventProducts()
                loadEventImageIfNeeded()
            }
        }
    }

    @ViewBuilder
    private func eventDetailsForm() -> some View {
        Form {
            Section("General") {
                TextField("Name", text: $vm.event.name)
                TextField("Venue", text: $vm.event.venueName)
                Toggle("Active", isOn: $vm.event.active)
            }

            Section("Event Image (Optional)") {
                PhotosPicker(
                    selection: $pickedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text(hasEventImage ? "Change Image" : "Choose Image")
                        if isUploadingImage {
                            Spacer()
                            ProgressView().scaleEffect(0.8)
                        }
                    }
                }
                .disabled(isUploadingImage)
                .onChange(of: pickedItem, perform: handleImageSelection)

                // Show newly selected image (not yet uploaded)
                if let img = uiImage {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(8)
                        if uploadedImageUrl != nil {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("New image uploaded successfully")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else if isUploadingImage {
                            HStack {
                                ProgressView().scaleEffect(0.7)
                                Text("Uploading new image…")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                // Show existing event image loaded from Firebase Storage
                else if let existingImage = loadedEventImage {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(uiImage: existingImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(8)
                        
                        HStack {
                            Text("Current event image")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Remove") { removeCurrentImage() }
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                // Show loading state for existing image
                else if isLoadingEventImage {
                    VStack(alignment: .leading, spacing: 8) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .cornerRadius(8)
                            .overlay(
                                VStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                    Text("Loading image...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                }
                // Show error state if image failed to load
                else if let error = imageLoadError {
                    VStack(alignment: .leading, spacing: 8) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .cornerRadius(8)
                            .overlay(
                                VStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                        .font(.title2)
                                    Text("Failed to load image")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(error)
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 4)
                                }
                            )
                        
                        HStack {
                            Button("Retry") {
                                loadEventImageIfNeeded()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Button("Remove") {
                                removeCurrentImage()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                }
            }

            Section("Timing") {
                DatePicker("Starts", selection: $vm.event.startDate)
                DatePicker("Ends", selection: $vm.event.endDate)
                    .onChange(of: vm.event.startDate) { newStart in
                        if vm.event.endDate <= newStart {
                            vm.event.endDate = newStart.addingTimeInterval(3600)
                        }
                    }
            }

            Section("Location & Geofencing") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Address").font(.subheadline)
                        Text(address.isEmpty ? "Tap to set location" : address)
                            .foregroundColor(address.isEmpty ? .gray : .primary)
                    }
                    Spacer()
                    Button("Set Location") { showingLocationPicker = true }
                        .foregroundColor(.purple)
                }

                TextField("Or type address manually", text: $address)
                    .onSubmit { geocodeAddress() }

                if let loc = selectedLocation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Geofence Radius").font(.subheadline)
                        HStack {
                            Slider(value: $vm.event.geofenceRadius, in: 50...500, step: 10)
                            Text("\(Int(vm.event.geofenceRadius)) m")
                                .frame(width: 50)
                                .font(.caption)
                        }
                        Text("Fans within \(Int(vm.event.geofenceRadius)) m can access your merch store")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Map(
                        coordinateRegion: .constant(
                            MKCoordinateRegion(
                                center: loc,
                                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                            )
                        ),
                        annotationItems: [EditEventLocationAnnotation(coordinate: loc)]
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

            if !vm.event.name.isEmpty && !vm.event.venueName.isEmpty {
                Section("Event Preview") {
                    EditEventPreviewCard(
                        eventName: vm.event.name,
                        venueName: vm.event.venueName,
                        startDate: vm.event.startDate,
                        endDate: vm.event.endDate,
                        address: address,
                        previewImage: currentPreviewImage
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func productsForm() -> some View {
        VStack {
            if productViewModel.products.isEmpty {
                EditEventEmptyProductsState(
                    showingAddProducts: $showingAddProducts,
                    showingCreateProduct: $showingCreateProduct
                )
            } else {
                Form {
                    Section(header:
                        HStack {
                            Text("Event Products (\(productViewModel.products.count))")
                            Spacer()
                            Menu {
                                Button("Add Existing Products", systemImage: "plus.square.on.square") {
                                    showingAddProducts = true
                                }
                                Button("Create New Product", systemImage: "plus.square") {
                                    showingCreateProduct = true
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .foregroundColor(.purple)
                            }
                        }
                    ) {
                        ForEach(productViewModel.products) { product in
                            EditEventProductRow(
                                product: product,
                                onRemove: { removeProduct(product) }
                            )
                        }
                    }
                }
            }
        }
        .id(refreshTrigger)
        .refreshable { loadEventProducts() }
    }

    // MARK: Image Handling

    private func handleImageSelection(_ newItem: PhotosPickerItem?) {
        guard let item = newItem else { return }
        isUploadingImage = true
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        uiImage = img
                        // Clear existing loaded image since we have a new one
                        loadedEventImage = nil
                        imageLoadError = nil
                    }
                    await uploadImageData(data)
                }
            } catch {
                await MainActor.run {
                    isUploadingImage = false
                    print("Error loading image: \(error)")
                }
            }
        }
    }

    private func uploadImageData(_ data: Data) async {
        await withCheckedContinuation { cont in
            let imageID = UUID().uuidString
            let ref = Storage.storage().reference().child("event_images/\(imageID).jpg")
            ref.putData(data, metadata: nil) { _, err in
                DispatchQueue.main.async {
                    self.isUploadingImage = false
                    if let err = err {
                        print("❌ Upload error: \(err.localizedDescription)")
                    } else {
                        ref.downloadURL { url, _ in
                            if let url = url {
                                self.uploadedImageUrl = url.absoluteString
                                print("✅ Uploaded: \(url)")
                            }
                        }
                    }
                    cont.resume()
                }
            }
        }
    }
    
    private func loadEventImageIfNeeded() {
        // Don't load if we already have a new image selected or if there's no existing image URL
        guard uiImage == nil,
              let imageUrl = vm.event.imageUrl,
              !imageUrl.isEmpty,
              loadedEventImage == nil else { return }
        
        isLoadingEventImage = true
        imageLoadError = nil
        
        // Check if it's a Firebase Storage URL or regular HTTP URL
        if imageUrl.contains("firebasestorage.googleapis.com") {
            // Use Firebase Storage reference for Firebase URLs
            do {
                let storageRef = Storage.storage().reference(forURL: imageUrl)
                storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        self.isLoadingEventImage = false
                        if let error = error {
                            self.imageLoadError = error.localizedDescription
                        } else if let data = data, let image = UIImage(data: data) {
                            self.loadedEventImage = image
                            self.imageLoadError = nil
                        } else {
                            self.imageLoadError = "Failed to load image data"
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingEventImage = false
                    self.imageLoadError = "Invalid Firebase Storage URL: \(error.localizedDescription)"
                }
            }
        } else {
            // Use URLSession for regular HTTP URLs
            guard let url = URL(string: imageUrl) else {
                DispatchQueue.main.async {
                    self.isLoadingEventImage = false
                    self.imageLoadError = "Invalid URL format"
                }
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    self.isLoadingEventImage = false
                    if let error = error {
                        self.imageLoadError = error.localizedDescription
                    } else if let data = data, let image = UIImage(data: data) {
                        self.loadedEventImage = image
                        self.imageLoadError = nil
                    } else {
                        self.imageLoadError = "Failed to load image data"
                    }
                }
            }.resume()
        }
    }

    private func removeCurrentImage() {
        vm.event.imageUrl = nil
        uiImage = nil
        uploadedImageUrl = nil
        loadedEventImage = nil
        imageLoadError = nil
    }

    private func geocodeAddress() {
        guard !address.isEmpty else { return }
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { marks, _ in
            if let mark = marks?.first, let loc = mark.location {
                selectedLocation = loc.coordinate
                region.center = loc.coordinate
                vm.event.latitude = loc.coordinate.latitude
                vm.event.longitude = loc.coordinate.longitude
            }
        }
    }

    // MARK: Computed

    private var hasEventImage: Bool {
        uiImage != nil || loadedEventImage != nil || (vm.event.imageUrl?.isEmpty == false)
    }

    private var currentImageUrl: String? {
        uploadedImageUrl ?? vm.event.imageUrl
    }
    
    private var currentPreviewImage: UIImage? {
        uiImage ?? loadedEventImage
    }

    private var isFormValid: Bool {
        !vm.event.name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !vm.event.venueName.trimmingCharacters(in: .whitespaces).isEmpty &&
        vm.event.endDate > vm.event.startDate
    }

    // MARK: Lifecycle Helpers

    private func setupInitialState() {
        let coord = CLLocationCoordinate2D(latitude: vm.event.latitude, longitude: vm.event.longitude)
        selectedLocation = coord
        address = vm.event.address
        region.center = coord
    }

    private func loadEventProducts() {
        guard let id = vm.event.id else { return }
        productViewModel.fetchEventProducts(eventId: id)
    }

    private func removeProduct(_ product: Product) {
        guard let eid = vm.event.id, let pid = product.id else { return }
        productViewModel.removeProductFromEvent(productId: pid, eventId: eid) { success in
            if success {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                refreshEventData()
            }
        }
    }

    private func refreshEventData() {
        guard let id = vm.event.id else { return }
        productViewModel.fetchEventProducts(eventId: id)
        vm.refreshEvent()
        refreshTrigger += 1
    }

    private func saveEvent() {
        if let newUrl = uploadedImageUrl { vm.event.imageUrl = newUrl }
        if let loc = selectedLocation {
            vm.event.latitude = loc.latitude
            vm.event.longitude = loc.longitude
        }
        vm.event.address = address
        vm.save { success in
            if success { showingSuccess = true }
        }
    }
}

// MARK: – Supporting Views

struct EditEventLocationAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct EditEventLocationPickerView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var address: String
    @Binding var region: MKCoordinateRegion
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @State private var searchResults = [MKMapItem]()

    var body: some View {
        NavigationView {
            VStack {
                EditEventLocationSearchBar(text: $searchText) {
                    searchForLocation()
                }
                .padding(.horizontal)

                Map(coordinateRegion: $region,
                    annotationItems: selectedLocation.map { [EditEventLocationAnnotation(coordinate: $0)] } ?? []
                ) { pin in
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
                    selectLocation(region.center)
                }

                if !searchResults.isEmpty {
                    List(searchResults, id: \.self) { item in
                        Button {
                            selectLocationFromSearch(item)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(item.name ?? "Unknown").font(.headline)
                                Text(item.placemark.title ?? "").font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pick Location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                        .disabled(selectedLocation == nil)
                }
            }
        }
    }

    private func searchForLocation() {
        guard !searchText.isEmpty else { return }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = searchText
        req.region = region
        MKLocalSearch(request: req).start { resp, _ in
            searchResults = resp?.mapItems ?? []
        }
    }

    private func selectLocation(_ coordinate: CLLocationCoordinate2D) {
        selectedLocation = coordinate
        let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
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

struct EditEventLocationSearchBar: View {
    @Binding var text: String
    var onSearchButtonClicked: () -> Void

    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search for venue or address", text: $text)
                    .onSubmit { onSearchButtonClicked() }
                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
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

struct EditEventPreviewCard: View {
    let eventName: String
    let venueName: String
    let startDate: Date
    let endDate: Date
    let address: String
    let previewImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .cornerRadius(8)
                    .clipped()
            }

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
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let cal = Calendar.current
        if cal.isDate(start, inSameDayAs: end) {
            let dateStr = formatter.string(from: start).components(separatedBy: ",").first ?? ""
            let tFormatter = DateFormatter()
            tFormatter.timeStyle = .short
            return "\(dateStr), \(tFormatter.string(from: start)) – \(tFormatter.string(from: end))"
        }
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}

struct EditEventProductRow: View {
    let product: Product
    let onRemove: () -> Void
    @State private var showingRemoveAlert = false
    @State private var productImage: UIImage?
    @State private var isLoadingProductImage = false

    var body: some View {
        HStack(spacing: 12) {
            // Use safe image loading for product images
            Group {
                if let image = productImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                        .clipped()
                } else if isLoadingProductImage {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                        .overlay(ProgressView().scaleEffect(0.8))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                }
            }
            .onAppear {
                loadProductImage()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("$\(String(format: "%.2f", product.price))")
                    .font(.caption)
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)

                HStack {
                    Text(product.sizes.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(product.inventory.values.reduce(0, +)) in stock")
                        .font(.caption2)
                        .foregroundColor(product.inventory.values.reduce(0, +) > 0 ? .green : .red)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                VStack {
                    Circle()
                        .fill(product.active ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(product.active ? "Active" : "Off")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Button {
                    showingRemoveAlert = true
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 18))
                }
            }
        }
        .padding(.vertical, 4)
        .alert("Remove Product", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive, action: onRemove)
        } message: {
            Text("Are you sure you want to remove this product? Fans won't be able to purchase it anymore.")
        }
    }
    
    private func loadProductImage() {
        guard !product.imageUrl.isEmpty, productImage == nil else { return }
        
        isLoadingProductImage = true
        
        if product.imageUrl.contains("firebasestorage.googleapis.com") {
            // Use Firebase Storage reference for Firebase URLs
            do {
                let storageRef = Storage.storage().reference(forURL: product.imageUrl)
                storageRef.getData(maxSize: 5 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        self.isLoadingProductImage = false
                        if let data = data, let image = UIImage(data: data) {
                            self.productImage = image
                        } else if let error = error {
                            print("Failed to load product image: \(error.localizedDescription)")
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingProductImage = false
                    print("Invalid Firebase Storage URL: \(error.localizedDescription)")
                }
            }
        } else {
            // Use URLSession for regular HTTP URLs
            guard let url = URL(string: product.imageUrl) else {
                DispatchQueue.main.async {
                    self.isLoadingProductImage = false
                }
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    self.isLoadingProductImage = false
                    if let data = data, let image = UIImage(data: data) {
                        self.productImage = image
                    } else if let error = error {
                        print("Failed to load product image: \(error.localizedDescription)")
                    }
                }
            }.resume()
        }
    }
}

struct EditEventEmptyProductsState: View {
    @Binding var showingAddProducts: Bool
    @Binding var showingCreateProduct: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "tag.circle")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("No Products Added")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add products to your event so fans can discover and purchase your merchandise.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Button(action: { showingAddProducts = true }) {
                    Label("Add Existing Products", systemImage: "plus.square.on.square")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(12)
                }

                Button(action: { showingCreateProduct = true }) {
                    Label("Create New Product", systemImage: "plus.square")
                        .font(.headline)
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding()
    }
}

struct EditEventAddProductsView: View {
    let event: Event
    @ObservedObject var viewModel: EventProductsViewModel
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedProducts = Set<String>()
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            Group {
                if viewModel.availableProducts.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 20) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Available Products").font(.headline)
                        Text("All your products are already added or you haven't created any.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding()
                } else {
                    List {
                        Section("Available Products") {
                            ForEach(viewModel.availableProducts) { product in
                                EditEventSelectableProductRow(
                                    product: product,
                                    isSelected: selectedProducts.contains(product.id ?? "")
                                ) { isSel in
                                    if let id = product.id {
                                        if isSel { selectedProducts.insert(id) }
                                        else { selectedProducts.remove(id) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Products")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Selected", action: addSelectedProducts)
                        .disabled(selectedProducts.isEmpty || isLoading)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let uid = authViewModel.user?.uid, let eid = event.id {
                    viewModel.fetchMerchantProducts(merchantId: uid, excludingEventId: eid)
                }
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack {
                        ProgressView().scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        Text("Adding Products…").font(.headline)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
            }
        }
    }

    private func addSelectedProducts() {
        guard let eid = event.id else { return }
        isLoading = true
        let group = DispatchGroup()
        var failed = false

        for pid in selectedProducts {
            group.enter()
            viewModel.addProductToEvent(productId: pid, eventId: eid) { success in
                if !success { failed = true }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            isLoading = false
            if !failed { presentationMode.wrappedValue.dismiss() }
        }
    }
}

struct EditEventSelectableProductRow: View {
    let product: Product
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    @State private var productImage: UIImage?
    @State private var isLoadingProductImage = false

    var body: some View {
        Button {
            onSelectionChanged(!isSelected)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .purple : .gray)
                    .font(.title3)

                // Use safe image loading
                Group {
                    if let image = productImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .cornerRadius(6)
                            .clipped()
                    } else if isLoadingProductImage {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .cornerRadius(6)
                            .overlay(ProgressView().scaleEffect(0.7))
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .cornerRadius(6)
                            .overlay(Image(systemName: "photo").foregroundColor(.gray))
                    }
                }
                .onAppear {
                    loadProductImage()
                }

                Text(product.title)
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func loadProductImage() {
        guard !product.imageUrl.isEmpty, productImage == nil else { return }
        
        isLoadingProductImage = true
        
        if product.imageUrl.contains("firebasestorage.googleapis.com") {
            // Use Firebase Storage reference for Firebase URLs
            do {
                let storageRef = Storage.storage().reference(forURL: product.imageUrl)
                storageRef.getData(maxSize: 5 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        self.isLoadingProductImage = false
                        if let data = data, let image = UIImage(data: data) {
                            self.productImage = image
                        } else if let error = error {
                            print("Failed to load product image: \(error.localizedDescription)")
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingProductImage = false
                    print("Invalid Firebase Storage URL: \(error.localizedDescription)")
                }
            }
        } else {
            // Use URLSession for regular HTTP URLs
            guard let url = URL(string: product.imageUrl) else {
                DispatchQueue.main.async {
                    self.isLoadingProductImage = false
                }
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    self.isLoadingProductImage = false
                    if let data = data, let image = UIImage(data: data) {
                        self.productImage = image
                    } else if let error = error {
                        print("Failed to load product image: \(error.localizedDescription)")
                    }
                }
            }.resume()
        }
    }
}

struct EditEventCreateProductView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create New Product")
                    .font(.title).fontWeight(.bold)
                    .padding(.top, 50)
                Image(systemName: "plus.square.dashed")
                    .font(.system(size: 64))
                    .foregroundColor(.gray)
                Text("This will open the product creation form. After creating, add it here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
                Button("Continue to Product Creation") {
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .cornerRadius(10)
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
            .navigationTitle("Create Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
