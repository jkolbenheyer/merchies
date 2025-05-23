import Foundation
import CoreLocation

class EventViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private let firestoreService = FirestoreService()
    
    func fetchNearbyEvents(latitude: Double, longitude: Double) {
        isLoading = true
        
        // Standard search radius in km
        let searchRadius = 10.0
        
        firestoreService.fetchNearbyEvents(
            latitude: latitude,
            longitude: longitude,
            radiusInKm: searchRadius
        ) { [weak self] events, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                
                self?.events = events ?? []
            }
        }
    }
}
