import Foundation

struct CheckinIdentity: Codable, Equatable {
    var name: String
    var isAnonymous: Bool

    /// Name shown to others, or nil when anonymous / blank. Capped at 40 chars
    /// since it appears on the public leaderboard.
    var displayName: String? {
        if isAnonymous { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(40))
    }
}
