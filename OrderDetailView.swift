import SwiftUI

struct OrderDetailView: View {
    let order: Order
    @Environment(\.presentationMode) var presentationMode
    @State private var showingQRCode = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Order summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Order Summary")
                            .font(.headline)
                        
                        HStack {
                            Text("Order #:")
                            Spacer()
                            Text(order.id?.suffix(6) ?? "")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Date:")
                            Spacer()
                            // Format date
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            formatter.timeStyle = .short
                            Text(formatter.string(from: order.createdAt))
                        }
                        
                        HStack {
                            Text("Status:")
                            Spacer()
                            Text(order.status.rawValue.capitalized.replacingOccurrences(of: "_", with: " "))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    order.status == .pendingPickup ? Color.orange.opacity(0.2) :
                                    order.status == .pickedUp ? Color.green.opacity(0.2) :
                                    Color.red.opacity(0.2)
                                )
                                .foregroundColor(
                                    order.status == .pendingPickup ? Color.orange :
                                    order.status == .pickedUp ? Color.green :
                                    Color.red
                                )
                                .cornerRadius(4)
                        }
                        
                        HStack {
                            Text("Total:")
                            Spacer()
                            Text("$\(String(format: "%.2f", order.amount))")
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Items list
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Items")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(order.items, id: \.productId) { item in
                            HStack {
                                // In a real app, you would fetch the product details
                                // For now, we'll just show the ID
                                VStack(alignment: .leading) {
                                    Text("Product ID: \(item.productId.suffix(6))")
                                        .font(.subheadline)
                                    Text("Size: \(item.size)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Text("Qty: \(item.qty)")
                                    .font(.subheadline)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            .padding(.horizontal)
                        }
                    }
                    
                    // QR Code for pickup (if order is pending)
                    if order.status == .pendingPickup {
                        VStack(alignment: .center) {
                            Button(action: {
                                showingQRCode = true
                            }) {
                                HStack {
                                    Image(systemName: "qrcode")
                                    Text("Show QR Code for Pickup")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(10)
                                .padding(.horizontal)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Order Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingQRCode) {
                VStack(spacing: 20) {
                    Text("Show this QR code at pickup")
                        .font(.headline)
                        .padding(.top, 30)
                    
                    if let qrImage = QRService.generateQRCode(from: order.qrCode) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 250, height: 250)
                    }
                    
                    VStack(spacing: 5) {
                        Text("Order #\(order.id?.suffix(6) ?? "")")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("\(order.items.count) item\(order.items.count > 1 ? "s" : "")")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    
                    Button("Close") {
                        showingQRCode = false
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .cornerRadius(10)
                    .padding(.bottom, 30)
                }
            }
        }
    }
}
