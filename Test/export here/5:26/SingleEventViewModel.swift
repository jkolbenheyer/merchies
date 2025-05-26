import Foundation
import Combine

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
}
