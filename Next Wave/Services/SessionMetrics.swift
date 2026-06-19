import Foundation

enum FoilConstants {
    static let foilSpeedThreshold = 3.0   // m/s (~11 km/h)
}

struct SessionMetrics: Equatable {
    let start: Date
    let end: Date
    let duration: TimeInterval
    let movingTime: TimeInterval
    let totalDistance: Double       // meters
    let maxSpeed: Double            // m/s
    let longestRideDistance: Double // meters (longest continuous ride)

    /// nil when fewer than 2 points.
    static func compute(from points: [GPXPoint]) -> SessionMetrics? {
        guard points.count >= 2, let first = points.first, let last = points.last else { return nil }

        var total = 0.0, maxSpeed = 0.0, moving = 0.0, currentRide = 0.0, longestRide = 0.0
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            let seg = GeoMath.distance(lat1: a.lat, lon1: a.lon, lat2: b.lat, lon2: b.lon)
            let dt = b.time.timeIntervalSince(a.time)
            let speed = b.speed ?? (dt > 0 ? seg / dt : 0)

            total += seg
            maxSpeed = max(maxSpeed, speed)
            if speed >= FoilConstants.foilSpeedThreshold {
                moving += max(0, dt)
                currentRide += seg
                longestRide = max(longestRide, currentRide)
            } else {
                currentRide = 0
            }
        }

        return SessionMetrics(start: first.time, end: last.time,
                              duration: last.time.timeIntervalSince(first.time),
                              movingTime: moving, totalDistance: total, maxSpeed: maxSpeed,
                              longestRideDistance: longestRide)
    }
}
