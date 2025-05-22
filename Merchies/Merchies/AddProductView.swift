import SwiftUI
import PhotosUI

struct MerchProductEditView: View {
    @StateObject private var productViewModel = ProductViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var title = ""
    @State private var price = ""
    @State private var selectedSizes: [String] = []
    @State private var inventoryValues: [String: String] = [:]
    @State private var selectedImage: UIImage?
    @State private var isImagePickerPresented = false
    
    let availableSizes = ["XS", "S", "M", "L", "XL", "XXL"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Product Information")) {
                    TextField("Product Title", text: $title)
                    
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Product Image")) {
                    HStack {
                        Spacer()
                        
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
                        
                        Spacer()
                    }
                    .onTapGesture {
                        isImagePickerPresented = true
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
                                            .foregroundColor(.purple)
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
                        // In a real app, you would upload the image to Firebase Storage
                        // and get the download URL
                        
                        // For now, we'll just use a placeholder URL
                        let mockImageUrl = "https://example.com/image.jpg"
                        
                        // Convert inventory values to integers
                        var inventory: [String: Int] = [:]
                        for (size, value) in inventoryValues {
                            inventory[size] = Int(value) ?? 0
                        }
                        
                        // Create a new product
                        let newProduct = Product(
                            bandId: "mock_band_id", // In a real app, you would get this from the user
                            title: title,
                            price: Double(price) ?? 0.0,
                            sizes: selectedSizes,
                            inventory: inventory,
                            imageUrl: mockImageUrl,
                            active: true
                        )
                        
                        productViewModel.addProduct(newProduct) { success in
                            if success {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                    .disabled(title.isEmpty || price.isEmpty || selectedSizes.isEmpty || selectedImage == nil)
                }
            }
            .sheet(isPresented: $isImagePickerPresented) {
                // In a real app, you would use PHPickerViewController
                // For simplicity, we'll use a placeholder
                VStack {
                    Text("Image Picker Placeholder")
                        .font(.headline)
                        .padding()
                    
                    Button("Select Image") {
                        // Simulate selecting an image
                        selectedImage = UIImage(systemName: "photo")
                        isImagePickerPresented = false
                    }
                    .padding()
                    
                    Button("Cancel") {
                        isImagePickerPresented = false
                    }
                    .padding()
                }
            }
        }
    }
}

