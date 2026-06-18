import Foundation

/// One ferry wave event (departure or arrival) to test the track against,
/// built from the schedule.
struct CandidateDeparture: Equatable {
    let stationId: String
    let stationName: String
    let stationUicRef: String?
    let stationLat: Double
    let stationLon: Double
    /// The scheduled event time — the departure time, or the arrival time when `isArrival`.
    let departure: Date
    let routeNumber: String
    /// true → this is an arriving ferry (wake builds while approaching, dies after docking).
    let isArrival: Bool = false
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
    static let windowBefore = 120.0  // seconds (short side of the wake window)
    static let windowAfter = 360.0   // seconds (long side of the wake window)

    /// The wake window for an event, relative to its scheduled time.
    /// Departure: wake builds just before leaving, biggest shortly after → [-before, +after].
    /// Arrival: wake builds while the ferry approaches, dies after docking → [-after, +before] (mirrored).
    static func window(for candidate: CandidateDeparture) -> (lo: TimeInterval, hi: TimeInterval) {
        let t = candidate.departure.timeIntervalSince1970
        return candidate.isArrival
            ? (t - windowAfter, t + windowBefore)
            : (t - windowBefore, t + windowAfter)
    }

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
                let (lo, hi) = window(for: d)
                return run.contains { p in
                    let pt = p.time.timeIntervalSince1970
                    return pt >= lo && pt <= hi
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
