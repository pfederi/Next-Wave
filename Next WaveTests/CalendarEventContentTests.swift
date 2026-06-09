import Testing
import Foundation
@testable import Next_Wave

struct CalendarEventContentTests {

    private func fixedDate() -> Date {
        // 2026-06-09 14:32:00 UTC
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 9; c.hour = 14; c.minute = 32
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    @Test func titleIncludesStationAndDestination() {
        let content = CalendarEventContent.make(
            waveTime: fixedDate(), stationName: "Thalwil", destinationName: "Zürich",
            latitude: nil, longitude: nil, shipName: nil,
            airTemperature: nil, waterTemperature: nil,
            windKnots: nil, windDirection: nil, wetsuitThickness: nil
        )
        #expect(content.title == "🌊 Wave – Thalwil → Zürich")
    }

    @Test func titleFallsBackWhenStationMissing() {
        let content = CalendarEventContent.make(
            waveTime: fixedDate(), stationName: nil, destinationName: "Zürich",
            latitude: nil, longitude: nil, shipName: nil,
            airTemperature: nil, waterTemperature: nil,
            windKnots: nil, windDirection: nil, wetsuitThickness: nil
        )
        #expect(content.title == "🌊 Wave → Zürich")
    }

    @Test func eventLastsOneHour() {
        let start = fixedDate()
        let content = CalendarEventContent.make(
            waveTime: start, stationName: "Thalwil", destinationName: "Zürich",
            latitude: nil, longitude: nil, shipName: nil,
            airTemperature: nil, waterTemperature: nil,
            windKnots: nil, windDirection: nil, wetsuitThickness: nil
        )
        #expect(content.startDate == start)
        #expect(content.endDate == start.addingTimeInterval(3600))
    }

    @Test func coordinatesPassThroughWhenPresent() {
        let content = CalendarEventContent.make(
            waveTime: fixedDate(), stationName: "Thalwil", destinationName: "Zürich",
            latitude: 47.29, longitude: 8.56, shipName: nil,
            airTemperature: nil, waterTemperature: nil,
            windKnots: nil, windDirection: nil, wetsuitThickness: nil
        )
        #expect(content.latitude == 47.29)
        #expect(content.longitude == 8.56)
        #expect(content.locationName == "Thalwil")
    }

    @Test func notesOmitUnavailableLines() {
        let content = CalendarEventContent.make(
            waveTime: fixedDate(), stationName: "Thalwil", destinationName: "Zürich",
            latitude: nil, longitude: nil, shipName: nil,
            airTemperature: nil, waterTemperature: nil,
            windKnots: nil, windDirection: nil, wetsuitThickness: nil
        )
        #expect(!content.notes.contains("⛴️"))
        #expect(!content.notes.contains("🌡️"))
        #expect(content.notes.contains("Next Wave"))
        #expect(content.notes.contains("nextwave://"))
    }

    @Test func notesIncludeAllAvailableData() {
        let content = CalendarEventContent.make(
            waveTime: fixedDate(), stationName: "Thalwil", destinationName: "Zürich",
            latitude: nil, longitude: nil, shipName: "MS Panta Rhei",
            airTemperature: 21.4, waterTemperature: 18.2,
            windKnots: 12, windDirection: "NW", wetsuitThickness: "3/2"
        )
        #expect(content.notes.contains("⛴️ MS Panta Rhei"))
        #expect(content.notes.contains("21.4"))
        #expect(content.notes.contains("18.2"))
        #expect(content.notes.contains("12 kn"))
        #expect(content.notes.contains("NW"))
        #expect(content.notes.contains("3/2"))
    }
}
