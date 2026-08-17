# Multi-Language Support (DE/FR/IT/EN) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add German, French, and Italian localization to NextWave (main app, iOS widget, watchOS app, watchOS widget), defaulting to the device's system language, with a manual override in Settings that applies live without an app restart.

**Architecture:** Adopt Xcode String Catalogs (`.xcstrings`), one per target. A new `AppLanguage` enum (mirroring the existing `Theme` enum in `AppSettings`) drives `.environment(\.locale, ...)` on each target's root view. The main app's language choice is pushed to the iOS widget via the existing App Group (`group.com.federi.Next-Wave`) and to the watch via the existing `WatchConnectivityManager` — no new sync mechanism is introduced.

**Tech Stack:** SwiftUI, WidgetKit, WatchConnectivity, Xcode String Catalogs, Swift Testing (`import Testing` / `@Test` / `#expect`).

**Spec:** [docs/superpowers/specs/2026-08-17-multi-language-support-design.md](../specs/2026-08-17-multi-language-support-design.md)

## Global Constraints

- Supported languages: `en` (development region / fallback), `de`, `fr`, `it`. No other language is in scope.
- `.system` must resolve to the best match among the 4 supported languages from `Locale.preferredLanguages`, falling back to `en` if none match.
- The language override must apply to the main app **live, without an app restart** (via `.environment(\.locale, ...)`, not `Bundle` swizzling).
- App Store metadata (name, description, keywords) is **out of scope**.
- `Shared/WatchWidget.swift` is not registered in any Xcode target (confirmed via `grep -n "WatchWidget" NextWave.xcodeproj/project.pbxproj`, no hits) — it is dead code and **excluded** from this work. Do not create a catalog entry for it.
- **Translation glossary** — reuse these exact translations everywhere the English term appears, across every task, so wording stays consistent app-wide:

  | English | German | French | Italian |
  |---|---|---|---|
  | Settings | Einstellungen | Réglages | Impostazioni |
  | Departures | Abfahrten | Départs | Partenze |
  | Station / Stations | Station / Stationen | Station / Stations | Stazione / Stazioni |
  | Favorites | Favoriten | Favoris | Preferiti |
  | Wave Check-in | Wave-Check-in | Check-in Wave | Check-in Wave |
  | Notifications | Benachrichtigungen | Notifications | Notifiche |
  | Widget(s) | Widget(s) | Widget(s) | Widget |
  | Language | Sprache | Langue | Lingua |
  | System | System | Système | Sistema |
  | Appearance | Erscheinungsbild | Apparence | Aspetto |
  | Light Mode | Heller Modus | Mode clair | Modalità chiara |
  | Dark Mode | Dunkler Modus | Mode sombre | Modalità scura |
  | Badge(s) | Badge(s) | Badge(s) | Badge |
  | Leaderboard | Rangliste | Classement | Classifica |

  `Foil`/`Foiling`/`Foiler`, `Wave`, and `NextWave` are sport/brand terms — leave them unchanged in every language. Station names, lake names, and other proper nouns are never translated.
- **Interpolated strings:** when Xcode extracts a `Text("... \(value) ...")` literal, the interpolation becomes a format specifier (e.g. `%lld`, `%@`) in the catalog key. Keep exactly one occurrence of each specifier in every language's translation; reorder surrounding words per that language's grammar, but never drop or duplicate a specifier. Task 4 has a fully worked example.
- **Verification script** (created in Task 2, reused by every translation task): `scripts/check_localization_completeness.py <path-to-Localizable.xcstrings>` — exits non-zero and lists every string missing a `de`/`fr`/`it` translation. A translation task is not done until this script exits 0 for its target's catalog.
- Build destinations confirmed available on this machine (use these exact strings in build/test commands):
  - iOS: `-destination 'platform=iOS Simulator,name=iPhone 17'`
  - watchOS: `-destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'`
- Schemes: `NextWave` (main app + widget, since the widget embeds in the app target), `Next Wave Watch Watch App`, `NextWaveWatchWidgetExtensionExtension`.

---

### Task 1: `AppLanguage` model + effective-locale resolution

**Files:**
- Modify: `Next Wave/ViewModels/AppSettings.swift`
- Create: `Next WaveTests/AppLanguageTests.swift`

**Interfaces:**
- Produces: `enum AppLanguage: String, Codable, CaseIterable, Identifiable { case system, en, de, fr, it }`, `AppLanguage.supportedLocaleCodes: [String]`, `AppLanguage.nativeName: String?`, `static AppLanguage.resolveEffectiveLocale(for:preferredSystemLanguages:) -> Locale`, `AppSettings.language: AppLanguage` (published, persisted), `AppSettings.effectiveLocale: Locale`.

- [ ] **Step 1: Write the failing tests**

Create `Next WaveTests/AppLanguageTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project NextWave.xcodeproj -scheme NextWave -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:Next_WaveTests/AppLanguageTests 2>&1 | tail -40`
Expected: FAIL — "cannot find type 'AppLanguage' in scope" (build error, since the type doesn't exist yet).

- [ ] **Step 3: Implement `AppLanguage` and wire it into `AppSettings`**

In `Next Wave/ViewModels/AppSettings.swift`, add this new top-level type after the closing brace of `AppSettings` (i.e. near the existing `LocationPickerMode`/`MapRegion` types at the bottom of the file):

```swift
enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system, en, de, fr, it
    var id: String { rawValue }

    static let supportedLocaleCodes = ["en", "de", "fr", "it"]

    /// The language's own name in its own script (e.g. "Deutsch"), always shown
    /// this way regardless of the app's current display language. `nil` for
    /// `.system`, whose label is translated instead of shown as a language name.
    var nativeName: String? {
        switch self {
        case .system: return nil
        case .en: return "English"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .it: return "Italiano"
        }
    }

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
```

Then inside the `AppSettings` class body, add the published property right after the existing `theme` property (after line 23's closing `}`):

```swift
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
        }
    }
```

Add the computed property near `isDarkMode` (after line 150's closing `}`):

```swift
    var effectiveLocale: Locale {
        AppLanguage.resolveEffectiveLocale(for: language)
    }
```

In `init()`, add alongside the existing `theme` initialization (after line 154):

```swift
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
        self.language = AppLanguage(rawValue: savedLanguage) ?? .system
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project NextWave.xcodeproj -scheme NextWave -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:Next_WaveTests/AppLanguageTests 2>&1 | tail -40`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add "Next Wave/ViewModels/AppSettings.swift" "Next WaveTests/AppLanguageTests.swift"
git commit -m "feat: add AppLanguage model with system-locale resolution"
```

---

### Task 2: Enable DE/FR/IT project localizations + scaffold empty String Catalogs

**Files:**
- Modify: `NextWave.xcodeproj/project.pbxproj`
- Create: `Next Wave/Localizable.xcstrings`
- Create: `NextWaveWidget/Localizable.xcstrings`
- Create: `Next Wave Watch Watch App/Localizable.xcstrings`
- Create: `NextWaveWatchWidgetExtension/Localizable.xcstrings`
- Create: `scripts/check_localization_completeness.py`

**Interfaces:**
- Produces: one empty `Localizable.xcstrings` per target, project-level `de`/`fr`/`it` localizations, and the completeness-check script every later translation task depends on.

- [ ] **Step 1: Register the 3 new languages at the project level**

In `NextWave.xcodeproj/project.pbxproj`, find:

```
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
```

Replace with:

```
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				de,
				fr,
				it,
				Base,
			);
```

- [ ] **Step 2: Create empty catalogs for the 3 targets that use synchronized folder groups**

These 3 targets (`Next Wave`, `NextWaveWidgetExtension`, `Next Wave Watch Watch App`) use Xcode 16's `PBXFileSystemSynchronizedRootGroup` — any file placed inside their target folder is picked up automatically, no manual pbxproj file-reference/build-phase entry needed. Create each with this exact content:

```json
{
  "sourceLanguage" : "en",
  "strings" : {

  },
  "version" : "1.1"
}
```

at:
- `Next Wave/Localizable.xcstrings`
- `NextWaveWidget/Localizable.xcstrings`
- `Next Wave Watch Watch App/Localizable.xcstrings`

- [ ] **Step 3: Register the catalog manually for the 4th target (uses a plain `PBXGroup`, not synchronized)**

`NextWaveWatchWidgetExtensionExtension` (folder `NextWaveWatchWidgetExtension/`) uses an explicit `PBXGroup`, so it needs manual pbxproj wiring. Create the file first:

`NextWaveWatchWidgetExtension/Localizable.xcstrings`:
```json
{
  "sourceLanguage" : "en",
  "strings" : {

  },
  "version" : "1.1"
}
```

Then in `NextWave.xcodeproj/project.pbxproj`:

1. Add a `PBXFileReference`. Find:
```
		8AFF99752DFB1ACC00F3E1FB /* NextWaveWatchWidgetExtensionExtension.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = NextWaveWatchWidgetExtensionExtension.entitlements; sourceTree = "<group>"; };
```
Insert immediately after it:
```
		BEEF00000000000000000001 /* Localizable.xcstrings */ = {isa = PBXFileReference; lastKnownFileType = text.json.xcstrings; path = Localizable.xcstrings; sourceTree = "<group>"; };
```

2. Add it to the target's group. Find:
```
		8AD40C432DFB4A7900FF448A /* NextWaveWatchWidgetExtension */ = {
			isa = PBXGroup;
			children = (
				8AD40C412DFB4A7900FF448A /* Info.plist */,
				8AD40C422DFB4A7900FF448A /* NextWaveWatchWidgetExtension.swift */,
			);
			path = NextWaveWatchWidgetExtension;
			sourceTree = "<group>";
		};
```
Replace with:
```
		8AD40C432DFB4A7900FF448A /* NextWaveWatchWidgetExtension */ = {
			isa = PBXGroup;
			children = (
				8AD40C412DFB4A7900FF448A /* Info.plist */,
				8AD40C422DFB4A7900FF448A /* NextWaveWatchWidgetExtension.swift */,
				BEEF00000000000000000001 /* Localizable.xcstrings */,
			);
			path = NextWaveWatchWidgetExtension;
			sourceTree = "<group>";
		};
```

3. Add a `PBXBuildFile`. Find:
```
		8AD40C442DFB4A7900FF448A /* NextWaveWatchWidgetExtension.swift in Sources */ = {isa = PBXBuildFile; fileRef = 8AD40C422DFB4A7900FF448A /* NextWaveWatchWidgetExtension.swift */; };
```
Insert immediately after it:
```
		BEEF00000000000000000002 /* Localizable.xcstrings in Resources */ = {isa = PBXBuildFile; fileRef = BEEF00000000000000000001 /* Localizable.xcstrings */; };
```

4. Add it to the target's Resources build phase. Find:
```
		8AFF99612DFB163800F3E1FB /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
```
Replace with:
```
		8AFF99612DFB163800F3E1FB /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				BEEF00000000000000000002 /* Localizable.xcstrings in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
```

- [ ] **Step 4: Create the completeness-check script**

Create `scripts/check_localization_completeness.py`:

```python
#!/usr/bin/env python3
"""
Checks that every string in a Localizable.xcstrings catalog has a
translated (non-empty) entry for de, fr, and it.

Usage: scripts/check_localization_completeness.py <path-to-Localizable.xcstrings> [...]
Exits 1 and prints every missing (key, language) pair if anything is missing.
"""
import json
import sys

REQUIRED_LANGUAGES = ("de", "fr", "it")


def check_catalog(path):
    with open(path) as f:
        catalog = json.load(f)

    missing = []
    for key, entry in catalog.get("strings", {}).items():
        if entry.get("shouldTranslate") is False:
            continue
        localizations = entry.get("localizations", {})
        for lang in REQUIRED_LANGUAGES:
            unit = localizations.get(lang, {}).get("stringUnit")
            if not unit or unit.get("state") != "translated" or not unit.get("value"):
                missing.append((key, lang))
    return missing


def main():
    if len(sys.argv) < 2:
        print("Usage: check_localization_completeness.py <path-to-Localizable.xcstrings> [...]")
        sys.exit(2)

    any_missing = False
    for path in sys.argv[1:]:
        missing = check_catalog(path)
        if missing:
            any_missing = True
            print(f"Missing {len(missing)} translations in {path}:")
            for key, lang in missing:
                print(f"  [{lang}] {key!r}")
        else:
            print(f"All strings fully translated in {path}")

    sys.exit(1 if any_missing else 0)


if __name__ == "__main__":
    main()
```

Make it executable: `chmod +x scripts/check_localization_completeness.py`

- [ ] **Step 5: Verify all 4 targets still build**

Run:
```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30
xcodebuild build -project NextWave.xcodeproj -scheme "Next Wave Watch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -30
xcodebuild build -project NextWave.xcodeproj -scheme NextWaveWatchWidgetExtensionExtension -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -30
```
Expected: `** BUILD SUCCEEDED **` for all three (the main `NextWave` scheme also builds `NextWaveWidgetExtension` as an embedded target). If the watch widget extension build fails with a pbxproj parse error, re-check the 4 edits in Step 3 for stray/missing braces or commas.

Also run the (currently trivially-passing, since catalogs are empty) completeness check to confirm the script itself runs cleanly:
```bash
python3 scripts/check_localization_completeness.py "Next Wave/Localizable.xcstrings" "NextWaveWidget/Localizable.xcstrings" "Next Wave Watch Watch App/Localizable.xcstrings" "NextWaveWatchWidgetExtension/Localizable.xcstrings"
```
Expected: `All strings fully translated in ...` ×4, exit code 0 (an empty `strings` dict has nothing to be missing).

- [ ] **Step 6: Commit**

```bash
git add NextWave.xcodeproj/project.pbxproj "Next Wave/Localizable.xcstrings" "NextWaveWidget/Localizable.xcstrings" "Next Wave Watch Watch App/Localizable.xcstrings" "NextWaveWatchWidgetExtension/Localizable.xcstrings" scripts/check_localization_completeness.py
git commit -m "build: enable de/fr/it localizations, scaffold String Catalogs per target"
```

---

### Task 3: Live locale wiring + Settings language picker (main app)

**Files:**
- Modify: `Next Wave/NextWaveApp.swift:204-211`
- Create: `Next Wave/Views/LanguageSettingsSection.swift`
- Modify: `Next Wave/Views/SettingsView.swift:22-26`

**Interfaces:**
- Consumes: `AppSettings.language: AppLanguage`, `AppSettings.effectiveLocale: Locale`, `AppLanguage.nativeName`, `AppLanguage.allCases` (from Task 1).
- Produces: `struct LanguageSettingsSection: View` for later reference by `SettingsView`.

- [ ] **Step 1: Apply the effective locale to the app's root view**

In `Next Wave/NextWaveApp.swift`, find (around line 204-211):
```swift
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(appSettings)
                .environmentObject(lakeStationsViewModel)
                .environmentObject(CheckinStore.shared)
                .preferredColorScheme(appSettings.theme == .system ? nil : (appSettings.isDarkMode ? .dark : .light))
```
Replace with:
```swift
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(appSettings)
                .environmentObject(lakeStationsViewModel)
                .environmentObject(CheckinStore.shared)
                .environment(\.locale, appSettings.effectiveLocale)
                .preferredColorScheme(appSettings.theme == .system ? nil : (appSettings.isDarkMode ? .dark : .light))
```

- [ ] **Step 2: Create the Settings language picker**

Create `Next Wave/Views/LanguageSettingsSection.swift`, following the exact `Menu` pattern used by `ThemeToggleView`:

```swift
import SwiftUI

struct LanguageSettingsSection: View {
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Language")
                .font(.headline)

            Menu {
                ForEach(AppLanguage.allCases) { language in
                    Button(action: {
                        appSettings.language = language
                    }) {
                        HStack {
                            label(for: language)
                            if appSettings.language == language {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(Color("text-color"))
                        .font(.system(size: 20))
                        .padding(.trailing, 8)

                    label(for: appSettings.language)
                        .foregroundColor(Color("text-color"))
                        .font(.system(size: 17, weight: .semibold))

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(Color("text-color"))
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("text-color").opacity(0.3), lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// `.system`'s label is translated ("System"/"Système"/...); every other
    /// language's own name is shown verbatim, in its own script, regardless of
    /// the app's current display language — so it never goes through Text's
    /// LocalizedStringKey lookup.
    private func label(for language: AppLanguage) -> Text {
        if let nativeName = language.nativeName {
            return Text(verbatim: nativeName)
        }
        return Text("System")
    }
}
```

- [ ] **Step 3: Insert the section into `SettingsView`**

In `Next Wave/Views/SettingsView.swift`, find (around line 22-26):
```swift
            VStack(alignment: .leading, spacing: 20) {
                // Theme section
                ThemeToggleView()
                Divider()
                
                // Display options section
```
Replace with:
```swift
            VStack(alignment: .leading, spacing: 20) {
                // Theme section
                ThemeToggleView()
                Divider()

                // Language section
                LanguageSettingsSection()
                Divider()
                
                // Display options section
```

- [ ] **Step 4: Build and manually verify live switching (no automated test — this is a UI wiring change)**

Run: `xcodebuild build -project NextWave.xcodeproj -scheme NextWave -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30`
Expected: `** BUILD SUCCEEDED **`.

Manually: run the app in the iPhone 17 simulator, open Settings, confirm a new "Language" row appears below "Appearance" showing a globe icon and a picker with System / English / Deutsch / Français / Italiano. Since no strings are translated yet (Task 2's catalogs are still empty), switching languages won't visibly change any text yet — that's expected; this task only verifies the control renders and persists a selection (kill and relaunch the app, confirm the picker still shows the previously chosen language).

- [ ] **Step 5: Commit**

```bash
git add "Next Wave/NextWaveApp.swift" "Next Wave/Views/LanguageSettingsSection.swift" "Next Wave/Views/SettingsView.swift"
git commit -m "feat: wire live locale switching and add language picker to Settings"
```

---

### Task 4: Translate — Settings & Core Navigation (main app)

**Files:**
- Modify: `Next Wave/Localizable.xcstrings`
- Modify: `Next Wave/Views/ThemeToggleView.swift` (fix a pre-existing localization bug while touching this file, see Step 1)
- Reference (read-only, extract strings from): `Next Wave/Views/SettingsView.swift`, `Next Wave/Views/WidgetSettingsView.swift`, `Next Wave/Views/CheckinSettingsSection.swift`, `Next Wave/ContentView.swift`, `Next Wave/Views/LanguageSettingsSection.swift`

**Interfaces:**
- Consumes: the completeness-check script from Task 2 (`scripts/check_localization_completeness.py`).
- Produces: every string literal in this file group has a `de`/`fr`/`it` entry in `Next Wave/Localizable.xcstrings`, ready for later tasks to add to without touching this group again.

- [ ] **Step 1: Fix a pre-existing bug that would silently skip translation in `ThemeToggleView`**

`ThemeToggleView.swift` currently builds its label via `Text({ switch ... return "Light Mode" ... }())`. Because the string comes from a closure's return value rather than a literal at the `Text(...)` call site, Swift resolves this to the non-localizing `Text(_ content: String)` initializer — these 3 strings would silently never translate even after being added to the catalog. Fix it by typing the switch's result as `LocalizedStringKey` so the literals stay literals:

In `Next Wave/Views/ThemeToggleView.swift`, find:
```swift
                    Text({
                        switch appSettings.theme {
                        case .light: return "Light Mode"
                        case .dark: return "Dark Mode"
                        case .system: return "System"
                        }
                    }())
```
Replace with:
```swift
                    Text(themeDisplayKey)
```

Then add this computed property to `ThemeToggleView` (right after `var body: some View {` 's closing brace, i.e. as a new property on the struct):
```swift
    private var themeDisplayKey: LocalizedStringKey {
        switch appSettings.theme {
        case .light: return "Light Mode"
        case .dark: return "Dark Mode"
        case .system: return "System"
        }
    }
```

- [ ] **Step 2: Extract every literal string in this file group**

Run:
```bash
grep -n 'Text("\|Text(verbatim\|\.alert(\|Label("' "Next Wave/Views/SettingsView.swift" "Next Wave/Views/WidgetSettingsView.swift" "Next Wave/Views/CheckinSettingsSection.swift" "Next Wave/ContentView.swift" "Next Wave/Views/LanguageSettingsSection.swift" "Next Wave/Views/ThemeToggleView.swift"
```
This lists every candidate literal with its file:line. Skip any `Text(verbatim: ...)` calls (by design, e.g. the language names in `LanguageSettingsSection`) and any `Text("\(dynamicValue)")` where the entire content is dynamic data (e.g. a station name) rather than UI copy.

- [ ] **Step 3: Add translated entries to `Next Wave/Localizable.xcstrings`**

Edit the (currently empty) `"strings": {}` object. Follow this exact schema. Three fully worked examples — one plain string, one from `ThemeToggleView` (now fixed), and one **interpolated** string (`Text("\(time) minutes")` in `LeadTimeMenu`, which is in this same file and must be included) to lock the format-specifier pattern:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "Settings" : {
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Einstellungen" } },
        "fr" : { "stringUnit" : { "state" : "translated", "value" : "Réglages" } },
        "it" : { "stringUnit" : { "state" : "translated", "value" : "Impostazioni" } }
      }
    },
    "Light Mode" : {
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Heller Modus" } },
        "fr" : { "stringUnit" : { "state" : "translated", "value" : "Mode clair" } },
        "it" : { "stringUnit" : { "state" : "translated", "value" : "Modalità chiara" } }
      }
    },
    "%lld minutes" : {
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "%lld Minuten" } },
        "fr" : { "stringUnit" : { "state" : "translated", "value" : "%lld minutes" } },
        "it" : { "stringUnit" : { "state" : "translated", "value" : "%lld minuti" } }
      }
    }
  },
  "version" : "1.1"
}
```

Continue this pattern for every remaining literal found in Step 2 (translate all of `SettingsView.swift`'s ~42 strings — section headers, toggle labels, button titles, the `SoundMenu`/`LeadTimeMenu` menus — plus `WidgetSettingsView.swift`, `CheckinSettingsSection.swift`, `ContentView.swift`'s literals, `LanguageSettingsSection.swift`'s "Language" and "System" keys, and `ThemeToggleView.swift`'s "Dark Mode"/"System" keys). Apply the Global Constraints glossary for any term listed there (e.g. "Settings" → use the glossary's exact translations, not a new one). For any other interpolated string in this group, mirror the `%lld minutes` pattern — check the exact specifier Xcode extracts by building first (Step 4) and re-checking the catalog's auto-populated English keys before hand-writing translations, rather than guessing the specifier text.

- [ ] **Step 4: Build to auto-extract any literal you may have missed, then re-check**

Run: `xcodebuild build -project NextWave.xcodeproj -scheme NextWave -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30`

Xcode's build merges any newly-found `Text("...")` literal from these files into the catalog automatically (as an untranslated `"state": "new"` entry for de/fr/it) even if you already hand-edited the file — open `Next Wave/Localizable.xcstrings` again afterward and translate anything that appeared with an empty/missing `stringUnit` for de/fr/it that Step 3 didn't already cover.

- [ ] **Step 5: Verify completeness**

Run: `python3 scripts/check_localization_completeness.py "Next Wave/Localizable.xcstrings"`
Expected: exits 0, `All strings fully translated in Next Wave/Localizable.xcstrings`. If it lists missing keys, they are almost always strings auto-extracted from files outside this task's scope (later tasks will cover them) — for now, add a translation for every key that maps back to `SettingsView.swift`, `WidgetSettingsView.swift`, `CheckinSettingsSection.swift`, `ContentView.swift`, `LanguageSettingsSection.swift`, or `ThemeToggleView.swift`; leave keys from other files for their own task.

- [ ] **Step 6: Manual smoke test**

Run the app in the iPhone 17 simulator. In Settings, switch Language to Deutsch → confirm "Einstellungen"/"Erscheinungsbild"/etc. render immediately without restarting. Switch to Français and Italiano and confirm the same. Switch back to System.

- [ ] **Step 7: Commit**

```bash
git add "Next Wave/Localizable.xcstrings" "Next Wave/Views/ThemeToggleView.swift"
git commit -m "feat(i18n): translate Settings and core navigation strings (de/fr/it)"
```

---

### Task 5: Translate — Departures & Stations (main app)

**Files:**
- Modify: `Next Wave/Localizable.xcstrings`
- Reference (read-only, extract strings from): `Next Wave/Views/DepartureRowView.swift`, `Next Wave/Views/DeparturesListView.swift`, `Next Wave/Views/FavoriteStationTileView.swift`, `Next Wave/Views/NearestStationTileView.swift`, `Next Wave/Views/FavoritesListView.swift`, `Next Wave/Views/FavoriteStationsEditView.swift`, `Next Wave/Views/MyStationsView.swift`, `Next Wave/Views/LocationPickerView.swift`, `Next Wave/Views/DateSelectionView.swift`

**Interfaces:**
- Consumes: same catalog schema and glossary as Task 4; the completeness-check script.

- [ ] **Step 1: Extract every literal string in this file group**

```bash
grep -n 'Text("\|Text(verbatim\|\.alert(\|Label("' "Next Wave/Views/DepartureRowView.swift" "Next Wave/Views/DeparturesListView.swift" "Next Wave/Views/FavoriteStationTileView.swift" "Next Wave/Views/NearestStationTileView.swift" "Next Wave/Views/FavoritesListView.swift" "Next Wave/Views/FavoriteStationsEditView.swift" "Next Wave/Views/MyStationsView.swift" "Next Wave/Views/LocationPickerView.swift" "Next Wave/Views/DateSelectionView.swift"
```

- [ ] **Step 2: Translate and add entries to `Next Wave/Localizable.xcstrings`**

Add one `strings` entry per literal found, using the same JSON shape as Task 4 Step 3. Apply the glossary ("Departures", "Station"/"Stations", "Favorites") wherever those exact English words appear. Two worked examples to anchor this group's vocabulary:

```json
    "Next Departure" : {
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Nächste Abfahrt" } },
        "fr" : { "stringUnit" : { "state" : "translated", "value" : "Prochain départ" } },
        "it" : { "stringUnit" : { "state" : "translated", "value" : "Prossima partenza" } }
      }
    },
    "No departures found" : {
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Keine Abfahrten gefunden" } },
        "fr" : { "stringUnit" : { "state" : "translated", "value" : "Aucun départ trouvé" } },
        "it" : { "stringUnit" : { "state" : "translated", "value" : "Nessuna partenza trovata" } }
      }
    }
```

Do not translate station/lake names (e.g. "Thalwil", "Zürich") — these come from dynamic data (`Text(station.name)`), not literals, and won't appear as catalog keys at all.

- [ ] **Step 3: Build to auto-extract anything missed**

Run: `xcodebuild build -project NextWave.xcodeproj -scheme NextWave -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30`
Translate any newly-appeared key belonging to this file group.

- [ ] **Step 4: Verify completeness for this group**

Run: `python3 scripts/check_localization_completeness.py "Next Wave/Localizable.xcstrings"`
As in Task 4 Step 5 — only chase down keys belonging to this task's files; leave others for their own task.

- [ ] **Step 5: Manual smoke test**

In the simulator, open the Departures list and Favorites/Station-picker screens with Language set to Deutsch, then Français, then Italiano — confirm all copy (not the station names) is translated and updates live.

- [ ] **Step 6: Commit**

```bash
git add "Next Wave/Localizable.xcstrings"
git commit -m "feat(i18n): translate departures and station screens (de/fr/it)"
```

---

### Task 6: Translate — Stats, Analytics, Badges & Leaderboard (main app)

**Files:**
- Modify: `Next Wave/Localizable.xcstrings`
- Reference (read-only, extract strings from): `Next Wave/Views/StatsView.swift`, `Next Wave/Views/WaveAnalyticsView.swift`, `Next Wave/Views/WaveTimelineChart.swift`, `Next Wave/Views/BadgeMedalView.swift`, `Next Wave/Views/WaveCheckinBadge.swift`, `Next Wave/Views/LeaderboardView.swift`

**Interfaces:**
- Consumes: same catalog schema and glossary as Task 4; the completeness-check script.

- [ ] **Step 1: Extract every literal string in this file group**

```bash
grep -n 'Text("\|Text(verbatim\|\.alert(\|Label("' "Next Wave/Views/StatsView.swift" "Next Wave/Views/WaveAnalyticsView.swift" "Next Wave/Views/WaveTimelineChart.swift" "Next Wave/Views/BadgeMedalView.swift" "Next Wave/Views/WaveCheckinBadge.swift" "Next Wave/Views/LeaderboardView.swift"
```

- [ ] **Step 2: Translate and add entries to `Next Wave/Localizable.xcstrings`**

Add one entry per literal, same JSON shape as before. Apply the glossary ("Badge(s)" stays "Badge(s)" in every language per Global Constraints, "Leaderboard" → "Rangliste"/"Classement"/"Classifica"). Worked example (a badge/stats string actually present in this app, per `BadgeEvaluatorTests`'s `"first_wave"` badge id):

```json
    "First Wave" : {
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Erste Wave" } },
        "fr" : { "stringUnit" : { "state" : "translated", "value" : "Première Wave" } },
        "it" : { "stringUnit" : { "state" : "translated", "value" : "Prima Wave" } }
      }
    }
```
("Wave" stays untranslated per the glossary's brand-term rule.)

- [ ] **Step 3: Build to auto-extract anything missed**

Run: `xcodebuild build -project NextWave.xcodeproj -scheme NextWave -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30`

- [ ] **Step 4: Verify completeness for this group**

Run: `python3 scripts/check_localization_completeness.py "Next Wave/Localizable.xcstrings"` — resolve only this task's files' keys.

- [ ] **Step 5: Manual smoke test**

Open Stats, Wave Analytics, Badges, and Leaderboard screens in Deutsch/Français/Italiano; confirm live translation.

- [ ] **Step 6: Commit**

```bash
git add "Next Wave/Localizable.xcstrings"
git commit -m "feat(i18n): translate stats, analytics, badges, and leaderboard (de/fr/it)"
```

---

### Task 7: Translate — Modals, Info & remaining components (main app)

**Files:**
- Modify: `Next Wave/Localizable.xcstrings`
- Reference (read-only, extract strings from): `Next Wave/Views/NavigationRulesModal.swift`, `Next Wave/Views/PromoTileView.swift`, `Next Wave/Views/GPXImportSummaryView.swift`, and every remaining file under `Next Wave/Views/Components/` not yet covered by Tasks 4–6

**Interfaces:**
- Consumes: same catalog schema and glossary as Task 4; the completeness-check script.

- [ ] **Step 1: Confirm what's left**

This is the catch-all for whatever Tasks 4–6 didn't cover. Run the full-project grep and diff against what's already in the catalog:

```bash
grep -rn 'Text("\|Text(verbatim\|\.alert(\|Label("' "Next Wave/Views/NavigationRulesModal.swift" "Next Wave/Views/PromoTileView.swift" "Next Wave/Views/GPXImportSummaryView.swift" "Next Wave/Views/Components/"
python3 -c "
import json
with open('Next Wave/Localizable.xcstrings') as f:
    print(sorted(json.load(f)['strings'].keys()))
"
```
Anything printed by `grep` whose exact text is not yet a key in the catalog dump is in scope for this task.

- [ ] **Step 2: Translate and add entries to `Next Wave/Localizable.xcstrings`**

Same JSON shape as Task 4 Step 3. Apply the glossary wherever its terms appear.

- [ ] **Step 3: Build to auto-extract anything missed**

Run: `xcodebuild build -project NextWave.xcodeproj -scheme NextWave -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30`

- [ ] **Step 4: Verify completeness for the whole main-app catalog**

Run: `python3 scripts/check_localization_completeness.py "Next Wave/Localizable.xcstrings"`
Expected: exits 0 — this is the last main-app translation task, so the **entire** main-app catalog must now be complete (no more "leave the rest for later").

- [ ] **Step 5: Manual smoke test**

Trigger the navigation-rules modal, a promo tile, and the GPX import summary screen in all 3 languages; confirm translation and live switching.

- [ ] **Step 6: Commit**

```bash
git add "Next Wave/Localizable.xcstrings"
git commit -m "feat(i18n): translate remaining modals and components (de/fr/it)"
```

---

### Task 8: iOS widget — language sync + translation

**Files:**
- Modify: `Next Wave/Shared/SharedDataManager.swift`
- Modify: `NextWaveWidget/SharedDataManager.swift`
- Create: `NextWaveWidget/AppLanguage.swift`
- Modify: `Next Wave/ViewModels/AppSettings.swift` (extend the `language` `didSet`)
- Modify: `NextWaveWidget/iPhoneWidget.swift:1501-1550`
- Modify: `NextWaveWidget/Localizable.xcstrings`

**Interfaces:**
- Consumes: `AppSettings.language` (Task 1).
- Produces: `NextWaveWidget/AppLanguage.swift`'s `AppLanguage.resolveEffectiveLocale(for:preferredSystemLanguages:)` (a target-local duplicate, matching this codebase's existing convention of duplicating small shared types per target — see `FavoriteStation`/`SharedDataManager` already duplicated across `NextWaveWidget`, `Next Wave Watch Watch App`, and `NextWaveWatchWidgetExtension`).

- [ ] **Step 1: Write-through the language setting to the App Group on the app side**

In `Next Wave/Shared/SharedDataManager.swift`, add near the other key constants (after line 13):
```swift
    private let languageKey = "appLanguage"
```
Add a new method (e.g. after `saveFavoriteStations`):
```swift
    func saveAppLanguage(_ language: String) {
        userDefaults?.set(language, forKey: languageKey)
        userDefaults?.synchronize()
    }
```

In `Next Wave/ViewModels/AppSettings.swift`, extend the `language` `didSet` added in Task 1:
```swift
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            SharedDataManager.shared.saveAppLanguage(language.rawValue)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
```

- [ ] **Step 2: Read the language setting on the widget side**

In `NextWaveWidget/SharedDataManager.swift`, add near the other key constants (after line 14):
```swift
    private let languageKey = "appLanguage"
```
Add a new method (e.g. after `loadFavoriteStations`):
```swift
    func loadAppLanguage() -> String {
        userDefaults?.string(forKey: languageKey) ?? "system"
    }
```

Create `NextWaveWidget/AppLanguage.swift`:
```swift
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
```

- [ ] **Step 3: Apply the resolved locale to both widget definitions**

In `NextWaveWidget/iPhoneWidget.swift`, find:
```swift
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: iPhoneProvider()) { entry in
            iPhoneWidgetEntryView(entry: entry)
                .widgetURL(createDeepLink(for: entry.departure))
        }
        .configurationDisplayName("NextWave")
        .description("Shows your next boat departure on iPhone")
```
Replace with:
```swift
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: iPhoneProvider()) { entry in
            iPhoneWidgetEntryView(entry: entry)
                .widgetURL(createDeepLink(for: entry.departure))
                .environment(\.locale, Self.effectiveLocale)
        }
        .configurationDisplayName("NextWave")
        .description("Shows your next boat departure on iPhone")
```
And find:
```swift
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: iPhoneMultipleProvider()) { entry in
            iPhoneMultipleWidgetEntryView(entry: entry)
                .widgetURL(createDeepLink(for: entry.departure))
        }
        .configurationDisplayName("NextWave - Next 3")
```
Replace with:
```swift
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: iPhoneMultipleProvider()) { entry in
            iPhoneMultipleWidgetEntryView(entry: entry)
                .widgetURL(createDeepLink(for: entry.departure))
                .environment(\.locale, Self.effectiveLocale)
        }
        .configurationDisplayName("NextWave - Next 3")
```

Add this shared helper once, e.g. as an extension right before `struct NextWaveiPhoneWidget: Widget {`:
```swift
extension Widget {
    static var effectiveLocale: Locale {
        let raw = SharedDataManager.shared.loadAppLanguage()
        return AppLanguage.resolveEffectiveLocale(for: AppLanguage(rawValue: raw) ?? .system)
    }
}
```

- [ ] **Step 4: Extract, translate, and verify this target's strings**

```bash
grep -n 'Text("\|Text(verbatim\|Label("' "NextWaveWidget/iPhoneWidget.swift"
```
Add translated entries to `NextWaveWidget/Localizable.xcstrings` following the same schema as Task 4 Step 3 (this catalog is separate from the main app's — its own glossary terms like "Departures" still apply). Then:
```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30
python3 scripts/check_localization_completeness.py "NextWaveWidget/Localizable.xcstrings"
```
Expected: build succeeds, completeness check exits 0.

- [ ] **Step 5: Manual verification**

Add the NextWave widget to the iPhone 17 simulator's home screen. In-app, switch Language to Deutsch, background the app, and confirm the widget updates to German after `reloadAllTimelines()` (may take a few seconds). Repeat for Français/Italiano.

- [ ] **Step 6: Commit**

```bash
git add "Next Wave/Shared/SharedDataManager.swift" "NextWaveWidget/SharedDataManager.swift" "NextWaveWidget/AppLanguage.swift" "Next Wave/ViewModels/AppSettings.swift" "NextWaveWidget/iPhoneWidget.swift" "NextWaveWidget/Localizable.xcstrings"
git commit -m "feat(i18n): sync language to iOS widget and translate its strings (de/fr/it)"
```

---

### Task 9: Watch app — WatchConnectivity sync, root wiring & translation

**Files:**
- Modify: `Next Wave/WatchConnectivityManager.swift` (app side)
- Modify: `Next Wave Watch Watch App/WatchConnectivityManager.swift` (watch side)
- Modify: `Next Wave Watch Watch App/SharedDataManager.swift`
- Create: `Next Wave Watch Watch App/AppLanguage.swift`
- Modify: `Next Wave Watch Watch App/WatchViewModel.swift`
- Modify: `Next Wave Watch Watch App/Next_Wave_Watch_App.swift`
- Modify: `Next Wave Watch Watch App/Localizable.xcstrings`
- Reference (read-only, extract strings from): `Next Wave Watch Watch App/ContentView.swift`

**Interfaces:**
- Consumes: `AppSettings.language` (Task 1), the app-side `WatchConnectivityManager.shared` singleton and its existing `updateWidgetSettings`/`sendCurrentDataToWatch` pattern.
- Produces: `WatchConnectivityManager.shared.updateLanguageSetting(_ language: String)` (app side), watch-side `Notification.Name.languageUpdated`, `WatchViewModel.effectiveLocale: Locale`.

- [ ] **Step 1: App side — send the language setting to the Watch**

In `Next Wave/WatchConnectivityManager.swift`, add a new method mirroring `updateWidgetSettings` (insert after it, i.e. after the closing `}` that currently precedes the blank line before `func triggerWidgetUpdate()`):

```swift
    func updateLanguageSetting(_ language: String) {
        let session = WCSession.default
        guard session.activationState == .activated else {
            logger.error("Cannot update language setting - WatchConnectivity session not activated")
            return
        }

        guard session.isPaired && session.isWatchAppInstalled else {
            logger.error("Cannot update language setting - Watch not available")
            return
        }

        var context: [String: Any] = ["appLanguage": language]
        if let currentFavoritesData = session.applicationContext["favoriteStations"] as? Data {
            context["favoriteStations"] = currentFavoritesData
        }
        if let currentWidgetSettingsData = session.applicationContext["widgetSettings"] as? Data {
            context["widgetSettings"] = currentWidgetSettingsData
        }

        do {
            try session.updateApplicationContext(context)
        } catch {
            logger.error("Failed to update application context with language: \(error.localizedDescription)")
        }

        let message: [String: Any] = [
            "action": "updateLanguage",
            "appLanguage": language,
            "timestamp": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: { response in
                self.logger.debug("Language setting message sent successfully: \(response)")
            }, errorHandler: { error in
                self.logger.error("Failed to send language setting message: \(error.localizedDescription)")
            })
        } else {
            session.transferUserInfo(message)
            logger.debug("Language setting queued for transfer via userInfo")
        }

        logger.debug("Successfully sent language setting to Watch - appLanguage: \(language)")
    }
```

In the same file's `sendCurrentDataToWatch()`, add the language alongside the existing widget-settings send:
```swift
    private func sendCurrentDataToWatch() {
        logger.debug("Sending current data to Watch after connection")
        
        // Send current widget settings
        let currentSettings = SharedDataManager.shared.loadWidgetSettings()
        updateWidgetSettings(currentSettings.useNearestStation)

        // Send current language
        let currentLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
        updateLanguageSetting(currentLanguage)
        
        // Also send current favorites if available
        let favoritesData = SharedDataManager.shared.loadFavoriteStations()
        if !favoritesData.isEmpty {
            updateFavorites(favoritesData)
        }
    }
```

In `Next Wave/ViewModels/AppSettings.swift`, extend `language`'s `didSet` (already extended once in Task 8) to also notify the Watch:
```swift
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            SharedDataManager.shared.saveAppLanguage(language.rawValue)
            WatchConnectivityManager.shared.updateLanguageSetting(language.rawValue)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
```

- [ ] **Step 2: Watch side — receive and persist the language setting**

In `Next Wave Watch Watch App/WatchConnectivityManager.swift`, add a new notification name alongside the existing ones (line 5-9):
```swift
extension Notification.Name {
    static let favoritesUpdated = Notification.Name("favoritesUpdated")
    static let forceWidgetUpdate = Notification.Name("forceWidgetUpdate")
    static let widgetSettingsUpdated = Notification.Name("widgetSettingsUpdated")
    static let languageUpdated = Notification.Name("languageUpdated")
}
```

In `processApplicationContext(_:)`, add handling for the new key (insert right after the existing `widgetSettings` block, before the closing brace that precedes `// Update widgets if we had any updates`):
```swift
        // Process language setting
        if let language = context["appLanguage"] as? String {
            logger.info("📱 Received language setting from iOS: \(language)")
            DispatchQueue.main.async {
                SharedDataManager.shared.saveAppLanguage(language)
                NotificationCenter.default.post(name: .languageUpdated, object: nil)
            }
            hasUpdates = true
        }
```

In `didReceiveMessage(_:_:replyHandler:)`'s `switch action`, add a new case (insert after the existing `case "updateWidgetSettings":` block, before `default:`):
```swift
            case "updateLanguage":
                if let language = message["appLanguage"] as? String {
                    logger.info("📱 Received language update - appLanguage: \(language)")
                    
                    DispatchQueue.main.async {
                        SharedDataManager.shared.saveAppLanguage(language)
                        NotificationCenter.default.post(name: .languageUpdated, object: nil)
                        replyHandler(["status": "language_updated", "appLanguage": language, "timestamp": Date().timeIntervalSince1970])
                    }
                }
```

In `didReceiveUserInfo(_:_:)`'s `switch action`, add the matching case (insert after the existing `case "updateWidgetSettings":` block, before `default:`):
```swift
            case "updateLanguage":
                if let language = userInfo["appLanguage"] as? String {
                    logger.info("📱 Received language update via user info - appLanguage: \(language)")
                    
                    DispatchQueue.main.async {
                        SharedDataManager.shared.saveAppLanguage(language)
                        NotificationCenter.default.post(name: .languageUpdated, object: nil)
                    }
                }
```

In `Next Wave Watch Watch App/SharedDataManager.swift`, add near the other key constants (after line 56):
```swift
    private let languageKey = "appLanguage"
```
Add new methods (e.g. after `loadWidgetSettings`):
```swift
    func saveAppLanguage(_ language: String) {
        userDefaults?.set(language, forKey: languageKey)
        userDefaults?.synchronize()
        logger.debug("Saved app language: \(language)")
    }

    func loadAppLanguage() -> String {
        userDefaults?.string(forKey: languageKey) ?? "system"
    }
```

- [ ] **Step 3: Watch-local `AppLanguage` + expose `effectiveLocale` on `WatchViewModel`**

Create `Next Wave Watch Watch App/AppLanguage.swift` (identical content to `NextWaveWidget/AppLanguage.swift` from Task 8 — this codebase duplicates small shared types per target rather than sharing a module, matching the existing `FavoriteStation`/`SharedDataManager` duplication):
```swift
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
```

In `Next Wave Watch Watch App/WatchViewModel.swift`, add a published property (after the existing `useNearestStationForWidget` on line 15):
```swift
    @Published var language: String = "system"
```
Add a computed property (anywhere in the class body):
```swift
    var effectiveLocale: Locale {
        AppLanguage.resolveEffectiveLocale(for: AppLanguage(rawValue: language) ?? .system)
    }
```
Add a `languageObserver` property alongside the other observers (after `widgetSettingsObserver` on line 26):
```swift
    private var languageObserver: NSObjectProtocol?
```
Add a setup method mirroring `setupWidgetSettingsObserver` — find that method's definition and add a new one right after it:
```swift
    private func setupLanguageObserver() {
        languageObserver = NotificationCenter.default.addObserver(
            forName: .languageUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.language = self.sharedDataManager.loadAppLanguage()
            }
        }
    }
```
In `init()`, call it alongside the other setup calls (after `setupWidgetSettingsObserver()` on line 35) and load the initial value alongside `loadWidgetSettings()` (line 37):
```swift
        setupLanguageObserver()
        ...
        language = sharedDataManager.loadAppLanguage()
```
In `deinit`, remove the observer alongside the others (after the `widgetSettingsObserver` removal block):
```swift
        if let observer = languageObserver {
            NotificationCenter.default.removeObserver(observer)
        }
```

- [ ] **Step 4: Apply the effective locale to the watch app's root view**

In `Next Wave Watch Watch App/Next_Wave_Watch_App.swift`, find:
```swift
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
                    .environmentObject(viewModel)
            }
        }
    }
```
Replace with:
```swift
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
                    .environmentObject(viewModel)
            }
            .environment(\.locale, viewModel.effectiveLocale)
        }
    }
```

- [ ] **Step 5: Extract, translate, and verify this target's strings**

```bash
grep -n 'Text("\|Text(verbatim\|Label("' "Next Wave Watch Watch App/ContentView.swift"
```
Add translated entries to `Next Wave Watch Watch App/Localizable.xcstrings` following the same schema as Task 4 Step 3.
```bash
xcodebuild build -project NextWave.xcodeproj -scheme "Next Wave Watch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -30
python3 scripts/check_localization_completeness.py "Next Wave Watch Watch App/Localizable.xcstrings"
```
Expected: build succeeds, completeness check exits 0.

- [ ] **Step 6: Manual verification**

Run the paired iPhone 17 + Apple Watch Series 11 (46mm) simulator pair. Switch Language in the iPhone app's Settings to Deutsch, foreground the Watch app, and confirm it reflects German once WatchConnectivity syncs (may take a moment on simulator — use "Force Send" if the app exposes it, or wait for `activationDidCompleteWith`). Repeat for Français/Italiano.

- [ ] **Step 7: Commit**

```bash
git add "Next Wave/WatchConnectivityManager.swift" "Next Wave Watch Watch App/WatchConnectivityManager.swift" "Next Wave Watch Watch App/SharedDataManager.swift" "Next Wave Watch Watch App/AppLanguage.swift" "Next Wave Watch Watch App/WatchViewModel.swift" "Next Wave Watch Watch App/Next_Wave_Watch_App.swift" "Next Wave Watch Watch App/Localizable.xcstrings" "Next Wave/ViewModels/AppSettings.swift"
git commit -m "feat(i18n): sync language to Watch app via WatchConnectivity and translate its strings (de/fr/it)"
```

---

### Task 10: Watch widget extension — locale resolution + translation

**Files:**
- Modify: `NextWaveWatchWidgetExtension/NextWaveWatchWidgetExtension.swift`
- Modify: `NextWaveWatchWidgetExtension/Localizable.xcstrings`

**Interfaces:**
- Consumes: the App Group key `"appLanguage"` written by the Watch app's own `SharedDataManager.saveAppLanguage` (Task 9) — this target reads the **watch-side** App Group, which is separate storage from the iPhone-side App Group used by Task 8's widget.

- [ ] **Step 1: Add a local `AppLanguage` + language read to this target's self-contained `SharedDataManager`**

This target's `SharedDataManager` is defined inline in `NextWaveWatchWidgetExtension.swift` (it doesn't share a file with the Watch app target). Add near its other key constants (after line 34):
```swift
    private let languageKey = "appLanguage"
```
Add a new method (e.g. after `loadWidgetSettings`):
```swift
    func loadAppLanguage() -> String {
        userDefaults?.string(forKey: languageKey) ?? "system"
    }
```

Add this enum near the top of the file, in the "Local Definitions for Watch Widget Extension" section (after the `FavoriteStation` struct, before `class SharedDataManager`):
```swift
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
```

- [ ] **Step 2: Apply the resolved locale to the complication widget**

Find:
```swift
struct NextWaveWatchComplication: Widget {
    let kind: String = "NextWaveWatchComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleWatchProvider()) { entry in
            SimpleWatchWidgetView(entry: entry)
        }
        .configurationDisplayName("NextWave")
        .description("Shows your next boat departure")
```
Replace with:
```swift
struct NextWaveWatchComplication: Widget {
    let kind: String = "NextWaveWatchComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleWatchProvider()) { entry in
            SimpleWatchWidgetView(entry: entry)
                .environment(\.locale, Self.effectiveLocale)
        }
        .configurationDisplayName("NextWave")
        .description("Shows your next boat departure")
```
Add the helper right above `struct NextWaveWatchComplication: Widget {`:
```swift
extension Widget {
    static var effectiveLocale: Locale {
        let raw = SharedDataManager.shared.loadAppLanguage()
        return AppLanguage.resolveEffectiveLocale(for: AppLanguage(rawValue: raw) ?? .system)
    }
}
```

- [ ] **Step 3: Extract, translate, and verify this target's strings**

```bash
grep -n 'Text("\|Text(verbatim' "NextWaveWatchWidgetExtension/NextWaveWatchWidgetExtension.swift"
```
This target has a small, fixed set of literals: `"now"`, `"at \(formatter.string(from: date))"` (interpolated — the `HH:mm` value is dynamic data, not UI copy, so only the surrounding "at %@" text needs translating, following the `%lld minutes` pattern from Task 4), `"No departures"`, `"NextWave"` (brand — leave untranslated per glossary), and `"No departures found"`. Add translated entries to `NextWaveWatchWidgetExtension/Localizable.xcstrings` following the same schema as Task 4 Step 3, reusing "Departures" from the glossary.

```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWaveWatchWidgetExtensionExtension -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -30
python3 scripts/check_localization_completeness.py "NextWaveWatchWidgetExtension/Localizable.xcstrings"
```
Expected: build succeeds, completeness check exits 0.

- [ ] **Step 4: Manual verification**

Add the NextWave complication to a watch face in the Apple Watch Series 11 (46mm) simulator. Switch Language on the paired iPhone to Deutsch and confirm the complication reflects it after the Watch app syncs (Task 9) and its own `reloadAllTimelines` fires.

- [ ] **Step 5: Commit**

```bash
git add "NextWaveWatchWidgetExtension/NextWaveWatchWidgetExtension.swift" "NextWaveWatchWidgetExtension/Localizable.xcstrings"
git commit -m "feat(i18n): resolve locale and translate Watch complication strings (de/fr/it)"
```

---

### Task 11: End-to-end verification pass

**Files:** none (verification only; fix forward in the relevant task's files if something fails)

**Interfaces:** none — this task exercises everything built in Tasks 1–10 together.

- [ ] **Step 1: Full build of all 4 targets**

```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30
xcodebuild build -project NextWave.xcodeproj -scheme "Next Wave Watch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -30
xcodebuild build -project NextWave.xcodeproj -scheme NextWaveWatchWidgetExtensionExtension -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -30
```
Expected: `** BUILD SUCCEEDED **` ×3.

- [ ] **Step 2: Full test suite**

```bash
xcodebuild test -project NextWave.xcodeproj -scheme NextWave -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -60
```
Expected: all tests pass, including `AppLanguageTests` from Task 1.

- [ ] **Step 3: Completeness check across all 4 catalogs at once**

```bash
python3 scripts/check_localization_completeness.py \
  "Next Wave/Localizable.xcstrings" \
  "NextWaveWidget/Localizable.xcstrings" \
  "Next Wave Watch Watch App/Localizable.xcstrings" \
  "NextWaveWatchWidgetExtension/Localizable.xcstrings"
```
Expected: exits 0, `All strings fully translated in ...` ×4.

- [ ] **Step 4: Manual scenario pass (per the spec's Testing section)**

Using the paired iPhone 17 + Apple Watch Series 11 (46mm) simulators:
1. Set the iOS Simulator's system language (Settings app → General → Language & Region) to German → confirm the app, widget, and Watch app all default to German with no manual override set.
2. Set it to a language outside {de, fr, it, en} (e.g. Spanish) → confirm the app falls back to English everywhere.
3. Reset the simulator's system language to English. In the app's Settings, use the in-app Language picker to cycle through System → English → Deutsch → Français → Italiano → System, confirming the main app's UI updates immediately at every step with no restart.
4. After picking Deutsch in Settings, background the app and check the home-screen widget updates to German within a few seconds.
5. After picking Deutsch, foreground the paired Watch app and confirm it reflects German once WatchConnectivity syncs; check the watch face complication too.

- [ ] **Step 5: Final commit (only if Step 4 surfaced fixes)**

If manual verification required any fix-forward changes, commit them with a message describing what was found and fixed. If everything passed as-is from Tasks 1–10's commits, there is nothing new to commit here.
