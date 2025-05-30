import SwiftUI
import Foundation

struct CartView: View {
    @ObservedObject var cartViewModel: CartViewModel
    @ObservedObject var orderViewModel: OrderViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingPaymentSheet = false
    @State private var showingOrderConfirmation = false
    @State private var newOrderId: String?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
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
                    List {
                        ForEach(Array(cartViewModel.cartItems.enumerated()), id: \.element.id) { index, item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.product.title)
                                        .font(.headline)
                                    Text("Size: \(item.size)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("$\(String(format: "%.2f", item.product.price * Double(item.quantity)))")
                                        .fontWeight(.semibold)
                                    
                                    Stepper("\(item.quantity)", value: Binding(
                                        get: { item.quantity },
                                        set: { cartViewModel.updateQuantity(at: index, quantity: $0) }
                                    ), in: 1...10)
                                    .labelsHidden()
                                    .frame(width: 100)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                cartViewModel.removeFromCart(at: index)
                            }
                        }
                    }
                    
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
                            showingPaymentSheet = true
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !cartViewModel.cartItems.isEmpty {
                        Button("Clear") {
                            cartViewModel.clearCart()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPaymentSheet) {
                // In a real app, you would integrate with Stripe SDK here
                VStack {
                    Text("Payment Processing")
                        .font(.title)
                        .padding()
                    
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    
                    Text("This is a simulated payment flow")
                        .foregroundColor(.gray)
                        .padding()
                    
                    Button("Complete Payment") {
                        if let user = authViewModel.user, let firstItem = cartViewModel.cartItems.first {
                            // Use the first item's band ID for the order
                            let bandId = firstItem.product.bandId
                            
                            // Create the order
                            orderViewModel.createOrder(
                                from: cartViewModel.cartItems,
                                userId: user.uid,
                                bandId: bandId,
                                total: cartViewModel.total
                            ) { orderId in
                                if let orderId = orderId {
                                    newOrderId = orderId
                                    showingOrderConfirmation = true
                                    showingPaymentSheet = false
                                    cartViewModel.clearCart()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding()
                    
                    Button("Cancel") {
                        showingPaymentSheet = false
                    }
                    .padding()
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingOrderConfirmation) {
                OrderConfirmationView(orderId: newOrderId ?? "")
            }
        }
    }
}
