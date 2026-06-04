# Support Specials And Tactical Modules Atlas

This atlas maps support calls, specials and tactical modules: paratroopers, paradrops, UAV, artillery, ICBM/Nuke, MASH, airlift/ZetaCargo, service actions and supply mission hooks.

## Tactical Menu Entry Points

The main support UI is `Client/GUI/GUI_Menu_Tactical.sqf`.

Key source refs:

- `GUI_Menu_Tactical.sqf:58-61` defines support list/fees/cooldowns.
- `:252-282` gates support buttons by funds, upgrade level and local cooldown state.
- `:371-373`, `:513-527` send `RequestSpecial` support requests.
- `:463-505` performs the ICBM local launch flow.
- `:532-605` requests artillery/fire mission behavior.

Server dispatch starts at `Server/PVFunctions/RequestSpecial.sqf:1`, which forwards directly into `Server/Functions/Server_HandleSpecial.sqf`. The server dispatch file handles paratroops/ammo/vehicle/UAV around `:43-64`, ICBM around `:97-111`, and repair-camp behavior around `:147-170`.

RequestSpecial scout 2026-06-04: the active tag set in source Chernarus is `update-teamleader`, `group-query`, `Paratroops`, `ParaVehi`, `ParaAmmo`, `RespawnST`, `uav`, `upgrade-sync`, `update-clientfps`, `update-town-delegation`, `ICBM`, `process-killed-hq`, `connected-hc` and `repair-camp`. `track-playerobject` has a server switch case around `Server_HandleSpecial.sqf:133-145`, but no active Chernarus `RequestSpecial` caller was found; treat it as an undriven bookkeeping branch unless a later dynamic caller proves otherwise.

No live `RequestSupport` symbol was found in source Chernarus during the 2026-06-04 trigger-chain scout; support and special effects route through `RequestSpecial`.

Adjacent server runtime surfaces: grouped base areas are enabled only when `WFBE_C_BASE_AREA > 0` (`Server/Init/Init_Server.sqf:565`). Side logic seeds `wfbe_basearea` at `Init_Server.sqf:380`; `Server/FSM/basearea.sqf:46-80` then polls every 20 seconds, prunes invalid/remote base-area logics, and schedules delayed orphan-defense cleanup through `_onAreaRemoved` (`basearea.sqf:12-43`). `Server/FSM/groupsMonitor.sqf:1-14` is a dormant debug monitor that logs `allGroups` counts every 30 seconds; its only source start point found in this pass is commented at `Init_Server.sqf:567`.

## Support Feature Matrix

| Feature | Status | Notes |
| --- | --- | --- |
| Tactical support menu | Partial | UI works, but most fee/cooldown/upgrade gates are client-side only. |
| Paratroopers | Working/partial | `RequestSpecial -> HandleSpecial -> KAT_Paratroopers`; server creates transport/units and sends marker callback. Missing server-side fee/cooldown/upgrade validation. |
| Ammo paradrop | Working/partial | Client-gated by `WFBE_UP_SUPPLYPARADROP` and shared `lastSupplyCall`; server creates aircraft/crates. |
| Vehicle paradrop | Working/partial | Similar to ammo paradrop; server creates cargo vehicle and empty-vehicle cleanup. |
| UAV | Partial | Client creates UAV, deducts funds and sends tracking request; server mostly monitors cleanup and reveal broadcasts. |
| Artillery | Working/partial | Local/client fire authority with upgrade-gated UI/ammo/timeout behavior. |
| ICBM/Nuke | Partial/high-risk | Client deducts funds and sends `RequestSpecial ["ICBM", ...]`; server applies nuke damage from payload. Stale adjunct paths remain. |
| MASH | Partial/stale | Local officer deploy path supports respawn lookup, but marker sender/relay/receiver are split or disabled. |
| ZetaCargo/airlift | Broken/partial | Hook attaches nearby unmanned land vehicle; detach action does not pass the lifted vehicle even though unhook expects it. |
| Service menu | Working/partial | Repair/refuel/rearm/heal effects and deductions are client-side; local support scripts recheck world state but not full money authority. |
| Supply mission | Partial | Server validates return proximity but trusts client-set `SupplyFromTown` / `SupplyAmount`. |
| Supply truck respawn | Working/unclear | Economy menu requests server-side supply-truck kill/respawn; no fee found. |

## Server Dispatch And PV Paths

`RequestSpecial.sqf` is intentionally tiny and forwards payloads. That makes `Server_HandleSpecial.sqf` the important hardening boundary. Today, several high-impact support effects rely on the client UI having already enforced role, upgrade, fee and cooldown.

Use [Server authority migration map](Server-Authority-Migration-Map) before adding public support features. Use [ICBM authority](ICBM-Authority-Playbook) for the nuke path specifically, because it has public-server blast radius.

## Economy Cooldown And Upgrade Gates

The tactical UI keeps support fees and intervals locally. The scout observed fee examples `[0,75000,9500,3500,8500,0,12500,0,0]` and intervals `[0,1000,800,600,900,0,0,0,0]`. Button enabling checks funds/upgrades/cooldowns client-side; future patches should re-check the same facts on the server before spawning assets or applying map-wide effects.

## Module Deep Dives

### UAV

`Client/Module/UAV/*` owns creation/cost/PV behavior, interface toggles and reveal broadcasts. The server monitors/trashes the UAV when the leader leaves or the UAV dies. Current authority is client-led for spawn/cost and server-led for cleanup tracking.

### ICBM And Nuke

`Client/Module/Nuke/*` owns launch UI/marker/object flow and sends the special request. `Client/FSM/updateclient.sqf:19-20` still registers an `ICBM_launched` event handler, but no current publisher was found. `NukeIncoming` PVF exists but the current launch path uses `RequestSpecial`.

### MASH

`Client/Module/Skill/*` owns officer MASH/supply actions. MASH deploy creates local tent state used by respawn lookup. Marker sync is stale: the server relay exists, the client receiver compile is commented, and no live sender was found in the audited Chernarus path. Use [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas) for the live respawn split.

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
| Zeta detach missing vehicle arg | Pass `[_vehicle]` when adding the detach action in `Zeta_Hook.sqf`, or revise `Zeta_Unhook.sqf` to find the lifted object safely. |
| Stale ICBM adjuncts | Either wire the `ICBM_launched` / `NukeIncoming` paths intentionally or remove/document them as dead. If revived, fix the missing `airRaid` sound reference first. |
| MASH marker flow is split | Reconcile sender, server relay and client receiver, or remove the stale marker relay. |
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

Previous: [Modules atlas](Modules-Atlas) | Next: [ICBM authority](ICBM-Authority-Playbook)

Main map: [Home](Home) | Feature triage: [Feature status](Feature-Status-Register) | Authority map: [Server authority migration map](Server-Authority-Migration-Map)
