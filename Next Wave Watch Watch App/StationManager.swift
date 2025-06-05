import Foundation
import CoreLocation

class StationManager {
    static let shared = StationManager()
    
    private var allStations: [StationData] = []
    private let logger = WatchLogger.shared
    
    private init() {
        loadHardcodedStations()
    }
    
    private func loadHardcodedStations() {
        // Load ferry stations with CORRECT data from stations.json
        allStations = [
            // Zürichsee (most important ones)
            StationData(id: "Zürich Bürkliplatz (See)_8503651", name: "Zürich Bürkliplatz (See)", latitude: 47.365662, longitude: 8.541005, uic_ref: "8503651"),
            StationData(id: "Rapperswil SG (See)_8503667", name: "Rapperswil SG (See)", latitude: 47.225705, longitude: 8.813555, uic_ref: "8503667"),
            StationData(id: "Horgen (See)_8503672", name: "Horgen (See)", latitude: 47.261887, longitude: 8.59752, uic_ref: "8503672"),
            StationData(id: "Meilen (See)_8503661", name: "Meilen (See)", latitude: 47.267547, longitude: 8.640329, uic_ref: "8503661"),
            StationData(id: "Küsnacht ZH (See)_8503657", name: "Küsnacht ZH (See)", latitude: 47.318993, longitude: 8.578297, uic_ref: "8503657"),
            StationData(id: "Erlenbach ZH (See)_8503659", name: "Erlenbach ZH (See)", latitude: 47.303025, longitude: 8.589302, uic_ref: "8503659"),
            StationData(id: "Herrliberg (See)_8503661", name: "Herrliberg (See)", latitude: 47.283303, longitude: 8.6095295, uic_ref: "8503661"),
            StationData(id: "Männedorf (See)_8503664", name: "Männedorf (See)", latitude: 47.252789, longitude: 8.689093, uic_ref: "8503664"),
            StationData(id: "Stäfa (See)_8503665", name: "Stäfa (See)", latitude: 47.238703, longitude: 8.718443, uic_ref: "8503665"),
            StationData(id: "Uerikon (See)_8503666", name: "Uerikon (See)", latitude: 47.233487, longitude: 8.758165, uic_ref: "8503666"),
            StationData(id: "Pfäffikon SZ (See)_8503680", name: "Pfäffikon SZ (See)", latitude: 47.207941, longitude: 8.775131, uic_ref: "8503680"),
            StationData(id: "Schmerikon (See)_8503647", name: "Schmerikon (See)", latitude: 47.224573, longitude: 8.940312, uic_ref: "8503647"),
            StationData(id: "Wädenswil (See)_8503670", name: "Wädenswil (See)", latitude: 47.230133, longitude: 8.675343, uic_ref: "8503670"),
            StationData(id: "Richterswil (See)_8503669", name: "Richterswil (See)", latitude: 47.209095, longitude: 8.707292, uic_ref: "8503669"),
            StationData(id: "Thalwil (See)_8503674", name: "Thalwil (See)", latitude: 47.296677, longitude: 8.568049, uic_ref: "8503674"),
            StationData(id: "Rüschlikon (See)_8503675", name: "Rüschlikon (See)", latitude: 47.309769, longitude: 8.55838, uic_ref: "8503675"),
            
            // Vierwaldstättersee
            StationData(id: "Luzern Schweizerhofquai_8508505", name: "Luzern Schweizerhofquai", latitude: 47.05363, longitude: 8.309939, uic_ref: "8508505"),
            StationData(id: "Weggis_8508463", name: "Weggis", latitude: 47.031417, longitude: 8.433224, uic_ref: "8508463"),
            StationData(id: "Vitznau_8508464", name: "Vitznau", latitude: 47.009354, longitude: 8.482384, uic_ref: "8508464"),
            StationData(id: "Landungssteg SGV Brunnen_8508470", name: "Landungssteg SGV Brunnen", latitude: 46.993551, longitude: 8.605311, uic_ref: "8508470"),
            StationData(id: "Flüelen (See)_8508476", name: "Flüelen (See)", latitude: 46.902687, longitude: 8.62392, uic_ref: "8508476"),
            StationData(id: "Beckenried (See)_8508467", name: "Beckenried (See)", latitude: 46.966964, longitude: 8.475607, uic_ref: "8508467")
        ]
        
        logger.info("🗄️ Loaded \(allStations.count) ferry stations with correct UIC references")
    }
    
    func findNearestStation(to location: CLLocation) -> (station: StationData, distance: Double)? {
        var nearestStation: StationData?
        var shortestDistance = Double.infinity
        
        for station in allStations {
            let stationLocation = CLLocation(
                latitude: station.latitude,
                longitude: station.longitude
            )
            
            let distance = location.distance(from: stationLocation) / 1000 // Convert to kilometers
            if distance < shortestDistance {
                shortestDistance = distance
                nearestStation = station
            }
        }
        
        if let station = nearestStation {
            return (station: station, distance: shortestDistance)
        }
        
        return nil
    }
}

struct StationData {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let uic_ref: String?
} 