# Add to Calendar — Share Sheet Integration

**Date:** 2026-06-09
**Status:** Design approved, ready for implementation plan

## Goal

Add an "Add to Calendar" option to the wave share sheet as an engagement driver. When a
planned wave lives in the user's calendar, they are more likely to return to the app and
gain planning certainty. Uses standard iOS EventKit APIs — low effort, high effect.

## Entry Point

A **fourth tile** labelled "Calendar" (SF Symbol `calendar`, red background) is added to the
existing tile row in `CustomShareSheet`
([Next Wave/Views/DepartureRowView.swift](../../../Next%20Wave/Views/DepartureRowView.swift),
struct `CustomShareSheet`), alongside WhatsApp / Messages / Mail.

- The sheet's fixed `presentationDetents([.height(220)])` grows to ≈240 to keep four tiles
  comfortable in the horizontal row.
- The tile is always shown — no permission gating, because the native editor handles the
  permission flow at save time.

## Mechanism

Tapping "Calendar" presents Apple's native **`EKEventEditViewController`**, wrapped in a
`UIViewControllerRepresentable` (`CalendarEventEditView`), pre-filled with an `EKEvent`.

- The user reviews the pre-filled event and taps **Add**.
- No upfront permission prompt — iOS requests write access only when the user saves.
- The edit view's delegate (`EKEventEditViewDelegate`) dismisses the editor and then closes
  the surrounding share sheet (`isPresented = false`).
- If the user cancels, the editor dismisses and nothing is written.

## Event Content

| Field | Value |
|-------|-------|
| **Title** | `🌊 Wave – {station} → {destination}` (e.g. "🌊 Wave – Thalwil → Zürich") |
| **Start** | `wave.time` |
| **End** | `wave.time + 1 hour` |
| **Alarm** | none (the app's own push notifications handle alerting; the user may add one manually in the native editor) |
| **Location** | station name as the text location **plus** an `EKStructuredLocation` carrying the station's `coordinates` (enables maps / travel-time in Calendar) |
| **Notes** | built line-by-line, omitting any unavailable data (see below) |

### Notes lines (each omitted if data is unavailable — no placeholders)

1. **Ship:** `{shipName}` — only for Zürichsee waves within the next 7 days, when the ship
   name is known and not "Unknown".
2. **Weather:** air temperature, water temperature, wind, and recommended wetsuit thickness,
   reusing the existing `getWaterTemperatureForWave` and `getWetsuitThickness` logic.
3. **Attribution:** `Opened with Next Wave – nextwave://` (the `nextwave://` URL scheme is
   already registered in `Info.plist`).

## Data Availability (verified)

- `WaveEvent` provides `time`, `routeNumber`, `routeName`, `neighborStopName` (destination),
  `shipName`, `weather`, `lake`, and `isZurichsee`.
- The selected station (`lakeStationsViewModel.selectedStation`) is a `Lake.Station`, which
  carries `coordinates: Coordinates?` (latitude / longitude).
- URL scheme `nextwave://` is registered under `CFBundleURLTypes` in
  `Next Wave/Info.plist`.

## Code Shape

- **New file** `CalendarEventEditView.swift` — the `UIViewControllerRepresentable` plus its
  `EKEventEditViewDelegate`. Single, isolated purpose.
- **Event-builder helper** that constructs an `EKEvent` from a `WaveEvent` + selected station
  + view model. Keeps event construction testable and out of the view. The notes / weather /
  wetsuit helpers currently living inside `CustomShareSheet` are reused (or lifted into this
  helper to avoid duplication).
- **`Info.plist`**: add `NSCalendarsWriteOnlyAccessUsageDescription` (iOS 17+ write-only
  calendar access) — the minimal permission string required to save events.

## Error / Edge Handling

- **Missing station coordinates** → event is still created, simply without the structured
  location.
- **Unknown ship / no weather data** → those notes lines are omitted; no placeholder text.
- **User cancels the editor** → the sheet dismisses, nothing is written to any calendar.

## Out of Scope (YAGNI)

- Direct silent calendar writes (`EKEventStore`) and `.ics` file export — rejected in favour
  of the native editor for lowest friction and full user control.
- Calendar event alarms — deliberately omitted; the app's push notifications cover alerting.
- Editing or deleting previously created calendar events from within the app.
