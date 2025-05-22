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
    
    enum CodingKeys: String, CodingKey {
        case id
        case bandId = "band_id"
        case title
        case price
        case sizes
        case inventory
        case imageUrl = "image_url"
        case active
    }
}

struct Order: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var bandId: String
    var items: [OrderItem]
    var amount: Double
    var status: OrderStatus
    var qrCode: String
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case bandId = "band_id"
        case items
        case amount
        case status
        case qrCode = "qr_code"
        case createdAt = "created_at"
    }
}

struct OrderItem: Codable {
    var productId: String
    var size: String
    var qty: Int
    
    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case size
        case qty
    }
}

enum OrderStatus: String, Codable {
    case pendingPickup = "pending_pickup"
    case pickedUp = "picked_up"
    case cancelled = "cancelled"
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
    var geofenceRadius: Double // in meters
    var active: Bool
    var merchantIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case venueName = "venue_name"
        case address
        case startDate = "start_date"
        case endDate = "end_date"
        case latitude
        case longitude
        case geofenceRadius = "geofence_radius"
        case active
        case merchantIds = "merchant_ids"
    }
}

struct Band: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var description: String?
    var logoUrl: String?
    var ownerUserId: String
    var memberUserIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case logoUrl = "logo_url"
        case ownerUserId = "owner_user_id"
        case memberUserIds = "member_user_ids"
    }
}
