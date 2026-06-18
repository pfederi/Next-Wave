import Foundation

struct VerifiedStats: Decodable, Equatable {
    let sessionCount: Int
    let totalDistanceM: Double
    let longestRideM: Double
    let maxSpeedMs: Double

    enum CodingKeys: String, CodingKey {
        case sessionCount = "session_count"
        case totalDistanceM = "total_distance_m"
        case longestRideM = "longest_ride_m"
        case maxSpeedMs = "max_speed_ms"
    }

    static let empty = VerifiedStats(sessionCount: 0, totalDistanceM: 0, longestRideM: 0, maxSpeedMs: 0)
}
