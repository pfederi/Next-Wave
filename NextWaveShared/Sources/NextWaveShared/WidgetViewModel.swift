import Foundation
import CoreLocation

public actor WidgetViewModel {
    public static let shared = WidgetViewModel()
    private let transportAPI = TransportAPI()
    private var departuresCache: [String: [Journey]] = [:]
    
    private init() {
        AppGroup.initialize()
    }
    
    private struct Location: Codable {
        let latitude: Double
        let longitude: Double
        
        var clLocation: CLLocation {
            CLLocation(latitude: latitude, longitude: longitude)
        }
        
        init(dictionary: [String: Double]) {
            self.latitude = dictionary["latitude"] ?? 0
            self.longitude = dictionary["longitude"] ?? 0
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            latitude = try container.decode(Double.self, forKey: .latitude)
            longitude = try container.decode(Double.self, forKey: .longitude)
        }
        
        private enum CodingKeys: String, CodingKey {
            case latitude
            case longitude
        }
    }
    
    public func getNextDeparture(for stationId: String) async -> Date? {
        do {
            let departures = try await transportAPI.getDepartures(for: stationId, date: Date())
            return departures.first?.time
        } catch {
            print("❌ Error fetching departures for \(stationId): \(error)")
            return nil
        }
    }
    
    public func getNearestStation() async -> (station: Lake.Station, distance: Double)? {
        guard let defaults = AppGroup.userDefaults else {
            print("❌ UserDefaults not available")
            return nil
        }
        
        // Load and decode location
        guard let locationData = defaults.data(forKey: AppGroup.Keys.lastLocation) else {
            print("❌ No location data found")
            return nil
        }
        
        let savedLocation: Location
        do {
            if let locationDict = try JSONSerialization.jsonObject(with: locationData) as? [String: Double] {
                savedLocation = Location(dictionary: locationDict)
                print("✅ Successfully decoded location: \(savedLocation.latitude), \(savedLocation.longitude)")
            } else {
                print("❌ Invalid location data format")
                return nil
            }
        } catch {
            print("❌ Failed to decode location data: \(error)")
            return nil
        }
        
        // Load and decode stations
        guard let stationsData = defaults.data(forKey: AppGroup.Keys.stations) else {
            print("❌ No stations data found")
            return nil
        }
        
        let stations: [Lake]
        do {
            stations = try JSONDecoder().decode([Lake].self, from: stationsData)
            print("✅ Successfully decoded \(stations.count) lakes")
        } catch {
            print("❌ Failed to decode stations data: \(error)")
            return nil
        }
        
        let location = savedLocation.clLocation
        var nearestStation: Lake.Station?
        var shortestDistance = Double.infinity
        
        for lake in stations {
            for station in lake.stations {
                guard let coordinates = station.coordinates else { continue }
                
                let stationLocation = CLLocation(
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude
                )
                
                let distance = location.distance(from: stationLocation) / 1000 // Convert to kilometers
                if distance < shortestDistance {
                    shortestDistance = distance
                    nearestStation = station
                }
            }
        }
        
        if let station = nearestStation {
            print("✅ Found nearest station: \(station.name) at \(shortestDistance)km")
            return (station: station, distance: shortestDistance)
        } else {
            print("❌ No station found within range")
            return nil
        }
    }
}

// MARK: - Transport API
extension WidgetViewModel {
    struct Journey: Codable {
        let time: Date
        
        enum CodingKeys: String, CodingKey {
            case time = "departure"
        }
    }
    
    actor TransportAPI {
        private let decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
        
        func getDepartures(for stationId: String, date: Date) async throws -> [Journey] {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            
            guard let url = URL(string: "https://pumpfoiling.community/api/departures/\(stationId)?date=\(dateString)") else {
                throw URLError(.badURL)
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            return try decoder.decode([Journey].self, from: data)
        }
    }
} 