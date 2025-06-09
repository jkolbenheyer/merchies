// Models/DataModels/Event.swift
import Foundation
import FirebaseFirestore

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
    var imageUrl: String?         // Optional event image URL
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
        case imageUrl      = "image_url"
        case productIds    = "product_ids"
        case description
        case eventType     = "event_type"
        case maxCapacity   = "max_capacity"
        case ticketPrice   = "ticket_price"
    }
    
    // Custom decoder to handle legacy events without product_ids field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode required fields
        self.name = try container.decode(String.self, forKey: .name)
        self.venueName = try container.decode(String.self, forKey: .venueName)
        self.address = try container.decode(String.self, forKey: .address)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.endDate = try container.decode(Date.self, forKey: .endDate)
        self.latitude = try container.decode(Double.self, forKey: .latitude)
        self.longitude = try container.decode(Double.self, forKey: .longitude)
        self.geofenceRadius = try container.decode(Double.self, forKey: .geofenceRadius)
        self.active = try container.decode(Bool.self, forKey: .active)
        self.merchantIds = try container.decode([String].self, forKey: .merchantIds)
        
        // Decode optional fields
        self.imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.eventType = try container.decodeIfPresent(EventType.self, forKey: .eventType)
        self.maxCapacity = try container.decodeIfPresent(Int.self, forKey: .maxCapacity)
        self.ticketPrice = try container.decodeIfPresent(Double.self, forKey: .ticketPrice)
        
        // Handle legacy events without product_ids field - this is the key fix
        self.productIds = try container.decodeIfPresent([String].self, forKey: .productIds) ?? []
        
        // Let @DocumentID handle itself through the property wrapper
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
        imageUrl: String? = nil,
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
        self.imageUrl       = imageUrl
        self.productIds     = productIds
        self.description    = description
        self.eventType      = eventType
        self.maxCapacity    = maxCapacity
        self.ticketPrice    = ticketPrice
    }
    
    // MARK: - Helper Properties
    
    /// Check if event is currently active (between start and end dates and marked as active)
    var isActive: Bool {
        let now = Date()
        return active && startDate <= now && endDate >= now
    }
    
    /// Check if event is upcoming (start date is in the future)
    var isUpcoming: Bool {
        return startDate > Date()
    }
    
    /// Check if event has ended
    var isPast: Bool {
        return endDate < Date()
    }
    
    /// Duration of the event in seconds
    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
    
    /// Duration of the event in hours
    var durationHours: Double {
        return duration / 3600
    }
    
    /// Formatted date range string for display
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
    
    /// Status description for UI display
    var statusDescription: String {
        if isActive {
            return "Live Now"
        } else if isUpcoming {
            return "Upcoming"
        } else {
            return "Ended"
        }
    }
    
    /// Check if a merchant is associated with this event
    func hasMerchant(_ merchantId: String) -> Bool {
        return merchantIds.contains(merchantId)
    }
    
    /// Check if a product is associated with this event
    func hasProduct(_ productId: String) -> Bool {
        return productIds.contains(productId)
    }
}

// Event type enumeration
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
