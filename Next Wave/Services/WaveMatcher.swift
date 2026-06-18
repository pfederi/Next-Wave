import Foundation

/// A scheduled boat event at a dock near the track: a departure or an arrival.
struct BoatEvent: Equatable {
    let time: Date
    let isArrival: Bool
    let routeNumber: String
}

/// A contiguous "behind a boat" ride: track points the foiler covered while
/// chasing a boat's wake within the event's time window.
struct MatchedRide: Equatable {
    let routeNumber: String
    let startAt: Date
    let points: [GPXPoint]
}

/// Simplified, time-based matching. A Kursschiff departs from (or arrives at) a
/// dock near the foiler; the foiler launches shortly after a departure (chasing
/// the wake) or shortly before an arrival, and rides the wave. We mainly match on
/// **time**: the foiler's moving track within an event's wake window counts.
enum WaveMatcher {
    /// Max distance (m) from a dock for its schedule to be relevant to the track.
    static let dockRadius = 500.0
    /// Lead time (s): a foiler is underway ~30 s before catching the wake, so the
    /// window starts 30 s after a departure (and ends 30 s before an arrival).
    static let chaseLead = 30.0
    /// How long (s) the wake stays rideable — the length of the matching window.
    static let rideWindow = 180.0

    /// Returns the contiguous rides where the foiler was moving inside a boat
    /// event's wake window. Speed is derived from the raw GPS points (coordinates +
    /// Δt); Foilmotion's own speed is only a fallback when Δt is zero.
    static func matchedRides(points: [GPXPoint], events: [BoatEvent]) -> [MatchedRide] {
        guard points.count >= 2, !events.isEmpty else { return [] }

        // Each event → a [lo, hi] wake window. Departure: foiler chases just after;
        // arrival: foiler rides the incoming wake just before docking.
        let windows: [(lo: TimeInterval, hi: TimeInterval, route: String)] = events.map { e in
            let t = e.time.timeIntervalSince1970
            return e.isArrival
                ? (t - chaseLead - rideWindow, t - chaseLead, e.routeNumber)
                : (t + chaseLead, t + chaseLead + rideWindow, e.routeNumber)
        }

        func windowRoute(at t: TimeInterval) -> String? {
            for w in windows where t >= w.lo && t <= w.hi { return w.route }
            return nil
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
            let t = points[i].time.timeIntervalSince1970
            if let route = windowRoute(at: t), derivedSpeed(points, i) >= FoilConstants.foilSpeedThreshold {
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
