import Foundation

struct Schedule: Codable {
    let periods: [String: PeriodSchedule]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        periods = try container.decode([String: PeriodSchedule].self)
    }
    
    init(periods: [String: PeriodSchedule]) {
        self.periods = periods
    }
}

struct PeriodSchedule: Codable {
    let routes: [String: RouteSchedule]
}

struct RouteSchedule: Codable {
    let stops: [String: StopSchedule]
    let routeInfo: RouteInfo
}

struct RouteInfo: Codable {
    let routeNumber: String
    let baseTime: String
    let frequency: String
}

struct StopSchedule: Codable {
    var departures: [String]
    var arrivals: [String]
    
    enum CodingKeys: String, CodingKey {
        case departures = "Abfahrten"
        case arrivals = "Ankünfte"
    }
    
    init(departures: [String] = [], arrivals: [String] = []) {
        self.departures = departures
        self.arrivals = arrivals
    }
}