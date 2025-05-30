// Improved EditEventView.swift with better form design and image handling
// Fixes: form field visibility, image picker UX, date picker alignment, and button functionality

import SwiftUI
import MapKit
import CoreLocation
import PhotosUI
import FirebaseStorage
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
                .toolbar(.hidden, for: .tabBar)
                
                // Loading overlay
                DSLoadingOverlay(
                    message: loadingMessage,
                    isVisible: vm.isLoading || isUploadingImage || isDeleting
                )
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .sheet(isPresented: $showingCreateProduct) {
                EditEventCreateProductView()
            }
            .alert("Event Updated!", isPresented: $showingSuccess) {
                Button("OK") { presentationMode.wrappedValue.dismiss() }
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
                setupInitialState()
                loadEventProducts()
                loadEventImageIfNeeded()
            }
        }
    }
    
    // MARK: - Event Details View
    @ViewBuilder
    private func eventDetailsView() -> some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.sectionSpacing) {
                
                // Basic Information - FIXED with proper form styling
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
                
                // Event Image - IMPROVED with better remove functionality
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
                        
                        // Image Action Buttons - FIXED functionality
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
                            
                            if hasEventImage {
                                // Remove this button since we have the X on the image
                            }
                        }
                    }
                }
                
                // Schedule - FIXED alignment and styling
                DSCard {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Event Schedule")
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            Text("When your event takes place")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // Start Date
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Start Date & Time")
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                
                                DatePicker(
                                    "",
                                    selection: $vm.event.startDate,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // End Date
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("End Date & Time")
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                
                                DatePicker(
                                    "",
                                    selection: $vm.event.endDate,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .onChange(of: vm.event.startDate) { newStart in
                                    if vm.event.endDate <= newStart {
                                        vm.event.endDate = newStart.addingTimeInterval(3600)
                                    }
                                }
                            }
                            
                            if formErrors["date"] != nil {
                                Text("End date must be after start date")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(DesignSystem.Colors.danger)
                            }
                        }
                    }
                }
                
                // Location & Geofencing
                DSCard {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Location & Geofencing")
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            Text("Set where fans can access your merchandise")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // Address Display
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Event Address")
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                
                                Button(action: { showingLocationPicker = true }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                            Text(address.isEmpty ? "No location set" : address)
                                                .font(DesignSystem.Typography.body)
                                                .foregroundColor(address.isEmpty ? DesignSystem.Colors.secondaryText : DesignSystem.Colors.primaryText)
                                                .multilineTextAlignment(.leading)
                                            
                                            if !address.isEmpty {
                                                Text("Tap to change location")
                                                    .font(DesignSystem.Typography.caption1)
                                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "location")
                                            .foregroundColor(DesignSystem.Colors.primary)
                                    }
                                    .padding(DesignSystem.Spacing.lg)
                                    .background(DesignSystem.Colors.inputBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                    )
                                    .cornerRadius(DesignSystem.CornerRadius.sm)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Manual address input
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Or enter manually")
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                
                                TextField("Type address here", text: $address)
                                    .font(DesignSystem.Typography.body)
                                    .padding(DesignSystem.Spacing.inputPadding)
                                    .background(DesignSystem.Colors.inputBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                            .stroke(Color(.systemGray3), lineWidth: 1.5)
                                    )
                                    .cornerRadius(DesignSystem.CornerRadius.sm)
                                    .onSubmit {
                                        geocodeAddress()
                                    }
                            }
                            
                            // Geofence settings
                            if selectedLocation != nil {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                            Text("Geofence Radius")
                                                .font(DesignSystem.Typography.subheadline)
                                                .foregroundColor(DesignSystem.Colors.primaryText)
                                            Text("Fans within this distance can access your store")
                                                .font(DesignSystem.Typography.caption1)
                                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(Int(vm.event.geofenceRadius)) meters")
                                            .font(DesignSystem.Typography.subheadline)
                                            .foregroundColor(DesignSystem.Colors.primary)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    Slider(value: $vm.event.geofenceRadius, in: 50...500, step: 10)
                                }
                                
                                // Mini map preview
                                if let location = selectedLocation {
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                        Text("Location Preview")
                                            .font(DesignSystem.Typography.subheadline)
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                        
                                        Map(
                                            coordinateRegion: .constant(
                                                MKCoordinateRegion(
                                                    center: location,
                                                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                                                )
                                            ),
                                            annotationItems: [EditEventLocationAnnotation(coordinate: location)]
                                        ) { pin in
                                            MapAnnotation(coordinate: pin.coordinate) {
                                                VStack {
                                                    Circle()
                                                        .fill(DesignSystem.Colors.primary)
                                                        .frame(width: 20, height: 20)
                                                    Circle()
                                                        .stroke(DesignSystem.Colors.primary.opacity(0.3), lineWidth: 2)
                                                        .frame(width: 40, height: 40)
                                                }
                                            }
                                        }
                                        .frame(height: 150)
                                        .cornerRadius(DesignSystem.CornerRadius.md)
                                        .disabled(true)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Event Preview
                if !vm.event.name.isEmpty && !vm.event.venueName.isEmpty {
                    DSCard {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Event Preview")
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                Text("How your event will appear to fans")
                                    .font(DesignSystem.Typography.caption1)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                            
                            DSEventPreviewCard(
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
                
                // Danger Zone
                DSCard(style: .outlined) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Delete Event")
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(DesignSystem.Colors.danger)
                            Text("Permanently delete this event and remove all associated products. This action cannot be undone.")
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        
                        Button(action: { showingDeleteAlert = true }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Event")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(DesignSystem.Spacing.lg)
                            .background(DesignSystem.Colors.danger)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                        }
                        .disabled(isDeleting || vm.isLoading || isUploadingImage)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(DesignSystem.Colors.danger.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(DesignSystem.Spacing.screenPadding)
        }
    }
    
    // MARK: - Products View (same as before)
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
                                    DSProductRow(
                                        title: product.title,
                                        price: "$\(String(format: "%.2f", product.price))",
                                        stock: product.inventory.values.reduce(0, +),
                                        sizes: product.sizes,
                                        isActive: product.active,
                                        image: nil,
                                        onRemove: { removeProduct(product) }
                                    )
                                }
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
    
    // MARK: - Image Components
    
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
    
    // MARK: - Computed Properties
    
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
    
    // MARK: - Helper Methods
    
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
    
    // MARK: - Image Handling
    
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
    
    // MARK: - Location Handling
    
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

// MARK: - Supporting Components

struct DSEventPreviewCard: View {
    let eventName: String
    let venueName: String
    let startDate: Date
    let endDate: Date
    let address: String
    let previewImage: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Event image
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                    .clipped()
            } else {
                Rectangle()
                    .fill(DesignSystem.Colors.primary.opacity(0.2))
                    .frame(height: 120)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                    .overlay(
                        Image(systemName: "calendar")
                            .foregroundColor(DesignSystem.Colors.primary)
                            .font(.system(size: 32))
                    )
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(eventName)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Text(venueName)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.primary)
                
                if !address.isEmpty {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "location")
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .font(.caption)
                        Text(address)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineLimit(2)
                    }
                }
                
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "calendar")
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .font(.caption)
                    Text(formatDateRange(start: startDate, end: endDate))
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surfaceBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
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

// MARK: - Location Components (same as before but keeping for completeness)

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

// MARK: - Product Management Views

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
                if viewModel.availableProducts.isEmpty && !viewModel.isLoading {
                    DSEmptyState(
                        icon: "tray",
                        title: "No Available Products",
                        subtitle: "All your products are already added to this event or you haven't created any products yet."
                    )
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
                if let uid = authViewModel.user?.uid, let eid = event.id {
                    viewModel.fetchMerchantProducts(merchantId: uid, excludingEventId: eid)
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
            if !failed {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct EditEventSelectableProductRow: View {
    let product: Product
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void

    var body: some View {
        Button {
            onSelectionChanged(!isSelected)
        } label: {
            HStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.secondaryText)
                    .font(.title3)

                // Product image placeholder
                Rectangle()
                    .fill(DesignSystem.Colors.success.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                    .overlay(
                        Image(systemName: "tshirt")
                            .foregroundColor(DesignSystem.Colors.success)
                    )

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
    }
}

struct EditEventCreateProductView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            DSEmptyState(
                icon: "plus.square.dashed",
                title: "Create New Product",
                subtitle: "This will take you to the product creation flow. After creating your product, you can add it to this event.",
                primaryActionTitle: "Continue to Product Creation",
                primaryAction: {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .navigationTitle("Create Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
