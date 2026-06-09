# Live Activity — Countdown to Next Wave Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a self-updating countdown to the user's next belled wave on the Lock Screen and Dynamic Island via a Live Activity.

**Architecture:** A pure selection function (`LiveActivitySelector`) decides which belled wave to track — unit-tested, no ActivityKit. A shared `WaveActivityAttributes` type (member of BOTH the app and widget targets) carries the wave's static data. The widget extension renders it via an `ActivityConfiguration`. `LiveActivityManager` (app) owns the single activity's lifecycle and is driven from `ScheduleViewModel`'s bell + foreground hooks. The countdown uses `Text(timerInterval:)`, so no push and no backend.

**Tech Stack:** Swift, SwiftUI, ActivityKit, WidgetKit, Swift Testing.

**Spec:** [docs/superpowers/specs/2026-06-09-live-activity-next-wave-design.md](../specs/2026-06-09-live-activity-next-wave-design.md)

**Test command (note for the engineer):** the Xcode scheme is `NextWave`. Run unit tests with:
```bash
xcodebuild test -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:'Next WaveTests' 2>&1 | xcpretty || true
```
If `iPhone 16` is unavailable, run `xcrun simctl list devices available` and substitute a device. **The Live Activity UI itself cannot be verified by automated tests** — it requires the Dynamic Island simulator or a physical device.

---

## ⚠️ Critical project-structure note (read before Task 2)

This project uses **file-system-synchronized groups** (`PBXFileSystemSynchronizedRootGroup`):
files dropped into a target's folder are auto-added to that one target. Most files therefore
need no `.pbxproj` edits.

**Exception — `WaveActivityAttributes.swift` (Task 2).** ActivityKit matches the activity
type between the app and the widget extension by its fully-qualified (module-scoped) name.
The type MUST be the *same* type in both targets. The project's usual "duplicate the file
into each target folder" trick (as done for `DepartureInfo.swift`) would create two different
types (`Next_Wave.WaveActivityAttributes` vs `NextWaveWidgetExtension.WaveActivityAttributes`)
and the Live Activity would start but its UI would **never appear**. So this one file needs
**dual target membership** (one physical file, ticked for both the `Next Wave` and
`NextWaveWidgetExtension` targets), which on this project is done in Xcode's File Inspector
(or a careful `.pbxproj` edit). Task 2 spells this out.

---

## File Structure

- **Create** `Next Wave/Utilities/LiveActivitySelector.swift` — pure "which wave to track" logic (app target, auto-synced). Testable core.
- **Create** `Next WaveTests/LiveActivitySelectorTests.swift` — unit tests.
- **Create** `Shared/WaveActivityAttributes.swift` — the `ActivityAttributes` type. **Dual target membership** (app + widget).
- **Create** `Next Wave/Utilities/WaveIcon.swift` — ship→icon-name mapping, shared by the app and the activity builder (extracted from `DepartureRowView.getWaveIcon` for DRY).
- **Create** `NextWaveWidget/WaveLiveActivityView.swift` — the Live Activity SwiftUI views + `ActivityConfiguration` (widget target, auto-synced).
- **Create** `Next Wave/Services/LiveActivityManager.swift` — ActivityKit lifecycle wrapper (app target, auto-synced).
- **Modify** `NextWaveWidget/NextWaveWidgetBundle.swift` — register the Live Activity in the bundle.
- **Modify** `Next Wave/ViewModels/ScheduleViewModel.swift` — call the manager from `scheduleNotification`, `removeNotification`, `appWillEnterForeground`.
- **Modify** `Next Wave/Views/DepartureRowView.swift` — `getWaveIcon` delegates to the new shared `WaveIcon` (DRY).
- **Modify** `Next Wave/Info.plist` — `NSSupportsLiveActivities = YES`.
- **Copy** wave icon assets into `NextWaveWidget/Assets.xcassets`.

---

## Task 1: `LiveActivitySelector` (pure selection logic)

**Files:**
- Create: `Next Wave/Utilities/LiveActivitySelector.swift`
- Test: `Next WaveTests/LiveActivitySelectorTests.swift`

`WaveEvent` lives in the app target and has a `time: Date` and an `id: String`. The selector
needs only an array of `WaveEvent`, `now`, and a window.

- [ ] **Step 1: Write the failing tests**

Create `Next WaveTests/LiveActivitySelectorTests.swift`:

```swift
import Testing
import Foundation
@testable import Next_Wave

struct LiveActivitySelectorTests {

    private func wave(minutesFromNow: Double, now: Date, route: String = "1") -> WaveEvent {
        WaveEvent(
            time: now.addingTimeInterval(minutesFromNow * 60),
            isArrival: false,
            routeNumber: route,
            routeName: "Route \(route)",
            neighborStop: "X",
            neighborStopName: "Zürich",
            period: "p",
            lake: "Zürichsee"
        )
    }

    private let window: TimeInterval = 8 * 3600

    @Test func returnsNilWhenAllWavesInPast() {
        let now = Date()
        let waves = [wave(minutesFromNow: -10, now: now), wave(minutesFromNow: -120, now: now)]
        #expect(LiveActivitySelector.soonestInWindow(waves, now: now, window: window) == nil)
    }

    @Test func returnsNilWhenSoonestBeyondWindow() {
        let now = Date()
        let waves = [wave(minutesFromNow: 9 * 60, now: now)] // 9h out, window is 8h
        #expect(LiveActivitySelector.soonestInWindow(waves, now: now, window: window) == nil)
    }

    @Test func returnsSoonestFutureWaveInWindow() {
        let now = Date()
        let soon = wave(minutesFromNow: 30, now: now, route: "soon")
        let later = wave(minutesFromNow: 90, now: now, route: "later")
        let result = LiveActivitySelector.soonestInWindow([later, soon], now: now, window: window)
        #expect(result?.routeNumber == "soon")
    }

    @Test func ignoresPastWavesWhenFutureQualifies() {
        let now = Date()
        let past = wave(minutesFromNow: -5, now: now, route: "past")
        let future = wave(minutesFromNow: 45, now: now, route: "future")
        let result = LiveActivitySelector.soonestInWindow([past, future], now: now, window: window)
        #expect(result?.routeNumber == "future")
    }
}
```

> Note: confirm the `WaveEvent` initializer argument list against `Next Wave/Models/WaveEvent.swift` before running — it has stored properties `time, isArrival, routeNumber, routeName, neighborStop, neighborStopName, period, lake` and an optional `shipName`/`weather`/`hasNotification` with defaults. Adjust the test helper if the memberwise initializer differs.

- [ ] **Step 2: Run tests, verify they FAIL**

Run the test command with `-only-testing:'Next WaveTests/LiveActivitySelectorTests'`.
Expected: FAIL — `LiveActivitySelector` undefined.

- [ ] **Step 3: Implement**

Create `Next Wave/Utilities/LiveActivitySelector.swift`:

```swift
import Foundation

/// Pure decision logic for which belled wave a Live Activity should track.
/// No ActivityKit dependency, so it is fully unit-testable.
enum LiveActivitySelector {
    /// The soonest wave strictly in the future and within `window` of `now`,
    /// or nil if none qualify.
    static func soonestInWindow(_ waves: [WaveEvent], now: Date, window: TimeInterval) -> WaveEvent? {
        let upperBound = now.addingTimeInterval(window)
        return waves
            .filter { $0.time > now && $0.time <= upperBound }
            .min(by: { $0.time < $1.time })
    }
}
```

- [ ] **Step 4: Run tests, verify they PASS** (4 tests).

- [ ] **Step 5: Commit**

```bash
git add "Next Wave/Utilities/LiveActivitySelector.swift" "Next WaveTests/LiveActivitySelectorTests.swift"
git commit -m "feat: add LiveActivitySelector wave-selection logic"
```

---

## Task 2: `WaveActivityAttributes` shared type (dual target membership)

**Files:**
- Create: `Shared/WaveActivityAttributes.swift`

- [ ] **Step 1: Create the file**

Create `Shared/WaveActivityAttributes.swift` at the repository root (a neutral location, not
inside either target's synchronized folder):

```swift
import Foundation
import ActivityKit

/// Static data for the "next wave" Live Activity. Shared (same type) between the
/// app and the widget extension. The countdown is rendered with Text(timerInterval:)
/// from `waveTime`, so no dynamic ContentState is needed.
struct WaveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {}

    let stationName: String
    let destinationName: String
    let waveTime: Date
    let shipName: String?
    let waveIconName: String?
    /// Deep link opened when the activity is tapped, e.g.
    /// nextwave://station?name=Thalwil&date=2026-06-09
    let deepLinkURL: URL
}
```

- [ ] **Step 2: Add the file to BOTH targets**

In Xcode: select `WaveActivityAttributes.swift`, open the File Inspector (right panel), and
under **Target Membership** tick **both** `Next Wave` and `NextWaveWidgetExtension`.

Verify afterwards by building both the app and the widget extension (Step 3). If you hand-edit
`NextWave.xcodeproj/project.pbxproj` instead, the file needs a `PBXFileReference`, a
`PBXBuildFile` entry in *each* target's `Sources` build phase, and (because it is outside the
synchronized root groups) a normal group reference — run `plutil -lint` afterwards.

- [ ] **Step 3: Verify both targets build**

```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | xcpretty || true
```
Expected: BUILD SUCCEEDED. (Building the app scheme also builds the embedded widget extension.)

- [ ] **Step 4: Commit**

```bash
git add "Shared/WaveActivityAttributes.swift" NextWave.xcodeproj/project.pbxproj
git commit -m "feat: add WaveActivityAttributes shared Live Activity type"
```

---

## Task 3: `WaveIcon` shared helper (DRY extraction)

**Files:**
- Create: `Next Wave/Utilities/WaveIcon.swift`
- Modify: `Next Wave/Views/DepartureRowView.swift` (the private `getWaveIcon(for:)` at ~line 442)

- [ ] **Step 1: Create the shared helper**

Create `Next Wave/Utilities/WaveIcon.swift` (content lifted verbatim from the existing
`DepartureRowView.getWaveIcon`, so behaviour is identical):

```swift
import Foundation

/// Maps a ship name to its wave-strength asset name ("waves1" | "waves2" | "waves3").
enum WaveIcon {
    static func name(for shipName: String) -> String {
        let cleanName = shipName.trimmingCharacters(in: .whitespaces)
        switch cleanName {
        case "MS Panta Rhei", "MS Albis", "EMS Uetliberg", "EMS Pfannenstiel", "EM Uetliberg", "EM Pfannenstiel":
            return "waves3"
        case "MS Wädenswil", "MS Limmat", "MS Helvetia", "MS Linth", "DS Stadt Zürich", "DS Stadt Rapperswil":
            return "waves2"
        default:
            return "waves1"
        }
    }
}
```

- [ ] **Step 2: Make `DepartureRowView.getWaveIcon` delegate to it**

In `Next Wave/Views/DepartureRowView.swift`, replace the body of the private
`getWaveIcon(for:)` method (around line 442) so it delegates:

```swift
    private func getWaveIcon(for shipName: String) -> String {
        WaveIcon.name(for: shipName)
    }
```

(Leave the call sites unchanged — behaviour is identical.)

- [ ] **Step 3: Build to verify it compiles**

```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | xcpretty || true
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Next Wave/Utilities/WaveIcon.swift" "Next Wave/Views/DepartureRowView.swift"
git commit -m "refactor: extract WaveIcon mapping for reuse in Live Activity"
```

---

## Task 4: Wave icon assets in the widget extension

**Files:**
- Copy into: `NextWaveWidget/Assets.xcassets/`

The widget extension renders `waves1/2/3`, so those imagesets must exist in its asset catalog.

- [ ] **Step 1: Locate the source imagesets**

```bash
find "Next Wave" -type d -name "waves*.imageset"
```
Expected: three imageset directories (`waves1.imageset`, `waves2.imageset`, `waves3.imageset`)
under the app's `Assets.xcassets`. If the icons are PDF/SVG single files rather than imagesets,
locate those instead and note their exact paths.

- [ ] **Step 2: Copy them into the widget's catalog**

```bash
cd "/Users/federi/Documents/Next-Wave"
SRC="$(find 'Next Wave' -type d -name 'waves1.imageset' | head -1 | xargs dirname)"
cp -R "$SRC/waves1.imageset" "$SRC/waves2.imageset" "$SRC/waves3.imageset" NextWaveWidget/Assets.xcassets/
ls NextWaveWidget/Assets.xcassets/
```
Expected: `waves1.imageset waves2.imageset waves3.imageset` now listed alongside the existing
widget assets. (Files inside the synchronized `NextWaveWidget` folder are auto-included in the
widget target — no `.pbxproj` edit.)

- [ ] **Step 3: Commit**

```bash
git add NextWaveWidget/Assets.xcassets
git commit -m "feat: add wave icons to widget asset catalog for Live Activity"
```

---

## Task 5: Live Activity view + `ActivityConfiguration`

**Files:**
- Create: `NextWaveWidget/WaveLiveActivityView.swift`
- Modify: `NextWaveWidget/NextWaveWidgetBundle.swift`

- [ ] **Step 1: Create the Live Activity views**

Create `NextWaveWidget/WaveLiveActivityView.swift`:

```swift
import SwiftUI
import WidgetKit
import ActivityKit

@available(iOS 16.2, *)
struct WaveLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WaveActivityAttributes.self) { context in
            // Lock Screen / banner
            WaveLockScreenView(attributes: context.attributes)
                .widgetURL(context.attributes.deepLinkURL)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.4))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.stationName).font(.caption).lineLimit(1)
                    } icon: {
                        waveGlyph(context.attributes.waveIconName)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(to: context.attributes.waveTime)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .frame(maxWidth: 90)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 4) {
                        Text("→ \(context.attributes.destinationName)").lineLimit(1)
                        if let ship = context.attributes.shipName {
                            Spacer()
                            Text(ship).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .font(.caption)
                }
            } compactLeading: {
                waveGlyph(context.attributes.waveIconName)
            } compactTrailing: {
                countdown(to: context.attributes.waveTime)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                countdown(to: context.attributes.waveTime)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            }
            .widgetURL(context.attributes.deepLinkURL)
        }
    }
}

@available(iOS 16.2, *)
private func countdown(to date: Date) -> some View {
    // Self-updating, clamped so it never shows negative time.
    Text(timerInterval: Date()...max(date, Date().addingTimeInterval(1)),
         countsDown: true)
        .multilineTextAlignment(.trailing)
}

@ViewBuilder
private func waveGlyph(_ iconName: String?) -> some View {
    if let iconName {
        Image(iconName).resizable().scaledToFit().frame(width: 18, height: 14)
    } else {
        Image(systemName: "water.waves").foregroundStyle(.blue)
    }
}

@available(iOS 16.2, *)
struct WaveLockScreenView: View {
    let attributes: WaveActivityAttributes

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "water.waves").foregroundStyle(.blue)
                    Text(attributes.stationName).font(.headline).lineLimit(1)
                }
                Text("→ \(attributes.destinationName)")
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                if let ship = attributes.shipName {
                    HStack(spacing: 4) {
                        if let icon = attributes.waveIconName {
                            Image(icon).resizable().scaledToFit().frame(width: 16, height: 12)
                        }
                        Text(ship).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                countdown(to: attributes.waveTime)
                    .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                Text("to wave").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 2: Register it in the widget bundle**

In `NextWaveWidget/NextWaveWidgetBundle.swift`, add the Live Activity to the bundle body
(gated by availability, since the rest target iOS 17.5):

```swift
@main
struct NextWaveWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Only iOS widgets in this bundle
        NextWaveiPhoneWidget()
        NextWaveiPhoneMultipleWidget()
        if #available(iOS 16.2, *) {
            WaveLiveActivity()
        }
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | xcpretty || true
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add NextWaveWidget/WaveLiveActivityView.swift NextWaveWidget/NextWaveWidgetBundle.swift
git commit -m "feat: add Live Activity view and configuration to widget bundle"
```

---

## Task 6: `LiveActivityManager` (ActivityKit lifecycle)

**Files:**
- Create: `Next Wave/Services/LiveActivityManager.swift`

This wraps ActivityKit and uses `LiveActivitySelector`. It tracks at most one activity. It is
not unit-tested (ActivityKit glue); the decision logic it relies on is already tested in Task 1.

- [ ] **Step 1: Implement the manager**

Create `Next Wave/Services/LiveActivityManager.swift`:

```swift
import Foundation
import ActivityKit

/// Owns the single "next wave" Live Activity. All ActivityKit side effects live here.
@available(iOS 16.2, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    static let window: TimeInterval = 8 * 3600

    private var currentActivity: Activity<WaveActivityAttributes>?
    private var currentWaveID: String?

    /// Start (or re-target) the activity for `wave` if it is the soonest in-window belled wave.
    func startOrRetarget(for wave: WaveEvent, station: Lake.Station?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let now = Date()
        guard wave.time > now, wave.time <= now.addingTimeInterval(Self.window) else { return }

        // Only re-target if there is no activity yet, or this wave is sooner than the tracked one.
        if let activity = currentActivity, let trackedTime = trackedWaveTime, wave.time >= trackedTime {
            _ = activity // keep the existing, sooner activity
            return
        }
        start(for: wave, station: station)
    }

    /// End the activity if it currently tracks `wave`.
    func end(for wave: WaveEvent) {
        guard currentWaveID == wave.id else { return }
        endCurrent()
    }

    /// Reconcile: end any stale activity and start one for the soonest in-window belled wave.
    func syncToSoonestBelledWave(among waves: [WaveEvent], station: Lake.Station?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let target = LiveActivitySelector.soonestInWindow(waves, now: Date(), window: Self.window)
        guard let target else { endCurrent(); return }
        if currentWaveID == target.id { return } // already tracking it
        start(for: target, station: station)
    }

    // MARK: - Private

    private var trackedWaveTime: Date? { currentActivity?.attributes.waveTime }

    private func start(for wave: WaveEvent, station: Lake.Station?) {
        endCurrent()

        let stationName = station?.name ?? ""
        var shipName: String? = nil
        var iconName: String? = nil
        if wave.isZurichsee, isWithinNext7Days(wave.time),
           let name = wave.shipName, name != "Unknown" {
            shipName = name
            iconName = WaveIcon.name(for: name)
        }

        let attributes = WaveActivityAttributes(
            stationName: stationName,
            destinationName: wave.neighborStopName,
            waveTime: wave.time,
            shipName: shipName,
            waveIconName: iconName,
            deepLinkURL: Self.deepLink(stationName: stationName, date: wave.time)
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: WaveActivityAttributes.ContentState(),
                               staleDate: wave.time.addingTimeInterval(120)),
                pushType: nil
            )
            currentActivity = activity
            currentWaveID = wave.id
        } catch {
            currentActivity = nil
            currentWaveID = nil
        }
    }

    private func endCurrent() {
        guard let activity = currentActivity else { currentWaveID = nil; return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        currentWaveID = nil
    }

    private func isWithinNext7Days(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sevenDaysFromNow = calendar.date(byAdding: .day, value: 7, to: today)!
        let dateDay = calendar.startOfDay(for: date)
        return dateDay >= today && dateDay < sevenDaysFromNow
    }

    static func deepLink(stationName: String, date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        var components = URLComponents()
        components.scheme = "nextwave"
        components.host = "station"
        components.queryItems = [
            URLQueryItem(name: "name", value: stationName),
            URLQueryItem(name: "date", value: dateString)
        ]
        return components.url ?? URL(string: "nextwave://station")!
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | xcpretty || true
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Next Wave/Services/LiveActivityManager.swift"
git commit -m "feat: add LiveActivityManager for next-wave Live Activity lifecycle"
```

---

## Task 7: Wire into `ScheduleViewModel` + Info.plist

**Files:**
- Modify: `Next Wave/ViewModels/ScheduleViewModel.swift` (`scheduleNotification` ~371, `removeNotification` ~416, `appWillEnterForeground` ~427)
- Modify: `Next Wave/Info.plist`

`ScheduleViewModel` already has `var selectedStation: Lake.Station?`, `@Published var nextWaves: [WaveEvent]`, and `@Published var notifiedJourneys: Set<String>`.

- [ ] **Step 1: Add `NSSupportsLiveActivities` to Info.plist**

In `Next Wave/Info.plist`, add inside the top-level `<dict>` (e.g. after the
`NSCalendarsWriteOnlyAccessUsageDescription` string added earlier):

```xml
	<key>NSSupportsLiveActivities</key>
	<true/>
```

Verify: `plutil -lint "Next Wave/Info.plist"` → `OK`.

- [ ] **Step 2: Start the activity on bell tap**

In `scheduleNotification(for:)`, inside the `UNUserNotificationCenter.current().add` completion
handler — right after `self?.saveNotifications()` and before `self?.objectWillChange.send()` —
start the activity:

```swift
                self?.notifiedJourneys.insert(wave.id)
                self?.saveNotifications()
                if #available(iOS 16.2, *) {
                    LiveActivityManager.shared.startOrRetarget(for: wave, station: self?.selectedStation)
                }
                self?.objectWillChange.send()
```

- [ ] **Step 3: End the activity on bell removal**

In `removeNotification(for:)`, after the existing removal work, add:

```swift
        if #available(iOS 16.2, *) {
            LiveActivityManager.shared.end(for: wave)
            let belled = nextWaves.filter { notifiedJourneys.contains($0.id) }
            LiveActivityManager.shared.syncToSoonestBelledWave(among: belled, station: selectedStation)
        }
```

(`end` clears the activity if it tracked this wave; the follow-up `sync` re-points it at the
next soonest belled wave, since this is a foreground action.)

- [ ] **Step 4: Re-sync on app foreground**

In `appWillEnterForeground()`, after `loadNotifications()`:

```swift
    func appWillEnterForeground() {
        loadNotifications()
        if #available(iOS 16.2, *) {
            let belled = nextWaves.filter { notifiedJourneys.contains($0.id) }
            LiveActivityManager.shared.syncToSoonestBelledWave(among: belled, station: selectedStation)
        }
    }
```

- [ ] **Step 5: Build to verify it compiles**

```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | xcpretty || true
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add "Next Wave/ViewModels/ScheduleViewModel.swift" "Next Wave/Info.plist"
git commit -m "feat: drive next-wave Live Activity from bell and foreground hooks"
```

---

## Task 8: Manual device/simulator verification

Live Activities cannot be verified by automated tests. Verify by hand:

- [ ] **Step 1:** Run the app on a device or a Dynamic-Island-capable simulator (e.g. iPhone 16 Pro). Ensure Settings → (app) → Live Activities is enabled.
- [ ] **Step 2:** Select a station with a wave within the next ~8 hours and tap the bell on it.
- [ ] **Step 3:** Background the app. Confirm the Lock Screen shows `🌊 {station}`, a counting-down timer, `→ {destination}`, and (for a Zürichsee wave within 7 days with a known ship) the ship name + wave icon.
- [ ] **Step 4:** Long-press / observe the Dynamic Island: compact shows the wave glyph + countdown; expanded shows station, countdown, destination, ship.
- [ ] **Step 5:** Tap the activity → the app opens at that station and date.
- [ ] **Step 6:** Remove the bell → the activity disappears (and re-points to the next belled in-window wave if one exists).
- [ ] **Step 7:** Bell a wave more than 8h out → no activity appears (notification still scheduled).

---

## Self-Review Notes

- **Spec coverage:** bell trigger (Task 7 Step 2); single activity / soonest wave (Task 6 + Task 1); 8h window (Task 1 window + Task 6 guard); content countdown/station/destination/ship+icon (Task 5 + Task 2 attributes); tap deep-link reusing `handleDeepLink` (Task 6 `deepLink` + Task 5 `widgetURL`); re-sync on foreground (Task 7 Step 4); end on bell-removal / staleDate (Task 6 `end`/`staleDate`); icons in widget (Task 4); `NSSupportsLiveActivities` (Task 7 Step 1); `areActivitiesEnabled` guard (Task 6); pure-logic unit tests (Task 1). All covered.
- **Critical structure caveat** (dual target membership for `WaveActivityAttributes`) is called out before Task 2 and embedded in Task 2 Step 2.
- **Type consistency:** `WaveActivityAttributes` field names (`stationName`, `destinationName`, `waveTime`, `shipName`, `waveIconName`, `deepLinkURL`) are identical across Tasks 2, 5, 6. `LiveActivitySelector.soonestInWindow(_:now:window:)` signature matches between Tasks 1 and 6. `WaveIcon.name(for:)` matches between Tasks 3 and 6. `Self.window` (8h) is the single source for the window in Task 6 and is the value tested in Task 1.
- **No alarm / no backend / no push:** `pushType: nil`, `Text(timerInterval:)` — consistent with the spec's backend-free constraint.
