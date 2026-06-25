import Foundation

struct VerifiedStats: Decodable, Equatable {
    let sessionCount: Int
    let totalDistanceM: Double
    let longestRideM: Double
    let maxSpeedMs: Double
    let distinctStations: Int

    enum CodingKeys: String, CodingKey {
        case sessionCount = "session_count"
        case totalDistanceM = "total_distance_m"
        case longestRideM = "longest_ride_m"
        case maxSpeedMs = "max_speed_ms"
        case distinctStations = "distinct_stations"
    }

    init(sessionCount: Int, totalDistanceM: Double, longestRideM: Double,
         maxSpeedMs: Double, distinctStations: Int = 0) {
        self.sessionCount = sessionCount
        self.totalDistanceM = totalDistanceM
        self.longestRideM = longestRideM
        self.maxSpeedMs = maxSpeedMs
        self.distinctStations = distinctStations
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionCount = try c.decode(Int.self, forKey: .sessionCount)
        totalDistanceM = try c.decode(Double.self, forKey: .totalDistanceM)
        longestRideM = try c.decode(Double.self, forKey: .longestRideM)
        maxSpeedMs = try c.decode(Double.self, forKey: .maxSpeedMs)
        // Tolerate the DB migration not yet applied (field absent).
        distinctStations = try c.decodeIfPresent(Int.self, forKey: .distinctStations) ?? 0
    }

    static let empty = VerifiedStats(sessionCount: 0, totalDistanceM: 0, longestRideM: 0, maxSpeedMs: 0)
}
