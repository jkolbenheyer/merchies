import SwiftUI
import AVFoundation
import Foundation

struct OrderScannerView: View {
    @StateObject private var orderViewModel = OrderViewModel()
    @State private var isScanning = false
    @State private var scannedCode: String?
    @State private var showingOrderDetail = false
    @State private var scannedOrder: Order?
    
    var body: some View {
        NavigationView {
            VStack {
                if isScanning {
                    ZStack {
                        QRScannerView(onCodeScanned: { code in
                            scannedCode = code
                            isScanning = false
                            
                            // In a real app, you would fetch the order from Firestore
                            // based on the QR code
                            // For now, we'll simulate finding an order
                            
                            // Simulate finding an order
                            let mockOrder = Order(
                                id: "order_123456",
                                userId: "user_abc",
                                bandId: "band_xyz",
                                items: [
                                    OrderItem(productId: "prod_1", size: "M", qty: 1),
                                    OrderItem(productId: "prod_2", size: "L", qty: 2)
                                ],
                                amount: 85.99,
                                status: .pendingPickup,
                                qrCode: code,
                                createdAt: Date()
                            )
                            
                            scannedOrder = mockOrder
                            showingOrderDetail = true
                        })
                        
                        VStack {
                            Spacer()
                            
                            Text("Scanning for QR code...")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(10)
                                .padding(.bottom, 50)
                        }
                    }
                    .navigationTitle("QR Scanner")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Cancel") {
                                isScanning = false
                            }
                        }
                    }
                } else {
                    VStack(spacing: 30) {
                        Image(systemName: "qrcode.viewfinder")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 150, height: 150)
                            .foregroundColor(.gray)
                        
                        Text("Scan QR Code to Verify Pickup")
                            .font(.headline)
                        
                        Button(action: {
                            isScanning = true
                        }) {
                            Text("Start Scanning")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 200)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(10)
                        }
                        .padding(.top, 20)
                    }
                    .navigationTitle("Scan Orders")
                }
            }
            .sheet(isPresented: $showingOrderDetail) {
                if let order = scannedOrder {
                    ScannedOrderDetailView(order: order, onComplete: {
                        showingOrderDetail = false
                        scannedOrder = nil
                        scannedCode = nil
                    })
                }
            }
        }
    }
}
