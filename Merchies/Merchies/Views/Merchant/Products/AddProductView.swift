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
    @State private var selectedImage: UIImage?
    @State private var pickedItem: PhotosPickerItem?
    @State private var isUploadingImage = false
    @State private var uploadedImageURL: String?
    
    // UI state
    @State private var isCreating = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    
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
                
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Product Image")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("Add an image to make your product more appealing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Image Display Area - Matches EditEventView exactly
                        Group {
                            if let image = selectedImage {
                                // New selected image
                                EditEventImageDisplayCard(
                                    image: image,
                                    isLoading: isUploadingImage,
                                    loadingText: "Uploading product image...",
                                    onRemove: removeCurrentImage
                                )
                            } else if isUploadingImage {
                                // Loading state
                                EditEventImageLoadingCard(message: "Uploading product image...")
                            } else {
                                // No image placeholder
                                EditEventImagePlaceholderCard()
                            }
                        }
                        
                        // Image Action Buttons - Exactly like EditEventView
                        VStack(spacing: 8) {
                            PhotosPicker(
                                selection: $pickedItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                HStack {
                                    Image(systemName: "photo")
                                    Text(hasProductImage ? "Change Image" : "Choose Image")
                                        .fontWeight(.medium)
                                    if isUploadingImage {
                                        Spacer()
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                .foregroundColor(.cyan)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Color.cyan.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .disabled(isUploadingImage)
                            .onChange(of: pickedItem) { newItem in
                                handleImageSelection(newItem)
                            }
                        }
                    }
                    .padding(.vertical, 8)
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
    }
    
    // MARK: - Computed Properties
    
    private var hasProductImage: Bool {
        selectedImage != nil
    }
    
    // MARK: - Helper Methods
    
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
                            }
                        }
                    }
                    cont.resume()
                }
            }
        }
    }
    
    private func removeCurrentImage() {
        selectedImage = nil
        uploadedImageURL = nil
        pickedItem = nil
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
                .scaledToFill()
                .frame(height: 200)
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
            .frame(height: 200)
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
            .frame(height: 200)
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
