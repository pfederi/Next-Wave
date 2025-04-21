import Foundation

struct DepartureInfo: Codable {
    let stationName: String
    let nextDeparture: Date
    let routeName: String
    let direction: String
} 