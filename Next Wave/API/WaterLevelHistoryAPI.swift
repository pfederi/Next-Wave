import Foundation
import Supabase

actor WaterLevelHistoryAPI {
    static let shared = WaterLevelHistoryAPI()
    private init() {}

    struct WaterLevelPoint: Decodable, Equatable {
        let date: Date
        let levelM: Double

        enum CodingKeys: String, CodingKey {
            case date
            case levelM = "level_m"
        }

        init(date: Date, levelM: Double) {
            self.date = date
            self.levelM = levelM
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let dateString = try container.decode(String.self, forKey: .date)
            guard let parsedDate = WaterLevelHistoryAPI.dateOnlyFormatter.date(from: dateString) else {
                throw DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "Invalid date: \(dateString)")
            }
            self.date = parsedDate
            self.levelM = try container.decode(Double.self, forKey: .levelM)
        }
    }

    private struct LevelRow: Encodable {
        let lake_name: String
        let date: String
        let level_m: Double
    }

    // A Postgres `date` column round-trips as a bare "yyyy-MM-dd" string over
    // PostgREST, not a full timestamp — decode/encode it ourselves rather
    // than relying on the Supabase client's default (timestamp-shaped) date
    // decoding strategy.
    //
    // Uses the device's timezone on purpose: the `date` column carries no
    // timezone component, so the only question is which calendar day a given
    // moment maps to, and that has to be the day the user considers "today".
    // This is the single source of truth for that mapping — callers deciding
    // whether today's level was already recorded must use this same formatter,
    // otherwise the guard and the written row can disagree around midnight.
    static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func recordLevel(lake: String, levelMeters: Double, date: Date = Date()) async throws {
        _ = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        let row = LevelRow(lake_name: lake, date: Self.dateOnlyFormatter.string(from: date), level_m: levelMeters)
        try await client.from("lake_water_levels")
            .upsert(row, onConflict: "lake_name,date")
            .execute()
    }

    func getHistory(lake: String, days: Int = 40) async throws -> [WaterLevelPoint] {
        _ = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        // Inclusive `.gte` filter: today counts as one of the `days`, so step
        // back `days - 1` to end up with exactly `days` distinct calendar dates.
        let since = Calendar(identifier: .gregorian).date(byAdding: .day, value: -(days - 1), to: Date()) ?? Date()
        let rows: [WaterLevelPoint] = try await client.from("lake_water_levels")
            .select("date,level_m")
            .eq("lake_name", value: lake)
            .gte("date", value: Self.dateOnlyFormatter.string(from: since))
            .order("date", ascending: true)
            .execute()
            .value
        return rows
    }
}
