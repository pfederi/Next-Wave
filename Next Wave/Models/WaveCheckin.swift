import Foundation

struct WaveCheckin: Identifiable, Equatable {
    let id: UUID
    let waveId: String
    let userId: UUID
    let displayName: String?      // nil == anonymous
    let departureAt: Date

    /// Fixed UTC ISO-8601 formatter so all devices agree on the string.
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Deterministic, cross-device wave identity.
    static func makeWaveId(stationUicRef: String?,
                           stationName: String,
                           departure: Date,
                           routeNumber: String) -> String {
        let station = stationUicRef ?? stationName
        let iso = isoFormatter.string(from: departure)
        return "\(station)_\(iso)_\(routeNumber)"
    }

    /// Calendar fixed to Europe/Zurich so "the day" matches the lake's local day.
    private static let zurichCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()

    private static func sameDayDepartures(as time: Date, in times: [Date]) -> [Date] {
        times.filter { zurichCalendar.isDate($0, inSameDayAs: time) }
    }

    /// True if `time` is the earliest departure on its local calendar day among `times`.
    static func isFirstOfDay(_ time: Date, amongDepartures times: [Date]) -> Bool {
        guard let earliest = sameDayDepartures(as: time, in: times).min() else { return false }
        return time == earliest
    }

    /// True if `time` is the latest departure on its local calendar day among `times`.
    static func isLastOfDay(_ time: Date, amongDepartures times: [Date]) -> Bool {
        guard let latest = sameDayDepartures(as: time, in: times).max() else { return false }
        return time == latest
    }
}
