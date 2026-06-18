# GPX Verified Rides & Badges — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import a Foilmotion GPX via iOS Share, auto-detect verified ferry-wave rides + session metrics, store them in Supabase, and award verified badges.

**Architecture:** GPX arrives via a registered document type → parsed client-side (`GPXParser`) → pure metrics (`SessionMetrics`) → matched against the day's ferry schedule (`WaveMatcher`) → uploaded to two Supabase tables → verified badges computed from a metrics RPC and shown in a "Verified" section.

**Tech Stack:** SwiftUI, `XMLParser`, Supabase (Postgres + RLS), existing `TransportAPI`, swift-testing.

## Global Constraints

- Foil/motion speed threshold: `FOIL_SPEED_THRESHOLD = 3.0` m/s (~11 km/h).
- Wave match: station radius `250` m; candidate-station radius `400` m; time window `[T − 120 s, T + 360 s]`; point must have speed ≥ threshold.
- `wave_id` format must equal the check-in format: `"{stationId}_{departureISO}_{routeNumber}"` (UTC ISO-8601, via `WaveCheckin.makeWaveId`).
- Verified data is client-computed and not tamper-proof (accepted).
- Distance metric for badges = **longest continuous ride distance** (one go), not total.
- Badge thresholds: verified waves 1/10/25; longest ride (m) 50/100/250/500/1000/5000/10000; top speed (km/h) 15/20/25/30/35.
- Note: longest-ride badge `250` (m) and station match radius `250` (m) are unrelated values that happen to coincide.
- New Swift files in `Next Wave/...` and tests in `Next WaveTests/` are auto-included (file-system-synchronized groups).
- Build/test: `xcodebuild test -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"…"` (or ⌘U in Xcode).
- Migrations: `supabase/migrations/YYYYMMDD_<name>.sql`; apply with `supabase db push`.

## File Structure

**Create**
- `Next Wave/Models/GPXSession.swift` — `GPXPoint`, `GPXMetadata`, `GPXSession`.
- `Next Wave/Services/GPXParser.swift` — XML → `GPXSession`.
- `Next Wave/Services/GeoMath.swift` — haversine distance.
- `Next Wave/Services/SessionMetrics.swift` — pure metrics + constants.
- `Next Wave/Services/WaveMatcher.swift` — `CandidateDeparture`, `VerifiedRide`, matching.
- `Next Wave/Models/VerifiedStats.swift` — `VerifiedStats` (Decodable).
- `Next Wave/API/VerifiedRidesAPI.swift` — upload + stats + sessionExists.
- `Next Wave/Models/VerifiedBadge.swift` — `VerifiedBadge`, `VerifiedBadgeCatalog`, `VerifiedBadgeEvaluator`, `EvaluatedVerifiedBadge`.
- `Next Wave/ViewModels/GPXImportCoordinator.swift` — orchestration + `GPXImportSummary`.
- `Next Wave/Views/GPXImportSummaryView.swift` — post-import sheet.
- `supabase/migrations/20260618_verified_rides.sql` — tables + RLS + RPC.
- Tests: `Next WaveTests/GPXParserTests.swift`, `SessionMetricsTests.swift`, `WaveMatcherTests.swift`, `VerifiedBadgeTests.swift`.

**Modify**
- `Next Wave/Info.plist` — GPX document type.
- `Next Wave/NextWaveApp.swift:252` — handle `.gpx` file URLs; present summary sheet.
- `Next Wave/Views/BadgeMedalView.swift` — image/ring init + verified shield overlay.
- `Next Wave/ViewModels/StatsStore.swift` — load verified stats + badges.
- `Next Wave/Views/StatsView.swift` — "Verified" section.

---

### Task 1: GPX models + parser

**Files:**
- Create: `Next Wave/Models/GPXSession.swift`
- Create: `Next Wave/Services/GPXParser.swift`
- Test: `Next WaveTests/GPXParserTests.swift`

**Interfaces:**
- Produces: `GPXPoint`, `GPXMetadata`, `GPXSession`; `GPXParser.parse(data:) throws -> GPXSession`.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import Next_Wave

struct GPXParserTests {
    private let sample = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="FoilMotion" xmlns="http://www.topografix.com/GPX/1/1">
      <metadata><name>Test</name><desc>1 run</desc><time>2025-09-18T15:48:52Z</time></metadata>
      <trk><trkseg>
        <trkpt lat="47.3110" lon="8.5571"><ele>406.6</ele><time>2025-09-18T15:49:09Z</time>
          <extensions><TrackPointExtension><distance>0.00</distance><speed>0.05</speed></TrackPointExtension></extensions>
        </trkpt>
        <trkpt lat="47.3112" lon="8.5573"><ele>406.7</ele><time>2025-09-18T15:49:10Z</time>
          <extensions><TrackPointExtension><distance>5.00</distance><speed>4.20</speed></TrackPointExtension></extensions>
        </trkpt>
      </trkseg></trk>
    </gpx>
    """

    @Test func parsesPointsAndExtensions() throws {
        let s = try GPXParser.parse(data: Data(sample.utf8))
        #expect(s.points.count == 2)
        #expect(s.metadata.creator == "FoilMotion")
        #expect(abs(s.points[0].lat - 47.3110) < 1e-6)
        #expect(s.points[1].speed == 4.20)
        #expect(s.points[1].cumulativeDistance == 5.00)
    }

    @Test func throwsWhenNoTrackPoints() {
        let empty = "<gpx><trk><trkseg></trkseg></trk></gpx>"
        #expect(throws: GPXParseError.self) { try GPXParser.parse(data: Data(empty.utf8)) }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Next WaveTests/GPXParserTests"`
Expected: FAIL — `GPXParser` / `GPXParseError` undefined.

- [ ] **Step 3: Implement the models**

`Next Wave/Models/GPXSession.swift`:
```swift
import Foundation

struct GPXPoint: Equatable {
    let time: Date
    let lat: Double
    let lon: Double
    let ele: Double?
    let speed: Double?              // m/s (from <speed> if present)
    let cumulativeDistance: Double? // m (from <distance> if present)
}

struct GPXMetadata: Equatable {
    let name: String?
    let desc: String?
    let creator: String?
    let startTime: Date?
}

struct GPXSession: Equatable {
    let metadata: GPXMetadata
    let points: [GPXPoint]
}
```

- [ ] **Step 4: Implement the parser**

`Next Wave/Services/GPXParser.swift`:
```swift
import Foundation

enum GPXParseError: Error, Equatable {
    case noTrackPoints
}

enum GPXParser {
    static func parse(url: URL) throws -> GPXSession {
        try parse(data: Data(contentsOf: url))
    }

    static func parse(data: Data) throws -> GPXSession {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        guard !delegate.points.isEmpty else { throw GPXParseError.noTrackPoints }
        let meta = GPXMetadata(name: delegate.metaName, desc: delegate.metaDesc,
                               creator: delegate.creator, startTime: delegate.metaTime)
        return GPXSession(metadata: meta, points: delegate.points)
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        private static let iso: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()
        private static let isoNoFrac: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f
        }()
        static func date(_ s: String) -> Date? {
            iso.date(from: s) ?? isoNoFrac.date(from: s)
        }

        var creator: String?
        var metaName: String?, metaDesc: String?, metaTime: Date?
        var points: [GPXPoint] = []

        private var inMetadata = false
        private var curLat = 0.0, curLon = 0.0
        private var curEle: Double?, curSpeed: Double?, curDist: Double?, curTime: Date?
        private var text = ""

        func parser(_ p: XMLParser, didStartElement el: String, namespaceURI: String?,
                    qualifiedName: String?, attributes a: [String: String]) {
            text = ""
            switch el {
            case "gpx": creator = a["creator"]
            case "metadata": inMetadata = true
            case "trkpt":
                curLat = Double(a["lat"] ?? "") ?? 0
                curLon = Double(a["lon"] ?? "") ?? 0
                curEle = nil; curSpeed = nil; curDist = nil; curTime = nil
            default: break
            }
        }

        func parser(_ p: XMLParser, foundCharacters s: String) { text += s }

        func parser(_ p: XMLParser, didEndElement el: String, namespaceURI: String?, qualifiedName: String?) {
            let v = text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch el {
            case "metadata": inMetadata = false
            case "name" where inMetadata: metaName = v
            case "desc" where inMetadata: metaDesc = v
            case "time" where inMetadata: metaTime = Delegate.date(v)
            case "ele": curEle = Double(v)
            case "speed": curSpeed = Double(v)
            case "distance": curDist = Double(v)
            case "time" where !inMetadata: curTime = Delegate.date(v)
            case "trkpt":
                if let t = curTime {
                    points.append(GPXPoint(time: t, lat: curLat, lon: curLon,
                                           ele: curEle, speed: curSpeed, cumulativeDistance: curDist))
                }
            default: break
            }
        }
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Next WaveTests/GPXParserTests"`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add "Next Wave/Models/GPXSession.swift" "Next Wave/Services/GPXParser.swift" "Next WaveTests/GPXParserTests.swift"
git commit -m "feat: GPX models + parser"
```

---

### Task 2: GeoMath + SessionMetrics

**Files:**
- Create: `Next Wave/Services/GeoMath.swift`
- Create: `Next Wave/Services/SessionMetrics.swift`
- Test: `Next WaveTests/SessionMetricsTests.swift`

**Interfaces:**
- Consumes: `GPXPoint` (Task 1).
- Produces: `GeoMath.distance(lat1:lon1:lat2:lon2:) -> Double` (meters); `FoilConstants.foilSpeedThreshold`; `SessionMetrics` + `SessionMetrics.compute(from:) -> SessionMetrics?`.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import Next_Wave

struct SessionMetricsTests {
    private func pt(_ t: TimeInterval, _ lat: Double, _ lon: Double, _ speed: Double) -> GPXPoint {
        GPXPoint(time: Date(timeIntervalSince1970: t), lat: lat, lon: lon, ele: nil,
                 speed: speed, cumulativeDistance: nil)
    }

    @Test func haversineKnownDistance() {
        // ~111.2 m per 0.001° latitude near the equator/mid-lat.
        let d = GeoMath.distance(lat1: 47.0, lon1: 8.0, lat2: 47.001, lon2: 8.0)
        #expect(abs(d - 111.2) < 2.0)
    }

    @Test func longestRideResetsOnSlowPoint() {
        // Move ~111 m north each step; speeds: fast, fast, SLOW, fast.
        let pts = [
            pt(0, 47.000, 8.0, 5.0),
            pt(1, 47.001, 8.0, 5.0),
            pt(2, 47.002, 8.0, 1.0),   // below threshold → breaks the ride
            pt(3, 47.003, 8.0, 5.0),
        ]
        let m = SessionMetrics.compute(from: pts)!
        #expect(m.maxSpeed == 5.0)
        #expect(m.longestRideDistance > 100 && m.longestRideDistance < 130) // one ~111 m segment
        #expect(m.totalDistance > 320 && m.totalDistance < 340)             // three ~111 m segments
    }

    @Test func tooFewPointsReturnsNil() {
        #expect(SessionMetrics.compute(from: [pt(0, 47, 8, 5)]) == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Next WaveTests/SessionMetricsTests"`
Expected: FAIL — `GeoMath` / `SessionMetrics` undefined.

- [ ] **Step 3: Implement GeoMath**

`Next Wave/Services/GeoMath.swift`:
```swift
import Foundation

enum GeoMath {
    /// Haversine great-circle distance in meters.
    static func distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return r * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
```

- [ ] **Step 4: Implement SessionMetrics**

`Next Wave/Services/SessionMetrics.swift`:
```swift
import Foundation

enum FoilConstants {
    static let foilSpeedThreshold = 3.0   // m/s (~11 km/h)
}

struct SessionMetrics: Equatable {
    let start: Date
    let end: Date
    let duration: TimeInterval
    let movingTime: TimeInterval
    let totalDistance: Double       // meters
    let maxSpeed: Double            // m/s
    let longestRideDistance: Double // meters (longest continuous ride)
    let minLat: Double, maxLat: Double, minLon: Double, maxLon: Double

    /// nil when fewer than 2 points.
    static func compute(from points: [GPXPoint]) -> SessionMetrics? {
        guard points.count >= 2, let first = points.first, let last = points.last else { return nil }

        var total = 0.0
        var maxSpeed = 0.0
        var moving = 0.0
        var currentRide = 0.0
        var longestRide = 0.0
        var minLat = first.lat, maxLat = first.lat, minLon = first.lon, maxLon = first.lon

        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            let seg = GeoMath.distance(lat1: a.lat, lon1: a.lon, lat2: b.lat, lon2: b.lon)
            let dt = b.time.timeIntervalSince(a.time)
            let speed = b.speed ?? (dt > 0 ? seg / dt : 0)

            total += seg
            maxSpeed = max(maxSpeed, speed)
            minLat = min(minLat, b.lat); maxLat = max(maxLat, b.lat)
            minLon = min(minLon, b.lon); maxLon = max(maxLon, b.lon)

            if speed >= FoilConstants.foilSpeedThreshold {
                moving += max(0, dt)
                currentRide += seg
                longestRide = max(longestRide, currentRide)
            } else {
                currentRide = 0
            }
        }

        return SessionMetrics(
            start: first.time, end: last.time,
            duration: last.time.timeIntervalSince(first.time),
            movingTime: moving, totalDistance: total, maxSpeed: maxSpeed,
            longestRideDistance: longestRide,
            minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Next WaveTests/SessionMetricsTests"`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add "Next Wave/Services/GeoMath.swift" "Next Wave/Services/SessionMetrics.swift" "Next WaveTests/SessionMetricsTests.swift"
git commit -m "feat: GeoMath + SessionMetrics"
```

---

### Task 3: WaveMatcher

**Files:**
- Create: `Next Wave/Services/WaveMatcher.swift`
- Test: `Next WaveTests/WaveMatcherTests.swift`

**Interfaces:**
- Consumes: `GPXPoint`, `GeoMath`, `FoilConstants`, `WaveCheckin.makeWaveId`.
- Produces:
  - `CandidateDeparture { stationId, stationName, stationUicRef: String?, stationLat, stationLon, departure: Date, routeNumber }`
  - `VerifiedRide { waveId, stationId, departureAt, rideDistance, rideMaxSpeed }`
  - `WaveMatcher.match(points:departures:) -> [VerifiedRide]`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import Next_Wave

struct WaveMatcherTests {
    private let station = (lat: 47.30, lon: 8.55)
    private func dep(_ t: Date) -> CandidateDeparture {
        CandidateDeparture(stationId: "S_1", stationName: "S", stationUicRef: "1",
                           stationLat: station.lat, stationLon: station.lon,
                           departure: t, routeNumber: "10")
    }
    private func pt(_ t: TimeInterval, _ lat: Double, _ lon: Double, _ speed: Double) -> GPXPoint {
        GPXPoint(time: Date(timeIntervalSince1970: t), lat: lat, lon: lon, ele: nil, speed: speed, cumulativeDistance: nil)
    }

    @Test func matchesNearStationInWindowWhileMoving() {
        let T = Date(timeIntervalSince1970: 1000)
        // Point AT the station, 1 min after departure, moving.
        let pts = [pt(900, 47.30, 8.55, 5.0), pt(1060, 47.30, 8.55, 5.0), pt(2000, 48.0, 9.0, 5.0)]
        let rides = WaveMatcher.match(points: pts, departures: [dep(T)])
        #expect(rides.count == 1)
        #expect(rides[0].stationId == "S_1")
    }

    @Test func rejectsWhenTooSlow() {
        let T = Date(timeIntervalSince1970: 1000)
        let pts = [pt(1060, 47.30, 8.55, 1.0)]   // at station, in window, but below threshold
        #expect(WaveMatcher.match(points: pts, departures: [dep(T)]).isEmpty)
    }

    @Test func rejectsWhenOutsideTimeWindow() {
        let T = Date(timeIntervalSince1970: 1000)
        let pts = [pt(1361, 47.30, 8.55, 5.0)]   // T + 361 s (> +360 s)
        #expect(WaveMatcher.match(points: pts, departures: [dep(T)]).isEmpty)
    }

    @Test func rejectsWhenTooFar() {
        let T = Date(timeIntervalSince1970: 1000)
        let pts = [pt(1060, 47.30, 8.556, 5.0)]   // ~455 m east of station (> 250 m)
        #expect(WaveMatcher.match(points: pts, departures: [dep(T)]).isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Next WaveTests/WaveMatcherTests"`
Expected: FAIL — `WaveMatcher` / `CandidateDeparture` undefined.

- [ ] **Step 3: Implement WaveMatcher**

`Next Wave/Services/WaveMatcher.swift`:
```swift
import Foundation

struct CandidateDeparture: Equatable {
    let stationId: String
    let stationName: String
    let stationUicRef: String?
    let stationLat: Double
    let stationLon: Double
    let departure: Date
    let routeNumber: String
}

struct VerifiedRide: Equatable {
    let waveId: String
    let stationId: String
    let departureAt: Date
    let rideDistance: Double
    let rideMaxSpeed: Double
}

enum WaveMatcher {
    static let matchRadius = 250.0   // meters
    static let windowBefore = 120.0  // seconds
    static let windowAfter = 360.0   // seconds

    static func match(points: [GPXPoint], departures: [CandidateDeparture]) -> [VerifiedRide] {
        var rides: [VerifiedRide] = []
        for dep in departures {
            let t = dep.departure.timeIntervalSince1970
            let inWindow = points.filter {
                let pt = $0.time.timeIntervalSince1970
                return pt >= t - windowBefore && pt <= t + windowAfter
            }
            let qualifying = inWindow.filter { p in
                let speed = p.speed ?? 0
                guard speed >= FoilConstants.foilSpeedThreshold else { return false }
                return GeoMath.distance(lat1: p.lat, lon1: p.lon,
                                        lat2: dep.stationLat, lon2: dep.stationLon) <= matchRadius
            }
            guard !qualifying.isEmpty else { continue }

            // Ride metrics from the in-window segment.
            var dist = 0.0
            for i in 1..<max(inWindow.count, 1) {
                let a = inWindow[i - 1], b = inWindow[i]
                dist += GeoMath.distance(lat1: a.lat, lon1: a.lon, lat2: b.lat, lon2: b.lon)
            }
            let maxSpeed = inWindow.compactMap { $0.speed }.max() ?? 0

            let waveId = WaveCheckin.makeWaveId(stationUicRef: dep.stationUicRef,
                                                stationName: dep.stationName,
                                                departure: dep.departure,
                                                routeNumber: dep.routeNumber)
            rides.append(VerifiedRide(waveId: waveId, stationId: dep.stationId,
                                      departureAt: dep.departure, rideDistance: dist, rideMaxSpeed: maxSpeed))
        }
        return rides
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Next WaveTests/WaveMatcherTests"`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add "Next Wave/Services/WaveMatcher.swift" "Next WaveTests/WaveMatcherTests.swift"
git commit -m "feat: WaveMatcher (proximity + time window + motion)"
```

---

### Task 4: Supabase migration (tables + RLS + stats RPC)

**Files:**
- Create: `supabase/migrations/20260618_verified_rides.sql`

**Interfaces:**
- Produces: tables `verified_sessions`, `verified_rides`; function `user_verified_stats()`.

- [ ] **Step 1: Write the migration**

```sql
-- Verified rides from imported GPX sessions.
create table if not exists public.verified_sessions (
  user_id        uuid not null references auth.users(id) on delete cascade,
  session_key    text not null,
  source         text not null default 'foilmotion',
  start_at       timestamptz not null,
  end_at         timestamptz not null,
  total_distance double precision not null,
  duration       int not null,
  moving_time    int not null,
  max_speed      double precision not null,
  longest_ride   double precision not null,
  recorded_at    timestamptz not null default now(),
  primary key (user_id, session_key)
);

create table if not exists public.verified_rides (
  user_id        uuid not null references auth.users(id) on delete cascade,
  wave_id        text not null,
  station_id     text not null,
  departure_at   timestamptz not null,
  session_key    text not null,
  ride_distance  double precision not null,
  ride_max_speed double precision not null,
  recorded_at    timestamptz not null default now(),
  primary key (user_id, wave_id)
);

alter table public.verified_sessions enable row level security;
alter table public.verified_rides enable row level security;

drop policy if exists "verified_sessions_select_own" on public.verified_sessions;
create policy "verified_sessions_select_own" on public.verified_sessions
  for select using (auth.uid() = user_id);
drop policy if exists "verified_sessions_insert_own" on public.verified_sessions;
create policy "verified_sessions_insert_own" on public.verified_sessions
  for insert with check (auth.uid() = user_id);

drop policy if exists "verified_rides_select_own" on public.verified_rides;
create policy "verified_rides_select_own" on public.verified_rides
  for select using (auth.uid() = user_id);
drop policy if exists "verified_rides_insert_own" on public.verified_rides;
create policy "verified_rides_insert_own" on public.verified_rides
  for insert with check (auth.uid() = user_id);

create or replace function public.user_verified_stats()
returns table (
  verified_waves int, longest_ride_m double precision, max_speed_ms double precision,
  session_count int, total_distance_m double precision
)
language sql stable security definer set search_path = public
as $$
  select
    (select count(*) from public.verified_rides where user_id = auth.uid())::int,
    coalesce((select max(longest_ride) from public.verified_sessions where user_id = auth.uid()), 0),
    coalesce((select max(max_speed)    from public.verified_sessions where user_id = auth.uid()), 0),
    (select count(*) from public.verified_sessions where user_id = auth.uid())::int,
    coalesce((select sum(total_distance) from public.verified_sessions where user_id = auth.uid()), 0);
$$;

grant execute on function public.user_verified_stats() to authenticated;
```

- [ ] **Step 2: Apply the migration**

Run: `supabase db push` (or paste into the Supabase SQL editor).
Expected: no errors (idempotent).

- [ ] **Step 3: Verify with a rollback transaction**

```sql
begin;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001"}', true);
insert into public.verified_sessions (user_id, session_key, start_at, end_at, total_distance, duration, moving_time, max_speed, longest_ride)
values ('00000000-0000-0000-0000-000000000001','k1', now()-interval '1h', now(), 1400, 1000, 800, 9.5, 230);
insert into public.verified_rides (user_id, wave_id, station_id, departure_at, session_key, ride_distance, ride_max_speed)
values ('00000000-0000-0000-0000-000000000001','w1','S1', now(), 'k1', 120, 8.0);
select * from public.user_verified_stats();
rollback;
```
Expected: `verified_waves=1, longest_ride_m=230, max_speed_ms=9.5, session_count=1, total_distance_m=1400`.

- [ ] **Step 4: Commit**

```bash
git add "supabase/migrations/20260618_verified_rides.sql"
git commit -m "feat(db): verified_sessions + verified_rides tables and user_verified_stats RPC"
```

---

### Task 5: Verified models + VerifiedRidesAPI

**Files:**
- Create: `Next Wave/Models/VerifiedStats.swift`
- Create: `Next Wave/API/VerifiedRidesAPI.swift`

**Interfaces:**
- Consumes: `SessionMetrics`, `VerifiedRide`, `SupabaseManager.shared` (`ensureSession() -> UUID`, `client`).
- Produces: `VerifiedStats` (Decodable, `.empty`); `actor VerifiedRidesAPI` with `upload(metrics:sessionKey:rides:) async throws`, `verifiedStats() async throws -> VerifiedStats`, `sessionExists(key:) async throws -> Bool`.

- [ ] **Step 1: Implement VerifiedStats**

`Next Wave/Models/VerifiedStats.swift`:
```swift
import Foundation

struct VerifiedStats: Decodable, Equatable {
    let verifiedWaves: Int
    let longestRideM: Double
    let maxSpeedMs: Double
    let sessionCount: Int
    let totalDistanceM: Double

    enum CodingKeys: String, CodingKey {
        case verifiedWaves = "verified_waves"
        case longestRideM = "longest_ride_m"
        case maxSpeedMs = "max_speed_ms"
        case sessionCount = "session_count"
        case totalDistanceM = "total_distance_m"
    }

    static let empty = VerifiedStats(verifiedWaves: 0, longestRideM: 0, maxSpeedMs: 0,
                                     sessionCount: 0, totalDistanceM: 0)
}
```

- [ ] **Step 2: Implement VerifiedRidesAPI**

`Next Wave/API/VerifiedRidesAPI.swift`:
```swift
import Foundation
import Supabase

actor VerifiedRidesAPI {
    static let shared = VerifiedRidesAPI()
    private init() {}

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private struct SessionRow: Encodable {
        let user_id: String, session_key: String, source: String
        let start_at: String, end_at: String
        let total_distance: Double, duration: Int, moving_time: Int
        let max_speed: Double, longest_ride: Double
    }
    private struct RideRow: Encodable {
        let user_id: String, wave_id: String, station_id: String
        let departure_at: String, session_key: String
        let ride_distance: Double, ride_max_speed: Double
    }

    func sessionExists(key: String) async throws -> Bool {
        let userId = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        struct Row: Decodable { let session_key: String }
        let rows: [Row] = try await client.from("verified_sessions")
            .select("session_key")
            .eq("user_id", value: userId.uuidString.lowercased())
            .eq("session_key", value: key)
            .limit(1)
            .execute().value
        return !rows.isEmpty
    }

    func upload(metrics: SessionMetrics, sessionKey: String, rides: [VerifiedRide]) async throws {
        let userId = try await SupabaseManager.shared.ensureSession()
        let uid = userId.uuidString.lowercased()
        let client = SupabaseManager.shared.client

        let session = SessionRow(
            user_id: uid, session_key: sessionKey, source: "foilmotion",
            start_at: Self.iso.string(from: metrics.start), end_at: Self.iso.string(from: metrics.end),
            total_distance: metrics.totalDistance, duration: Int(metrics.duration),
            moving_time: Int(metrics.movingTime), max_speed: metrics.maxSpeed,
            longest_ride: metrics.longestRideDistance)
        try await client.from("verified_sessions").upsert(session, onConflict: "user_id,session_key").execute()

        if !rides.isEmpty {
            let rows = rides.map {
                RideRow(user_id: uid, wave_id: $0.waveId, station_id: $0.stationId,
                        departure_at: Self.iso.string(from: $0.departureAt), session_key: sessionKey,
                        ride_distance: $0.rideDistance, ride_max_speed: $0.rideMaxSpeed)
            }
            try await client.from("verified_rides").upsert(rows, onConflict: "user_id,wave_id").execute()
        }
    }

    func verifiedStats() async throws -> VerifiedStats {
        _ = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        let rows: [VerifiedStats] = try await client.rpc("user_verified_stats").execute().value
        return rows.first ?? .empty
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild build -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Next Wave/Models/VerifiedStats.swift" "Next Wave/API/VerifiedRidesAPI.swift"
git commit -m "feat: VerifiedStats model + VerifiedRidesAPI (upload + stats)"
```

---

### Task 6: Verified badges + BadgeMedalView verified support

**Files:**
- Create: `Next Wave/Models/VerifiedBadge.swift`
- Modify: `Next Wave/Views/BadgeMedalView.swift`
- Test: `Next WaveTests/VerifiedBadgeTests.swift`

**Interfaces:**
- Consumes: `VerifiedStats`, `Color(badgeHex:)` pattern.
- Produces: `VerifiedBadge`, `EvaluatedVerifiedBadge`, `VerifiedBadgeCatalog.all`, `VerifiedBadgeEvaluator.evaluate(_:)`; `BadgeMedalView(imageName:ringColor:isEarned:verified:size:)`.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import Next_Wave

struct VerifiedBadgeTests {
    private func stats(waves: Int = 0, longest: Double = 0, speedMs: Double = 0) -> VerifiedStats {
        VerifiedStats(verifiedWaves: waves, longestRideM: longest, maxSpeedMs: speedMs,
                      sessionCount: 0, totalDistanceM: 0)
    }

    @Test func firstVerifiedWaveUnlocksAtOne() {
        let none = VerifiedBadgeEvaluator.evaluate(stats(waves: 0)).first { $0.badge.id == "vwave_1" }!
        let one = VerifiedBadgeEvaluator.evaluate(stats(waves: 1)).first { $0.badge.id == "vwave_1" }!
        #expect(none.isEarned == false)
        #expect(one.isEarned == true)
    }

    @Test func longestRide500m() {
        let e = VerifiedBadgeEvaluator.evaluate(stats(longest: 500)).first { $0.badge.id == "dist_500" }!
        #expect(e.isEarned == true)
    }

    @Test func topSpeedUsesKmh() {
        // 8.4 m/s = 30.24 km/h → earns the 30 badge, not 35.
        let e = VerifiedBadgeEvaluator.evaluate(stats(speedMs: 8.4))
        #expect(e.first { $0.badge.id == "speed_30" }!.isEarned == true)
        #expect(e.first { $0.badge.id == "speed_35" }!.isEarned == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Next WaveTests/VerifiedBadgeTests"`
Expected: FAIL — `VerifiedBadgeEvaluator` undefined.

- [ ] **Step 3: Implement VerifiedBadge**

`Next Wave/Models/VerifiedBadge.swift`:
```swift
import SwiftUI

struct VerifiedBadge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let imageName: String
    let ringColor: Color
    let target: Int
    let metric: (VerifiedStats) -> Int

    func current(_ s: VerifiedStats) -> Int { metric(s) }
    func isEarned(_ s: VerifiedStats) -> Bool { metric(s) >= target }
}

struct EvaluatedVerifiedBadge: Identifiable {
    let badge: VerifiedBadge
    let current: Int
    var id: String { badge.id }
    var isEarned: Bool { current >= badge.target }
    var progressText: String { isEarned ? "Done" : "\(current)/\(badge.target)" }
}

enum VerifiedBadgeCatalog {
    private static let waveColor = Color(verifiedHex: "#00897B")
    private static let distColor = Color(verifiedHex: "#1E88E5")
    private static let speedColor = Color(verifiedHex: "#E53935")

    static let all: [VerifiedBadge] = {
        func wave(_ n: Int) -> VerifiedBadge {
            VerifiedBadge(id: "vwave_\(n)", title: n == 1 ? "Verified Ride" : "\(n) Verified",
                          detail: "\(n) verified ferry wave\(n == 1 ? "" : "s")",
                          imageName: "badge_verified_wave", ringColor: waveColor, target: n) { $0.verifiedWaves }
        }
        func dist(_ m: Int, _ label: String) -> VerifiedBadge {
            VerifiedBadge(id: "dist_\(m)", title: label, detail: "Longest ride \(label)",
                          imageName: "badge_distance", ringColor: distColor, target: m) { Int($0.longestRideM) }
        }
        func speed(_ kmh: Int) -> VerifiedBadge {
            VerifiedBadge(id: "speed_\(kmh)", title: "\(kmh) km/h", detail: "Top speed \(kmh) km/h",
                          imageName: "badge_speed", ringColor: speedColor, target: kmh) { Int($0.maxSpeedMs * 3.6) }
        }
        return [
            wave(1), wave(10), wave(25),
            dist(50, "50 m"), dist(100, "100 m"), dist(250, "250 m"), dist(500, "500 m"),
            dist(1000, "1 km"), dist(5000, "5 km"), dist(10000, "10 km"),
            speed(15), speed(20), speed(25), speed(30), speed(35),
        ]
    }()
}

enum VerifiedBadgeEvaluator {
    static func evaluate(_ stats: VerifiedStats) -> [EvaluatedVerifiedBadge] {
        VerifiedBadgeCatalog.all.map { EvaluatedVerifiedBadge(badge: $0, current: $0.current(stats)) }
    }
}

private extension Color {
    init(verifiedHex hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        guard s.count == 6, Scanner(string: s).scanHexInt64(&v) else { self = .gray; return }
        self.init(red: Double((v & 0xFF0000) >> 16) / 255, green: Double((v & 0x00FF00) >> 8) / 255,
                  blue: Double(v & 0x0000FF) / 255)
    }
}
```

- [ ] **Step 4: Add a verified-capable initializer + shield to BadgeMedalView**

In `Next Wave/Views/BadgeMedalView.swift`, replace the stored `let badge: Badge` / `isEarned` / `size` properties and the `assetName`/`illustration` so the view renders from explicit fields, keeping the existing `init(badge:isEarned:size:)`. Replace the top of the struct (the property block + the `body`'s use of `assetName`/`badge.category.ringColor`) with:

```swift
struct BadgeMedalView: View {
    let imageName: String
    let ringColor: Color
    let isEarned: Bool
    let verified: Bool
    var size: CGFloat = 96

    private static let cream = Color(badgeHex: "#F3E6C9")

    /// Unverified badge (existing call sites).
    init(badge: Badge, isEarned: Bool, size: CGFloat = 96) {
        self.imageName = BadgeMedalView.assetName(for: badge)
        self.ringColor = badge.category.ringColor
        self.isEarned = isEarned
        self.verified = false
        self.size = size
    }

    /// Verified badge.
    init(imageName: String, ringColor: Color, isEarned: Bool, verified: Bool = true, size: CGFloat = 96) {
        self.imageName = imageName
        self.ringColor = ringColor
        self.isEarned = isEarned
        self.verified = verified
        self.size = size
    }

    private static func assetName(for badge: Badge) -> String {
        switch badge.id {
        case "season_spring": return "badge_spring"
        case "season_summer": return "badge_summer"
        case "season_autumn": return "badge_autumn"
        case "season_winter": return "badge_winter"
        case "four_seasons":  return "badge_fourseasons"
        case "lone_wolf":     return "badge_lonewolf"
        default:              return badge.category.imageName
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(ringColor)
            Circle().fill(Self.cream).padding(size * 0.045)
            illustration
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .padding(size * 0.075)
                .grayscale(isEarned ? 0 : 1)
            if !isEarned {
                ZStack {
                    Circle().fill(Color.white.opacity(0.72)).frame(width: size * 0.44, height: size * 0.44)
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.22, weight: .bold))
                        .foregroundColor(Color(white: 0.23))
                }
            }
            if verified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: size * 0.24))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.green).frame(width: size * 0.24, height: size * 0.24))
                    .position(x: size * 0.84, y: size * 0.16)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.18), radius: size * 0.04, x: 0, y: size * 0.02)
    }

    @ViewBuilder
    private var illustration: some View {
        if UIImage(named: imageName) != nil {
            Image(imageName).resizable()
        } else {
            LinearGradient(colors: [ringColor.opacity(0.22), ringColor.opacity(0.55)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
```

Keep the existing `extension BadgeCategory { ringColor; imageName }` and the existing `private extension Color { init(badgeHex:) }` in the file (do NOT duplicate them — they remain unchanged below this struct).

- [ ] **Step 5: Run the tests to verify they pass**

Run: `xcodebuild test -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:"Next WaveTests/VerifiedBadgeTests"`
Expected: PASS (3 tests). Also confirm `BadgeEvaluatorTests` still pass (BadgeMedalView change is render-only).

- [ ] **Step 6: Commit**

```bash
git add "Next Wave/Models/VerifiedBadge.swift" "Next Wave/Views/BadgeMedalView.swift" "Next WaveTests/VerifiedBadgeTests.swift"
git commit -m "feat: verified badge catalog + BadgeMedalView verified shield"
```

---

### Task 7: GPXImportCoordinator (orchestration)

**Files:**
- Create: `Next Wave/ViewModels/GPXImportCoordinator.swift`

**Interfaces:**
- Consumes: `GPXParser`, `SessionMetrics`, `GeoMath`, `WaveMatcher`/`CandidateDeparture`, `VerifiedRidesAPI`, `TransportAPI.getStationboard`, `Lake.Station`, `Journey`.
- Produces: `struct GPXImportSummary`; `@MainActor final class GPXImportCoordinator: ObservableObject` with `@Published var summary: GPXImportSummary?` and `func handleFile(_ url: URL, stations: [Lake.Station]) async`.

- [ ] **Step 1: Implement the coordinator**

`Next Wave/ViewModels/GPXImportCoordinator.swift`:
```swift
import Foundation
import CryptoKit

struct GPXImportSummary: Identifiable {
    let id = UUID()
    enum Outcome { case imported, alreadyImported, failed }
    let outcome: Outcome
    let totalDistanceM: Double
    let verifiedWaves: Int
    let topSpeedKmh: Double
    let longestRideM: Double
    let message: String?
}

@MainActor
final class GPXImportCoordinator: ObservableObject {
    static let shared = GPXImportCoordinator()
    private init() {}

    @Published var summary: GPXImportSummary?
    @Published var isBusy = false

    private static func sessionKey(_ session: GPXSession) -> String {
        let creator = session.metadata.creator ?? "?"
        let start = session.metadata.startTime?.timeIntervalSince1970 ?? session.points.first?.time.timeIntervalSince1970 ?? 0
        let raw = "\(creator)|\(Int(start))|\(session.points.count)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func handleFile(_ url: URL, stations: [Lake.Station]) async {
        isBusy = true
        defer { isBusy = false }

        // Parse off the main actor.
        let session: GPXSession
        do {
            session = try await Task.detached { try GPXParser.parse(url: url) }.value
        } catch {
            summary = GPXImportSummary(outcome: .failed, totalDistanceM: 0, verifiedWaves: 0,
                                       topSpeedKmh: 0, longestRideM: 0, message: "Couldn't read the GPX file.")
            return
        }

        guard let metrics = SessionMetrics.compute(from: session.points) else {
            summary = GPXImportSummary(outcome: .failed, totalDistanceM: 0, verifiedWaves: 0,
                                       topSpeedKmh: 0, longestRideM: 0, message: "The track has too few points.")
            return
        }

        let key = Self.sessionKey(session)
        if (try? await VerifiedRidesAPI.shared.sessionExists(key: key)) == true {
            summary = GPXImportSummary(outcome: .alreadyImported, totalDistanceM: metrics.totalDistance,
                                       verifiedWaves: 0, topSpeedKmh: metrics.maxSpeed * 3.6,
                                       longestRideM: metrics.longestRideDistance, message: "Already imported.")
            return
        }

        // Candidate stations within 400 m of any track point.
        let candidates = stations.filter { station in
            guard let c = station.coordinates else { return false }
            return session.points.contains {
                GeoMath.distance(lat1: $0.lat, lon1: $0.lon, lat2: c.latitude, lon2: c.longitude) <= 400
            }
        }

        // Build departures from each candidate's schedule for the session date.
        var departures: [CandidateDeparture] = []
        let api = TransportAPI()
        for station in candidates {
            guard let c = station.coordinates, let uic = station.uic_ref else { continue }
            let journeys = (try? await api.getStationboard(stationId: uic, for: metrics.start, limit: 200)) ?? []
            for j in journeys {
                guard let ts = j.stop.departureTimestamp else { continue }
                let route = (j.name ?? "")
                    .replacingOccurrences(of: "^0+", with: "", options: .regularExpression)
                departures.append(CandidateDeparture(
                    stationId: station.id, stationName: station.name, stationUicRef: station.uic_ref,
                    stationLat: c.latitude, stationLon: c.longitude,
                    departure: Date(timeIntervalSince1970: TimeInterval(ts)), routeNumber: route))
            }
        }

        let rides = WaveMatcher.match(points: session.points, departures: departures)

        do {
            try await VerifiedRidesAPI.shared.upload(metrics: metrics, sessionKey: key, rides: rides)
        } catch {
            summary = GPXImportSummary(outcome: .failed, totalDistanceM: metrics.totalDistance,
                                       verifiedWaves: rides.count, topSpeedKmh: metrics.maxSpeed * 3.6,
                                       longestRideM: metrics.longestRideDistance,
                                       message: "Imported locally but upload failed — try again later.")
            return
        }

        summary = GPXImportSummary(outcome: .imported, totalDistanceM: metrics.totalDistance,
                                   verifiedWaves: rides.count, topSpeedKmh: metrics.maxSpeed * 3.6,
                                   longestRideM: metrics.longestRideDistance, message: nil)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED. (Confirm `Journey.stop.departureTimestamp` and `Lake.Station.coordinates` member names compile.)

- [ ] **Step 3: Commit**

```bash
git add "Next Wave/ViewModels/GPXImportCoordinator.swift"
git commit -m "feat: GPXImportCoordinator (parse → match → upload → summary)"
```

---

### Task 8: Import wiring (document type + onOpenURL + summary sheet)

**Files:**
- Modify: `Next Wave/Info.plist`
- Modify: `Next Wave/NextWaveApp.swift`
- Create: `Next Wave/Views/GPXImportSummaryView.swift`

**Interfaces:**
- Consumes: `GPXImportCoordinator.shared`, `GPXImportSummary`, `lakeStationsViewModel.lakes`.

- [ ] **Step 1: Register the GPX document type (Info.plist)**

Run (adds the imported UTI + document type):
```bash
cd "/Users/federi/Documents/Next-Wave"
F="Next Wave/Info.plist"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations array" "$F"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0 dict" "$F"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0:UTTypeIdentifier string com.topografix.gpx" "$F"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0:UTTypeDescription string GPS Exchange Format" "$F"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0:UTTypeConformsTo array" "$F"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0:UTTypeConformsTo:0 string public.xml" "$F"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0:UTTypeTagSpecification dict" "$F"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension array" "$F"
/usr/libexec/PlistBuddy -c "Add :UTImportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension:0 string gpx" "$F"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes array" "$F"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0 dict" "$F"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string GPX Track" "$F"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Alternate" "$F"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Viewer" "$F"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$F"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string com.topografix.gpx" "$F"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:1 string public.xml" "$F"
```
Verify: `/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes" "Next Wave/Info.plist"` shows the entry.

- [ ] **Step 2: Create the summary sheet**

`Next Wave/Views/GPXImportSummaryView.swift`:
```swift
import SwiftUI

struct GPXImportSummaryView: View {
    let summary: GPXImportSummary
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: summary.outcome == .imported ? "checkmark.seal.fill"
                  : (summary.outcome == .alreadyImported ? "tray.full" : "exclamationmark.triangle"))
                .font(.system(size: 48))
                .foregroundColor(summary.outcome == .failed ? .orange : .green)
                .padding(.top, 24)

            Text(title).font(.title2.bold())

            if summary.outcome != .failed {
                VStack(spacing: 8) {
                    row("Distance", String(format: "%.2f km", summary.totalDistanceM / 1000))
                    row("Longest ride", String(format: "%.0f m", summary.longestRideM))
                    row("Top speed", String(format: "%.1f km/h", summary.topSpeedKmh))
                    if summary.outcome == .imported {
                        row("Verified waves", "\(summary.verifiedWaves)")
                    }
                }
                .padding(.horizontal)
            }
            if let m = summary.message {
                Text(m).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            }

            Button("Done", action: onDone)
                .font(.headline)
                .padding(.top, 8)
            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
    }

    private var title: String {
        switch summary.outcome {
        case .imported: return "Session imported! 🏄"
        case .alreadyImported: return "Already imported"
        case .failed: return "Import failed"
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundColor(.secondary); Spacer(); Text(value).fontWeight(.semibold) }
    }
}
```

- [ ] **Step 3: Wire onOpenURL + present the sheet**

In `Next Wave/NextWaveApp.swift`, add `@StateObject private var importCoordinator = GPXImportCoordinator.shared` (alongside the other state objects). Replace the existing `.onOpenURL { url in handleDeepLink(url) }` (line ~252) with:

```swift
                .onOpenURL { url in
                    if url.isFileURL && url.pathExtension.lowercased() == "gpx" {
                        let didAccess = url.startAccessingSecurityScopedResource()
                        // Copy to a temp file we control, then release the security scope.
                        let temp = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString).appendingPathExtension("gpx")
                        try? FileManager.default.copyItem(at: url, to: temp)
                        if didAccess { url.stopAccessingSecurityScopedResource() }
                        let stations = lakeStationsViewModel.lakes.flatMap { $0.stations }
                        Task {
                            if lakeStationsViewModel.lakes.isEmpty { await lakeStationsViewModel.loadLakes() }
                            let s = lakeStationsViewModel.lakes.flatMap { $0.stations }
                            await importCoordinator.handleFile(temp, stations: s.isEmpty ? stations : s)
                        }
                    } else {
                        handleDeepLink(url)
                    }
                }
                .sheet(item: $importCoordinator.summary) { summary in
                    GPXImportSummaryView(summary: summary) { importCoordinator.summary = nil }
                }
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild build -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED. (`lakeStationsViewModel.loadLakes()` exists per the deep-link handler that already calls it.)

- [ ] **Step 5: Manual verification**

In the simulator: drag a `.gpx` onto it / use Files → "Share" → Next Wave (or `xcrun simctl openurl`). Expected: the summary sheet appears with distance/top speed (verified waves will be 0 for pumpfoil samples — no ferry). Re-open the same file → "Already imported".

- [ ] **Step 6: Commit**

```bash
git add "Next Wave/Info.plist" "Next Wave/NextWaveApp.swift" "Next Wave/Views/GPXImportSummaryView.swift"
git commit -m "feat: import GPX via document type, parse + show summary sheet"
```

---

### Task 9: Verified section in My Badges

**Files:**
- Modify: `Next Wave/ViewModels/StatsStore.swift`
- Modify: `Next Wave/Views/StatsView.swift`

**Interfaces:**
- Consumes: `VerifiedRidesAPI.verifiedStats()`, `VerifiedBadgeEvaluator`, `VerifiedStats`, `BadgeMedalView(imageName:ringColor:isEarned:verified:size:)`.

- [ ] **Step 1: Load verified stats/badges in StatsStore**

In `Next Wave/ViewModels/StatsStore.swift`, add published state next to the existing ones:
```swift
    @Published private(set) var verifiedStats: VerifiedStats = .empty
    @Published private(set) var verifiedBadges: [EvaluatedVerifiedBadge] = VerifiedBadgeEvaluator.evaluate(.empty)
```
And at the end of `refresh(seenIds:onSeen:)`, after the existing independent `stationCounts` load, add another independent block:
```swift
        do {
            let vs = try await VerifiedRidesAPI.shared.verifiedStats()
            verifiedStats = vs
            verifiedBadges = VerifiedBadgeEvaluator.evaluate(vs)
        } catch {
            print("⚠️ Verified stats failed: \(error)")
        }
```

- [ ] **Step 2: Add the Verified section to StatsView**

In `Next Wave/Views/StatsView.swift`, after the "Locked" section block (`if !lockedBadges.isEmpty { badgeSection(...) }`), add:
```swift
                // MARK: Verified badges
                if store.verifiedStats.sessionCount > 0 || store.verifiedBadges.contains(where: { $0.isEarned }) {
                    verifiedSection
                }
```
And add these helpers next to `badgeSection(_:_:)`:
```swift
    private var verifiedSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            sectionHeader("Verified")
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                stat("\(store.verifiedStats.verifiedWaves)", "waves")
                stat(String(format: "%.0f m", store.verifiedStats.longestRideM), "longest")
                stat(String(format: "%.0f", store.verifiedStats.maxSpeedMs * 3.6), "km/h top")
            }
            LazyVGrid(columns: columns, spacing: 32) {
                ForEach(store.verifiedBadges) { item in
                    VStack(spacing: 20) {
                        BadgeMedalView(imageName: item.badge.imageName, ringColor: item.badge.ringColor,
                                       isEarned: item.isEarned, verified: true, size: 120)
                        VStack(spacing: 3) {
                            Text(item.badge.title).font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundColor(item.isEarned ? .primary : .secondary)
                            Text(item.badge.detail).font(.subheadline)
                                .multilineTextAlignment(.center).foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundColor(.secondary)
        }
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild build -scheme "NextWave" -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual verification**

After importing a GPX with verified data, open "My Badges" → a **Verified** section shows the verified figures + badges (with the green shield). Earned ones colored, others greyed/locked.

- [ ] **Step 5: Commit**

```bash
git add "Next Wave/ViewModels/StatsStore.swift" "Next Wave/Views/StatsView.swift"
git commit -m "feat: Verified section (stats + verified badges) in My Badges"
```

---

## Self-Review Notes (reconciled)

- **Spec coverage:** import/document type (Task 8); parse (Task 1); metrics incl. longest continuous ride (Task 2); matching by proximity+window+motion with check-in `wave_id` (Task 3); Supabase tables + RLS + RPC + dedup (Tasks 4–5); verified badges with thresholds + shield (Task 6); orchestration + dedup `session_key` (Task 7); summary sheet + error handling (Tasks 7–8); Verified UI section (Task 9); tests for parser/metrics/matcher/badges (Tasks 1–3, 6) + SQL verify (Task 4).
- **Type consistency:** `VerifiedRide`/`CandidateDeparture` (Task 3) consumed by Coordinator (Task 7) and `VerifiedRidesAPI.upload` (Task 5); `VerifiedStats` keys match the RPC columns (Tasks 4/5); `BadgeMedalView(imageName:ringColor:isEarned:verified:size:)` (Task 6) used in Task 9; `Journey.stop.departureTimestamp` + `Lake.Station.coordinates/uic_ref/id` are the real members.
- **Open items (from spec):** tuning values (thresholds/radii/window) to confirm with real ferry-wave GPX; verified badge artwork (`badge_verified_wave/distance/speed` show a category-color placeholder until added); whether to also fire the local badge notification on import.
- **Note:** the sample GPX are pumpfoil (no ferry) → expect 0 verified waves but valid distance/speed. Confirm wave-matching with a real ferry-wave recording.
