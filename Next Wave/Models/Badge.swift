import Foundation

enum BadgeCategory: String {
    case milestone, stations, lakes, loyalty, firstShip, lastShip
    case timeOfDay, weekend, seasons, sameDay, anniversary, social, streak
}

struct Badge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let category: BadgeCategory
    let target: Int
    /// Current progress value for this badge from the user's stats.
    let metric: (WaveStats) -> Int

    func current(_ stats: WaveStats) -> Int { metric(stats) }
    func isEarned(_ stats: WaveStats) -> Bool { metric(stats) >= target }
}

struct EvaluatedBadge: Identifiable {
    let badge: Badge
    let current: Int
    var id: String { badge.id }
    var isEarned: Bool { current >= badge.target }
    var progressText: String { isEarned ? "Done" : "\(current)/\(badge.target)" }
}

enum BadgeCatalog {
    /// Total number of Swiss lakes in the app's data — target for the "all lakes" Swiss Explorer badge.
    /// NOTE: keep in sync with the lakes shipped in the app data (see `LakeStationsViewModel.lakes`).
    static let totalLakeCount = 15

    static let all: [Badge] = {
        func milestone(_ n: Int) -> Badge {
            Badge(id: n == 1 ? "first_wave" : "milestone_\(n)",
                  title: n == 1 ? "First Wave" : "\(n) Waves",
                  detail: n == 1 ? "Your first wave" : "Ride \(n) waves",
                  systemImage: "water.waves", category: .milestone, target: n) { $0.totalWaves }
        }
        func seasonBadge(_ key: String, _ title: String, _ icon: String) -> Badge {
            Badge(id: "season_\(key)", title: title, detail: "Ride in \(title.lowercased())",
                  systemImage: icon, category: .seasons, target: 1) { $0.seasonsRidden.contains(key) ? 1 : 0 }
        }
        return [
            // Milestones
            milestone(1), milestone(10), milestone(25), milestone(50), milestone(100),
            // Distinct stations
            Badge(id: "stations_3", title: "Explorer", detail: "3 stations",
                  systemImage: "mappin.and.ellipse", category: .stations, target: 3) { $0.distinctStations },
            Badge(id: "stations_5", title: "Wanderer", detail: "5 stations",
                  systemImage: "mappin.and.ellipse", category: .stations, target: 5) { $0.distinctStations },
            Badge(id: "stations_10", title: "Nomad", detail: "10 stations",
                  systemImage: "mappin.and.ellipse", category: .stations, target: 10) { $0.distinctStations },
            // Swiss Explorer (distinct lakes)
            Badge(id: "lakes_2", title: "Two Lakes", detail: "2 lakes",
                  systemImage: "map", category: .lakes, target: 2) { $0.distinctLakes },
            Badge(id: "lakes_3", title: "Swiss Explorer", detail: "3 lakes",
                  systemImage: "map", category: .lakes, target: 3) { $0.distinctLakes },
            Badge(id: "lakes_all", title: "Swiss Champion", detail: "All lakes",
                  systemImage: "map.fill", category: .lakes, target: totalLakeCount) { $0.distinctLakes },
            // Loyalty (max waves at one station)
            Badge(id: "regular_10", title: "Regular", detail: "10 at one station",
                  systemImage: "house", category: .loyalty, target: 10) { $0.maxWavesOneStation },
            Badge(id: "regular_25", title: "Local Legend", detail: "25 at one station",
                  systemImage: "house.fill", category: .loyalty, target: 25) { $0.maxWavesOneStation },
            // First / last ship of the day
            Badge(id: "first_ship_1", title: "First Ship", detail: "First ship of day",
                  systemImage: "sunrise", category: .firstShip, target: 1) { $0.firstOfDayCount },
            Badge(id: "first_ship_10", title: "Dawn Patrol", detail: "First ship ×10",
                  systemImage: "sunrise.fill", category: .firstShip, target: 10) { $0.firstOfDayCount },
            Badge(id: "last_ship_1", title: "Last Ship", detail: "Last ship of day",
                  systemImage: "sunset", category: .lastShip, target: 1) { $0.lastOfDayCount },
            Badge(id: "last_ship_10", title: "Closing Time", detail: "Last ship ×10",
                  systemImage: "sunset.fill", category: .lastShip, target: 10) { $0.lastOfDayCount },
            // Time of day
            Badge(id: "early_bird", title: "Early Bird", detail: "Before 08:00",
                  systemImage: "alarm", category: .timeOfDay, target: 1) { $0.earlyBirdCount },
            Badge(id: "lunch_ship", title: "Lunch Ship", detail: "11:30–13:30",
                  systemImage: "fork.knife", category: .timeOfDay, target: 1) { $0.lunchCount },
            Badge(id: "night_owl", title: "Night Owl", detail: "After 19:00",
                  systemImage: "moon.stars", category: .timeOfDay, target: 1) { $0.nightOwlCount },
            // Weekend
            Badge(id: "weekend_warrior", title: "Weekend Warrior", detail: "10 on weekends",
                  systemImage: "calendar", category: .weekend, target: 10) { $0.weekendCount },
            // Seasons
            seasonBadge("spring", "Spring", "leaf"),
            seasonBadge("summer", "Summer", "sun.max"),
            seasonBadge("autumn", "Autumn", "wind"),
            seasonBadge("winter", "Winter", "snowflake"),
            Badge(id: "four_seasons", title: "Four Seasons", detail: "All four seasons",
                  systemImage: "circle.hexagongrid.fill", category: .seasons, target: 4) { $0.seasonsRidden.count },
            // Same day
            Badge(id: "double", title: "Double", detail: "2 in one day",
                  systemImage: "2.circle", category: .sameDay, target: 2) { $0.maxWavesOneDay },
            Badge(id: "triple", title: "Triple", detail: "3 in one day",
                  systemImage: "3.circle", category: .sameDay, target: 3) { $0.maxWavesOneDay },
            // Anniversary
            Badge(id: "one_year", title: "One Year", detail: "A year after first",
                  systemImage: "birthday.cake", category: .anniversary, target: 1) { $0.hasAnniversary ? 1 : 0 },
            // Social
            Badge(id: "lone_wolf", title: "Lone Wolf", detail: "Ride solo",
                  systemImage: "person", category: .social, target: 1) { $0.soloCount },
            Badge(id: "crowd_surfer", title: "Crowd Surfer", detail: "5+ riders",
                  systemImage: "person.3.fill", category: .social, target: 5) { $0.maxPeerCount },
            Badge(id: "trendsetter", title: "Trendsetter", detail: "First, 3+ joined",
                  systemImage: "flame", category: .social, target: 1) { $0.trendsetterCount },
            // Streak
            Badge(id: "streak_3", title: "On a Roll", detail: "3 weeks streak",
                  systemImage: "flame", category: .streak, target: 3) { $0.longestStreakWeeks },
            Badge(id: "streak_6", title: "Unstoppable", detail: "6 weeks streak",
                  systemImage: "flame.fill", category: .streak, target: 6) { $0.longestStreakWeeks },
        ]
    }()
}

enum BadgeEvaluator {
    static func evaluate(_ stats: WaveStats) -> [EvaluatedBadge] {
        BadgeCatalog.all.map { EvaluatedBadge(badge: $0, current: $0.current(stats)) }
    }

    /// Badges earned now whose ids are not in `seenIds`, in catalog order.
    static func newlyEarned(_ stats: WaveStats, seenIds: Set<String>) -> [Badge] {
        BadgeCatalog.all.filter { $0.isEarned(stats) && !seenIds.contains($0.id) }
    }
}
