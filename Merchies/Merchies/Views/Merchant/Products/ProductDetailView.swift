import SwiftUI
import Foundation

struct ProductDetailView: View {
    let product: Product
    @Environment(\.presentationMode) var presentationMode
    @State private var isEditing = false
    @State private var inventory: [String: String] = [:]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Product Information")) {
                    if let url = URL(string: product.imageUrl) {
                        HStack {
                            Spacer()
                            
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 200)
                                        .cornerRadius(10)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 200)
                                        .cornerRadius(10)
                                case .failure:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 200)
                                        .cornerRadius(10)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                        )
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    
                    HStack {
                        Text("Title")
                        Spacer()
                        Text(product.title)
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Price")
                        Spacer()
                        Text("$\(String(format: "%.2f", product.price))")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(product.active ? "Active" : "Inactive")
                            .foregroundColor(product.active ? .green : .gray)
                    }
                }
                
                Section(header: Text("Inventory")) {
                    ForEach(product.sizes, id: \.self) { size in
                        HStack {
                            Text(size)
                            
                            Spacer()
                            
                            if isEditing {
                                TextField("Quantity", text: Binding(
                                    get: { inventory[size] ?? "\(product.inventory[size] ?? 0)" },
                                    set: { inventory[size] = $0 }
                                ))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            } else {
                                Text("\(product.inventory[size] ?? 0)")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
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
                            // In a real app, you would update the product in Firestore
                            isEditing = false
                        }
                    } else {
                        Button("Edit") {
                            isEditing = true
                            
                            // Initialize inventory with current values
                            for size in product.sizes {
                                inventory[size] = "\(product.inventory[size] ?? 0)"
                            }
                        }
                    }
                }
            }
        }
    }
}
