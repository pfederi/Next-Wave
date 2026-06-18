import Testing
import Foundation
@testable import Next_Wave

struct WaveMatcherTests {
    // A boat travelling due north along lon 8.55 from lat 47.30 to 47.32,
    // from t=1000 to t=1200 (≈2.2 km in 200 s ≈ 11 m/s).
    private func boat() -> FerryTrajectory {
        FerryTrajectory(routeNumber: "10", waypoints: [
            FerryWaypoint(lat: 47.30, lon: 8.55, t: 1000),
            FerryWaypoint(lat: 47.32, lon: 8.55, t: 1200),
        ])
    }
    private func pt(_ t: TimeInterval, _ lat: Double, _ lon: Double) -> GPXPoint {
        GPXPoint(time: Date(timeIntervalSince1970: t), lat: lat, lon: lon, ele: nil,
                 speed: nil, cumulativeDistance: nil)   // speed nil → derived from coords
    }

    @Test func interpolatesPositionAlongTrajectory() {
        let pos = boat().position(at: 1100)   // halfway in time → halfway in space
        #expect(pos != nil)
        #expect(abs(pos!.lat - 47.31) < 1e-6)
        #expect(abs(pos!.lon - 8.55) < 1e-6)
    }

    @Test func positionNilOutsideTimeSpan() {
        #expect(boat().position(at: 900) == nil)
        #expect(boat().position(at: 1300) == nil)
    }

    @Test func matchesTrackFollowingMovingBoat() {
        // Track points shadow the boat ~50 m east, moving north, at the same times.
        let pts = (0...4).map { i -> GPXPoint in
            let t = 1000.0 + Double(i) * 25       // 1000…1100
            let lat = 47.30 + 0.0025 * Double(i)  // climbs with the boat (0.0001°/s)
            return pt(t, lat, 8.5506)             // ~45 m east of lon 8.55
        }
        let rides = WaveMatcher.matchedRides(points: pts, trajectories: [boat()])
        #expect(rides.count == 1)
        #expect(rides[0].points.count == 5)
        #expect(rides[0].routeNumber == "10")
    }

    @Test func excludesTrackFarFromBoat() {
        // Same motion/time but ~800 m east of the boat → outside wakeRadius.
        let pts = (0...4).map { i -> GPXPoint in
            let t = 1000.0 + Double(i) * 25
            let lat = 47.30 + 0.0025 * Double(i)
            return pt(t, lat, 8.5606)   // ~800 m east of the boat
        }
        #expect(WaveMatcher.matchedRides(points: pts, trajectories: [boat()]).isEmpty)
    }

    @Test func excludesTrackNearBoatPositionButWrongTime() {
        // Moving along the boat's path, but 1 h later → boat already gone (out of span).
        let pts = (0...4).map { i in pt(4600.0 + Double(i) * 25, 47.31 + 0.0025 * Double(i), 8.55) }
        #expect(WaveMatcher.matchedRides(points: pts, trajectories: [boat()]).isEmpty)
    }

    @Test func excludesStationaryFoiler() {
        // Close to the boat at the right time, but not moving (no position change).
        let pts = (0...4).map { i in pt(1000.0 + Double(i) * 25, 47.30, 8.55) }
        #expect(WaveMatcher.matchedRides(points: pts, trajectories: [boat()]).isEmpty)
    }

    @Test func derivedSpeedFromCoordinates() {
        // Two points 100 m apart, 10 s → 10 m/s, regardless of recorded speed.
        let a = pt(0, 47.30, 8.55)
        let b = pt(10, 47.300899, 8.55)   // ~100 m north
        let s = WaveMatcher.derivedSpeed([a, b], 1)
        #expect(abs(s - 10) < 1.5)
    }
}
