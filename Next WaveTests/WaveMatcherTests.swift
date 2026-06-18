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
