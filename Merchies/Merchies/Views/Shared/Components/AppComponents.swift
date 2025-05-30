// FIXED: Add this to your AppComponents.swift file
// Replace the existing `if` extension with this corrected version:

import SwiftUI

// MARK: - View Extensions (CORRECTED)
extension View {
    /// Conditional view modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Screen layout modifier
    func screenLayout() -> some View {
        self
            .padding(AppDesignSystem.Spacing.screenPadding)
            .background(AppDesignSystem.Colors.groupedBackground)
    }
    
    /// Loading overlay modifier
    func loadingOverlay(isLoading: Bool, message: String = "Loading...") -> some View {
        self.overlay(
            Group {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: AppDesignSystem.Spacing.lg) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: AppDesignSystem.Colors.primary))
                        
                        Text(message)
                            .font(AppDesignSystem.Typography.headline)
                            .foregroundColor(AppDesignSystem.Colors.primaryText)
                    }
                    .padding(AppDesignSystem.Spacing.xxxl)
                    .background(AppDesignSystem.Colors.background)
                    .cornerRadius(AppDesignSystem.CornerRadius.lg)
                    .shadow(
                        color: AppDesignSystem.Shadow.modalShadow.color,
                        radius: AppDesignSystem.Shadow.modalShadow.radius,
                        x: AppDesignSystem.Shadow.modalShadow.x,
                        y: AppDesignSystem.Shadow.modalShadow.y
                    )
                }
            }
        )
    }
    
    /// Card styling modifier
    func cardStyle(showShadow: Bool = true) -> some View {
        self
            .padding(AppDesignSystem.Spacing.cardPadding)
            .background(AppDesignSystem.Colors.cardBackground)
            .cornerRadius(AppDesignSystem.CornerRadius.md)
            .if(showShadow) { view in
                view.shadow(
                    color: AppDesignSystem.Shadow.cardShadow.color,
                    radius: AppDesignSystem.Shadow.cardShadow.radius,
                    x: AppDesignSystem.Shadow.cardShadow.x,
                    y: AppDesignSystem.Shadow.cardShadow.y
                )
            }
    }
    
    /// Section spacing modifier
    func sectionSpacing() -> some View {
        self.padding(.bottom, AppDesignSystem.Spacing.sectionSpacing)
    }
}
