import Foundation
import CoreLocation
import Combine

@MainActor
class WatchLocationManager: NSObject, ObservableObject {
    @Published var userLocation: CLLocation?
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var nearestStation: FavoriteStation?
    
    private let locationManager = CLLocationManager()
    private let logger = WatchLogger.shared
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        // Configure for Watch
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // Update when moved 100m
        
        logger.info("🗺️ WatchLocationManager initialized")
    }
    
    func requestLocation() {
        guard locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways else {
            logger.warning("🗺️ Location not authorized, status: \(locationStatus.rawValue)")
            return
        }
        
        logger.info("🗺️ Requesting location update")
        locationManager.requestLocation()
    }
    
    func startLocationUpdates() {
        guard locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways else {
            logger.warning("🗺️ Cannot start location updates - not authorized")
            return
        }
        
        logger.info("🗺️ Starting location updates")
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        logger.info("🗺️ Stopping location updates")
        locationManager.stopUpdatingLocation()
    }
    
    func updateNearestStation() {
        guard let userLocation = userLocation else {
            logger.debug("🗺️ No user location available for nearest station calculation")
            return
        }
        
        // Find nearest station from ALL available stations, not just favorites
        if let result = StationManager.shared.findNearestStation(to: userLocation) {
            let nearestFavoriteStation = FavoriteStation(
                id: result.station.id,
                name: result.station.name,
                latitude: result.station.latitude,
                longitude: result.station.longitude,
                uic_ref: result.station.uic_ref
            )
            
            self.nearestStation = nearestFavoriteStation
            logger.info("🗺️ Found nearest station from ALL stations: \(result.station.name) at \(String(format: "%.1f", result.distance))km")
            
            // Save to SharedDataManager for Widget access
            SharedDataManager.shared.saveNearestStation(nearestFavoriteStation)
        } else {
            self.nearestStation = nil
            logger.debug("🗺️ No nearest station found")
            SharedDataManager.shared.saveNearestStation(nil as FavoriteStation?)
        }
    }
}

extension WatchLocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            
            logger.info("🗺️ Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
            userLocation = location
            updateNearestStation()
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            logger.error("🗺️ Location error: \(error.localizedDescription)")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            logger.info("🗺️ Authorization status changed: \(status.rawValue)")
            
            locationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                requestLocation()
            case .denied, .restricted:
                logger.warning("🗺️ Location access denied")
            case .notDetermined:
                logger.info("🗺️ Location authorization not determined")
            @unknown default:
                logger.warning("🗺️ Unknown location authorization status")
            }
        }
    }
} 