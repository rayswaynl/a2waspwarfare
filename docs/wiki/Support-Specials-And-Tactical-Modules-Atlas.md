# Support Specials And Tactical Modules Atlas

This atlas maps support calls, specials and tactical modules: paratroopers, paradrops, UAV, artillery, ICBM/Nuke, MASH, airlift/ZetaCargo, service actions and supply mission hooks.

## How To Use This Page

This page is the support/tactical gateway. Use it to identify which runtime family owns an effect, then follow the owner page before editing authority, economy, networking or smoke status.

| Need | Start here |
| --- | --- |
| Tactical menu entry points, button gates and local support flow | [Tactical Menu Entry Points](#tactical-menu-entry-points) below and [Client UI systems](Client-UI-Systems-Atlas) |
| `RequestSpecial` server authority and forged-payload risk | [Server Dispatch And PV Paths](#server-dispatch-and-pv-paths), [Server authority migration map](Server-Authority-Migration-Map) |
| ICBM/nuke hardening | [ICBM authority](ICBM-Authority-Playbook) |
| Artillery visibility, commander-built ARTY and fire-mission smoke | [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas), [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack) |
| Supply missions, service actions or client-side funds/debits | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Service menu affordability guards](Service-Menu-Affordability-Guards), [Economy authority first cut](Economy-Authority-First-Cut) |
| MASH, UAV, ZetaCargo, AAR or aircraft ordnance leaf behavior | [Module Deep Dives](#module-deep-dives) and [Aircraft Ordnance Guardrails](#aircraft-ordnance-guardrails) below |
| Branch/release readiness for support fixes | [Feature status register](Feature-Status-Register), [Source fix propagation queue](Source-Fix-Propagation-Queue), [Testing workflow](Testing-Debugging-And-Release-Workflow) |

## Current Branch Scope

This atlas carries support orientation and selected source anchors. Deep hardening status belongs on owner pages: [Server authority migration map](Server-Authority-Migration-Map) for `RequestSpecial`, [ICBM authority](ICBM-Authority-Playbook) for nuke, [Service menu affordability guards](Service-Menu-Affordability-Guards) for service actions, and [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) for supply. The `upgrade-sync` matrix below was refreshed against docs checkout `e785f1e9`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f`, release `a96fdda2` and `origin/feat/upgrade-queue-stacking` `b061c905`; all checked roots still keep the mixed `_args` / `_this` parser in `Server_HandleSpecial.sqf:67-73`.

## Tactical Menu Entry Points

The main support UI is `Client/GUI/GUI_Menu_Tactical.sqf`.

Key source refs:

- `GUI_Menu_Tactical.sqf:58-61` defines support list/fees/cooldowns.
- `:146-217` owns fast-travel destination discovery, fee-mode filtering and local fee marker text.
- `:252-282` gates support buttons by funds, upgrade level and local cooldown state.
- `:403-406` locally debits paid fast travel after destination click.
- `:371-373`, `:513-527` send `RequestSpecial` support requests.
- `:463-505` performs the ICBM local launch flow.
- `:532-605` requests artillery/fire mission behavior.

Server dispatch starts at `Server/PVFunctions/RequestSpecial.sqf:1`, which forwards directly into `Server/Functions/Server_HandleSpecial.sqf`. The server dispatch file handles paratroops/ammo/vehicle/UAV around `:43-64`, ICBM around `:97-111`, and repair-camp behavior around `:147-170`.

RequestSpecial scout 2026-06-04: the active tag set in source Chernarus is `update-teamleader`, `group-query`, `Paratroops`, `ParaVehi`, `ParaAmmo`, `RespawnST`, `uav`, `upgrade-sync`, `update-clientfps`, `update-town-delegation`, `ICBM`, `process-killed-hq`, `connected-hc` and `repair-camp`. `track-playerobject` has a server switch case around `Server_HandleSpecial.sqf:133-145`, but no active Chernarus `RequestSpecial` caller was found; treat it as an undriven bookkeeping branch unless a later dynamic caller proves otherwise.

Depth scout follow-up 2026-06-04 added one high-value authority caution: `group-query` is not just a harmless request relay. `Server_HandleSpecial.sqf:13-31` trusts payload `_group`, `_player` and `_side`; if the target leader is AI and the group lacks `wfbe_uid`, it calls `Common_ChangeUnitGroup.sqf:3-11` to move the payload player into that group. Patch this in the server-authority lane by deriving requester/player/side server-side before any group move.

Mini-scout follow-up 2026-06-04 tightened the authority map:

- Tactical menu gating is client-side first: `Client/GUI/GUI_Menu_Tactical.sqf:252-283,293-347,463-527` checks funds, upgrades, commander status, UAV state and local cooldowns before requests are sent.
- Artillery is not a `RequestSpecial` asset-spawn path. `Client_RequestFireMission.sqf:50-72`, `Common_HandleArtillery.sqf:7-85` and `Common_FireArtillery.sqf:7-72` own local cooldown/fire-control/range behavior, with ammo options loaded through `Common_GetArtilleryAmmoOptions.sqf:41-72` and `Common_LoadArtilleryAmmo.sqf:18-53`.
- UAV is client-spawned and client-paid in `Client/Module/UAV/uav.sqf:15-52`; `Server/Support/Support_UAV.sqf:6-20` mainly monitors and cleans it up.
- `Server_HandleSpecial.sqf:67-73` has a fragile `upgrade-sync` branch: it reads `_side` from `_args select 1`, then `_upgrade_id` / `_upgrade_level` from `_this select 2/3`. Any caller-shape change can break that branch differently from the other `RequestSpecial` tags.

### Upgrade-Sync Branch Matrix

`upgrade-sync` is consistency/cleanup debt rather than a proven current runtime break: `Server_HandleSpecial.sqf:3` sets `_args = _this`, so today's mixed `_args` / `_this` reads resolve to the same payload. The cleanup is still patch-ready because it makes the RequestSpecial tuple contract explicit before broader router hardening.

| Root / branch | Evidence | Status |
| --- | --- | --- |
| Docs checkout Chernarus `e785f1e9` | `Server_HandleSpecial.sqf:3,67-73` assigns `_args = _this`, reads `_side` from `_args select 1`, then `_upgrade_id` / `_upgrade_level` from `_this select 2/3`; `GUI_UpgradeMenu.sqf:171` sends `["upgrade-sync", WFBE_Client_SideJoined, _this select 0, _this select 1]`; `Server_ProcessUpgrade.sqf:26,29,35` owns the sync variable. | Mixed-source reads remain; current behavior is equivalent but fragile. |
| Docs checkout maintained Vanilla `e785f1e9` | Same maintained-root shape in `Server_HandleSpecial.sqf:3,67-73`, `GUI_UpgradeMenu.sqf:171` and `Server_ProcessUpgrade.sqf:26,29,35`. | Needs the same cleanup if source is patched. |
| Stable `origin/master` `cf2a6d6a` | Same mixed `_args` / `_this` branch in both maintained roots; Chernarus and maintained Vanilla callers shifted to `GUI_UpgradeMenu.sqf:268` after the upgrade-menu countdown/status work. `Server_ProcessUpgrade.sqf:26,29,35` still owns the sync variable. | No stable-master rescue; only caller line drift from the docs checkout. |
| Miksuu upstream `b8389e74` | Same mixed branch in both maintained roots; caller line `GUI_UpgradeMenu.sqf:241`; `Server_ProcessUpgrade.sqf:26,29,35` still owns the sync variable. | No upstream rescue. |
| `origin/perf/quick-wins` `0076040f` | Same mixed branch in both maintained roots; caller line `GUI_UpgradeMenu.sqf:241`; `Server_ProcessUpgrade.sqf:26,29,35` still owns the sync variable. | Perf branch does not touch this router path. |
| Release `origin/release/2026-06-feature-bundle` `a96fdda2` | Same mixed branch in both maintained roots; release Chernarus and maintained Vanilla callers both sit at `GUI_UpgradeMenu.sqf:254`; `Server_ProcessUpgrade.sqf:26,29,35` still owns the sync variable. | No release rescue; only release-root line drift. |
| `origin/feat/upgrade-queue-stacking` `b061c905` | Same mixed branch in both maintained roots; Chernarus and maintained Vanilla callers sit at `GUI_UpgradeMenu.sqf:268`; `RequestUpgrade.sqf:5` still forwards directly into `WFBE_SE_FNC_ProcessUpgrade`. | Queue UI work does not normalize the `upgrade-sync` tuple or close upgrade request authority. |

Patch order: normalize the branch to read side/id/level from `_args` only, add a short tuple comment or helper-local guard if editing the router, keep RequestUpgrade authority migration separate, propagate maintained Vanilla, then smoke normal commander upgrade completion, non-server client timer sync, malformed/short payload rejection and AI commander upgrade progress.

Support-authority scout 2026-06-04 sharpened the non-ICBM payload-trust cases:

- Paratrooper support passes payload `_playerTeam` into `Support_Paratroopers.sqf`; the dropped infantry are created into that team and the marker callback targets `leader _playerTeam`. A forged or stale team payload is therefore not just a notification issue.
- `RespawnST` is called from `GUI_Menu_Economy.sqf:91-96` with `sideJoined`, while `Server_HandleSpecial.sqf:55-60` trusts the payload side and damages every current `wfbe_ai_supplytrucks` entry for that side. Treat wrong-side forged respawn requests as part of the non-ICBM support authority lane.
- Camp repair action scripts send `["repair-camp", _camp, WFBE_Client_SideID]`; `Server_HandleSpecial.sqf:147-168` trusts the camp object and repair-side payload when changing camp `sideID` and broadcasting `CampCaptured`.
- Old UAV cleanup is server-observed but client-created/client-paid: `Client/Module/UAV/uav.sqf:27-52` owns spawn/debit, and `Support_UAV.sqf:6-20` mainly tracks/cleans the payload object.

No live `RequestSupport` symbol was found in source Chernarus during the 2026-06-04 trigger-chain scout; support and special effects route through `RequestSpecial`.

Transport split from the 2026-06-04 supports scout:

- Registered support requests use the generic PVF envelope: `Common/Functions/Common_SendToServer.sqf:12-18` prepends the function tag, `Server/Functions/Server_HandlePVF.sqf:9-14` dispatches it, and `Server/PVFunctions/RequestSpecial.sqf:1` delegates into `Server_HandleSpecial.sqf`.
- Client-bound support feedback uses the sibling path: `Common/Functions/Common_SendToClient.sqf:9-18` and `Client/Functions/Client_HandlePVF.sqf:19-22`.
- Artillery is not the same server-accepted support path. `Client/GUI/GUI_Menu_Tactical.sqf:531-547` gates fire missions locally, `Common_GetTeamArtillery.sqf:10-30` discovers usable guns from the caller's group units, `Client/Functions/Client_RequestFireMission.sqf:13-31,51-54` starts local fire/cooldown behavior, and `Common/Functions/Common_FireArtillery.sqf:9-23,53-72` validates gun/range/firing mechanics. The 2026-06-04 source patch makes manned artillery-class base-area defenses use the current commander team when one exists (`Construction_StationaryDefense.sqf:91-94`), so commander-built HQ/base ARTY can become visible to this group-based fire-mission path. Smoke that ownership separately from ARTY setup in Arma 2 OA.
- Service actions are another local support family. `Client/GUI/GUI_Menu_Service.sqf:196-234` debits/spawns rearm/refuel/repair/heal support locally; [Service menu affordability guards](Service-Menu-Affordability-Guards) owns the small local correctness patch, while full authority remains an economy-ledger redesign.

Adjacent server runtime surfaces: grouped base areas are enabled only when `WFBE_C_BASE_AREA > 0` (`Server/Init/Init_Server.sqf:565`). Side logic seeds `wfbe_basearea` at `Init_Server.sqf:380`; `Server/FSM/basearea.sqf:46-80` then polls every 20 seconds, prunes invalid/remote base-area logics, and schedules delayed orphan-defense cleanup through `_onAreaRemoved` (`basearea.sqf:12-43`). `Server/FSM/groupsMonitor.sqf:1-14` is a dormant debug monitor that logs `allGroups` counts every 30 seconds; its only source start point found in this pass is commented at `Init_Server.sqf:567`.

## Support Feature Matrix

| Feature | Status | Notes |
| --- | --- | --- |
| Tactical support menu | Partial | UI works, but most fee/cooldown/upgrade gates are client-side only. |
| Fast travel | Working/partial | Local Tactical flow. Fee mode hides unaffordable towns and debits locally; branch/root matrix and UX decision live in [Client UI systems](Client-UI-Systems-Atlas#tactical-fast-travel-fee-branch-matrix). |
| Paratroopers | Working/partial | `RequestSpecial -> HandleSpecial -> KAT_Paratroopers`; server creates transport/units and sends marker callback. Missing server-side fee/cooldown/upgrade validation. |
| Ammo paradrop | Working/partial | Client-gated by `WFBE_UP_SUPPLYPARADROP` and shared `lastSupplyCall`; server creates aircraft/crates. |
| Vehicle paradrop | Working/partial | Similar to ammo paradrop; server creates cargo vehicle and empty-vehicle cleanup. |
| UAV | Partial | Client creates UAV, deducts funds and sends tracking request; server mostly monitors cleanup and reveal broadcasts. |
| Artillery | Working/partial | Local/client fire authority with upgrade-gated UI/ammo/timeout behavior. |
| Anti-air radar (AAR) | Working/partial | Base structure and client marker feature are live when enabled; upgrade levels change marker detail and refresh rate, but the per-aircraft marker loops are client-local and should be performance-smoked on busy air games. |
| ICBM/Nuke | Partial/high-risk | Client deducts funds and sends `RequestSpecial ["ICBM", ...]`; server applies nuke damage from payload. Stale adjunct paths remain. |
| MASH | Partial/stale | Local officer deploy path supports respawn lookup, but marker sender/relay/receiver are split or disabled. |
| ZetaCargo/airlift | Broken/partial | Hook attaches nearby unmanned land vehicle; detach action does not pass the lifted vehicle even though unhook expects it. |
| Service menu | Working/partial | Repair/refuel/rearm/heal effects and deductions are client-side; local support scripts recheck world state but not full money authority. |
| Supply mission | Partial | Server validates return proximity but trusts client-set `SupplyFromTown` / `SupplyAmount`. |
| Supply truck respawn | Safe-disabled / authority gap if revived | Economy menu requests `RequestSpecial ["RespawnST", sideJoined]`; `Server_HandleSpecial.sqf:55-60` still trusts the payload side and damages the side logic's `wfbe_ai_supplytrucks` list. Current `origin/master` `cf2a6d6a` and release `a96fdda2` initialize that list and log-disable old AI supply-truck logistics at `Init_Server.sqf:382-384` in both maintained roots instead of raw-spawning `UpdateSupplyTruck`; the old worker still points at missing `Server\FSM\supplytruck.fsm` at `AI_UpdateSupplyTruck.sqf:17`. Canonical branch matrix: [AI commander autonomy audit](AI-Commander-Autonomy-Audit#ai-supply-truck-branch-matrix). |

## Server Dispatch And PV Paths

`RequestSpecial.sqf` is intentionally tiny and forwards payloads. That makes `Server_HandleSpecial.sqf` the important hardening boundary. Today, several high-impact support effects rely on the client UI having already enforced role, upgrade, fee and cooldown.

Use [Server authority migration map](Server-Authority-Migration-Map) before adding public support features. Use [ICBM authority](ICBM-Authority-Playbook) for the nuke path specifically, because it has public-server blast radius.

## Economy Cooldown And Upgrade Gates

The tactical UI keeps support fees and intervals locally. The scout observed support fee examples `[0,75000,9500,3500,8500,0,12500,0,0]` and intervals `[0,1000,800,600,900,0,0,0,0]`; paid fast travel uses the separate distance-based `WFBE_C_GAMEPLAY_FAST_TRAVEL_PRICE_KM` path. Button enabling checks funds/upgrades/cooldowns client-side; future patches should re-check the same facts on the server before spawning assets or applying map-wide effects.

Do not treat those UI checks as security boundaries. For paradrops, UAV and ICBM, the server router currently assumes the client already did role, upgrade, fee and cooldown filtering. For artillery and services, much of the effect/debit path is client-local. Public-server hardening should therefore separate:

- `RequestSpecial` server validation for server-spawned assets and map-wide effects.
- local correctness guards for service/EASA/artillery UI paths.
- a broader economy ledger decision for client-side funds/effects.

## Module Deep Dives

### Anti-Air Radar

AAR is a live base-support system, not only a historical changelog item. The build/action layer recognizes `AARadar` structures (`RequestStructure.sqf:14`; `updateavailableactions.fsm:189-222`), and unit init starts `Common_AARadarMarkerUpdate.sqf` for opposite-side aircraft when `WFBE_C_STRUCTURES_ANTIAIRRADAR > 0` (`Init_Unit.sqf:111-114`). The marker loop hides work while the map is closed, requires an AAR in range, applies the configured detection altitude, and reads `WFBE_UP_AAR` to move from speed-only markers at 5 seconds to altitude at 3 seconds and aircraft type at 1 second (`Common_AARadarMarkerUpdate.sqf:53-121`). It also records `PerformanceAuditAARMarkerScripts` and `aar_marker_update` samples, so large-aircraft smoke should include map-open/map-closed performance.

### UAV

`Client/Module/UAV/*` owns creation/cost/PV behavior, interface toggles and reveal broadcasts. The server monitors/trashes the UAV when the leader leaves or the UAV dies. Current authority is client-led for spawn/cost and server-led for cleanup tracking.

### ICBM And Nuke

`Client/Module/Nuke/*` owns launch UI/marker/object flow and sends the special request. `Client/FSM/updateclient.sqf:19-20` still registers an `ICBM_launched` event handler, but no current publisher was found. `NukeIncoming` PVF exists but the current launch path uses `RequestSpecial`.

### MASH

`Client/Module/Skill/*` owns officer MASH/supply actions. MASH deploy creates local tent state used by respawn lookup. Marker sync is stale: the server relay exists, the client receiver compile is commented, and no maintained Chernarus/Vanilla sender was found. The 2026-06-05 branch recheck found the same orphaned relay shape on stable, Miksuu upstream and the current release branch; modded `eden`/`lingor` sender lines are drift, not maintained-marker proof. Use [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas) for the live respawn split.

### ZetaCargo Airlift

`Client/Module/ZetaCargo/*` defines lifters/types and hook/unhook behavior. Airlift action is gated by `WFBE_UP_AIRLIFT`, but the detach action does not pass the lifted vehicle while `Zeta_Unhook.sqf` expects it in action arguments.

## Logistics Supports

Paradrops, service actions and supply missions overlap with economy authority:

- Paradrops are server-created assets but client-gated requests.
- Service actions perform local timed repair/rearm/refuel/heal support and client-side debits.
- Supply mission completion adds side supply server-side but trusts truck variables set from client mission start.

Use [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Service menu affordability guards](Service-Menu-Affordability-Guards) and [Economy authority first cut](Economy-Authority-First-Cut) for implementation sequencing.

## Aircraft Ordnance Guardrails

Current source has live ordnance guardrails, but they are not all equally active:

- Bomb distance restriction is live for `Bo_FAB_250` and `Bo_Mk82`. Plane setup attaches `HandleShootBombs` (`Common/Init/Init_Unit.sqf:118-121`); the handler exits unless the ammo is one of those bomb classes, requires the local player as shooter, reads `WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION`, checks `cursorTarget`, hints `STR_WF_MESSAGE_BombDistanceRestriction` and deletes the projectile when the target is beyond the configured distance (`Common/Functions/Common_HandleShootBombs.sqf:15-30`).
- Bomb altitude is config-present but runtime-dormant in that handler. `Rsc/Parameters.hpp:284-288` exposes `WFBE_C_GAMEPLAY_BOMBS_ALTITUDE`, default 2000, but the altitude check/delete block in `Common_HandleShootBombs.sqf:32-44` is commented out.
- Incoming missile range limiting is live when `WFBE_C_GAMEPLAY_MISSILES_RANGE` is non-zero. Non-man units get an `incomingMissile` handler (`Common/Init/Init_Unit.sqf:125-128`); `Common_HandleIncomingMissile.sqf:9-21` deletes IR-lock missiles, with a dumb-bomb workaround, once they exceed the configured range.
- Terrain-masking missile blocking is live for tanks, cars and air units through a `Fired` handler (`Common/Init/Init_Unit.sqf:207-212`). `Common_HandleShootMissiles.sqf:95-140` detects guided missile-like ammo, uses `cursorTarget`, checks vehicle-to-target terrain intersection with ASL positions and deletes the projectile with `STR_WF_MESSAGE_MissileTerrainMaskingRestriction` plus `MissileLaunchBlocked`.
- The terrain-masking handler has a commented `_limit_distance` section (`Common_HandleShootMissiles.sqf:107-117`), so current enforcement is terrain-intersection based rather than "only under configured distance".
- Aircraft AA gating is partial/path-dependent. Build, buy, rearm and EASA paths remove/filter AA missiles through upgrade and parameter checks (`Client_BuildUnit.sqf:287-293`; `Server_BuyUnit.sqf:155-162`; `Common_RearmVehicle.sqf:53-60`; `GUI_Menu_EASA.sqf:15-20`), but start/pre-placed vehicles or unusual creation paths should be smoke-tested before claiming complete coverage.

The main risks are locality and player-facing false positives: bomb distance and missile masking lean on local `cursorTarget`, the unit init path exits for non-local player scope, and bomb altitude has a lobby parameter without active enforcement. Treat future aircraft-balance work as runtime-test-heavy, not just config editing.

## Wave N Dispatch Notes

Wave N rechecked the support router and found two source-level traps worth keeping on this owner page:

- `Server/PVFunctions/RequestSpecial.sqf:1` remains only a trampoline into `HandleSpecial`, so the actual authority boundary is `Server/Functions/Server_HandleSpecial.sqf`. That dispatch accepts paratroop/ammo/vehicle tags around `:43-52`, UAV around `:63-64`, ICBM around `:97-111`, `track-playerobject` around `:133-146` and `repair-camp` around `:147-170`.
- RU para-ammo config is effectively commented out in `Common/Config/Core_Root/Root_RU.sqf:36`: the `WFBE_%1PARAAMMO` assignment appears after `//--- Starting Vehicles` on the same physical line. `Server/Support/Support_ParaAmmo.sqf:59-60` exits unless `WFBE_%1PARAAMMO` is an array, so RU ammo paradrop support needs a config-line repair before it can be treated as feature-complete.
- `Client/PVFunctions/NukeIncoming.sqf:7` plays `airRaid`, while [Assets/config/localization/parameters atlas](Assets-Config-Localization-And-Parameters-Atlas) confirms no `class airRaid` in `Sounds/description.ext`. If `NukeIncoming` is revived, add or replace that sound reference.

## Patch-Ready Hardening

| Finding | Patch shape |
| --- | --- |
| `RequestSpecial` trusts client-side gates | Add server-side requester/side/role/funds/cooldown/upgrade validation before dispatching assets or map-wide effects. |
| Base-area cleanup private-list nit | If editing `basearea.sqf`, add `_unit` to the `_onAreaRemoved` private list before its static-gunner cleanup block. This is low-risk hygiene, not an urgent behavior bug. |
| Bomb altitude parameter is dormant | Either revive and smoke the commented altitude block in `Common_HandleShootBombs.sqf`, or rename/document the parameter as historical so admins do not expect it to enforce. |
| Ordnance guardrails depend on local target state | Test lock/no-lock, pilot/gunner, AI crew, JIP and remote locality cases before tightening bomb or missile restrictions. |
| AA missile gating is path-dependent | Verify start vehicles, purchased aircraft, client-built aircraft, rearmed aircraft, SAMs and EASA loadouts all pass the same `WFBE_C_GAMEPLAY_AIR_AA_MISSILES` / `WFBE_UP_AIRAAM` policy before calling AA restrictions complete. |
| RU ammo paradrop config is commented out | Split `Root_RU.sqf:36` so the starting-vehicle comment does not swallow `WFBE_%1PARAAMMO`; smoke RU para-ammo request after the fix. |
| `upgrade-sync` mixed argument source | Use the [upgrade-sync branch matrix](#upgrade-sync-branch-matrix). Normalize `Server_HandleSpecial.sqf:67-73` to read side/id/level from one payload shape, then smoke upgrade completion synchronization. |
| Zeta detach missing vehicle arg | Pass `[_vehicle]` when adding the detach action in `Zeta_Hook.sqf`, or revise `Zeta_Unhook.sqf` to find the lifted object safely. |
| Stale ICBM adjuncts | Either wire the `ICBM_launched` / `NukeIncoming` paths intentionally or remove/document them as dead. If revived, fix the missing `airRaid` sound reference first. |
| MASH marker flow is split | Reconcile sender, server relay, client receiver, delete replay and JIP resend, or remove/archive the stale marker relay. |
| Supply mission cargo/source trust | Recompute cargo/source/reward server-side from trusted truck/town state. |
| UAV creation/cost client-owned | Move UAV spawn/cost validation server-side or validate requested type, side, funds and existing UAV before accepting tracking. |

## Validation Checklist

- Paratrooper, ammo and vehicle paradrops with valid/invalid upgrade levels and insufficient funds.
- UAV spawn, reveal, leader disconnect and cleanup.
- Artillery request with each upgrade level and local/remote gunner state.
- ICBM request from valid commander and forged/non-commander payload.
- MASH deploy, respawn availability and marker sync.
- Zeta hook/unhook with vehicle attached.
- Service actions with changing funds/world state between button enable and click.
- Supply mission cargo reward and cooldown after truck reuse.

## Continue Reading

Previous: [Modules atlas](Modules-Atlas) | Next: [ICBM authority](ICBM-Authority-Playbook)

Main map: [Home](Home) | Feature triage: [Feature status](Feature-Status-Register) | Authority map: [Server authority migration map](Server-Authority-Migration-Map)
