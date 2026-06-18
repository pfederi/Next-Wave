import Testing
import Foundation
@testable import Next_Wave

struct WaveMatcherTests {
    private let stationLat = 47.30, stationLon = 8.55

    private func dep(_ t: Date) -> CandidateDeparture {
        CandidateDeparture(stationId: "S_1", stationName: "S", stationUicRef: "1",
                           stationLat: stationLat, stationLon: stationLon, departure: t, routeNumber: "10")
    }
    private func pt(_ t: TimeInterval, _ lat: Double, _ lon: Double, _ speed: Double) -> GPXPoint {
        GPXPoint(time: Date(timeIntervalSince1970: t), lat: lat, lon: lon, ele: nil,
                 speed: speed, cumulativeDistance: nil)
    }

    @Test func matchesMovingRunNearStationInWindow() {
        let T = Date(timeIntervalSince1970: 1000)
        // One moving run; the first point is at the station, 1 min after departure.
        let pts = [pt(1060, 47.30, 8.55, 5), pt(1065, 47.301, 8.55, 5), pt(1070, 47.302, 8.55, 5)]
        let rides = WaveMatcher.matchedRides(points: pts, departures: [dep(T)])
        #expect(rides.count == 1)
        #expect(rides[0].points.count == 3)
        #expect(rides[0].stationId == "S_1")
    }

    @Test func excludesNonMovingRun() {
        let T = Date(timeIntervalSince1970: 1000)
        let pts = [pt(1060, 47.30, 8.55, 1), pt(1065, 47.30, 8.55, 1)]   // at station, in window, too slow
        #expect(WaveMatcher.matchedRides(points: pts, departures: [dep(T)]).isEmpty)
    }

    @Test func excludesRunFarFromStation() {
        let T = Date(timeIntervalSince1970: 1000)
        let pts = [pt(1060, 47.30, 8.556, 5), pt(1065, 47.301, 8.556, 5)]   // ~455 m east, moving, in window
        #expect(WaveMatcher.matchedRides(points: pts, departures: [dep(T)]).isEmpty)
    }

    @Test func excludesRunOutsideWindow() {
        let T = Date(timeIntervalSince1970: 1000)
        let pts = [pt(1500, 47.30, 8.55, 5), pt(1505, 47.30, 8.55, 5)]   // T+500s > +360s
        #expect(WaveMatcher.matchedRides(points: pts, departures: [dep(T)]).isEmpty)
    }
}
