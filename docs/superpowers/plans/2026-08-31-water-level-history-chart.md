# Water Level History Chart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a 40-day water level history chart plus key figures (current, min/max, delta vs. yesterday) above "Best Surf Sessions" in the spot analytics view, built by persisting the water level reading the app already fetches daily.

**Architecture:** A new Supabase table (`lake_water_levels`) stores one row per lake per day. `LakeStationsViewModel` — right after its existing daily water-level fetch — upserts today's reading through a new `WaterLevelHistoryAPI` actor. `WaveAnalyticsViewModel` reads the last 40 days for the spot's lake through the same actor and publishes it; a new `WaterLevelSectionView` (Swift Charts line chart + key-figure tiles, driven by a pure `WaterLevelStats` calculator) renders it above the existing Best Surf Sessions content in `WaveAnalyticsView`.

**Tech Stack:** SwiftUI, Swift Charts, Supabase (Postgres + RLS + pg_cron), swift-testing.

**Spec:** `docs/superpowers/specs/2026-08-31-water-level-history-chart-design.md`

## Global Constraints

- No water-level forecast: BAFU/hydrodaten publishes no lake-level forecast, and the Alplakes/Eawag API has no water-level product at all (checked against its full endpoint list). This feature is **history only**.
- The 40-day history is built forward from the app's own daily fetch, not backfilled — it starts thin and fills in over ~40 days.
- Server-side retention: 60 days (40-day UI window + buffer), enforced by a daily `pg_cron` cleanup.
- `lake_water_levels` RLS: public read; insert/update requires an authenticated session (the app already signs in anonymously via `SupabaseManager.ensureSession()`). Same trust level as `verified_sessions` — client-writable, not tamper-proof, accepted per spec.
- New Swift files under `Next Wave/...` and tests under `Next WaveTests/` are auto-included (Xcode 16 file-system-synchronized groups) — no `project.pbxproj` edits needed.
- Build/test: `xcodebuild test -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"…"` (or ⌘U in Xcode). Module name for `@testable import` is `Next_Wave`.
- Migrations: `supabase/migrations/YYYYMMDD_<name>.sql`; apply with `supabase db push` (self-hosted Supabase — applied manually by a human, not CI).

---

## File Structure

**Create**
- `supabase/migrations/20260831_lake_water_levels.sql` — table + RLS + retention cron.
- `Next Wave/API/WaterLevelHistoryAPI.swift` — `WaterLevelPoint`, `recordLevel`, `getHistory`.
- `Next Wave/Models/WaterLevelStats.swift` — pure current/min/max/delta calculator.
- `Next Wave/Views/WaterLevelSectionView.swift` — chart + key-figure tiles.
- Tests: `Next WaveTests/LakeWaterLevelParsingTests.swift`, `Next WaveTests/WaterLevelStatsTests.swift`.

**Modify**
- `Next Wave/Models/Lake.swift` — extract `Lake.parseLevelMeters(from:)`, reuse it in `calculateWaterLevelDifference`.
- `Next Wave/ViewModels/LakeStationsViewModel.swift` — persist today's reading after the existing water-level fetch.
- `Next Wave/ViewModels/WaveAnalyticsViewModel.swift` — `waterLevelHistory` published state + `loadWaterLevelHistory(lake:)`.
- `Next Wave/Views/WaveAnalyticsView.swift` — new `lakeName` param; `WaterLevelSectionView` above Best Surf Sessions.
- `Next Wave/Views/DeparturesListView.swift` — resolve the selected station's lake name; pass it down; trigger the history load.
- `Next Wave/Localizable.xcstrings` — new keys (de/fr/it).

---

### Task 1: Supabase migration (table + RLS + retention)

**Files:**
- Create: `supabase/migrations/20260831_lake_water_levels.sql`

**Interfaces:**
- Produces: table `public.lake_water_levels(id, lake_name, date, level_m, recorded_at)`, unique on `(lake_name, date)`.

- [ ] **Step 1: Write the migration**

```sql
create table if not exists public.lake_water_levels (
  id          bigint generated always as identity primary key,
  lake_name   text not null,
  date        date not null,
  level_m     numeric(7,3) not null,
  recorded_at timestamptz not null default now(),
  unique (lake_name, date)
);

alter table public.lake_water_levels enable row level security;

-- Public read (same as the existing current-level badge elsewhere in the app)
drop policy if exists "lake_water_levels_select_public" on public.lake_water_levels;
create policy "lake_water_levels_select_public"
  on public.lake_water_levels for select
  using (true);

-- Any signed-in client (incl. anonymous) may write — no per-user ownership,
-- same trust level the app already uses for verified_sessions.
drop policy if exists "lake_water_levels_insert_authenticated" on public.lake_water_levels;
create policy "lake_water_levels_insert_authenticated"
  on public.lake_water_levels for insert
  to authenticated
  with check (true);

drop policy if exists "lake_water_levels_update_authenticated" on public.lake_water_levels;
create policy "lake_water_levels_update_authenticated"
  on public.lake_water_levels for update
  to authenticated
  using (true)
  with check (true);

-- Retention: keep a buffer beyond the 40-day chart window
create extension if not exists pg_cron;
select cron.schedule(
  'lake_water_levels_cleanup',
  '0 3 * * *',
  $$delete from public.lake_water_levels where date < current_date - interval '60 days'$$
);
```

- [ ] **Step 2: Apply**

Run: `supabase db push` (or SQL editor). Expected: no errors (idempotent).

- [ ] **Step 3: Verify with a rollback transaction**

```sql
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001"}', true);

insert into public.lake_water_levels (lake_name, date, level_m) values
  ('Zürichsee', current_date - 2, 405.10),
  ('Zürichsee', current_date - 1, 405.20),
  ('Zürichsee', current_date, 405.05);

-- Same-day upsert overwrites, doesn't duplicate
insert into public.lake_water_levels (lake_name, date, level_m)
values ('Zürichsee', current_date, 405.08)
on conflict (lake_name, date) do update set level_m = excluded.level_m;

select lake_name, date, level_m from public.lake_water_levels
where lake_name = 'Zürichsee' order by date;

rollback;
```
Expected: 3 rows (not 4), the `current_date` row showing `level_m = 405.08`.

- [ ] **Step 4: Commit**

```bash
git add "supabase/migrations/20260831_lake_water_levels.sql"
git commit -m "feat(db): lake_water_levels table + retention cron"
```

---

### Task 2: Lake water level parsing helper

**Files:**
- Modify: `Next Wave/Models/Lake.swift:97-135`
- Test: `Next WaveTests/LakeWaterLevelParsingTests.swift`

**Interfaces:**
- Produces: `Lake.parseLevelMeters(from: String) -> Double?`, used by Task 5's write path and internally by `calculateWaterLevelDifference`.

- [ ] **Step 1: Write the failing test**

`Next WaveTests/LakeWaterLevelParsingTests.swift`:
```swift
import Testing
@testable import Next_Wave

struct LakeWaterLevelParsingTests {
    @Test func parsesValueWithUnit() {
        #expect(Lake.parseLevelMeters(from: "405.96 m.ü.M.") == 405.96)
    }

    @Test func returnsNilForEmptyString() {
        #expect(Lake.parseLevelMeters(from: "") == nil)
    }

    @Test func returnsNilForNonNumericPrefix() {
        #expect(Lake.parseLevelMeters(from: "n/a m.ü.M.") == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Next WaveTests/LakeWaterLevelParsingTests"`
Expected: FAIL to build — `Lake.parseLevelMeters` doesn't exist yet.

- [ ] **Step 3: Implement the helper and reuse it**

In `Next Wave/Models/Lake.swift`, add (after the `Lake.Station` `==`/`hash` extension, before `calculateWaterLevelDifference`):
```swift
extension Lake {
    /// Extracts the numeric value from a level string like "405.96 m.ü.M.".
    static func parseLevelMeters(from text: String) -> Double? {
        text.components(separatedBy: " ").first.flatMap(Double.init)
    }
}
```

Then in `calculateWaterLevelDifference`, replace:
```swift
    // Extract numeric value from string like "405.96 m.ü.M."
    let components = currentLevel.components(separatedBy: " ")
    guard let levelString = components.first,
          let current = Double(levelString) else { return nil }
```
with:
```swift
    guard let current = Lake.parseLevelMeters(from: currentLevel) else { return nil }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Next WaveTests/LakeWaterLevelParsingTests"`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add "Next Wave/Models/Lake.swift" "Next WaveTests/LakeWaterLevelParsingTests.swift"
git commit -m "refactor: extract Lake.parseLevelMeters, reuse in waterLevelDifference"
```

---

### Task 3: WaterLevelHistoryAPI

**Files:**
- Create: `Next Wave/API/WaterLevelHistoryAPI.swift`

**Interfaces:**
- Consumes: `SupabaseManager.shared` (`ensureSession() async throws -> UUID`, `client`), table `lake_water_levels` (Task 1).
- Produces: `struct WaterLevelHistoryAPI.WaterLevelPoint { let date: Date; let levelM: Double }` (also `init(date:levelM:)` for tests/previews); `actor WaterLevelHistoryAPI` with `recordLevel(lake:levelMeters:date:) async throws` and `getHistory(lake:days:) async throws -> [WaterLevelPoint]`.

- [ ] **Step 1: Implement WaterLevelHistoryAPI**

`Next Wave/API/WaterLevelHistoryAPI.swift`:
```swift
import Foundation
import Supabase

actor WaterLevelHistoryAPI {
    static let shared = WaterLevelHistoryAPI()
    private init() {}

    struct WaterLevelPoint: Decodable, Equatable {
        let date: Date
        let levelM: Double

        enum CodingKeys: String, CodingKey {
            case date
            case levelM = "level_m"
        }

        init(date: Date, levelM: Double) {
            self.date = date
            self.levelM = levelM
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let dateString = try container.decode(String.self, forKey: .date)
            guard let parsedDate = WaterLevelHistoryAPI.dateOnlyFormatter.date(from: dateString) else {
                throw DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "Invalid date: \(dateString)")
            }
            self.date = parsedDate
            self.levelM = try container.decode(Double.self, forKey: .levelM)
        }
    }

    private struct LevelRow: Encodable {
        let lake_name: String
        let date: String
        let level_m: Double
    }

    // A Postgres `date` column round-trips as a bare "yyyy-MM-dd" string over
    // PostgREST, not a full timestamp — decode/encode it ourselves rather
    // than relying on the Supabase client's default (timestamp-shaped) date
    // decoding strategy.
    static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func recordLevel(lake: String, levelMeters: Double, date: Date = Date()) async throws {
        _ = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        let row = LevelRow(lake_name: lake, date: Self.dateOnlyFormatter.string(from: date), level_m: levelMeters)
        try await client.from("lake_water_levels")
            .upsert(row, onConflict: "lake_name,date")
            .execute()
    }

    func getHistory(lake: String, days: Int = 40) async throws -> [WaterLevelPoint] {
        _ = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        let since = Calendar(identifier: .gregorian).date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let rows: [WaterLevelPoint] = try await client.from("lake_water_levels")
            .select("date,level_m")
            .eq("lake_name", value: lake)
            .gte("date", value: Self.dateOnlyFormatter.string(from: since))
            .order("date", ascending: true)
            .execute()
            .value
        return rows
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Next Wave/API/WaterLevelHistoryAPI.swift"
git commit -m "feat: WaterLevelHistoryAPI (record + read 40-day history)"
```

---

### Task 4: WaterLevelStats (pure calculator)

**Files:**
- Create: `Next Wave/Models/WaterLevelStats.swift`
- Test: `Next WaveTests/WaterLevelStatsTests.swift`

**Interfaces:**
- Consumes: `WaterLevelHistoryAPI.WaterLevelPoint` (Task 3).
- Produces: `struct WaterLevelStats { let current: Double?; let min: Double?; let max: Double?; let deltaSinceYesterday: Double? }`, `init(history: [WaterLevelHistoryAPI.WaterLevelPoint])`. Used by Task 7's `WaterLevelSectionView`.

- [ ] **Step 1: Write the failing tests**

`Next WaveTests/WaterLevelStatsTests.swift`:
```swift
import Testing
import Foundation
@testable import Next_Wave

struct WaterLevelStatsTests {
    private func pt(_ daysAgo: Int, _ level: Double) -> WaterLevelHistoryAPI.WaterLevelPoint {
        let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: -daysAgo, to: Date())!
        return WaterLevelHistoryAPI.WaterLevelPoint(date: date, levelM: level)
    }

    @Test func emptyHistoryYieldsNils() {
        let stats = WaterLevelStats(history: [])
        #expect(stats.current == nil)
        #expect(stats.min == nil)
        #expect(stats.max == nil)
        #expect(stats.deltaSinceYesterday == nil)
    }

    @Test func singlePointHasNoDelta() {
        let stats = WaterLevelStats(history: [pt(0, 405.5)])
        #expect(stats.current == 405.5)
        #expect(stats.min == 405.5)
        #expect(stats.max == 405.5)
        #expect(stats.deltaSinceYesterday == nil)
    }

    @Test func computesCurrentMinMaxAndDelta() {
        let history = [pt(2, 405.0), pt(1, 405.5), pt(0, 405.2)]
        let stats = WaterLevelStats(history: history)
        #expect(stats.current == 405.2)
        #expect(stats.min == 405.0)
        #expect(stats.max == 405.5)
        #expect(abs(stats.deltaSinceYesterday! - (-0.3)) < 0.0001)
    }

    @Test func unsortedInputIsSortedInternally() {
        let history = [pt(0, 405.2), pt(2, 405.0), pt(1, 405.5)]
        let stats = WaterLevelStats(history: history)
        #expect(stats.current == 405.2)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Next WaveTests/WaterLevelStatsTests"`
Expected: FAIL to build — `WaterLevelStats` doesn't exist yet.

- [ ] **Step 3: Implement WaterLevelStats**

`Next Wave/Models/WaterLevelStats.swift`:
```swift
import Foundation

struct WaterLevelStats: Equatable {
    let current: Double?
    let min: Double?
    let max: Double?
    let deltaSinceYesterday: Double?

    init(history: [WaterLevelHistoryAPI.WaterLevelPoint]) {
        let sorted = history.sorted { $0.date < $1.date }
        current = sorted.last?.levelM
        min = history.map(\.levelM).min()
        max = history.map(\.levelM).max()
        if sorted.count >= 2 {
            deltaSinceYesterday = sorted[sorted.count - 1].levelM - sorted[sorted.count - 2].levelM
        } else {
            deltaSinceYesterday = nil
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Next WaveTests/WaterLevelStatsTests"`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add "Next Wave/Models/WaterLevelStats.swift" "Next WaveTests/WaterLevelStatsTests.swift"
git commit -m "feat: WaterLevelStats pure current/min/max/delta calculator"
```

---

### Task 5: Persist today's reading (write path)

**Files:**
- Modify: `Next Wave/ViewModels/LakeStationsViewModel.swift:152-162` (loop), plus a new private helper near it.

**Interfaces:**
- Consumes: `Lake.parseLevelMeters(from:)` (Task 2), `WaterLevelHistoryAPI.shared.recordLevel(lake:levelMeters:date:)` (Task 3), the class's existing `cacheFormatter` (already `"yyyy-MM-dd"`, `Next Wave/ViewModels/LakeStationsViewModel.swift:36-40`).
- Produces: no new public API — this task only adds a side effect to the existing `loadWaterTemperatures()` flow.

- [ ] **Step 1: Record the parsed level inside the existing fetch loop**

In `Next Wave/ViewModels/LakeStationsViewModel.swift`, inside `loadWaterTemperatures()`, change:
```swift
                if let level = waterLevels.first(where: { $0.name.lowercased() == lakeName.lowercased() }) {
                    meteoNewsData[lakeName] = level
                    
                    var updatedLake = lakes[i]
                    updatedLake.waterLevel = level.waterLevel
                    lakes[i] = updatedLake
                }
```
to:
```swift
                if let level = waterLevels.first(where: { $0.name.lowercased() == lakeName.lowercased() }) {
                    meteoNewsData[lakeName] = level
                    
                    var updatedLake = lakes[i]
                    updatedLake.waterLevel = level.waterLevel
                    lakes[i] = updatedLake
                    
                    if let waterLevelString = level.waterLevel,
                       let levelMeters = Lake.parseLevelMeters(from: waterLevelString) {
                        recordWaterLevelIfNeeded(lake: lakeName, levelMeters: levelMeters)
                    }
                }
```

- [ ] **Step 2: Add the write-once-per-day helper**

Add this private method to `LakeStationsViewModel` (e.g. right after `loadWaterTemperatures()`):
```swift
    /// Persists today's water level reading once per lake per day. The DB
    /// upsert (Task 1) is correct even without this check — this just skips
    /// the redundant network call on later same-day foreground refreshes.
    private func recordWaterLevelIfNeeded(lake: String, levelMeters: Double) {
        let key = "waterLevelRecorded_\(lake)"
        let today = cacheFormatter.string(from: Date())
        guard UserDefaults.standard.string(forKey: key) != today else { return }
        Task {
            do {
                try await WaterLevelHistoryAPI.shared.recordLevel(lake: lake, levelMeters: levelMeters)
                UserDefaults.standard.set(today, forKey: key)
            } catch {
                print("⚠️ [WaterLevelHistory] Failed to record level for \(lake): \(error)")
            }
        }
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild build -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual verification**

Run the app in the simulator (any lake with a real water level), then in the Supabase SQL editor:
```sql
select * from public.lake_water_levels where date = current_date order by lake_name;
```
Expected: a row for at least one lake, dated today, with a plausible `level_m`.

- [ ] **Step 5: Commit**

```bash
git add "Next Wave/ViewModels/LakeStationsViewModel.swift"
git commit -m "feat: persist daily water level reading per lake"
```

---

### Task 6: Load 40-day history (read path)

**Files:**
- Modify: `Next Wave/ViewModels/WaveAnalyticsViewModel.swift`

**Interfaces:**
- Consumes: `WaterLevelHistoryAPI.shared.getHistory(lake:days:)` (Task 3).
- Produces: `@Published var waterLevelHistory: [WaterLevelHistoryAPI.WaterLevelPoint]`, `func loadWaterLevelHistory(lake: String)`. Used by Task 8.

- [ ] **Step 1: Add published state + loader**

In `Next Wave/ViewModels/WaveAnalyticsViewModel.swift`, add after the existing `@Published var spotAnalytics` declaration:
```swift
    @Published var waterLevelHistory: [WaterLevelHistoryAPI.WaterLevelPoint] = []
    private var waterLevelTask: Task<Void, Never>?

    func loadWaterLevelHistory(lake: String) {
        guard !lake.isEmpty else {
            waterLevelHistory = []
            return
        }
        waterLevelTask?.cancel()
        waterLevelTask = Task { [weak self] in
            do {
                let history = try await WaterLevelHistoryAPI.shared.getHistory(lake: lake, days: 40)
                if Task.isCancelled { return }
                await MainActor.run { self?.waterLevelHistory = history }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run { self?.waterLevelHistory = [] }
            }
        }
    }
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Next Wave/ViewModels/WaveAnalyticsViewModel.swift"
git commit -m "feat: load 40-day water level history in WaveAnalyticsViewModel"
```

---

### Task 7: WaterLevelSectionView (UI)

**Files:**
- Create: `Next Wave/Views/WaterLevelSectionView.swift`

**Interfaces:**
- Consumes: `WaterLevelHistoryAPI.WaterLevelPoint` (Task 3), `WaterLevelStats` (Task 4).
- Produces: `struct WaterLevelSectionView: View` with `let history: [WaterLevelHistoryAPI.WaterLevelPoint]`. Used by Task 8.

- [ ] **Step 1: Implement the view**

`Next Wave/Views/WaterLevelSectionView.swift`:
```swift
import SwiftUI
import Charts

struct WaterLevelSectionView: View {
    let history: [WaterLevelHistoryAPI.WaterLevelPoint]

    private var stats: WaterLevelStats { WaterLevelStats(history: history) }

    var body: some View {
        Group {
            if !history.isEmpty {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Water Level")
                .font(.title2)

            Chart(history, id: \.date) { point in
                LineMark(x: .value("Date", point.date), y: .value("Level", point.levelM))
                    .foregroundStyle(Color.accentColor)
                AreaMark(x: .value("Date", point.date), y: .value("Level", point.levelM))
                    .foregroundStyle(Color.accentColor.opacity(0.15))
            }
            .frame(height: 120)

            if history.count < 7 {
                Text("Not enough data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                statTile(title: "Current", value: stats.current)
                statTile(title: "Min", value: stats.min)
                statTile(title: "Max", value: stats.max)
                deltaTile
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
    }

    private func statTile(title: LocalizedStringKey, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value.map { String(format: "%.2f", $0) } ?? "–")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var deltaTile: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Since yesterday")
                .font(.caption)
                .foregroundColor(.secondary)
            if let delta = stats.deltaSinceYesterday {
                HStack(spacing: 2) {
                    Image(systemName: delta >= 0 ? "water.waves.and.arrow.trianglehead.up" : "water.waves.and.arrow.trianglehead.down")
                        .font(.caption)
                    Text(String(format: "%+.0f cm", delta * 100))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            } else {
                Text("–")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    WaterLevelSectionView(history: (0..<40).map { offset in
        WaterLevelHistoryAPI.WaterLevelPoint(
            date: Calendar.current.date(byAdding: .day, value: -offset, to: Date())!,
            levelM: 405.0 + Double.random(in: -0.3...0.3)
        )
    })
    .padding()
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Check the preview**

Open `WaterLevelSectionView.swift` in Xcode, enable the canvas (⌥⌘Return). Expected: a card with a line/area chart over ~40 days and four tiles (Current, Min, Max, Since yesterday) with plausible values.

- [ ] **Step 4: Commit**

```bash
git add "Next Wave/Views/WaterLevelSectionView.swift"
git commit -m "feat: WaterLevelSectionView (chart + key figures)"
```

---

### Task 8: Wire into the spot analytics screen

**Files:**
- Modify: `Next Wave/Views/WaveAnalyticsView.swift:3-20`
- Modify: `Next Wave/Views/DeparturesListView.swift:4-32,180-195`

**Interfaces:**
- Consumes: `WaterLevelSectionView` (Task 7), `WaveAnalyticsViewModel.waterLevelHistory` / `.loadWaterLevelHistory(lake:)` (Task 6).
- Produces: `WaveAnalyticsView` gains `let lakeName: String`; `DeparturesListView` gains a private `lakeName: String` computed property.

- [ ] **Step 1: Add `lakeName` to WaveAnalyticsView and render the section**

In `Next Wave/Views/WaveAnalyticsView.swift`, add the property next to the existing ones:
```swift
struct WaveAnalyticsView: View {
    @ObservedObject var viewModel: WaveAnalyticsViewModel
    let spotId: String
    let spotName: String
    let lakeName: String
    let allWaves: [WaveEvent]
```
Then insert the section as the first thing in the `VStack`, before `if let analytics = ...`:
```swift
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                WaterLevelSectionView(history: viewModel.waterLevelHistory)
                
                if let analytics = viewModel.spotAnalytics.first(where: { $0.spotId == spotId }) {
```

- [ ] **Step 2: Resolve the lake for the selected station in DeparturesListView**

In `Next Wave/Views/DeparturesListView.swift`, add next to the existing `isCurrentDay` computed property:
```swift
    private var lakeName: String {
        guard let selectedStation else { return "" }
        return viewModel.lakes.first(where: { lake in
            lake.stations.contains(where: { $0.name == selectedStation.name })
        })?.name ?? ""
    }
```

- [ ] **Step 3: Pass it into WaveAnalyticsView and trigger the load**

Update the `WaveAnalyticsView` call:
```swift
                WaveAnalyticsView(
                    viewModel: analyticsViewModel,
                    spotId: selectedStation?.id ?? "",
                    spotName: selectedStation?.name ?? "",
                    lakeName: lakeName,
                    allWaves: scheduleViewModel.nextWaves
                )
```
Update the toolbar button that opens analytics:
```swift
                        Button(action: {
                            showingAnalytics.toggle()
                            if showingAnalytics {
                                analyticsViewModel.analyzeWaves(
                                    scheduleViewModel.nextWaves,
                                    for: selectedStation?.id ?? "",
                                    spotName: selectedStation?.name ?? ""
                                )
                                analyticsViewModel.loadWaterLevelHistory(lake: lakeName)
                            }
                        }) {
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild build -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Manual run**

Run the app in the simulator, pick a station with departures, tap the chart-bar icon to open analytics. Expected: the Water Level section appears above "Best Surf Sessions" (or above the "No Good Surf Sessions" card), with real data if that lake already has rows in `lake_water_levels` (from Task 5's manual check), or nothing rendered if it doesn't yet.

- [ ] **Step 6: Commit**

```bash
git add "Next Wave/Views/WaveAnalyticsView.swift" "Next Wave/Views/DeparturesListView.swift"
git commit -m "feat: show water level history above Best Surf Sessions"
```

---

### Task 9: Localization

**Files:**
- Modify: `Next Wave/Localizable.xcstrings`

**Interfaces:**
- Consumes: string keys used by Task 7's `WaterLevelSectionView` (`"Water Level"`, `"Current"`, `"Min"`, `"Max"`, `"Since yesterday"`, `"Not enough data yet"`).
- Produces: nothing new consumed elsewhere — this is the last task.

- [ ] **Step 1: Add the new keys**

Run this script (adjust the path if run from elsewhere) to add the keys idempotently, matching the catalog's existing schema (checked against current entries like `"Best Surf Sessions"`):

```bash
python3 - <<'PYEOF'
import json

path = "Next Wave/Localizable.xcstrings"
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

new_strings = {
    "Water Level": {"de": "Wasserstand", "fr": "Niveau d'eau", "it": "Livello dell'acqua"},
    "Current": {"de": "Aktuell", "fr": "Actuel", "it": "Attuale"},
    "Min": {"de": "Min", "fr": "Min", "it": "Min"},
    "Max": {"de": "Max", "fr": "Max", "it": "Max"},
    "Since yesterday": {"de": "seit gestern", "fr": "depuis hier", "it": "da ieri"},
    "Not enough data yet": {
        "de": "Noch nicht genug Daten",
        "fr": "Pas encore assez de données",
        "it": "Dati non ancora sufficienti",
    },
}

added = []
for key, translations in new_strings.items():
    if key in data["strings"]:
        continue
    data["strings"][key] = {
        "localizations": {
            lang: {"stringUnit": {"state": "translated", "value": value}}
            for lang, value in translations.items()
        }
    }
    added.append(key)

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2, separators=(",", " : "))
    f.write("\n")

print(f"Added {len(added)} keys: {added}")
PYEOF
```
Expected output: `Added 6 keys: [...]` (or `Added 0 keys: []` if run twice — idempotent).

- [ ] **Step 2: Validate the catalog**

```bash
python3 -c "import json; json.load(open('Next Wave/Localizable.xcstrings')); print('valid JSON')"
```
Expected: `valid JSON`.

- [ ] **Step 3: Build to verify Xcode accepts the catalog**

Run: `xcodebuild build -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Next Wave/Localizable.xcstrings"
git commit -m "i18n: localize water level section strings (de/fr/it)"
```
