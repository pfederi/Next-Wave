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
    /// A time gap (s) larger than this ends the current foiling run (a real break).
    static let runGapSeconds = 10.0
    /// Brief sub-threshold dips this many points long are tolerated mid-run (a
    /// pumpfoiler's speed oscillates between pumps; don't shatter a ride on each dip).
    static let slowTolerance = 4

    /// Matches the foiler's continuous moving runs against boat events. The model:
    /// once a foiling run **starts** inside a boat's wake window, the foiler is
    /// assumed to ride that wake until the run ends — so the **whole run** counts.
    /// Each event credits only the single most logical run (the one starting soonest
    /// within its window), not every run that happens to overlap. Speed is derived
    /// from the raw GPS points (coordinates + Δt); Foilmotion's own speed is only a
    /// fallback when Δt is zero.
    static func matchedRides(points: [GPXPoint], events: [BoatEvent]) -> [MatchedRide] {
        guard points.count >= 2, !events.isEmpty else { return [] }

        // 1. Split the track into foiling runs: a run is on-foil motion that ends
        //    on a real break (a >runGapSeconds time gap, or sustained slow). Brief
        //    sub-threshold dips while pumping are tolerated so a ride isn't shattered.
        var runs: [[GPXPoint]] = []
        var current: [GPXPoint] = []
        var slowStreak = 0
        func endRun() { if current.count >= 2 { runs.append(current) }; current = []; slowStreak = 0 }
        for i in points.indices {
            if i > 0, points[i].time.timeIntervalSince(points[i - 1].time) > runGapSeconds { endRun() }
            if derivedSpeed(points, i) >= FoilConstants.foilSpeedThreshold {
                slowStreak = 0
                current.append(points[i])
            } else {
                slowStreak += 1
                if slowStreak <= slowTolerance, !current.isEmpty {
                    current.append(points[i])   // brief dip mid-run
                } else {
                    endRun()
                }
            }
        }
        if current.count >= 2 { runs.append(current) }
        guard !runs.isEmpty else { return [] }

        // 2. Each event → a [lo, hi] wake window. Departure: foiler chases just
        //    after; arrival: foiler rides the incoming wake just before docking.
        let windows: [(lo: TimeInterval, hi: TimeInterval, route: String)] = events.map { e in
            let t = e.time.timeIntervalSince1970
            return e.isArrival
                ? (t - chaseLead - rideWindow, t - chaseLead, e.routeNumber)
                : (t + chaseLead, t + chaseLead + rideWindow, e.routeNumber)
        }

        // 3. For each window, pick the run whose start falls soonest within it.
        var chosen: [Int: String] = [:]   // run index → route (first event wins)
        for w in windows {
            var best: Int?
            var bestDelta = Double.greatestFiniteMagnitude
            for (idx, run) in runs.enumerated() {
                let st = run[0].time.timeIntervalSince1970
                if st >= w.lo, st <= w.hi, st - w.lo < bestDelta {
                    bestDelta = st - w.lo
                    best = idx
                }
            }
            if let b = best, chosen[b] == nil { chosen[b] = w.route }
        }

        // 4. Emit the chosen whole runs, in track order.
        return chosen.keys.sorted().map { i in
            MatchedRide(routeNumber: chosen[i]!, startAt: runs[i][0].time, points: runs[i])
        }
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
