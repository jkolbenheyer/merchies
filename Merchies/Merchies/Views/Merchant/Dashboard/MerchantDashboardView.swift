import SwiftUI
import PhotosUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import Foundation

struct MerchantDashboardView: View {
    @StateObject private var productViewModel = ProductViewModel()
    @StateObject private var eventViewModel = EventViewModel()
    @StateObject private var orderNotificationService = OrderNotificationService()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingAddProduct = false
    @State private var showingCreateEvent = false
    @State private var showingEventsList = false
    @State private var showingProductDetail: Product? = nil
    @State private var showingEditEvent: Event? = nil
    @State private var isStoreActive = true
    @State private var errorMessage: String? = nil
    @State private var showArchivedEvents = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Order Alert Banner
                OrderAlertBanner(notificationService: orderNotificationService)
                    .padding(.horizontal)
                    .padding(.top, orderNotificationService.hasNewOrders ? 8 : 0)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Quick Stats Section
                        if orderNotificationService.recentOrders.count > 0 {
                            quickStatsSection
                        }
                        
                        // Quick Actions Section
                        quickActionsSection
                        
                        // Error Message
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                        }
                        
                        // Loading or Content
                        if productViewModel.isLoading || eventViewModel.isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                        } else if productViewModel.products.isEmpty && eventViewModel.events.isEmpty {
                            emptyStateSection
                        } else {
                            // Content
                            if !eventViewModel.events.isEmpty { EventsSection() }
                            if !productViewModel.products.isEmpty { ProductsSection() }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Your Stuff")
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink("Design") {
                        EnhancedDesignSystemPreview()
                    }
                }
            }
            .sheet(isPresented: $showingCreateEvent, onDismiss: loadMerchantData) { CreateEventView() }
            .sheet(isPresented: $showingEventsList, onDismiss: loadMerchantData) { EventsListView() }
            .sheet(isPresented: $showingAddProduct, onDismiss: loadMerchantProducts) {
                AddProductView(bandId: getMerchantBandId())
            }
            .sheet(item: $showingProductDetail) { product in
                MerchantProductDetailView(product: product) {
                    loadMerchantProducts()
                }
            }
            .sheet(item: $showingEditEvent) { event in
                EditEventView(vm: SingleEventViewModel(event: event))
                    .onDisappear {
                        loadMerchantData()
                    }
            }
            .onAppear(perform: {
                loadMerchantData()
                startOrderNotifications()
            })
            .onDisappear {
                orderNotificationService.stopListening()
            }
            .refreshable { loadMerchantData() }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredEvents: [Event] {
        if showArchivedEvents {
            return eventViewModel.events
        } else {
            return eventViewModel.events.filter { !$0.archived }
        }
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        HStack {
            NavigationLink(destination: MerchantOrdersView(initialFilter: .todaysOrders)) {
                OrderStatCard(
                    title: "Today's Orders",
                    value: "\(orderNotificationService.todaysOrdersCount)",
                    icon: "bag.fill",
                    color: .blue
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            NavigationLink(destination: MerchantOrdersView(initialFilter: .pendingPickup)) {
                OrderStatCard(
                    title: "Pending",
                    value: "\(orderNotificationService.pendingOrdersCount)",
                    icon: "clock.fill",
                    color: .orange
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            NavigationLink(destination: MerchantOrdersView(initialFilter: .todaysCompleted)) {
                OrderStatCard(
                    title: "Today's Revenue",
                    value: "$\(String(format: "%.0f", orderNotificationService.todaysRevenue))",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 15) {
                // Manage Events Button
                Button(action: { showingCreateEvent = true }) {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                        Text("Add Event")
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
        }
    }
    
    // MARK: - Empty State Section
    
    private var emptyStateSection: some View {
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
    }
    
    // MARK: - Helper Functions
    
    private func startOrderNotifications() {
        guard let user = authViewModel.user else { return }
        orderNotificationService.startListening(for: user.uid)
    }
    
    private func loadMerchantData() {
        guard let user = authViewModel.user else { 
            errorMessage = "User not logged in"
            return 
        }
        eventViewModel.fetchMerchantEvents(merchantId: user.uid)
        loadMerchantProducts()
    }
    
    func getMerchantBandId() -> String {
        return authViewModel.user?.uid ?? "mock_band_id"
    }
    
    func loadMerchantProducts() {
        guard let user = authViewModel.user else { 
            errorMessage = "User not logged in"
            return 
        }
        let db = Firestore.firestore()
        productViewModel.isLoading = true
        db.collection("products").whereField("band_id", isEqualTo: user.uid)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.productViewModel.isLoading = false
                    if let error = error {
                        self.errorMessage = "Error fetching products: \(error.localizedDescription)"
                        return
                    }
                    self.productViewModel.products = snapshot?.documents.compactMap {
                        try? $0.data(as: Product.self)
                    } ?? []
                }
            }
    }
    
    // MARK: - Enhanced Events Section with Images
    @ViewBuilder
    private func EventsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Events")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                // Archive toggle
                Button(action: {
                    showArchivedEvents.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showArchivedEvents ? "archivebox.fill" : "archivebox")
                            .font(.caption)
                        Text(showArchivedEvents ? "Hide Archived" : "Show Archived")
                            .font(.caption)
                    }
                    .foregroundColor(showArchivedEvents ? .orange : .purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((showArchivedEvents ? Color.orange : Color.purple).opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Sort menu
                Menu {
                    ForEach(EventSortOption.allCases, id: \.self) { option in
                        Button(action: {
                            eventViewModel.setSortOption(option)
                        }) {
                            HStack {
                                Text(option.rawValue)
                                if eventViewModel.sortOption == option {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.cyan)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption)
                        Text("Sort")
                            .font(.caption)
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            HStack {
                Text("\(filteredEvents.count) item\(filteredEvents.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if showArchivedEvents {
                    Text("• \(eventViewModel.events.filter { $0.archived }.count) archived")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                Spacer()
                Text("Sorted by: \(eventViewModel.sortOption.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            LazyVStack(spacing: 12) {
                ForEach(filteredEvents.indices, id: \.self) { index in
                    let event = filteredEvents[index]
                    SwipeableEventRow(
                        event: event,
                        onArchiveToggle: { eventId in
                            toggleArchiveStatus(eventId: eventId)
                        },
                        onEventTap: { event in
                            showingEditEvent = event
                        }
                    )
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
    
    private func toggleArchiveStatus(eventId: String) {
        guard let event = eventViewModel.events.first(where: { $0.id == eventId }) else { return }
        
        if event.archived {
            eventViewModel.unarchiveEvent(eventId: eventId) { success in
                if success {
                    print("✅ Event unarchived successfully")
                }
            }
        } else {
            eventViewModel.archiveEvent(eventId: eventId) { success in
                if success {
                    print("✅ Event archived successfully")
                }
            }
        }
    }

}

// MARK: - Enhanced Event Row with Safe Firebase Storage Loading
struct EnhancedEventRow: View {
    let event: Event
    let onArchiveToggle: (String) -> Void
    let onEventTap: (Event) -> Void
    @State private var loadedEventImage: UIImage?
    @State private var isLoadingEventImage = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Main content - tappable for navigation
            Button(action: { onEventTap(event) }) {
                HStack(spacing: 12) {
                    // Event Image with Safe Firebase Storage Loading
                    Group {
                        if let loadedImage = loadedEventImage {
                            Image(uiImage: loadedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                                .clipped()
                        } else if isLoadingEventImage {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.8)
                                )
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                                .overlay(
                                    Image(systemName: "calendar")
                                        .font(.title3)
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    
                    // Event Details
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(event.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Spacer()
                            
                            // Archive status badge
                            if event.archived {
                                HStack(spacing: 4) {
                                    Image(systemName: "archivebox.fill")
                                        .font(.caption2)
                                    Text("Archived")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .cornerRadius(8)
                            } else {
                                // Status indicator
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(event.isActive ? Color.green : (event.isUpcoming ? Color.orange : Color.gray))
                                        .frame(width: 6, height: 6)
                                    Text(event.isActive ? "Live" : (event.isUpcoming ? "Upcoming" : "Ended"))
                                        .font(.caption2)
                                        .foregroundColor(event.isActive ? .green : (event.isUpcoming ? .orange : .gray))
                                }
                            }
                        }
                        
                        Text(event.venueName)
                            .font(.caption)
                            .foregroundColor(.cyan)
                            .lineLimit(1)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text("\(formatDateTime(event.startDate)) - \(formatDateTime(event.endDate))")
                            Spacer()
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                            Text(event.address)
                            Spacer()
                            Text("\(event.productIds.count) products")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .onAppear {
            loadEventImage()
        }
        .onChange(of: event.imageUrl) { _ in
            loadEventImage()
        }
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func loadEventImage() {
        guard let imageUrl = event.imageUrl, !imageUrl.isEmpty else {
            return
        }
        
        // If we already have a loaded image for this URL, don't reload
        if loadedEventImage != nil {
            return
        }
        
        isLoadingEventImage = true
        
        // Safe Firebase Storage loading with URL type detection
        if imageUrl.contains("firebasestorage.googleapis.com") {
            // Use Firebase Storage reference for Firebase URLs
            do {
                let storageRef = Storage.storage().reference(forURL: imageUrl)
                storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        self.isLoadingEventImage = false
                        if let error = error {
                            print("Error loading event image: \(error.localizedDescription)")
                        } else if let data = data, let image = UIImage(data: data) {
                            self.loadedEventImage = image
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoadingEventImage = false
                    print("Invalid Firebase Storage URL: \(error.localizedDescription)")
                }
            }
        } else {
            // Use URLSession for regular HTTP URLs
            guard let url = URL(string: imageUrl) else {
                DispatchQueue.main.async {
                    self.isLoadingEventImage = false
                }
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    self.isLoadingEventImage = false
                    if let error = error {
                        print("Error loading event image: \(error.localizedDescription)")
                    } else if let data = data, let image = UIImage(data: data) {
                        self.loadedEventImage = image
                    }
                }
            }.resume()
        }
    }
}

// MARK: - ProductRow Component with Safe Firebase Storage Loading
struct ProductRow: View {
    let product: Product
    let onTap: () -> Void
    @State private var loadedProductImage: UIImage?
    @State private var isLoadingProductImage = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Product Image with Safe Firebase Storage Loading
                Group {
                    if let loadedImage = loadedProductImage {
                        Image(uiImage: loadedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .clipped()
                    } else if isLoadingProductImage {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .overlay(ProgressView().scaleEffect(0.7))
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            )
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
        .onAppear {
            loadProductImage()
        }
        .onChange(of: product.imageUrl) { _ in
            loadProductImage()
        }
    }
    
    private func loadProductImage() {
        guard !product.imageUrl.isEmpty else {
            return
        }
        
        // If we already have a loaded image for this URL, don't reload
        if loadedProductImage != nil {
            return
        }
        
        isLoadingProductImage = true
        
        // Safe Firebase Storage loading with URL type detection
        if product.imageUrl.contains("firebasestorage.googleapis.com") {
            // Use Firebase Storage reference for Firebase URLs
            do {
                let storageRef = Storage.storage().reference(forURL: product.imageUrl)
                storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        self.isLoadingProductImage = false
                        if let error = error {
                            print("Error loading product image: \(error.localizedDescription)")
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
            guard let url = URL(string: product.imageUrl) else {
                DispatchQueue.main.async {
                    self.isLoadingProductImage = false
                }
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    self.isLoadingProductImage = false
                    if let error = error {
                        print("Error loading product image: \(error.localizedDescription)")
                    } else if let data = data, let image = UIImage(data: data) {
                        self.loadedProductImage = image
                    }
                }
            }.resume()
        }
    }
}

// MARK: - Swipeable Event Row Component
struct SwipeableEventRow: View {
    let event: Event
    let onArchiveToggle: (String) -> Void
    let onEventTap: (Event) -> Void
    @State private var offsetX: CGFloat = 0
    @State private var showingAction = false
    
    var body: some View {
        ZStack {
            // Background action button
            HStack {
                Spacer()
                Button(action: {
                    guard let eventId = event.id else { return }
                    onArchiveToggle(eventId)
                    withAnimation(.spring()) {
                        offsetX = 0
                        showingAction = false
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: event.archived ? "archivebox" : "archivebox.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text(event.archived ? "Restore" : "Archive")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .frame(width: 80)
                    .frame(maxHeight: .infinity)
                    .background(event.archived ? Color.orange : Color.purple)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .opacity(showingAction ? 1 : 0)
            
            // Main event row
            EnhancedEventRow(event: event, onArchiveToggle: onArchiveToggle, onEventTap: onEventTap)
                .offset(x: offsetX, y: 0)
        }
        .clipped()
        .simultaneousGesture(
            DragGesture(coordinateSpace: .local)
                .onChanged { value in
                    // Only respond to primarily horizontal gestures
                    let horizontalMovement = abs(value.translation.width)
                    let verticalMovement = abs(value.translation.height)
                    
                    // More stringent check: horizontal must be significantly more than vertical
                    if horizontalMovement > max(verticalMovement * 2, 20) && value.translation.width < -10 {
                        print("🔄 Horizontal swipe detected: \(value.translation.width)")
                        offsetX = max(-80, value.translation.width)
                        showingAction = horizontalMovement > 30
                        print("📱 Setting offsetX to: \(offsetX), showingAction: \(showingAction)")
                    }
                }
                .onEnded { value in
                    let horizontalMovement = abs(value.translation.width)
                    let verticalMovement = abs(value.translation.height)
                    
                    // Only handle completion if this was clearly a horizontal gesture
                    if horizontalMovement > max(verticalMovement * 2, 20) && value.translation.width < -10 {
                        print("🏁 Horizontal swipe ended: \(value.translation.width)")
                        withAnimation(.spring()) {
                            if horizontalMovement > 50 {
                                offsetX = -80
                                showingAction = true
                                print("✅ Showing action button")
                            } else {
                                offsetX = 0
                                showingAction = false
                                print("❌ Hiding action button")
                            }
                        }
                    }
                }
        )
        .onTapGesture {
            // Tap anywhere to dismiss swipe action
            if showingAction {
                withAnimation(.spring()) {
                    offsetX = 0
                    showingAction = false
                }
            }
        }
    }
}
