# PR8 June Feature Bundle Test Profile

Use this profile for broad PR8 regression testing and as the template for future
PR-specific test profiles.

## Focus Areas

- Client GPS/minimap gain and WF-menu GPS toggle.
- AI delegation, HC participation, leader locality, empty/no-waypoint groups, and stuck leaders.
- Factory queues, build acceptance, queue counts, and damaged/dead factories.
- Supply helicopter load/unload action visibility and completion.
- WDDM/static-defense crew counts, AAR/HQ wall layout, and commander artillery registration.
- Client/server FPS during heavy AI, vehicle load, UI menus, GPS/map open states, and cleanup.
- General bughunting invariants: missing feature functions, loaded supply vehicles, static crews, town cooldowns, and open queues.

## Suggested Manual Sequence

1. Join the mission, get commander if needed, and let the HC connect.
2. Run `PR8 Queue: GPS/UI`; open WF menu, toggle GPS, open service menu, and open Tactical/Buy Units once.
3. Run `PR8 Queue: AI behavior`; watch for `AI_DELEGATION_AUDIT` and `AI_BEHAVIOR`.
4. Run `PR8 Queue: factories`; build or queue a few representative units.
5. Run `PR8 Queue: service/supply`; test supply heli load/unload and service menu text.
6. Run `PR8 Queue: WDDM/artillery`; build WDDM/defenses and commander artillery if available.
7. Run `PR8 Queue: load/perf`; allow the perf burst to finish.
8. Run `PR8 Queue: bughunt sweep`; use this as the final broad snapshot.
9. Run `PR8 Test: cleanup/reset`.

## Expected Live Tick Topics

- HC status and RPT freshness.
- Latest queue step/proof.
- Latest AI aggregate and AI delegation audit.
- Latest GPS/UI proof.
- Latest bughunt audit.
- New real errors, with known mod noise separated.
