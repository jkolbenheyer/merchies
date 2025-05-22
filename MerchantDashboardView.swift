import SwiftUI
import PhotosUI

struct MerchantDashboardView: View {
    @StateObject private var productViewModel = ProductViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingAddProduct = false
    @State private var showingProductDetail: Product? = nil
    @State private var isStoreActive = true
    
    var body: some View {
        NavigationView {
            VStack {
                // Store status toggle
                HStack {
                    Text("Store Status:")
                        .font(.headline)
                    
                    Spacer()
                    
                    Toggle("", isOn: $isStoreActive)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                if productViewModel.products.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "tag")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Products Yet")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Add your first product to get started")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        Button(action: {
                            showingAddProduct = true
                        }) {
                            Text("+ Add Product")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(10)
                        }
                        .padding()
                    }
                    .padding(.top, 50)
                } else {
                    // Product list
                    List {
                        ForEach(productViewModel.products) { product in
                            Button(action: {
                                showingProductDetail = product
                            }) {
                                HStack {
                                    // Product image
                                    if let url = URL(string: product.imageUrl) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.2))
                                                    .frame(width: 60, height: 60)
                                                    .cornerRadius(8)
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 60, height: 60)
                                                    .cornerRadius(8)
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
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 60, height: 60)
                                            .cornerRadius(8)
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(product.title)
                                            .font(.headline)
                                        
                                        Text("$\(String(format: "%.2f", product.price))")
                                            .font(.subheadline)
                                            .foregroundColor(.purple)
                                        
                                        // Show available sizes
                                        Text(product.sizes.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.leading, 5)
                                    
                                    Spacer()
                                    
                                    // Status indicator
                                    Circle()
                                        .fill(product.active ? Color.green : Color.gray)
                                        .frame(width: 12, height: 12)
                                }
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .navigationTitle("Your Store")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddProduct = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProduct) {
                AddProductView()
            }
            .sheet(item: $showingProductDetail) { product in
                ProductDetailView(product: product)
            }
            .onAppear {
                // In a real app, you would fetch products for the current merchant
                // For now, we'll just use a placeholder
                if let user = authViewModel.user {
                    // Mock band ID
                    let mockBandId = "band_\(user.uid)"
                    
                    // Fetch products for this band
                    // This would be implemented differently in a real app
                }
            }
        }
    }
}
