import SwiftUI

struct PaymentMethodsView: View {
    @State private var paymentMethods: [PaymentMethod] = []
    @State private var showingAddCard = false
    @State private var showingDeleteAlert = false
    @State private var cardToDelete: PaymentMethod?
    
    var body: some View {
        VStack(spacing: 0) {
            if paymentMethods.isEmpty {
                emptyStateView
            } else {
                // Payment Methods List
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(paymentMethods) { method in
                            PaymentMethodCard(
                                paymentMethod: method,
                                onDelete: {
                                    cardToDelete = method
                                    showingDeleteAlert = true
                                },
                                onSetDefault: {
                                    setDefaultPaymentMethod(method)
                                }
                            )
                        }
                        
                        // Add New Card Button
                        addNewCardButton
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Payment Methods")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !paymentMethods.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Card") {
                        showingAddCard = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddCard) {
            AddPaymentMethodView { newMethod in
                paymentMethods.append(newMethod)
            }
        }
        .alert("Delete Payment Method", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let card = cardToDelete {
                    deletePaymentMethod(card)
                }
            }
        } message: {
            Text("Are you sure you want to delete this payment method? This action cannot be undone.")
        }
        .onAppear {
            loadPaymentMethods()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 20) {
                Image(systemName: "creditcard")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("No Payment Methods")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Add a credit or debit card to make purchases easier")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: { showingAddCard = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Payment Method")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Add New Card Button
    
    private var addNewCardButton: some View {
        Button(action: { showingAddCard = true }) {
            HStack {
                Image(systemName: "plus.circle.dashed")
                    .font(.title2)
                Text("Add New Payment Method")
                    .fontWeight(.medium)
            }
            .foregroundColor(.purple)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Functions
    
    private func loadPaymentMethods() {
        // Mock data for now - in real app this would come from a payment service
        paymentMethods = [
            PaymentMethod(
                id: "1",
                type: .visa,
                lastFourDigits: "4242",
                expiryMonth: 12,
                expiryYear: 2026,
                isDefault: true
            ),
            PaymentMethod(
                id: "2",
                type: .mastercard,
                lastFourDigits: "8888",
                expiryMonth: 8,
                expiryYear: 2025,
                isDefault: false
            )
        ]
    }
    
    private func deletePaymentMethod(_ method: PaymentMethod) {
        paymentMethods.removeAll { $0.id == method.id }
        
        // If we deleted the default card, make the first remaining card default
        if method.isDefault && !paymentMethods.isEmpty {
            paymentMethods[0].isDefault = true
        }
    }
    
    private func setDefaultPaymentMethod(_ method: PaymentMethod) {
        // Remove default from all cards
        for i in paymentMethods.indices {
            paymentMethods[i].isDefault = false
        }
        
        // Set new default
        if let index = paymentMethods.firstIndex(where: { $0.id == method.id }) {
            paymentMethods[index].isDefault = true
        }
    }
}

// MARK: - Payment Method Models

struct PaymentMethod: Identifiable {
    let id: String
    let type: CardType
    let lastFourDigits: String
    let expiryMonth: Int
    let expiryYear: Int
    var isDefault: Bool
    
    enum CardType: String, CaseIterable {
        case visa = "Visa"
        case mastercard = "Mastercard"
        case amex = "American Express"
        case discover = "Discover"
        
        var icon: String {
            switch self {
            case .visa: return "creditcard"
            case .mastercard: return "creditcard"
            case .amex: return "creditcard"
            case .discover: return "creditcard"
            }
        }
        
        var color: Color {
            switch self {
            case .visa: return .blue
            case .mastercard: return .red
            case .amex: return .green
            case .discover: return .orange
            }
        }
    }
}

// MARK: - Payment Method Card

struct PaymentMethodCard: View {
    let paymentMethod: PaymentMethod
    let onDelete: () -> Void
    let onSetDefault: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Card Icon
                Image(systemName: paymentMethod.type.icon)
                    .font(.title2)
                    .foregroundColor(paymentMethod.type.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(paymentMethod.type.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if paymentMethod.isDefault {
                            Text("DEFAULT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("•••• •••• •••• \(paymentMethod.lastFourDigits)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Expires \(String(format: "%02d", paymentMethod.expiryMonth))/\(String(paymentMethod.expiryYear).suffix(2))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Actions Menu
                Menu {
                    if !paymentMethod.isDefault {
                        Button("Set as Default") {
                            onSetDefault()
                        }
                    }
                    
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Add Payment Method View

struct AddPaymentMethodView: View {
    @Environment(\.presentationMode) private var presentationMode
    let onCardAdded: (PaymentMethod) -> Void
    
    @State private var cardNumber = ""
    @State private var expiryDate = ""
    @State private var cvv = ""
    @State private var cardholderName = ""
    @State private var isDefault = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Card Information")) {
                    TextField("Card Number", text: $cardNumber)
                        .keyboardType(.numberPad)
                    
                    HStack {
                        TextField("MM/YY", text: $expiryDate)
                            .keyboardType(.numberPad)
                        
                        TextField("CVV", text: $cvv)
                            .keyboardType(.numberPad)
                    }
                    
                    TextField("Cardholder Name", text: $cardholderName)
                        .textContentType(.name)
                }
                
                Section {
                    Toggle("Set as default payment method", isOn: $isDefault)
                }
                
                Section(footer: Text("Your payment information is securely encrypted and stored.")) {
                    Button("Add Card") {
                        addCard()
                    }
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Add Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !cardNumber.isEmpty && !expiryDate.isEmpty && !cvv.isEmpty && !cardholderName.isEmpty
    }
    
    private func addCard() {
        // Mock card creation - in real app this would integrate with payment processor
        let newCard = PaymentMethod(
            id: UUID().uuidString,
            type: detectCardType(cardNumber),
            lastFourDigits: String(cardNumber.suffix(4)),
            expiryMonth: extractExpiryMonth(expiryDate),
            expiryYear: extractExpiryYear(expiryDate),
            isDefault: isDefault
        )
        
        onCardAdded(newCard)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func detectCardType(_ number: String) -> PaymentMethod.CardType {
        let cleanNumber = number.replacingOccurrences(of: " ", with: "")
        
        if cleanNumber.hasPrefix("4") {
            return .visa
        } else if cleanNumber.hasPrefix("5") || cleanNumber.hasPrefix("2") {
            return .mastercard
        } else if cleanNumber.hasPrefix("3") {
            return .amex
        } else {
            return .discover
        }
    }
    
    private func extractExpiryMonth(_ expiry: String) -> Int {
        let components = expiry.components(separatedBy: "/")
        return Int(components.first ?? "1") ?? 1
    }
    
    private func extractExpiryYear(_ expiry: String) -> Int {
        let components = expiry.components(separatedBy: "/")
        let yearString = components.last ?? "25"
        let year = Int(yearString) ?? 25
        return year < 50 ? 2000 + year : 1900 + year
    }
}