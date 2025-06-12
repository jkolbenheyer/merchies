import SwiftUI
import Foundation
import FirebaseStorage

struct ScannedOrderDetailView: View {
    // Input parameters
    let order: Order
    let onComplete: () -> Void

    // Local state & services
    @State private var isConfirming = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @StateObject private var orderViewModel = OrderViewModel()
    @Environment(\.presentationMode) private var presentationMode
    
    // Product data for images
    @State private var productDetails: [String: Product] = [:]
    @State private var isLoadingProducts = true

    // Static formatter to avoid `let` inside the body
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()

    var body: some View {
        NavigationView {
            VStack {
                // MARK: — Status Header
                VStack(spacing: 10) {
                    if order.status == .pendingPickup {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("Ready for Pickup")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.bottom, 5)

                    } else if order.status == .pickedUp {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        Text("Already Picked Up")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.bottom, 5)

                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text("Cancelled")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.bottom, 5)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    order.status == .pendingPickup ? Color.orange.opacity(0.1) :
                    order.status == .pickedUp     ? Color.green.opacity(0.1) :
                                                    Color.red.opacity(0.1)
                )
                .cornerRadius(10)
                .padding()

                // MARK: — Order Details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Order #\(order.id?.suffix(6) ?? "")")
                        .font(.headline)

                    Text("Ordered: \(Self.dateFormatter.string(from: order.createdAt))")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    HStack {
                        Text("Total: $\(String(format: "%.2f", order.amount))")
                            .font(.headline)
                        Spacer()
                        Text(order.paymentStatus.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                    }
                    .padding(.top, 5)
                    
                    if let transactionId = order.transactionId {
                        Text("Transaction: \(transactionId.suffix(8).uppercased())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)

                // MARK: — Line Items with Images
                List {
                    Section(header: Text("Order Items (\(order.totalItems) items)")) {
                        if isLoadingProducts {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading product details...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding()
                        } else {
                            ForEach(order.items, id: \.productId) { item in
                                OrderItemRowWithImage(
                                    item: item,
                                    product: productDetails[item.productId]
                                )
                            }
                        }
                    }
                }

                // MARK: — Actions
                if order.status == .pendingPickup {
                    Button("Confirm Pickup") {
                        isConfirming = true
                    }
                    .buttonStyle(ActionButtonStyle(color: .cyan))
                    .padding()

                } else {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                        onComplete()
                    }
                    .buttonStyle(ActionButtonStyle(color: .gray))
                    .padding()
                }
            }
            .navigationTitle("Order Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                        onComplete()
                    }
                }
            }
            .onAppear {
                loadProductDetails()
            }
            .alert(isPresented: $isConfirming) {
                Alert(
                    title: Text("Confirm Pickup"),
                    message: Text("Are you sure you want to mark this order as picked up?"),
                    primaryButton: .default(Text("Yes")) {
                        guard let orderId = order.id, !orderId.isEmpty else {
                            print("❌ ScannedOrderDetailView: Cannot update order - missing or empty order ID")
                            // Show error to user
                            DispatchQueue.main.async {
                                self.errorMessage = "Error: Order ID is missing. Please try scanning the QR code again."
                                self.showingError = true
                            }
                            return
                        }
                        
                        print("🔄 ScannedOrderDetailView: Updating order status for orderId: \(orderId)")
                        orderViewModel.updateOrderStatus(
                            orderId: orderId,
                            status: .pickedUp
                        ) { success in
                            if success {
                                print("✅ ScannedOrderDetailView: Order status updated successfully")
                                // Haptic feedback
                                UINotificationFeedbackGenerator()
                                    .notificationOccurred(.success)

                                // Dismiss & notify parent
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    presentationMode.wrappedValue.dismiss()
                                    onComplete()
                                }
                            } else {
                                print("❌ ScannedOrderDetailView: Failed to update order status")
                                DispatchQueue.main.async {
                                    self.errorMessage = "Failed to update order status. Please try again."
                                    self.showingError = true
                                }
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Product Loading
    
    private func loadProductDetails() {
        let productIds = Array(Set(order.items.map { $0.productId }))
        print("🔍 ScannedOrderDetailView: Loading products for IDs: \(productIds)")
        
        let firestoreService = FirestoreService()
        
        let group = DispatchGroup()
        var loadedProducts: [String: Product] = [:]
        
        for productId in productIds {
            group.enter()
            print("🔄 ScannedOrderDetailView: Fetching product \(productId)")
            firestoreService.fetchProductById(productId: productId) { product, error in
                defer { group.leave() }
                
                if let product = product {
                    print("✅ ScannedOrderDetailView: Loaded product \(productId): \(product.title)")
                    print("🖼️ ScannedOrderDetailView: Product image URL: \(product.imageUrl)")
                    loadedProducts[productId] = product
                } else {
                    print("❌ ScannedOrderDetailView: Failed to load product \(productId): \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
        
        group.notify(queue: .main) {
            print("📦 ScannedOrderDetailView: Finished loading \(loadedProducts.count) products")
            self.productDetails = loadedProducts
            self.isLoadingProducts = false
        }
    }
}

// MARK: - Order Item Row with Product Image
struct OrderItemRowWithImage: View {
    let item: OrderItem
    let product: Product?
    @State private var loadedProductImage: UIImage?
    @State private var isLoadingImage = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Product Image
            Group {
                if let loadedImage = loadedProductImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(12)
                        .clipped()
                } else if isLoadingImage {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .cornerRadius(12)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                        )
                } else {
                    Rectangle()
                        .fill(Color.cyan.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .cornerRadius(12)
                        .overlay(
                            Image(systemName: "tshirt.fill")
                                .font(.title2)
                                .foregroundColor(.cyan)
                        )
                }
            }
            
            // Product Details
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.productTitle ?? product?.title ?? "Product \(item.productId.suffix(6))")
                        .font(.headline)
                        .lineLimit(2)
                    Spacer()
                    
                    // Quantity badge
                    Text("×\(item.qty)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.cyan)
                        .cornerRadius(20)
                }
                
                HStack {
                    Text("Size: \(item.size)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    if let price = item.productPrice {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$\(String(format: "%.2f", price)) each")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("$\(String(format: "%.2f", item.totalPrice))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.cyan)
                        }
                    }
                }
                
                // Additional product info if available
                if let product = product {
                    HStack {
                        if !product.availableSizes.isEmpty {
                            Text("Available: \(product.availableSizes.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if product.totalInventory > 0 {
                            Text("\(product.totalInventory) in stock")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadProductImage()
        }
        .onChange(of: product?.imageUrl) { _ in
            loadProductImage()
        }
        .onChange(of: product?.id) { _ in
            // Reload image when product data becomes available
            loadProductImage()
        }
    }
    
    private func loadProductImage() {
        print("🔄 OrderItemRowWithImage: loadProductImage called for product \(item.productId)")
        print("🔄 OrderItemRowWithImage: Product available: \(product != nil)")
        print("🔄 OrderItemRowWithImage: Product title: \(product?.title ?? "nil")")
        print("🔄 OrderItemRowWithImage: Product imageUrl: \(product?.imageUrl ?? "nil")")
        
        guard let imageUrl = product?.imageUrl, !imageUrl.isEmpty else {
            print("🖼️ OrderItemRowWithImage: No image URL for product \(item.productId)")
            return
        }
        
        print("🖼️ OrderItemRowWithImage: Loading image from URL: \(imageUrl)")
        
        // If we already have a loaded image for this URL, don't reload
        if loadedProductImage != nil {
            print("🖼️ OrderItemRowWithImage: Image already loaded, skipping")
            return
        }
        
        isLoadingImage = true
        
        // Safe Firebase Storage loading with URL type detection
        if imageUrl.contains("firebasestorage.googleapis.com") {
            // Use Firebase Storage reference for Firebase URLs
            do {
                let storageRef = Storage.storage().reference(forURL: imageUrl)
                storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        self.isLoadingImage = false
                        if let error = error {
                            print("❌ OrderItemRowWithImage: Error loading Firebase image: \(error.localizedDescription)")
                        } else if let data = data, let image = UIImage(data: data) {
                            print("✅ OrderItemRowWithImage: Successfully loaded Firebase image")
                            self.loadedProductImage = image
                        } else {
                            print("❌ OrderItemRowWithImage: No data received from Firebase")
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingImage = false
                    print("Invalid Firebase Storage URL: \(error.localizedDescription)")
                }
            }
        } else {
            // Use URLSession for regular HTTP URLs
            guard let url = URL(string: imageUrl) else {
                DispatchQueue.main.async {
                    self.isLoadingImage = false
                }
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    self.isLoadingImage = false
                    if let error = error {
                        print("❌ OrderItemRowWithImage: Error loading URL image: \(error.localizedDescription)")
                    } else if let data = data, let image = UIImage(data: data) {
                        print("✅ OrderItemRowWithImage: Successfully loaded URL image")
                        self.loadedProductImage = image
                    } else {
                        print("❌ OrderItemRowWithImage: No data received from URL")
                    }
                }
            }.resume()
        }
    }
}

// MARK: — Reusable button style
private struct ActionButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
