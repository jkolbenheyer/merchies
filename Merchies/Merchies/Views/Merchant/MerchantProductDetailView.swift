// MerchantProductDetailView.swift - FINAL FIXED VERSION
import SwiftUI
import FirebaseFirestore

struct MerchantProductDetailView: View {
    let product: Product
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isEditing = false
    @State private var inventory: [String: String] = [:]
    @State private var isActive: Bool = true
    @State private var isUpdating = false
    @State private var showingDeleteAlert = false
    @State private var showingEventsList = false
    @State private var associatedEvents: [Event] = []
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Product Image and Basic Info
                    ProductImageSection()
                    
                    // Product Details Card
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
                        .disabled(isUpdating)
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
            }
            .overlay(
                Group {
                    if isUpdating {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            
                            Text("Updating...")
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
    
    // MARK: - Product Image Section
    @ViewBuilder
    private func ProductImageSection() -> some View {
        VStack(spacing: 12) {
            AsyncImage(url: URL(string: product.imageUrl)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .cornerRadius(12)
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .cornerRadius(12)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray)
                                Text("Image not available")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                @unknown default:
                    EmptyView()
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text(product.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("$\(String(format: "%.2f", product.price))")
                        .font(.title3)
                        .foregroundColor(.cyan)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    HStack {
                        Circle()
                            .fill(isActive ? Color.green : Color.orange)
                            .frame(width: 12, height: 12)
                        
                        Text(isActive ? "Active" : "Inactive")
                            .font(.subheadline)
                            .foregroundColor(isActive ? .green : .orange)
                            .fontWeight(.medium)
                    }
                    
                    if isEditing {
                        Toggle("", isOn: $isActive)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: .cyan))
                    }
                }
            }
        }
    }
    
    // MARK: - Product Details Card
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
                DetailRow(label: "Events", value: "\(product.eventIds.count)")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Inventory Card
    @ViewBuilder
    private func InventoryCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Inventory Management")
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
            
            VStack(spacing: 8) {
                ForEach(product.sizes, id: \.self) { size in
                    HStack {
                        Text(size)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 40, alignment: .leading)
                        
                        Spacer()
                        
                        if isEditing {
                            TextField("Qty", text: Binding(
                                get: { inventory[size] ?? "\(product.inventory[size] ?? 0)" },
                                set: { inventory[size] = $0 }
                            ))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white)
                            .cornerRadius(6)
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
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
                    .disabled(isUpdating)
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
    
    // MARK: - Helper Functions
    private func setupInitialValues() {
        isActive = product.active
        
        // Initialize inventory values
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
    }
    
    private func saveChanges() {
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
        
        // Update product in Firestore
        db.collection("products").document(productId).updateData([
            "inventory": updatedInventory,
            "active": isActive
        ]) { error in
            DispatchQueue.main.async {
                self.isUpdating = false
                
                if let error = error {
                    self.errorMessage = "Failed to update product: \(error.localizedDescription)"
                } else {
                    self.successMessage = "Product updated successfully!"
                    self.isEditing = false
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

// MARK: - Supporting Views
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
