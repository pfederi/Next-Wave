import Foundation
import Supabase

actor StatsAPI {
    static let shared = StatsAPI()
    private init() {}

    private struct LeaderboardParams: Encodable {
        let p_station_id: String?
        let p_limit: Int
    }

    /// The caller's raw gamification metrics. `user_wave_stats()` returns a single row.
    func stats() async throws -> WaveStats {
        _ = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        let rows: [WaveStats] = try await client
            .rpc("user_wave_stats")
            .execute()
            .value
        return rows.first ?? .empty
    }

    /// Global (stationId == nil) or per-station leaderboard, top `limit` named users + own row.
    func leaderboard(stationId: String?, limit: Int = 50) async throws -> [LeaderboardEntry] {
        _ = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        let rows: [LeaderboardEntry] = try await client
            .rpc("wave_leaderboard", params: LeaderboardParams(p_station_id: stationId, p_limit: limit))
            .execute()
            .value
        return rows
    }
}
