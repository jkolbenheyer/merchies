import Foundation
import Firebase
import FirebaseStorage
import UIKit
import SwiftUI

class ImageUploadService: ObservableObject {
    private let storage = Storage.storage()
    
    enum ImageType {
        case product
        case event
        case profile
        
        var folder: String {
            switch self {
            case .product: return "products"
            case .event: return "event_images"  // Match your existing EditEventView.swift
            case .profile: return "profiles"
            }
        }
    }
    
    /// Upload an image to Firebase Storage
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - type: The type of image (product, event, profile)
    ///   - id: Unique identifier for the image (product ID, event ID, etc.)
    ///   - completion: Completion handler with URL string or error
    func uploadImage(
        _ image: UIImage,
        type: ImageType,
        id: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Compress the image
        guard let imageData = compressImage(image) else {
            completion(.failure(ImageUploadError.compressionFailed))
            return
        }
        
        // Create storage reference
        let filename = "\(id)_\(UUID().uuidString).jpg"
        let storageRef = storage.reference().child("\(type.folder)/\(filename)")
        
        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload the image
        storageRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Get download URL
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("❌ ImageUploadService: Failed to get download URL: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url else {
                    print("❌ ImageUploadService: Download URL is nil")
                    completion(.failure(ImageUploadError.urlRetrievalFailed))
                    return
                }
                
                print("✅ ImageUploadService: Generated download URL: \(downloadURL.absoluteString)")
                completion(.success(downloadURL.absoluteString))
            }
        }
    }
    
    /// Delete an image from Firebase Storage
    /// - Parameters:
    ///   - imageUrl: The full URL of the image to delete
    ///   - completion: Completion handler
    func deleteImage(at imageUrl: String, completion: @escaping (Error?) -> Void) {
        guard let url = URL(string: imageUrl) else {
            completion(ImageUploadError.invalidURL)
            return
        }
        
        let storageRef = storage.reference(forURL: imageUrl)
        storageRef.delete { error in
            completion(error)
        }
    }
    
    /// Compress image for upload
    private func compressImage(_ image: UIImage) -> Data? {
        // Resize image if it's too large
        let maxSize: CGFloat = 1024
        let resizedImage: UIImage
        
        if image.size.width > maxSize || image.size.height > maxSize {
            let ratio = min(maxSize / image.size.width, maxSize / image.size.height)
            let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            resizedImage = image
        }
        
        // Compress with quality
        return resizedImage.jpegData(compressionQuality: 0.8)
    }
}

// MARK: - Error Types
enum ImageUploadError: LocalizedError {
    case compressionFailed
    case urlRetrievalFailed
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image for upload"
        case .urlRetrievalFailed:
            return "Failed to retrieve download URL"
        case .invalidURL:
            return "Invalid image URL"
        }
    }
}
