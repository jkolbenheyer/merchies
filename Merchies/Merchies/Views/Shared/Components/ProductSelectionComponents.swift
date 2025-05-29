// Product Selection Components for Event Management

import SwiftUI
import Foundation

// MARK: - SelectableProductRow
struct SelectableProductRow: View {
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
                        .foregroundColor(isSelected ? .purple : .gray)
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
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                )
                        }
                    }
                    
                    // Product details
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        Text("$\(String(format: "%.2f", product.price))")
                            .font(.caption)
                            .foregroundColor(.purple)
                            .fontWeight(.semibold)
                        
                        if !product.sizes.isEmpty {
                            Text("Sizes: \(product.sizes.joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Stock indicator
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(product.totalInventory)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(product.totalInventory > 0 ? .green : .red)
                        
                        Text("in stock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - EventProductCard
struct EventProductCard: View {
    let product: Product
    let onRemove: () -> Void
    @State private var showingRemoveAlert = false
    @State private var showingProductDetail = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Product Image
            AsyncImage(url: URL(string: product.imageUrl)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .cornerRadius(AppConstants.UI.standardCornerRadius)
                        .overlay(ProgressView().scaleEffect(0.8))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .cornerRadius(AppConstants.UI.standardCornerRadius)
                        .clipped()
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .cornerRadius(AppConstants.UI.standardCornerRadius)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .onTapGesture {
                showingProductDetail = true
            }
            
            // Product Details
            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("$\(String(format: "%.2f", product.price))")
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)
                
                HStack {
                    if !product.sizes.isEmpty {
                        Text(product.sizes.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(product.totalInventory) in stock")
                        .font(.caption)
                        .foregroundColor(product.totalInventory > 0 ? .green : .red)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            // Status and Actions
            VStack(spacing: 8) {
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
        .sheet(isPresented: $showingProductDetail) {
            ProductDetailSheet(product: product)
        }
    }
}

// MARK: - Product Detail Sheet
struct ProductDetailSheet: View {
    let product: Product
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Product Image
                    AsyncImage(url: URL(string: product.imageUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(AppConstants.UI.cardCornerRadius)
                        default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 300)
                                .cornerRadius(AppConstants.UI.cardCornerRadius)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Product Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text(product.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("$\(String(format: "%.2f", product.price))")
                                .font(.title3)
                                .foregroundColor(.purple)
                                .fontWeight(.semibold)
                        }
                        
                        // Status
                        HStack {
                            Text("Status:")
                                .font(.headline)
                            
                            Text(product.active ? "Active" : "Inactive")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(product.active ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                .foregroundColor(product.active ? .green : .orange)
                                .cornerRadius(AppConstants.UI.standardCornerRadius)
                        }
                        
                        // Sizes and Inventory
                        if !product.sizes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Inventory")
                                    .font(.headline)
                                
                                ForEach(product.sizes, id: \.self) { size in
                                    HStack {
                                        Text("Size \(size):")
                                            .font(.subheadline)
                                        
                                        Spacer()
                                        
                                        Text("\(product.inventory[size] ?? 0) available")
                                            .font(.subheadline)
                                            .foregroundColor(
                                                (product.inventory[size] ?? 0) > 0 ? .green : .red
                                            )
                                            .fontWeight(.medium)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(AppConstants.UI.cardCornerRadius)
                        }
                        
                        // Total Inventory
                        HStack {
                            Text("Total Stock:")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(product.totalInventory) items")
                                .font(.headline)
                                .foregroundColor(product.totalInventory > 0 ? .green : .red)
                                .fontWeight(.bold)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(AppConstants.UI.cardCornerRadius)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Product Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Product Grid Item (Alternative compact view)
struct ProductGridItem: View {
    let product: Product
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    
    var body: some View {
        VStack {
            // Selection overlay
            ZStack(alignment: .topTrailing) {
                // Product image
                AsyncImage(url: URL(string: product.imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .cornerRadius(AppConstants.UI.cardCornerRadius)
                            .clipped()
                    default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .cornerRadius(AppConstants.UI.cardCornerRadius)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                }
                
                // Selection indicator
                Button(action: {
                    onSelectionChanged(!isSelected)
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .purple : .white)
                        .background(
                            Circle()
                                .fill(isSelected ? Color.white : Color.black.opacity(0.5))
                                .frame(width: 20, height: 20)
                        )
                        .font(.system(size: 16))
                }
                .padding(8)
            }
            
            // Product details
            VStack(alignment: .leading, spacing: 2) {
                Text(product.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("$\(String(format: "%.2f", product.price))")
                    .font(.caption2)
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 120)
    }
}

// MARK: - Quick Add Product Button
struct QuickAddProductButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.dashed")
                    .font(.system(size: 40))
                    .foregroundColor(.purple)
                
                Text("Add Product")
                    .font(.caption)
                    .foregroundColor(.purple)
                    .fontWeight(.medium)
            }
            .frame(width: 120, height: 120)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(AppConstants.UI.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
        }
    }
}

// MARK: - Product Summary Card
struct ProductSummaryCard: View {
    let products: [Product]
    
    var totalProducts: Int { products.count }
    var totalInventory: Int { products.reduce(0) { $0 + $1.totalInventory } }
    var activeProducts: Int { products.filter { $0.active }.count }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Product Summary")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            HStack(spacing: 20) {
                SummaryItem(
                    title: "Total",
                    value: "\(totalProducts)",
                    color: .blue
                )
                
                SummaryItem(
                    title: "Active",
                    value: "\(activeProducts)",
                    color: .green
                )
                
                SummaryItem(
                    title: "Stock",
                    value: "\(totalInventory)",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppConstants.UI.cardCornerRadius)
    }
}

// MARK: - Summary Item
struct SummaryItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
