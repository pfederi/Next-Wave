import Testing
import Foundation
@testable import Next_Wave

struct AppLanguageTests {
    @Test func explicitLanguageIgnoresSystemPreferences() {
        let locale = AppLanguage.resolveEffectiveLocale(for: .fr, preferredSystemLanguages: ["de-CH", "en-US"])
        #expect(locale.identifier == "fr")
    }

    @Test func systemPicksFirstSupportedPreference() {
        let locale = AppLanguage.resolveEffectiveLocale(for: .system, preferredSystemLanguages: ["es-ES", "de-CH", "en-US"])
        #expect(locale.identifier == "de")
    }

    @Test func systemFallsBackToEnglishWhenNothingSupported() {
        let locale = AppLanguage.resolveEffectiveLocale(for: .system, preferredSystemLanguages: ["es-ES", "pt-PT"])
        #expect(locale.identifier == "en")
    }

    @Test func nativeNameIsNilForSystem() {
        #expect(AppLanguage.system.nativeName == nil)
    }

    @Test func nativeNameIsUntranslatedForExplicitLanguages() {
        #expect(AppLanguage.de.nativeName == "Deutsch")
        #expect(AppLanguage.fr.nativeName == "Français")
        #expect(AppLanguage.it.nativeName == "Italiano")
        #expect(AppLanguage.en.nativeName == "English")
    }
}
