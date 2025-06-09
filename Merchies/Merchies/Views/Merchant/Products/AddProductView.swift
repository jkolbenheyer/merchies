// AddProductView.swift - COMPLETE WORKING VERSION
import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage
import Foundation

struct AddProductView: View {
    @StateObject private var productViewModel = ProductViewModel()
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    
    let bandId: String
    
    // Form state
    @State private var title = ""
    @State private var price = ""
    @State private var selectedSizes: [String] = []
    @State private var inventoryValues: [String: String] = [:]
    
    // Image state
    @State private var selectedImage: UIImage? {
        didSet {
            print("📸 AddProductView: selectedImage changed to \(selectedImage != nil ? "available" : "nil")")
        }
    }
    @State private var pickedItem: PhotosPickerItem?
    @State private var isUploadingImage = false
    @State private var uploadedImageURL: String? {
        didSet {
            print("📸 AddProductView: uploadedImageURL changed to \(uploadedImageURL != nil ? "available" : "nil")")
        }
    }
    @State private var showingCamera = false
    @State private var showingImageCropper = false
    @State private var imageForCropping: UIImage?
    @State private var pendingCropImage: UIImage?  // For delayed cropping after camera
    @State private var activeSheet: ActiveSheet? = nil
    
    enum ActiveSheet: Identifiable {
        case camera, photoLibrary, imageCropper
        var id: Int {
            hashValue
        }
    }
    
    // UI state
    @State private var isCreating = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    @State private var showingRemoveConfirmation = false
    
    let availableSizes = ["XS", "S", "M", "L", "XL", "XXL"]
    
    init(bandId: String) {
        self.bandId = bandId
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Product Information")) {
                    TextField("Product Title", text: $title)
                    
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Product Image")) {
                    VStack(spacing: 16) {
                        // Image Display Area
                        if let image = selectedImage {
                            // New selected image
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 200)
                                .cornerRadius(12)
                                .overlay(
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Button(action: {
                                                print("📸 AddProductView: X button pressed - user wants to remove image")
                                                showingRemoveConfirmation = true
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.8))
                                                    .clipShape(Circle())
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .frame(width: 30, height: 30)
                                            .contentShape(Circle())
                                        }
                                        Spacer()
                                    }
                                    .padding(8)
                                )
                        } else if isUploadingImage {
                            // Loading state
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .frame(height: 150)
                                .overlay(
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                                        Text("Uploading image...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        } else {
                            // No image placeholder
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .frame(height: 150)
                                .overlay(
                                    VStack(spacing: 12) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 48))
                                            .foregroundColor(.gray)
                                        
                                        VStack(spacing: 4) {
                                            Text("No Image Set")
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            
                                            Text("Choose an image to make your product more appealing")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.separator), style: StrokeStyle(lineWidth: 1, dash: [5]))
                                )
                        }
                        
                        // Image Action Buttons
                        VStack(spacing: 12) {
                            VStack(spacing: 12) {
                                // Camera Button
                                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                    Button(action: { 
                                        guard activeSheet == nil else { return }
                                        print("📸 AddProductView: Camera button pressed")
                                        activeSheet = .camera
                                    }) {
                                        HStack {
                                            Image(systemName: "camera.fill")
                                            Text("Camera")
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.purple)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.purple.opacity(0.1))
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(isUploadingImage || activeSheet != nil)
                                }
                                
                                // Photo Library Button
                                Button(action: {
                                    guard activeSheet == nil else { return }
                                    print("📸 AddProductView: Library button pressed")
                                    activeSheet = .photoLibrary
                                }) {
                                    HStack {
                                        Image(systemName: "photo")
                                        Text("Library")
                                            .fontWeight(.medium)
                                        if isUploadingImage {
                                            Spacer()
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        }
                                    }
                                    .foregroundColor(isUploadingImage ? .gray : .cyan)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background((isUploadingImage ? Color.gray : Color.cyan).opacity(0.1))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(isUploadingImage || activeSheet != nil)
                            }
                            
                            // Crop button (only show when image is selected and no sheets are active)
                            if (selectedImage != nil || uploadedImageURL != nil) && activeSheet == nil {
                                Button(action: {
                                    guard activeSheet == nil else { return }
                                    print("📸 AddProductView: Crop button pressed, checking selectedImage...")
                                    print("📸 AddProductView: selectedImage is \(selectedImage != nil ? "available" : "nil")")
                                    print("📸 AddProductView: uploadedImageURL is \(uploadedImageURL != nil ? "available" : "nil")")
                                    
                                    // Try to get image from selectedImage first, then fall back to uploaded image
                                    if let image = selectedImage {
                                        print("📸 AddProductView: Using selectedImage for cropping")
                                        imageForCropping = image
                                        activeSheet = .imageCropper
                                    } else if let uploadedURL = uploadedImageURL {
                                        print("📸 AddProductView: Loading uploaded image for cropping")
                                        // Load the uploaded image for cropping
                                        loadImageFromURL(uploadedURL) { loadedImage in
                                            DispatchQueue.main.async {
                                                if let loadedImage = loadedImage {
                                                    self.imageForCropping = loadedImage
                                                    self.activeSheet = .imageCropper
                                                } else {
                                                    self.errorMessage = "Failed to load image for cropping"
                                                }
                                            }
                                        }
                                    } else {
                                        print("❌ AddProductView: No image available for cropping")
                                        return 
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "crop")
                                        Text("Crop Image")
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.orange)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(10)
                                }
                                .disabled(isUploadingImage || activeSheet != nil)
                            }
                        }
                    }
                }
                
                // Available Sizes Section
                Section(header: Text("Available Sizes")) {
                    ForEach(availableSizes, id: \.self) { size in
                        Button(action: {
                            toggleSizeSelection(size)
                        }) {
                            HStack {
                                Text(size)
                                    .foregroundColor(.primary)
                                    .font(.body)
                                
                                Spacer()
                                
                                if selectedSizes.contains(size) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.cyan)
                                        .font(.title3)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                        .font(.title3)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 4)
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
            .navigationTitle("Add Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        createProduct()
                    }
                    .disabled(title.isEmpty || price.isEmpty || selectedSizes.isEmpty ||
                              isCreating || isUploadingImage)
                    .fontWeight(.semibold)
                }
            }
            .alert("Product Created!", isPresented: $showingSuccess) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Your product has been created successfully. You can now add it to events from the Events tab.")
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
            .alert("Remove Image", isPresented: $showingRemoveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    removeCurrentImage()
                }
            } message: {
                Text("Are you sure you want to remove this image?")
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
            .sheet(item: $activeSheet) { sheetType in
                switch sheetType {
                case .camera:
                    print("📸 AddProductView: Presenting Camera sheet")
                    return AnyView(
                        ImagePickerView(selectedImage: $selectedImage, sourceType: .camera)
                            .onDisappear {
                                activeSheet = nil
                                // Give time for sheet to fully dismiss before any other operations
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    if selectedImage != nil {
                                        handleCameraImageSelection()
                                    }
                                }
                            }
                    )
                case .photoLibrary:
                    print("📸 AddProductView: Presenting Photo Library sheet")
                    return AnyView(
                        ImagePickerView(selectedImage: $selectedImage, sourceType: .photoLibrary)
                            .onDisappear {
                                print("📸 AddProductView: Photo Library sheet dismissed")
                                activeSheet = nil
                                // Give time for sheet to fully dismiss before any other operations
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    print("📸 AddProductView: Checking for image to upload after delay")
                                    if selectedImage != nil {
                                        print("📸 AddProductView: Calling handleImageSelection")
                                        handleImageSelection()
                                    } else {
                                        print("📸 AddProductView: No selectedImage found after sheet dismiss")
                                    }
                                }
                            }
                    )
                case .imageCropper:
                    print("📸 AddProductView: Presenting Image Cropper sheet")
                    if let imageForCropping = imageForCropping {
                        return AnyView(
                            ImageCropperView(
                                selectedImage: $selectedImage,
                                isPresented: Binding(
                                    get: { activeSheet == .imageCropper },
                                    set: { if !$0 { activeSheet = nil } }
                                ),
                                originalImage: imageForCropping
                            )
                            .onDisappear {
                                activeSheet = nil
                                self.imageForCropping = nil
                                // Re-upload the cropped image if one was selected
                                if selectedImage != nil {
                                    handleCroppedImageUpload()
                                }
                            }
                        )
                    } else {
                        print("❌ AddProductView: No image available for cropping")
                        return AnyView(
                            VStack {
                                Text("No image to crop")
                                Button("Close") {
                                    activeSheet = nil
                                }
                            }
                            .padding()
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasProductImage: Bool {
        selectedImage != nil
    }
    
    // MARK: - Helper Methods
    
    private func handleCameraImageSelection() {
        guard let image = selectedImage else { return }
        
        isUploadingImage = true
        
        // Convert UIImage to Data and upload
        if let data = image.jpegData(compressionQuality: 0.8) {
            Task {
                await uploadImageData(data)
            }
        } else {
            isUploadingImage = false
            errorMessage = "Failed to process camera image"
        }
    }
    
    private func handleCroppedImageUpload() {
        guard let image = selectedImage else { return }
        
        isUploadingImage = true
        
        // Convert cropped UIImage to Data and re-upload
        if let data = image.jpegData(compressionQuality: 0.8) {
            Task {
                await uploadImageData(data)
            }
        } else {
            isUploadingImage = false
            errorMessage = "Failed to process cropped image"
        }
    }
    
    private func handleImageSelection() {
        guard let image = selectedImage else { return }
        
        isUploadingImage = true
        
        // Convert UIImage to Data and upload
        if let data = image.jpegData(compressionQuality: 0.8) {
            Task {
                await uploadImageData(data)
                // Keep selectedImage available for cropping after upload
                print("📸 AddProductView: Image uploaded, selectedImage preserved for cropping")
            }
        } else {
            isUploadingImage = false
            errorMessage = "Failed to process selected image"
        }
    }
    
    private func handleImageSelection(_ newItem: PhotosPickerItem?) {
        guard let item = newItem else { return }
        isUploadingImage = true
        
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = img
                    }
                    await uploadImageData(data)
                }
            } catch {
                await MainActor.run {
                    isUploadingImage = false
                    errorMessage = "Error loading image: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func uploadImageData(_ data: Data) async {
        await withCheckedContinuation { cont in
            let imageID = UUID().uuidString
            let ref = Storage.storage().reference().child("products/\(imageID).jpg")
            
            ref.putData(data, metadata: nil) { _, err in
                DispatchQueue.main.async {
                    self.isUploadingImage = false
                    if let err = err {
                        self.errorMessage = "Upload error: \(err.localizedDescription)"
                    } else {
                        ref.downloadURL { url, _ in
                            if let url = url {
                                self.uploadedImageURL = url.absoluteString
                                print("✅ Product image uploaded: \(url)")
                                print("📸 AddProductView: After upload - selectedImage is \(self.selectedImage != nil ? "available" : "nil")")
                                print("📸 AddProductView: After upload - uploadedImageURL is \(self.uploadedImageURL != nil ? "available" : "nil")")
                            }
                        }
                    }
                    cont.resume()
                }
            }
        }
    }
    
    private func removeCurrentImage() {
        print("📸 AddProductView: removeCurrentImage() called - clearing all image state")
        selectedImage = nil
        uploadedImageURL = nil
        pickedItem = nil
    }
    
    private func loadImageFromURL(_ urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                completion(image)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    private func toggleSizeSelection(_ size: String) {
        if selectedSizes.contains(size) {
            selectedSizes.removeAll { $0 == size }
            inventoryValues.removeValue(forKey: size)
        } else {
            selectedSizes.append(size)
            inventoryValues[size] = "0"
        }
    }
    
    private func createProduct() {
        isCreating = true
        errorMessage = nil
        
        // Use uploaded image URL if available, otherwise use placeholder
        let imageURL = uploadedImageURL ?? "https://via.placeholder.com/300x300.png?text=Product+Image"
        createProductWithImage(imageURL: imageURL)
    }
    
    private func createProductWithImage(imageURL: String) {
        // Convert inventory values to integers
        var inventory: [String: Int] = [:]
        for (size, value) in inventoryValues {
            inventory[size] = Int(value) ?? 0
        }
        
        // Create the product
        let newProduct = Product(
            bandId: bandId,
            title: title,
            price: Double(price) ?? 0.0,
            sizes: selectedSizes,
            inventory: inventory,
            imageUrl: imageURL,
            active: true,
            eventIds: []
        )
        
        // Save to Firestore
        let db = Firestore.firestore()
        
        do {
            let _ = try db.collection("products").addDocument(from: newProduct) { error in
                DispatchQueue.main.async {
                    self.isCreating = false
                    
                    if let error = error {
                        self.errorMessage = "Failed to create product: \(error.localizedDescription)"
                        
                        // Clean up uploaded image if product creation failed
                        if let imageURL = self.uploadedImageURL {
                            self.deleteUploadedImage(imageURL)
                        }
                    } else {
                        self.showingSuccess = true
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isCreating = false
                self.errorMessage = "Failed to create product: \(error.localizedDescription)"
                
                // Clean up uploaded image if product creation failed
                if let imageURL = self.uploadedImageURL {
                    self.deleteUploadedImage(imageURL)
                }
            }
        }
    }
    
    private func deleteUploadedImage(_ imageURL: String) {
        guard imageURL.contains("firebasestorage.googleapis.com") else { return }
        
        do {
            let storageRef = Storage.storage().reference(forURL: imageURL)
            storageRef.delete { _ in
                print("Cleaned up uploaded image after product creation failure")
            }
        } catch {
            print("Failed to clean up uploaded image: \(error)")
        }
    }
}

// MARK: - Image Display Components (Match EditEventView Design)

struct EditEventImageDisplayCard: View {
    let image: UIImage
    let isLoading: Bool
    let loadingText: String?
    let onRemove: () -> Void
    
    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
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
                .padding(12)
            }
        }
    }
}

struct EditEventImageLoadingCard: View {
    let message: String
    
    var body: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .frame(maxHeight: 200)
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

struct EditEventImagePlaceholderCard: View {
    var body: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .frame(maxHeight: 200)
            .cornerRadius(12)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 4) {
                        Text("No Image Set")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text("Choose an image to make your product more appealing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
    }
}
