import Foundation
import FirebaseFirestore

struct Product: Identifiable, Codable {
    @DocumentID var id: String?
    var bandId: String
    var title: String
    var price: Double
    var sizes: [String]
    var inventory: [String: Int]
    var imageUrl: String
    var active: Bool
    var eventIds: [String] // NEW: Array of event IDs this product is associated with
    
    enum CodingKeys: String, CodingKey {
        case id
        case bandId = "band_id"
        case title
        case price
        case sizes
        case inventory
        case imageUrl = "image_url"
        case active
        case eventIds = "event_ids" // NEW
    }
    
    // Convenience initializer for backward compatibility
    init(id: String? = nil, bandId: String, title: String, price: Double, sizes: [String], inventory: [String: Int], imageUrl: String, active: Bool, eventIds: [String] = []) {
        self.id = id
        self.bandId = bandId
        self.title = title
        self.price = price
        self.sizes = sizes
        self.inventory = inventory
        self.imageUrl = imageUrl
        self.active = active
        self.eventIds = eventIds
    }
    
    // Helper methods
    var totalInventory: Int {
        return inventory.values.reduce(0, +)
    }
    
    var availableSizes: [String] {
        return sizes.filter { size in
            (inventory[size] ?? 0) > 0
        }
    }
    
    func isAvailableForEvent(_ eventId: String) -> Bool {
        return eventIds.contains(eventId) && active
    }
    
}

struct Order: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var bandId: String
    var eventId: String? // NEW: Optional event ID for event-specific orders
    var items: [OrderItem]
    var amount: Double
    var status: OrderStatus
    var qrCode: String
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case bandId = "band_id"
        case eventId = "event_id" // NEW
        case items
        case amount
        case status
        case qrCode = "qr_code"
        case createdAt = "created_at"
    }
    
    // Convenience initializer for backward compatibility
    init(id: String? = nil, userId: String, bandId: String, eventId: String? = nil, items: [OrderItem], amount: Double, status: OrderStatus, qrCode: String, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.bandId = bandId
        self.eventId = eventId
        self.items = items
        self.amount = amount
        self.status = status
        self.qrCode = qrCode
        self.createdAt = createdAt
    }
}

struct OrderItem: Codable {
    var productId: String
    var size: String
    var qty: Int
    var productTitle: String? // NEW: Cache product title for better UX
    var productPrice: Double? // NEW: Cache product price for better UX
    
    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case size
        case qty
        case productTitle = "product_title" // NEW
        case productPrice = "product_price" // NEW
    }
    
    // Convenience initializer for backward compatibility
    init(productId: String, size: String, qty: Int, productTitle: String? = nil, productPrice: Double? = nil) {
        self.productId = productId
        self.size = size
        self.qty = qty
        self.productTitle = productTitle
        self.productPrice = productPrice
    }
    
    // Helper computed property
    var totalPrice: Double {
        return (productPrice ?? 0.0) * Double(qty)
    }
}

enum OrderStatus: String, Codable {
    case pendingPickup = "pending_pickup"
    case pickedUp = "picked_up"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pendingPickup:
            return "Pending Pickup"
        case .pickedUp:
            return "Picked Up"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .pendingPickup:
            return "orange"
        case .pickedUp:
            return "green"
        case .cancelled:
            return "red"
        }
    }
}

struct Event: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var venueName: String
    var address: String
    var startDate: Date
    var endDate: Date
    var latitude: Double
    var longitude: Double
    var geofenceRadius: Double    // in meters
    var active: Bool
    var merchantIds: [String]
    var imageUrl: String?         // ← NEW: Optional event image URL
    var productIds: [String]      // Array of product IDs at this event
    var description: String?      // Optional event description
    var eventType: EventType?     // Optional categorization
    var maxCapacity: Int?         // Optional maximum capacity
    var ticketPrice: Double?      // Optional ticket price

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case venueName     = "venue_name"
        case address
        case startDate     = "start_date"
        case endDate       = "end_date"
        case latitude
        case longitude
        case geofenceRadius = "geofence_radius"
        case active
        case merchantIds   = "merchant_ids"
        case imageUrl      = "image_url"       // NEW
        case productIds    = "product_ids"
        case description
        case eventType     = "event_type"
        case maxCapacity   = "max_capacity"
        case ticketPrice   = "ticket_price"
    }

    init(
        id: String? = nil,
        name: String,
        venueName: String,
        address: String,
        startDate: Date,
        endDate: Date,
        latitude: Double,
        longitude: Double,
        geofenceRadius: Double,
        active: Bool,
        merchantIds: [String],
        imageUrl: String? = nil,            // NEW default
        productIds: [String] = [],
        description: String? = nil,
        eventType: EventType? = nil,
        maxCapacity: Int? = nil,
        ticketPrice: Double? = nil
    ) {
        self.id             = id
        self.name           = name
        self.venueName      = venueName
        self.address        = address
        self.startDate      = startDate
        self.endDate        = endDate
        self.latitude       = latitude
        self.longitude      = longitude
        self.geofenceRadius = geofenceRadius
        self.active         = active
        self.merchantIds    = merchantIds
        self.imageUrl       = imageUrl         // ← store your uploaded URL here
        self.productIds     = productIds
        self.description    = description
        self.eventType      = eventType
        self.maxCapacity    = maxCapacity
        self.ticketPrice    = ticketPrice
    }
    
    // Helper properties
    var isActive: Bool {
        let now = Date()
        return active && startDate <= now && endDate >= now
    }
    
    var isUpcoming: Bool {
        return startDate > Date()
    }
    
    var isPast: Bool {
        return endDate < Date()
    }
    
    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
    
    var durationHours: Double {
        return duration / 3600
    }
    
    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let calendar = Calendar.current
        if calendar.isDate(startDate, inSameDayAs: endDate) {
            // Same day
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            
            return "\(dateFormatter.string(from: startDate)), \(timeFormatter.string(from: startDate)) - \(timeFormatter.string(from: endDate))"
        } else {
            // Different days
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }
}

// NEW: Event type enumeration
enum EventType: String, Codable, CaseIterable {
    case concert = "concert"
    case festival = "festival"
    case conference = "conference"
    case sports = "sports"
    case theater = "theater"
    case comedy = "comedy"
    case exhibition = "exhibition"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .concert:
            return "Concert"
        case .festival:
            return "Festival"
        case .conference:
            return "Conference"
        case .sports:
            return "Sports Event"
        case .theater:
            return "Theater"
        case .comedy:
            return "Comedy Show"
        case .exhibition:
            return "Exhibition"
        case .other:
            return "Other"
        }
    }
    
    var iconName: String {
        switch self {
        case .concert:
            return "music.note"
        case .festival:
            return "party.popper"
        case .conference:
            return "person.3"
        case .sports:
            return "sportscourt"
        case .theater:
            return "theatermasks"
        case .comedy:
            return "face.smiling"
        case .exhibition:
            return "building.columns"
        case .other:
            return "calendar"
        }
    }
}

struct Band: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var description: String?
    var logoUrl: String?
    var ownerUserId: String
    var memberUserIds: [String]
    var genre: String? // NEW: Optional music genre
    var website: String? // NEW: Optional website URL
    var socialMedia: SocialMediaLinks? // NEW: Optional social media links
    var isVerified: Bool // NEW: Verification status
    var createdAt: Date? // NEW: Creation timestamp
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case logoUrl = "logo_url"
        case ownerUserId = "owner_user_id"
        case memberUserIds = "member_user_ids"
        case genre
        case website
        case socialMedia = "social_media"
        case isVerified = "is_verified"
        case createdAt = "created_at"
    }
    
    // Convenience initializer for backward compatibility
    init(id: String? = nil, name: String, description: String? = nil, logoUrl: String? = nil, ownerUserId: String, memberUserIds: [String], genre: String? = nil, website: String? = nil, socialMedia: SocialMediaLinks? = nil, isVerified: Bool = false, createdAt: Date? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.logoUrl = logoUrl
        self.ownerUserId = ownerUserId
        self.memberUserIds = memberUserIds
        self.genre = genre
        self.website = website
        self.socialMedia = socialMedia
        self.isVerified = isVerified
        self.createdAt = createdAt
    }
    
    // Helper properties
    var allMemberIds: [String] {
        return [ownerUserId] + memberUserIds
    }
    
    func isMember(_ userId: String) -> Bool {
        return allMemberIds.contains(userId)
    }
    
    func isOwner(_ userId: String) -> Bool {
        return ownerUserId == userId
    }
}

// NEW: Social media links structure
struct SocialMediaLinks: Codable {
    var instagram: String?
    var twitter: String?
    var facebook: String?
    var tiktok: String?
    var youtube: String?
    var spotify: String?
    var appleMusic: String?
    
    enum CodingKeys: String, CodingKey {
        case instagram
        case twitter
        case facebook
        case tiktok
        case youtube
        case spotify
        case appleMusic = "apple_music"
    }
    
    var hasAnyLinks: Bool {
        return instagram != nil || twitter != nil || facebook != nil ||
               tiktok != nil || youtube != nil || spotify != nil || appleMusic != nil
    }
}

// NEW: User profile structure (for enhanced user management)
struct UserProfile: Identifiable, Codable {
    @DocumentID var id: String?
    var email: String
    var displayName: String?
    var photoURL: String?
    var role: UserRole
    var createdAt: Date
    var lastActiveAt: Date?
    var preferences: UserPreferences?
    var bandIds: [String] // For merchants - bands they're associated with
    var isEmailVerified: Bool
    var phoneNumber: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case photoURL = "photo_url"
        case role
        case createdAt = "created_at"
        case lastActiveAt = "last_active_at"
        case preferences
        case bandIds = "band_ids"
        case isEmailVerified = "is_email_verified"
        case phoneNumber = "phone_number"
    }
    
    init(id: String? = nil, email: String, displayName: String? = nil, photoURL: String? = nil, role: UserRole, createdAt: Date, lastActiveAt: Date? = nil, preferences: UserPreferences? = nil, bandIds: [String] = [], isEmailVerified: Bool = false, phoneNumber: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.role = role
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.preferences = preferences
        self.bandIds = bandIds
        self.isEmailVerified = isEmailVerified
        self.phoneNumber = phoneNumber
    }
}

// Enhanced UserRole enum
enum UserRole: String, Codable, CaseIterable {
    case fan
    case merchant
    case admin
    case superAdmin = "super_admin"
    
    var displayName: String {
        switch self {
        case .fan:
            return "Fan"
        case .merchant:
            return "Merchant"
        case .admin:
            return "Admin"
        case .superAdmin:
            return "Super Admin"
        }
    }
    
    var permissions: [Permission] {
        switch self {
        case .fan:
            return [.viewEvents, .purchaseProducts, .viewOwnOrders]
        case .merchant:
            return [.viewEvents, .createProducts, .manageInventory, .scanOrders, .viewSalesReports]
        case .admin:
            return [.viewEvents, .createEvents, .manageUsers, .viewAllReports]
        case .superAdmin:
            return Permission.allCases
        }
    }
}

// NEW: Permission system
enum Permission: String, Codable, CaseIterable {
    case viewEvents = "view_events"
    case createEvents = "create_events"
    case createProducts = "create_products"
    case manageInventory = "manage_inventory"
    case purchaseProducts = "purchase_products"
    case viewOwnOrders = "view_own_orders"
    case viewAllOrders = "view_all_orders"
    case scanOrders = "scan_orders"
    case viewSalesReports = "view_sales_reports"
    case viewAllReports = "view_all_reports"
    case manageUsers = "manage_users"
    case systemAdmin = "system_admin"
}

// NEW: User preferences
struct UserPreferences: Codable {
    var notificationsEnabled: Bool
    var emailNotifications: Bool
    var pushNotifications: Bool
    var smsNotifications: Bool
    var preferredGenres: [String]
    var locationTracking: Bool
    var marketingEmails: Bool
    
    enum CodingKeys: String, CodingKey {
        case notificationsEnabled = "notifications_enabled"
        case emailNotifications = "email_notifications"
        case pushNotifications = "push_notifications"
        case smsNotifications = "sms_notifications"
        case preferredGenres = "preferred_genres"
        case locationTracking = "location_tracking"
        case marketingEmails = "marketing_emails"
    }
    
    init(notificationsEnabled: Bool = true, emailNotifications: Bool = true, pushNotifications: Bool = true, smsNotifications: Bool = false, preferredGenres: [String] = [], locationTracking: Bool = true, marketingEmails: Bool = false) {
        self.notificationsEnabled = notificationsEnabled
        self.emailNotifications = emailNotifications
        self.pushNotifications = pushNotifications
        self.smsNotifications = smsNotifications
        self.preferredGenres = preferredGenres
        self.locationTracking = locationTracking
        self.marketingEmails = marketingEmails
    }
}

// NEW: Analytics and reporting structures
struct EventAnalytics: Identifiable, Codable {
    @DocumentID var id: String?
    var eventId: String
    var totalRevenue: Double
    var totalOrders: Int
    var totalItems: Int
    var topSellingProducts: [ProductSalesData]
    var averageOrderValue: Double
    var pickupRate: Double // Percentage of orders picked up
    var refundRate: Double
    var generatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case totalRevenue = "total_revenue"
        case totalOrders = "total_orders"
        case totalItems = "total_items"
        case topSellingProducts = "top_selling_products"
        case averageOrderValue = "average_order_value"
        case pickupRate = "pickup_rate"
        case refundRate = "refund_rate"
        case generatedAt = "generated_at"
    }
}

struct ProductSalesData: Codable, Identifiable {
    var id: String { productId }
    var productId: String
    var productTitle: String
    var quantitySold: Int
    var revenue: Double
    var averagePrice: Double
    
    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case productTitle = "product_title"
        case quantitySold = "quantity_sold"
        case revenue
        case averagePrice = "average_price"
    }
}
