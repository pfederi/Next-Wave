import Foundation

/// Pure, testable helper for linear interpolation between sorted forecast steps.
/// Resolves which two steps bracket a target time and the 0...1 fraction between
/// them; clamps to the endpoints outside the range.
struct WeatherInterpolation: Equatable {
    let lowerIndex: Int
    let upperIndex: Int
    let fraction: Double   // 0 = at lower step, 1 = at upper step

    /// Locate the bracketing indices + fraction for `t` among ascending `timestamps`.
    /// Returns nil only for an empty input.
    static func locate(_ t: TimeInterval, in timestamps: [TimeInterval]) -> WeatherInterpolation? {
        guard let first = timestamps.first, let last = timestamps.last else { return nil }
        if t <= first { return WeatherInterpolation(lowerIndex: 0, upperIndex: 0, fraction: 0) }
        if t >= last {
            let i = timestamps.count - 1
            return WeatherInterpolation(lowerIndex: i, upperIndex: i, fraction: 0)
        }
        for i in 1..<timestamps.count where timestamps[i] >= t {
            let span = timestamps[i] - timestamps[i - 1]
            let fraction = span > 0 ? (t - timestamps[i - 1]) / span : 0
            return WeatherInterpolation(lowerIndex: i - 1, upperIndex: i, fraction: fraction)
        }
        let i = timestamps.count - 1
        return WeatherInterpolation(lowerIndex: i, upperIndex: i, fraction: 0)
    }

    /// Linear interpolation between two values at this fraction.
    func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * fraction }

    /// Index of the nearer step (for categorical fields like icon / wind direction).
    var nearestIndex: Int { fraction < 0.5 ? lowerIndex : upperIndex }
}
