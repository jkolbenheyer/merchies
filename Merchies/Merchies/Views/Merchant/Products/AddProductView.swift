// MerchProductEditView.swift - CORRECTED WITH REAL IMAGE UPLOAD
import SwiftUI
import PhotosUI
import FirebaseFirestore
import Foundation


struct MerchProductEditView: View {
    @StateObject private var productViewModel = ProductViewModel()
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    
    let bandId: String
    
    @State private var title = ""
    @State private var price = ""
    @State private var selectedSizes: [String] = []
    @State private var inventoryValues: [String: String] = [:]
    @State private var selectedImage: UIImage?
    @State private var isImagePickerPresented = false
    @State private var isCreating = false
    @State private var isUploadingImage = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    @State private var uploadedImageURL: String?
    
    // Image upload service
    private let imageUploadService = ImageUploadService()
    
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
                    if #available(iOS 14.0, *) {
                        PhotoPickerView(selectedImage: $selectedImage, title: "Product Image")
                    } else {
                        // Fallback for older iOS versions
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
                        HStack {
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
                                    if selectedSizes.contains(size) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.cyan)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
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
            .sheet(isPresented: $isImagePickerPresented) {
                if #available(iOS 14.0, *) {
                    // For iOS 14+, the PhotoPickerView handles this directly
                    EmptyView()
                } else {
                    LegacyImagePickerSheet(selectedImage: $selectedImage, isPresented: $isImagePickerPresented)
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
    
    private func createProduct() {
        isCreating = true
        errorMessage = nil
        
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
                        self.errorMessage = "Failed to upload image: \(error.localizedDescription)"
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
            eventIds: [] // Start with no events assigned
        )
        
        // Save to Firestore directly
        let db = Firestore.firestore()
        
        do {
            let _ = try db.collection("products").addDocument(from: newProduct) { error in
                DispatchQueue.main.async {
                    self.isCreating = false
                    
                    if let error = error {
                        self.errorMessage = "Failed to create product: \(error.localizedDescription)"
                        
                        // If product creation failed but image was uploaded, clean up the image
                        if let imageURL = self.uploadedImageURL {
                            self.imageUploadService.deleteImage(at: imageURL) { _ in }
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
                    self.imageUploadService.deleteImage(at: imageURL) { _ in }
                }
            }
        }
    }
}
