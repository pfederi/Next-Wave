import Foundation

/// Pure decision logic for which belled wave a Live Activity should track.
/// No ActivityKit dependency, so it is fully unit-testable.
enum LiveActivitySelector {
    /// The soonest wave strictly in the future and within `window` of `now`,
    /// or nil if none qualify.
    static func soonestInWindow(_ waves: [WaveEvent], now: Date, window: TimeInterval) -> WaveEvent? {
        let upperBound = now.addingTimeInterval(window)
        return waves
            .filter { $0.time > now && $0.time <= upperBound }
            .min(by: { $0.time < $1.time })
    }
}
