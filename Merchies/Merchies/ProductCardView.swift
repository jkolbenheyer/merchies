import SwiftUI

struct ProductCardView: View {
    let product: Product
    @State private var selectedSize: String? = nil
    @State private var showDetails: Bool = false
    @ObservedObject var cartViewModel: CartViewModel
    
    var body: some View {
        // Wrap everything in a Button that shows product details
        Button {
            showDetails = true
        } label: {
            VStack(alignment: .leading) {
                // Product image
                if let url = URL(string: product.imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                ProgressView()
                            }
                            .aspectRatio(1, contentMode: .fit)
                            .cornerRadius(8)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(8)
                        case .failure:
                            ZStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            }
                            .aspectRatio(1, contentMode: .fit)
                            .cornerRadius(8)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .cornerRadius(8)
                }
                
                // Product details
                Text(product.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("$\(String(format: "%.2f", product.price))")
                    .font(.subheadline)
                    .foregroundColor(.purple)
                
                // Size selection
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(product.sizes, id: \.self) { size in
                            Button {
                                selectedSize = size
                            } label: {
                                Text(size)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedSize == size ? Color.purple : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedSize == size ? .white : .black)
                                    .cornerRadius(20)
                            }
                            .disabled(product.inventory[size] ?? 0 <= 0)
                            .opacity(product.inventory[size] ?? 0 <= 0 ? 0.3 : 1.0)
                        }
                    }
                }
                .padding(.vertical, 5)
                
                // Add to cart button - Using special button to prevent conflict
                Button {
                    if let size = selectedSize {
                        cartViewModel.addToCart(product: product, size: size)
                    }
                } label: {
                    Text("Add to Cart")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedSize != nil ? Color.purple : Color.gray)
                        .cornerRadius(8)
                }
                .disabled(selectedSize == nil)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .sheet(isPresented: $showDetails) {
            detailViewForProduct()
        }
    }
    
    // Changed return type to concrete View type
    @ViewBuilder
    private func detailViewForProduct() -> some View {
        // Simple placeholder detail view
        // Replace this with your own ProductDetailView when you have one
        NavigationView {
            VStack(spacing: 20) {
                Text(product.title)
                    .font(.title)
                    .fontWeight(.bold)
                
                if let url = URL(string: product.imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 250)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 70))
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .padding()
                }
                
                Text("$\(String(format: "%.2f", product.price))")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("Select Size")
                    .font(.headline)
                    .padding(.top)
                
                // Size selection
                HStack(spacing: 15) {
                    ForEach(product.sizes, id: \.self) { size in
                        Button {
                            selectedSize = size
                        } label: {
                            Text(size)
                                .font(.headline)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(selectedSize == size ? Color.purple : Color.gray.opacity(0.2))
                                .foregroundColor(selectedSize == size ? .white : .black)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.vertical)
                
                Spacer()
                
                // Add to cart button
                Button {
                    if let size = selectedSize {
                        cartViewModel.addToCart(product: product, size: size)
                        showDetails = false
                    }
                } label: {
                    Text("Add to Cart")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedSize != nil ? Color.purple : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(selectedSize == nil)
                .padding()
            }
            .padding()
            .navigationTitle("Product Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        showDetails = false
                    }
                }
            }
        }
    }
}
