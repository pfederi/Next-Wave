import Foundation

struct CheckinIdentity: Codable, Equatable {
    var name: String
    var isAnonymous: Bool

    /// Name shown to others, or nil when anonymous / blank.
    var displayName: String? {
        if isAnonymous { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
