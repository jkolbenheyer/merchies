// Models/DataModels/Product.swift
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
    var eventIds: [String] // Array of event IDs this product is associated with
    
    enum CodingKeys: String, CodingKey {
        case id
        case bandId = "band_id"
        case title
        case price
        case sizes
        case inventory
        case imageUrl = "image_url"
        case active
        case eventIds = "event_ids"
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
    
    // MARK: - Helper Methods
    
    /// Total quantity across all sizes
    var totalInventory: Int {
        return inventory.values.reduce(0, +)
    }
    
    /// Sizes that have inventory > 0
    var availableSizes: [String] {
        return sizes.filter { size in
            (inventory[size] ?? 0) > 0
        }
    }
    
    /// Check if product is available for a specific event
    func isAvailableForEvent(_ eventId: String) -> Bool {
        return eventIds.contains(eventId) && active
    }
    
    /// Check if a specific size is available
    func hasAvailableSize(_ size: String) -> Bool {
        return (inventory[size] ?? 0) > 0
    }
    
    /// Get inventory count for a specific size
    func inventoryCount(for size: String) -> Int {
        return inventory[size] ?? 0
    }
}
