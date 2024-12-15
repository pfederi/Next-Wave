import Foundation

struct Station: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let uic_name: String?
    let uic_ref: String?
    let coordinates: Coordinates?
    
    struct Coordinates: Codable, Hashable {
        let lat: Double
        let lon: Double
    }
    
    // Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Station, rhs: Station) -> Bool {
        lhs.id == rhs.id
    }
} 