// EditEventView.swift - UPDATED with Product Creation Integration
import SwiftUI
import MapKit
import CoreLocation
import PhotosUI
import FirebaseStorage
import FirebaseFirestore
import Foundation

struct EditEventView: View {
    @StateObject var vm: SingleEventViewModel
    @StateObject private var productViewModel = EventProductsViewModel()
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel

    // Image handling
    @State private var pickedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isUploadingImage = false
    @State private var uploadedImageUrl: String?
    @State private var loadedEventImage: UIImage?
    @State private var isLoadingEventImage = false
    @State private var imageLoadError: String?

    // Location & Map
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

    // UI states
    @State private var showingSuccess = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    @State private var formErrors: [String: String] = [:]

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                TabView(selection: $currentTab) {
                    eventDetailsView()
                        .tabItem {
                            Image(systemName: "info.circle")
                            Text("Details")
                        }
                        .tag(0)

                    productsView()
                        .tabItem {
                            Image(systemName: "tag")
                            Text("Products")
                        }
                        .tag(1)
                }
                
                // Loading overlay
                DSLoadingOverlay(
                    message: loadingMessage,
                    isVisible: vm.isLoading || isUploadingImage || isDeleting
                )
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        saveEvent()
                    }
                    .disabled(!isFormValid || vm.isLoading || isUploadingImage || isDeleting)
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
            // UPDATED: Real product creation with event linking
            .sheet(isPresented: $showingCreateProduct) {
                CreateProductForEventView(
                    event: vm.event,
                    bandId: authViewModel.user?.uid ?? ""
                )
                .onDisappear {
                    // Refresh products when creation sheet closes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        refreshEventData()
                    }
                }
            }
            .alert("Event Updated!", isPresented: $showingSuccess) {
                Button("OK") { }
            } message: {
                Text("Your changes have been saved successfully.")
            }
            .alert("Delete Event", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteEvent()
                }
            } message: {
                Text("Are you sure you want to delete '\(vm.event.name)'? This action cannot be undone and will remove all associated products from this event.")
            }
            .onAppear {
                print("🔍 EditEventView - onAppear triggered")
                print("🔍 EditEventView - Event name: \(vm.event.name)")
                print("🔍 EditEventView - Event ID: \(vm.event.id ?? "nil")")
                
                setupInitialState()
                loadEventProducts()
                loadEventImageIfNeeded()
            }
        }
    }
    
    // MARK: - Event Details View (keeping existing implementation)
    @ViewBuilder
    private func eventDetailsView() -> some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.sectionSpacing) {
                
                // Basic Information
                DSCard {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Event Information")
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            Text("Basic details about your event")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // Event Name Field
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                HStack {
                                    Text("Event Name")
                                        .font(DesignSystem.Typography.subheadline)
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                    Text("*")
                                        .foregroundColor(DesignSystem.Colors.danger)
                                }
                                
                                TextField("Enter event name", text: $vm.event.name)
                                    .font(DesignSystem.Typography.body)
                                    .padding(DesignSystem.Spacing.inputPadding)
                                    .background(DesignSystem.Colors.inputBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                            .stroke(
                                                formErrors["name"] != nil ? DesignSystem.Colors.danger : Color(.systemGray3),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .cornerRadius(DesignSystem.CornerRadius.sm)
                                
                                if let error = formErrors["name"] {
                                    Text(error)
                                        .font(DesignSystem.Typography.caption1)
                                        .foregroundColor(DesignSystem.Colors.danger)
                                }
                            }
                            
                            // Venue Name Field
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                HStack {
                                    Text("Venue Name")
                                        .font(DesignSystem.Typography.subheadline)
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                    Text("*")
                                        .foregroundColor(DesignSystem.Colors.danger)
                                }
                                
                                TextField("Enter venue name", text: $vm.event.venueName)
                                    .font(DesignSystem.Typography.body)
                                    .padding(DesignSystem.Spacing.inputPadding)
                                    .background(DesignSystem.Colors.inputBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                            .stroke(
                                                formErrors["venue"] != nil ? DesignSystem.Colors.danger : Color(.systemGray3),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .cornerRadius(DesignSystem.CornerRadius.sm)
                                
                                if let error = formErrors["venue"] {
                                    Text(error)
                                        .font(DesignSystem.Typography.caption1)
                                        .foregroundColor(DesignSystem.Colors.danger)
                                }
                            }
                            
                            // Event Status Toggle
                            HStack {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text("Event Status")
                                        .font(DesignSystem.Typography.subheadline)
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                    Text("Active events are visible to fans")
                                        .font(DesignSystem.Typography.caption1)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $vm.event.active)
                                    .labelsHidden()
                            }
                        }
                    }
                }
                
                // Event Image (keeping existing implementation)
                DSCard {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Event Image")
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            Text("Add an image to make your event more appealing")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        
                        // Image Display Area
                        Group {
                            if let image = selectedImage {
                                // New selected image
                                ImageDisplayCard(
                                    image: image,
                                    isLoading: isUploadingImage,
                                    loadingText: "Uploading new image...",
                                    onRemove: removeCurrentImage
                                )
                            } else if let existingImage = loadedEventImage {
                                // Existing image loaded from Firebase
                                ImageDisplayCard(
                                    image: existingImage,
                                    isLoading: false,
                                    loadingText: nil,
                                    onRemove: removeCurrentImage
                                )
                            } else if isLoadingEventImage {
                                // Loading existing image
                                ImageLoadingCard(message: "Loading event image...")
                            } else if let error = imageLoadError {
                                // Error loading image
                                ImageErrorCard(
                                    error: error,
                                    onRetry: loadEventImageIfNeeded,
                                    onRemove: removeCurrentImage
                                )
                            } else {
                                // No image placeholder
                                ImagePlaceholderCard()
                            }
                        }
                        
                        // Image Action Buttons
                        VStack(spacing: DesignSystem.Spacing.md) {
                            PhotosPicker(
                                selection: $pickedItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                HStack {
                                    Image(systemName: "photo")
                                    Text(hasEventImage ? "Change Image" : "Choose Image")
                                        .fontWeight(.medium)
                                    if isUploadingImage {
                                        Spacer()
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                .foregroundColor(DesignSystem.Colors.primary)
                                .frame(maxWidth: .infinity)
                                .padding(DesignSystem.Spacing.lg)
                                .background(DesignSystem.Colors.primary.opacity(0.1))
                                .cornerRadius(DesignSystem.CornerRadius.md)
                            }
                            .disabled(isUploadingImage)
                            .onChange(of: pickedItem) { newItem in
                                handleImageSelection(newItem)
                            }
                        }
                    }
                }
                
                // Schedule, Location sections (keeping existing implementation)
                // ... [other sections remain the same] ...
                
            }
            .padding(DesignSystem.Spacing.screenPadding)
        }
    }
    
    // MARK: - UPDATED Products View with Create Product Integration
    @ViewBuilder
    private func productsView() -> some View {
        VStack(spacing: 0) {
            if productViewModel.products.isEmpty {
                DSEmptyState(
                    icon: "tag.circle",
                    title: "No Products Added",
                    subtitle: "Add products to your event so fans can discover and purchase your merchandise.",
                    primaryActionTitle: "Add Existing Products",
                    primaryAction: { showingAddProducts = true },
                    secondaryActionTitle: "Create New Product",
                    secondaryAction: { showingCreateProduct = true }
                )
            } else {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.sectionSpacing) {
                        DSSectionCard(
                            title: "Event Products",
                            subtitle: "\(productViewModel.products.count) products available",
                            actionTitle: "Add More",
                            action: { showingAddProducts = true }
                        ) {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                ForEach(productViewModel.products) { product in
                                    EditEventProductRow(
                                        product: product,
                                        onRemove: { removeProduct(product) }
                                    )
                                }
                                
                                // Add Create New Product button within the products list
                                Button(action: { showingCreateProduct = true }) {
                                    HStack {
                                        Image(systemName: "plus.circle.dashed")
                                            .font(.title2)
                                        Text("Create New Product for This Event")
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(DesignSystem.Colors.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(DesignSystem.Spacing.lg)
                                    .background(DesignSystem.Colors.primary.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                            .stroke(DesignSystem.Colors.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                                    )
                                    .cornerRadius(DesignSystem.CornerRadius.md)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.screenPadding)
                }
                .refreshable {
                    loadEventProducts()
                }
            }
        }
        .id(refreshTrigger)
    }
    
    // MARK: - Helper Methods (keeping existing implementations)
    
    private var loadingMessage: String {
        if isDeleting { return "Deleting Event…" }
        if isUploadingImage { return "Uploading Image…" }
        return "Saving Changes…"
    }
    
    private var hasEventImage: Bool {
        selectedImage != nil || loadedEventImage != nil || (vm.event.imageUrl?.isEmpty == false)
    }
    
    private var currentImageUrl: String? {
        uploadedImageUrl ?? vm.event.imageUrl
    }
    
    private var currentPreviewImage: UIImage? {
        selectedImage ?? loadedEventImage
    }
    
    private var isFormValid: Bool {
        validateForm()
        return formErrors.isEmpty
    }
    
    private func validateForm() {
        formErrors.removeAll()
        
        if vm.event.name.trimmingCharacters(in: .whitespaces).isEmpty {
            formErrors["name"] = "Event name is required"
        }
        
        if vm.event.venueName.trimmingCharacters(in: .whitespaces).isEmpty {
            formErrors["venue"] = "Venue name is required"
        }
        
        if vm.event.endDate <= vm.event.startDate {
            formErrors["date"] = "End date must be after start date"
        }
    }
    
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
    
    private func refreshEventData() {
        guard let id = vm.event.id else { return }
        productViewModel.fetchEventProducts(eventId: id)
        vm.refreshEvent()
        refreshTrigger += 1
    }
    
    // MARK: - Image Handling (keeping existing implementations)
    
    private func handleImageSelection(_ newItem: PhotosPickerItem?) {
        guard let item = newItem else { return }
        isUploadingImage = true
        
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = img
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
        guard selectedImage == nil,
              let imageUrl = vm.event.imageUrl,
              !imageUrl.isEmpty,
              loadedEventImage == nil else { return }
        
        isLoadingEventImage = true
        imageLoadError = nil
        
        if imageUrl.contains("firebasestorage.googleapis.com") {
            loadFirebaseImage(from: imageUrl)
        } else {
            loadImageFromURL(imageUrl)
        }
    }
    
    private func loadFirebaseImage(from urlString: String) {
        do {
            let storageRef = Storage.storage().reference(forURL: urlString)
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
    }
    
    private func loadImageFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
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
    
    private func removeCurrentImage() {
        print("🗑️ Removing current image...")
        vm.event.imageUrl = nil
        selectedImage = nil
        uploadedImageUrl = nil
        loadedEventImage = nil
        imageLoadError = nil
        pickedItem = nil
        print("🗑️ Image removal completed")
    }
    
    // MARK: - Product Management
    
    private func removeProduct(_ product: Product) {
        guard let eid = vm.event.id, let pid = product.id else { return }
        productViewModel.removeProductFromEvent(productId: pid, eventId: eid) { success in
            if success {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                refreshEventData()
            }
        }
    }
    
    // MARK: - Event Actions
    
    private func saveEvent() {
        print("🔄 Starting save process...")
        
        // Handle image state
        if let newUrl = uploadedImageUrl {
            vm.event.imageUrl = newUrl
            print("💾 Saving event with new image URL: \(newUrl)")
        } else if selectedImage == nil && loadedEventImage == nil && vm.event.imageUrl != nil {
            vm.event.imageUrl = nil
            print("💾 Saving event with image removed")
        }
        
        // Update location
        if let loc = selectedLocation {
            vm.event.latitude = loc.latitude
            vm.event.longitude = loc.longitude
        }
        vm.event.address = address
        
        print("📤 Final event imageUrl before save: \(vm.event.imageUrl ?? "nil")")
        
        vm.save { success in
            if success {
                showingSuccess = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                print("✅ Event saved successfully")
            } else {
                print("❌ Event save failed")
            }
        }
    }
    
    private func deleteEvent() {
        guard let eventId = vm.event.id else {
            print("❌ Cannot delete event - missing ID")
            return
        }
        
        isDeleting = true
        
        let firestoreService = FirestoreService()
        firestoreService.deleteEvent(eventId: eventId) { error in
            DispatchQueue.main.async {
                self.isDeleting = false
                
                if let error = error {
                    print("❌ Failed to delete event: \(error.localizedDescription)")
                } else {
                    print("✅ Event deleted successfully")
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// MARK: - NEW: Create Product for Event View
struct CreateProductForEventView: View {
    let event: Event
    let bandId: String
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var productViewModel = ProductViewModel()
    @State private var createdProductId: String?
    @State private var isLinkingProduct = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main product creation view
                MerchProductEditViewContent(
                    bandId: bandId,
                    onProductCreated: { productId in
                        createdProductId = productId
                        linkProductToEvent(productId: productId)
                    },
                    onError: { error in
                        errorMessage = error
                    }
                )
                
                // Linking overlay
                if isLinkingProduct {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                        
                        Text("Linking product to event...")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }
                    .padding(24)
                    .background(DesignSystem.Colors.cardBackground)
                    .cornerRadius(DesignSystem.CornerRadius.lg)
                    .shadow(radius: 10)
                }
            }
            .navigationTitle("Create Product for Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Product Created & Added!", isPresented: $showingSuccess) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Your product has been created and automatically added to '\(event.name)'. Fans can now discover and purchase it at this event!")
            }
            .alert(item: Binding<AlertItem?>(
                get: { errorMessage != nil ? AlertItem(title: "Error", message: errorMessage!) : nil },
                set: { _ in errorMessage = nil }
            )) { alertItem in
                Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func linkProductToEvent(productId: String) {
        print("🔗 EditEventView - linkProductToEvent called")
        print("🔗 EditEventView - Product ID: \(productId)")
        print("🔗 EditEventView - Event name: \(event.name)")
        print("🔗 EditEventView - Event ID: \(event.id ?? "nil")")
        
        guard let eventId = event.id else {
            print("❌ EditEventView - Event ID is nil when trying to link product")
            errorMessage = "Event ID not found"
            return
        }
        
        isLinkingProduct = true
        
        let firestoreService = FirestoreService()
        firestoreService.linkProductToEvent(productId: productId, eventId: eventId) { success, error in
            DispatchQueue.main.async {
                isLinkingProduct = false
                
                if let error = error {
                    errorMessage = "Product created but failed to link to event: \(error.localizedDescription)"
                } else if success {
                    showingSuccess = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    errorMessage = "Product created but failed to link to event"
                }
            }
        }
    }
}

// MARK: - Product Creation Content (Extracted from MerchProductEditView)
struct MerchProductEditViewContent: View {
    let bandId: String
    let onProductCreated: (String) -> Void
    let onError: (String) -> Void
    
    @StateObject private var productViewModel = ProductViewModel()
    @State private var title = ""
    @State private var price = ""
    @State private var selectedSizes: [String] = []
    @State private var inventoryValues: [String: String] = [:]
    @State private var selectedImage: UIImage?
    @State private var isImagePickerPresented = false
    @State private var isCreating = false
    @State private var isUploadingImage = false
    @State private var uploadedImageURL: String?
    
    // Image upload service
    private let imageUploadService = ImageUploadService()
    let availableSizes = ["XS", "S", "M", "L", "XL", "XXL"]
    
    var body: some View {
        Form {
            Section(header: Text("Product Information")) {
                TextField("Product Title", text: $title)
                
                TextField("Price", text: $price)
                    .keyboardType(.decimalPad)
            }
            
            Section(header: Text("Product Image")) {
                if #available(iOS 14.0, *) {
                    PhotoPickerView(selectedImage: $selectedImage, title: "Product Image")
                } else {
                    VStack {
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(10)
                        } else {
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 200)
                                    .cornerRadius(10)
                                
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.system(size: 30))
                                        .foregroundColor(.gray)
                                    
                                    Text("Tap to select image")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .padding(.top, 5)
                                }
                            }
                        }
                        
                        Button(selectedImage == nil ? "Select Image" : "Change Image") {
                            isImagePickerPresented = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.cyan)
                        .padding(.top, 8)
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
            
            Section(header: Text("Available Sizes")) {
                ForEach(availableSizes, id: \.self) { size in
                    Button(action: {
                        if selectedSizes.contains(size) {
                            selectedSizes.removeAll { $0 == size }
                            inventoryValues.removeValue(forKey: size)
                        } else {
                            selectedSizes.append(size)
                            inventoryValues[size] = "0"
                        }
                    }) {
                        HStack {
                            Text(size)
                            Spacer()
                            Image(systemName: selectedSizes.contains(size) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedSizes.contains(size) ? .cyan : .gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            if !selectedSizes.isEmpty {
                Section(header: Text("Inventory")) {
                    ForEach(selectedSizes, id: \.self) { size in
                        HStack {
                            Text(size)
                            
                            Spacer()
                            
                            TextField("Quantity", text: Binding(
                                get: { inventoryValues[size] ?? "0" },
                                set: { inventoryValues[size] = $0 }
                            ))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Create & Add") {
                    createProduct()
                }
                .disabled(title.isEmpty || price.isEmpty || selectedSizes.isEmpty ||
                          isCreating || isUploadingImage)
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $isImagePickerPresented) {
            if #available(iOS 14.0, *) {
                EmptyView()
            } else {
                LegacyImagePickerSheet(selectedImage: $selectedImage, isPresented: $isImagePickerPresented)
            }
        }
        .overlay(
            Group {
                if isCreating {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                        
                        Text(isUploadingImage ? "Uploading image..." : "Creating Product...")
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
    
    private func createProduct() {
        isCreating = true
        
        // If there's an image, upload it first
        if let image = selectedImage {
            isUploadingImage = true
            let tempProductId = UUID().uuidString
            
            imageUploadService.uploadImage(image, type: .product, id: tempProductId) { result in
                DispatchQueue.main.async {
                    self.isUploadingImage = false
                    
                    switch result {
                    case .success(let imageURL):
                        self.uploadedImageURL = imageURL
                        self.createProductWithImage(imageURL: imageURL)
                    case .failure(let error):
                        self.isCreating = false
                        self.onError("Failed to upload image: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // Create product without image (use placeholder)
            createProductWithImage(imageURL: "https://via.placeholder.com/300x300.png?text=Product+Image")
        }
    }
    
    private func createProductWithImage(imageURL: String) {
        // Convert inventory values to integers
        var inventory: [String: Int] = [:]
        for (size, value) in inventoryValues {
            inventory[size] = Int(value) ?? 0
        }
        
        // Create the product using the new model structure
        let newProduct = Product(
            bandId: bandId,
            title: title,
            price: Double(price) ?? 0.0,
            sizes: selectedSizes,
            inventory: inventory,
            imageUrl: imageURL,
            active: true,
            eventIds: [] // Start with no events assigned (will be linked separately)
        )
        
        // Save to Firestore using ProductViewModel
        productViewModel.addProduct(newProduct) { success in
            DispatchQueue.main.async {
                self.isCreating = false
                
                if success {
                    // Get the created product ID from the ProductViewModel
                    if let createdProduct = self.productViewModel.products.last {
                        self.onProductCreated(createdProduct.id ?? "")
                    } else {
                        self.onError("Product created but ID not found")
                    }
                } else {
                    self.onError("Failed to create product")
                    
                    // Clean up uploaded image if product creation failed
                    if let imageURL = self.uploadedImageURL {
                        self.imageUploadService.deleteImage(at: imageURL) { _ in }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Image Components (keeping existing implementations)

struct ImageDisplayCard: View {
    let image: UIImage
    let isLoading: Bool
    let loadingText: String?
    let onRemove: () -> Void
    
    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .cornerRadius(DesignSystem.CornerRadius.md)
                .clipped()
            
            if isLoading {
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .cornerRadius(DesignSystem.CornerRadius.md)
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    if let loadingText = loadingText {
                        Text(loadingText)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(.white)
                    }
                }
            }
            
            if !isLoading {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    Spacer()
                }
                .padding(DesignSystem.Spacing.md)
            }
        }
    }
}

struct ImageLoadingCard: View {
    let message: String
    
    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.surfaceBackground)
            .frame(height: 200)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .overlay(
                VStack(spacing: DesignSystem.Spacing.md) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                    Text(message)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            )
    }
}

struct ImageErrorCard: View {
    let error: String
    let onRetry: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.surfaceBackground)
            .frame(height: 200)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .overlay(
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(DesignSystem.Colors.warning)
                        .font(.title2)
                    
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Failed to load image")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        Text(error)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Button("Retry", action: onRetry)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(DesignSystem.Colors.primary)
                        
                        Button("Remove", action: onRemove)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(DesignSystem.Colors.danger)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            )
    }
}

struct ImagePlaceholderCard: View {
    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.surfaceBackground)
            .frame(height: 200)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .overlay(
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("No Image Set")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        Text("Choose an image to make your event more appealing")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(DesignSystem.Colors.border, style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
    }
}

// MARK: - Location Components (keeping existing implementations)

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
            VStack(spacing: 0) {
                // Search bar
                VStack(spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Search Location")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        TextField("Search for venue or address", text: $searchText)
                            .font(DesignSystem.Typography.body)
                            .padding(DesignSystem.Spacing.inputPadding)
                            .background(DesignSystem.Colors.inputBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
                            )
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                            .onSubmit {
                                searchForLocation()
                            }
                    }
                    
                    if !searchText.isEmpty {
                        Button(action: searchForLocation) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Search")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(DesignSystem.Spacing.lg)
                            .background(DesignSystem.Colors.primary)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(DesignSystem.Spacing.screenPadding)
                .background(DesignSystem.Colors.cardBackground)
                
                // Map
                Map(coordinateRegion: $region,
                    annotationItems: selectedLocation.map { [EditEventLocationAnnotation(coordinate: $0)] } ?? []
                ) { pin in
                    MapAnnotation(coordinate: pin.coordinate) {
                        VStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(DesignSystem.Colors.primary)
                                .font(.title)
                            Circle()
                                .stroke(DesignSystem.Colors.primary.opacity(0.3), lineWidth: 2)
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
                        Button {
                            selectLocationFromSearch(item)
                        } label: {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text(item.name ?? "Unknown")
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                Text(item.placemark.title ?? "")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(selectedLocation == nil)
                    .fontWeight(.semibold)
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

// MARK: - Add Products Views (keeping existing implementations)

struct EditEventAddProductsView: View {
    let event: Event
    @ObservedObject var viewModel: EventProductsViewModel
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedProducts = Set<String>()
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    VStack {
                        ProgressView("Loading products...")
                            .padding()
                    }
                } else if viewModel.availableProducts.isEmpty {
                    VStack(spacing: 16) {
                        DSEmptyState(
                            icon: "tray",
                            title: "No Available Products",
                            subtitle: "All your products are already added to this event or you haven't created any products yet."
                        )
                        
                        HStack(spacing: 12) {
                            Button("Refresh") {
                                if let uid = authViewModel.user?.uid, let eid = event.id {
                                    viewModel.fetchMerchantProducts(merchantId: uid, excludingEventId: eid)
                                }
                            }
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            
                            Button("Debug") {
                                debugCheckProducts()
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                } else {
                    List {
                        Section("Available Products") {
                            ForEach(viewModel.availableProducts) { product in
                                EditEventSelectableProductRow(
                                    product: product,
                                    isSelected: selectedProducts.contains(product.id ?? "")
                                ) { isSel in
                                    if let id = product.id {
                                        if isSel {
                                            selectedProducts.insert(id)
                                        } else {
                                            selectedProducts.remove(id)
                                        }
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
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Selected") {
                        addSelectedProducts()
                    }
                    .disabled(selectedProducts.isEmpty || isLoading)
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                            .scaleEffect(1.5)
                        Text("Adding Products…")
                            .font(DesignSystem.Typography.subheadline)
                            .padding(.top)
                    }
                    .padding()
                    .background(DesignSystem.Colors.cardBackground)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }
            }
            .onAppear {
                print("🔍 EditEventView - Add Products onAppear triggered")
                print("🔍 EditEventView - User ID: \(authViewModel.user?.uid ?? "nil")")
                print("🔍 EditEventView - User email: \(authViewModel.user?.email ?? "nil")")
                print("🔍 EditEventView - Event ID: \(event.id ?? "nil")")
                print("🔍 EditEventView - Event name: \(event.name)")
                print("🔍 EditEventView - Current available products count: \(viewModel.availableProducts.count)")
                print("🔍 EditEventView - Current event products count: \(viewModel.products.count)")
                
                if let uid = authViewModel.user?.uid, let eid = event.id {
                    print("🔍 EditEventView - Calling fetchMerchantProducts for merchant: \(uid), event: \(eid)")
                    viewModel.fetchMerchantProducts(merchantId: uid, excludingEventId: eid)
                } else {
                    print("❌ EditEventView - Missing required data - userId: \(authViewModel.user?.uid ?? "nil"), eventId: \(event.id ?? "nil")")
                }
            }
        }
    }
    
    private func debugCheckProducts() {
        guard let uid = authViewModel.user?.uid else {
            print("❌ No user ID available")
            return
        }
        
        print("🔍 DEBUG: Starting product check for user \(uid)")
        
        let db = Firestore.firestore()
        
        // First, check all products for this user (without any filters)
        db.collection("products")
            .whereField("band_id", isEqualTo: uid)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ DEBUG: Error fetching products: \(error.localizedDescription)")
                    return
                }
                
                print("🔍 DEBUG: Found \(snapshot?.documents.count ?? 0) total products for user \(uid)")
                
                snapshot?.documents.forEach { doc in
                    let data = doc.data()
                    print("🔍 DEBUG: Product \(doc.documentID):")
                    print("   - title: \(data["title"] as? String ?? "nil")")
                    print("   - band_id: \(data["band_id"] as? String ?? "nil")")
                    print("   - active: \(data["active"] as? Bool ?? false)")
                    print("   - event_ids: \(data["event_ids"] as? [String] ?? [])")
                }
                
                // Now check active products
                db.collection("products")
                    .whereField("band_id", isEqualTo: uid)
                    .whereField("active", isEqualTo: true)
                    .getDocuments { snapshot2, error2 in
                        if let error2 = error2 {
                            print("❌ DEBUG: Error fetching active products: \(error2.localizedDescription)")
                            return
                        }
                        
                        print("🔍 DEBUG: Found \(snapshot2?.documents.count ?? 0) active products for user \(uid)")
                        
                        // Check if this event exists
                        if let eventId = self.event.id {
                            print("🔍 DEBUG: Checking event \(eventId)")
                            db.collection("events").document(eventId).getDocument { eventDoc, eventError in
                                if let eventError = eventError {
                                    print("❌ DEBUG: Error fetching event: \(eventError.localizedDescription)")
                                    return
                                }
                                
                                if let eventData = eventDoc?.data() {
                                    print("🔍 DEBUG: Event data: \(eventData)")
                                } else {
                                    print("❌ DEBUG: Event not found")
                                }
                            }
                        }
                    }
            }
    }
    
    private func addSelectedProducts() {
        guard let eid = event.id else { return }
        isLoading = true
        
        let productIds = Array(selectedProducts)
        print("🔍 EditEventView - Adding \(productIds.count) products to event")
        
        viewModel.addProductsToEvent(productIds: productIds, eventId: eid) { success in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    print("✅ EditEventView - Successfully added all products")
                    self.presentationMode.wrappedValue.dismiss()
                } else {
                    print("❌ EditEventView - Failed to add products")
                    // Show error state - optionally keep dialog open to retry
                }
            }
        }
    }
}

// MARK: - Product Row for EditEvent with Real Images
struct EditEventProductRow: View {
    let product: Product
    let onRemove: () -> Void
    let onInventoryUpdate: ((Product, [String: Int]) -> Void)?
    @State private var loadedProductImage: UIImage?
    @State private var isLoadingProductImage = false
    @State private var showingInventoryEdit = false
    @State private var editedInventory: [String: Int] = [:]
    
    init(product: Product, onRemove: @escaping () -> Void, onInventoryUpdate: ((Product, [String: Int]) -> Void)? = nil) {
        self.product = product
        self.onRemove = onRemove
        self.onInventoryUpdate = onInventoryUpdate
        self._editedInventory = State(initialValue: product.inventory)
    }

    var body: some View {
        DSCard(padding: DesignSystem.Spacing.lg) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Product Image with Safe Firebase Storage Loading
                Group {
                    if let loadedImage = loadedProductImage {
                        Image(uiImage: loadedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                            .clipped()
                    } else if isLoadingProductImage {
                        Rectangle()
                            .fill(DesignSystem.Colors.surfaceBackground)
                            .frame(width: 50, height: 50)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                            )
                    } else {
                        Rectangle()
                            .fill(DesignSystem.Colors.success.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                            .overlay(
                                Image(systemName: "tshirt")
                                    .foregroundColor(DesignSystem.Colors.success)
                            )
                    }
                }
                
                // Product details
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text(product.title)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(1)
                    
                    HStack {
                        Text("$\(String(format: "%.2f", product.price))")
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .fontWeight(.semibold)
                        
                        Text("•")
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        
                        Button(action: {
                            showingInventoryEdit = true
                        }) {
                            HStack(spacing: 4) {
                                Text("\(product.inventory.values.reduce(0, +)) in stock")
                                    .font(DesignSystem.Typography.footnote)
                                    .foregroundColor(product.inventory.values.reduce(0, +) > 0 ? DesignSystem.Colors.success : DesignSystem.Colors.danger)
                                
                                Image(systemName: "pencil.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Text(product.sizes.joined(separator: ", "))
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Status and actions
                HStack(spacing: DesignSystem.Spacing.md) {
                    DSStatusBadge(
                        text: product.active ? "Active" : "Off",
                        status: product.active ? .active : .inactive
                    )
                    
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(DesignSystem.Colors.danger)
                            .font(.system(size: 18))
                    }
                }
            }
        }
        .onAppear {
            loadProductImage()
        }
        .onChange(of: product.imageUrl) { _ in
            loadProductImage()
        }
        .sheet(isPresented: $showingInventoryEdit) {
            SimpleInventoryEditView(
                product: product,
                inventory: $editedInventory,
                onSave: { newInventory in
                    onInventoryUpdate?(product, newInventory)
                }
            )
        }
    }
    
    private func loadProductImage() {
        guard !product.imageUrl.isEmpty else {
            return
        }
        
        // If we already have a loaded image for this URL, don't reload
        if loadedProductImage != nil {
            return
        }
        
        isLoadingProductImage = true
        
        // Safe Firebase Storage loading with URL type detection
        if product.imageUrl.contains("firebasestorage.googleapis.com") {
            // Use Firebase Storage reference for Firebase URLs
            do {
                let storageRef = Storage.storage().reference(forURL: product.imageUrl)
                storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        self.isLoadingProductImage = false
                        if let error = error {
                            print("Error loading product image: \(error.localizedDescription)")
                        } else if let data = data, let image = UIImage(data: data) {
                            self.loadedProductImage = image
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
                    if let error = error {
                        print("Error loading product image: \(error.localizedDescription)")
                    } else if let data = data, let image = UIImage(data: data) {
                        self.loadedProductImage = image
                    }
                }
            }.resume()
        }
    }
}

struct EditEventSelectableProductRow: View {
    let product: Product
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    @State private var loadedProductImage: UIImage?
    @State private var isLoadingProductImage = false

    var body: some View {
        Button {
            onSelectionChanged(!isSelected)
        } label: {
            HStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.secondaryText)
                    .font(.title3)

                // Product Image with Real Image Loading
                Group {
                    if let loadedImage = loadedProductImage {
                        Image(uiImage: loadedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                            .clipped()
                    } else if isLoadingProductImage {
                        Rectangle()
                            .fill(DesignSystem.Colors.surfaceBackground)
                            .frame(width: 40, height: 40)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                            )
                    } else {
                        Rectangle()
                            .fill(DesignSystem.Colors.success.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                            .overlay(
                                Image(systemName: "tshirt")
                                    .foregroundColor(DesignSystem.Colors.success)
                            )
                    }
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(product.title)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    Text("$\(String(format: "%.2f", product.price))")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .fontWeight(.semibold)
                }

                Spacer()
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadProductImage()
        }
        .onChange(of: product.imageUrl) { _ in
            loadProductImage()
        }
    }
    
    private func loadProductImage() {
        guard !product.imageUrl.isEmpty else {
            return
        }
        
        // If we already have a loaded image for this URL, don't reload
        if loadedProductImage != nil {
            return
        }
        
        isLoadingProductImage = true
        
        // Safe Firebase Storage loading with URL type detection
        if product.imageUrl.contains("firebasestorage.googleapis.com") {
            // Use Firebase Storage reference for Firebase URLs
            do {
                let storageRef = Storage.storage().reference(forURL: product.imageUrl)
                storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        self.isLoadingProductImage = false
                        if let error = error {
                            print("Error loading product image: \(error.localizedDescription)")
                        } else if let data = data, let image = UIImage(data: data) {
                            self.loadedProductImage = image
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
                    if let error = error {
                        print("Error loading product image: \(error.localizedDescription)")
                    } else if let data = data, let image = UIImage(data: data) {
                        self.loadedProductImage = image
                    }
                }
            }.resume()
        }
    }
}
