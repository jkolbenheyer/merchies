import SwiftUI
import PhotosUI
import Firebase
import FirebaseFirestore

struct MerchantDashboardView: View {
    @StateObject private var productViewModel = ProductViewModel()
    @StateObject private var eventViewModel = EventViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingAddProduct = false
    @State private var showingCreateEvent = false
    @State private var showingEventsList = false
    @State private var showingProductDetail: Product? = nil
    @State private var isStoreActive = true
    @State private var errorMessage: String? = nil
    
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
                        .toggleStyle(SwitchToggleStyle(tint: .cyan))
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Quick Actions Section
                HStack(spacing: 15) {
                    // Manage Events Button
                    Button(action: { showingEventsList = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            Text("Manage Events")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.cyan)
                        .cornerRadius(10)
                    }
                    // Add Product Button
                    Button(action: { showingAddProduct = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 24))
                                .foregroundColor(.cyan)
                            Text("Add Product")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.cyan)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.cyan.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                
                // Stats Overview Section
                if !eventViewModel.events.isEmpty || !productViewModel.products.isEmpty {
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(eventViewModel.events.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.cyan)
                            Text("Events")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Divider().frame(height: 30)
                        VStack {
                            Text("\(productViewModel.products.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.cyan)
                            Text("Products")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Divider().frame(height: 30)
                        VStack {
                            let totalStock = productViewModel.products.reduce(0) { $0 + $1.totalInventory }
                            Text("\(totalStock)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.cyan)
                            Text("Total Stock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.cyan.opacity(0.05))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                if productViewModel.isLoading || eventViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                } else if productViewModel.products.isEmpty && eventViewModel.events.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "storefront")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Welcome to MerchPit!")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Start by creating an event and adding products to build your mobile merch store")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        VStack(spacing: 12) {
                            Button(action: { showingCreateEvent = true }) {
                                HStack {
                                    Image(systemName: "calendar.badge.plus")
                                    Text("Create Your First Event")
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.cyan)
                                .cornerRadius(10)
                            }
                            Button(action: { showingAddProduct = true }) {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("Add Your First Product")
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.cyan)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.cyan.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 30)
                } else {
                    // Content
                    ScrollView {
                        VStack(spacing: 20) {
                            if !eventViewModel.events.isEmpty { EventsSection() }
                            if !productViewModel.products.isEmpty { ProductsSection() }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Your Store")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingEventsList = true }) { Label("Manage Events", systemImage: "calendar") }
                        Button(action: { showingCreateEvent = true }) { Label("Create Event", systemImage: "calendar.badge.plus") }
                        Divider()
                        Button(action: { showingAddProduct = true }) { Label("Add Product", systemImage: "plus") }
                    } label: {
                        Image(systemName: "plus").font(.system(size: 18, weight: .medium))
                    }
                }
            }
            .sheet(isPresented: $showingCreateEvent, onDismiss: loadMerchantData) { CreateEventView() }
            .sheet(isPresented: $showingEventsList, onDismiss: loadMerchantData) { EventsListView() }
            .sheet(isPresented: $showingAddProduct, onDismiss: loadMerchantProducts) { MerchProductEditView(bandId: getMerchantBandId()) }
            .sheet(item: $showingProductDetail) { product in
                MerchantProductDetailView(product: product)
            }
            .onAppear(perform: loadMerchantData)
            .refreshable { loadMerchantData() }
        }
    }
    
    // MARK: - Events Section
    @ViewBuilder
    private func EventsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Events")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(eventViewModel.events.count) item\(eventViewModel.events.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            LazyVStack(spacing: 8) {
                ForEach(eventViewModel.events) { event in
                    Button(action: { showingEventsList = true }) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(event.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text("\(formatDateTime(event.startDate)) - \(formatDateTime(event.endDate))")
                                Spacer()
                                Text("\(event.productIds.count) products")
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Image(systemName: "location")
                                Text(event.address)
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Products Section
    @ViewBuilder
    private func ProductsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Products")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(productViewModel.products.count) item\(productViewModel.products.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            LazyVStack(spacing: 8) {
                ForEach(productViewModel.products) { product in
                    ProductRow(product: product) { showingProductDetail = product }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func getMerchantBandId() -> String {
        return authViewModel.user?.uid ?? "mock_band_id"
    }
    func loadMerchantData() {
        guard let user = authViewModel.user else { errorMessage = "User not logged in"; return }
        eventViewModel.fetchMerchantEvents(merchantId: user.uid)
        loadMerchantProducts()
    }
    func loadMerchantProducts() {
        guard let user = authViewModel.user else { errorMessage = "User not logged in"; return }
        let db = Firestore.firestore()
        productViewModel.isLoading = true
        db.collection("products").whereField("band_id", isEqualTo: user.uid)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    productViewModel.isLoading = false
                    if let error = error {
                        errorMessage = "Error fetching products: \(error.localizedDescription)"
                        return
                    }
                    productViewModel.products = snapshot?.documents.compactMap {
                        try? $0.data(as: Product.self)
                    } ?? []
                }
            }
    }
}




// MARK: - ProductRow Component
struct ProductRow: View {
    let product: Product
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: product.imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .overlay(ProgressView().scaleEffect(0.7))
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Text("$\(String(format: "%.2f", product.price))")
                            .font(.caption)
                            .foregroundColor(.cyan)
                            .fontWeight(.semibold)

                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(product.totalInventory) in stock")
                            .font(.caption)
                            .foregroundColor(product.totalInventory > 0 ? .green : .red)

                        Spacer()

                        if !product.eventIds.isEmpty {
                            Text("\(product.eventIds.count) events")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.1))
                                .foregroundColor(.cyan)
                                .cornerRadius(4)
                        }
                    }

                    Text(product.availableSizes.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                VStack {
                    Circle()
                        .fill(product.active ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
