# Wave Check-ins Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let foilers check in to a specific wave (ferry departure) so everyone sees a live, cross-device counter of who plans to go — with optional names.

**Architecture:** iOS app talks directly to the existing Supabase instance via `supabase-swift` using Anonymous Auth + Row-Level Security. A single `wave_checkins` table is keyed by a deterministic, client-computed `waveId`. Counts read via a batched RPC and stay live via Supabase Realtime. Local identity (name + anonymous flag) lives in the App Group UserDefaults and is editable in Settings.

**Tech Stack:** SwiftUI, Swift Concurrency (actors), Swift Testing (`import Testing`), `supabase-swift` SPM package, Supabase (Postgres + Realtime + pg_cron).

**Design spec:** `docs/superpowers/specs/2026-06-16-wave-checkins-design.md`

---

## Reference: established patterns (read before starting)

- **Models:** `Next Wave/Models/WaveEvent.swift`, `Next Wave/Models/Lake.swift` (`Lake.Station` has `uic_ref: String?` and `id`).
- **Wave row UI:** `Next Wave/Views/DepartureRowView.swift` (renders a `WaveEvent`).
- **List + station context:** `Next Wave/Views/DeparturesListView.swift`, `Next Wave/ViewModels/ScheduleViewModel.swift` (`selectedStation: Lake.Station?`, `@Published nextWaves: [WaveEvent]`).
- **Settings:** `Next Wave/Views/SettingsView.swift` + `Next Wave/ViewModels/AppSettings.swift` (`@Published` + `didSet` → `UserDefaults`; `UserDefaults.bool(forKey:defaultValue:)` extension at top of AppSettings.swift).
- **API actor pattern:** `Next Wave/API/VesselAPI.swift` (singleton `static let shared`, `private init()`).
- **App Group:** `group.com.federi.Next-Wave`, accessor `Next Wave/Shared/SharedDataManager.swift`.
- **Tests:** `Next WaveTests/` use Swift Testing (`import Testing`, `@Test`, `#expect`, `@testable import Next_Wave`).
- **Test command (used throughout):**
  ```bash
  xcodebuild test -project NextWave.xcodeproj -scheme NextWave \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:"Next WaveTests/<TestType>"
  ```
  If `iPhone 16` is unavailable, run `xcrun simctl list devices available` and substitute an available simulator name.

**waveId formula (locked):**
```
waveId = "{station.uic_ref ?? station.name}_{ISO8601(wave.time, UTC)}_{wave.routeNumber}"
```
`uic_ref` is the stable official station ID; fall back to name only when absent. ISO8601 uses a fixed UTC formatter so two devices in different time zones produce identical strings.

---

## Task 1: Backend — Supabase schema, RLS, RPC, cleanup

No app code. Apply this SQL to the existing Supabase project (the one serving promo tiles) via the SQL editor or Supabase MCP. Enable Anonymous Sign-ins in Auth settings first.

**Files:**
- Create: `supabase/migrations/20260616_wave_checkins.sql` (kept in repo for reference)

- [ ] **Step 1: Enable anonymous auth**

In Supabase dashboard → Authentication → Providers → enable **Anonymous sign-ins**. (No SQL.)

- [ ] **Step 2: Write the migration SQL file**

Create `supabase/migrations/20260616_wave_checkins.sql`:

```sql
-- Wave check-ins: one row per (wave, device-identity)
create table if not exists public.wave_checkins (
  id           uuid primary key default gen_random_uuid(),
  wave_id      text not null,
  user_id      uuid not null references auth.users (id) on delete cascade,
  display_name text,
  departure_at timestamptz not null,
  created_at   timestamptz not null default now(),
  unique (wave_id, user_id)
);

create index if not exists wave_checkins_wave_id_idx on public.wave_checkins (wave_id);
create index if not exists wave_checkins_departure_at_idx on public.wave_checkins (departure_at);

alter table public.wave_checkins enable row level security;

-- Public read (count + names are public)
create policy "wave_checkins_select_public"
  on public.wave_checkins for select
  using (true);

-- Insert only your own rows
create policy "wave_checkins_insert_own"
  on public.wave_checkins for insert
  with check (auth.uid() = user_id);

-- Update only your own rows
create policy "wave_checkins_update_own"
  on public.wave_checkins for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Delete only your own rows
create policy "wave_checkins_delete_own"
  on public.wave_checkins for delete
  using (auth.uid() = user_id);

-- Batched counter read: count + non-anonymous names per wave
create or replace function public.wave_checkin_counts(wave_ids text[])
returns table (wave_id text, count bigint, names text[])
language sql
stable
security definer
set search_path = public
as $$
  select
    c.wave_id,
    count(*)::bigint as count,
    array_remove(array_agg(c.display_name) filter (where c.display_name is not null), null) as names
  from public.wave_checkins c
  where c.wave_id = any(wave_ids)
    and c.departure_at >= now()
  group by c.wave_id;
$$;

grant execute on function public.wave_checkin_counts(text[]) to anon, authenticated;

-- Daily cleanup of past check-ins
create extension if not exists pg_cron;
select cron.schedule(
  'wave_checkins_cleanup',
  '0 3 * * *',
  $$delete from public.wave_checkins where departure_at < now()$$
);
```

- [ ] **Step 3: Apply the migration**

Run the SQL in the Supabase SQL editor (or via the Supabase MCP `apply_migration`). Verify with:
```sql
select * from public.wave_checkin_counts(array['nonexistent']::text[]);
```
Expected: 0 rows, no error.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260616_wave_checkins.sql
git commit -m "feat(backend): wave_checkins table, RLS, counts RPC, cleanup job"
```

---

## Task 2: Add supabase-swift dependency

Manual Xcode step (SPM cannot be added via test).

**Files:**
- Modify: `NextWave.xcodeproj/project.pbxproj` (Xcode edits this)

- [ ] **Step 1: Add the package**

In Xcode: File → Add Package Dependencies → `https://github.com/supabase/supabase-swift.git` → Dependency Rule "Up to Next Major" from `2.0.0` → add the **Supabase** product to the **Next Wave** (NextWave) app target only (not widget/watch).

- [ ] **Step 2: Verify it builds**

Run:
```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add NextWave.xcodeproj
git commit -m "build: add supabase-swift package dependency"
```

---

## Task 3: Deterministic waveId generation (TDD)

A pure, testable function — the heart of correct counting.

**Files:**
- Create: `Next Wave/Models/WaveCheckin.swift`
- Test: `Next WaveTests/WaveCheckinIdTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Next WaveTests/WaveCheckinIdTests.swift`:

```swift
import Testing
import Foundation
@testable import Next_Wave

struct WaveCheckinIdTests {

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    @Test func usesUicRefWhenPresent() {
        let id = WaveCheckin.makeWaveId(
            stationUicRef: "8503671", stationName: "Thalwil",
            departure: date(2026, 6, 18, 14, 32), routeNumber: "ZSG-12")
        #expect(id == "8503671_2026-06-18T14:32:00Z_ZSG-12")
    }

    @Test func fallsBackToNameWhenNoUicRef() {
        let id = WaveCheckin.makeWaveId(
            stationUicRef: nil, stationName: "Thalwil",
            departure: date(2026, 6, 18, 14, 32), routeNumber: "ZSG-12")
        #expect(id == "Thalwil_2026-06-18T14:32:00Z_ZSG-12")
    }

    @Test func isDeterministicAcrossTimeZones() {
        let utc = WaveCheckin.makeWaveId(
            stationUicRef: "8503671", stationName: "Thalwil",
            departure: date(2026, 6, 18, 14, 32), routeNumber: "ZSG-12")
        // Same instant — must yield identical id regardless of device TZ.
        #expect(utc == "8503671_2026-06-18T14:32:00Z_ZSG-12")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:"Next WaveTests/WaveCheckinIdTests"
```
Expected: FAIL — `WaveCheckin` not found.

- [ ] **Step 3: Write minimal implementation**

Create `Next Wave/Models/WaveCheckin.swift`:

```swift
import Foundation

struct WaveCheckin: Identifiable, Equatable {
    let id: UUID
    let waveId: String
    let userId: UUID
    let displayName: String?      // nil == anonymous
    let departureAt: Date

    /// Fixed UTC ISO-8601 formatter so all devices agree on the string.
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.formatOptions = [.withInternetDateTime] // yyyy-MM-dd'T'HH:mm:ssZ
        return f
    }()

    /// Deterministic, cross-device wave identity.
    static func makeWaveId(stationUicRef: String?,
                           stationName: String,
                           departure: Date,
                           routeNumber: String) -> String {
        let station = stationUicRef ?? stationName
        let iso = isoFormatter.string(from: departure)
        return "\(station)_\(iso)_\(routeNumber)"
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild test -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:"Next WaveTests/WaveCheckinIdTests"
```
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add "Next Wave/Models/WaveCheckin.swift" "Next WaveTests/WaveCheckinIdTests.swift"
git commit -m "feat: deterministic waveId generation"
```

---

## Task 4: Local check-in identity (TDD)

Name + anonymous flag, persisted in the App Group, editable later.

**Files:**
- Create: `Next Wave/Models/CheckinIdentity.swift`
- Modify: `Next Wave/Shared/SharedDataManager.swift`
- Test: `Next WaveTests/CheckinIdentityTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Next WaveTests/CheckinIdentityTests.swift`:

```swift
import Testing
import Foundation
@testable import Next_Wave

struct CheckinIdentityTests {

    @Test func anonymousReturnsNilDisplayName() {
        let identity = CheckinIdentity(name: "Pat", isAnonymous: true)
        #expect(identity.displayName == nil)
    }

    @Test func namedReturnsTrimmedName() {
        let identity = CheckinIdentity(name: "  Pat  ", isAnonymous: false)
        #expect(identity.displayName == "Pat")
    }

    @Test func emptyNameIsTreatedAsAnonymous() {
        let identity = CheckinIdentity(name: "   ", isAnonymous: false)
        #expect(identity.displayName == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:"Next WaveTests/CheckinIdentityTests"
```
Expected: FAIL — `CheckinIdentity` not found.

- [ ] **Step 3: Write minimal implementation**

Create `Next Wave/Models/CheckinIdentity.swift`:

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodebuild test -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:"Next WaveTests/CheckinIdentityTests"
```
Expected: PASS (3 tests).

- [ ] **Step 5: Add persistence to SharedDataManager**

In `Next Wave/Shared/SharedDataManager.swift`, add inside the class (follow the existing `userDefaults?` + JSON pattern):

```swift
private let checkinIdentityKey = "checkinIdentity"

func saveCheckinIdentity(_ identity: CheckinIdentity) {
    if let encoded = try? JSONEncoder().encode(identity) {
        userDefaults?.set(encoded, forKey: checkinIdentityKey)
        userDefaults?.synchronize()
    }
}

func loadCheckinIdentity() -> CheckinIdentity? {
    guard let data = userDefaults?.data(forKey: checkinIdentityKey),
          let identity = try? JSONDecoder().decode(CheckinIdentity.self, from: data) else {
        return nil
    }
    return identity
}
```

- [ ] **Step 6: Run tests again (still pass) and commit**

```bash
xcodebuild test -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:"Next WaveTests/CheckinIdentityTests"
git add "Next Wave/Models/CheckinIdentity.swift" \
        "Next Wave/Shared/SharedDataManager.swift" \
        "Next WaveTests/CheckinIdentityTests.swift"
git commit -m "feat: local check-in identity with App Group persistence"
```

---

## Task 5: Supabase client + anonymous auth bootstrap

**Files:**
- Create: `Next Wave/API/SupabaseConfig.swift`
- Create: `Next Wave/API/SupabaseManager.swift`

- [ ] **Step 1: Add the config**

Create `Next Wave/API/SupabaseConfig.swift` (anon key is public-by-design; protected by RLS):

```swift
import Foundation

enum SupabaseConfig {
    // Self-hosted Supabase (same instance as promo tiles).
    static let url = URL(string: "https://nextwaveapp.db.lakeshorestudios.ch")!
    // Public anon key — safe to ship; writes are constrained by RLS.
    static let anonKey = "<PASTE_ANON_KEY>" // TODO(once): from Supabase project API settings
}
```

> The `<PASTE_ANON_KEY>` is the only manual value — copy it from Supabase → Project Settings → API → `anon` `public` key. This is not a secret.

- [ ] **Step 2: Add the manager with anonymous bootstrap**

Create `Next Wave/API/SupabaseManager.swift`:

```swift
import Foundation
import Supabase

actor SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }

    /// Ensures an anonymous session exists. Returns the current user id.
    @discardableResult
    func ensureSession() async throws -> UUID {
        if let session = try? await client.auth.session {
            return session.user.id
        }
        let session = try await client.auth.signInAnonymously()
        return session.user.id
    }
}
```

- [ ] **Step 3: Bootstrap on app launch**

In the app's startup path (where `VesselAPI.shared.preloadData()` is called — find it in the `App`/`AppDelegate` or root view `.task`), add a fire-and-forget bootstrap:

```swift
Task { try? await SupabaseManager.shared.ensureSession() }
```

- [ ] **Step 4: Verify it builds**

```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add "Next Wave/API/SupabaseConfig.swift" "Next Wave/API/SupabaseManager.swift" <startup file>
git commit -m "feat: Supabase client + anonymous auth bootstrap"
```

---

## Task 6: CheckinAPI actor (write + batched count read)

**Files:**
- Create: `Next Wave/API/CheckinAPI.swift`

- [ ] **Step 1: Define the count DTO and API**

Create `Next Wave/API/CheckinAPI.swift`:

```swift
import Foundation
import Supabase

struct WaveCheckinCount: Decodable, Equatable {
    let waveId: String
    let count: Int
    let names: [String]

    enum CodingKeys: String, CodingKey {
        case waveId = "wave_id"
        case count
        case names
    }
}

actor CheckinAPI {
    static let shared = CheckinAPI()
    private init() {}

    private struct CheckinRow: Encodable {
        let wave_id: String
        let user_id: String
        let display_name: String?
        let departure_at: String
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Check in (upsert so re-tapping with a new name updates the row).
    func checkIn(waveId: String, displayName: String?, departureAt: Date) async throws {
        let userId = try await SupabaseManager.shared.ensureSession()
        let client = await SupabaseManager.shared.client
        let row = CheckinRow(
            wave_id: waveId,
            user_id: userId.uuidString.lowercased(),
            display_name: displayName,
            departure_at: Self.iso.string(from: departureAt)
        )
        try await client
            .from("wave_checkins")
            .upsert(row, onConflict: "wave_id,user_id")
            .execute()
    }

    /// Remove my check-in from a wave.
    func checkOut(waveId: String) async throws {
        let userId = try await SupabaseManager.shared.ensureSession()
        let client = await SupabaseManager.shared.client
        try await client
            .from("wave_checkins")
            .delete()
            .eq("wave_id", value: waveId)
            .eq("user_id", value: userId.uuidString.lowercased())
            .execute()
    }

    /// Batched counts for the currently visible waves.
    func counts(for waveIds: [String]) async throws -> [WaveCheckinCount] {
        guard !waveIds.isEmpty else { return [] }
        let client = await SupabaseManager.shared.client
        let response: [WaveCheckinCount] = try await client
            .rpc("wave_checkin_counts", params: ["wave_ids": waveIds])
            .execute()
            .value
        return response
    }

    /// Wave ids the current user is checked into (to render "I'm in" state).
    func myCheckins(waveIds: [String]) async throws -> Set<String> {
        guard !waveIds.isEmpty else { return [] }
        let userId = try await SupabaseManager.shared.ensureSession()
        let client = await SupabaseManager.shared.client
        struct Row: Decodable { let wave_id: String }
        let rows: [Row] = try await client
            .from("wave_checkins")
            .select("wave_id")
            .eq("user_id", value: userId.uuidString.lowercased())
            .in("wave_id", values: waveIds)
            .execute()
            .value
        return Set(rows.map(\.wave_id))
    }
}
```

- [ ] **Step 2: Verify it builds**

```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: BUILD SUCCEEDED. (If the `supabase-swift` `rpc`/`in`/`upsert` signatures differ in the resolved version, adjust to the SDK's current API — confirm against the installed package's headers.)

- [ ] **Step 3: Commit**

```bash
git add "Next Wave/API/CheckinAPI.swift"
git commit -m "feat: CheckinAPI for check-in/out and batched counts"
```

---

## Task 7: CheckinStore — observable state + Realtime

**Files:**
- Create: `Next Wave/ViewModels/CheckinStore.swift`

- [ ] **Step 1: Implement the store**

Create `Next Wave/ViewModels/CheckinStore.swift`:

```swift
import Foundation
import SwiftUI
import Supabase

@MainActor
final class CheckinStore: ObservableObject {
    static let shared = CheckinStore()

    @Published private(set) var counts: [String: WaveCheckinCount] = [:]
    @Published private(set) var mine: Set<String> = []

    private var realtimeChannel: RealtimeChannelV2?
    private var subscribedWaveIds: [String] = []

    private init() {}

    /// Load counts + my-state for the visible waves and (re)subscribe to Realtime.
    func refresh(waveIds: [String]) async {
        subscribedWaveIds = waveIds
        do {
            async let counts = CheckinAPI.shared.counts(for: waveIds)
            async let mine = CheckinAPI.shared.myCheckins(waveIds: waveIds)
            let (c, m) = try await (counts, mine)
            var dict: [String: WaveCheckinCount] = [:]
            for item in c { dict[item.waveId] = item }
            self.counts = dict
            self.mine = m
        } catch {
            print("⚠️ Checkin refresh failed: \(error)")
        }
        await subscribeRealtime()
    }

    private func subscribeRealtime() async {
        if let channel = realtimeChannel {
            await channel.unsubscribe()
        }
        let client = await SupabaseManager.shared.client
        let channel = client.channel("wave_checkins_live")
        let changes = channel.postgresChange(AnyAction.self,
                                              schema: "public",
                                              table: "wave_checkins")
        await channel.subscribe()
        realtimeChannel = channel
        Task { [weak self] in
            for await _ in changes {
                guard let self else { return }
                // A change occurred — re-pull the counts for the visible window.
                let ids = await self.subscribedWaveIds
                do {
                    let c = try await CheckinAPI.shared.counts(for: ids)
                    var dict: [String: WaveCheckinCount] = [:]
                    for item in c { dict[item.waveId] = item }
                    await MainActor.run { self.counts = dict }
                } catch { }
            }
        }
    }

    func toggle(waveId: String, departureAt: Date, identity: CheckinIdentity) async {
        do {
            if mine.contains(waveId) {
                try await CheckinAPI.shared.checkOut(waveId: waveId)
                mine.remove(waveId)
            } else {
                try await CheckinAPI.shared.checkIn(
                    waveId: waveId,
                    displayName: identity.displayName,
                    departureAt: departureAt)
                mine.insert(waveId)
            }
            // Optimistic local count bump; Realtime will reconcile.
            await refresh(waveIds: subscribedWaveIds)
        } catch {
            print("⚠️ Checkin toggle failed: \(error)")
        }
    }
}
```

- [ ] **Step 2: Verify it builds**

```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: BUILD SUCCEEDED. (Adjust `postgresChange`/`channel` calls to the installed Realtime API if the resolved SDK differs.)

- [ ] **Step 3: Commit**

```bash
git add "Next Wave/ViewModels/CheckinStore.swift"
git commit -m "feat: CheckinStore with Realtime-backed live counts"
```

---

## Task 8: Settings — identity editing + feature toggle

**Files:**
- Modify: `Next Wave/ViewModels/AppSettings.swift`
- Modify: `Next Wave/Views/SettingsView.swift`
- Create: `Next Wave/Views/CheckinIdentitySheet.swift`

- [ ] **Step 1: Add settings to AppSettings**

In `Next Wave/ViewModels/AppSettings.swift`, add `@Published` properties (mirror the existing `didSet` → UserDefaults pattern) and initialize them in `init()`:

```swift
@Published var enableWaveCheckIn: Bool {
    didSet { UserDefaults.standard.set(enableWaveCheckIn, forKey: "enableWaveCheckIn") }
}
@Published var checkinName: String {
    didSet { UserDefaults.standard.set(checkinName, forKey: "checkinName") }
}
@Published var checkinAnonymous: Bool {
    didSet { UserDefaults.standard.set(checkinAnonymous, forKey: "checkinAnonymous") }
}

var checkinIdentity: CheckinIdentity {
    CheckinIdentity(name: checkinName, isAnonymous: checkinAnonymous)
}
var hasCheckinIdentity: Bool {
    checkinAnonymous || !checkinName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}
```

In `init()` add:
```swift
self.enableWaveCheckIn = UserDefaults.standard.bool(forKey: "enableWaveCheckIn", defaultValue: true)
self.checkinName = UserDefaults.standard.string(forKey: "checkinName") ?? ""
self.checkinAnonymous = UserDefaults.standard.bool(forKey: "checkinAnonymous", defaultValue: false)
```

- [ ] **Step 2: Build the identity sheet**

Create `Next Wave/Views/CheckinIdentitySheet.swift`:

```swift
import SwiftUI

struct CheckinIdentitySheet: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss
    /// Called when the user confirms; nil if they cancel.
    var onSave: (() -> Void)?

    @State private var name: String = ""
    @State private var anonymous: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Your name", text: $name)
                        .disabled(anonymous)
                    Toggle("Join anonymously", isOn: $anonymous)
                } footer: {
                    Text("Your name is visible to other foilers on this wave. Choose anonymous to be counted without a name. See our privacy policy for details.")
                }
            }
            .navigationTitle("How should others see you?")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appSettings.checkinName = name
                        appSettings.checkinAnonymous = anonymous
                        onSave?()
                        dismiss()
                    }
                    .disabled(!anonymous && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                name = appSettings.checkinName.isEmpty
                    ? (UIDevice.current.name) : appSettings.checkinName
                anonymous = appSettings.checkinAnonymous
            }
        }
    }
}
```

- [ ] **Step 3: Add a Settings entry**

In `Next Wave/Views/SettingsView.swift`, add (following the existing `Toggle`/row style) a toggle for `appSettings.enableWaveCheckIn` and a row that presents `CheckinIdentitySheet` to edit name/anonymous:

```swift
Toggle(isOn: $appSettings.enableWaveCheckIn) {
    HStack {
        Image(systemName: "person.2.fill")
        VStack(alignment: .leading, spacing: 2) {
            Text("Wave Check-In")
            Text("Show who plans to ride each wave")
                .font(.system(size: 14)).foregroundColor(.gray)
        }
    }
}
.padding(.vertical, 12)

if appSettings.enableWaveCheckIn {
    Button { showCheckinIdentity = true } label: {
        HStack {
            Image(systemName: "person.crop.circle")
            Text(appSettings.checkinAnonymous ? "Check-in name: Anonymous"
                 : "Check-in name: \(appSettings.checkinName.isEmpty ? "Not set" : appSettings.checkinName)")
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray)
        }
    }
    .padding(.vertical, 12)
}
```

Add `@State private var showCheckinIdentity = false` to the view and a `.sheet(isPresented: $showCheckinIdentity) { CheckinIdentitySheet().environmentObject(appSettings) }`.

- [ ] **Step 4: Verify it builds**

```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add "Next Wave/ViewModels/AppSettings.swift" "Next Wave/Views/SettingsView.swift" \
        "Next Wave/Views/CheckinIdentitySheet.swift"
git commit -m "feat: check-in settings (toggle + editable identity)"
```

---

## Task 9: Check-in button + live counter in the wave row

**Files:**
- Modify: `Next Wave/Views/DepartureRowView.swift`
- Create: `Next Wave/Views/WaveCheckinBadge.swift`
- Modify: `Next Wave/Views/DeparturesListView.swift`

- [ ] **Step 1: Build the badge view**

Create `Next Wave/Views/WaveCheckinBadge.swift`:

```swift
import SwiftUI

struct WaveCheckinBadge: View {
    let count: Int
    let names: [String]
    let isMine: Bool
    let onTap: () -> Void

    @State private var showNames = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: isMine ? "person.2.fill" : "person.2")
                if count > 0 { Text("\(count)") }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(isMine ? .blue : (count > 0 ? .primary : .gray))
        }
        .buttonStyle(.plain)
        .onLongPressGesture { if count > 0 { showNames = true } }
        .popover(isPresented: $showNames) {
            let anon = max(0, count - names.count)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(names, id: \.self) { Text($0) }
                if anon > 0 { Text("+\(anon) anonymous").foregroundColor(.gray) }
            }
            .padding()
            .presentationCompactAdaptation(.popover)
        }
    }
}
```

- [ ] **Step 2: Wire the badge into the row**

In `Next Wave/Views/DepartureRowView.swift`, in "Row 1" (the `HStack` with the bell + share button), add the badge before the share `Button`. The view needs the store and the wave's `waveId`/`departureAt`. Add at the top of the struct:

```swift
@EnvironmentObject var checkinStore: CheckinStore
```

Compute the wave id using the selected station from `scheduleViewModel`:

```swift
private var waveId: String? {
    guard let station = scheduleViewModel.selectedStation else { return nil }
    return WaveCheckin.makeWaveId(
        stationUicRef: station.uic_ref,
        stationName: station.name,
        departure: wave.time,
        routeNumber: wave.routeNumber)
}
```

Then in Row 1, before the share button, when enabled and not past:

```swift
if appSettings.enableWaveCheckIn, !isPast, let waveId {
    let info = checkinStore.counts[waveId]
    WaveCheckinBadge(
        count: info?.count ?? 0,
        names: info?.names ?? [],
        isMine: checkinStore.mine.contains(waveId),
        onTap: { handleCheckinTap(waveId: waveId) }
    )
}
```

Add the tap handler to the struct (presents the name sheet on first use, else toggles):

```swift
@State private var showIdentitySheet = false
@State private var pendingWaveId: String?

private func handleCheckinTap(waveId: String) {
    if appSettings.hasCheckinIdentity {
        Task {
            await checkinStore.toggle(waveId: waveId,
                                      departureAt: wave.time,
                                      identity: appSettings.checkinIdentity)
        }
    } else {
        pendingWaveId = waveId
        showIdentitySheet = true
    }
}
```

Add the sheet modifier to the row body:

```swift
.sheet(isPresented: $showIdentitySheet) {
    CheckinIdentitySheet(onSave: {
        if let id = pendingWaveId {
            Task {
                await checkinStore.toggle(waveId: id,
                                          departureAt: wave.time,
                                          identity: appSettings.checkinIdentity)
            }
        }
    })
    .environmentObject(appSettings)
}
```

- [ ] **Step 3: Drive the store from the list**

In `Next Wave/Views/DeparturesListView.swift`, inject and refresh the store. Add `@StateObject private var checkinStore = CheckinStore.shared` (or `@EnvironmentObject` if registered app-wide; prefer the shared singleton via `.environmentObject(CheckinStore.shared)` at the app root). After the list loads/`filteredWaves` changes, compute the visible wave ids and refresh:

```swift
.onChange(of: scheduleViewModel.nextWaves) { _ in
    guard appSettings.enableWaveCheckIn,
          let station = scheduleViewModel.selectedStation else { return }
    let ids = scheduleViewModel.nextWaves
        .filter { $0.time >= Date() }
        .map { WaveCheckin.makeWaveId(stationUicRef: station.uic_ref,
                                      stationName: station.name,
                                      departure: $0.time,
                                      routeNumber: $0.routeNumber) }
    Task { await checkinStore.refresh(waveIds: ids) }
}
```

Ensure `DepartureRowView` receives the store via `.environmentObject(checkinStore)` from the list (or from the app root). Register `CheckinStore.shared` as an `.environmentObject` at the same place `AppSettings` is injected.

- [ ] **Step 4: Verify it builds**

```bash
xcodebuild build -project NextWave.xcodeproj -scheme NextWave \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Manual smoke test**

Run the app in the simulator. On a future wave, tap the check-in icon → name sheet appears on first use → save → counter shows `1` and icon fills. Tap again → counter returns to `0`. On a second simulator/device the count should reflect the other's check-in (Realtime).

- [ ] **Step 6: Commit**

```bash
git add "Next Wave/Views/DepartureRowView.swift" "Next Wave/Views/WaveCheckinBadge.swift" \
        "Next Wave/Views/DeparturesListView.swift"
git commit -m "feat: check-in button + live counter in wave row"
```

---

## Task 10: Privacy policy update

**Files:**
- Modify: the app's privacy policy source (find under `docs/` or the website repo; if the policy is hosted externally, note the change for the web repo).

- [ ] **Step 1: Add a check-in clause**

Add a paragraph stating that when a user checks in to a wave, their chosen display name (if not anonymous) and an anonymous device identifier are shared with other users and stored until the departure passes, then deleted. No email/account is collected.

- [ ] **Step 2: Commit**

```bash
git add <privacy policy file>
git commit -m "docs: privacy policy note for wave check-ins"
```

---

## Self-Review notes

- **Spec coverage:** shared counter (Tasks 1,6,7), name optional/anonymous (Tasks 4,8,9), local+editable identity (Tasks 4,8), 7-day horizon (counts RPC filters `departure_at >= now()`; list refreshes all visible future waves), Supabase + anon auth + RLS (Tasks 1,5,6), one-per-device unique constraint (Task 1), Realtime (Task 7), auto-cleanup pg_cron (Task 1), privacy note (Tasks 8 footer, 10), deterministic waveId (Task 3). All covered.
- **SDK caveat:** `supabase-swift` API surface (`upsert`/`rpc`/`channel`/`postgresChange`) can shift between major versions. Each Supabase-touching task ends in a build step; reconcile signatures against the resolved package version when a build fails — the data model and SQL are the source of truth.
- **Manual values:** anon key (Task 5) and the simulator name in the test command are the only environment-specific inputs.
