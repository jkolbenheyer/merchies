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
    var transactionId: String?
    var paymentStatus: PaymentStatus
    var createdAt: Date
    
    // Custom mutating function to set ID when it's missing
    mutating func setDocumentID(_ documentID: String) {
        if self.id == nil {
            self.id = documentID
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case bandId = "band_id"
        case eventId = "event_id"
        case items
        case amount
        case status
        case qrCode = "qr_code"
        case transactionId = "transaction_id"
        case paymentStatus = "payment_status"
        case createdAt = "created_at"
    }
    
    // Custom decoder to handle legacy orders without payment_status
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Initialize @DocumentID wrapper properly - it will be set by Firestore automatically
        self._id = DocumentID<String>(wrappedValue: nil)
        
        // Decode required fields
        self.userId = try container.decode(String.self, forKey: .userId)
        self.bandId = try container.decode(String.self, forKey: .bandId)
        self.items = try container.decode([OrderItem].self, forKey: .items)
        self.amount = try container.decode(Double.self, forKey: .amount)
        let decodedStatus = try container.decode(OrderStatus.self, forKey: .status)
        self.status = decodedStatus
        self.qrCode = try container.decode(String.self, forKey: .qrCode)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        // Decode optional fields
        self.eventId = try container.decodeIfPresent(String.self, forKey: .eventId)
        let decodedTransactionId = try container.decodeIfPresent(String.self, forKey: .transactionId)
        self.transactionId = decodedTransactionId
        
        // Handle legacy orders without payment_status field
        self.paymentStatus = try container.decodeIfPresent(PaymentStatus.self, forKey: .paymentStatus) ?? {
            // For legacy orders, infer payment status from transaction presence and order status
            if decodedTransactionId != nil {
                return .succeeded
            } else if decodedStatus == .pendingPayment {
                return .pending
            } else {
                return .succeeded // Assume old orders that aren't pending payment are paid
            }
        }()
    }
    
    // Convenience initializer for backward compatibility
    init(id: String? = nil, userId: String, bandId: String, eventId: String? = nil, items: [OrderItem], amount: Double, status: OrderStatus, qrCode: String, transactionId: String? = nil, paymentStatus: PaymentStatus = .pending, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.bandId = bandId
        self.eventId = eventId
        self.items = items
        self.amount = amount
        self.status = status
        self.qrCode = qrCode
        self.transactionId = transactionId
        self.paymentStatus = paymentStatus
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
    case pendingPayment = "pending_payment"
    case pendingPickup = "pending_pickup"
    case pickedUp = "picked_up"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pendingPayment:
            return "Pending Payment"
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
        case .pendingPayment:
            return "blue"
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
        case .pendingPayment:
            return "creditcard.fill"
        case .pendingPickup:
            return "clock.fill"
        case .pickedUp:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }
}

enum PaymentStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case processing = "processing"
    case succeeded = "succeeded"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending:
            return "Payment Pending"
        case .processing:
            return "Processing Payment"
        case .succeeded:
            return "Payment Complete"
        case .failed:
            return "Payment Failed"
        case .cancelled:
            return "Payment Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .pending:
            return "orange"
        case .processing:
            return "blue"
        case .succeeded:
            return "green"
        case .failed, .cancelled:
            return "red"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .pending:
            return "clock.fill"
        case .processing:
            return "arrow.triangle.2.circlepath"
        case .succeeded:
            return "checkmark.circle.fill"
        case .failed, .cancelled:
            return "xmark.circle.fill"
        }
    }
}
