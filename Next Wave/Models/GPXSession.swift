import Foundation

struct GPXPoint: Equatable {
    let time: Date
    let lat: Double
    let lon: Double
    let ele: Double?
    let speed: Double?              // m/s (from <speed> if present)
    let cumulativeDistance: Double? // m (from <distance> if present)
}

struct GPXMetadata: Equatable {
    let name: String?
    let desc: String?
    let creator: String?
    let startTime: Date?
}

struct GPXSession: Equatable {
    let metadata: GPXMetadata
    let points: [GPXPoint]
}
