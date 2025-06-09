import SwiftUI
import AVFoundation
import Foundation

struct OrderScannerView: View {
    @StateObject private var orderViewModel = OrderViewModel()
    @State private var isScanning = false
    @State private var scannedCode: String?
    @State private var showingOrderDetail = false
    @State private var scannedOrder: Order?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var hasPermission = true
    @State private var permissionDenied = false
    @State private var isLoadingOrder = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isScanning {
                    ZStack {
                        QRScannerView(
                            onCodeScanned: { code in
                                // Prevent multiple scans while one is processing
                                guard !isLoadingOrder else { return }
                                
                                scannedCode = code
                                isLoadingOrder = true
                                
                                // Fetch the real order from Firestore based on QR code
                                print("🔍 OrderScannerView: Fetching order for QR code: \(code)")
                                
                                // Add timeout to prevent hanging
                                let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                                    DispatchQueue.main.async {
                                        if isLoadingOrder {
                                            isLoadingOrder = false
                                            isScanning = false
                                            errorMessage = "Request timed out. Please try scanning again."
                                            showingError = true
                                        }
                                    }
                                }
                                
                                orderViewModel.fetchOrderByQRCode(qrCode: code) { order in
                                    DispatchQueue.main.async {
                                        timeoutTimer.invalidate() // Cancel timeout
                                        isLoadingOrder = false
                                        isScanning = false
                                        
                                        if let order = order, order.id != nil && !order.id!.isEmpty {
                                            print("✅ OrderScannerView: Order found, setting for display: \(order.id!)")
                                            scannedOrder = order
                                            showingOrderDetail = true
                                        } else {
                                            print("❌ OrderScannerView: No valid order found for QR code: \(code)")
                                            errorMessage = "Unable to load order details. Please try scanning again."
                                            showingError = true
                                        }
                                    }
                                }
                            },
                            hasPermission: $hasPermission,
                            permissionDenied: $permissionDenied
                        )
                        
                        if hasPermission && !permissionDenied {
                            VStack {
                                Spacer()
                                
                                if isLoadingOrder {
                                    VStack(spacing: 16) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.5)
                                        
                                        Text("Loading order details...")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                    .padding()
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(10)
                                    .padding(.bottom, 50)
                                } else {
                                    Text("Scanning for QR code...")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.black.opacity(0.7))
                                        .cornerRadius(10)
                                        .padding(.bottom, 50)
                                }
                            }
                        } else if permissionDenied {
                            VStack(spacing: 20) {
                                Spacer()
                                
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                                
                                Text("Camera Access Required")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Text("Please enable camera access in Settings to scan QR codes.")
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button("Open Settings") {
                                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(settingsUrl)
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(10)
                                
                                Spacer()
                            }
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
                Group {
                    if let order = scannedOrder {
                        ScannedOrderDetailView(order: order, onComplete: {
                            print("🔍 OrderScannerView: Completing order detail view")
                            DispatchQueue.main.async {
                                showingOrderDetail = false
                                scannedOrder = nil
                                scannedCode = nil
                            }
                        })
                    } else {
                        // This should not happen with our improved logic, but provides a fallback
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            
                            Text("Order Loading Error")
                                .font(.headline)
                            
                            Text("Unable to load order details. Please try scanning again.")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Close") {
                                DispatchQueue.main.async {
                                    showingOrderDetail = false
                                    scannedOrder = nil
                                    scannedCode = nil
                                }
                            }
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding()
                        .onAppear {
                            print("❌ OrderScannerView: Sheet shown but scannedOrder is nil!")
                        }
                    }
                }
            }
            .alert("QR Code Error", isPresented: $showingError) {
                Button("Try Again") {
                    isScanning = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
}
