# Archive Script Mining v2

Lane: 208, archive script mining v2
Base checked: `origin/claude/build84-cmdcon36@3ac68b5d`
Guide revision: `GR-2026-07-03a`
Scope: docs-only catalog from the local Main PC cache at `E:\arma2-cache`. No mission source, generated mission files, archive payloads, package files, or live runtime settings were changed.

## Summary

The lane prompt named NIAC, MORTAR, Random_Arty, RoadBlockGeneration, NORRN aerialTaxi, and Airfield_Support archive families. The local cache has a mix of exact indexed rows and already-extracted script systems, so this pass records what can be mined from local evidence without downloading anything new.

Useful source-backed mechanics were found in these already-extracted cache items:

| Cache item | Local status | Most useful mechanic | WASP fit |
| --- | --- | --- | --- |
| `FSM_Support_Systems_1.0` | Extracted | Single FSM API for CAS, attack helicopter, artillery, transport, and supply drop calls with per-type quotas and an in-progress mutex. | Good support-economy reference; do not drop in wholesale. |
| `VIP_Arty_XEH_ver1.6` | Extracted | Map-click aimpoint, visible max/min range markers, timed rounds, ammo counter, and radio callouts. | Strongest small UX pattern for a future player-callable artillery lane. |
| `R3F_Arty_and_Log_1.3` | Extracted | Ballistic lookup tables, action-condition polling, object carry/tow/load, and helicopter sling-load offsets. | Mine for patterns only; R3F is GPLv3 and larger than a small WASP patch. |
| `norrn_dbo_fastRope_v9` / `NORRN_FR_gototest103.utes` | Extracted | Aerial taxi, map-click fast-rope/landing/extraction destinations, RTB loop, fast-rope gating by altitude and speed. | Useful design reference; old locality model needs modernization before source use. |
| `SAM_support_v95.Takistan` | Extracted | Real-vehicle CAS/transport/artillery support resources with busy flags, call limits, on-station/RTB handling, and airfield return/rearm. | Reference only; broad, ACE/LDL-heavy, and too large to port directly. |
| `Defining Airstrips and Taxiways` | Extracted | Editor-side airstrip/taxiway/ILS placement guidance plus helper scripts. | Mission-editor reference only, not runtime gameplay. |

The exact direct archives for NIAC, direct mortar addons, RealMortars, and RoadBlockGeneration were not locally present under `E:\arma2-cache\archives` or `E:\arma2-cache\extracted` during this pass. They are listed in `E:\arma2-cache\triage.csv` or implied by the lane name, but were not downloaded or extracted here.

## Cache Inventory Result

| Prompt target | Evidence found | Status | Catalog decision |
| --- | --- | --- | --- |
| NIAC | `triage.csv` row for `RUK_NIAC_V1_WithPW.7z`, category `units`, described as a Russian/Ukrainian unit reskin. | Indexed only, not mined. | No script mechanic extracted. Treat as content/reskin, not a lane 208 runtime candidate. |
| MORTAR | `triage.csv` rows for `test_barrage_area_mortar.Intro_WithPW.7z`, `bwc_M3mortar_WithPW.7z`, and `RealMortars_WithPW.7z`; no matching local archive/extracted directory. | Indexed only for direct targets. | Use extracted adjacent artillery systems below instead of inventing from absent archives. |
| Random_Arty | No exact `Random_Arty` archive found locally. Adjacent mined systems: `VIP_Arty_XEH_ver1.6`, `R3F_Arty_and_Log_1.3`, `FSM_Support_Systems_1.0`; report also lists `RYD_FireAtWill`. | Adjacent mined, exact target absent. | Portable ideas are artillery UX/range-gating and AI fire-control, not a direct port. |
| RoadBlockGeneration | No exact local hit in archives, extracted roots, or reports for `RoadBlockGeneration`. | Not found. | Defer. Do not claim a roadblock-generation port until the exact archive is available and inspected. |
| NORRN aerialTaxi | `norrn_dbo_fastRope_v9` and `NORRN_FR_gototest103.utes` extracted; source contains `scripts\heloGoTo` aerial taxi, landing, extraction, RTB, fast-rope, and respawn pieces. | Mined. | Use as design reference for helicopter extraction/fast-rope behavior; source lane must replace old locality primitives. |
| Airfield_Support | `SAM_support_v95.Takistan`, `FSM_Support_Systems_1.0`, and airstrip/taxiway docs extracted. | Mined. | Useful for support-call economy and airfield RTB/rearm notes; no immediate source change. |

## Mechanics Worth Keeping

### 1. Quota-gated support calls

`FSM_Support_Systems_1.0` exposes support calls as compact menu entries:

- `Support\CommsMenu.sqf` calls `['Arty','HE'] execFSM 'Support\Support.fsm'`, plus smoke, illumination, laser, SADARM, FFE, fixed-wing CAS, rotor CAS/transport, ammo, and vehicle drop variants.
- `Support\SupInit.sqf` initializes quotas such as `ASnumHEL = 5`, `ASnumFIX = 5`, `ASHEL`, `ASFIX`, `ARMissions`, and the global in-progress flag `IPAS`.
- `Support\Support.fsm` increments those counters, blocks calls when a quota is exhausted, spawns aircraft or artillery branches, and clears/deletes support assets on completion or failure.

WASP fit: this is a good shape for an economy-gated commander or player support menu later. The important portable idea is the interface contract, not the exact FSM:

1. Support request takes `[supportType, option]`.
2. Server owns resource state, quotas, and in-progress locks.
3. Client/UI gets only a clear accept/reject reason.
4. Each call has a supply/funds price plus a match or wave quota.
5. Cleanup is part of the support state machine, not a caller afterthought.

### 2. Map-click artillery with visible range gates

`VIP_Arty_XEH_ver1.6` is the cleanest small reference for player-facing artillery:

- `VIP_D30IF__src\scripts\aimpoint.sqs` draws a max-range marker at 8250 m and a min-range exclusion marker at 800 m before accepting fire.
- `callarty.sqs` resets the target/range markers and prepares the map-click flow.
- `VIP_fireinit.sqs` tracks `D30_Rounds`, delays shots with a randomized cadence, sends "Shot", "Rounds complete", and "Out of Rounds" style radio messages, and decrements ammunition.
- `gridcord.sqf` converts world positions into short grid references for readable radio traffic.

WASP fit: if a future lane adds player-callable off-map artillery, this is the smallest UX pattern to imitate. Do not start by porting the full addon. Start with:

1. a map-click aimpoint;
2. a visible allowed-ring and dead-zone marker;
3. a server-side price/quota check;
4. clear radio callouts;
5. bounded ammunition/uses.

### 3. R3F artillery and logistics patterns

`R3F_Arty_and_Log_1.3` has two separate value streams.

Artillery:

- `R3F_ARTY\calcul_balistique\generer_table.sqf` builds range/elevation tables from projectile parameters.
- `R3F_ARTY\calcul_balistique\calculer_elevation.sqf` finds flat and high-angle solutions with bounded iteration.
- `R3F_ARTY\tables\table_M252_et_2b14_82mm.sqf` and `table_M119_et_D30.sqf` show precomputed tables for common A2 mortar/howitzer classes.
- `R3F_ARTY\tirer_position_dans_zone_elliptique.sqf` samples a point in an oriented ellipse, useful for beaten-zone dispersion.

Logistics:

- `R3F_LOG\surveiller_conditions_actions_menu.sqf` moves expensive addAction condition checks into a 0.3 second polling loop, so addAction strings read cached booleans instead of running `nearestObjects` every frame.
- `R3F_LOG\heliporteur\heliporter.sqf` sling-loads objects by using `boundingBox` height offsets and network-visible `setVariable` state.
- `R3F_LOG\objet_init.sqf` installs actions with cached condition booleans rather than recalculating object validity inside every action condition.

WASP fit: reference, not copy. R3F ships with GPLv3 material and a broad subsystem footprint. The safest follow-ups are independent re-implementations of narrow ideas:

- throttled action-condition cache for busy service/build/supply interactions;
- dynamic sling-load offset math for supply helicopter cargo;
- precomputed mortar/howitzer solution tables only if the existing artillery behavior ever gets reopened.

### 4. NORRN aerial taxi and fast-rope loop

`NORRN_FR_gototest103.utes` and the source tree inside `norrn_dbo_fastRope_v9` contain the closest match to "NORRN aerialTaxi".

Observed mechanics:

- `scripts\heloGoTo\addGotoAction.sqf` adds "Set fast rope destination" and "Set chopper destination" actions to the helicopter.
- `mapClick.sqf` and `mapClickLand.sqf` capture a destination with `onMapSingleClick`, store it as `NORRN_FR_destPos`, and broadcast work via `Nor_HT_S`.
- `FR_destination.sqf` sends the helicopter to the clicked point, lowers flight height, and runs `fast_rope_AI_pilot.sqf`.
- `Land_destination.sqf`, `Extraction_destination.sqf`, and `RTB.sqf` handle land/extract/return-to-base cycles, ramp animation, status messages, and all-clear takeoff actions.
- `limitFastRopeAction.sqf` gates fast-rope deployment on speed, altitude, cargo count, and whether a player group leader is in cargo.
- `respawnHeli.sqf` tracks aerial-taxi destruction and respawns the taxi with the command state restored.

Porting caveat: these scripts rely heavily on older MP patterns such as `setVehicleInit`, `processInitCommands`, wide `publicVariable` use, and global action IDs. A WASP source lane should use explicit server/client locality, object `setVariable` state, and current remote execution patterns already used in the mission instead of copying the old transport layer.

WASP fit: good concept, sensitive source surface. A later implementation should stay default-off and avoid touching hot aircraft AI or GUI files unless the board is clear.

### 5. SAM support and airfield handling

`SAM_support_v95.Takistan` is large, but it shows a useful support-resource model:

- `sam_support\client.sqf` validates selected resource, mission type, target coordinates, ammunition, busy state, and remaining calls before raising a server request.
- `sam_support\server_cas.sqf`, `server_transport.sqf`, `server_art.sqf`, and `server_on_station.sqf` drive real assets rather than invisible fire support.
- CAS uses `sam_busy`, server-side call counters, on-station lists, target-distance waits, RTB state, and airfield rearm/refuel with `landAt`, `setFuel`, and `setVehicleAmmo`.
- The system also includes LDL AC130/UAV pieces and ACE weapon handling, so it is not a small vanilla WASP drop-in.

WASP fit: borrow the resource-state model only. The airfield return/rearm pattern is useful documentation for future support-resource or AI airbase work, but the exact implementation is too broad for a clean Build84 patch.

### 6. Airstrip and taxiway editor docs

The `Defining Airstrips and Taxiways` cache items include a Word tutorial, `Pos.sqs`, `Dir.sqs`, and an `ilsDirection.xls` helper. Prior cache findings mark this as terrain-authoring documentation rather than runtime gameplay.

WASP fit: keep it as editor reference for custom-terrain or Takistan airfield notes. It should not become mission runtime code.

## Explicit Non-Candidates From This Pass

| Item | Reason |
| --- | --- |
| `RUK_NIAC_V1_WithPW.7z` | Indexed as a unit reskin and not locally present. No script mechanic was mined. |
| `bwc_M3mortar_WithPW.7z` | Indexed as a mortar weapon addon and not locally present. Do not infer scripting behavior from the name. |
| `RealMortars_WithPW.7z` | Indexed as a realistic mortar system and not locally present. Potentially worth a future Main PC download/extract lane, but not this PR. |
| `test_barrage_area_mortar.Intro_WithPW.7z` | Indexed as a test mission and not locally present. Use adjacent extracted artillery references for now. |
| `RoadBlockGeneration` | Exact archive/script not found locally. No port recommendation. |
| Wholesale R3F/SAM/NORRN import | Too broad for Build84, license/locality risk, and likely overlaps hot aircraft/support/GUI surfaces. |

## Suggested Follow-Ups When Source Lanes Are Free

| Follow-up | Shape | Source risk |
| --- | --- | --- |
| Fire-support UX spec | Design a server-owned support-call API, visible range markers, and radio callouts using the VIP/FSM patterns above. | Medium; touches UI/support/state if implemented. |
| Support quota economy | Add a default-off support budget concept tied to supplies/funds and per-wave quotas. | Medium; source lane should be isolated from existing service/support GUI work. |
| Aerial taxi design audit | Produce a WASP-specific design for map-click taxi/extraction without old `setVehicleInit` patterns. | Medium-high; aircraft AI and transport actions are sensitive. |
| Logistics action polling | Audit current service/build/supply addAction conditions and cache expensive predicates on a timer. | Low-medium if isolated; performance-only if behavior is unchanged. |
| Mortar archive refresh | Download/extract the indexed mortar archives on the Main PC and create a second catalog only if the board is free. | Docs-only until direct source is inspected. |

## Verification

- Confirmed the source worktree is on `codex/lane208-archive-script-mining-v2` from `origin/claude/build84-cmdcon36@3ac68b5d`.
- Read `E:\arma2-cache\triage.csv`, `E:\arma2-cache\reports\findings.csv`, and relevant extracted directories under `E:\arma2-cache\extracted`.
- Confirmed the direct NIAC/mortar/RealMortars targets were not present in `E:\arma2-cache\archives` or `E:\arma2-cache\extracted` during this pass.
- No SQF, SQM, HPP, EXT, generated Takistan output, package, or runtime file was changed.
- LoadoutManager was not run because this is a docs-only research lane.
