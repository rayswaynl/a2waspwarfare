# KHESANH release status - 2026-07-03

Scope: fleet lane 173, `KHESANH-REL`, on `origin/claude/build84-cmdcon36`.
This is a source-backed status note only. No mission source, generated mirror,
package artifact, live deploy, or server action was changed here.

## Verdict

Current source already carries the Khe Sanh carrier repair stack. The remaining
release blocker is proof, not another blind source patch: boot the intended
package and verify complete carriers, reachable deck/camp geometry, SCUD pad on
deck, no flicker, capture/respawn, and map-specific behavior in RPT and in game.

The prompt says "both maps"; current source truth is map-specific. Chernarus is
the naval carrier map (`version.sqf:6` defines `IS_NAVAL_MAP`) and has the three
pre-placed Khe Sanh town logics in `mission.sqm:55-100`. Takistan keeps
`//#define IS_NAVAL_MAP` in `version.sqf:6`, so `Init_NavalHVT.sqf:28` exits
explicitly there instead of trying to spawn sea carriers on a landlocked map.

## Source-present fixes

- Launch/gates: both roots compile the SCUD handler and launch
  `Server\Init\Init_NavalHVT.sqf` behind `WFBE_C_NAVAL_HVT`
  (`Init_Server.sqf:58-61`, `:994-996`), while the common constants keep
  `WFBE_C_NAVAL_HVT=1` and `WFBE_C_NAVAL_TWIN_HULLS=1`
  (`Init_CommonConstants.sqf:885`, `:1700`).
- Full LHD assembly: `Init_NavalHVT.sqf:69-84` restores the missing port
  elevator and island bridge/control-point classes and documents the exact
  half-carrier / camp-under-deck / SCUD-in-water failure it is preventing.
  `WFBE_NavalHVT_SpawnLHD` then builds every part at the carrier anchor
  (`:90-106`) using the `setPosASL` spawn helper (`:45-57`).
- Deck-height town centers: each carrier measures deck height from the spawned
  deck part (`:213`, `:241`, `:258`), stores `wfbe_naval_deckz`
  (`:214`, `:242`, `:259`), and lifts the town logic to deck height
  (`:223`, `:245`, `:262`). This addresses the "town-center logic under the
  deck" symptom without changing the town FSM shape.
- Capture scan height: `server_town.sqf:50` raises the naval-HVT capture band
  to `wfbe_naval_deckz + 12`, so on-deck attackers can count while normal towns
  keep the legacy height filter.
- SCUD placement: the SCUD platform is resolved to the runtime middle carrier
  (`:267-289`), its pad is placed at `wfbe_naval_deckz` (`:285`), the visible
  launcher is reseated at deck height (`:338`, `:355`), and then attached to the
  carrier deck part to stop physics drift (`:361`).
- Twin-hull layout: the two outer carriers get a second parallel LHD hull and
  deck-height bridge piers when `WFBE_C_NAVAL_TWIN_HULLS=1`
  (`:388-435`). The middle carrier remains the single-hull SCUD carrier.
- Carrier UX: shop POI markers rescan for late-replicating carrier flags
  (`Client/Init/Init_Markers.sqf:53-90`), captured carrier respawn options are
  offered through `Client_GetRespawnAvailable.sqf:122-130`, deck respawn uses
  `wfbe_naval_deckz` in `Client_OnRespawnHandler.sqf:97-110`, and carrier
  air-shop lookup is wired in `Client_GetClosestAirport.sqf:16-32`.
- AI guardrails: ground AICOM assignment skips naval HVTs unless the team has a
  transport helicopter (`AI_Commander_AssignTowns.sqf:592`, `:637`, `:671`),
  side patrols exclude carrier towns and water positions (`Common_RunSidePatrol.sqf:135-187`),
  and `Common_GetRandomPosition.sqf:34` keeps the old water-reject loop capped.

## Release proof still required

1. Build/generate the exact package intended for release from current source.
2. Boot Chernarus with `WFBE_C_NAVAL_HVT=1`; confirm RPT shows
   `Init_NavalHVT`, `NAVALHVT-DECK`, and `NAVALHVT-TWIN` entries with no
   `NAVALHVT-SPAWNFAIL`.
3. Inspect Alpha, Bravo, and Charlie in game: complete LHD part set, no
   half-ship flicker, town/camp interaction reachable from the deck, SCUD pad
   and visible launcher on the middle carrier deck, and bridge piers usable on
   the outer twin-hull carriers.
4. Capture a carrier, verify marker/shop ownership refresh, deck respawn, and
   carrier SCUD/Tactical menu behavior from the owning side.
5. Boot Takistan as the paired map check; expected result is the explicit
   `IS_naval_map=false` information log and no carrier spawn attempt. If the
   requirement changes to a Takistan HVT, route that through the land-HVT design
   in `TK-DEEP-PARITY.md` instead of forcing sea carriers onto Takistan.

## Boundary

Do not treat this status note as release-ready smoke. It only records that the
current target branch already contains the source-side KHESANH fixes and that
the remaining lane 173 work is runtime validation or a deliberately scoped
follow-up if the boot finds a fresh, reproducible defect.
