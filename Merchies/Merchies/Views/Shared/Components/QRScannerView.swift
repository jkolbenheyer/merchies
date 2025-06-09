import SwiftUI
import AVFoundation
import Foundation

struct QRScannerView: UIViewRepresentable {
    @Binding var hasPermission: Bool
    @Binding var permissionDenied: Bool
    
    let onCodeScanned: (String) -> Void
    
    init(onCodeScanned: @escaping (String) -> Void, hasPermission: Binding<Bool> = .constant(true), permissionDenied: Binding<Bool> = .constant(false)) {
        self.onCodeScanned = onCodeScanned
        self._hasPermission = hasPermission
        self._permissionDenied = permissionDenied
    }
    
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: QRScannerView
        var codeFound = false
        
        init(_ parent: QRScannerView) {
            self.parent = parent
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if !codeFound, let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               let code = metadataObject.stringValue {
                // Only process the first QR code found
                codeFound = true
                
                // Provide haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Notify parent of the scanned code
                DispatchQueue.main.async {
                    self.parent.onCodeScanned(code)
                    
                    // Reset after a short delay to allow for new scans
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.codeFound = false
                    }
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        // Check camera permission first
        checkCameraPermission { [weak view] granted in
            DispatchQueue.main.async {
                if granted {
                    self.setupCamera(in: view, context: context)
                } else {
                    self.showPermissionDeniedMessage(in: view)
                }
            }
        }
        
        return view
    }
    
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.permissionDenied = true
            }
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func showPermissionDeniedMessage(in view: UIView?) {
        guard let view = view else { return }
        
        let label = UILabel()
        label.text = "Camera access is required to scan QR codes.\nPlease enable camera access in Settings."
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        
        DispatchQueue.main.async {
            self.hasPermission = false
            self.permissionDenied = true
        }
    }
    
    private func setupCamera(in view: UIView?, context: Context) {
        guard let view = view else { return }
        
        let captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            showErrorMessage(in: view, message: "Camera not available")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            showErrorMessage(in: view, message: "Failed to access camera: \(error.localizedDescription)")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            showErrorMessage(in: view, message: "Failed to configure camera input")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            showErrorMessage(in: view, message: "Failed to configure camera output")
            return
        }
        
        // Add preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Start capture session
        DispatchQueue.global(qos: .background).async {
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        }
        
        DispatchQueue.main.async {
            self.hasPermission = true
        }
    }
    
    private func showErrorMessage(in view: UIView, message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        
        DispatchQueue.main.async {
            self.hasPermission = false
        }
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer bounds if needed
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}