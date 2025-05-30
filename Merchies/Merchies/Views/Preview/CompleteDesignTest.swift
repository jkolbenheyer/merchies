// Enhanced Design System for MerchPit
// File: Views/DesignSystem/DesignSystemComponents.swift
// Complete design system with dark mode support and EditEventView components

import SwiftUI
import PhotosUI

// MARK: - Enhanced Design System
enum DesignSystem {
    // MARK: - Colors (Dark Mode Compatible)
    enum Colors {
        static let primary = Color("PrimaryColor") // Define in Assets.xcassets
        static let primaryLight = Color("PrimaryLightColor")
        static let primaryDark = Color("PrimaryDarkColor")
        
        static let success = Color.green
        static let warning = Color.orange
        static let danger = Color.red
        static let info = Color.blue
        
        // Adaptive colors for dark mode
        static let cardBackground = Color("CardBackground")
        static let surfaceBackground = Color("SurfaceBackground")
        static let primaryText = Color("PrimaryText")
        static let secondaryText = Color("SecondaryText")
        static let tertiaryText = Color("TertiaryText")
        static let background = Color("Background")
        static let border = Color("BorderColor")
        static let borderLight = Color("BorderLightColor")
        static let shadow = Color("ShadowColor")
        
        // Form colors
        static let inputBackground = Color("InputBackground")
        static let inputFocused = Color("InputFocused")
        
        // Status colors with opacity variants
        static let successBackground = Color.green.opacity(0.1)
        static let warningBackground = Color.orange.opacity(0.1)
        static let dangerBackground = Color.red.opacity(0.1)
    }
    
    // MARK: - Typography
    enum Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title1 = Font.title.weight(.bold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.semibold)
        static let headline = Font.headline.weight(.semibold)
        static let subheadline = Font.subheadline.weight(.medium)
        static let body = Font.body
        static let bodyMedium = Font.body.weight(.medium)
        static let callout = Font.callout
        static let caption1 = Font.caption
        static let caption2 = Font.caption2
        static let footnote = Font.footnote
        
        // Button typography
        static let buttonLarge = Font.headline.weight(.semibold)
        static let buttonMedium = Font.subheadline.weight(.semibold)
        static let buttonSmall = Font.caption.weight(.semibold)
    }
    
    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 2
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        static let xxxl: CGFloat = 24
        static let xxxxl: CGFloat = 32
        
        // Component specific
        static let cardPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let screenPadding: CGFloat = 16
        static let buttonPadding: CGFloat = 16
        static let inputPadding: CGFloat = 12
    }
    
    // MARK: - Corner Radius
    enum CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let round: CGFloat = 50
    }
    
    // MARK: - Shadows
    enum Shadow {
        static let light = Color.black.opacity(0.05)
        static let medium = Color.black.opacity(0.1)
        static let heavy = Color.black.opacity(0.2)
    }
}

// MARK: - Enhanced Button Component
struct DSButton: View {
    enum Style {
        case primary, secondary, tertiary, danger, success, ghost
        
        var backgroundColor: Color {
            switch self {
            case .primary: return DesignSystem.Colors.primary
            case .secondary: return DesignSystem.Colors.cardBackground
            case .tertiary: return DesignSystem.Colors.surfaceBackground
            case .danger: return DesignSystem.Colors.danger
            case .success: return DesignSystem.Colors.success
            case .ghost: return Color.clear
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary, .danger, .success: return .white
            case .secondary, .tertiary: return DesignSystem.Colors.primary
            case .ghost: return DesignSystem.Colors.primary
            }
        }
        
        var borderColor: Color? {
            switch self {
            case .ghost: return DesignSystem.Colors.border
            default: return nil
            }
        }
    }
    
    enum Size {
        case small, medium, large
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            case .medium: return EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            case .large: return EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
            }
        }
        
        var font: Font {
            switch self {
            case .small: return DesignSystem.Typography.buttonSmall
            case .medium: return DesignSystem.Typography.buttonMedium
            case .large: return DesignSystem.Typography.buttonLarge
            }
        }
    }
    
    let title: String
    let style: Style
    let size: Size
    let icon: String?
    let action: () -> Void
    let disabled: Bool
    
    init(
        title: String,
        style: Style = .primary,
        size: Size = .medium,
        icon: String? = nil,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.icon = icon
        self.disabled = disabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(size.font)
                }
                Text(title)
                    .font(size.font)
            }
            .foregroundColor(disabled ? DesignSystem.Colors.tertiaryText : style.foregroundColor)
            .padding(size.padding)
            .frame(maxWidth: .infinity)
            .background(
                disabled ? DesignSystem.Colors.border : style.backgroundColor
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(style.borderColor ?? Color.clear, lineWidth: 1)
            )
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .disabled(disabled)
        .scaleEffect(disabled ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: disabled)
    }
}

// MARK: - Enhanced Card Component
struct DSCard<Content: View>: View {
    enum Style {
        case elevated, flat, outlined
        
        var shadow: Color {
            switch self {
            case .elevated: return DesignSystem.Shadow.medium
            case .flat, .outlined: return Color.clear
            }
        }
        
        var borderColor: Color? {
            switch self {
            case .outlined: return DesignSystem.Colors.border
            default: return nil
            }
        }
    }
    
    let style: Style
    let padding: CGFloat
    let content: Content
    
    init(
        style: Style = .elevated,
        padding: CGFloat = DesignSystem.Spacing.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(DesignSystem.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(style.borderColor ?? Color.clear, lineWidth: 1)
            )
            .cornerRadius(DesignSystem.CornerRadius.md)
            .shadow(color: style.shadow, radius: 8, x: 0, y: 2)
    }
}

// MARK: - Section Card with Header
struct DSSectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let action: (() -> Void)?
    let actionTitle: String?
    let content: Content
    
    init(
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(title)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    if let actionTitle = actionTitle, let action = action {
                        Button(action: action) {
                            Text(actionTitle)
                                .font(DesignSystem.Typography.buttonSmall)
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                    }
                }
                
                content
            }
        }
    }
}

// MARK: - Enhanced Text Field
struct DSTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let required: Bool
    let disabled: Bool
    let errorMessage: String?
    
    @FocusState private var isFocused: Bool
    
    init(
        label: String,
        placeholder: String,
        text: Binding<String>,
        required: Bool = false,
        disabled: Bool = false,
        errorMessage: String? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.required = required
        self.disabled = disabled
        self.errorMessage = errorMessage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(label)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                if required {
                    Text("*")
                        .foregroundColor(DesignSystem.Colors.danger)
                }
            }
            
            TextField(placeholder, text: $text)
                .font(DesignSystem.Typography.body)
                .padding(DesignSystem.Spacing.inputPadding)
                .background(
                    isFocused ? DesignSystem.Colors.inputFocused : DesignSystem.Colors.inputBackground
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .stroke(
                            errorMessage != nil ? DesignSystem.Colors.danger :
                            isFocused ? DesignSystem.Colors.primary : Color(.systemGray3),
                            lineWidth: isFocused ? 2 : 1.5
                        )
                )
                .cornerRadius(DesignSystem.CornerRadius.sm)
                .focused($isFocused)
                .disabled(disabled)
                .opacity(disabled ? 0.6 : 1.0)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.danger)
            }
        }
    }
}

// MARK: - Enhanced Status Badge
struct DSStatusBadge: View {
    enum Status {
        case active, pending, inactive, success, warning, danger
        
        var color: Color {
            switch self {
            case .active, .success: return DesignSystem.Colors.success
            case .pending, .warning: return DesignSystem.Colors.warning
            case .inactive: return DesignSystem.Colors.secondaryText
            case .danger: return DesignSystem.Colors.danger
            }
        }
        
        var backgroundColor: Color {
            color.opacity(0.1)
        }
    }
    
    let text: String
    let status: Status
    let size: DSButton.Size
    
    init(text: String, status: Status, size: DSButton.Size = .small) {
        self.text = text
        self.status = status
        self.size = size
    }
    
    var body: some View {
        Text(text)
            .font(size.font)
            .fontWeight(.medium)
            .foregroundColor(status.color)
            .padding(.horizontal, size == .small ? DesignSystem.Spacing.md : DesignSystem.Spacing.lg)
            .padding(.vertical, size == .small ? DesignSystem.Spacing.sm : DesignSystem.Spacing.md)
            .background(status.backgroundColor)
            .cornerRadius(DesignSystem.CornerRadius.xs)
    }
}

// MARK: - Image Components
struct DSImagePicker: View {
    @Binding var selectedImage: UIImage?
    @Binding var isUploading: Bool
    let hasExistingImage: Bool
    let onImageSelected: (PhotosPickerItem?) -> Void
    let onRemoveImage: () -> Void
    
    @State private var pickerItem: PhotosPickerItem?
    
    var body: some View {
        DSCard {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Image display area
                Group {
                    if let image = selectedImage {
                        DSImageDisplay(
                            image: image,
                            isLoading: isUploading,
                            showRemoveButton: true,
                            onRemove: onRemoveImage
                        )
                    } else if hasExistingImage {
                        DSImagePlaceholder(
                            icon: "photo",
                            title: "Current Image",
                            subtitle: "Tap below to change image"
                        )
                    } else {
                        DSImagePlaceholder(
                            icon: "photo.badge.plus",
                            title: "Add Image",
                            subtitle: "Choose from photo library"
                        )
                    }
                }
                
                // Image picker button - UPDATED to match EditEventView
                PhotosPicker(
                    selection: $pickerItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Image(systemName: "photo")
                        Text(hasExistingImage || selectedImage != nil ? "Change Image" : "Choose Image")
                            .fontWeight(.medium)
                        if isUploading {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.lg)
                    .background(DesignSystem.Colors.primary.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }
                .disabled(isUploading)
                .onChange(of: pickerItem) { newItem in
                    onImageSelected(newItem)
                }
            }
        }
    }
}

struct DSImageDisplay: View {
    let image: UIImage
    let isLoading: Bool
    let showRemoveButton: Bool
    let onRemove: () -> Void
    
    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxHeight: 200)
                .cornerRadius(DesignSystem.CornerRadius.md)
                .clipped()
            
            if isLoading {
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .cornerRadius(DesignSystem.CornerRadius.md)
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Uploading...")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(.white)
                }
            }
            
            if showRemoveButton && !isLoading {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    Spacer()
                }
                .padding(DesignSystem.Spacing.sm)
            }
        }
    }
}

struct DSImagePlaceholder: View {
    let icon: String
    let title: String
    let subtitle: String
    let showRemoveButton: Bool
    let onRemove: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        showRemoveButton: Bool = false,
        onRemove: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.showRemoveButton = showRemoveButton
        self.onRemove = onRemove
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.secondaryText)
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Text(subtitle)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            if showRemoveButton, let onRemove = onRemove {
                DSButton(
                    title: "Remove",
                    style: .danger,
                    size: .small
                ) {
                    onRemove()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(DesignSystem.Colors.surfaceBackground)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(DesignSystem.Colors.border, style: StrokeStyle(lineWidth: 1, dash: [5]))
        )
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// MARK: - Event/Product Row Components
struct DSEventRow: View {
    let title: String
    let subtitle: String
    let dateRange: String
    let status: DSStatusBadge.Status
    let image: UIImage?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            DSCard(padding: DesignSystem.Spacing.lg) {
                HStack(spacing: DesignSystem.Spacing.lg) {
                    // Event image
                    Group {
                        if let image = image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .cornerRadius(DesignSystem.CornerRadius.sm)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(DesignSystem.Colors.primary.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .cornerRadius(DesignSystem.CornerRadius.sm)
                                .overlay(
                                    Image(systemName: "calendar")
                                        .foregroundColor(DesignSystem.Colors.primary)
                                        .font(.title2)
                                )
                        }
                    }
                    
                    // Event details
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text(title)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .lineLimit(1)
                        
                        Text(subtitle)
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .lineLimit(1)
                        
                        HStack {
                            Text(dateRange)
                                .font(DesignSystem.Typography.caption1)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            DSStatusBadge(text: status == .active ? "Active" : "Inactive", status: status)
                        }
                    }
                    
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DSProductRow: View {
    let title: String
    let price: String
    let stock: Int
    let sizes: [String]
    let isActive: Bool
    let image: UIImage?
    let onRemove: (() -> Void)?
    
    var body: some View {
        DSCard(padding: DesignSystem.Spacing.lg) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Product image
                Group {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(DesignSystem.Colors.success.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                            .overlay(
                                Image(systemName: "tshirt")
                                    .foregroundColor(DesignSystem.Colors.success)
                            )
                    }
                }
                
                // Product details
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text(title)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(1)
                    
                    HStack {
                        Text(price)
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .fontWeight(.semibold)
                        
                        Text("•")
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        
                        Text("\(stock) in stock")
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(stock > 0 ? DesignSystem.Colors.success : DesignSystem.Colors.danger)
                    }
                    
                    Text(sizes.joined(separator: ", "))
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Status and actions
                HStack(spacing: DesignSystem.Spacing.md) {
                    DSStatusBadge(
                        text: isActive ? "Active" : "Off",
                        status: isActive ? .active : .inactive
                    )
                    
                    if let onRemove = onRemove {
                        Button(action: onRemove) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(DesignSystem.Colors.danger)
                                .font(.system(size: 18))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Danger Zone Component
struct DSDangerZone<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content
    
    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        DSCard(style: .outlined, padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.danger)
                    
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                
                content
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(DesignSystem.Colors.danger.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview Content
struct EnhancedDesignSystemPreview: View {
    @State private var sampleText = ""
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.sectionSpacing) {
                    
                    // Colors
                    DSSectionCard(title: "Color Palette", subtitle: "Adaptive colors for light and dark mode") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: DesignSystem.Spacing.md) {
                            ColorSwatch(name: "Primary", color: DesignSystem.Colors.primary)
                            ColorSwatch(name: "Success", color: DesignSystem.Colors.success)
                            ColorSwatch(name: "Warning", color: DesignSystem.Colors.warning)
                            ColorSwatch(name: "Danger", color: DesignSystem.Colors.danger)
                        }
                    }
                    
                    // Typography
                    DSSectionCard(title: "Typography") {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Large Title Text")
                                .font(DesignSystem.Typography.largeTitle)
                            Text("Headline Text")
                                .font(DesignSystem.Typography.headline)
                            Text("Subheadline Text")
                                .font(DesignSystem.Typography.subheadline)
                            Text("Body text for regular content and descriptions")
                                .font(DesignSystem.Typography.body)
                            Text("Caption text for small details")
                                .font(DesignSystem.Typography.caption1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Buttons
                    DSSectionCard(title: "Buttons") {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            DSButton(title: "Primary Button", style: .primary, icon: "star.fill") {
                                print("Primary tapped")
                            }
                            DSButton(title: "Secondary Button", style: .secondary) {
                                print("Secondary tapped")
                            }
                            DSButton(title: "Danger Button", style: .danger, icon: "trash") {
                                print("Danger tapped")
                            }
                            DSButton(title: "Disabled Button", disabled: true) {
                                print("Won't be called")
                            }
                        }
                    }
                    
                    // Form Elements
                    DSSectionCard(title: "Form Elements", subtitle: "Enhanced form fields with better borders") {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            DSTextField(
                                label: "Email Address",
                                placeholder: "Enter your email",
                                text: $sampleText,
                                required: true
                            )
                            DSTextField(
                                label: "Optional Field",
                                placeholder: "This is optional",
                                text: $sampleText
                            )
                            DSTextField(
                                label: "Error Field",
                                placeholder: "This field has an error",
                                text: $sampleText,
                                required: true,
                                errorMessage: "This field is required"
                            )
                        }
                    }
                    
                    // Status Badges
                    DSSectionCard(title: "Status Badges") {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            HStack {
                                DSStatusBadge(text: "Active", status: .active)
                                DSStatusBadge(text: "Pending", status: .pending)
                                DSStatusBadge(text: "Inactive", status: .inactive)
                            }
                            HStack {
                                DSStatusBadge(text: "Success", status: .success, size: .medium)
                                DSStatusBadge(text: "Warning", status: .warning, size: .medium)
                                DSStatusBadge(text: "Danger", status: .danger, size: .medium)
                            }
                        }
                    }
                    
                    // Image Picker
                    DSSectionCard(title: "Image Picker", subtitle: "Updated to match EditEventView styling") {
                        DSImagePicker(
                            selectedImage: $selectedImage,
                            isUploading: $isUploading,
                            hasExistingImage: false,
                            onImageSelected: { _ in
                                // Handle image selection
                                print("Image selected")
                            },
                            onRemoveImage: {
                                selectedImage = nil
                            }
                        )
                    }
                    
                    // Event Row Example
                    DSSectionCard(title: "Event Row") {
                        DSEventRow(
                            title: "Summer Music Festival",
                            subtitle: "Central Park Venue",
                            dateRange: "Jul 15, 2:00 PM - 11:00 PM",
                            status: .active,
                            image: nil
                        ) {
                            print("Event tapped")
                        }
                    }
                    
                    // Product Row Example
                    DSSectionCard(title: "Product Row") {
                        DSProductRow(
                            title: "Festival T-Shirt",
                            price: "$24.99",
                            stock: 156,
                            sizes: ["S", "M", "L", "XL"],
                            isActive: true,
                            image: nil,
                            onRemove: {
                                print("Remove product")
                            }
                        )
                    }
                    
                    // Danger Zone Example
                    DSSectionCard(title: "Danger Zone") {
                        DSDangerZone(
                            title: "Delete Event",
                            subtitle: "This action cannot be undone and will remove all associated data."
                        ) {
                            DSButton(
                                title: "Delete Event",
                                style: .danger,
                                icon: "trash"
                            ) {
                                print("Delete tapped")
                            }
                        }
                    }
                    
                    // Card Styles
                    DSSectionCard(title: "Card Styles") {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            DSCard(style: .elevated) {
                                Text("Elevated Card")
                                    .font(DesignSystem.Typography.subheadline)
                            }
                            
                            DSCard(style: .flat) {
                                Text("Flat Card")
                                    .font(DesignSystem.Typography.subheadline)
                            }
                            
                            DSCard(style: .outlined) {
                                Text("Outlined Card")
                                    .font(DesignSystem.Typography.subheadline)
                            }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.screenPadding)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Enhanced Design System")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Color Swatch Component
struct ColorSwatch: View {
    let name: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Rectangle()
                .fill(color)
                .frame(height: 40)
                .cornerRadius(DesignSystem.CornerRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
                )
            
            Text(name)
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .lineLimit(1)
        }
    }
}

// MARK: - Empty State Component
struct DSEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    let primaryAction: (() -> Void)?
    let primaryActionTitle: String?
    let secondaryAction: (() -> Void)?
    let secondaryActionTitle: String?
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        primaryActionTitle: String? = nil,
        primaryAction: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxxl) {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: 64))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text(title)
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            
            if primaryAction != nil || secondaryAction != nil {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    if let primaryActionTitle = primaryActionTitle,
                       let primaryAction = primaryAction {
                        DSButton(
                            title: primaryActionTitle,
                            style: .primary,
                            size: .large,
                            action: primaryAction
                        )
                    }
                    
                    if let secondaryActionTitle = secondaryActionTitle,
                       let secondaryAction = secondaryAction {
                        DSButton(
                            title: secondaryActionTitle,
                            style: .secondary,
                            size: .large,
                            action: secondaryAction
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.xxxxl)
            }
        }
        .padding(DesignSystem.Spacing.xxxxl)
    }
}

// MARK: - Loading Overlay Component
struct DSLoadingOverlay: View {
    let message: String
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                DSCard {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                            .scaleEffect(1.5)
                        
                        Text(message)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }
                    .padding(DesignSystem.Spacing.xl)
                }
                .frame(maxWidth: 200)
            }
        }
    }
}

// MARK: - Form Section Component
struct DSFormSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content
    
    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
            
            content
        }
    }
}

// MARK: - Toggle Component
struct DSToggle: View {
    let label: String
    let subtitle: String?
    @Binding var isOn: Bool
    let disabled: Bool
    
    init(
        label: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>,
        disabled: Bool = false
    ) {
        self.label = label
        self.subtitle = subtitle
        self._isOn = isOn
        self.disabled = disabled
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(label)
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .disabled(disabled)
                .opacity(disabled ? 0.6 : 1.0)
        }
    }
}

// MARK: - Date Picker Component
struct DSDatePicker: View {
    let label: String
    @Binding var date: Date
    let displayedComponents: DatePickerComponents
    let disabled: Bool
    
    init(
        label: String,
        date: Binding<Date>,
        displayedComponents: DatePickerComponents = [.date, .hourAndMinute],
        disabled: Bool = false
    ) {
        self.label = label
        self._date = date
        self.displayedComponents = displayedComponents
        self.disabled = disabled
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(label)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            DatePicker(
                "",
                selection: $date,
                displayedComponents: displayedComponents
            )
            .labelsHidden()
            .disabled(disabled)
            .opacity(disabled ? 0.6 : 1.0)
        }
    }
}

// MARK: - Slider Component
struct DSSlider: View {
    let label: String
    let subtitle: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let disabled: Bool
    
    init(
        label: String,
        subtitle: String? = nil,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 1,
        unit: String = "",
        disabled: Bool = false
    ) {
        self.label = label
        self.subtitle = subtitle
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.disabled = disabled
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(label)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
                
                Spacer()
                
                Text("\(Int(value)) \(unit)")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .fontWeight(.semibold)
                    .frame(minWidth: 60, alignment: .trailing)
            }
            
            Slider(value: $value, in: range, step: step)
                .disabled(disabled)
                .opacity(disabled ? 0.6 : 1.0)
        }
    }
}

// MARK: - Preview Provider
struct EnhancedDesignSystemPreview_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EnhancedDesignSystemPreview()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            EnhancedDesignSystemPreview()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
