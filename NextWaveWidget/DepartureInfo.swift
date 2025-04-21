import Foundation

struct DepartureInfo: Codable, Identifiable {
    var stationName: String
    var nextDeparture: Date
    var routeName: String
    var direction: String
    
    var id: String {
        "\(stationName)-\(nextDeparture.timeIntervalSince1970)"
    }
} 