import Testing
import Foundation
@testable import Next_Wave

struct LiveActivitySelectorTests {

    private func wave(minutesFromNow: Double, now: Date, route: String = "1") -> WaveEvent {
        WaveEvent(
            time: now.addingTimeInterval(minutesFromNow * 60),
            isArrival: false,
            routeNumber: route,
            routeName: "Route \(route)",
            neighborStop: "X",
            neighborStopName: "Zürich",
            period: "p",
            lake: "Zürichsee"
        )
    }

    private let window: TimeInterval = 8 * 3600

    @Test func returnsNilWhenAllWavesInPast() {
        let now = Date()
        let waves = [wave(minutesFromNow: -10, now: now), wave(minutesFromNow: -120, now: now)]
        #expect(LiveActivitySelector.soonestInWindow(waves, now: now, window: window) == nil)
    }

    @Test func returnsNilWhenSoonestBeyondWindow() {
        let now = Date()
        let waves = [wave(minutesFromNow: 9 * 60, now: now)] // 9h out, window is 8h
        #expect(LiveActivitySelector.soonestInWindow(waves, now: now, window: window) == nil)
    }

    @Test func returnsSoonestFutureWaveInWindow() {
        let now = Date()
        let soon = wave(minutesFromNow: 30, now: now, route: "soon")
        let later = wave(minutesFromNow: 90, now: now, route: "later")
        let result = LiveActivitySelector.soonestInWindow([later, soon], now: now, window: window)
        #expect(result?.routeNumber == "soon")
    }

    @Test func ignoresPastWavesWhenFutureQualifies() {
        let now = Date()
        let past = wave(minutesFromNow: -5, now: now, route: "past")
        let future = wave(minutesFromNow: 45, now: now, route: "future")
        let result = LiveActivitySelector.soonestInWindow([past, future], now: now, window: window)
        #expect(result?.routeNumber == "future")
    }
}
