import Testing
import Foundation
@testable import Next_Wave

struct WaveMatcherTests {
    private func dep(_ t: TimeInterval) -> BoatEvent {
        BoatEvent(time: Date(timeIntervalSince1970: t), isArrival: false, routeNumber: "10")
    }
    private func arr(_ t: TimeInterval) -> BoatEvent {
        BoatEvent(time: Date(timeIntervalSince1970: t), isArrival: true, routeNumber: "10")
    }
    // A moving foiler: ~5 m/s north (0.00045° lat / 10 s) starting at the given time.
    private func movingTrack(from t0: TimeInterval, count: Int = 6) -> [GPXPoint] {
        (0..<count).map { i in
            GPXPoint(time: Date(timeIntervalSince1970: t0 + Double(i) * 10),
                     lat: 47.30 + 0.00045 * Double(i), lon: 8.55,
                     ele: nil, speed: nil, cumulativeDistance: nil)
        }
    }

    @Test func matchesMovingTrackInDepartureWindow() {
        // Departure at t=1000 → window [1030, 1210]. Track moves through it.
        let rides = WaveMatcher.matchedRides(points: movingTrack(from: 1040), events: [dep(1000)])
        #expect(rides.count == 1)
        #expect(rides[0].routeNumber == "10")
    }

    @Test func matchesMovingTrackInArrivalWindow() {
        // Arrival at t=2000 → window [1790, 1970]. Track moves through it.
        let rides = WaveMatcher.matchedRides(points: movingTrack(from: 1800), events: [arr(2000)])
        #expect(rides.count == 1)
    }

    @Test func excludesTrackBeforeChaseLead() {
        // Departure at t=1000 → window opens only at 1030. A track entirely in the
        // first 30 s (1000…1050 but ending before 1030 matters) — use 1000…1025.
        let pts = (0...2).map { i in
            GPXPoint(time: Date(timeIntervalSince1970: 1000 + Double(i) * 10),
                     lat: 47.30 + 0.00045 * Double(i), lon: 8.55,
                     ele: nil, speed: nil, cumulativeDistance: nil)
        }
        #expect(WaveMatcher.matchedRides(points: pts, events: [dep(1000)]).isEmpty)
    }

    @Test func excludesTrackOutsideWindow() {
        // Track an hour after the only departure's window.
        let rides = WaveMatcher.matchedRides(points: movingTrack(from: 5000), events: [dep(1000)])
        #expect(rides.isEmpty)
    }

    @Test func excludesStationaryFoilerInWindow() {
        // Inside the window but not moving → no ride.
        let pts = (0...5).map { i in
            GPXPoint(time: Date(timeIntervalSince1970: 1040 + Double(i) * 10),
                     lat: 47.30, lon: 8.55, ele: nil, speed: nil, cumulativeDistance: nil)
        }
        #expect(WaveMatcher.matchedRides(points: pts, events: [dep(1000)]).isEmpty)
    }

    private func p(_ t: TimeInterval, _ lat: Double) -> GPXPoint {
        GPXPoint(time: Date(timeIntervalSince1970: t), lat: lat, lon: 8.55,
                 ele: nil, speed: nil, cumulativeDistance: nil)
    }

    @Test func creditsWholeRunPastWindowEnd() {
        // Run starts at 1040 (inside dep window [1030,1210]) and keeps going far past
        // the window's end — the whole run is credited (foiler rides until it ends).
        let pts = movingTrack(from: 1040, count: 40)   // 1040…1430
        let rides = WaveMatcher.matchedRides(points: pts, events: [dep(1000)])
        #expect(rides.count == 1)
        #expect(rides[0].points.count == 40)
    }

    @Test func toleratesBriefDipMidRun() {
        // One slow point in the middle should not split the ride into two.
        var pts = (0...4).map { p(1040 + Double($0) * 5, 47.300 + 0.0003 * Double($0)) }
        pts.append(p(1065, 47.3012))                       // ~tiny move → a dip
        pts += (0...4).map { p(1070 + Double($0) * 5, 47.3015 + 0.0003 * Double($0)) }
        let rides = WaveMatcher.matchedRides(points: pts, events: [dep(1000)])
        #expect(rides.count == 1)
        #expect(rides[0].points.count == 11)
    }

    @Test func picksOneRunPerDeparture() {
        // Two separate runs both start inside the window; only the earliest counts.
        var pts = [p(1040, 47.300), p(1045, 47.3005), p(1050, 47.3010)]  // run A (start 1040)
        pts.append(p(1075, 47.3010))                                      // long-ish stop (>slowTol via gap)
        pts.append(p(1095, 47.3010))
        pts += [p(1100, 47.320), p(1105, 47.3205), p(1110, 47.3210)]      // run B (start 1100)
        let rides = WaveMatcher.matchedRides(points: pts, events: [dep(1000)])
        #expect(rides.count == 1)
        #expect(rides[0].startAt == Date(timeIntervalSince1970: 1040))
    }

    @Test func noEventsNoRides() {
        #expect(WaveMatcher.matchedRides(points: movingTrack(from: 1040), events: []).isEmpty)
    }

    @Test func derivedSpeedFromCoordinates() {
        // Two points 100 m apart, 10 s → 10 m/s, regardless of recorded speed.
        let a = GPXPoint(time: Date(timeIntervalSince1970: 0), lat: 47.30, lon: 8.55,
                         ele: nil, speed: nil, cumulativeDistance: nil)
        let b = GPXPoint(time: Date(timeIntervalSince1970: 10), lat: 47.300899, lon: 8.55,
                         ele: nil, speed: nil, cumulativeDistance: nil)
        #expect(abs(WaveMatcher.derivedSpeed([a, b], 1) - 10) < 1.5)
    }
}
