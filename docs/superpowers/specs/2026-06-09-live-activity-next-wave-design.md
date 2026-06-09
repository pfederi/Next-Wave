# Live Activity — Countdown to Next Wave

**Date:** 2026-06-09
**Status:** Design approved, ready for implementation plan

## Goal

Bring NextWave onto the Lock Screen and Dynamic Island with a live countdown to the
user's next wave. When a wave the user committed to is ticking down on their most-seen
screen, the app stays present without being opened — a passive re-engagement driver and a
genuine planning aid ("be at the water at 14:32").

## Key Constraint

iOS only allows an app to **start** a Live Activity while it is in the foreground.
Auto-starting from the background requires APNs push-to-start (a backend), which this
project does not have. Therefore the Live Activity is started from an in-app action and
re-synced whenever the app is foregrounded. No remote push, no backend.

## Behaviour Decisions (confirmed)

- **Trigger:** the bell. When the user taps the bell to set a notification for a wave, a
  Live Activity counting down to that wave is also started.
- **Single activity:** at most one Live Activity exists, pointed at the **soonest belled,
  not-yet-passed wave**.
- **8-hour window:** a Live Activity is only started when the wave is within ~8 hours.
  Belling a wave further out only schedules the notification (current behaviour); the
  activity is started later, on app foreground, once the wave enters the window.
- **Content:** live countdown + station name (always); destination (`→ Zürich`); ship name
  + wave-strength icon when known (Zürichsee, within 7 days). No wave number, no weather.
- **Tap target:** tapping the activity deep-links into the app at that station/date.

## Architecture & Components

The Live Activity is added to the **existing widget extension**
(`NextWaveWidgetBundle`, `NextWaveWidgetExtension` target) as an `ActivityConfiguration`
alongside the current widgets.

### `WaveActivityAttributes` (shared: app + widget targets)
Defines the activity's data. Because a single fixed wave is tracked, the data is mostly
**static**:

```swift
struct WaveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {}   // empty — see note

    let stationName: String
    let destinationName: String
    let waveTime: Date
    let shipName: String?       // nil unless Zürichsee + within 7 days + known
    let waveIconName: String?   // "waves1" | "waves2" | "waves3", nil if no ship
}
```

The countdown uses SwiftUI's `Text(timerInterval:)`, which self-updates on-device with no
push and no background work. The `ContentState` is therefore empty — no dynamic updates are
needed for a single wave. This is what keeps the feature backend-free.

### `WaveLiveActivityView` (widget target)
The lock-screen view plus the Dynamic Island presentations (compact leading / compact
trailing / minimal / expanded). Lives next to the existing widget views.

### `LiveActivityManager` (app target)
A small wrapper around `ActivityKit`. Single responsibility: own the lifecycle of the one
activity. Public surface:

- `startOrRetarget(for wave: WaveEvent, stationName:, coordinates:)` — start an activity for
  the wave, or re-target the existing one if this wave is sooner and in-window.
- `end(for wave: WaveEvent)` — end the activity if it currently tracks this wave.
- `syncToSoonestBelledWave(_ candidates: [WaveEvent], ...)` — end any stale activity and
  start one for the soonest in-window candidate.

### `LiveActivityCandidate` selection (pure, app target — unit-tested)
The decision logic — "given a set of belled waves and `now`, which wave (if any) should the
activity track?" — is extracted as a **pure function** with no ActivityKit dependency:

```swift
enum LiveActivitySelector {
    /// Returns the soonest wave that is in the future and within `window` of `now`,
    /// or nil if none qualify.
    static func soonestInWindow(_ waves: [WaveEvent], now: Date, window: TimeInterval) -> WaveEvent?
}
```

`window` is `8 * 3600`. This function is the testable core; `LiveActivityManager` calls it
and performs the ActivityKit side effects.

## Data Flow / Lifecycle

1. **Bell tap** — in `ScheduleViewModel.scheduleNotification(for:)`, after the existing
   notification is scheduled, call `LiveActivityManager.startOrRetarget(...)` with the wave
   and the currently selected station (for name + coordinates + deep-link).
2. **Re-target** — if an activity already exists and the new wave is sooner and in-window,
   end the old and start the new. If the new wave is later, leave the existing one.
3. **Bell removed** — in `ScheduleViewModel.removeNotification(for:)`, call
   `LiveActivityManager.end(for:)`; if it was the tracked wave, the activity ends. (The
   manager may then re-sync to the next soonest belled wave, since this is a foreground
   action.)
4. **App foreground** — call `syncToSoonestBelledWave(...)` with the set of currently belled
   waves. This ends a passed/stale activity and starts one for the next soonest in-window
   wave. This is how "advance to the next wave after one passes" is handled without push.
5. **Auto-end** — the activity is requested with `staleDate = waveTime` and a dismissal
   policy that removes it shortly after `waveTime`.
6. **Tap** — the activity's `widgetURL` / deep link is
   `nextwave://station?name=<station>&date=<yyyy-MM-dd>`, handled by `handleDeepLink` in
   [Next Wave/NextWaveApp.swift](../../../Next%20Wave/NextWaveApp.swift) (around line 244),
   which selects the station and sets the date.

## Content & Layout

- **Lock screen:** `🌊 {stationName}` — large live countdown (`in 12:34`) — `→ {destinationName}`
  — ship name + wave icon when `shipName`/`waveIconName` are present.
- **Dynamic Island:**
  - Expanded: station + countdown + `→ destination` + ship/icon when known.
  - Compact leading: 🌊 (or the wave icon when known). Compact trailing: the countdown.
  - Minimal: the countdown.
- The countdown is `Text(timerInterval: context.attributes.waveTime ... , countsDown: true)`
  (clamped so it does not display negative time).

## Wave Icon Mapping

Ship → icon name reuses the existing rule (from `DepartureRowView.getWaveIcon`):
`waves3` for the strongest-wake ships, `waves2` for the mid set, `waves1` otherwise. The
caller in the app resolves `waveIconName` when building the attributes (only for Zürichsee
waves within 7 days with a known ship name); the widget just renders the named asset.

## Assets

The wave icons (`waves1`, `waves2`, `waves3`) currently live in the app target's asset
catalog. They must be available to the **widget extension** too. Add them to the widget's
asset catalog (`NextWaveWidget/Assets.xcassets`).

## Permissions / Configuration

- Add `NSSupportsLiveActivities = YES` to `Next Wave/Info.plist`.
- Guard every start on `ActivityAuthorizationInfo().areActivitiesEnabled`. If Live Activities
  are disabled or unsupported, silently skip — the local notification still works exactly as
  today. The Live Activity is strictly additive.

## Error Handling / Edge Cases

- **Activities disabled / unsupported OS:** guarded; skip silently.
- **Wave further than 8h out:** no activity started; notification only. Picked up on next
  foreground sync once in-window.
- **Wave already passed:** never started; an existing one auto-ends via `staleDate`.
- **Missing ship / not Zürichsee / >7 days:** `shipName` and `waveIconName` are nil; the view
  omits the ship row and uses the 🌊 glyph.
- **Re-targeting races:** the manager always ends the previous activity before starting a new
  one, so at most one activity is live.

## Testing

- **Unit tests** (Swift Testing, `Next WaveTests`) cover `LiveActivitySelector.soonestInWindow`:
  - returns nil when all waves are in the past,
  - returns nil when the soonest future wave is beyond the window,
  - returns the soonest future wave within the window when several qualify,
  - ignores past waves when later waves qualify.
- The ActivityKit lifecycle (`LiveActivityManager`) and the SwiftUI activity view are **not**
  unit-tested, consistent with the codebase's treatment of widget/notification glue. They are
  verified manually on device/simulator (Dynamic Island requires a supported simulator or a
  physical device).

## Out of Scope (YAGNI)

- Push-to-start / remote updates / any backend.
- Multiple simultaneous Live Activities (one per belled wave).
- Live weather/wind on the activity.
- Auto-starting an activity with no bell tap (the "fully automatic next wave" option).
- Advancing to the next wave while the app is backgrounded (only handled on foreground sync).
