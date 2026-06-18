import Foundation
import Supabase

actor VerifiedRidesAPI {
    static let shared = VerifiedRidesAPI()
    private init() {}

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private struct SessionRow: Encodable {
        let user_id: String, session_key: String, source: String
        let start_at: String, end_at: String
        let total_distance: Double, duration: Int, moving_time: Int
        let max_speed: Double, longest_ride: Double
    }

    func sessionExists(key: String) async throws -> Bool {
        let userId = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        struct Row: Decodable { let session_key: String }
        let rows: [Row] = try await client.from("verified_sessions")
            .select("session_key")
            .eq("user_id", value: userId.uuidString.lowercased())
            .eq("session_key", value: key)
            .limit(1)
            .execute().value
        return !rows.isEmpty
    }

    func upload(metrics: SessionMetrics, sessionKey: String) async throws {
        let userId = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        let row = SessionRow(
            user_id: userId.uuidString.lowercased(), session_key: sessionKey, source: "foilmotion",
            start_at: Self.iso.string(from: metrics.start), end_at: Self.iso.string(from: metrics.end),
            total_distance: metrics.totalDistance, duration: Int(metrics.duration),
            moving_time: Int(metrics.movingTime), max_speed: metrics.maxSpeed,
            longest_ride: metrics.longestRideDistance)
        try await client.from("verified_sessions").upsert(row, onConflict: "user_id,session_key").execute()
    }

    func verifiedStats() async throws -> VerifiedStats {
        _ = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        let rows: [VerifiedStats] = try await client.rpc("user_verified_stats").execute().value
        return rows.first ?? .empty
    }
}
