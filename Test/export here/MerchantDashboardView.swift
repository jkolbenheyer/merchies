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
                } else {
                    List {
                        ForEach(productViewModel.products) { product in
                            Text(product.title)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Your Store")
            .sheet(isPresented: $showingCreateEvent) {
                CreateEventView()
            }
            .sheet(isPresented: $showingAddProduct) {
                AddProductView(bandId: "mock_band_id")
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
            if let bandIdArray = data["bandIds"] as? [String] {
                bandIds = bandIdArray
            }

            if bandIds.isEmpty {
                self.errorMessage = "No bands associated with this merchant"
                return
            }

            fetchProductsForBands(bandIds: bandIds)
        }
    }

    func fetchProductsForBands(bandIds: [String]) {
        let db = Firestore.firestore()
        productViewModel.isLoading = true
        db.collection("products")
            .whereField("band_id", in: bandIds)
            .getDocuments { snapshot, error in
                productViewModel.isLoading = false
                if let documents = snapshot?.documents {
                    productViewModel.products = documents.compactMap {
                        try? $0.data(as: Product.self)
                    }
                }
            }
    }
}
