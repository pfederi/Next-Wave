import Foundation

struct Lake: Codable, Identifiable, Hashable {
    let name: String
    let operators: [String]
    private let _stations: [Station]
    
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