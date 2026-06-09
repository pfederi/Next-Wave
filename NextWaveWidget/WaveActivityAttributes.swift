import Foundation
import ActivityKit

struct WaveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {}

    let stationName: String
    let destinationName: String
    let waveTime: Date
    let shipName: String?
    let waveIconName: String?
    let deepLinkURL: URL
}
