import SwiftUI
import FirebaseStorage

struct FavoriteProductsView: View {
    @State private var favoriteProducts: [Product] = []
    @State private var isLoading = true
    @State private var selectedProduct: Product?
    
    var body: some View {
        VStack {
            if isLoading {
                loadingView
            } else if favoriteProducts.isEmpty {
                emptyStateView
            } else {
                // Favorites Grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(favoriteProducts) { product in
                            FavoriteProductCard(product: product) {
                                selectedProduct = product
                            } onRemove: {
                                removeFavorite(product)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Favorite Products")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedProduct) { product in
            // Use a simple product detail view for favorites
            FavoriteProductDetailView(product: product)
        }
        .onAppear {
            loadFavoriteProducts()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
            
            Text("Loading your favorites...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Favorites Yet")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Products you like will appear here. Tap the heart icon on any product to add it to your favorites.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helper Functions
    
    private func loadFavoriteProducts() {
        // Mock data for now - in real app this would load from user's favorites
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            favoriteProducts = [
                Product(
                    id: "fav1",
                    bandId: "band1",
                    title: "Festival T-Shirt",
                    price: 24.99,
                    sizes: ["S", "M", "L", "XL"],
                    inventory: ["S": 5, "M": 10, "L": 8, "XL": 3],
                    imageUrl: "https://example.com/tshirt.jpg",
                    active: true,
                    eventIds: ["event1"]
                ),
                Product(
                    id: "fav2",
                    bandId: "band2",
                    title: "Concert Hoodie",
                    price: 39.99,
                    sizes: ["M", "L", "XL"],
                    inventory: ["M": 2, "L": 5, "XL": 7],
                    imageUrl: "https://example.com/hoodie.jpg",
                    active: true,
                    eventIds: ["event2"]
                )
            ]
            isLoading = false
        }
    }
    
    private func removeFavorite(_ product: Product) {
        favoriteProducts.removeAll { $0.id == product.id }
        // In real app, this would also remove from backend
    }
}

// MARK: - Favorite Product Card

struct FavoriteProductCard: View {
    let product: Product
    let onTap: () -> Void
    let onRemove: () -> Void
    @State private var loadedImage: UIImage?
    @State private var isLoadingImage = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    // Product Image
                    Group {
                        if let image = loadedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 120)
                                .cornerRadius(8)
                                .clipped()
                        } else if isLoadingImage {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 120)
                                .cornerRadius(8)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.8)
                                )
                        } else {
                            Rectangle()
                                .fill(Color.purple.opacity(0.2))
                                .frame(height: 120)
                                .cornerRadius(8)
                                .overlay(
                                    Image(systemName: "tshirt")
                                        .foregroundColor(.purple)
                                        .font(.title)
                                )
                        }
                    }
                    
                    // Remove Heart Button
                    Button(action: onRemove) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                            )
                    }
                    .padding(8)
                }
                
                // Product Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text("$\(String(format: "%.2f", product.price))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    
                    if product.totalInventory > 0 {
                        Text("\(product.totalInventory) available")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else {
                        Text("Out of stock")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadProductImage()
        }
    }
    
    private func loadProductImage() {
        guard !product.imageUrl.isEmpty else { return }
        
        if loadedImage != nil { return }
        
        isLoadingImage = true
        
        if product.imageUrl.contains("firebasestorage.googleapis.com") {
            do {
                let storageRef = Storage.storage().reference(forURL: product.imageUrl)
                storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        self.isLoadingImage = false
                        if let data = data, let image = UIImage(data: data) {
                            self.loadedImage = image
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingImage = false
                }
            }
        }
    }
}

// MARK: - Favorite Product Detail View

struct FavoriteProductDetailView: View {
    let product: Product
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Product details would go here")
                Text("Product: \(product.title)")
                Text("Price: $\(String(format: "%.2f", product.price))")
            }
            .navigationTitle("Product Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}