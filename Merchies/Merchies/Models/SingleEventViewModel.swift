import Foundation
import Combine
import FirebaseStorage

class SingleEventViewModel: ObservableObject {
    @Published var event: Event
    @Published var isLoading = false
    @Published var error: String?

    private let service = FirestoreService()

    init(event: Event) {
        self.event = event
    }

    /// Persist changes back to Firestore.
    func save(completion: @escaping (Bool) -> Void = { _ in }) {
        isLoading = true
        service.updateEvent(event) { [weak self] err in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let err = err {
                    self?.error = err.localizedDescription
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }

    /// Upload an image to Storage and attach its URL to `event.imageUrl`
    func uploadImage(_ data: Data, completion: @escaping (Bool) -> Void = { _ in }) {
        isLoading = true
        error     = nil

        let imageID = event.id ?? UUID().uuidString
        let ref     = Storage.storage().reference()
                         .child("event_images/\(imageID).jpg")

        ref.putData(data, metadata: nil) { [weak self] _, err in
            if let err = err {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.error     = err.localizedDescription
                    completion(false)
                }
                return
            }
            ref.downloadURL { url, err2 in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let url = url {
                        self?.event.imageUrl = url.absoluteString
                        completion(true)
                    } else {
                        self?.error = err2?.localizedDescription
                        completion(false)
                    }
                }
            }
        }
    }
}
