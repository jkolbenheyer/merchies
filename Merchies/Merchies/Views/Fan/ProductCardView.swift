import SwiftUI

struct ProductCardView: View {
    let product: Product
    @ObservedObject var cartViewModel: CartViewModel
    @State private var selectedSize: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            imageView

            Text(product.title)
                .font(.headline)
                .foregroundColor(.blue)
                .lineLimit(1)

            Text(String(format: "$%.2f", product.price))
                .font(.subheadline)
                .foregroundColor(.purple)

            sizePicker

            addToCartButton
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }

    @ViewBuilder
    private var imageView: some View {
        // Break complex AsyncImage into subview for better type-checking
        if let url = URL(string: product.imageUrl) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .cornerRadius(8)
                } else {
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .cornerRadius(8)
                }
            }
        } else {
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            }
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var sizePicker: some View {
        HStack(spacing: 8) {
            ForEach(product.sizes, id: \.self) { size in
                Text(size)
                    .font(.caption)
                    .padding(6)
                    .background(selectedSize == size ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                    .cornerRadius(4)
                    .onTapGesture {
                        selectedSize = size
                    }
            }
        }
    }

    private var addToCartButton: some View {
        Button(action: {
            if let size = selectedSize {
                cartViewModel.addToCart(product: product, size: size)
            }
        }) {
            Text("Add to Cart")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(selectedSize == nil)
    }
}
