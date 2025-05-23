// MerchantProductDetailView.swift
import SwiftUI
import Firebase
import FirebaseFirestore

struct MerchantProductDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var product: Product
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingDeleteAlert = false
    
    // Editable fields
    @State private var editTitle: String
    @State private var editPrice: String
    @State private var editInventory: [String: String] = [:]
    @State private var editActive: Bool
    
    init(product: Product) {
        self._product = State(initialValue: product)
        self._editTitle = State(initialValue: product.title)
        self._editPrice = State(initialValue: String(format: "%.2f", product.price))
        self._editActive = State(initialValue: product.active)
        
        // Initialize inventory values
        var inventoryDict: [String: String] = [:]
        for (size, quantity) in product.inventory {
            inventoryDict[size] = String(quantity)
        }
        self._editInventory = State(initialValue: inventoryDict)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Product Image Section
                Section(header: Text("Product Image")) {
                    HStack {
                        Spacer()
                        
                        if let url = URL(string: product.imageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 200)
                                        .cornerRadius(10)
                                        .overlay(ProgressView())
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 200)
                                        .cornerRadius(10)
                                case .failure:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 200)
                                        .cornerRadius(10)
                                        .overlay(
                                            VStack {
                                                Image(systemName: "photo")
                                                    .foregroundColor(.gray)
                                                    .font(.title)
                                                Text("Failed to load image")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                        )
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                                .cornerRadius(10)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                        .font(.title)
                                )
                        }
                        
                        Spacer()
                    }
                    
                    if isEditing {
                        Button("Change Image") {
                            // TODO: Implement image picker
                        }
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                // Product Information
                Section(header: Text("Product Information")) {
                    HStack {
                        Text("Title")
                        Spacer()
                        if isEditing {
                            TextField("Product Title", text: $editTitle)
                                .multilineTextAlignment(.trailing)
                        } else {
                            Text(product.title)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Price")
                        Spacer()
                        if isEditing {
                            HStack {
                                Text("$")
                                TextField("0.00", text: $editPrice)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }
                        } else {
                            Text("$\(String(format: "%.2f", product.price))")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        if isEditing {
                            Toggle("", isOn: $editActive)
                                .labelsHidden()
                        } else {
                            HStack {
                                Circle()
                                    .fill(product.active ? Color.green : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text(product.active ? "Active" : "Inactive")
                                    .foregroundColor(product.active ? .green : .gray)
                            }
                        }
                    }
                    
                    HStack {
                        Text("Available Sizes")
                        Spacer()
                        Text(product.sizes.joined(separator: ", "))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Inventory Management
                Section(header: Text("Inventory")) {
                    ForEach(product.sizes, id: \.self) { size in
                        HStack {
                            Text("Size \(size)")
                            
                            Spacer()
                            
                            if isEditing {
                                TextField("Qty", text: Binding(
                                    get: { editInventory[size] ?? "0" },
                                    set: { editInventory[size] = $0 }
                                ))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            } else {
                                let quantity = product.inventory[size] ?? 0
                                Text("\(quantity)")
                                    .foregroundColor(quantity > 0 ? .primary : .red)
                                    .fontWeight(quantity == 0 ? .medium : .regular)
                            }
                        }
                    }
                    
                    if !isEditing {
                        let totalStock = product.inventory.values.reduce(0, +)
                        HStack {
                            Text("Total Stock")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(totalStock)")
                                .fontWeight(.medium)
                                .foregroundColor(totalStock > 0 ? .green : .red)
                        }
                        .padding(.top, 8)
                    }
                }
                
                // Product Analytics (placeholder)
                if !isEditing {
                    Section(header: Text("Analytics")) {
                        HStack {
                            Text("Total Sales")
                            Spacer()
                            Text("Coming Soon")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Revenue Generated")
                            Spacer()
                            Text("Coming Soon")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Danger Zone
                if isEditing {
                    Section(header: Text("Danger Zone")) {
                        Button("Delete Product") {
                            showingDeleteAlert = true
                        }
                        .foregroundColor(.red)
                    }
                }
                
                // Error message
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
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
                    HStack {
                        if isEditing {
                            Button("Cancel") {
                                cancelEditing()
                            }
                            
                            Button("Save") {
                                saveChanges()
                            }
                            .fontWeight(.semibold)
                            .disabled(isSaving || editTitle.isEmpty)
                        } else {
                            Button("Edit") {
                                startEditing()
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
            .alert("Delete Product", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteProduct()
                }
            } message: {
                Text("Are you sure you want to delete this product? This action cannot be undone.")
            }
            .overlay(
                Group {
                    if isSaving {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                            
                            Text("Saving...")
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
    
    private func startEditing() {
        isEditing = true
        errorMessage = nil
        
        // Reset edit values to current product values
        editTitle = product.title
        editPrice = String(format: "%.2f", product.price)
        editActive = product.active
        
        editInventory.removeAll()
        for (size, quantity) in product.inventory {
            editInventory[size] = String(quantity)
        }
    }
    
    private func cancelEditing() {
        isEditing = false
        errorMessage = nil
    }
    
    private func saveChanges() {
        guard !editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Product title cannot be empty"
            return
        }
        
        guard let newPrice = Double(editPrice), newPrice >= 0 else {
            errorMessage = "Please enter a valid price"
            return
        }
        
        // Validate inventory
        var newInventory: [String: Int] = [:]
        for (size, quantityString) in editInventory {
            guard let quantity = Int(quantityString), quantity >= 0 else {
                errorMessage = "Please enter valid quantities for all sizes"
                return
            }
            newInventory[size] = quantity
        }
        
        isSaving = true
        errorMessage = nil
        
        // Update the product
        var updatedProduct = product
        updatedProduct.title = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProduct.price = newPrice
        updatedProduct.active = editActive
        updatedProduct.inventory = newInventory
        
        updateProductInFirestore(updatedProduct)
    }
    
    private func updateProductInFirestore(_ updatedProduct: Product) {
        guard let productId = product.id else {
            errorMessage = "Product ID not found"
            isSaving = false
            return
        }
        
        let db = Firestore.firestore()
        
        do {
            try db.collection("products").document(productId).setData(from: updatedProduct) { error in
                DispatchQueue.main.async {
                    self.isSaving = false
                    
                    if let error = error {
                        self.errorMessage = "Failed to update product: \(error.localizedDescription)"
                    } else {
                        // Update local product and exit edit mode
                        self.product = updatedProduct
                        self.isEditing = false
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isSaving = false
                self.errorMessage = "Failed to prepare update: \(error.localizedDescription)"
            }
        }
    }
    
    private func deleteProduct() {
        guard let productId = product.id else {
            errorMessage = "Product ID not found"
            return
        }
        
        isSaving = true
        
        let db = Firestore.firestore()
        db.collection("products").document(productId).delete { error in
            DispatchQueue.main.async {
                self.isSaving = false
                
                if let error = error {
                    self.errorMessage = "Failed to delete product: \(error.localizedDescription)"
                } else {
                    // Product deleted successfully, close the view
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// Preview
struct MerchantProductDetailView_Previews: PreviewProvider {
    static var previews: some View {
        MerchantProductDetailView(product: Product(
            id: "sample_id",
            bandId: "band_123",
            title: "Sample T-Shirt",
            price: 25.99,
            sizes: ["S", "M", "L", "XL"],
            inventory: ["S": 10, "M": 15, "L": 8, "XL": 5],
            imageUrl: "https://example.com/image.jpg",
            active: true
        ))
    }
}
