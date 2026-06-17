import Testing
import Foundation
@testable import Next_Wave

struct WaveDayContextTests {

    /// Builds a date at a Europe/Zurich wall-clock time.
    private func zurich(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        c.timeZone = TimeZone(identifier: "Europe/Zurich")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    @Test func earliestDepartureIsFirstOfDay() {
        let day = [zurich(2026,6,18,7,0), zurich(2026,6,18,12,0), zurich(2026,6,18,20,0)]
        #expect(WaveCheckin.isFirstOfDay(day[0], amongDepartures: day) == true)
        #expect(WaveCheckin.isFirstOfDay(day[1], amongDepartures: day) == false)
    }

    @Test func latestDepartureIsLastOfDay() {
        let day = [zurich(2026,6,18,7,0), zurich(2026,6,18,12,0), zurich(2026,6,18,20,0)]
        #expect(WaveCheckin.isLastOfDay(day[2], amongDepartures: day) == true)
        #expect(WaveCheckin.isLastOfDay(day[1], amongDepartures: day) == false)
    }

    @Test func onlyConsidersSameLocalDay() {
        // A late wave today + an early wave tomorrow must not make today's late wave "last" vs tomorrow.
        let today = zurich(2026,6,18,20,0)
        let tomorrow = zurich(2026,6,19,7,0)
        #expect(WaveCheckin.isLastOfDay(today, amongDepartures: [today, tomorrow]) == true)
        #expect(WaveCheckin.isFirstOfDay(tomorrow, amongDepartures: [today, tomorrow]) == true)
    }

    @Test func singleDepartureIsBothFirstAndLast() {
        let only = [zurich(2026,6,18,9,0)]
        #expect(WaveCheckin.isFirstOfDay(only[0], amongDepartures: only) == true)
        #expect(WaveCheckin.isLastOfDay(only[0], amongDepartures: only) == true)
    }
}
