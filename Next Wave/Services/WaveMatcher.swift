import Foundation

/// One ferry departure to test the track against (built from the schedule).
struct CandidateDeparture: Equatable {
    let stationId: String
    let stationName: String
    let stationUicRef: String?
    let stationLat: Double
    let stationLon: Double
    let departure: Date
    let routeNumber: String
}

/// A contiguous "behind a ship" ride: the moving run of track points that was
/// near a station inside a ferry departure's wake window.
struct MatchedRide: Equatable {
    let waveId: String
    let stationId: String
    let departureAt: Date
    let points: [GPXPoint]
}

enum WaveMatcher {
    static let matchRadius = 250.0   // meters
    static let windowBefore = 120.0  // seconds (wake builds just before departure)
    static let windowAfter = 360.0   // seconds (wake arrives shortly after)

    /// Returns the moving runs of the track that qualify as ferry-wave rides:
    /// a contiguous run of points with speed ≥ threshold that contains at least
    /// one point within `matchRadius` of a station inside that departure's window.
    static func matchedRides(points: [GPXPoint], departures: [CandidateDeparture]) -> [MatchedRide] {
        guard !points.isEmpty, !departures.isEmpty else { return [] }

        // 1. Split the track into contiguous moving runs.
        var runs: [[GPXPoint]] = []
        var current: [GPXPoint] = []
        for p in points {
            if (p.speed ?? 0) >= FoilConstants.foilSpeedThreshold {
                current.append(p)
            } else if !current.isEmpty {
                runs.append(current); current = []
            }
        }
        if !current.isEmpty { runs.append(current) }

        // 2. Keep only runs that belong to a ferry departure (near station + in window).
        var rides: [MatchedRide] = []
        for run in runs where run.count >= 2 {
            guard let dep = departures.first(where: { d in
                let t = d.departure.timeIntervalSince1970
                return run.contains { p in
                    let pt = p.time.timeIntervalSince1970
                    return pt >= t - windowBefore && pt <= t + windowAfter
                        && GeoMath.distance(lat1: p.lat, lon1: p.lon,
                                            lat2: d.stationLat, lon2: d.stationLon) <= matchRadius
                }
            }) else { continue }

            let waveId = WaveCheckin.makeWaveId(stationUicRef: dep.stationUicRef,
                                                stationName: dep.stationName,
                                                departure: dep.departure,
                                                routeNumber: dep.routeNumber)
            rides.append(MatchedRide(waveId: waveId, stationId: dep.stationId,
                                     departureAt: dep.departure, points: run))
        }
        return rides
    }
}
