import Foundation

enum AppLanguage: String {
    case system, en, de, fr, it

    static let supportedLocaleCodes = ["en", "de", "fr", "it"]

    static func resolveEffectiveLocale(
        for language: AppLanguage,
        preferredSystemLanguages: [String] = Locale.preferredLanguages
    ) -> Locale {
        switch language {
        case .en, .de, .fr, .it:
            return Locale(identifier: language.rawValue)
        case .system:
            for preferred in preferredSystemLanguages {
                let code = Locale(identifier: preferred).language.languageCode?.identifier
                    ?? String(preferred.prefix(2))
                if supportedLocaleCodes.contains(code) {
                    return Locale(identifier: code)
                }
            }
            return Locale(identifier: "en")
        }
    }
}
