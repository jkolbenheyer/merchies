// Updated ProductCardView.swift with horizontal scrollable sizes
import SwiftUI
import Foundation
import FirebaseStorage

struct ProductCardView: View {
    let product: Product
    @ObservedObject var cartViewModel: CartViewModel
    @State private var selectedSizes: Set<String> = [] // Just selected sizes, no quantities
    @State private var loadedProductImage: UIImage?
    @State private var isLoadingProductImage = false
    @State private var showingAddedConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            imageView

            Text(product.title)
                .font(.headline)
                .foregroundColor(.blue)
                .lineLimit(1)

            Text(String(format: "$%.2f", product.price))
                .font(.subheadline)
                .foregroundColor(.purple)

            sizesWithQuantityPicker

            Spacer(minLength: 4)
            
            addToCartButton
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .top)
        .onAppear {
            loadProductImage()
            debugProductInfo()
        }
        .onChange(of: product.imageUrl) { _ in
            loadProductImage()
        }
    }

    @ViewBuilder
    private var imageView: some View {
        // Product image with Firebase Storage support
        Group {
            if let loadedImage = loadedProductImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .cornerRadius(8)
                    .clipped()
            } else if isLoadingProductImage {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                }
                .aspectRatio(1, contentMode: .fill)
                .cornerRadius(8)
                .clipped()
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.purple.opacity(0.2))
                    Image(systemName: "tshirt")
                        .font(.largeTitle)
                        .foregroundColor(.purple)
                }
                .aspectRatio(1, contentMode: .fill)
                .cornerRadius(8)
                .clipped()
            }
        }
    }

    @ViewBuilder
    private var sizesWithQuantityPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Instructions for user - Fixed height container
            VStack(alignment: .leading) {
                let availableSizes = product.sizes.filter { size in
                    let inventory = product.inventory[size] ?? 0
                    return inventory > 0
                }
                
                if availableSizes.isEmpty {
                    Text("Out of stock")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                } else if selectedSizes.isEmpty {
                    Text("Tap sizes to select:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(0.8)
                } else {
                    Text("Selected: \(selectedSizes.count) size\(selectedSizes.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .fontWeight(.medium)
                }
            }
            .frame(height: 16, alignment: .leading)
            
            // Compact horizontal scroll view similar to original
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(product.sizes
                        .filter { size in
                            let inventory = product.inventory[size] ?? 0
                            return inventory > 0
                        }
                        .sorted { lhs, rhs in
                            // Custom sorting for clothing sizes
                            let sizeOrder = ["XXS", "XS", "S", "M", "L", "XL", "XXL", "XXXL"]
                            let lhsIndex = sizeOrder.firstIndex(of: lhs) ?? Int.max
                            let rhsIndex = sizeOrder.firstIndex(of: rhs) ?? Int.max
                            if lhsIndex != Int.max && rhsIndex != Int.max {
                                return lhsIndex < rhsIndex
                            }
                            return lhs < rhs // Fallback to alphabetical
                        }, id: \.self) { size in
                        compactSizeButton(for: size)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 32) // Slightly taller than original to accommodate quantity
        }
    }
    
    @ViewBuilder
    private func compactSizeButton(for size: String) -> some View {
        let isSelected = selectedSizes.contains(size)
        
        Button(action: {
            print("👆 Size button tapped: \(size) for \(product.title)")
            print("👆 Available inventory for \(size): \(product.inventory[size] ?? 0)")
            
            // Simple toggle selection
            if isSelected {
                selectedSizes.remove(size)
                print("👆 Deselected \(size)")
            } else {
                selectedSizes.insert(size)
                print("👆 Selected \(size)")
            }
        }) {
            Text(size)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isSelected ? Color.blue : Color.gray.opacity(0.4),
                            lineWidth: 1
                        )
                )
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var addToCartButton: some View {
        VStack(spacing: 4) {
            if showingAddedConfirmation {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Added to Cart!")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            } else {
                Button(action: addSelectedItemsToCart) {
                    HStack {
                        let availableSizes = product.sizes.filter { size in
                            let inventory = product.inventory[size] ?? 0
                            return inventory > 0
                        }
                        
                        if availableSizes.isEmpty {
                            Text("Out of Stock")
                        } else if selectedSizes.isEmpty {
                            Text("Select Size")
                        } else {
                            Text("Add to Cart")
                            Text("(\(selectedSizes.count))")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .disabled({
                    let availableSizes = product.sizes.filter { size in
                        let inventory = product.inventory[size] ?? 0
                        return inventory > 0
                    }
                    return selectedSizes.isEmpty || availableSizes.isEmpty
                }())
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func addSelectedItemsToCart() {
        print("🛒 === ADD TO CART CALLED for \(product.title) ===")
        print("🛒 Selected sizes: \(Array(selectedSizes))")
        
        if selectedSizes.isEmpty {
            print("🛒 ❌ No sizes selected!")
            return
        }
        
        var totalItemsAdded = 0
        
        // Add each selected size (quantity 1) to cart
        for size in selectedSizes {
            print("🛒 Processing size \(size) of \(product.title)")
            
            // Check if we have inventory before adding
            let availableInventory = product.inventory[size] ?? 0
            let currentCartQuantity = cartViewModel.cartItems
                .filter { $0.product.id == product.id && $0.size == size }
                .reduce(0) { $0 + $1.quantity }
            
            let canAdd = availableInventory > currentCartQuantity
            
            print("🛒 Available: \(availableInventory), In cart: \(currentCartQuantity), Can add: \(canAdd)")
            
            if !canAdd {
                print("🛒 ❌ Cannot add size \(size) - no inventory or already at max")
                continue
            }
            
            // Add one item of this size to cart
            cartViewModel.addToCart(product: product, size: size)
            totalItemsAdded += 1
        }
        
        print("🛒 Total items added: \(totalItemsAdded)")
        print("🛒 Cart now has \(cartViewModel.cartItems.count) items, total quantity: \(cartViewModel.totalItemCount)")
        
        if totalItemsAdded > 0 {
            // Show confirmation
            withAnimation(.easeInOut(duration: 0.3)) {
                showingAddedConfirmation = true
            }
            
            // Clear selections and hide confirmation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingAddedConfirmation = false
                    selectedSizes.removeAll()
                }
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        } else {
            print("🛒 ❌ No items were added to cart!")
        }
    }
    
    private func loadProductImage() {
        guard !product.imageUrl.isEmpty else {
            return
        }
        
        // If we already have a loaded image for this URL, don't reload
        if loadedProductImage != nil {
            return
        }
        
        isLoadingProductImage = true
        
        // Safe Firebase Storage loading with URL type detection
        if product.imageUrl.contains("firebasestorage.googleapis.com") {
            // Use Firebase Storage reference for Firebase URLs
            do {
                let storageRef = Storage.storage().reference(forURL: product.imageUrl)
                storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        self.isLoadingProductImage = false
                        if let error = error {
                            print("Error loading product image: \(error.localizedDescription)")
                        } else if let data = data, let image = UIImage(data: data) {
                            self.loadedProductImage = image
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingProductImage = false
                    print("Invalid Firebase Storage URL: \(error.localizedDescription)")
                }
            }
        } else {
            // Use URLSession for regular HTTP URLs
            guard let url = URL(string: product.imageUrl) else {
                DispatchQueue.main.async {
                    self.isLoadingProductImage = false
                }
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    self.isLoadingProductImage = false
                    if let error = error {
                        print("Error loading product image: \(error.localizedDescription)")
                    } else if let data = data, let image = UIImage(data: data) {
                        self.loadedProductImage = image
                    }
                }
            }.resume()
        }
    }
    
    private func debugProductInfo() {
        print("🛍️ Product: \(product.title)")
        print("🛍️ Sizes: \(product.sizes)")
        print("🛍️ Inventory: \(product.inventory)")
        print("🛍️ Total inventory: \(product.totalInventory)")
        print("🛍️ Available sizes: \(product.availableSizes)")
        print("🛍️ Active: \(product.active)")
    }
}
