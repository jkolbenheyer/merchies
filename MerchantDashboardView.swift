import SwiftUI
import PhotosUI
import Firebase
import FirebaseFirestore

struct MerchantDashboardView: View {
    @StateObject private var productViewModel = ProductViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingAddProduct = false
    @State private var showingCreateEvent = false
    @State private var showingProductDetail: Product? = nil
    @State private var isStoreActive = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                // Store status toggle
                HStack {
                    Text("Store Status:")
                        .font(.headline)
                    
                    Spacer()
                    
                    Toggle("", isOn: $isStoreActive)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .cyan))
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Quick Actions Section
                HStack(spacing: 15) {
                    // Create Event Button
                    Button(action: {
                        showingCreateEvent = true
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            Text("Create Event")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.cyan)
                        .cornerRadius(10)
                    }
                    
                    // Add Product Button
                    Button(action: {
                        showingAddProduct = true
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.cyan)
                            Text("Add Product")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.cyan)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.cyan.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                if productViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                } else if productViewModel.products.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "tag")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Products Yet")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Add your first product to get started selling at events")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                showingCreateEvent = true
                            }) {
                                HStack {
                                    Image(systemName: "calendar.badge.plus")
                                    Text("Create Your First Event")
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.cyan)
                                .cornerRadius(10)
                            }
                            
                            Button(action: {
                                showingAddProduct = true
                            }) {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("Add Your First Product")
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.cyan)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.cyan.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 30)
                } else {
                    // Products section header
                    HStack {
                        Text("Your Products")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text("\(productViewModel.products.count) item\(productViewModel.products.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 5)
                    
                    // Product list
                    List {
                        ForEach(productViewModel.products) { product in
                            Button(action: {
                                showingProductDetail = product
                            }) {
                                HStack {
                                    // Product image
                                    if let url = URL(string: product.imageUrl) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.2))
                                                    .frame(width: 60, height: 60)
                                                    .cornerRadius(8)
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 60, height: 60)
                                                    .cornerRadius(8)
                                                    .clipped()
                                            case .failure:
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.2))
                                                    .frame(width: 60, height: 60)
                                                    .cornerRadius(8)
                                                    .overlay(
                                                        Image(systemName: "photo")
                                                            .foregroundColor(.gray)
                                                    )
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 60, height: 60)
                                            .cornerRadius(8)
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(product.title)
                                            .font(.headline)
                                            .lineLimit(1)
                                        
                                        Text("$\(String(format: "%.2f", product.price))")
                                            .font(.subheadline)
                                            .foregroundColor(.cyan)
                                        
                                        // Show available sizes
                                        Text(product.sizes.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                        
                                        // Show total inventory
                                        let totalInventory = product.inventory.values.reduce(0, +)
                                        Text("Stock: \(totalInventory)")
                                            .font(.caption2)
                                            .foregroundColor(totalInventory > 0 ? .green : .red)
                                    }
                                    .padding(.leading, 5)
                                    
                                    Spacer()
                                    
                                    VStack(spacing: 8) {
                                        // Status indicator
                                        Circle()
                                            .fill(product.active ? Color.green : Color.gray)
                                            .frame(width: 12, height: 12)
                                        
                                        // Active/Inactive text
                                        Text(product.active ? "Active" : "Inactive")
                                            .font(.caption2)
                                            .foregroundColor(product.active ? .green : .gray)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Your Store")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingCreateEvent = true
                        }) {
                            Label("Create Event", systemImage: "calendar.badge.plus")
                        }
                        
                        Button(action: {
                            showingAddProduct = true
                        }) {
                            Label("Add Product", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
            .sheet(isPresented: $showingCreateEvent) {
                CreateEventView()
            }
            .sheet(isPresented: $showingAddProduct) {
                AddProductView(bandId: getMerchantBandId())
            }
            .sheet(item: $showingProductDetail) { product in
                MerchantProductDetailView(product: product)
            }
            .onAppear {
                loadMerchantProducts()
            }
        }
    }
    
    func getMerchantBandId() -> String {
        // Default to mock_band_id for testing
        return "mock_band_id"
    }
    
    func loadMerchantProducts() {
        guard let user = authViewModel.user else {
            errorMessage = "User not logged in"
            return
        }
        
        let db = Firestore.firestore()
        
        // First, get the user document to find the band IDs
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                self.errorMessage = "Error fetching user data: \(error.localizedDescription)"
                return
            }
            
            guard let document = document, document.exists else {
                self.errorMessage = "User document not found"
                return
            }
            
            // Get bandIds from the user document
            let data = document.data() ?? [:]
            
            // Handle both string and array formats for bandIds
            var bandIds: [String] = []
            
            if let bandIdString = data["bandIds"] as? String {
                // If bandIds is stored as a single string
                bandIds = [bandIdString]
            } else if let bandIdArray = data["bandIds"] as? [String] {
                // If bandIds is stored as an array of strings
                bandIds = bandIdArray
            }
            
            if bandIds.isEmpty {
                self.errorMessage = "No bands associated with this merchant"
                return
            }
            
            // Now fetch products for these band IDs
            self.fetchProductsForBands(bandIds: bandIds)
        }
    }
    
    func fetchProductsForBands(bandIds: [String]) {
        let db = Firestore.firestore()
        
        // Set loading state
        productViewModel.isLoading = true
        
        // Query products collection where band_id is in the list of band IDs
        db.collection("products")
            .whereField("band_id", in: bandIds)
            .getDocuments { snapshot, error in
                // Reset loading state
                self.productViewModel.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error fetching products: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.productViewModel.products = []
                    return
                }
                
                // Parse products
                self.productViewModel.products = documents.compactMap { document -> Product? in
                    do {
                        return try document.data(as: Product.self)
                    } catch {
                        self.errorMessage = "Error parsing product: \(error.localizedDescription)"
                        return nil
                    }
                }
            }
    }
}

// Modified AddProductView to accept bandId with Cyan theme
struct AddProductView: View {
    @StateObject private var productViewModel = ProductViewModel()
    @Environment(\.presentationMode) var presentationMode
    let bandId: String
    
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
                            bandId: bandId, // Use the passed bandId
                            title: title,
                            price: Double(price) ?? 0.0,
                            sizes: selectedSizes,
                            inventory: inventory,
                            imageUrl: mockImageUrl,
                            active: true
                        )
                        
                        // Add the product
                        let db = Firestore.firestore()
                        do {
                            let _ = try db.collection("products").addDocument(from: newProduct)
                            presentationMode.wrappedValue.dismiss()
                        } catch {
                            print("Error adding product: \(error.localizedDescription)")
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
