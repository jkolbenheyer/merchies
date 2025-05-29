import Foundation
import UIKit
import CoreImage
import AVFoundation

class QRService {
    // Generate QR code from a string
    static func generateQRCode(from string: String, size: CGSize = CGSize(width: 250, height: 250)) -> UIImage? {
        if let data = string.data(using: .ascii),
           let qrFilter = CIFilter(name: "CIQRCodeGenerator") {
            
            qrFilter.setValue(data, forKey: "inputMessage")
            qrFilter.setValue("H", forKey: "inputCorrectionLevel") // Highest correction level
            
            if let qrImage = qrFilter.outputImage {
                // Scale the image to the requested size
                let transform = CGAffineTransform(scaleX: size.width / qrImage.extent.width, y: size.height / qrImage.extent.height)
                let scaledQrImage = qrImage.transformed(by: transform)
                
                let context = CIContext()
                if let cgImage = context.createCGImage(scaledQrImage, from: scaledQrImage.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }
        
        return nil
    }
}
