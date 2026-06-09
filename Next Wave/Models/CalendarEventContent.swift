import Foundation

/// Pure, EventKit-free description of a calendar event for a wave.
/// All inputs are pre-resolved by the caller, so this type stays testable
/// and free of weather/lake/date-dependent logic.
struct CalendarEventContent {
    let title: String
    let startDate: Date
    let endDate: Date
    let locationName: String?
    let latitude: Double?
    let longitude: Double?
    let notes: String

    static func make(
        waveTime: Date,
        stationName: String?,
        destinationName: String,
        latitude: Double?,
        longitude: Double?,
        shipName: String?,
        airTemperature: Double?,
        waterTemperature: Double?,
        windKnots: Double?,
        windDirection: String?,
        wetsuitThickness: String?
    ) -> CalendarEventContent {
        let title: String
        if let station = stationName, !station.isEmpty {
            title = "🌊 Wave – \(station) → \(destinationName)"
        } else {
            title = "🌊 Wave → \(destinationName)"
        }

        var lines: [String] = []

        if let ship = shipName, !ship.isEmpty {
            lines.append("⛴️ \(ship)")
        }
        if let air = airTemperature {
            lines.append("🌡️ \(String(format: "%.1f°C", air))")
        }
        if let water = waterTemperature {
            lines.append("💧 \(String(format: "%.1f°C", water))")
        }
        if let knots = windKnots {
            let dir = windDirection.map { " \($0)" } ?? ""
            lines.append("💨 \(Int(knots)) kn\(dir)")
        }
        if let wetsuit = wetsuitThickness {
            lines.append("🤸 Wetsuit: \(wetsuit)mm")
        }
        lines.append("")
        lines.append("📱 Opened with Next Wave")
        lines.append("nextwave://")

        return CalendarEventContent(
            title: title,
            startDate: waveTime,
            endDate: waveTime.addingTimeInterval(3600),
            locationName: stationName,
            latitude: latitude,
            longitude: longitude,
            notes: lines.joined(separator: "\n")
        )
    }
}
