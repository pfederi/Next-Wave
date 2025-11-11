import Foundation

struct Lake: Codable, Identifiable, Hashable {
    let name: String
    let operators: [String]
    private let _stations: [Station]
    var waterTemperature: Double? // Wassertemperatur in °C
    var waterLevel: String? // Pegel (z.B. "405.96 m.ü.M.")
    var temperatureForecast: [TemperatureForecast]? // Vorhersage für nächste 2 Tage
    var waterLevelDifference: String? { // Differenz zum Durchschnitt (z.B. "+7 cm")
        guard let waterLevel = waterLevel else { return nil }
        return calculateWaterLevelDifference(for: name, currentLevel: waterLevel)
    }
    
    struct TemperatureForecast: Codable, Hashable {
        let time: Date
        let temperature: Double
    }
    
    var stations: [Station] {
        Array(_stations.reduce(into: Set<Station>()) { result, station in
            result.insert(station)
        }).sorted { $0.name < $1.name }
    }
    
    var id: String { name }
    
    enum CodingKeys: String, CodingKey {
        case name
        case operators
        case _stations = "stations"
        case waterTemperature
        case waterLevel
        case temperatureForecast
    }
    
    struct Station: Codable, Hashable, Identifiable {
        let name: String
        let uic_ref: String?
        let coordinates: Coordinates?
        
        var id: String {
            if let ref = uic_ref {
                return "\(name)_\(ref)"
            }
            return name
        }
        
        init(from decoder: Decoder) throws {
            if let container = try? decoder.singleValueContainer(),
               let stationName = try? container.decode(String.self) {
                self.name = stationName
                self.uic_ref = nil
                self.coordinates = nil
            } else {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.name = try container.decode(String.self, forKey: .name)
                self.uic_ref = try container.decode(String?.self, forKey: .uic_ref)
                self.coordinates = try container.decodeIfPresent(Coordinates.self, forKey: .coordinates)
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case name
            case uic_ref
            case coordinates
        }
        
        struct Coordinates: Codable, Hashable {
            let latitude: Double
            let longitude: Double
        }
    }
}

extension Lake.Station {
    static func == (lhs: Lake.Station, rhs: Lake.Station) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Helper function to calculate water level difference
private func calculateWaterLevelDifference(for lakeName: String, currentLevel: String) -> String? {
    // Reference levels from lake-water-levels.json
    let averageLevels: [String: Double] = [
        "Zürichsee": 405.94,
        "Vierwaldstättersee": 433.57,
        "Bodensee": 395.60,
        "Genfersee": 372.05,
        "Thunersee": 557.66,
        "Brienzersee": 563.77,
        "Lago Maggiore": 193.49,
        "Luganersee": 270.47,
        "Bielersee": 429.25,
        "Neuenburgersee": 429.29,
        "Murtensee": 429.30,
        "Zugersee": 413.57,
        "Walensee": 419.03,
        "Hallwilersee": 448.66,
        "Ägerisee": 723.76
    ]
    
    guard let averageLevel = averageLevels[lakeName] else { return nil }
    
    // Extract numeric value from string like "405.96 m.ü.M."
    let components = currentLevel.components(separatedBy: " ")
    guard let levelString = components.first,
          let current = Double(levelString) else { return nil }
    
    // Calculate difference in cm
    let differenceCm = Int(round((current - averageLevel) * 100))
    
    if differenceCm > 0 {
        return "+\(differenceCm)"
    } else if differenceCm < 0 {
        return "\(differenceCm)"
    } else {
        return "±0"
    }
} 