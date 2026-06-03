# Recon UAV — remade UAV deploy (Tactical Center support)

**Date:** 2026-06-03
**Branch:** `feat/recon-uav` (stacked on `feat/drone-saturation-strike`)
**Mission:** Chernarus source-of-truth (`Missions\[55-2hc]warfarev2_073v48co.chernarus`). Takistan regenerated via LoadoutManager as a follow-up.

## Problem

The existing UAV deploy (Tactical menu → "UAV") is the one support in that menu that breaks the
server-dispatch pattern. It creates the UAV **client-side**, hands control to the player via the
legacy `remoteControl gunner` + a camera interface (two variants: `uav_interface.sqf` for vanilla A2
and `uav_interface_oa.sqf` for OA), and tracks it through a client global `playerUAV`. This path is
fragile in multiplayer (desync on disconnect, client-authoritative destroy, marker bugs — upstream
has a `UAV_MarkerFix` branch), and the cost is hardcoded in two places (`$12500` in the menu fee
array *and* in `uav.sqf`).

## Decision (from brainstorming)

Replace the player-piloted camera UAV with an **AI-automated recon drone**, built on the
`feat/drone-saturation-strike` framework:

- **Fire-and-forget.** Press the "UAV" button — no map click. The server spawns the drone.
- **Auto-targets the frontline.** It flies to and orbits the **nearest contested town** (the closest
  town the deploying side does not own), via `WFBE_CO_FNC_GetClosestEnemyLocation`.
- **Reveals enemies to the team.** A server-side spotting loop reuses the existing `uav-reveal` path
  (`WFBE_CL_FNC_Reveal_UAV`) to draw orange enemy blips for the deploying side — identical markers to
  today, but server-authoritative.
- **Persists until shot down.** No timer. It loiters until the enemy destroys it, a teammate recalls
  it, or the side loses its HQ.
- **No enemy warning.** The enemy gets no marker; they must visually/audibly spot and kill it. Favors
  the deploying side, by design.
- **Airframe: `Ka137_PMC`** (the strike drone's `WFBE_{side}DRONE` classname) — an unmanned helicopter
  that can hover/orbit tightly and is easy to engage. One airframe across all six configured factions.

### Per-side, not per-player

The old UAV was tied to one player (`playerUAV`). The remade UAV is a **team asset**: one live recon
UAV per side (`WFBE_C_RECON_CONCURRENT_CAP = 1`). Any squad can deploy or recall it. The server owns
the concurrent count and **broadcasts** it (`WFBE_RECON_ACTIVE_<SIDE>`) so the menu can gate the button.

## Architecture

Client button → `WFBE_CO_FNC_SendToServer("RequestSpecial", ["ReconUAV", side, clientTeam])`
→ `Server_HandleSpecial.sqf` case `"ReconUAV"` → `_args spawn KAT_ReconUAV`
→ `Server\Support\Support_ReconUAV.sqf`.

`Support_ReconUAV.sqf` lifecycle:
1. Lobby toggle + concurrent-cap guard.
2. Resolve airframe (`WFBE_{side}DRONE`) + pilot (`WFBE_{side}PILOT`, fallback `…SOLDIER`).
3. Spawn point = side HQ (`WFBE_CO_FNC_GetSideHQ`) at orbit altitude.
4. Loiter target = nearest contested town (`WFBE_CO_FNC_GetClosestEnemyLocation`; fallback nearest town).
5. Increment + broadcast `WFBE_RECON_ACTIVE_<SIDE>`.
6. Spawn one drone + hidden AI pilot. Group `AWARE` (sensors hot) + `combatMode "BLUE"` (never fire) +
   `disableAI TARGET/AUTOTARGET`. Scripted-HP `HandleDamage` (mirrors the strike's model, attributes
   kill credit so downing it pays a bounty). `Killed` EH → `WFBE_CO_FNC_OnUnitKilled`.
7. Expose the live drone (`WFBE_RECON_UAV_<SIDE>`) so Recall can find it.
8. **Orbit + reveal thread:** every ~5s re-aim a `doMove` orbit point around the town (smooth arc);
   every `WFBE_C_PLAYERS_UAV_SPOTTING_DELAY` scan `nearEntities` and broadcast `uav-reveal` to the side.
9. **Cleanup thread:** `waitUntil {!alive drone}`, delete crew + group, clear the handle, decrement +
   broadcast the active count.

Recall: client → `["RequestSpecial", ["ReconUAVRecall", side, clientTeam]]` → server case deletes the
live drone's crew + vehicle (no `Killed` EH → no enemy bounty). The cleanup thread frees the slot.

## Menu changes (`GUI_Menu_Tactical.sqf`)

| Entry | Before | After |
|-------|--------|-------|
| `UAV` | client spawn + camera | fire-and-forget `RequestSpecial → ReconUAV`; fee from `WFBE_C_RECON_COST` |
| `UAV_Destroy` → `UAV_Recall` | client self-destruct | server-authoritative recall |
| `UAV_Remote_Control` | re-enter camera | **removed** (no camera) |

Availability for `UAV`: funds ≥ cost, `WFBE_UP_UAV ≥ 1`, `WFBE_RECON_ACTIVE_<SIDE> < cap`,
`WFBE_C_RECON_ENABLED == 1`. Availability for `UAV_Recall`: `WFBE_RECON_ACTIVE_<SIDE> > 0`.

## Files

- **New:** `Server\Support\Support_ReconUAV.sqf`.
- **Edit:** `GUI_Menu_Tactical.sqf`, `Server\Functions\Server_HandleSpecial.sqf`,
  `Server\Init\Init_Server.sqf` (`KAT_UAV` → `KAT_ReconUAV`), `Common\Init\Init_CommonConstants.sqf`
  (recon constants), `Rsc\Parameters.hpp` (lobby toggle), `stringtable.xml` (new strings).
- **Delete:** `Client\Module\UAV\uav.sqf`, `uav_interface.sqf`, `uav_interface_oa.sqf`,
  `uav_spotter.sqf`, `Server\Support\Support_UAV.sqf`.
- **Keep:** `WFBE_CL_FNC_Reveal_UAV` (the marker drawer), `WFBE_{side}UAV` root configs,
  `WFBE_UP_UAV` upgrade gating.

## Constants (`Init_CommonConstants.sqf`, after the drone block)

| Constant | Default | Purpose |
|----------|---------|---------|
| `WFBE_C_RECON_ENABLED` | 1 | lobby toggle |
| `WFBE_C_RECON_COST` | 12500 | deploy cost (single source of truth) |
| `WFBE_C_RECON_CONCURRENT_CAP` | 1 | max live recon UAVs per side |
| `WFBE_C_RECON_ALT` | 250 | m AGL orbit altitude |
| `WFBE_C_RECON_ORBIT_RADIUS` | 450 | m orbit radius (town range = 600) |
| `WFBE_C_RECON_SPEED` | 28 | m/s loiter speed |
| `WFBE_C_RECON_HP` | 12 | scripted hit points (~.50-cal hits to down) |
| `WFBE_C_RECON_MIN_HIT` | 0.08 | min HandleDamage delta that counts |

Reuses the existing `WFBE_C_PLAYERS_UAV_SPOTTING_DELAY/RANGE/DETECTION` for the reveal scan.

## Out of scope / follow-ups

- In-engine smoke test (cannot run the Arma engine here): confirm the Ka-137 reaches the town, orbits,
  reveals enemies for friendlies only, is killable, recall works, and the menu button gates on the
  per-side cap.
- Takistan regen via LoadoutManager.
- Possible balance retune after playtest (all values are constants).

## Known limitations

- Rare double-pay race if two players on a side click deploy simultaneously before the cap broadcasts
  (same behaviour as `DroneStrike`); the server cap still prevents a second spawn.
- If a side owns every town, the loiter target falls back to the nearest town overall.
