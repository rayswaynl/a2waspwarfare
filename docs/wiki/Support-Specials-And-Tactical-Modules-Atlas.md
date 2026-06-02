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

## Wave N Dispatch Notes

Wave N rechecked the support router and found two source-level traps worth keeping on this owner page:

- `Server/PVFunctions/RequestSpecial.sqf:1` remains only a trampoline into `HandleSpecial`, so the actual authority boundary is `Server/Functions/Server_HandleSpecial.sqf`. That dispatch accepts paratroop/ammo/vehicle tags around `:43-52`, UAV around `:63-64`, ICBM around `:97-111`, `track-playerobject` around `:133-146` and `repair-camp` around `:147-170`.
- RU para-ammo config is effectively commented out in `Common/Config/Core_Root/Root_RU.sqf:36`: the `WFBE_%1PARAAMMO` assignment appears after `//--- Starting Vehicles` on the same physical line. `Server/Support/Support_ParaAmmo.sqf:59-60` exits unless `WFBE_%1PARAAMMO` is an array, so RU ammo paradrop support needs a config-line repair before it can be treated as feature-complete.
- `Client/PVFunctions/NukeIncoming.sqf:7` plays `airRaid`, while [Assets/config/localization/parameters atlas](Assets-Config-Localization-And-Parameters-Atlas) confirms no `class airRaid` in `Sounds/description.ext`. If `NukeIncoming` is revived, add or replace that sound reference.

## Patch-Ready Hardening

| Finding | Patch shape |
| --- | --- |
| `RequestSpecial` trusts client-side gates | Add server-side requester/side/role/funds/cooldown/upgrade validation before dispatching assets or map-wide effects. |
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
