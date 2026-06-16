import Testing
import Foundation
@testable import Next_Wave

struct WaveCheckinIdTests {

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    @Test func usesUicRefWhenPresent() {
        let id = WaveCheckin.makeWaveId(
            stationUicRef: "8503671", stationName: "Thalwil",
            departure: date(2026, 6, 18, 14, 32), routeNumber: "ZSG-12")
        #expect(id == "8503671_2026-06-18T14:32:00Z_ZSG-12")
    }

    @Test func fallsBackToNameWhenNoUicRef() {
        let id = WaveCheckin.makeWaveId(
            stationUicRef: nil, stationName: "Thalwil",
            departure: date(2026, 6, 18, 14, 32), routeNumber: "ZSG-12")
        #expect(id == "Thalwil_2026-06-18T14:32:00Z_ZSG-12")
    }

    @Test func isDeterministicAcrossTimeZones() {
        let utc = WaveCheckin.makeWaveId(
            stationUicRef: "8503671", stationName: "Thalwil",
            departure: date(2026, 6, 18, 14, 32), routeNumber: "ZSG-12")
        #expect(utc == "8503671_2026-06-18T14:32:00Z_ZSG-12")
    }
}
