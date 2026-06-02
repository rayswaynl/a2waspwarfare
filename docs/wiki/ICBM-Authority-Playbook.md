# ICBM Authority Playbook

Implementation playbook for DR-27: the ICBM/nuke module lets a forged `RequestSpecial` payload trigger server-applied map-wide damage.

Scope: `Missions/[55-2hc]warfarev2_073v48co.chernarus`. Apply gameplay patches there first, then propagate generated missions with `Tools/LoadoutManager`.

## Status

| Field | Value |
| --- | --- |
| Finding | Confirmed critical authority bug |
| Finding id | DR-27 |
| Primary server files | `Server/PVFunctions/RequestSpecial.sqf`, `Server/Functions/Server_HandleSpecial.sqf` |
| Primary client files | `Client/GUI/GUI_Menu_Tactical.sqf`, `Client/Module/Nuke/nukeincoming.sqf`, `Client/Module/Nuke/damage.sqf` |
| Risk | Any client can forge an ICBM request with chosen side/team/objects; server later runs `NukeDammage` centered on client-supplied coordinates. |
| Patch type | Server-authoritative `RequestSpecial` `"ICBM"` validation and debit/cooldown design |

## Source Chain

| File | Evidence |
| --- | --- |
| `Common/Init/Init_CommonConstants.sqf:48,237,239` | Defines `WFBE_UP_ICBM`; enables the ICBM module by default when unset; sets `WFBE_ICBM_TIME_TO_IMPACT`. |
| `Rsc/Parameters.hpp:32-33,387-388` | Exposes impact-time and ICBM module mission parameters. |
| `Common/Init/Init_Common.sqf:319` | Loads `Client\Module\Nuke\ICBM_Init.sqf` when `WFBE_C_MODULE_WFBE_ICBM > 0`. |
| `Client/Module/Nuke/ICBM_Init.sqf:6-13` | Compiles `NukeIncoming`, marker/message handlers, radiation and `NukeDammage`. |
| `Common/Init/Init_PublicVariables.sqf:18,39` | Registers `RequestSpecial` server-bound and `NukeIncoming` client-bound PVF command names. |
| `Client/GUI/GUI_Menu_Tactical.sqf:252-260` | UI enables ICBM only when module is enabled, current side upgrade level is > 0, player group is commander team, and local funds cover `_currentFee`. |
| `Client/GUI/GUI_Menu_Tactical.sqf:463-499` | On map click, client debits local funds, creates a local marker object and spawns `NukeIncoming`. |
| `Client/Module/Nuke/nukeincoming.sqf:7-23` | Client sleeps for impact time, creates a cruise object locally and sends `["RequestSpecial", ["ICBM", sideJoined, _target, _cruise, clientTeam]]`. |
| `Server/Functions/Server_HandleSpecial.sqf:97-111` | Server trusts `_side`, `_base`, `_target` and `_playerTeam`; after `_target` dies or nulls, it runs `[_base] Spawn NukeDammage`. |
| `Client/Module/Nuke/damage.sqf:13-34` | `NukeDammage` uses the supplied object as the impact center, finds nearby objects with `nearestObjects [_target, [], ICBM_DAMAGE_RADIUS]`, damages almost everything and starts radiation. |
| `Deep-Review-Findings.md` DR-27 | Canonical finding record for the exploit and its campaign-level impact. |

## Current Trust Boundary

The UI path has local affordance checks, but those checks are not server authority. `GUI_Menu_Tactical.sqf:252-260` is useful UX: it hides the button unless the player appears to be the commander, has the ICBM upgrade and can afford the fee. A forged PVF does not have to use that UI path.

The unsafe boundary is the server's `"ICBM"` case in `Server_HandleSpecial.sqf:97-111`:

- `_side` is accepted from payload;
- `_base` is accepted from payload and later becomes the `NukeDammage` center;
- `_target` is accepted from payload and is only used as a timing gate;
- `_playerTeam` is accepted from payload and used for logging;
- there is no server commander check, upgrade check, funds check, cooldown/idempotency guard, target-shape check or range/side ownership check.

`waitUntil {!alive _target || isNull _target}` is timing, not authority. A forged client can choose or create a disposable object for `_target`, then satisfy the wait by killing/deleting it.

## Safe Patch Shape

Patch the server branch first. Keep client markers/messages as presentation until the server accepts the request.

1. Treat `RequestSpecial` `"ICBM"` as an untrusted request.
2. Include requester context in the payload if possible, for example the player object or team object. Arma 2 OA PVEHs do not provide a clean sender identity, so validate hints against server-known state.
3. Re-derive side from server-known requester/team state; do not trust the payload `_side`.
4. Verify requester side is west/east and that `commanderTeam` for that side matches the requester group.
5. Verify `WFBE_C_MODULE_WFBE_ICBM > 0` and `!IS_air_war_event`.
6. Verify the side's `WFBE_UP_ICBM` level is > 0 from server-held upgrade state.
7. Verify the side/team/player can pay the server-defined fee; debit server-side once on acceptance.
8. Verify the target/impact object shape. Prefer sending a position request and creating the impact anchor server-side instead of trusting a client-created object as `_base`.
9. Add an active/cooldown guard so duplicate forged or repeated requests cannot queue multiple nukes.
10. Broadcast accepted launch presentation after server acceptance. Rejected requests should log one compact `WARNING`.

## Pseudo-SQF Direction

This is shape only, not drop-in code. Keep Arma 2 OA syntax and local helper conventions.

```sqf
case "ICBM": {
    Private ["_requester","_side","_team","_impactPos","_impactAnchor","_cost"];

    _requester = _args select 1;
    _impactPos = _args select 2;

    if (isNull _requester || !isPlayer _requester) exitWith {
        ["WARNING", "Server_HandleSpecial.sqf: rejected ICBM request with invalid requester."] Call WFBE_CO_FNC_LogContent;
    };

    _team = group _requester;
    _side = side _requester;
    if (!(_side in [west, east])) exitWith {};

    if ((_side Call WFBE_CO_FNC_GetCommanderTeam) != _team) exitWith {
        ["WARNING", Format ["Server_HandleSpecial.sqf: rejected ICBM request from non-commander team [%1].", _team]] Call WFBE_CO_FNC_LogContent;
    };

    // Re-check module, upgrade, funds/cost, active/cooldown and position bounds here.
    // Create or validate the impact anchor server-side before calling NukeDammage.
    [_impactAnchor] Spawn NukeDammage;
};
```

If no reliable `GetCommanderTeam` helper exists for this exact call shape, inspect commander state ownership in [Gameplay systems atlas](Gameplay-Systems-Atlas), [Economy authority first cut](Economy-Authority-First-Cut) and [Server authority migration map](Server-Authority-Migration-Map) before writing the patch.

## Validation

| Gate | Check |
| --- | --- |
| Static source check | `Server_HandleSpecial.sqf` no longer trusts payload `_side`, `_base`, `_target` or `_playerTeam` as final authority for `"ICBM"`. |
| Static dispatch check | `RequestSpecial` remains documented as a legitimate PVF command, but the `"ICBM"` branch has its own server validation. |
| Legit smoke | Commander with ICBM upgrade and enough funds can launch once; marker/message timing still feels correct. |
| Role negative | Non-commander, wrong-side, dead/disconnected or forged requester cannot start a nuke. |
| Upgrade/funds negative | Missing ICBM upgrade, disabled ICBM module, air-war event, insufficient funds or cooldown/active guard rejects. |
| Object/position negative | Forged disposable `_target`, forged `_base`, null/dead objects or out-of-range/invalid positions cannot produce `NukeDammage`. |
| Idempotency | Duplicate PVF submissions cannot stack multiple `waitUntil` threads or multiple damage events. |
| RPT | Rejected requests log useful `WARNING`s without hot-loop spam; accepted launch logs side/team/requester once. |
| Generated missions | Run `Tools/LoadoutManager` from a correctly named `a2waspwarfare` checkout; missing `7za` is packaging-only unless deployment packaging is required. |

## Related Pages

- [Deep-review findings](Deep-Review-Findings) DR-27
- [Hardening implementation roadmap](Hardening-Implementation-Roadmap)
- [Server authority migration map](Server-Authority-Migration-Map)
- [Networking and public variables](Networking-And-Public-Variables)
- [Modules atlas](Modules-Atlas)
- [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl)

## Continue Reading

Previous: [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) | Next: [Attack-wave authority playbook](Attack-Wave-Authority-Playbook)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
