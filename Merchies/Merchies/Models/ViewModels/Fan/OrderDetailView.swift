import SwiftUI
import Foundation
import FirebaseStorage

struct OrderDetailView: View {
    let order: Order
    @Environment(\.presentationMode) private var presentationMode
    @State private var showingQRCode = false
    @State private var productDetails: [String: ProductDetailCache] = [:]
    @State private var isLoadingProducts = false

    // Static formatter to avoid inline `let` bindings
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()
    
    // Cache for product details
    struct ProductDetailCache {
        let title: String
        let imageUrl: String
        let price: Double
        var loadedImage: UIImage?
        var isLoadingImage: Bool = false
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summarySection
                    itemsSection

                    // Show QR-code button only if still pending
                    if order.status == .pendingPickup {
                        Button {
                            showingQRCode = true
                        } label: {
                            HStack {
                                Image(systemName: "qrcode")
                                Text("Show QR Code for Pickup")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Order Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingQRCode) {
                QRCodeSheet(order: order, isPresented: $showingQRCode)
            }
            .onAppear {
                loadProductDetails()
            }
        }
    }

    // MARK: — Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Order Summary")
                .font(.headline)

            summaryRow(
                title: "Order #:",
                // Cast Substring to String here
                value: order.id.map { String($0.suffix(6)) } ?? ""
            )

            summaryRow(
                title: "Date:",
                value: Self.dateFormatter.string(from: order.createdAt)
            )

            HStack {
                Text("Status:")
                Spacer()
                statusBadge(for: order.status)
            }

            summaryRow(
                title: "Total:",
                value: String(format: "$%.2f", order.amount)
            )
            .fontWeight(.bold)

        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    // MARK: — Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items")
                .font(.headline)
                .padding(.horizontal)

            ForEach(order.items, id: \.productId) { item in
                OrderItemRow(
                    item: item,
                    productCache: productDetails[item.productId],
                    onImageLoad: { image in
                        productDetails[item.productId]?.loadedImage = image
                    }
                )
                .padding(.horizontal)
                .id("\(item.productId)_\(productDetails[item.productId]?.imageUrl ?? "")")
            }
        }
    }

    // MARK: — Helpers

    @ViewBuilder
    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
        }
    }

    @ViewBuilder
    private func statusBadge(for status: OrderStatus) -> some View {
        let (bg, fg): (Color, Color) = {
            switch status {
            case .pendingPayment: return (Color.blue.opacity(0.2),   .blue)
            case .pendingPickup:  return (Color.orange.opacity(0.2), .orange)
            case .pickedUp:       return (Color.green.opacity(0.2),  .green)
            case .cancelled:      return (Color.red.opacity(0.2),    .red)
            }
        }()
        Text(status.rawValue
                .capitalized
                .replacingOccurrences(of: "_", with: " "))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bg)
            .foregroundColor(fg)
            .cornerRadius(4)
    }
    
    // MARK: - Product Details Loading
    
    private func loadProductDetails() {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        
        let productIds = Set(order.items.map { $0.productId })
        let firestoreService = FirestoreService()
        let group = DispatchGroup()
        
        for productId in productIds {
            group.enter()
            
            // Fetch full product details to get image URL and latest data
            firestoreService.fetchProductById(productId: productId) { product, error in
                DispatchQueue.main.async {
                    if let product = product {
                        print("✅ Loaded product: \(product.title) with image: \(product.imageUrl)")
                        self.productDetails[productId] = ProductDetailCache(
                            title: product.title,
                            imageUrl: product.imageUrl,
                            price: product.price
                        )
                    } else if let error = error {
                        print("❌ Failed to fetch product \(productId): \(error.localizedDescription)")
                        
                        // Fallback to cached data from order item if available
                        if let orderItem = self.order.items.first(where: { $0.productId == productId }) {
                            self.productDetails[productId] = ProductDetailCache(
                                title: orderItem.productTitle ?? "Product \(String(productId.suffix(6)))",
                                imageUrl: "", // No image URL available
                                price: orderItem.productPrice ?? 0.0
                            )
                        } else {
                            self.productDetails[productId] = ProductDetailCache(
                                title: "Product \(String(productId.suffix(6)))",
                                imageUrl: "",
                                price: 0.0
                            )
                        }
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            self.isLoadingProducts = false
            print("✅ Finished loading all product details")
        }
    }
}

// MARK: - OrderItemRow Component

struct OrderItemRow: View {
    let item: OrderItem
    let productCache: OrderDetailView.ProductDetailCache?
    let onImageLoad: (UIImage) -> Void
    @State private var loadedImage: UIImage?
    @State private var isLoadingImage = false
    @State private var lastImageUrl: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // Product Image
            Group {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .clipped()
                } else if isLoadingImage {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        )
                } else {
                    Rectangle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "tshirt")
                                .foregroundColor(.purple)
                                .font(.title2)
                        )
                }
            }
            
            // Product Details
            VStack(alignment: .leading, spacing: 4) {
                Text(productCache?.title ?? item.productTitle ?? "Product \(String(item.productId.suffix(6)))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack {
                    Text("Size: \(item.size)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("Qty: \(item.qty)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if let price = productCache?.price ?? item.productPrice {
                    HStack {
                        Text("$\(String(format: "%.2f", price)) each")
                            .font(.caption)
                            .foregroundColor(.purple)
                        
                        Spacer()
                        
                        Text("$\(String(format: "%.2f", price * Double(item.qty)))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        .onAppear {
            loadProductImage()
        }
        .onChange(of: productCache?.imageUrl) { newImageUrl in
            // Load image when productCache updates
            if let newUrl = newImageUrl, newUrl != lastImageUrl {
                lastImageUrl = newUrl
                loadedImage = nil // Reset current image
                loadProductImage()
            }
        }
    }
    
    private func loadProductImage() {
        guard let imageUrl = productCache?.imageUrl, !imageUrl.isEmpty else {
            print("🖼️ No image URL available for product \(item.productId)")
            return
        }
        
        if loadedImage != nil && lastImageUrl == imageUrl {
            print("🖼️ Image already loaded for \(item.productId)")
            return
        }
        
        print("🖼️ Loading image for product \(item.productId): \(imageUrl)")
        isLoadingImage = true
        
        // Load image from Firebase Storage or URL
        if imageUrl.contains("firebasestorage.googleapis.com") {
            do {
                let storageRef = Storage.storage().reference(forURL: imageUrl)
                storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        self.isLoadingImage = false
                        if let error = error {
                            print("❌ Error loading Firebase image for \(self.item.productId): \(error.localizedDescription)")
                        } else if let data = data, let image = UIImage(data: data) {
                            print("✅ Successfully loaded Firebase image for \(self.item.productId)")
                            self.loadedImage = image
                            self.onImageLoad(image)
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingImage = false
                    print("❌ Invalid Firebase Storage URL for \(self.item.productId): \(error.localizedDescription)")
                }
            }
        } else {
            guard let url = URL(string: imageUrl) else {
                DispatchQueue.main.async {
                    self.isLoadingImage = false
                    print("❌ Invalid URL for \(self.item.productId): \(imageUrl)")
                }
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    self.isLoadingImage = false
                    if let error = error {
                        print("❌ Error loading URL image for \(self.item.productId): \(error.localizedDescription)")
                    } else if let data = data, let image = UIImage(data: data) {
                        print("✅ Successfully loaded URL image for \(self.item.productId)")
                        self.loadedImage = image
                        self.onImageLoad(image)
                    }
                }
            }.resume()
        }
    }
}


