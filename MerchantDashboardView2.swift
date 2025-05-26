import SwiftUI
import PhotosUI
import Firebase
import FirebaseFirestore

struct MerchantDashboardView: View {
    @StateObject private var productViewModel = ProductViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingAddProduct = false
    @State private var showingCreateEvent = false
    @State private var showingProductDetail: Product? = nil
    @State private var isStoreActive = true
    @State private var errorMessage: String? = nil
    @State private var showingEventsView = false

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
                    Button(action: { showingCreateEvent = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            Text("Create Event")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.cyan)
                        .cornerRadius(10)
                    }

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

                    Button(action: { showingEventsView = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 24))
                                .foregroundColor(.cyan)
                            Text("My Events")
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

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }

                if productViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                } else if productViewModel.products.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tag")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Products Yet")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Add your first product to get started selling at events")
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
                    HStack {
                        Text("Your Products")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(productViewModel.products.count) item\(productViewModel.products.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 5)

                    List {
                        ForEach(productViewModel.products) { product in
                            Button(action: { showingProductDetail = product }) {
                                HStack {
                                    if let url = URL(string: product.imageUrl) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 60, height: 60).cornerRadius(8)
                                            case .success(let image):
                                                image.resizable().aspectRatio(contentMode: .fill).frame(width: 60, height: 60).cornerRadius(8).clipped()
                                            case .failure:
                                                Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 60, height: 60).cornerRadius(8).overlay(Image(systemName: "photo").foregroundColor(.gray))
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                    } else {
                                        Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 60, height: 60).cornerRadius(8).overlay(Image(systemName: "photo").foregroundColor(.gray))
                                    }
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(product.title).font(.headline).lineLimit(1)
                                        Text("$\(String(format: "%.2f", product.price))").font(.subheadline).foregroundColor(.cyan)
                                        Text(product.sizes.joined(separator: ", ")).font(.caption).foregroundColor(.gray).lineLimit(1)
                                        let totalInventory = product.inventory.values.reduce(0, +)
                                        Text("Stock: \(totalInventory)").font(.caption2).foregroundColor(totalInventory > 0 ? .green : .red)
                                    }
                                    .padding(.leading, 5)
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Circle().fill(product.active ? Color.green : Color.gray).frame(width: 12, height: 12)
                                        Text(product.active ? "Active" : "Inactive").font(.caption2).foregroundColor(product.active ? .green : .gray)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Your Store")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingCreateEvent = true }) {
                            Label("Create Event", systemImage: "calendar.badge.plus")
                        }
                        Button(action: { showingAddProduct = true }) {
                            Label("Add Product", systemImage: "plus")
                        }
                        Button(action: { showingEventsView = true }) {
                            Label("My Events", systemImage: "calendar")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
            .sheet(isPresented: $showingCreateEvent) {
                CreateEventView()
            }
            .sheet(isPresented: $showingAddProduct) {
                AddProductView(bandId: getMerchantBandId())
            }
            .sheet(item: $showingProductDetail) { product in
                MerchantProductDetailView(product: product)
            }
            .sheet(isPresented: $showingEventsView) {
                MerchantEventsView()
                    .environmentObject(authViewModel)
            }
            .onAppear {
                loadMerchantProducts()
            }
        }
    }

    func getMerchantBandId() -> String {
        return "mock_band_id"
    }

    func loadMerchantProducts() {
        guard let user = authViewModel.user else {
            errorMessage = "User not logged in"
            return
        }
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                self.errorMessage = "Error fetching user data: \(error.localizedDescription)"
                return
            }
            guard let document = document, document.exists else {
                self.errorMessage = "User document not found"
                return
            }
            let data = document.data() ?? [:]
            var bandIds: [String] = []
            if let bandIdString = data["bandIds"] as? String {
                bandIds = [bandIdString]
            } else if let bandIdArray = data["bandIds"] as? [String] {
                bandIds = bandIdArray
            }
            if bandIds.isEmpty {
                self.errorMessage = "No bands associated with this merchant"
                return
            }
            self.fetchProductsForBands(bandIds: bandIds)
        }
    }

    func fetchProductsForBands(bandIds: [String]) {
        let db = Firestore.firestore()
        productViewModel.isLoading = true
        db.collection("products")
            .whereField("band_id", in: bandIds)
            .getDocuments { snapshot, error in
                productViewModel.isLoading = false
                if let error = error {
                    self.errorMessage = "Error fetching products: \(error.localizedDescription)"
                    return
                }
                guard let documents = snapshot?.documents else {
                    self.productViewModel.products = []
                    return
                }
                self.productViewModel.products = documents.compactMap { document -> Product? in
                    try? document.data(as: Product.self)
                }
            }
    }
}
