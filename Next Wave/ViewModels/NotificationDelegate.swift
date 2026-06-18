import UserNotifications

/// Handles notification presentation in the foreground and taps.
/// Badge notifications deep-link to the "My Badges" screen.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private func isBadge(_ notification: UNNotification) -> Bool {
        (notification.request.content.userInfo["deepLink"] as? String) == "badges"
    }

    // Show badge notifications even while the app is in the foreground.
    // Other notifications keep their default (suppressed-in-foreground) behavior.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(isBadge(notification) ? [.banner, .sound] : [])
    }

    // Tapping a badge notification opens "My Badges".
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if (response.notification.request.content.userInfo["deepLink"] as? String) == "badges" {
            Task { @MainActor in AppRouter.shared.openBadges = true }
        }
        completionHandler()
    }
}
