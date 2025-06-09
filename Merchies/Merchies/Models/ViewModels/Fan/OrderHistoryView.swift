import SwiftUI
import Foundation
import FirebaseStorage

struct OrderHistoryView: View {
    @EnvironmentObject var orderViewModel: OrderViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedOrder: Order?
    @State private var hasInitiallyLoaded = false
    @State private var qrCodeOrder: Order?
    
    // Date formatter for order list
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()
    
    var body: some View {
        NavigationView {
            Group {
                if orderViewModel.isLoading && !hasInitiallyLoaded && orderViewModel.orders.isEmpty {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading orders...")
                            .foregroundColor(.gray)
                            .padding(.top)
                        
                        Button("Cancel") {
                            orderViewModel.isLoading = false
                        }
                        .padding(.top)
                        .foregroundColor(.purple)
                    }
                } else if let error = orderViewModel.error, orderViewModel.orders.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        Text("Error Loading Orders")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(error)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Try Again") {
                            orderViewModel.clearError()
                            loadOrders()
                        }
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                } else if orderViewModel.orders.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bag")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Orders Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Your order history will appear here after you make your first purchase")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    ZStack {
                        List {
                            ForEach(orderViewModel.orders.sorted { $0.createdAt > $1.createdAt }) { order in
                                OrderRowView(
                                    order: order,
                                    onTapOrder: {
                                        selectedOrder = order
                                    },
                                    onTapQRCode: {
                                        print("🔄 QR Code tapped for order: \(order.id ?? "nil")")
                                        print("🔄 QR Code string: \(order.qrCode)")
                                        qrCodeOrder = order
                                        print("🔄 Set qrCodeOrder to: \(qrCodeOrder?.id ?? "nil")")
                                    }
                                )
                            }
                        }
                        .listStyle(PlainListStyle())
                        .refreshable {
                            refreshOrders()
                        }
                        
                        // Show subtle loading indicator in top right during refresh
                        if orderViewModel.isLoading && !orderViewModel.orders.isEmpty {
                            VStack {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.trailing)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Orders")
            .onAppear {
                if !hasInitiallyLoaded {
                    loadOrders()
                }
            }
            .sheet(item: $selectedOrder) { order in
                OrderDetailView(order: order)
            }
            .sheet(item: $qrCodeOrder) { order in
                QRCodeSheetWrapper(order: order, qrCodeOrder: $qrCodeOrder)
            }
        }
    }
    
    private func loadOrders() {
        guard let user = authViewModel.user else { 
            print("❌ OrderHistoryView: No user found")
            orderViewModel.isLoading = false
            hasInitiallyLoaded = true
            return 
        }
        print("🔄 OrderHistoryView: Loading orders for user: \(user.uid)")
        
        // Add a timeout to prevent infinite loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if orderViewModel.isLoading {
                print("⏰ OrderHistoryView: Fetch timeout after 10 seconds")
                orderViewModel.isLoading = false
                orderViewModel.error = "Failed to load orders. Please try again."
                hasInitiallyLoaded = true
            }
        }
        
        orderViewModel.fetchOrders(for: user.uid)
        hasInitiallyLoaded = true
    }
    
    private func refreshOrders() {
        guard let user = authViewModel.user else { return }
        orderViewModel.refreshOrders(for: user.uid)
    }
}

// Wrapper for QRCodeSheet to handle the binding properly
struct QRCodeSheetWrapper: View {
    let order: Order
    @Binding var qrCodeOrder: Order?
    
    var body: some View {
        QRCodeSheet(
            order: order,
            isPresented: Binding(
                get: { qrCodeOrder != nil },
                set: { if !$0 { qrCodeOrder = nil } }
            )
        )
        .onAppear {
            print("🔄 QRCodeSheetWrapper appeared with order: \(order.id ?? "nil")")
            print("🔄 Order QR code: \(order.qrCode)")
        }
    }
}

struct OrderRowView: View {
    let order: Order
    let onTapOrder: () -> Void
    let onTapQRCode: () -> Void
    @State private var eventImage: UIImage?
    @State private var isLoadingEventImage = false
    @State private var eventImageUrl: String?
    
    // Date formatter for order rows
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Event Image
                Group {
                    if let eventImage = eventImage {
                        Image(uiImage: eventImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .clipped()
                    } else if isLoadingEventImage {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                            )
                    } else {
                        Rectangle()
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.purple)
                                    .font(.title3)
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Order #\(order.id.map { String($0.suffix(6)) } ?? "")")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(Self.dateFormatter.string(from: order.createdAt))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "$%.2f", order.amount))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    statusBadge(for: order.status)
                }
            }
            
            HStack {
                Text("\(order.totalItems) item\(order.totalItems == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if order.status == .pendingPickup {
                    HStack(spacing: 4) {
                        Image(systemName: "qrcode")
                            .font(.caption)
                        Text("Tap for QR code")
                            .font(.caption)
                    }
                    .foregroundColor(.purple)
                    .onTapGesture {
                        onTapQRCode()
                    }
                } else if order.status == .pendingPayment {
                    HStack(spacing: 4) {
                        Image(systemName: "creditcard")
                            .font(.caption)
                        Text("Payment pending")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTapOrder()
        }
        .onAppear {
            loadEventImage()
        }
    }
    
    @ViewBuilder
    private func statusBadge(for status: OrderStatus) -> some View {
        let (bg, fg): (Color, Color) = {
            switch status {
            case .pendingPayment: return (Color.blue.opacity(0.2),   .blue)
            case .pendingPickup:  return (Color.orange.opacity(0.2), .orange)
            case .pickedUp:       return (Color.green.opacity(0.2),  .green)
            case .cancelled:      return (Color.red.opacity(0.2),    .red)
            }
        }()
        
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(bg)
            .foregroundColor(fg)
            .cornerRadius(12)
    }
    
    // MARK: - Event Image Loading
    
    private func loadEventImage() {
        print("🖼️ OrderRowView: Attempting to load event image for order \(order.id ?? "nil")")
        print("🖼️ Order eventId: \(order.eventId ?? "nil")")
        
        if eventImage != nil {
            print("🖼️ Event image already loaded for order \(order.id ?? "nil")")
            return // Already loaded
        }
        
        if let eventId = order.eventId, !eventId.isEmpty {
            // Direct eventId approach for new orders
            print("🖼️ Starting to fetch event data for eventId: \(eventId)")
            fetchEventById(eventId)
        } else {
            // Fallback approach for legacy orders without eventId
            print("🖼️ No eventId - using fallback to find event by bandId and date")
            print("🖼️ Order bandId: \(order.bandId)")
            print("🖼️ Order created: \(order.createdAt)")
            fetchEventByBandAndDate()
        }
    }
    
    private func fetchEventById(_ eventId: String) {
        isLoadingEventImage = true
        
        let firestoreService = FirestoreService()
        firestoreService.fetchSingleEvent(eventId: eventId) { event, error in
            DispatchQueue.main.async {
                isLoadingEventImage = false
                
                if let error = error {
                    print("❌ Error fetching event for order: \(error.localizedDescription)")
                    return
                }
                
                guard let event = event else {
                    print("❌ No event found for eventId: \(eventId)")
                    return
                }
                
                print("✅ Successfully fetched event: \(event.name)")
                print("🖼️ Event image URL: \(event.imageUrl ?? "nil")")
                
                eventImageUrl = event.imageUrl
                loadImageFromUrl(event.imageUrl)
            }
        }
    }
    
    private func fetchEventByBandAndDate() {
        print("🔍 Fetching events for bandId: \(order.bandId)")
        isLoadingEventImage = true
        
        let firestoreService = FirestoreService()
        firestoreService.fetchEventsForMerchant(merchantId: order.bandId) { events, error in
            DispatchQueue.main.async {
                isLoadingEventImage = false
                
                if let error = error {
                    print("❌ Error fetching events for bandId \(order.bandId): \(error.localizedDescription)")
                    return
                }
                
                guard let events = events, !events.isEmpty else {
                    print("🖼️ No events found for bandId: \(order.bandId)")
                    return
                }
                
                print("📅 Found \(events.count) events for bandId \(order.bandId)")
                for (index, event) in events.enumerated() {
                    print("   Event \(index + 1): \(event.name) (\(event.startDate) - \(event.endDate)) - Image: \(event.imageUrl != nil ? "✅" : "❌")")
                }
                
                let orderDate = order.createdAt
                print("📅 Order created: \(orderDate)")
                
                // Try to find the best matching event, but be more permissive
                var bestMatchEvent: Event?
                
                // First try: exact date range match
                bestMatchEvent = events.first { event in
                    let eventStart = event.startDate
                    let eventEnd = event.endDate
                    let dayBeforeEvent = Calendar.current.date(byAdding: .day, value: -1, to: eventStart) ?? eventStart
                    let dayAfterEvent = Calendar.current.date(byAdding: .day, value: 1, to: eventEnd) ?? eventEnd
                    
                    let matches = orderDate >= dayBeforeEvent && orderDate <= dayAfterEvent
                    if matches {
                        print("📅 ✅ Date match found: \(event.name)")
                    }
                    return matches
                }
                
                // Second try: just use the most recent event with an image
                if bestMatchEvent == nil {
                    print("📅 No date match found, using most recent event with image")
                    bestMatchEvent = events
                        .filter { $0.imageUrl != nil && !$0.imageUrl!.isEmpty }
                        .sorted { $0.startDate > $1.startDate }
                        .first
                }
                
                // Third try: just use any event with an image
                if bestMatchEvent == nil {
                    print("📅 Using any event with an image")
                    bestMatchEvent = events.first { $0.imageUrl != nil && !$0.imageUrl!.isEmpty }
                }
                
                // Final fallback: use first event regardless of image
                if bestMatchEvent == nil {
                    print("📅 Using first available event")
                    bestMatchEvent = events.first
                }
                
                if let event = bestMatchEvent {
                    print("✅ Selected event for legacy order: \(event.name)")
                    print("🖼️ Event image URL: \(event.imageUrl ?? "nil")")
                    eventImageUrl = event.imageUrl
                    loadImageFromUrl(event.imageUrl)
                } else {
                    print("❌ No suitable event found for legacy order")
                }
            }
        }
    }
    
    private func loadImageFromUrl(_ imageUrl: String?) {
        print("🖼️ loadImageFromUrl called with: \(imageUrl ?? "nil")")
        guard let imageUrl = imageUrl, !imageUrl.isEmpty else {
            print("🖼️ No image URL for event - will show fallback icon")
            return
        }
        
        print("🖼️ Starting to load image from: \(imageUrl)")
        
        // Safe Firebase Storage loading with URL type detection
        if imageUrl.contains("firebasestorage.googleapis.com") {
            // Use Firebase Storage reference for Firebase URLs
            do {
                let storageRef = Storage.storage().reference(forURL: imageUrl)
                storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ Error loading event image from Firebase: \(error.localizedDescription)")
                        } else if let data = data, let image = UIImage(data: data) {
                            print("✅ Successfully loaded event image from Firebase")
                            eventImage = image
                        }
                    }
                }
            } catch {
                print("❌ Invalid Firebase Storage URL: \(error.localizedDescription)")
            }
        } else {
            // Use URLSession for regular HTTP URLs
            guard let url = URL(string: imageUrl) else {
                print("❌ Invalid URL: \(imageUrl)")
                return
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error loading event image from URL: \(error.localizedDescription)")
                    } else if let data = data, let image = UIImage(data: data) {
                        print("✅ Successfully loaded event image from URL")
                        eventImage = image
                    }
                }
            }.resume()
        }
    }
}
