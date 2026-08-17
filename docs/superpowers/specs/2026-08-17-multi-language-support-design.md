# Multi-Language Support (DE / FR / IT / EN)

Status: Approved for planning
Date: 2026-08-17

## Goal

NextWave currently ships English-only across all four targets (iOS app,
iOS home-screen widget, watchOS app, watchOS widget). This adds German,
French, and Italian, defaulting to the device's system language, with a
manual override in the app's Settings screen that applies live, without
an app restart.

## Current State

- No localization infrastructure exists: no `.lproj` directories, no
  `Localizable.strings`/`.xcstrings`, no `NSLocalizedString` /
  `String(localized:)` usage anywhere in the codebase.
- `NextWave.xcodeproj/project.pbxproj`: `developmentRegion = en;`,
  `knownRegions = (en, Base);` — only English registered.
- ~300 discrete `Text(...)`/`Label(...)`/alert string literals across
  ~30 SwiftUI view files, spread over 4 build targets:
  - Main app (`Next Wave/`)
  - iOS home-screen widget (`NextWaveWidget/`)
  - watchOS app (`Next Wave Watch Watch App/`)
  - watchOS widget extension (`NextWaveWatchWidgetExtension/`)
- Deployment targets (iOS 17.5–18.1, watchOS 10.6, Xcode 16.4) fully
  support String Catalogs and `String(localized:)`.
- Settings persistence pattern already established in
  `Next Wave/ViewModels/AppSettings.swift`: an `ObservableObject` with
  `@Published` properties backed by `UserDefaults.standard` in each
  property's `didSet`. The existing `Theme` enum (`system`/`light`/`dark`,
  `AppSettings.swift:15-17`) is the direct template for a `Language`
  enum with a `system` fallback case.
- Cross-process sync infrastructure already exists and will be reused,
  not rebuilt:
  - App Group `group.com.federi.Next-Wave` (shared `UserDefaults`) is
    already used to pass data to `NextWaveWidget`.
  - `WatchConnectivityManager` (app side: `Next Wave/WatchConnectivityManager.swift`;
    watch side: `Next Wave Watch Watch App/WatchConnectivityManager.swift`)
    already syncs settings to the watch via `session.applicationContext`,
    e.g. `updateWidgetSettings(_:)`.

## Approach

### Technology: String Catalogs (`.xcstrings`)

Use Xcode's String Catalog format instead of legacy `Localizable.strings`.
Xcode auto-extracts string literals passed to `Text(...)` and similar
SwiftUI APIs at build time; translations are entered per key per
language directly in the catalog. This is Apple's current recommended
approach (since Xcode 15) and requires no manual key management.

Each of the 4 targets gets its own `Localizable.xcstrings` (string sets
are largely disjoint between app/widget/watch). `en` (the literal text
already in source) remains the development region and the fallback
for any system language outside {de, fr, it, en}. Add `de`, `fr`, `it`
to the project's Localizations list, which updates `knownRegions` in
`project.pbxproj`.

### Data model: `AppLanguage`

In `AppSettings.swift`, add:

```swift
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, de, fr, it
    var id: String { rawValue }
}
```

- `AppSettings.language: AppLanguage` — `@Published`, persisted to
  `UserDefaults.standard` in `didSet`, mirroring the existing `theme`
  property exactly.
- `AppSettings.effectiveLocale: Locale` — computed:
  - `.system`: pick the best match from `Locale.preferredLanguages`
    that falls within {en, de, fr, it}; fall back to `en` if none
    match.
  - otherwise: `Locale(identifier: language.rawValue)`.

### Live switching in the main app

Apply `.environment(\.locale, appSettings.effectiveLocale)` on the root
view in `NextWaveApp.swift`'s `WindowGroup`. Because `Text("literal")`
is implicitly a `LocalizedStringKey`, this makes every view in the
hierarchy re-resolve against the String Catalog and the chosen locale
immediately when `AppSettings.language` changes — no restart needed.

Any string built outside a `Text` literal (dynamic construction, e.g.
notification bodies assembled in `NotificationManager`, VoiceOver
labels built from concatenation) needs an explicit
`String(localized:locale:)` call passing `appSettings.effectiveLocale`,
since those do not sit inside the SwiftUI environment. These call sites
will be identified and converted during implementation as each file is
localized.

### Settings UI

New section in `SettingsView.swift`, following the existing `Menu`-based
picker convention used by `LeadTimeMenu`/`SoundMenu`. Options: System,
English, Deutsch, Français, Italiano — each language label shown in its
own language (standard convention so users can find their language
regardless of current app language).

### Sync to the iOS widget

- On `AppSettings.language` change, write the raw value into the shared
  App Group `UserDefaults(suiteName: "group.com.federi.Next-Wave")`
  under a new key (e.g. `"app_language"`), alongside the existing
  `updateWidgetSettings` write path.
- Call `WidgetCenter.shared.reloadAllTimelines()` to force an immediate
  timeline refresh reflecting the new language.
- The widget's `TimelineProvider`/entry view reads `"app_language"` from
  the same App Group `UserDefaults`, computes its own effective locale
  (same {system,en,de,fr,it} logic, duplicated — the widget extension is
  a separate process and cannot share `AppSettings`), and applies
  `.environment(\.locale, ...)` on its own view hierarchy.

### Sync to the watchOS app and watch widget

- Add `updateLanguageSetting(_ language: AppLanguage)` to
  `WatchConnectivityManager` (app side), sent via
  `session.applicationContext`, mirroring `updateWidgetSettings`.
- Add the corresponding receive/apply logic to the watch-side
  `WatchConnectivityManager` and to `WatchViewModel`, storing the value
  locally on the watch (its own `UserDefaults`) and exposing an
  `effectiveLocale` the same way.
- Watch app root view applies `.environment(\.locale, ...)` the same
  way as the phone app.
- The watch widget extension (`NextWaveWatchWidgetExtension`) reads the
  synced value from the watch-side shared storage the same way the iOS
  widget does from the App Group.

### Fallback behavior

If a device's system language is not one of {de, fr, it, en}, the
`system` case's best-match logic falls back to English. This mirrors
standard iOS String Catalog behavior (missing translations fall back to
the development region) so no extra handling is required for the
`.system` case beyond the `effectiveLocale` computation above.

## Translation Scope

All ~300 extracted UI strings across all 4 targets are translated into
German, French, and Italian as part of this work (done directly in this
session — no external translator handoff). Station names, lake names,
and other proper nouns are left unchanged. App Store metadata (app
name, description, keywords) is explicitly out of scope.

## Testing

Manual verification only (no existing UI test suite to extend for pure
string-translation work):

1. Change the iOS Simulator's system language to German/French/Italian
   → app, widget, and watch (paired simulator/companion) follow it.
2. Change the simulator's system language to an unsupported language
   (e.g. Spanish) → app falls back to English.
3. In-app Settings: switch the language picker through all 5 options →
   main app UI updates immediately, without restart.
4. After switching in Settings, check the home-screen widget updates
   (may require a brief wait for `reloadAllTimelines()` to take effect).
5. After switching in Settings, foreground the paired Watch app and
   confirm it reflects the new language once `applicationContext`
   syncs.

## Out of Scope

- App Store listing localization (name, description, screenshots).
- Any language beyond German, French, Italian, English.
- Automated/unit tests for translation content correctness.
