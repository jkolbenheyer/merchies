import SwiftUI
import Foundation

struct OrderDetailView: View {
    let order: Order
    @Environment(\.presentationMode) private var presentationMode
    @State private var showingQRCode = false

    // Static formatter to avoid inline `let` bindings
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summarySection
                    itemsSection

                    // Show QR-code button only if still pending
                    if order.status == .pendingPickup {
                        Button {
                            showingQRCode = true
                        } label: {
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
                QRCodeSheet(order: order, isPresented: $showingQRCode)
            }
        }
    }

    // MARK: — Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Order Summary")
                .font(.headline)

            summaryRow(
                title: "Order #:",
                // Cast Substring to String here
                value: order.id.map { String($0.suffix(6)) } ?? ""
            )

            summaryRow(
                title: "Date:",
                value: Self.dateFormatter.string(from: order.createdAt)
            )

            HStack {
                Text("Status:")
                Spacer()
                statusBadge(for: order.status)
            }

            summaryRow(
                title: "Total:",
                value: String(format: "$%.2f", order.amount)
            )
            .fontWeight(.bold)

        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    // MARK: — Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Items")
                .font(.headline)
                .padding(.horizontal)

            ForEach(order.items, id: \.productId) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text("Product ID: \(String(item.productId.suffix(6)))")
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
    }

    // MARK: — Helpers

    @ViewBuilder
    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
        }
    }

    @ViewBuilder
    private func statusBadge(for status: OrderStatus) -> some View {
        let (bg, fg): (Color, Color) = {
            switch status {
            case .pendingPickup: return (Color.orange.opacity(0.2), .orange)
            case .pickedUp:      return (Color.green.opacity(0.2),  .green)
            case .cancelled:     return (Color.red.opacity(0.2),    .red)
            }
        }()
        Text(status.rawValue
                .capitalized
                .replacingOccurrences(of: "_", with: " "))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bg)
            .foregroundColor(fg)
            .cornerRadius(4)
    }
}


/// A separate sheet view for showing the QR code
struct QRCodeSheet: View {
    let order: Order
    @Binding var isPresented: Bool

    var body: some View {
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

            Text("Order #\(order.id.map { String($0.suffix(6)) } ?? "")")
                .font(.title3)
                .fontWeight(.semibold)

            Text("\(order.items.count) item\(order.items.count > 1 ? "s" : "")")
                .foregroundColor(.gray)

            Button("Close") {
                isPresented = false
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
