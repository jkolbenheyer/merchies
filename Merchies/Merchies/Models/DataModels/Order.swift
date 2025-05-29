// Models/DataModels/Order.swift
import Foundation
import FirebaseFirestore

struct Order: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var bandId: String
    var eventId: String? // Optional event ID for event-specific orders
    var items: [OrderItem]
    var amount: Double
    var status: OrderStatus
    var qrCode: String
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case bandId = "band_id"
        case eventId = "event_id"
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
    
    // MARK: - Helper Methods
    
    /// Total number of items in the order
    var totalItems: Int {
        return items.reduce(0) { $0 + $1.qty }
    }
    
    /// Check if order is ready for pickup
    var isReadyForPickup: Bool {
        return status == .pendingPickup
    }
    
    /// Check if order has been completed
    var isCompleted: Bool {
        return status == .pickedUp
    }
}

struct OrderItem: Codable {
    var productId: String
    var size: String
    var qty: Int
    var productTitle: String? // Cache product title for better UX
    var productPrice: Double? // Cache product price for better UX
    
    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case size
        case qty
        case productTitle = "product_title"
        case productPrice = "product_price"
    }
    
    // Convenience initializer for backward compatibility
    init(productId: String, size: String, qty: Int, productTitle: String? = nil, productPrice: Double? = nil) {
        self.productId = productId
        self.size = size
        self.qty = qty
        self.productTitle = productTitle
        self.productPrice = productPrice
    }
    
    // MARK: - Helper Methods
    
    /// Total price for this line item
    var totalPrice: Double {
        return (productPrice ?? 0.0) * Double(qty)
    }
    
    /// Display string for the item
    var displayDescription: String {
        let title = productTitle ?? "Product \(String(productId.suffix(6)))"
        return "\(title) (Size: \(size)) x\(qty)"
    }
}

enum OrderStatus: String, Codable, CaseIterable {
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
    
    var systemImageName: String {
        switch self {
        case .pendingPickup:
            return "clock.fill"
        case .pickedUp:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }
}
