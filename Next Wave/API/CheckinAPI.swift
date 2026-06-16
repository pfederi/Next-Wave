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
    func checkIn(waveId: String, displayName: String?, departureAt: Date) async throws {
        let userId = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        let row = CheckinRow(
            wave_id: waveId,
            user_id: userId.uuidString.lowercased(),
            display_name: displayName,
            departure_at: Self.iso.string(from: departureAt)
        )
        try await client
            .from("wave_checkins")
            .upsert(row, onConflict: "wave_id,user_id")
            .execute()
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
