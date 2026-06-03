# ICBM Authority Playbook

This is the implementation handoff for the P0 `icbm-requestspecial-authority` lane. Treat it as Arma 2 OA / Combined Operations 1.64 mission SQF only; do not import Arma 3 `remoteExec` sender patterns.

Scope: patch source Chernarus first, then propagate generated Vanilla Takistan with `Tools/LoadoutManager`. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## Current Finding

The ICBM path is still client-authoritative. The Tactical menu gates the action locally, debits local funds, creates a local marker/base object, then sends `RequestSpecial ["ICBM", ...]`. The server handler trusts that payload, waits for the client-supplied cruise target to die, and spawns server-side nuke damage at the client-supplied base object.

| Surface | Evidence | Risk |
| --- | --- | --- |
| Client UI gate | `Client/GUI/GUI_Menu_Tactical.sqf:253-259` checks module enablement, commander group, ICBM upgrade and local funds before enabling the button. | UI gate only; a forged PVF bypasses it. |
| Client debit/object creation | `Client/GUI/GUI_Menu_Tactical.sqf:463-500` debits `_currentFee` locally, creates `"HeliHEmpty"` at the clicked map position, creates local marker/message effects and spawns `NukeIncoming`. | Spend and target marker are client-side affordances, not authority. |
| Server-bound request | `Client/Module/Nuke/nukeincoming.sqf:23` sends `["RequestSpecial", ["ICBM", sideJoined, _target, _cruise, clientTeam]]`. | Payload carries side, target/base objects and team from the client. |
| Registered PVF | `Common/Init/Init_PublicVariables.sqf:18` registers `RequestSpecial`; `Server/PVFunctions/RequestSpecial.sqf:1` is `_this Spawn HandleSpecial;`. | Legitimate PVF command with high-risk sub-tags; dispatcher allowlisting alone will not validate payload authority. |
| Server effect | `Server/Functions/Server_HandleSpecial.sqf:97-111` reads `_side`, `_base`, `_target`, `_playerTeam`, logs, waits for `_target` death, then runs `[_base] Spawn NukeDammage`. | No server-side commander, side, upgrade, funds, target validity or cooldown validation is visible before damage. |
| Damage function | `Common/Init/Init_Common.sqf:319` loads `Client\Module\Nuke\ICBM_Init.sqf` when enabled; `ICBM_Init.sqf:12-14` compiles `NukeDammage` on the server from `Client\Module\Nuke\damage.sqf`; `damage.sqf:14-34` damages nearby objects and spawns radiation. | The function path is under `Client/Module`, but the destructive effect is server-side once `HandleSpecial` calls it. |

## Safe Implementation Shape

1. Change the request shape only as much as needed to give the server a verifiable requester anchor. In OA publicVariable/PVF handlers there is no hidden trusted remote sender, so do not rely on `_remoteSender`, `remoteExecutedOwner` or `isRemoteExecuted`.
2. In the `"ICBM"` case, reject malformed payloads before any wait or damage spawn.
3. Re-derive requester side/team/commander authority from server-owned state. The client-provided `_side` and `clientTeam` should be treated as hints until validated.
4. Validate module enablement, air-war exclusion, side upgrade level (`WFBE_UP_ICBM`), dependencies and funds/supply cost on the server.
5. Debit the accepted cost on the server, or reject without side effects.
6. Validate target/base objects: non-null, alive where expected, sane type, side-legal target position and not a stale object supplied by a forged client.
7. Log compact `WARNING` records for rejected requests and keep the existing `INFORMATION` log only for accepted launches.
8. Keep client marker, message and sound behavior as presentation; do not let those presentation effects prove server acceptance.

## Validation Plan

| Gate | Checks |
| --- | --- |
| Source-only | `RequestSpecial` still dispatches valid tags; `"ICBM"` rejects malformed shape; accepted path uses server-derived side/team/commander/funds/upgrade state. |
| Negative smoke | Forged non-commander, wrong-side, missing-upgrade, unaffordable, null-object and stale-object requests do not call `NukeDammage`. |
| Positive smoke | Valid commander launch still creates warning UX, missile/cruise sequence, damage and radiation at the intended target. |
| Economy smoke | Accepted launch debits exactly once server-side; rejected launch does not debit. |
| Multiplayer smoke | Dedicated and hosted/listen behavior match; JIP clients do not infer accepted launches from stale local markers alone. |
| Generated mission | Run LoadoutManager after source patch and inspect generated Vanilla Takistan diff. Modded Napf/eden/lingor remain separate owner decisions because they are divergent forks. |

## Coordination Notes

- This is not the same as the generic PVF dispatcher fix. The dispatcher allowlist should block arbitrary handler strings, but the ICBM `"RequestSpecial"` tag still needs its own server authority validation.
- BattlEye `publicvariable.txt` can be defense-in-depth, but the repo only proves the AFK publicVariable rule as shipped. Do not call the ICBM path hardened until server-side validation exists or production BattlEye filters are actually supplied and documented.
- `NukeDammage` is intentionally spelled that way in source; keep the existing symbol unless a code-owner refactor explicitly updates all references.

## Continue Reading

Finding: [Deep-review findings](Deep-Review-Findings) DR-27 | Dispatcher: [PVF dispatch implementation playbook](PVF-Dispatch-Implementation-Playbook) | Status: [Feature status register](Feature-Status-Register)
