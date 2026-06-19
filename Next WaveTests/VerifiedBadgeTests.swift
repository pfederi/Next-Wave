import Testing
import Foundation
@testable import Next_Wave

struct VerifiedBadgeTests {
    private func stats(sessions: Int = 0, total: Double = 0, longest: Double = 0, speedMs: Double = 0) -> VerifiedStats {
        VerifiedStats(sessionCount: sessions, totalDistanceM: total, longestRideM: longest, maxSpeedMs: speedMs)
    }

    @Test func firstSessionUnlocks() {
        #expect(VerifiedBadgeEvaluator.evaluate(stats(sessions: 0)).first { $0.badge.id == "sessions_1" }!.isEarned == false)
        #expect(VerifiedBadgeEvaluator.evaluate(stats(sessions: 1)).first { $0.badge.id == "sessions_1" }!.isEarned == true)
    }

    @Test func longestRide500m() {
        #expect(VerifiedBadgeEvaluator.evaluate(stats(longest: 500)).first { $0.badge.id == "dist_500" }!.isEarned == true)
    }

    @Test func totalDistance25km() {
        #expect(VerifiedBadgeEvaluator.evaluate(stats(total: 25000)).first { $0.badge.id == "total_25000" }!.isEarned == true)
        #expect(VerifiedBadgeEvaluator.evaluate(stats(total: 24999)).first { $0.badge.id == "total_25000" }!.isEarned == false)
    }

    @Test func topSpeedUsesKmh() {
        let e = VerifiedBadgeEvaluator.evaluate(stats(speedMs: 8.4))   // 30.24 km/h
        #expect(e.first { $0.badge.id == "speed_30" }!.isEarned == true)
        #expect(e.first { $0.badge.id == "speed_35" }!.isEarned == false)
    }
}
