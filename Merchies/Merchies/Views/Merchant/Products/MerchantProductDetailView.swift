// Enhanced MerchantProductDetailView.swift - COMPLETE UPDATED FILE
import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage
import Foundation

struct MerchantProductDetailView: View {
    @State private var product: Product  // Make product mutable
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isEditing = false
    @State private var inventory: [String: String] = [:]
    @State private var isActive: Bool = true
    @State private var editedPrice: String = ""
    @State private var editedTitle: String = ""
    @State private var editedSizes: [String] = []
    @State private var newSizeText: String = ""
    @State private var showingAddSize = false
    @State private var showingSizeSelector = false
    @State private var isUpdating = false
    @State private var showingDeleteAlert = false
    @State private var showingEventsList = false
    @State private var associatedEvents: [Event] = []
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    // Image editing states
    @State private var selectedImage: UIImage?
    @State private var pickedItem: PhotosPickerItem?
    @State private var isUploadingImage = false
    @State private var uploadedImageURL: String?
    @State private var loadedProductImage: UIImage?
    @State private var isLoadingProductImage = false
    @State private var imageLoadError: String?
    
    // Image upload service
    private let imageUploadService = ImageUploadService()
    
    // Custom initializer to set the initial product
    init(product: Product) {
        self._product = State(initialValue: product)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Product Image and Basic Info - ENHANCED
                    ProductImageSection()
                    
                    // Product Details Card - ENHANCED
                    ProductDetailsCard()
                    
                    // Inventory Management Card
                    InventoryCard()
                    
                    // Events Association Card
                    EventsCard()
                    
                    // Analytics Card (if product has sales)
                    if !product.eventIds.isEmpty {
                        AnalyticsCard()
                    }
                    
                    // Action Buttons
                    ActionButtonsSection()
                }
                .padding()
            }
            .navigationTitle("Product Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(isUpdating || isUploadingImage)
                        .fontWeight(.semibold)
                    } else {
                        Button("Edit") {
                            startEditing()
                        }
                    }
                }
            }
            .alert(item: Binding<AlertItem?>(
                get: {
                    if let error = errorMessage {
                        return AlertItem(title: "Error", message: error)
                    } else if let success = successMessage {
                        return AlertItem(title: "Success", message: success)
                    }
                    return nil
                },
                set: { _ in
                    errorMessage = nil
                    successMessage = nil
                }
            )) { alertItem in
                Alert(
                    title: Text(alertItem.title),
                    message: Text(alertItem.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("Delete Product", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteProduct()
                }
            } message: {
                Text("Are you sure you want to delete this product? This action cannot be undone and will remove it from all events.")
            }
            .sheet(isPresented: $showingEventsList) {
                AssociatedEventsView(eventIds: product.eventIds)
            }
            .onAppear {
                setupInitialValues()
                loadAssociatedEvents()
                loadProductImageIfNeeded()
            }
            .overlay(loadingOverlay)
        }
    }
    
    // MARK: - Enhanced Product Image Section
    @ViewBuilder
    private func ProductImageSection() -> some View {
        VStack(spacing: 16) {
            // Image Display Area - ENHANCED
            Group {
                if let image = selectedImage {
                    // New selected image
                    ImageDisplayCard(
                        image: image,
                        isLoading: isUploadingImage,
                        loadingText: "Uploading new image...",
                        showRemoveButton: isEditing,
                        onRemove: removeCurrentImage
                    )
                } else if let existingImage = loadedProductImage {
                    // Existing image loaded from Firebase
                    ImageDisplayCard(
                        image: existingImage,
                        isLoading: false,
                        loadingText: nil,
                        showRemoveButton: isEditing,
                        onRemove: removeCurrentImage
                    )
                } else if isLoadingProductImage {
                    // Loading existing image
                    ImageLoadingCard(message: "Loading product image...")
                } else if let error = imageLoadError {
                    // Error loading image
                    ImageErrorCard(
                        error: error,
                        onRetry: loadProductImageIfNeeded,
                        onRemove: isEditing ? removeCurrentImage : nil
                    )
                } else {
                    // No image placeholder
                    ImagePlaceholderCard(showChangeButton: isEditing)
                }
            }
            .frame(height: 250)
            
            // Image Action Buttons - ENHANCED
            if isEditing {
                VStack(spacing: 12) {
                    PhotosPicker(
                        selection: $pickedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Image(systemName: "photo")
                            Text(hasProductImage ? "Change Image" : "Add Image")
                                .fontWeight(.medium)
                            if isUploadingImage {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .disabled(isUploadingImage)
                    .onChange(of: pickedItem) { newItem in
                        handleImageSelection(newItem)
                    }
                }
            }
            
            // Product Title and Price - ENHANCED
            VStack(spacing: 12) {
                if isEditing {
                    // Editable title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Product Title")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TextField("Product title", text: $editedTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                } else {
                    Text(product.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                
                if isEditing {
                    // Editable price
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Price")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("$")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.cyan)
                            
                            TextField("0.00", text: $editedPrice)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.cyan)
                                .keyboardType(.decimalPad)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                } else {
                    Text("$\(String(format: "%.2f", product.price))")
                        .font(.title3)
                        .foregroundColor(.cyan)
                        .fontWeight(.semibold)
                }
                
                // Status toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Product Status")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text(isActive ? "Visible to customers" : "Hidden from customers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isEditing {
                        Toggle("", isOn: $isActive)
                            .labelsHidden()
                    } else {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(isActive ? Color.green : Color.orange)
                                .frame(width: 12, height: 12)
                            
                            Text(isActive ? "Active" : "Inactive")
                                .font(.subheadline)
                                .foregroundColor(isActive ? .green : .orange)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Enhanced Product Details Card
    @ViewBuilder
    private func ProductDetailsCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Product Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                DetailRow(label: "Product ID", value: product.id?.suffix(8).description ?? "Unknown")
                DetailRow(label: "Available Sizes", value: product.sizes.joined(separator: ", "))
                DetailRow(label: "Total Stock", value: "\(product.totalInventory)")
                DetailRow(label: "Associated Events", value: "\(product.eventIds.count)")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Enhanced Inventory Card with Size Management
    @ViewBuilder
    private func InventoryCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Inventory & Sizes")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !isEditing {
                    Button("Quick Edit") {
                        startEditing()
                    }
                    .font(.caption)
                    .foregroundColor(.cyan)
                }
            }
            
            if isEditing {
                // Size Management Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Available Sizes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button("Add Sizes") {
                            showingSizeSelector = true
                        }
                        .font(.caption)
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.1))
                        .cornerRadius(4)
                    }
                    
                    // Editable Sizes List
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(editedSizes, id: \.self) { size in
                            HStack {
                                Text(size)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button(action: {
                                    removeSize(size)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
            
            // Inventory quantities
            VStack(alignment: .leading, spacing: 8) {
                Text("Stock Quantities")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                let sizesToShow = isEditing ? editedSizes : product.sizes
                
                ForEach(sizesToShow, id: \.self) { size in
                    HStack {
                        Text(size)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 40, alignment: .leading)
                        
                        Spacer()
                        
                        if isEditing {
                            HStack(spacing: 8) {
                                // Minus button
                                Button(action: {
                                    decreaseInventory(for: size)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title3)
                                }
                                .disabled((Int(inventory[size] ?? "0") ?? 0) <= 0)
                                
                                // Quantity display/input
                                TextField("Qty", text: Binding(
                                    get: { inventory[size] ?? "0" },
                                    set: { inventory[size] = $0 }
                                ))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 60)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemBackground))
                                .foregroundColor(.primary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(.systemGray3), lineWidth: 1)
                                )
                                .cornerRadius(6)
                                
                                // Plus button
                                Button(action: {
                                    increaseInventory(for: size)
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title3)
                                }
                            }
                        } else {
                            let quantity = product.inventory[size] ?? 0
                            HStack {
                                Text("\(quantity)")
                                    .font(.subheadline)
                                    .foregroundColor(quantity > 0 ? .primary : .red)
                                
                                if quantity <= 5 && quantity > 0 {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                } else if quantity == 0 {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            if !isEditing {
                HStack {
                    Spacer()
                    Text("Total: \(product.totalInventory) items")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            } else {
                // Show total for edited inventory
                let totalEdited = editedSizes.reduce(0) { total, size in
                    total + (Int(inventory[size] ?? "0") ?? 0)
                }
                HStack {
                    Spacer()
                    Text("Total: \(totalEdited) items")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showingSizeSelector) {
            SizeSelectorView(
                currentSizes: editedSizes,
                onSizesSelected: { selectedSizes in
                    addSelectedSizes(selectedSizes)
                }
            )
        }
    }
    
    // MARK: - Events Card
    @ViewBuilder
    private func EventsCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Associated Events")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !product.eventIds.isEmpty {
                    Button("View All") {
                        showingEventsList = true
                    }
                    .font(.caption)
                    .foregroundColor(.cyan)
                }
            }
            
            if product.eventIds.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                    
                    Text("Not added to any events")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Add this product to events so fans can discover and purchase it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(associatedEvents.prefix(3), id: \.id) { event in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                Text(event.venueName)
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Circle()
                                .fill(event.isActive ? Color.green : (event.isUpcoming ? Color.orange : Color.gray))
                                .frame(width: 8, height: 8)
                        }
                        .padding(.vertical, 2)
                    }
                    
                    if product.eventIds.count > 3 {
                        Text("+ \(product.eventIds.count - 3) more events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Analytics Card
    @ViewBuilder
    private func AnalyticsCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                VStack {
                    Text("0")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                    Text("Total Sold")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack {
                    Text("$0.00")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                    Text("Revenue")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack {
                    Text("0")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                    Text("Pending")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            
            Text("Analytics data will be available once customers start purchasing this product.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons Section
    @ViewBuilder
    private func ActionButtonsSection() -> some View {
        VStack(spacing: 12) {
            if isEditing {
                HStack(spacing: 12) {
                    Button("Cancel") {
                        cancelEditing()
                    }
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                    
                    Button("Save Changes") {
                        saveChanges()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.cyan)
                    .cornerRadius(10)
                    .disabled(isUpdating || isUploadingImage)
                }
            } else {
                Button("Delete Product") {
                    showingDeleteAlert = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(10)
            }
        }
        .padding(.top)
    }
    
    // MARK: - Image Display Components
    
    struct ImageDisplayCard: View {
        let image: UIImage
        let isLoading: Bool
        let loadingText: String?
        let showRemoveButton: Bool
        let onRemove: () -> Void
        
        var body: some View {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(12)
                    .clipped()
                
                if isLoading {
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .cornerRadius(12)
                    
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        if let loadingText = loadingText {
                            Text(loadingText)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                if showRemoveButton && !isLoading {
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
                    .padding(12)
                }
            }
        }
    }
    
    struct ImageLoadingCard: View {
        let message: String
        
        var body: some View {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(12)
                .overlay(
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
        }
    }
    
    struct ImageErrorCard: View {
        let error: String
        let onRetry: () -> Void
        let onRemove: (() -> Void)?
        
        var body: some View {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(12)
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.title2)
                        
                        VStack(spacing: 4) {
                            Text("Failed to load image")
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        
                        HStack(spacing: 12) {
                            Button("Retry", action: onRetry)
                                .font(.caption)
                                .foregroundColor(.cyan)
                            
                            if let onRemove = onRemove {
                                Button("Remove", action: onRemove)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(16)
                )
        }
    }
    
    struct ImagePlaceholderCard: View {
        let showChangeButton: Bool
        
        var body: some View {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(12)
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 4) {
                            Text(showChangeButton ? "Add Product Image" : "No Image")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Text(showChangeButton ? "Tap 'Add Image' below to select" : "Product has no image")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
        }
    }
    
    // MARK: - Loading Overlay
    @ViewBuilder
    private var loadingOverlay: some View {
        if isUpdating || isUploadingImage {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                
                Text(loadingMessage)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 8)
        }
    }
    
    // MARK: - Computed Properties
    
    private var loadingMessage: String {
        if isUploadingImage { return "Uploading Image..." }
        if isUpdating { return "Updating Product..." }
        return "Processing..."
    }
    
    private var hasProductImage: Bool {
        selectedImage != nil || loadedProductImage != nil || (!product.imageUrl.isEmpty && !product.imageUrl.contains("placeholder"))
    }
    
    private var isFormValid: Bool {
        !editedTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !editedPrice.isEmpty &&
        Double(editedPrice) != nil &&
        Double(editedPrice)! >= 0
    }
    
    // MARK: - Inventory Management Functions
    
    private func increaseInventory(for size: String) {
        let currentValue = Int(inventory[size] ?? "0") ?? 0
        inventory[size] = "\(currentValue + 1)"
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func decreaseInventory(for size: String) {
        let currentValue = Int(inventory[size] ?? "0") ?? 0
        let newValue = max(0, currentValue - 1) // Don't go below 0
        inventory[size] = "\(newValue)"
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // MARK: - Size Management Functions
    
    private func addSelectedSizes(_ selectedSizes: [String]) {
        for size in selectedSizes {
            // Only add sizes that aren't already present
            if !editedSizes.contains(size) {
                editedSizes.append(size)
                // Initialize inventory for the new size
                inventory[size] = "0"
            }
        }
        
        // Sort sizes in a logical order
        editedSizes = sortSizes(editedSizes)
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func sortSizes(_ sizes: [String]) -> [String] {
        let sizeOrder = ["XXS", "XS", "S", "M", "L", "XL", "XXL", "XXXL", "3XL", "4XL", "5XL"]
        
        return sizes.sorted { size1, size2 in
            let index1 = sizeOrder.firstIndex(of: size1) ?? Int.max
            let index2 = sizeOrder.firstIndex(of: size2) ?? Int.max
            return index1 < index2
        }
    }
    
    private func removeSize(_ size: String) {
        // Don't allow removing the last size
        guard editedSizes.count > 1 else {
            errorMessage = "Product must have at least one size"
            return
        }
        
        // Remove the size from the edited sizes array
        editedSizes.removeAll { $0 == size }
        
        // Remove the inventory entry for this size
        inventory.removeValue(forKey: size)
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // MARK: - Helper Functions
    
    private func setupInitialValues() {
        isActive = product.active
        editedTitle = product.title
        editedPrice = String(format: "%.2f", product.price)
        editedSizes = product.sizes
        
        // Initialize inventory values for all sizes
        inventory.removeAll()
        for size in product.sizes {
            inventory[size] = "\(product.inventory[size] ?? 0)"
        }
    }
    
    private func startEditing() {
        isEditing = true
        setupInitialValues()
    }
    
    private func cancelEditing() {
        isEditing = false
        setupInitialValues()
        selectedImage = nil
        uploadedImageURL = nil
        pickedItem = nil
        imageLoadError = nil
        newSizeText = ""
        // Reload the current product image
        loadProductImageIfNeeded()
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
                        loadedProductImage = nil
                        imageLoadError = nil
                    }
                    await uploadImageData(data)
                }
            } catch {
                await MainActor.run {
                    isUploadingImage = false
                    errorMessage = "Failed to load image: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func uploadImageData(_ data: Data) async {
        await withCheckedContinuation { continuation in
            let imageID = product.id ?? UUID().uuidString
            let ref = Storage.storage().reference().child("products/\(imageID)_\(UUID().uuidString).jpg")
            
            ref.putData(data, metadata: nil) { _, error in
                DispatchQueue.main.async {
                    self.isUploadingImage = false
                    if let error = error {
                        self.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                    } else {
                        ref.downloadURL { url, _ in
                            if let url = url {
                                self.uploadedImageURL = url.absoluteString
                                print("✅ Image uploaded: \(url)")
                            }
                        }
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    private func loadProductImageIfNeeded() {
        // Clear previous state
        loadedProductImage = nil
        isLoadingProductImage = false
        imageLoadError = nil
        
        guard selectedImage == nil,
              !product.imageUrl.isEmpty,
              !product.imageUrl.contains("placeholder") else { return }
        
        isLoadingProductImage = true
        
        if product.imageUrl.contains("firebasestorage.googleapis.com") {
            loadFirebaseImage(from: product.imageUrl)
        } else {
            loadImageFromURL(product.imageUrl)
        }
    }
    
    private func loadFirebaseImage(from urlString: String) {
        do {
            let storageRef = Storage.storage().reference(forURL: urlString)
            storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                DispatchQueue.main.async {
                    self.isLoadingProductImage = false
                    if let error = error {
                        self.imageLoadError = error.localizedDescription
                    } else if let data = data, let image = UIImage(data: data) {
                        self.loadedProductImage = image
                        self.imageLoadError = nil
                    } else {
                        self.imageLoadError = "Failed to load image data"
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoadingProductImage = false
                self.imageLoadError = "Invalid Firebase Storage URL"
            }
        }
    }
    
    private func loadImageFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.isLoadingProductImage = false
                self.imageLoadError = "Invalid URL format"
            }
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingProductImage = false
                if let error = error {
                    self.imageLoadError = error.localizedDescription
                } else if let data = data, let image = UIImage(data: data) {
                    self.loadedProductImage = image
                    self.imageLoadError = nil
                } else {
                    self.imageLoadError = "Failed to load image data"
                }
            }
        }.resume()
    }
    
    private func removeCurrentImage() {
        selectedImage = nil
        uploadedImageURL = nil
        loadedProductImage = nil
        imageLoadError = nil
        pickedItem = nil
        
        // If we're in editing mode, this represents removing the image entirely
        if isEditing {
            // We'll set the image URL to placeholder when saving
            print("Image will be removed when saving")
        }
    }
    
    // MARK: - Save Changes
    
    private func saveChanges() {
        guard isFormValid else {
            errorMessage = "Please check all fields are valid"
            return
        }
        
        isUpdating = true
        
        let db = Firestore.firestore()
        guard let productId = product.id else {
            errorMessage = "Product ID not found"
            isUpdating = false
            return
        }
        
        // Convert inventory strings to integers
        var updatedInventory: [String: Int] = [:]
        for (size, value) in inventory {
            updatedInventory[size] = Int(value) ?? 0
        }
        
        // Prepare update data
        var updateData: [String: Any] = [
            "inventory": updatedInventory,
            "active": isActive,
            "title": editedTitle.trimmingCharacters(in: .whitespaces),
            "price": Double(editedPrice) ?? product.price,
            "sizes": editedSizes
        ]
        
        // Handle image URL update
        if let newImageURL = uploadedImageURL {
            updateData["image_url"] = newImageURL
        } else if selectedImage == nil && loadedProductImage == nil {
            // If no image is selected and no loaded image, set to placeholder
            updateData["image_url"] = "https://via.placeholder.com/300x300.png?text=Product+Image"
        }
        
        // Update product in Firestore
        db.collection("products").document(productId).updateData(updateData) { error in
            DispatchQueue.main.async {
                self.isUpdating = false
                
                if let error = error {
                    self.errorMessage = "Failed to update product: \(error.localizedDescription)"
                } else {
                    // Update the local product object to reflect changes
                    self.product.title = self.editedTitle.trimmingCharacters(in: .whitespaces)
                    self.product.price = Double(self.editedPrice) ?? self.product.price
                    self.product.active = self.isActive
                    self.product.sizes = self.editedSizes
                    
                    // Update inventory
                    var newInventory: [String: Int] = [:]
                    for (size, value) in self.inventory {
                        newInventory[size] = Int(value) ?? 0
                    }
                    self.product.inventory = newInventory
                    
                    // Update image URL if changed
                    if let newImageURL = self.uploadedImageURL {
                        self.product.imageUrl = newImageURL
                        // Clear the uploaded URL since it's now saved
                        self.uploadedImageURL = nil
                    } else if self.selectedImage == nil && self.loadedProductImage == nil {
                        self.product.imageUrl = "https://via.placeholder.com/300x300.png?text=Product+Image"
                    }
                    
                    self.successMessage = "Product updated successfully!"
                    self.isEditing = false
                    
                    // Clear the selected image since changes are saved
                    self.selectedImage = nil
                    
                    // Reload the product image to show the updated version
                    self.loadProductImageIfNeeded()
                    
                    // Provide haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            }
        }
    }
    
    private func deleteProduct() {
        isUpdating = true
        
        let db = Firestore.firestore()
        guard let productId = product.id else {
            errorMessage = "Product ID not found"
            isUpdating = false
            return
        }
        
        // Create a batch to remove product from all events and then delete it
        let batch = db.batch()
        
        // Remove product from all associated events
        for eventId in product.eventIds {
            let eventRef = db.collection("events").document(eventId)
            batch.updateData([
                "product_ids": FieldValue.arrayRemove([productId])
            ], forDocument: eventRef)
        }
        
        // Delete the product
        let productRef = db.collection("products").document(productId)
        batch.deleteDocument(productRef)
        
        batch.commit { error in
            DispatchQueue.main.async {
                self.isUpdating = false
                
                if let error = error {
                    self.errorMessage = "Failed to delete product: \(error.localizedDescription)"
                } else {
                    // Delete the old image from storage if it exists
                    if !self.product.imageUrl.isEmpty && self.product.imageUrl.contains("firebasestorage.googleapis.com") {
                        self.imageUploadService.deleteImage(at: self.product.imageUrl) { _ in }
                    }
                    
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    private func loadAssociatedEvents() {
        guard !product.eventIds.isEmpty else { return }
        
        let db = Firestore.firestore()
        
        db.collection("events")
            .whereField(FieldPath.documentID(), in: product.eventIds)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error loading associated events: \(error)")
                    return
                }
                
                let events = snapshot?.documents.compactMap { document -> Event? in
                    do {
                        return try document.data(as: Event.self)
                    } catch {
                        print("Error parsing event: \(error)")
                        return nil
                    }
                }
                
                DispatchQueue.main.async {
                    self.associatedEvents = events ?? []
                }
            }
    }
}

// MARK: - Size Selector View
struct SizeSelectorView: View {
    let currentSizes: [String]
    let onSizesSelected: ([String]) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedSizes: Set<String> = []
    
    // Standard clothing sizes organized by category
    private let standardSizes = [
        SizeCategory(
            name: "Standard",
            sizes: ["XXS", "XS", "S", "M", "L", "XL", "XXL", "XXXL"]
        ),
        SizeCategory(
            name: "Numeric Extended",
            sizes: ["3XL", "4XL", "5XL"]
        )
    ]
    
    var availableSizes: [SizeCategory] {
        return standardSizes.map { category in
            SizeCategory(
                name: category.name,
                sizes: category.sizes.filter { !currentSizes.contains($0) }
            )
        }.filter { !$0.sizes.isEmpty }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Add Product Sizes")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Select one or more sizes to add to your product")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Size Categories
                    ForEach(availableSizes, id: \.name) { category in
                        SizeCategorySection(
                            category: category,
                            selectedSizes: $selectedSizes
                        )
                    }
                    
                    if availableSizes.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.green)
                            
                            Text("All Sizes Added")
                                .font(.headline)
                            
                            Text("You've already added all available sizes to this product.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Add Sizes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Selected") {
                        onSizesSelected(Array(selectedSizes))
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(selectedSizes.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Size Category Section
struct SizeCategorySection: View {
    let category: SizeCategory
    @Binding var selectedSizes: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !category.sizes.isEmpty {
                    Button(allSelected ? "Deselect All" : "Select All") {
                        toggleSelectAll()
                    }
                    .font(.caption)
                    .foregroundColor(.cyan)
                }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(category.sizes, id: \.self) { size in
                    SizeSelectionButton(
                        size: size,
                        isSelected: selectedSizes.contains(size)
                    ) {
                        toggleSize(size)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var allSelected: Bool {
        category.sizes.allSatisfy { selectedSizes.contains($0) }
    }
    
    private func toggleSelectAll() {
        if allSelected {
            // Deselect all sizes in this category
            for size in category.sizes {
                selectedSizes.remove(size)
            }
        } else {
            // Select all sizes in this category
            for size in category.sizes {
                selectedSizes.insert(size)
            }
        }
    }
    
    private func toggleSize(_ size: String) {
        if selectedSizes.contains(size) {
            selectedSizes.remove(size)
        } else {
            selectedSizes.insert(size)
        }
    }
}

// MARK: - Size Selection Button
struct SizeSelectionButton: View {
    let size: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(size)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    isSelected ? Color.cyan : Color(.systemBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? Color.cyan : Color(.systemGray3),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Data Structures
struct SizeCategory {
    let name: String
    let sizes: [String]
}

// MARK: - Supporting Views (unchanged from original)
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct AssociatedEventsView: View {
    let eventIds: [String]
    @State private var events: [Event] = []
    @State private var isLoading = true
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if events.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No Events Found")
                            .font(.headline)
                        
                        Text("The associated events may have been deleted.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(events) { event in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(event.name)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Circle()
                                    .fill(event.isActive ? Color.green : (event.isUpcoming ? Color.orange : Color.gray))
                                    .frame(width: 12, height: 12)
                            }
                            
                            Text(event.venueName)
                                .font(.subheadline)
                                .foregroundColor(.cyan)
                            
                            if !event.address.isEmpty {
                                Label(event.address, systemImage: "location")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Label(event.formattedDateRange, systemImage: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Associated Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                loadEvents()
            }
        }
    }
    
    private func loadEvents() {
        guard !eventIds.isEmpty else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("events")
            .whereField(FieldPath.documentID(), in: eventIds)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        print("Error loading events: \(error)")
                        return
                    }
                    
                    self.events = snapshot?.documents.compactMap { document -> Event? in
                        do {
                            return try document.data(as: Event.self)
                        } catch {
                            print("Error parsing event: \(error)")
                            return nil
                        }
                    } ?? []
                }
            }
    }
}
