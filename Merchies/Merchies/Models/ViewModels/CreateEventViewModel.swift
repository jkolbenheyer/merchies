// Models/ViewModels/CreateEventViewModel.swift - Fixed Version

import Foundation
import Firebase
import FirebaseStorage
import SwiftUI

class EventCreationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    @Published var imageUrl: String?
    @Published var createdEventId: String?

    private let firestoreService = FirestoreService()

    func createEvent(_ event: Event, completion: @escaping (_ success: Bool) -> Void) {
        isLoading = true
        error = nil
        
        print("📝 EventCreationViewModel creating event with imageUrl: \(event.imageUrl ?? "nil")")
        
        // Use the correct FirestoreService method name
        firestoreService.saveNewEvent(event) { [weak self] (success: Bool, err: Error?) in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let err = err {
                    self?.error = err.localizedDescription
                    print("❌ Event creation failed: \(err.localizedDescription)")
                    completion(false)
                } else if success {
                    self?.createdEventId = event.id
                    print("✅ Event created successfully with ID: \(event.id ?? "unknown")")
                    completion(true)
                } else {
                    print("❌ Event creation failed - unknown error")
                    completion(false)
                }
            }
        }
    }

    func uploadImage(_ data: Data, completion: @escaping (_ success: Bool) -> Void) {
        isLoading = true
        error = nil
        let imageID = UUID().uuidString
        let ref = Storage.storage().reference().child("event_images/\(imageID).jpg")
        
        print("📤 EventCreationViewModel starting image upload...")
        
        ref.putData(data, metadata: nil) { [weak self] (_, err: Error?) in
            if let err = err {
                print("❌ Image upload error: \(err.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.error = err.localizedDescription
                    completion(false)
                }
                return
            }
            
            ref.downloadURL { (url: URL?, err2: Error?) in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let url = url {
                        self?.imageUrl = url.absoluteString
                        print("✅ Image uploaded successfully: \(url.absoluteString)")
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
    
    // Clear all data (useful for resetting the view model)
    func reset() {
        isLoading = false
        error = nil
        imageUrl = nil
        createdEventId = nil
    }
}
