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
}
