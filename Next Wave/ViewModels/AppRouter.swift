import SwiftUI

/// App-wide navigation triggers that can be set from outside the view tree
/// (e.g. a notification tap handler).
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()
    private init() {}

    /// When set true, ContentView pushes the "My Badges" screen.
    @Published var openBadges = false
}
