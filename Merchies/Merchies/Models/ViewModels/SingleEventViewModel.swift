// Updated SingleEventViewModel.swift - Uses Correct FirestoreService Methods

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

class SingleEventViewModel: ObservableObject {
    @Published var event: Event
    @Published var isLoading = false
    @Published var error: String?
    @Published var imageUrl: String? // Track image URL separately
    
    private let firestoreService = FirestoreService()
    
    init(event: Event) {
        self.event = event
        self.imageUrl = event.imageUrl // Initialize with existing image URL
    }
    
    // FIXED: Save method with proper image URL handling
    func save(completion: @escaping (Bool) -> Void) {
        isLoading = true
        error = nil
        
        print("💾 SingleEventViewModel saving event with imageUrl: \(event.imageUrl ?? "nil")")
        
        // Use the correct FirestoreService method name
        firestoreService.saveEvent(event) { [weak self] success, err in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let err = err {
                    self?.error = err.localizedDescription
                    print("❌ Event save error: \(err.localizedDescription)")
                    completion(false)
                } else if success {
                    print("✅ Event saved successfully")
                    completion(true)
                } else {
                    print("❌ Event save failed - unknown error")
                    completion(false)
                }
            }
        }
    }
    
    // Upload image method
    func uploadImage(_ data: Data, completion: @escaping (Bool) -> Void) {
        isLoading = true
        error = nil
        
        let imageID = UUID().uuidString
        let ref = Storage.storage().reference().child("event_images/\(imageID).jpg")
        
        print("📤 SingleEventViewModel uploading image...")
        
        ref.putData(data, metadata: nil) { [weak self] _, err in
            if let err = err {
                print("❌ Image upload error: \(err.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.error = err.localizedDescription
                    completion(false)
                }
                return
            }
            
            ref.downloadURL { url, err2 in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let url = url {
                        let urlString = url.absoluteString
                        self?.imageUrl = urlString
                        self?.event.imageUrl = urlString // Update the event model
                        print("✅ Image uploaded successfully: \(urlString)")
                        completion(true)
                    } else {
                        let errorMsg = err2?.localizedDescription ?? "Failed to get download URL"
                        print("❌ Download URL error: \(errorMsg)")
                        self?.error = errorMsg
                        completion(false)
                    }
                }
            }
        }
    }
    
    // Refresh event data from Firestore
    func refreshEvent() {
        guard let eventId = event.id else { return }
        
        isLoading = true
        error = nil
        
        // Use the correct FirestoreService method name
        firestoreService.fetchSingleEvent(eventId: eventId) { [weak self] fetchedEvent, err in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let err = err {
                    self?.error = err.localizedDescription
                    print("❌ Event refresh error: \(err.localizedDescription)")
                } else if let fetchedEvent = fetchedEvent {
                    self?.event = fetchedEvent
                    self?.imageUrl = fetchedEvent.imageUrl
                    print("✅ Event refreshed successfully")
                } else {
                    print("❌ Event refresh failed - no event returned")
                }
            }
        }
    }
    
    // Remove image method
    func removeImage(completion: @escaping (Bool) -> Void) {
        // Clear the image URL from the event
        event.imageUrl = nil
        imageUrl = nil
        
        // Save the updated event
        save { success in
            completion(success)
        }
    }
    
    // Helper method to check if event has an image
    var hasImage: Bool {
        return imageUrl != nil && !imageUrl!.isEmpty
    }
}
