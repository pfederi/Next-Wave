import Testing
import Foundation
@testable import Next_Wave

struct SessionMetricsTests {
    private func pt(_ t: TimeInterval, _ lat: Double, _ lon: Double, _ speed: Double) -> GPXPoint {
        GPXPoint(time: Date(timeIntervalSince1970: t), lat: lat, lon: lon, ele: nil,
                 speed: speed, cumulativeDistance: nil)
    }

    @Test func haversineKnownDistance() {
        let d = GeoMath.distance(lat1: 47.0, lon1: 8.0, lat2: 47.001, lon2: 8.0)
        #expect(abs(d - 111.2) < 2.0)   // ~111 m per 0.001° latitude
    }

    @Test func longestRideResetsOnSlowPoint() {
        let pts = [
            pt(0, 47.000, 8.0, 5.0),
            pt(1, 47.001, 8.0, 5.0),
            pt(2, 47.002, 8.0, 1.0),   // below threshold → breaks the ride
            pt(3, 47.003, 8.0, 5.0),
        ]
        let m = SessionMetrics.compute(from: pts)!
        #expect(m.maxSpeed == 5.0)
        #expect(m.longestRideDistance > 100 && m.longestRideDistance < 130)  // one ~111 m segment
        #expect(m.totalDistance > 320 && m.totalDistance < 340)              // three ~111 m segments
    }

    @Test func tooFewPointsReturnsNil() {
        #expect(SessionMetrics.compute(from: [pt(0, 47, 8, 5)]) == nil)
    }
}
