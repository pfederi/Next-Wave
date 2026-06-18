import Foundation
import SwiftUI

@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var stats: WaveStats?
    @Published private(set) var badges: [EvaluatedBadge] = BadgeEvaluator.evaluate(.empty)
    @Published private(set) var leaderboard: [LeaderboardEntry] = []
    @Published private(set) var newlyEarned: [Badge] = []
    @Published private(set) var stationCounts: [StationWaveCount] = []
    @Published private(set) var loadFailed = false
    @Published private(set) var verifiedStats: VerifiedStats = .empty
    @Published private(set) var verifiedBadges: [EvaluatedVerifiedBadge] = VerifiedBadgeEvaluator.evaluate(.empty)

    /// Load global stats + global leaderboard. `seenIds` drives the newly-earned diff;
    /// `onSeen` is called with the full earned set so the caller can persist it.
    func refresh(seenIds: Set<String>, onSeen: (Set<String>) -> Void) async {
        loadFailed = false
        do {
            let fetched = try await StatsAPI.shared.stats()
            stats = fetched
            let evaluated = BadgeEvaluator.evaluate(fetched)
            badges = evaluated
            newlyEarned = BadgeEvaluator.newlyEarned(fetched, seenIds: seenIds)
            let earnedNow = Set(evaluated.filter { $0.isEarned }.map { $0.badge.id })
            onSeen(seenIds.union(earnedNow))
            leaderboard = try await StatsAPI.shared.leaderboard(stationId: nil)
        } catch {
            print("⚠️ Stats refresh failed: \(error)")
            loadFailed = true
        }

        // Load independently so a failure here doesn't affect badges/leaderboard.
        do {
            stationCounts = try await StatsAPI.shared.stationCounts()
        } catch {
            print("⚠️ Station counts failed: \(error)")
        }

        do {
            let vs = try await VerifiedRidesAPI.shared.verifiedStats()
            verifiedStats = vs
            verifiedBadges = VerifiedBadgeEvaluator.evaluate(vs)
        } catch {
            print("⚠️ Verified stats failed: \(error)")
        }
    }

    /// Load a leaderboard scoped to one station (used by the station-detail view).
    func loadLeaderboard(stationId: String?) async {
        loadFailed = false
        do {
            leaderboard = try await StatsAPI.shared.leaderboard(stationId: stationId)
        } catch {
            print("⚠️ Leaderboard load failed: \(error)")
            loadFailed = true
        }
    }
}
