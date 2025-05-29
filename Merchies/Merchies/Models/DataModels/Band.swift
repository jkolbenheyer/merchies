// Models/DataModels/Band.swift
import Foundation
import FirebaseFirestore

struct Band: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var description: String?
    var logoUrl: String?
    var ownerUserId: String
    var memberUserIds: [String]
    var genre: String? // Optional music genre
    var website: String? // Optional website URL
    var socialMedia: SocialMediaLinks? // Optional social media links
    var isVerified: Bool // Verification status
    var createdAt: Date? // Creation timestamp
    
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
    
    // MARK: - Helper Properties
    
    /// All member IDs including the owner
    var allMemberIds: [String] {
        return [ownerUserId] + memberUserIds
    }
    
    /// Total number of members including owner
    var totalMemberCount: Int {
        return allMemberIds.count
    }
    
    // MARK: - Helper Methods
    
    /// Check if a user is a member of this band
    func isMember(_ userId: String) -> Bool {
        return allMemberIds.contains(userId)
    }
    
    /// Check if a user is the owner of this band
    func isOwner(_ userId: String) -> Bool {
        return ownerUserId == userId
    }
    
    /// Check if band has social media links
    var hasSocialMediaLinks: Bool {
        return socialMedia?.hasAnyLinks == true
    }
}

// Social media links structure
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
    
    /// Check if any social media links are present
    var hasAnyLinks: Bool {
        return instagram != nil || twitter != nil || facebook != nil ||
               tiktok != nil || youtube != nil || spotify != nil || appleMusic != nil
    }
    
    /// Get all available social media platforms
    var availablePlatforms: [String] {
        var platforms: [String] = []
        if instagram != nil { platforms.append("Instagram") }
        if twitter != nil { platforms.append("Twitter") }
        if facebook != nil { platforms.append("Facebook") }
        if tiktok != nil { platforms.append("TikTok") }
        if youtube != nil { platforms.append("YouTube") }
        if spotify != nil { platforms.append("Spotify") }
        if appleMusic != nil { platforms.append("Apple Music") }
        return platforms
    }
}

// Analytics and reporting structures
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
    
    // MARK: - Helper Properties
    
    /// Formatted revenue string
    var formattedRevenue: String {
        return String(format: "$%.2f", totalRevenue)
    }
    
    /// Formatted pickup rate percentage
    var formattedPickupRate: String {
        return String(format: "%.1f%%", pickupRate * 100)
    }
    
    /// Performance rating based on pickup rate
    var performanceRating: String {
        switch pickupRate {
        case 0.9...:
            return "Excellent"
        case 0.7..<0.9:
            return "Good"
        case 0.5..<0.7:
            return "Fair"
        default:
            return "Needs Improvement"
        }
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
    
    // MARK: - Helper Properties
    
    /// Formatted revenue string
    var formattedRevenue: String {
        return String(format: "$%.2f", revenue)
    }
    
    /// Formatted average price string
    var formattedAveragePrice: String {
        return String(format: "$%.2f", averagePrice)
    }
    
    /// Revenue per unit sold
    var revenuePerUnit: Double {
        guard quantitySold > 0 else { return 0 }
        return revenue / Double(quantitySold)
    }
}
