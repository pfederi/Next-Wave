import Foundation
import Supabase

struct WaveCheckinCount: Decodable, Equatable {
    let waveId: String
    let count: Int
    let names: [String]

    enum CodingKeys: String, CodingKey {
        case waveId = "wave_id"
        case count
        case names
    }
}

actor CheckinAPI {
    static let shared = CheckinAPI()
    private init() {}

    private struct CheckinRow: Encodable {
        let wave_id: String
        let user_id: String
        let display_name: String?
        let departure_at: String
        let station_id: String
        let lake_id: String
        let is_first_of_day: Bool
        let is_last_of_day: Bool
    }

    private struct ProfileRow: Encodable {
        let user_id: String
        let display_name: String
    }

    private struct ProfileUpsert: Encodable {
        let user_id: String
        let display_name: String?   // nil → stored as null (anonymous: hidden from public leaderboard)
    }

    /// Sync the leaderboard display name immediately when the identity changes in Settings.
    /// Pass the resolved display name (nil when anonymous or blank) to set it — or clear it.
    func syncProfileName(_ displayName: String?) async {
        guard let userId = try? await SupabaseManager.shared.ensureSession() else { return }
        let client = SupabaseManager.shared.client
        _ = try? await client
            .from("user_profiles")
            .upsert(ProfileUpsert(user_id: userId.uuidString.lowercased(), display_name: displayName),
                    onConflict: "user_id")
            .execute()
    }

    private struct CountParams: Encodable {
        let wave_ids: [String]
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Check in (upsert so re-tapping with a new name updates the row).
    func checkIn(waveId: String,
                 displayName: String?,
                 departureAt: Date,
                 context: CheckinContext) async throws {
        let userId = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        let uid = userId.uuidString.lowercased()
        let row = CheckinRow(
            wave_id: waveId,
            user_id: uid,
            display_name: displayName,
            departure_at: Self.iso.string(from: departureAt),
            station_id: context.stationId,
            lake_id: context.lakeId,
            is_first_of_day: context.isFirstOfDay,
            is_last_of_day: context.isLastOfDay
        )
        try await client
            .from("wave_checkins")
            .upsert(row, onConflict: "wave_id,user_id")
            .execute()

        // Persist the latest non-anonymous name for the leaderboard.
        if let name = displayName {
            _ = try? await client
                .from("user_profiles")
                .upsert(ProfileRow(user_id: uid, display_name: name), onConflict: "user_id")
                .execute()
        }
    }

    /// Remove my check-in from a wave.
    func checkOut(waveId: String) async throws {
        let userId = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        try await client
            .from("wave_checkins")
            .delete()
            .eq("wave_id", value: waveId)
            .eq("user_id", value: userId.uuidString.lowercased())
            .execute()
    }

    /// Batched counts for the currently visible waves.
    func counts(for waveIds: [String]) async throws -> [WaveCheckinCount] {
        guard !waveIds.isEmpty else { return [] }
        let client = SupabaseManager.shared.client
        let response: [WaveCheckinCount] = try await client
            .rpc("wave_checkin_counts", params: CountParams(wave_ids: waveIds))
            .execute()
            .value
        return response
    }

    /// Wave ids the current user is checked into (to render "I'm in" state).
    func myCheckins(waveIds: [String]) async throws -> Set<String> {
        guard !waveIds.isEmpty else { return [] }
        let userId = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        struct Row: Decodable { let wave_id: String }
        let rows: [Row] = try await client
            .from("wave_checkins")
            .select("wave_id")
            .eq("user_id", value: userId.uuidString.lowercased())
            .in("wave_id", values: waveIds)
            .execute()
            .value
        return Set(rows.map(\.wave_id))
    }
}
