// File: Utilities/DesignSystem/AppDesignSystem.swift

import SwiftUI
import Foundation

public enum AppDesignSystem {
    
    // MARK: - Color Palette
    public enum Colors {
        // Primary Brand Colors (using your existing cyan/purple theme)
        static let primary = Color.cyan
        static let primaryLight = Color.cyan.opacity(0.7)
        static let primaryDark = Color.purple
        
        // Semantic Colors
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red
        static let info = Color.blue
        
        // Background Colors
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let cardBackground = Color(.systemGray6)
        static let groupedBackground = Color(.systemGroupedBackground)
        
        // Text Colors
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let tertiaryText = Color(.tertiaryLabel)
        
        // Border Colors
        static let border = Color(.separator)
        static let borderLight = Color(.systemGray5)
    }
    
    // MARK: - Typography Scale
    public enum Typography {
        // Headers
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title1 = Font.title.weight(.bold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.semibold)
        
        // Body Text
        static let headline = Font.headline.weight(.semibold)
        static let subheadline = Font.subheadline.weight(.medium)
        static let body = Font.body
        static let bodyMedium = Font.body.weight(.medium)
        
        // Small Text
        static let callout = Font.callout
        static let footnote = Font.footnote
        static let caption1 = Font.caption
        static let caption2 = Font.caption2
        
        // Button Text
        static let buttonLarge = Font.headline.weight(.semibold)
        static let buttonMedium = Font.subheadline.weight(.semibold)
        static let buttonSmall = Font.footnote.weight(.semibold)
    }
    
    // MARK: - Spacing System
    public enum Spacing {
        static let xs: CGFloat = 2
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        static let xxxl: CGFloat = 24
        static let huge: CGFloat = 32
        
        // Semantic Spacing
        static let cardPadding = xl
        static let sectionSpacing = xxl
        static let screenPadding = xl
        static let listItemSpacing = lg
    }
    
    // MARK: - Corner Radius
    public enum CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let round: CGFloat = 50
    }
    
    // MARK: - Shadows
    public enum Shadow {
        static let light = Color.black.opacity(0.05)
        static let medium = Color.black.opacity(0.1)
        static let heavy = Color.black.opacity(0.2)
        
        static let cardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) =
            (light, 4, 0, 2)
        static let modalShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) =
            (medium, 8, 0, 4)
    }
    
    // MARK: - Animation
    public enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
    }
}
