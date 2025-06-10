import SwiftUI

// MARK: - Simple Inventory Edit View
struct SimpleInventoryEditView: View {
    let product: Product
    @Binding var inventory: [String: Int]
    let onSave: ([String: Int]) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var editedInventory: [String: String] = [:]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Inventory for \(product.title)")) {
                    ForEach(product.sizes, id: \.self) { size in
                        HStack {
                            Text(size)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(width: 40, alignment: .leading)
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Button(action: {
                                    decreaseInventory(for: size)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title3)
                                }
                                .disabled((Int(editedInventory[size] ?? "0") ?? 0) <= 0)
                                
                                TextField("Qty", text: Binding(
                                    get: { editedInventory[size] ?? "0" },
                                    set: { editedInventory[size] = $0 }
                                ))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 60)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(.systemGray3), lineWidth: 1)
                                )
                                .cornerRadius(6)
                                
                                Button(action: {
                                    increaseInventory(for: size)
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.title3)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Edit Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                setupInitialInventory()
            }
        }
    }
    
    private func setupInitialInventory() {
        for size in product.sizes {
            editedInventory[size] = "\(inventory[size] ?? 0)"
        }
    }
    
    private func increaseInventory(for size: String) {
        let currentValue = Int(editedInventory[size] ?? "0") ?? 0
        editedInventory[size] = "\(currentValue + 1)"
    }
    
    private func decreaseInventory(for size: String) {
        let currentValue = Int(editedInventory[size] ?? "0") ?? 0
        let newValue = max(0, currentValue - 1)
        editedInventory[size] = "\(newValue)"
    }
    
    private func saveChanges() {
        var newInventory: [String: Int] = [:]
        for (size, value) in editedInventory {
            newInventory[size] = Int(value) ?? 0
        }
        onSave(newInventory)
        presentationMode.wrappedValue.dismiss()
    }
}