import SwiftUI
import FirebaseFirestore
import Foundation

struct EventProductsView: View {
    let event: Event
    @StateObject private var viewModel = EventProductsViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingAddProducts = false
    @State private var showingCreateProduct = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading products...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.products.isEmpty {
                    EmptyStateView {
                        showingAddProducts = true
                    } onCreateNew: {
                        showingCreateProduct = true
                    }
                } else {
                    ProductsList()
                }
            }
            .navigationTitle("Event Products")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add Existing Products", systemImage: "plus.square.on.square") {
                            showingAddProducts = true
                        }
                        
                        Button("Create New Product", systemImage: "plus.square") {
                            showingCreateProduct = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProducts) {
                OriginalAddProductsToEventView(event: event, viewModel: viewModel)
            }
            .sheet(isPresented: $showingCreateProduct) {
                // FIXED: Use AddProductView instead of MerchProductEditView
                AddProductView(bandId: authViewModel.user?.uid ?? "")
                    .environmentObject(authViewModel)
                    .onDisappear {
                        // When the sheet closes, re-fetch the event's products
                        if let id = event.id {
                            viewModel.fetchEventProducts(eventId: id)
                        }
                    }
            }

            .onAppear {
                if let eventId = event.id {
                    viewModel.fetchEventProducts(eventId: eventId)
                }
            }
            .alert(item: Binding<ErrorAlert?>(
                get: { viewModel.error != nil ? ErrorAlert(message: viewModel.error!) : nil },
                set: { _ in viewModel.error = nil }
            )) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    @ViewBuilder
    private func ProductsList() -> some View {
        List {
            Section(header: HStack {
                Text("Products (\(viewModel.products.count))")
                Spacer()
                Button("Add More") {
                    showingAddProducts = true
                }
                .font(.caption)
                .foregroundColor(.cyan)
            }) {
                ForEach(viewModel.products) { product in
                    OriginalEventProductCard(
                        product: product,
                        onRemove: {
                            removeProduct(product)
                        }
                    )
                }
            }
        }
        .refreshable {
            if let eventId = event.id {
                viewModel.fetchEventProducts(eventId: eventId)
            }
        }
    }
    
    @ViewBuilder
    private func EmptyStateView(onAddExisting: @escaping () -> Void, onCreateNew: @escaping () -> Void) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "tag.circle")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Products Added")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add products to your event so fans can discover and purchase your merchandise.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                Button(action: onAddExisting) {
                    Label("Add Existing Products", systemImage: "plus.square.on.square")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan)
                        .cornerRadius(12)
                }
                
                Button(action: onCreateNew) {
                    Label("Create New Product", systemImage: "plus.square")
                        .font(.headline)
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding()
    }
    
    private func removeProduct(_ product: Product) {
        guard let eventId = event.id, let productId = product.id else { return }
        
        viewModel.removeProductFromEvent(productId: productId, eventId: eventId) { success in
            if success {
                // Show success feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
}

// MARK: - Original Event Product Card (Renamed to avoid conflicts)
struct OriginalEventProductCard: View {
    let product: Product
    let onRemove: () -> Void
    @State private var showingRemoveAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Product Image
            AsyncImage(url: URL(string: product.imageUrl)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(ProgressView().scaleEffect(0.8))
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
            
            // Product Details
            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("$\(String(format: "%.2f", product.price))")
                    .font(.subheadline)
                    .foregroundColor(.cyan)
                    .fontWeight(.semibold)
                
                HStack {
                    Text(product.sizes.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(product.totalInventory) in stock")
                        .font(.caption)
                        .foregroundColor(product.totalInventory > 0 ? .green : .red)
                }
            }
            
            Spacer()
            
            // Status indicator
            VStack {
                Circle()
                    .fill(product.active ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(product.active ? "Active" : "Inactive")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Remove button
            Button(action: {
                showingRemoveAlert = true
            }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
        .alert("Remove Product", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("Are you sure you want to remove this product from the event? Fans won't be able to purchase it anymore.")
        }
    }
}

// MARK: - Original Add Products to Event View (Renamed to avoid conflicts)
struct OriginalAddProductsToEventView: View {
    let event: Event
    @ObservedObject var viewModel: EventProductsViewModel
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedProducts: Set<String> = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.availableProducts.isEmpty && !viewModel.isLoading {
                    EmptyAvailableProductsView()
                } else {
                    List {
                        Section(header: Text("Available Products")) {
                            ForEach(viewModel.availableProducts) { product in
                                OriginalSelectableProductRow(
                                    product: product,
                                    isSelected: selectedProducts.contains(product.id ?? "")
                                ) { isSelected in
                                    if let productId = product.id {
                                        if isSelected {
                                            selectedProducts.insert(productId)
                                        } else {
                                            selectedProducts.remove(productId)
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
            .onAppear {
                if let userId = authViewModel.user?.uid, let eventId = event.id {
                    viewModel.fetchMerchantProducts(merchantId: userId, excludingEventId: eventId)
                }
            }
            .overlay(
                Group {
                    if isLoading {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            
                            Text("Adding Products...")
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
    
    @ViewBuilder
    private func EmptyAvailableProductsView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Available Products")
                .font(.headline)
            
            Text("All your products are already added to this event, or you haven't created any products yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
    
    private func addSelectedProducts() {
        guard let eventId = event.id else { return }
        
        isLoading = true
        let group = DispatchGroup()
        var hasError = false
        
        for productId in selectedProducts {
            group.enter()
            viewModel.addProductToEvent(productId: productId, eventId: eventId) { success in
                if !success {
                    hasError = true
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            isLoading = false
            if !hasError {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - Original Selectable Product Row (Renamed to avoid conflicts)
struct OriginalSelectableProductRow: View {
    let product: Product
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                onSelectionChanged(!isSelected)
            }) {
                HStack(spacing: 12) {
                    // Selection indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .cyan : .gray)
                        .font(.title3)
                    
                    // Product image
                    AsyncImage(url: URL(string: product.imageUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .cornerRadius(6)
                                .clipped()
                        default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .cornerRadius(6)
                        }
                    }
                    
                    // Product details
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Text("$\(String(format: "%.2f", product.price))")
                            .font(.caption)
                            .foregroundColor(.cyan)
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}
