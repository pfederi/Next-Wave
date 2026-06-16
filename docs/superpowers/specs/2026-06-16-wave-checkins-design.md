# Wave Check-ins ("Wer ist heute draussen?") — Design

**Date:** 2026-06-16
**Status:** Approved (design), pending implementation plan
**Author:** Patrick Federi

## Summary

A lightweight social check-in feature for Next Wave. Foilers can mark a specific
wave (ferry departure) as "I'm going on this one" so others can see how many
people plan to be out — enabling buddy meetups and improving safety. Each wave
shows a small live counter of how many foilers plan to catch it, with optional
names.

## Goals

- Let a user check in to a specific wave (toggle on/off).
- Show a small, unobtrusive counter per wave of how many plan to go.
- Optionally show names of those checked in (name is optional → anonymous count
  always works).
- Identity (name + anonymous preference) is stored locally on the device and is
  editable any time.
- Counts are shared across all users via the backend and update live.

## Non-Goals

- No user accounts, login, email, or social profiles.
- No chat/messaging between foilers (counter + names only).
- No more than one check-in per device per wave.
- No moderation/CMS UI in this iteration (abuse handled by rate limit + RLS).

## Decisions (from brainstorming)

| Question | Decision |
|----------|----------|
| Visibility | Shared across all users via server (real cross-device counter). |
| Privacy | Count always visible; **name optional** (anonymous opt-out). |
| Time horizon | Check in to any wave across the **next 7 days**. |
| Backend | **Supabase** (reuse existing instance used for promo tiles). |
| Write path / security | Direct to Supabase via `supabase-swift` SDK using **Anonymous Auth + RLS** (safest realistic option for iOS — no embedded secret is truly secret; anon key is public-by-design and protected by RLS; a service-key proxy would be more dangerous if leaked). |
| One name per device | Yes — `unique (wave_id, user_id)`. |
| Counter freshness | **Realtime** via Supabase Realtime (WebSocket), scoped to visible waves. |

## Wave Identity

Two different devices must compute the **same** ID for the same departure, or the
counter splits. The ID is computed **client-side** from stable fields of the
transport API and sent to the backend. The server never needs to understand the
schedule.

```
waveId = "{stationId}_{departureISO}_{lineName}"
   e.g.  "8503671_2026-06-18T14:32_ZSG-12"
```

- `stationId` — official station ID (already available in the app).
- `departureISO` — departure date + time.
- `lineName` / course number — disambiguates two simultaneous departures.

`waveId` generation must be deterministic and is covered by unit tests.

## Data Model

Single table in the existing Supabase project.

```sql
create table wave_checkins (
  id           uuid primary key default gen_random_uuid(),
  wave_id      text not null,            -- "{stationId}_{departureISO}_{line}"
  user_id      uuid not null,            -- = auth.uid() (anonymous JWT)
  display_name text,                     -- NULL = anonymous
  departure_at timestamptz not null,     -- used for auto-cleanup + client filter
  created_at   timestamptz default now(),
  unique (wave_id, user_id)              -- one check-in per wave per device
);

create index on wave_checkins (wave_id);
create index on wave_checkins (departure_at);
```

### Row-Level Security

- **SELECT** — public: `using (true)` (anyone may read count + names).
- **INSERT** — `with check (auth.uid() = user_id)`.
- **UPDATE / DELETE** — `using (auth.uid() = user_id)` (only own rows).

### Counter read

An RPC `wave_checkin_counts(wave_ids text[])` returns per `wave_id`:
`{ wave_id, count, names text[] }` (names excludes NULL/anonymous entries). The
app queries the currently visible waves in a single batched call rather than
per-wave.

### Auto-cleanup

`pg_cron` job runs daily and deletes rows where `departure_at < now()`. The app
additionally filters `departure_at < now()` client-side as a safety net.

### Anti-abuse (first stage)

Rate limit inserts per `user_id` (DB/RLS level). If fake counts become a problem,
add Apple **App Attest** in a later iteration. App Attest is out of scope now.

## App Architecture (iOS / SwiftUI)

Follows existing patterns (actor-based API clients, App Group `group.com.federi.Next-Wave`).

- **`supabase-swift` SDK** added as dependency (first direct Supabase use; promo
  tiles stay on their read-only JSON endpoint and are untouched).
- **Anonymous auth bootstrap:** on first launch, obtain an anonymous Supabase
  session; persist JWT in the Keychain; refresh transparently on expiry.
- **`CheckinAPI` actor:** check-in (insert), un-check (delete), update name,
  batched counter fetch, and Realtime subscription management.
- **Local identity:** `display_name` + "count me anonymously" flag stored in
  UserDefaults; editable from Settings. Prefilled from device name on first use
  when readable, otherwise entered manually.
- **Realtime:** subscribe only to the `wave_id`s of the currently visible day's
  list; re-subscribe on day change.

## UI / UX

**a) Trigger** — Each wave row in the departure list gets a tappable action
(person / surfer icon). Tap = toggle check-in. Filled = you're in.

**b) Name sheet (first check-in only)** — small sheet:
> "Wie sollen dich andere sehen?"
> [ name field ] · toggle "Anonym mitzählen"
- Prefilled from device name if readable; else empty → manual entry.
- Name + anonymous choice saved locally; reused automatically afterward.
- Editable any time via Settings.
- Includes a short privacy note: "Dein Name ist für andere Foiler sichtbar" +
  link to the privacy policy.

**c) Counter on the wave**
- `0` going → nothing / greyed icon (no list noise).
- `≥1` → `👤 3`; tapping opens a small list: "Pat, Lisa, +1 anonym".
- Your own participation is visually highlighted.

**d) Placement** — counter sits compactly within the existing departure row;
the name list opens as a popover/sheet to keep the row slim.

## Edge Cases

- **Offline:** optimistic UI update + retry queue; on persistent failure roll
  back with a subtle message.
- **Token expiry:** transparent refresh of the anonymous session.
- **Waves with no check-ins:** counter hidden/greyed — no visual noise.
- **Cleanup miss:** client-side `departure_at < now()` filter as backstop.

## Privacy

`display_name` is personal data and visible to other users. Surface this clearly
in the first name sheet, offer "anonymous" as an equal option, and link the
privacy policy. Update the app's privacy policy to mention shared check-in names.

## Testing

- **Unit:** deterministic `waveId` generation; counter aggregation.
- **RLS:** modifying another user's row must fail; reading must succeed publicly.
- **UI:** check-in toggle; first-time name sheet; name edit in Settings.
- **Realtime:** counter updates when another device checks in/out.

## Open Items for Implementation Plan

- Exact source field in the transport API used for `lineName` (verify it is
  always present and stable across the 7-day window).
- Whether the counter list shows anonymous entries as "+N anonym" only, or also
  a placeholder per anonymous person.
- Rate-limit thresholds for inserts per `user_id`.
