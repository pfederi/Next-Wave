import Foundation
import UserNotifications

/// Detects newly-earned badges and sends a local notification that deep-links
/// to "My Badges". Implemented as an actor so the read-modify-write of the
/// "notified" state is serialized across the foreground and background callers.
/// State is kept in UserDefaults so it survives relaunches (independently of the
/// in-app celebration, which uses `seenBadgeIds`).
actor BadgeNotifier {
    static let shared = BadgeNotifier()
    private init() {}

    private let notifiedKey = "notifiedBadgeIds"
    private let initKey = "badgeNotifierInitialized"

    /// Fetch stats, compare earned badges against the last-notified set, and
    /// notify about any newly earned ones. On first run it only establishes a
    /// baseline (no retroactive notification for already-earned badges).
    func checkAndNotify() async {
        guard let stats = try? await StatsAPI.shared.stats() else { return }
        let earnedIds = Set(BadgeEvaluator.evaluate(stats).filter { $0.isEarned }.map { $0.badge.id })

        let defaults = UserDefaults.standard
        let notified = Set(defaults.array(forKey: notifiedKey) as? [String] ?? [])

        // First run: seed the baseline so existing badges don't fire a notification.
        guard defaults.bool(forKey: initKey) else {
            defaults.set(Array(earnedIds), forKey: notifiedKey)
            defaults.set(true, forKey: initKey)
            return
        }

        let freshIds = earnedIds.subtracting(notified)
        guard !freshIds.isEmpty else { return }

        let fresh = BadgeCatalog.all.filter { freshIds.contains($0.id) }
        do {
            try await send(fresh)
            // Only record as notified once the notification was actually scheduled,
            // so a failure is retried on the next check rather than lost.
            defaults.set(Array(notified.union(earnedIds)), forKey: notifiedKey)
        } catch {
            print("⚠️ Badge notification failed: \(error)")
        }
    }

    private func send(_ badges: [Badge]) async throws {
        guard !badges.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = "Next Wave 🏅"
        if badges.count == 1 {
            content.body = "You earned the “\(badges[0].title)” badge — tap to see it."
        } else {
            let names = badges.prefix(3).map { $0.title }.joined(separator: ", ")
            content.body = "You earned \(badges.count) new badges: \(names)\(badges.count > 3 ? " …" : "")"
        }
        content.sound = .default
        content.userInfo = ["deepLink": "badges"]
        content.categoryIdentifier = "badge_earned"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "badge_earned_\(UUID().uuidString)",
                                            content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }
}
