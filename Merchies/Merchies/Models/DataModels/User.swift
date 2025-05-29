// Models/DataModels/User.swift
import Foundation
import FirebaseFirestore

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
    
    var canManageProducts: Bool {
        return permissions.contains(.createProducts)
    }
    
    var canManageEvents: Bool {
        return permissions.contains(.createEvents)
    }
    
    var canViewAnalytics: Bool {
        return permissions.contains(.viewSalesReports) || permissions.contains(.viewAllReports)
    }
}

// Permission system
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
    
    var displayName: String {
        switch self {
        case .viewEvents:
            return "View Events"
        case .createEvents:
            return "Create Events"
        case .createProducts:
            return "Create Products"
        case .manageInventory:
            return "Manage Inventory"
        case .purchaseProducts:
            return "Purchase Products"
        case .viewOwnOrders:
            return "View Own Orders"
        case .viewAllOrders:
            return "View All Orders"
        case .scanOrders:
            return "Scan Orders"
        case .viewSalesReports:
            return "View Sales Reports"
        case .viewAllReports:
            return "View All Reports"
        case .manageUsers:
            return "Manage Users"
        case .systemAdmin:
            return "System Administration"
        }
    }
}

// User profile structure (for enhanced user management)
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
    
    // MARK: - Helper Methods
    
    /// Check if user has a specific permission
    func hasPermission(_ permission: Permission) -> Bool {
        return role.permissions.contains(permission)
    }
    
    /// Check if user is associated with a specific band
    func isAssociatedWith(bandId: String) -> Bool {
        return bandIds.contains(bandId)
    }
    
    /// Get display name or fallback to email
    var effectiveDisplayName: String {
        return displayName ?? email.components(separatedBy: "@").first ?? "User"
    }
}

// User preferences
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
    
    // MARK: - Helper Methods
    
    /// Check if any notifications are enabled
    var hasNotificationsEnabled: Bool {
        return notificationsEnabled && (emailNotifications || pushNotifications || smsNotifications)
    }
}
