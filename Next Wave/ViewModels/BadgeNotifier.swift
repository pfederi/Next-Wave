import Foundation
import UserNotifications

/// Detects newly-earned badges and sends a local notification that deep-links
/// to "My Badges". State is kept in UserDefaults so it works from both the
/// foreground and a background task (independently of the in-app celebration,
/// which uses `seenBadgeIds`).
enum BadgeNotifier {
    private static let notifiedKey = "notifiedBadgeIds"
    private static let initKey = "badgeNotifierInitialized"

    /// Fetch stats, compare earned badges against the last-notified set, and
    /// notify about any newly earned ones. On first run it only establishes a
    /// baseline (no retroactive notification for already-earned badges).
    static func checkAndNotify() async {
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
        send(fresh)
        defaults.set(Array(notified.union(earnedIds)), forKey: notifiedKey)
    }

    private static func send(_ badges: [Badge]) {
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
        UNUserNotificationCenter.current().add(request)
    }
}
