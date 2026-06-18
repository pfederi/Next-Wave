import SwiftUI

struct VerifiedBadge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let imageName: String
    let ringColor: Color
    let target: Int
    let metric: (VerifiedStats) -> Int

    func current(_ s: VerifiedStats) -> Int { metric(s) }
    func isEarned(_ s: VerifiedStats) -> Bool { metric(s) >= target }
}

struct EvaluatedVerifiedBadge: Identifiable {
    let badge: VerifiedBadge
    let current: Int
    var id: String { badge.id }
    var isEarned: Bool { current >= badge.target }
    var progressText: String { isEarned ? "Done" : "\(current)/\(badge.target)" }
}

enum VerifiedBadgeCatalog {
    private static let distColor = Color(verifiedHex: "#1E88E5")
    private static let speedColor = Color(verifiedHex: "#E53935")
    private static let totalColor = Color(verifiedHex: "#43A047")
    private static let sessionColor = Color(verifiedHex: "#00897B")

    static let all: [VerifiedBadge] = {
        func dist(_ m: Int, _ label: String) -> VerifiedBadge {
            VerifiedBadge(id: "dist_\(m)", title: label, detail: "Longest ride \(label)",
                          imageName: "badge_distance", ringColor: distColor, target: m) { Int($0.longestRideM) }
        }
        func speed(_ kmh: Int) -> VerifiedBadge {
            VerifiedBadge(id: "speed_\(kmh)", title: "\(kmh) km/h", detail: "Top speed \(kmh) km/h",
                          imageName: "badge_speed", ringColor: speedColor, target: kmh) { Int($0.maxSpeedMs * 3.6) }
        }
        func total(_ m: Int, _ label: String) -> VerifiedBadge {
            VerifiedBadge(id: "total_\(m)", title: label, detail: "\(label) total distance",
                          imageName: "badge_total", ringColor: totalColor, target: m) { Int($0.totalDistanceM) }
        }
        func session(_ n: Int) -> VerifiedBadge {
            VerifiedBadge(id: "sessions_\(n)", title: n == 1 ? "First Session" : "\(n) Sessions",
                          detail: "\(n) verified session\(n == 1 ? "" : "s")",
                          imageName: "badge_session", ringColor: sessionColor, target: n) { $0.sessionCount }
        }
        return [
            dist(50, "50 m"), dist(100, "100 m"), dist(250, "250 m"), dist(500, "500 m"),
            dist(1000, "1 km"), dist(5000, "5 km"), dist(10000, "10 km"),
            speed(15), speed(20), speed(25), speed(30), speed(35),
            total(5000, "5 km"), total(25000, "25 km"), total(100000, "100 km"),
            total(250000, "250 km"), total(500000, "500 km"),
            session(1), session(10), session(25), session(50), session(100),
        ]
    }()
}

enum VerifiedBadgeEvaluator {
    static func evaluate(_ stats: VerifiedStats) -> [EvaluatedVerifiedBadge] {
        VerifiedBadgeCatalog.all.map { EvaluatedVerifiedBadge(badge: $0, current: $0.current(stats)) }
    }
}

private extension Color {
    init(verifiedHex hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        guard s.count == 6, Scanner(string: s).scanHexInt64(&v) else { self = .gray; return }
        self.init(red: Double((v & 0xFF0000) >> 16) / 255, green: Double((v & 0x00FF00) >> 8) / 255,
                  blue: Double(v & 0x0000FF) / 255)
    }
}
