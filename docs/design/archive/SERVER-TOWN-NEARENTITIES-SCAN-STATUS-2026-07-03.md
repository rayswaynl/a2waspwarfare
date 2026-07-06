# Server Town NearEntities Scan Status - 2026-07-03

## Scope

Fleet lane 108 asks to reduce the `server_town.sqf` per-town capture scan cost:

- the town-capture loop scans nearby `Man`, vehicle, air, and ship classes every pass;
- the airfield recapture path used to scan for nearby `LocationLogicAirport` anchors;
- the proposed direction was to fold or cache those scans.

This pass is docs-only. The source was read on
`origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`.

## Verdict

Lane 108 is only partially open on the current target.

The airfield lookup half is already implemented safely. `server_town.sqf:529-535` caches the nearest
`LocationLogicAirport` on `wfbe_airfield_logic_ref`, so later recaptures reuse the town-local anchor
instead of repeating the 1500 m logic scan.

The capture-presence half is still intentionally a direct scan. `server_town.sqf:47-56` says the
previous dedupe was reverted after capture-detection wedges, then performs:

- a height-aware direct `nearEntities` call at the current town capture range;
- side counts from that exact fresh object set;
- `town_capture_scan` performance audit timing around the direct scan.

Do not re-land the old one-scan-many-readers cache reuse without an in-engine capture soak. It was
already tried in commit `5f0bcfaf` and reverted in `8440d052` after repeated capture failures.

## Current Source Shape

### Capture scan

`Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town.sqf:47-56`
uses the proven direct capture scan:

- `:47-48` documents the dedupe revert and says the `server_town_ai` cache write is unread;
- `:49` starts the performance timing;
- `:50` keeps the Naval-HVT deck height exception;
- `:51` runs direct `nearEntities` at `_town_capture_range`;
- `:53-55` derives west/east/resistance counts from that object set;
- `:56` records `town_capture_scan`.

`server_town_ai.sqf:118-119` still runs its own activation scan at the larger dynamic detection
range, but the current target no longer publishes `wfbe_town_near_units` / `wfbe_town_near_units_t`
for `server_town.sqf` to reuse.

### Airfield logic scan

`server_town.sqf:529-535` already has the cache that lane 108 requested for airfields:

- read `wfbe_airfield_logic_ref` from the town;
- only if it is null, scan for `LocationLogicAirport` within 1500 m;
- store the first match back on the town with local `setVariable`.

That source was added by PR #301 / commit `412989d7` via `d2068e21`, and is present in all maintained
roots.

## Regression History

The obvious optimization was already attempted.

Commit `5f0bcfaf` added "one-scan-many-readers" cache reuse: `server_town_ai.sqf` wrote
`wfbe_town_near_units` plus a timestamp, and `server_town.sqf` distance-filtered that 600 m cache
down to the capture range.

Commit `8440d052` reverted the `server_town.sqf` reader. The revert message records that the cached
array path threw every tick and prevented captures even after a null/dead filter. Current source keeps
the direct capture scan because it is the proven path.

## Recommendation

Do not ship a blind source "fix" for lane 108 from static inspection alone.

Safe next steps would be:

- keep the airfield logic cache as already implemented;
- use the existing `town_capture_scan` performance audit token to quantify remaining scan cost in a
  real soak;
- if capture-scan reuse is revisited, test it behind a default-off flag with an in-engine capture
  soak covering infantry, vehicles, Naval-HVT deck captures, neutral towns, owned towns, and rapid
  recaptures;
- avoid any implementation that changes capture detection freshness or object shape without runtime
  proof.

## Maintained Root Parity

All maintained roots have identical `server_town.sqf` content for this audit:

| Root | SHA256 |
| --- | --- |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus` | `7EAFC3C5AAFFB3C3ED5BA3632F1ABA72776F063FEF56E8A07C6E0B7A165B8C84` |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan` | `7EAFC3C5AAFFB3C3ED5BA3632F1ABA72776F063FEF56E8A07C6E0B7A165B8C84` |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad` | `7EAFC3C5AAFFB3C3ED5BA3632F1ABA72776F063FEF56E8A07C6E0B7A165B8C84` |

## Validation Notes

- `rg` confirmed the direct capture-scan anchors in all maintained roots.
- `rg` confirmed `wfbe_airfield_logic_ref` caching and the `LocationLogicAirport` fallback scan in all maintained roots.
- `rg` found no current `wfbe_town_near_units` / `wfbe_town_near_units_t` cache writer in maintained Chernarus.
- `git log -S"PERF dedupe REVERTED"` identifies `8440d052`.
- `git log -S"town_capture_scan"` identifies the current audit timing hook lineage.
- LoadoutManager was not run because this pass changes documentation only.
