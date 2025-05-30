// File: Views/Preview/SimpleDesignPreview.swift

import SwiftUI

struct SimpleDesignPreview: View {
    @State private var sampleText = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppDesignSystem.Spacing.sectionSpacing) {
                
                // Test the card
                AppCard {
                    Text("This is a simple card test")
                        .font(AppDesignSystem.Typography.body)
                }
                
                // Test the section card
                AppSectionCard("Section Title") {
                    Text("This is section content")
                        .font(AppDesignSystem.Typography.body)
                }
                
                // Test buttons
                VStack(spacing: AppDesignSystem.Spacing.lg) {
                    AppButton("Primary Button") {}
                    AppButton("Secondary Button", style: .secondary) {}
                    AppButton("Danger Button", style: .danger) {}
                }
                
                // Test text field
                AppTextField("Email", text: $sampleText, placeholder: "Enter email")
                
                // Test status badges
                HStack {
                    AppStatusBadge(text: "Active", status: .active)
                    AppStatusBadge(text: "Pending", status: .pending)
                    AppStatusBadge(text: "Inactive", status: .inactive)
                }
            }
            .screenLayout()
        }
        .navigationTitle("Design Test")
    }
}

struct SimpleDesignPreview_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SimpleDesignPreview()
        }
    }
}
