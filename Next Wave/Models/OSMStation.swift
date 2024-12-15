import Foundation

struct OSMStationResponse: Codable {
    let elements: [OSMStation]
}

struct OSMStation: Codable {
    let type: String?
    let id: Int
    let lat: Double?
    let lon: Double?
    let tags: StationTags
}

struct StationTags: Codable {
    let name: String?
    let uic_ref: String?
    let uic_name: String?
    let operator_name: String?
    let lake: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case uic_ref
        case uic_name
        case operator_name = "operator"
        case lake
    }
} 