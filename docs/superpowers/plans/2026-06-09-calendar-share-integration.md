# Add to Calendar — Share Sheet Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an "Add to Calendar" tile to the wave share sheet that opens iOS's native event editor pre-filled with a rich, 1-hour wave event.

**Architecture:** A pure value type (`CalendarEventContent`) holds the event data and assembles the title/notes strings — fully unit-testable with no EventKit dependency. A thin `UIViewControllerRepresentable` (`CalendarEventEditView`) turns that content into an `EKEvent` and presents `EKEventEditViewController`. `CustomShareSheet` gains a fourth tile that builds the content (reusing its existing weather/wetsuit helpers) and presents the editor.

**Tech Stack:** Swift, SwiftUI, EventKit / EventKitUI, CoreLocation, Swift Testing (`import Testing`).

**Spec:** [docs/superpowers/specs/2026-06-09-calendar-share-integration-design.md](../specs/2026-06-09-calendar-share-integration-design.md)

**Test command (note for the engineer):** the Xcode scheme is `NextWave`. Run unit tests with:
```bash
xcodebuild test -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:'Next WaveTests' 2>&1 | xcpretty || true
```
If `iPhone 16` is not an installed simulator, run `xcrun simctl list devices available` and substitute an available device name.

---

## File Structure

- **Create** `Next Wave/Models/CalendarEventContent.swift` — pure value type + builder + string assembly. No UIKit/EventKit imports. The unit-testable core.
- **Create** `Next Wave/Views/CalendarEventEditView.swift` — `UIViewControllerRepresentable` wrapping `EKEventEditViewController`; builds the `EKEvent` from a `CalendarEventContent`.
- **Modify** `Next Wave/Views/DepartureRowView.swift` — add the "Calendar" tile to `CustomShareSheet`, a content-builder method, the presenting `.sheet`, and grow the detent height.
- **Modify** `Next Wave/Info.plist` — add `NSCalendarsWriteOnlyAccessUsageDescription`.
- **Create** `Next WaveTests/CalendarEventContentTests.swift` — unit tests for the builder.

---

## Task 1: `CalendarEventContent` value type + builder

**Files:**
- Create: `Next Wave/Models/CalendarEventContent.swift`
- Test: `Next WaveTests/CalendarEventContentTests.swift`

The builder receives already-resolved optional values (the caller in Task 4 decides ship-name applicability, water temp, wetsuit, etc.). This keeps the model pure and free of `WeatherAPI`/`Lake`/date-dependent logic.

- [ ] **Step 1: Write the failing tests**

Create `Next WaveTests/CalendarEventContentTests.swift`:

```swift
import Testing
import Foundation
@testable import Next_Wave

struct CalendarEventContentTests {

    private func fixedDate() -> Date {
        // 2026-06-09 14:32:00 UTC
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 9; c.hour = 14; c.minute = 32
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    @Test func titleIncludesStationAndDestination() {
        let content = CalendarEventContent.make(
            waveTime: fixedDate(), stationName: "Thalwil", destinationName: "Zürich",
            latitude: nil, longitude: nil, shipName: nil,
            airTemperature: nil, waterTemperature: nil,
            windKnots: nil, windDirection: nil, wetsuitThickness: nil
        )
        #expect(content.title == "🌊 Wave – Thalwil → Zürich")
    }

    @Test func titleFallsBackWhenStationMissing() {
        let content = CalendarEventContent.make(
            waveTime: fixedDate(), stationName: nil, destinationName: "Zürich",
            latitude: nil, longitude: nil, shipName: nil,
            airTemperature: nil, waterTemperature: nil,
            windKnots: nil, windDirection: nil, wetsuitThickness: nil
        )
        #expect(content.title == "🌊 Wave → Zürich")
    }

    @Test func eventLastsOneHour() {
        let start = fixedDate()
        let content = CalendarEventContent.make(
            waveTime: start, stationName: "Thalwil", destinationName: "Zürich",
            latitude: nil, longitude: nil, shipName: nil,
            airTemperature: nil, waterTemperature: nil,
            windKnots: nil, windDirection: nil, wetsuitThickness: nil
        )
        #expect(content.startDate == start)
        #expect(content.endDate == start.addingTimeInterval(3600))
    }

    @Test func coordinatesPassThroughWhenPresent() {
        let content = CalendarEventContent.make(
            waveTime: fixedDate(), stationName: "Thalwil", destinationName: "Zürich",
            latitude: 47.29, longitude: 8.56, shipName: nil,
            airTemperature: nil, waterTemperature: nil,
            windKnots: nil, windDirection: nil, wetsuitThickness: nil
        )
        #expect(content.latitude == 47.29)
        #expect(content.longitude == 8.56)
        #expect(content.locationName == "Thalwil")
    }

    @Test func notesOmitUnavailableLines() {
        let content = CalendarEventContent.make(
            waveTime: fixedDate(), stationName: "Thalwil", destinationName: "Zürich",
            latitude: nil, longitude: nil, shipName: nil,
            airTemperature: nil, waterTemperature: nil,
            windKnots: nil, windDirection: nil, wetsuitThickness: nil
        )
        // Only the attribution lines remain.
        #expect(!content.notes.contains("⛴️"))
        #expect(!content.notes.contains("🌡️"))
        #expect(content.notes.contains("Next Wave"))
        #expect(content.notes.contains("nextwave://"))
    }

    @Test func notesIncludeAllAvailableData() {
        let content = CalendarEventContent.make(
            waveTime: fixedDate(), stationName: "Thalwil", destinationName: "Zürich",
            latitude: nil, longitude: nil, shipName: "MS Panta Rhei",
            airTemperature: 21.4, waterTemperature: 18.2,
            windKnots: 12, windDirection: "NW", wetsuitThickness: "3/2"
        )
        #expect(content.notes.contains("⛴️ MS Panta Rhei"))
        #expect(content.notes.contains("21.4"))   // air temp
        #expect(content.notes.contains("18.2"))   // water temp
        #expect(content.notes.contains("12 kn"))  // wind
        #expect(content.notes.contains("NW"))
        #expect(content.notes.contains("3/2"))    // wetsuit
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the test command above (with `-only-testing:'Next WaveTests/CalendarEventContentTests'`).
Expected: FAIL — `CalendarEventContent` is not defined / does not compile.

- [ ] **Step 3: Write the implementation**

Create `Next Wave/Models/CalendarEventContent.swift`:

```swift
import Foundation

/// Pure, EventKit-free description of a calendar event for a wave.
/// All inputs are pre-resolved by the caller, so this type stays testable
/// and free of weather/lake/date-dependent logic.
struct CalendarEventContent {
    let title: String
    let startDate: Date
    let endDate: Date
    let locationName: String?
    let latitude: Double?
    let longitude: Double?
    let notes: String

    static func make(
        waveTime: Date,
        stationName: String?,
        destinationName: String,
        latitude: Double?,
        longitude: Double?,
        shipName: String?,
        airTemperature: Double?,
        waterTemperature: Double?,
        windKnots: Double?,
        windDirection: String?,
        wetsuitThickness: String?
    ) -> CalendarEventContent {
        let title: String
        if let station = stationName, !station.isEmpty {
            title = "🌊 Wave – \(station) → \(destinationName)"
        } else {
            title = "🌊 Wave → \(destinationName)"
        }

        var lines: [String] = []

        if let ship = shipName, !ship.isEmpty {
            lines.append("⛴️ \(ship)")
        }
        if let air = airTemperature {
            lines.append("🌡️ \(String(format: "%.1f°C", air))")
        }
        if let water = waterTemperature {
            lines.append("💧 \(String(format: "%.1f°C", water))")
        }
        if let knots = windKnots {
            let dir = windDirection.map { " \($0)" } ?? ""
            lines.append("💨 \(Int(knots)) kn\(dir)")
        }
        if let wetsuit = wetsuitThickness {
            lines.append("🤸 Wetsuit: \(wetsuit)mm")
        }
        // Attribution — always present.
        lines.append("")
        lines.append("📱 Opened with Next Wave")
        lines.append("nextwave://")

        return CalendarEventContent(
            title: title,
            startDate: waveTime,
            endDate: waveTime.addingTimeInterval(3600),
            locationName: stationName,
            latitude: latitude,
            longitude: longitude,
            notes: lines.joined(separator: "\n")
        )
    }
}
```

- [ ] **Step 4: Add the file to the test target membership**

In Xcode, both `CalendarEventContent.swift` (Next Wave target) and `CalendarEventContentTests.swift` (Next WaveTests target) must be added to the project. If editing the `.pbxproj` by hand is undesirable, open the project in Xcode and drag the files in with the correct target checkboxes. Verify by re-running the build in Step 5.

- [ ] **Step 5: Run tests to verify they pass**

Run the test command. Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add "Next Wave/Models/CalendarEventContent.swift" "Next WaveTests/CalendarEventContentTests.swift" NextWave.xcodeproj/project.pbxproj
git commit -m "feat: add CalendarEventContent value type for wave calendar events"
```

---

## Task 2: `CalendarEventEditView` (native editor wrapper)

This view is UI/EventKit glue and is not unit-tested (consistent with the existing `MessageComposeView` in the codebase, which also has no tests).

**Files:**
- Create: `Next Wave/Views/CalendarEventEditView.swift`

- [ ] **Step 1: Write the implementation**

Create `Next Wave/Views/CalendarEventEditView.swift`:

```swift
import SwiftUI
import EventKit
import EventKitUI
import CoreLocation

/// Presents iOS's native event editor pre-filled from a `CalendarEventContent`.
/// No upfront permission prompt — EventKit requests write access only on save.
struct CalendarEventEditView: UIViewControllerRepresentable {
    let content: CalendarEventContent
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()

        let event = EKEvent(eventStore: store)
        event.title = content.title
        event.startDate = content.startDate
        event.endDate = content.endDate
        event.notes = content.notes

        if let name = content.locationName, !name.isEmpty {
            event.location = name
            if let lat = content.latitude, let lon = content.longitude {
                let structured = EKStructuredLocation(title: name)
                structured.geoLocation = CLLocation(latitude: lat, longitude: lon)
                event.structuredLocation = structured
            }
        }

        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    class Coordinator: NSObject, EKEventEditViewDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true)
            isPresented = false
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Add the file to the `Next Wave` target, then build:
```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | xcpretty || true
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Next Wave/Views/CalendarEventEditView.swift" NextWave.xcodeproj/project.pbxproj
git commit -m "feat: add CalendarEventEditView wrapping EKEventEditViewController"
```

---

## Task 3: Info.plist permission string

**Files:**
- Modify: `Next Wave/Info.plist`

- [ ] **Step 1: Add the write-only calendar usage description**

In `Next Wave/Info.plist`, add the following key/value pair inside the top-level `<dict>` (e.g. directly after the `CFBundleURLTypes` array closes):

```xml
	<key>NSCalendarsWriteOnlyAccessUsageDescription</key>
	<string>Next Wave adds your selected wave to your calendar so you can plan your session.</string>
```

- [ ] **Step 2: Verify the plist is still valid**

Run:
```bash
plutil -lint "Next Wave/Info.plist"
```
Expected: `Next Wave/Info.plist: OK`

- [ ] **Step 3: Commit**

```bash
git add "Next Wave/Info.plist"
git commit -m "feat: add calendar write-only usage description"
```

---

## Task 4: Wire the "Calendar" tile into `CustomShareSheet`

**Files:**
- Modify: `Next Wave/Views/DepartureRowView.swift` (struct `CustomShareSheet`, starts at line 476)

- [ ] **Step 1: Add the editor presentation state**

In `CustomShareSheet`, next to `@State private var showMessageComposer = false` (around line 481), add:

```swift
    @State private var showCalendarEditor = false
```

- [ ] **Step 2: Add the "Calendar" tile to the tile row**

In `CustomShareSheet.body`, the tile row is the `HStack(spacing: 0)` containing the WhatsApp / Messages / Mail `ShareTileButton`s. After the Mail tile's `.frame(maxWidth: .infinity)` and before the `HStack`'s closing brace, add a fourth tile:

```swift
                // Calendar
                ShareTileButton(
                    icon: "calendar",
                    iconColor: .white,
                    backgroundColor: .red,
                    title: "Calendar",
                    action: {
                        showCalendarEditor = true
                    }
                )
                .frame(maxWidth: .infinity)
```

- [ ] **Step 3: Grow the sheet height for four tiles**

In `CustomShareSheet.body`, change the existing detent:

```swift
        .presentationDetents([.height(220)])
```
to:
```swift
        .presentationDetents([.height(240)])
```

- [ ] **Step 4: Present the calendar editor**

Immediately after the existing `.sheet(isPresented: $showMessageComposer) { ... }` modifier in `CustomShareSheet.body`, add:

```swift
        .sheet(isPresented: $showCalendarEditor) {
            CalendarEventEditView(content: makeCalendarContent(), isPresented: $showCalendarEditor)
                .ignoresSafeArea()
                .onDisappear {
                    isPresented = false
                }
        }
```

- [ ] **Step 5: Add the content-builder method**

Inside `CustomShareSheet` (e.g. directly above the existing `private func generateShareText(forMail:)`), add a method that resolves all values — reusing the struct's existing `getWaterTemperatureForWave(lake:)` and `getWetsuitThickness(for:airTemp:)` helpers — and applies the ship-name gating rule (Zürichsee + within next 7 days + known name):

```swift
    private func isWithinNext7Days(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sevenDaysFromNow = calendar.date(byAdding: .day, value: 7, to: today)!
        let dateDay = calendar.startOfDay(for: date)
        return dateDay >= today && dateDay < sevenDaysFromNow
    }

    private func makeCalendarContent() -> CalendarEventContent {
        let selectedStation = lakeStationsViewModel.selectedStation
        let stationName = selectedStation?.name
        let coordinates = selectedStation?.coordinates

        // Ship name: only Zürichsee, within the next 7 days, and known.
        var shipName: String? = nil
        if wave.isZurichsee, isWithinNext7Days(wave.time),
           let name = wave.shipName, name != "Unknown" {
            shipName = name
        }

        // Water temperature via the lake forecast (reuses existing helper).
        var waterTemp: Double? = nil
        if let selected = selectedStation,
           let lake = lakeStationsViewModel.lakes.first(where: { lake in
               lake.stations.contains(where: { $0.name == selected.name })
           }) {
            waterTemp = getWaterTemperatureForWave(lake: lake)
        }

        // Wetsuit thickness (reuses existing helper).
        var wetsuit: String? = nil
        if let waterTemp = waterTemp, let weather = wave.weather {
            wetsuit = getWetsuitThickness(for: waterTemp, airTemp: weather.feelsLike)
        }

        return CalendarEventContent.make(
            waveTime: wave.time,
            stationName: stationName,
            destinationName: wave.neighborStopName,
            latitude: coordinates?.latitude,
            longitude: coordinates?.longitude,
            shipName: shipName,
            airTemperature: wave.weather?.temperature,
            waterTemperature: waterTemp,
            windKnots: wave.weather?.windSpeedKnots,
            windDirection: wave.weather?.windDirectionText,
            wetsuitThickness: wetsuit
        )
    }
```

- [ ] **Step 6: Build and verify it compiles**

Run:
```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | xcpretty || true
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Manual smoke test (simulator)**

Launch the app, open a station with upcoming waves, tap the share button (`square.and.arrow.up`) on a future wave, then tap the **Calendar** tile.
Expected: the native iOS event editor slides up pre-filled with the title `🌊 Wave – … → …`, a 1-hour duration, the station as location, and the notes block. Tapping **Add** prompts for calendar access (first time only) and saves; **Cancel** dismisses with nothing written. Either way the share sheet closes.

- [ ] **Step 8: Commit**

```bash
git add "Next Wave/Views/DepartureRowView.swift"
git commit -m "feat: add Add to Calendar tile to wave share sheet"
```

---

## Self-Review Notes

- **Spec coverage:** entry-point tile (Task 4), `EKEventEditViewController` mechanism (Task 2), title/duration/location-with-GPS/ship/weather-wetsuit/attribution notes (Tasks 1 & 4), permission string (Task 3), edge handling — missing coordinates (Task 2 guard), unknown ship/no weather (Task 1 omits lines), cancel (Task 2 delegate). All covered.
- **1-hour duration** (per the approved change) is enforced in `CalendarEventContent.make` and asserted in `eventLastsOneHour`.
- **No alarm** — no `EKAlarm` is ever added; the user can add one manually in the native editor.
- **Type consistency:** `CalendarEventContent.make(...)` signature is identical across Task 1 (definition + tests) and Task 4 (call site). `isPresented` binding name is consistent across Tasks 2 and 4.
