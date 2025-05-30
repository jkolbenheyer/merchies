// Utilities/Extensions/View+Extensions.swift
import SwiftUI
import Foundation

// MARK: - Loading & Error Handling Extensions

extension View {
    /// Show loading overlay with optional message
    func loading(_ isLoading: Bool, message: String = "Loading...") -> some View {
        self.overlay(
            Group {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        
                        Text(message)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 8)
                }
            }
        )
    }
    
    /// Show error alert with standardized styling
    func errorAlert(isPresented: Binding<Bool>, error: String?) -> some View {
        self.alert("Error", isPresented: isPresented) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(error ?? "An unexpected error occurred. Please try again.")
        }
    }
    
    /// Show success message overlay
    func successMessage(_ message: String, isShowing: Binding<Bool>) -> some View {
        self.overlay(
            Group {
                if isShowing.wrappedValue {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            
                            Text(message)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                        .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                isShowing.wrappedValue = false
                            }
                        }
                    }
                }
            }
        )
    }
}

// MARK: - Styling Extensions

extension View {
    /// Apply card styling with standard appearance
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    /// Apply section header styling
    func sectionHeaderStyle() -> some View {
        self
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }
    
    /// Apply primary button styling
    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color.blue)
            .cornerRadius(8)
    }
    
    /// Apply secondary button styling
    func secondaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
    }
    
    /// Apply destructive button styling
    func destructiveButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color.red)
            .cornerRadius(8)
    }
}

// MARK: - Navigation Extensions

extension View {
    /// Hide navigation bar
    func hideNavigationBar() -> some View {
        self.navigationBarHidden(true)
    }
    
    

    
    /// Add close button to navigation bar
    func closeButton(action: @escaping () -> Void) -> some View {
        self.toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close", action: action)
            }
        }
    }
    
    /// Add done button to navigation bar
    func doneButton(action: @escaping () -> Void) -> some View {
        self.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done", action: action)
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Conditional Modifiers

extension View {
    /// Apply modifier conditionally (renamed to avoid keyword conflict)
    @ViewBuilder
    func conditionalModifier<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply one of two modifiers based on condition
        @ViewBuilder
        func conditionalModifier<TrueContent: View, FalseContent: View>(
            _ condition: Bool,
            ifTrue: (Self) -> TrueContent,
            ifFalse: (Self) -> FalseContent
        ) -> some View {
            if condition {
                ifTrue(self)
            } else {
                ifFalse(self)
            }
        }
    }
// MARK: - Image Extensions

extension View {
    /// Apply standard product image styling
    func productImageStyle(size: CGFloat = 150) -> some View {
        self
            .frame(width: size, height: size)
            .cornerRadius(8)
            .clipped()
    }
    
    /// Apply circular avatar styling
    func avatarStyle(size: CGFloat = 80) -> some View {
        self
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
    
    /// Apply event image styling
    func eventImageStyle(height: CGFloat = 200) -> some View {
        self
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .cornerRadius(12)
            .clipped()
    }
}

// MARK: - Form Extensions

extension View {
    /// Apply standard form field styling
    func formFieldStyle() -> some View {
        self
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
    
    /// Apply form section styling
    func formSectionStyle() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }
}

// MARK: - Animation Extensions

extension View {
    /// Apply standard spring animation
    func standardAnimation() -> some View {
        self.animation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0), value: UUID())
    }
    
    /// Apply quick fade animation
    func quickFade() -> some View {
        self.animation(.easeInOut(duration: 0.2), value: UUID())
    }
    
    /// Apply smooth scale animation
    func smoothScale() -> some View {
        self.animation(.easeInOut(duration: 0.3), value: UUID())
    }
}

// MARK: - Keyboard Extensions

extension View {
    /// Dismiss keyboard on tap
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// MARK: - Accessibility Extensions

extension View {
    /// Add accessibility label and hint
    func accessibility(label: String, hint: String? = nil) -> some View {
        Group {
            if let hint = hint {
                self
                    .accessibilityLabel(label)
                    .accessibilityHint(hint)
            } else {
                self
                    .accessibilityLabel(label)
            }
        }
    }
    
    /// Mark as accessibility element with value
    func accessibilityElement(value: String) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityValue(value)
    }
}

// MARK: - Preview Extensions

extension View {
    /// Wrap view for preview with standard padding
    func previewLayout() -> some View {
        self
            .padding()
            .previewLayout(.sizeThatFits)
    }
    
    /// Preview with different color schemes
    func previewColorSchemes() -> some View {
        Group {
            self.preferredColorScheme(.light)
            self.preferredColorScheme(.dark)
        }
    }
}

// MARK: - Status Bar Extensions

extension View {
    /// Hide status bar
    func hideStatusBar() -> some View {
        self.statusBarHidden(true)
    }
    
    /// Set status bar style
    func statusBarStyle(_ style: UIStatusBarStyle) -> some View {
        self.preferredColorScheme(style == .lightContent ? .dark : .light)
    }
}
