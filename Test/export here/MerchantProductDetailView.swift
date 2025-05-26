// Replace your existing ProductDetailView with this enhanced version
// Or create a new file called MerchantProductDetailView.swift

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
                                        .overlay(ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .cyan)))
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
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                                .font(.title)
                                        )
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    
                    if isEditing {
                        Button("Change Image") {
                            // TODO: Implement image picker in future
                        }
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                // Product Information - FULLY EDITABLE!
                Section(header: Text("Product Information")) {
                    HStack {
                        Text("Title")
                            .frame(width: 60, alignment: .leading)
                        if isEditing {
                            TextField("Product Title", text: $editTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            Spacer()
                            Text(product.title)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Price")
                            .frame(width: 60, alignment: .leading)
                        if isEditing {
                            Spacer()
                            HStack {
                                Text("$")
                                TextField("0.00", text: $editPrice)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                            }
                        } else {
                            Spacer()
                            Text("$\(String(format: "%.2f", product.price))")
                                .foregroundColor(.cyan)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack {
                        Text("Status")
                            .frame(width: 60, alignment: .leading)
                        Spacer()
                        if isEditing {
                            Toggle("Active", isOn: $editActive)
                                .toggleStyle(SwitchToggleStyle(tint: .cyan))
                        } else {
                            HStack {
                                Circle()
                                    .fill(product.active ? Color.green : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text(product.active ? "Active" : "Inactive")
                                    .foregroundColor(product.active ? .green : .gray)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    
                    HStack {
                        Text("Sizes")
                            .frame(width: 60, alignment: .leading)
                        Spacer()
                        Text(product.sizes.joined(separator: ", "))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Inventory Management - Enhanced and Fully Editable
                Section(header: Text("Inventory Management")) {
                    ForEach(product.sizes, id: \.self) { size in
                        HStack {
                            Text("Size \(size)")
                                .frame(width: 60, alignment: .leading)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            if isEditing {
                                TextField("Qty", text: Binding(
                                    get: { editInventory[size] ?? "0" },
                                    set: { editInventory[size] = $0 }
                                ))
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 70)
                                .multilineTextAlignment(.center)
                            } else {
                                let quantity = product.inventory[size] ?? 0
                                HStack {
                                    Text("\(quantity)")
                                        .foregroundColor(quantity > 0 ? .primary : .red)
                                        .fontWeight(quantity == 0 ? .bold : .regular)
                                    
                                    if quantity == 0 {
                                        Text("(Out of Stock)")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    
                    // Total Stock Display
                    if !isEditing {
                        Divider()
                        
                        let totalStock = product.inventory.values.reduce(0, +)
                        HStack {
                            Text("Total Stock")
                                .fontWeight(.bold)
                            Spacer()
                            Text("\(totalStock)")
                                .fontWeight(.bold)
                                .foregroundColor(totalStock > 0 ? .cyan : .red)
                                .font(.title3)
                        }
                        .padding(.vertical, 8)
                        .background(totalStock > 0 ? Color.cyan.opacity(0.1) : Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // Product Analytics (placeholder)
                if !isEditing {
                    Section(header: Text("Product Analytics")) {
                        HStack {
                            Text("Total Sales")
                            Spacer()
                            Text("Coming Soon")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                        HStack {
                            Text("Revenue Generated")
                            Spacer()
                            Text("Coming Soon")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                // Danger Zone - Delete Product
                if isEditing {
                    Section(header: Text("Danger Zone")) {
                        Button("Delete Product") {
                            showingDeleteAlert = true
                        }
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                    }
                }
                
                // Error message display
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
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
                    if isEditing {
                        HStack {
                            Button("Cancel") {
                                cancelEditing()
                            }
                            .foregroundColor(.secondary)
                            
                            Button("Save") {
                                saveChanges()
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.cyan)
                            .disabled(isSaving || editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    } else {
                        Button("Edit") {
                            startEditing()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.cyan)
                    }
                }
            }
            .alert("Delete Product", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteProduct()
                }
            } message: {
                Text("Are you sure you want to delete '\(product.title)'? This action cannot be undone and will remove the product from all events.")
            }
            .overlay(
                Group {
                    if isSaving {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            
                            Text("Saving Changes...")
                                .font(.headline)
                                .padding(.top)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(radius: 10)
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
        // Validate inputs
        let trimmedTitle = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Product title cannot be empty"
            return
        }
        
        guard let newPrice = Double(editPrice), newPrice >= 0 else {
            errorMessage = "Please enter a valid price (must be 0.00 or greater)"
            return
        }
        
        // Validate inventory quantities
        var newInventory: [String: Int] = [:]
        for (size, quantityString) in editInventory {
            guard let quantity = Int(quantityString), quantity >= 0 else {
                errorMessage = "Please enter valid quantities for all sizes (must be 0 or greater)"
                return
            }
            newInventory[size] = quantity
        }
        
        isSaving = true
        errorMessage = nil
        
        // Create updated product
        var updatedProduct = product
        updatedProduct.title = trimmedTitle
        updatedProduct.price = newPrice
        updatedProduct.active = editActive
        updatedProduct.inventory = newInventory
        
        updateProductInFirestore(updatedProduct)
    }
    
    private func updateProductInFirestore(_ updatedProduct: Product) {
        guard let productId = product.id else {
            errorMessage = "Product ID not found - cannot save changes"
            isSaving = false
            return
        }
        
        let db = Firestore.firestore()
        
        do {
            try db.collection("products").document(productId).setData(from: updatedProduct) { error in
                DispatchQueue.main.async {
                    self.isSaving = false
                    
                    if let error = error {
                        self.errorMessage = "Failed to save changes: \(error.localizedDescription)"
                    } else {
                        // Update successful!
                        self.product = updatedProduct
                        self.isEditing = false
                        
                        // Provide haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
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
            errorMessage = "Product ID not found - cannot delete"
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
                    // Product deleted successfully
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // Close the view
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// MARK: - Usage Instructions & Summary
/*
🎯 FULL EDITING CAPABILITIES:

✅ Product Title - Text field with validation
✅ Product Price - Decimal input with currency formatting
✅ Product Status - Toggle between Active/Inactive
✅ Inventory Quantities - Individual editing for each size
✅ Delete Product - With confirmation alert

🎨 CYAN COLOR SCHEME:
- Toggle switches use cyan
- Price display in cyan
- Edit/Save buttons in cyan
- Progress indicators in cyan
- Cyan accent throughout

🔧 FEATURES:
- Input validation and error handling
- Loading states during save operations
- Haptic feedback on successful actions
- Real-time Firestore updates
- Confirmation dialogs for destructive actions

📱 USAGE:
1. Tap "Edit" to enter edit mode
2. Modify any field (title, price, status, inventory)
3. Tap "Save" to persist changes to Firestore
4. Tap "Cancel" to discard changes
5. Use "Delete Product" for permanent removal

This view provides complete CRUD operations for merchant products!
*/
