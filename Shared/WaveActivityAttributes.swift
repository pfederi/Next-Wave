import Foundation
import ActivityKit

/// Static data for the "next wave" Live Activity. Shared (same type) between the
/// app and the widget extension. The countdown is rendered with Text(timerInterval:)
/// from `waveTime`, so no dynamic ContentState is needed.
struct WaveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {}

    let stationName: String
    let destinationName: String
    let waveTime: Date
    let shipName: String?
    /// Deep link opened when the activity is tapped, e.g.
    /// nextwave://station?name=Thalwil&date=2026-06-09
    let deepLinkURL: URL
}
