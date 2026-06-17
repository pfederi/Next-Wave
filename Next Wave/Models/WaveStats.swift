import Foundation

struct WaveStats: Decodable, Equatable {
    let totalWaves: Int
    let distinctStations: Int
    let distinctLakes: Int
    let maxWavesOneStation: Int
    let firstOfDayCount: Int
    let lastOfDayCount: Int
    let earlyBirdCount: Int
    let lunchCount: Int
    let nightOwlCount: Int
    let weekendCount: Int
    let maxWavesOneDay: Int
    let hasAnniversary: Bool
    let soloCount: Int
    let maxPeerCount: Int
    let trendsetterCount: Int
    let seasonsRidden: [String]
    let currentStreakWeeks: Int
    let longestStreakWeeks: Int

    enum CodingKeys: String, CodingKey {
        case totalWaves = "total_waves"
        case distinctStations = "distinct_stations"
        case distinctLakes = "distinct_lakes"
        case maxWavesOneStation = "max_waves_one_station"
        case firstOfDayCount = "first_of_day_count"
        case lastOfDayCount = "last_of_day_count"
        case earlyBirdCount = "early_bird_count"
        case lunchCount = "lunch_count"
        case nightOwlCount = "night_owl_count"
        case weekendCount = "weekend_count"
        case maxWavesOneDay = "max_waves_one_day"
        case hasAnniversary = "has_anniversary"
        case soloCount = "solo_count"
        case maxPeerCount = "max_peer_count"
        case trendsetterCount = "trendsetter_count"
        case seasonsRidden = "seasons_ridden"
        case currentStreakWeeks = "current_streak_weeks"
        case longestStreakWeeks = "longest_streak_weeks"
    }

    static let empty = WaveStats(
        totalWaves: 0, distinctStations: 0, distinctLakes: 0, maxWavesOneStation: 0,
        firstOfDayCount: 0, lastOfDayCount: 0, earlyBirdCount: 0, lunchCount: 0,
        nightOwlCount: 0, weekendCount: 0, maxWavesOneDay: 0, hasAnniversary: false,
        soloCount: 0, maxPeerCount: 0, trendsetterCount: 0, seasonsRidden: [],
        currentStreakWeeks: 0, longestStreakWeeks: 0)
}

struct LeaderboardEntry: Decodable, Identifiable, Equatable {
    let rank: Int
    let displayName: String
    let totalWaves: Int
    let isMe: Bool

    var id: String { "\(rank)-\(displayName)-\(isMe)" }

    enum CodingKeys: String, CodingKey {
        case rank
        case displayName = "display_name"
        case totalWaves = "total_waves"
        case isMe = "is_me"
    }
}
