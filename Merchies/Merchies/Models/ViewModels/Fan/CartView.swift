import SwiftUI
import Foundation
import FirebaseStorage

struct CartView: View {
    @ObservedObject var cartViewModel: CartViewModel
    @ObservedObject var orderViewModel: OrderViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    let currentEventId: String? // Add current event ID
    @State private var showingPaymentSheet = false
    @State private var showingOrderConfirmation = false
    @State private var newOrderId: String?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if cartViewModel.cartItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "cart")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Your cart is empty")
                            .font(.headline)
                        Text("Add items to your cart to see them here")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    Spacer()
                } else {
                    // Cart items count header
                    HStack {
                        Text("Items in Cart")
                            .font(.headline)
                        Spacer()
                        Text("\(cartViewModel.totalItemCount) item\(cartViewModel.totalItemCount == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.systemGroupedBackground))
                    
                    List {
                        ForEach(cartViewModel.cartItems.indices, id: \.self) { index in
                            EnhancedCartItemRow(
                                item: cartViewModel.cartItems[index],
                                index: index,
                                cartViewModel: cartViewModel
                            )
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                cartViewModel.removeFromCart(at: index)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    
                    VStack(spacing: 15) {
                        HStack {
                            Text("Total:")
                                .font(.headline)
                            Spacer()
                            Text("$\(String(format: "%.2f", cartViewModel.total))")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        
                        Button(action: {
                            processDirectPayment()
                        }) {
                            Text("Checkout")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Your Cart")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !cartViewModel.cartItems.isEmpty {
                        Button("Clear") {
                            cartViewModel.clearCart()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPaymentSheet) {
                StripePaymentView(
                    amount: cartViewModel.total,
                    onCompletion: { result in
                        switch result {
                        case .success(let paymentResult):
                            // Payment successful, create the order
                            if let user = authViewModel.user, let firstItem = cartViewModel.cartItems.first {
                                let bandId = firstItem.product.bandId
                                
                                orderViewModel.createOrder(
                                    from: cartViewModel.cartItems,
                                    userId: user.uid,
                                    bandId: bandId,
                                    eventId: currentEventId,
                                    total: cartViewModel.total,
                                    transactionId: paymentResult.transactionId
                                ) { orderId in
                                    if let orderId = orderId {
                                        print("✅ Legacy flow: Order created successfully: \(orderId)")
                                        newOrderId = orderId
                                        cartViewModel.clearCart()
                                        showingPaymentSheet = false
                                        
                                        // Small delay to ensure proper sheet transition
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            showingOrderConfirmation = true
                                        }
                                    }
                                }
                            }
                        case .failure(let error):
                            // Handle payment failure
                            print("Payment failed: \(error.localizedDescription)")
                            showingPaymentSheet = false
                        }
                    },
                    onCancel: {
                        showingPaymentSheet = false
                    }
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingOrderConfirmation) {
                OrderConfirmationView(orderId: newOrderId ?? "")
                    .onAppear {
                        print("📱 OrderConfirmationView sheet appeared with order ID: \(newOrderId ?? "nil")")
                    }
            }
        }
    }
    
    // Process payment with proper order creation flow
    private func processDirectPayment() {
        guard let user = authViewModel.user, let firstItem = cartViewModel.cartItems.first else {
            print("❌ User not authenticated or cart is empty")
            return
        }
        
        let bandId = firstItem.product.bandId
        
        // Step 1: Create order with "pending_payment" status
        orderViewModel.createOrder(
            from: cartViewModel.cartItems,
            userId: user.uid,
            bandId: bandId,
            eventId: currentEventId,
            total: cartViewModel.total,
            transactionId: nil, // No transaction ID yet
            status: .pendingPayment // New status for unpaid orders
        ) { orderId in
            guard let orderId = orderId else {
                print("❌ Failed to create order")
                return
            }
            
            print("✅ Order created with ID: \(orderId), proceeding to payment")
            
            // Step 2: Process payment with the real order ID
            print("🚀 Processing payment for order: \(orderId)")
            PaymentService.shared.processPayment(amount: cartViewModel.total, orderId: orderId) { result in
                print("🎯 Payment result received in CartView: \(result)")
                DispatchQueue.main.async {
                    switch result {
                    case .success(let paymentResult):
                        print("✅ Payment successful! Transaction ID: \(paymentResult.transactionId)")
                        // Step 3: Update order with transaction ID and mark as paid
                        orderViewModel.updateOrderAfterPayment(
                            orderId: orderId,
                            transactionId: paymentResult.transactionId
                        ) { success in
                            DispatchQueue.main.async {
                                if success {
                                    print("✅ Order updated successfully, showing order confirmation for order: \(orderId)")
                                    newOrderId = orderId
                                    cartViewModel.clearCart()
                                    
                                    // Small delay to ensure proper sheet presentation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        print("📱 Setting showingOrderConfirmation to true")
                                        showingOrderConfirmation = true
                                    }
                                } else {
                                    print("❌ Failed to update order after payment")
                                }
                            }
                        }
                    case .failure(let error):
                        // Step 4: Handle payment failure - mark order as failed
                        print("❌ Payment failed in CartView: \(error.localizedDescription)")
                        orderViewModel.updateOrderStatus(orderId: orderId, status: .cancelled) { _ in
                            // Order marked as cancelled
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Cart Item Row with Product Images
struct EnhancedCartItemRow: View {
    let item: CartItem
    let index: Int
    @ObservedObject var cartViewModel: CartViewModel
    @State private var loadedProductImage: UIImage?
    @State private var isLoadingProductImage = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Product Image
            Group {
                if let loadedImage = loadedProductImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .clipped()
                } else if isLoadingProductImage {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
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
            VStack(alignment: .leading, spacing: 8) {
                // Product name and size
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.product.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text("Size: \(item.size)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Quantity and pricing
                HStack {
                    // Quantity Badge
                    HStack(spacing: 4) {
                        Text("Qty:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(item.quantity)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.purple)
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    Text("$\(String(format: "%.2f", item.product.price * Double(item.quantity)))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
                
                // Price per item
                Text("$\(String(format: "%.2f", item.product.price)) each")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Quantity Controls (moved under pricing)
                HStack(spacing: 12) {
                    // Minus Button - Simple subtract one
                    Button(action: {
                        print("🛒🛒🛒 MINUS BUTTON TAPPED! Index: \(index)")
                        print("🛒 Current quantity: \(item.quantity)")
                        print("🛒 Cart items count: \(cartViewModel.cartItems.count)")
                        cartViewModel.subtractOne(at: index)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("\(item.quantity)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(minWidth: 20)
                    
                    // Plus Button - Simple add one
                    Button(action: {
                        print("🛒🛒🛒 PLUS BUTTON TAPPED! Index: \(index)")
                        print("🛒 Current quantity: \(item.quantity)")
                        print("🛒 Cart items count: \(cartViewModel.cartItems.count)")
                        cartViewModel.addOne(at: index)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.purple)
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadProductImage()
        }
        .onChange(of: item.product.imageUrl) { _ in
            loadProductImage()
        }
    }
    
    private func loadProductImage() {
        guard !item.product.imageUrl.isEmpty else {
            return
        }
        
        // If we already have a loaded image for this URL, don't reload
        if loadedProductImage != nil {
            return
        }
        
        isLoadingProductImage = true
        
        // Safe Firebase Storage loading with URL type detection
        if item.product.imageUrl.contains("firebasestorage.googleapis.com") {
            // Use Firebase Storage reference for Firebase URLs
            do {
                let storageRef = Storage.storage().reference(forURL: item.product.imageUrl)
                storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        self.isLoadingProductImage = false
                        if let error = error {
                            print("Error loading cart item image: \(error.localizedDescription)")
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
            guard let url = URL(string: item.product.imageUrl) else {
                DispatchQueue.main.async {
                    self.isLoadingProductImage = false
                }
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    self.isLoadingProductImage = false
                    if let error = error {
                        print("Error loading cart item image: \(error.localizedDescription)")
                    } else if let data = data, let image = UIImage(data: data) {
                        self.loadedProductImage = image
                    }
                }
            }.resume()
        }
    }
}
