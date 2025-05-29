import Foundation
import CoreLocation
import SwiftUI

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var inEventGeofence: Bool = false
    @Published var currentEvent: Event?
    @Published var locationError: String?
    
    private var events: [Event] = []
    
    override init() {
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update when user moves 10 meters
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func setEvents(_ events: [Event]) {
        self.events = events
        checkGeofences()
    }
    
    func checkGeofences() {
        guard let currentLocation = currentLocation else { return }
        
        // Check if user is within any event geofence
        for event in events {
            let eventLocation = CLLocation(latitude: event.latitude, longitude: event.longitude)
            let distance = currentLocation.distance(from: eventLocation)
            
            if distance <= event.geofenceRadius {
                inEventGeofence = true
                currentEvent = event
                return
            }
        }
        
        inEventGeofence = false
        currentEvent = nil
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .denied, .restricted:
            locationError = "Location permission denied. Please enable location services in Settings."
            stopUpdatingLocation()
        case .notDetermined:
            // Wait for user's response
            break
        @unknown default:
            locationError = "Unknown location authorization status"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            currentLocation = location
            checkGeofences()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = "Location error: \(error.localizedDescription)"
    }
}
