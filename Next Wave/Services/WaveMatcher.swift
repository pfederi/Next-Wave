import Foundation

/// One waypoint of a ferry's scheduled path: a stop's position at a point in time.
struct FerryWaypoint: Equatable {
    let lat: Double
    let lon: Double
    let t: TimeInterval   // epoch seconds
}

/// A ferry's reconstructed path over time — straight lines between its scheduled
/// stops. Lets us ask "where was this ferry at time t?".
struct FerryTrajectory: Equatable {
    let routeNumber: String
    let waypoints: [FerryWaypoint]   // sorted by t, strictly increasing

    /// Linearly interpolated ferry position at epoch time `t`,
    /// or nil if `t` is outside the trajectory's time span.
    func position(at t: TimeInterval) -> (lat: Double, lon: Double)? {
        guard let first = waypoints.first, let last = waypoints.last,
              t >= first.t, t <= last.t else { return nil }
        for i in 1..<waypoints.count {
            let a = waypoints[i - 1], b = waypoints[i]
            if t <= b.t {
                let span = b.t - a.t
                let f = span > 0 ? (t - a.t) / span : 0
                return (a.lat + (b.lat - a.lat) * f, a.lon + (b.lon - a.lon) * f)
            }
        }
        return (last.lat, last.lon)
    }
}

/// A contiguous "behind a ship" ride: track points that followed a moving ferry.
struct MatchedRide: Equatable {
    let routeNumber: String
    let startAt: Date
    let points: [GPXPoint]
}

enum WaveMatcher {
    /// How close (m) the foiler must be to the interpolated ferry position to
    /// count as riding its wake. Generous, to absorb straight-line and timing error.
    static let wakeRadius = 200.0

    /// Returns the contiguous rides where the foiler was moving AND within
    /// `wakeRadius` of a ferry that was underway at that moment. Speed is derived
    /// from the raw GPS points (coordinates + Δt); Foilmotion's own speed is only a
    /// fallback when Δt is zero.
    static func matchedRides(points: [GPXPoint], trajectories: [FerryTrajectory]) -> [MatchedRide] {
        guard points.count >= 2, !trajectories.isEmpty else { return [] }

        // The closest ferry route within wakeRadius at this point's time, or nil.
        func behindShip(_ p: GPXPoint, speed: Double) -> String? {
            guard speed >= FoilConstants.foilSpeedThreshold else { return nil }
            let t = p.time.timeIntervalSince1970
            var best: (route: String, d: Double)?
            for traj in trajectories {
                guard let pos = traj.position(at: t) else { continue }
                let d = GeoMath.distance(lat1: p.lat, lon1: p.lon, lat2: pos.lat, lon2: pos.lon)
                if d <= wakeRadius, best == nil || d < best!.d {
                    best = (traj.routeNumber, d)
                }
            }
            return best?.route
        }

        var rides: [MatchedRide] = []
        var current: [GPXPoint] = []
        var currentRoute = ""
        func flush() {
            if current.count >= 2 {
                rides.append(MatchedRide(routeNumber: currentRoute,
                                         startAt: current[0].time, points: current))
            }
            current = []
        }

        for i in points.indices {
            if let route = behindShip(points[i], speed: derivedSpeed(points, i)) {
                if current.isEmpty { currentRoute = route }
                current.append(points[i])
            } else {
                flush()
            }
        }
        flush()
        return rides
    }

    /// Speed (m/s) at index `i` from the neighbouring point (coordinates + Δt),
    /// falling back to Foilmotion's recorded speed only when Δt is zero.
    static func derivedSpeed(_ points: [GPXPoint], _ i: Int) -> Double {
        let j = i > 0 ? i - 1 : (i + 1 < points.count ? i + 1 : i)
        guard j != i else { return points[i].speed ?? 0 }
        let a = points[min(i, j)], b = points[max(i, j)]
        let dt = b.time.timeIntervalSince(a.time)
        guard dt > 0 else { return points[i].speed ?? 0 }
        return GeoMath.distance(lat1: a.lat, lon1: a.lon, lat2: b.lat, lon2: b.lon) / dt
    }
}
