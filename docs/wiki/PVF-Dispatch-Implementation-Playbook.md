# PVF Dispatch Implementation Playbook

This page turns DR-1 and DR-38 into a patch-ready guide for hardening the generic PVF dispatch layer.

Scope: Chernarus source mission first, then LoadoutManager propagation. All source paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/` unless noted. Arma 2 Operation Arrowhead 1.64 only.

Use this with [Networking and public variables](Networking-And-Public-Variables), [Implementation plan](Documentation-Implementation-Plan), [Tools and build workflow](Tools-And-Build-Workflow), and the refreshed [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) entry `pvf-dispatch-lookup`.

## Status

| Item | State |
| --- | --- |
| Finding | Confirmed high live-server hardening gap: DR-1. |
| Performance note | Confirmed low/medium perf win: DR-38. |
| Current code | Still uses dispatch-time `Call Compile` on sender-chosen handler names. |
| Recommended fix | Registered allowlist plus `missionNamespace getVariable` lookup; keep `Spawn`. |
| What this fixes | Arbitrary handler-string compilation and avoidable per-message recompile in generic PVF dispatch. |
| What it does not fix | Payload forgery inside legitimate handlers, direct publicVariable channels outside `WFBE_PVF_*`, or missing BattlEye defense-in-depth. |

## What I Read

- `Common/Init/Init_PublicVariables.sqf:9-23`, `:25-41`, `:43-50`
- `Server/Functions/Server_HandlePVF.sqf:7-14`
- `Client/Functions/Client_HandlePVF.sqf:7-22`
- `Common/Functions/Common_SendToServer.sqf:12-17`
- `Common/Functions/Common_SendToServerOptimized.sqf:12-17`
- `Common/Functions/Common_SendToClient.sqf:13-20`
- `Common/Functions/Common_SendToClients.sqf:12-18`
- [Deep-review findings](Deep-Review-Findings) DR-1 and DR-38
- [Networking and public variables](Networking-And-Public-Variables), especially direct-PV and residual authority sections
- [Implementation plan](Documentation-Implementation-Plan) hardening/workstream notes
- [Feature status](Feature-Status-Register) PV dispatch trust-boundary row
- Bohemia Interactive `missionNamespace` and `getVariable` pages, which list namespace variable lookup as available in Arma 2 OA and show `missionNamespace getVariable`: https://community.bohemia.net/wiki/missionNamespace and https://community.bohemia.net/wiki/getVariable
- Bohemia Interactive `isEqualTo` page, which marks that comparison command as introduced with Arma 3; this playbook deliberately uses an allowlist plus `typeName` instead: https://community.bohemia.net/wiki/isEqualTo

## What The Code Actually Does

`Init_PublicVariables.sqf` builds two command arrays. The server command list includes `RequestVehicleLock`, `RequestChangeScore`, `RequestStructure`, `RequestDefense`, `RequestJoin`, `RequestSpecial`, `RequestUpgrade` and related server handlers at `:9-23`. The client command list includes `AllCampsCaptured`, `AwardBounty`, `CampCaptured`, `HandleSpecial`, `LocalizeMessage`, `SetVehicleLock`, `TownCaptured`, `RequestBaseArea` and `NukeIncoming` at `:25-41`.

The same file already compiles every registered command into global code variables:

```sqf
Call Compile Format["CLTFNC%1 = compile preprocessFileLineNumbers 'Client\PVFunctions\%1.sqf'", _x];
Call Compile Format["SRVFNC%1 = compile preprocessFileLineNumbers 'Server\PVFunctions\%1.sqf'", _x];
```

It also registers one `WFBE_PVF_<Command>` event handler per command. Client PVF variables call `WFBE_CL_FNC_HandlePVF`; server PVF variables call `WFBE_SE_FNC_HandlePVF`.

The send helpers rewrite a logical command name into one of those compiled function variable names:

- server-bound helpers set payload index `0` to `SRVFNC<Command>`;
- client-bound helpers set payload index `1` to `CLTFNC<Command>`;
- dedicated/multiplayer branches publish `WFBE_PVF_<Command>`;
- hosted branches call the same handler locally with `Spawn WFBE_*_FNC_HandlePVF`.

The dispatchers then compile the string from the payload on every message:

```sqf
// Server_HandlePVF.sqf:11-14
_script = _publicVar select 0;
_parameters = if (count _publicVar > 1) then {_publicVar select 1} else {[]};
_parameters Spawn (Call Compile _script);

// Client_HandlePVF.sqf:19-22, after destination filtering
_script = _publicVar select 1;
_parameters = if (count _this > 2) then {_publicVar select 2} else {[]};
_parameters Spawn (Call Compile _script);
```

## Why It Matters

DR-1 is the security boundary: the receiver compiles a handler string chosen by the sender. Legitimate traffic names `SRVFNC*` or `CLTFNC*`, but the current dispatcher does not prove that before compiling.

DR-38 is the performance angle: the compile is also redundant. Registered handlers were already compiled at init, so dispatch-time `Call Compile _script` is just doing a variable lookup in the slowest and riskiest way.

The source-backed opportunity is unusually clean: one bounded patch can close the arbitrary handler-string compilation class and remove per-message recompilation without changing legitimate PVF payload shape.

## Implementation Shape

Patch all three files together.

### 1. Export allowlists at PVF init

In `Common/Init/Init_PublicVariables.sqf`, create mission globals for the compiled handler names. The exact names are owner choice; keep them clear and side-specific.

```sqf
WFBE_CL_PVF_ALLOWED = [];
WFBE_SE_PVF_ALLOWED = [];

{
    Call Compile Format["CLTFNC%1 = compile preprocessFileLineNumbers 'Client\PVFunctions\%1.sqf'", _x];
    WFBE_CL_PVF_ALLOWED = WFBE_CL_PVF_ALLOWED + [Format["CLTFNC%1", _x]];
    if (!isServer || local player) then {Format['WFBE_PVF_%1',_x] addPublicVariableEventHandler {(_this select 1) Spawn WFBE_CL_FNC_HandlePVF}};
} forEach _clientCommandPV;

{
    Call Compile Format["SRVFNC%1 = compile preprocessFileLineNumbers 'Server\PVFunctions\%1.sqf'", _x];
    WFBE_SE_PVF_ALLOWED = WFBE_SE_PVF_ALLOWED + [Format["SRVFNC%1", _x]];
    if (isServer) then {Format['WFBE_PVF_%1',_x] addPublicVariableEventHandler {(_this select 1) Spawn WFBE_SE_FNC_HandlePVF}};
} forEach _serverCommandPV;
```

Why not only `getVariable`? A plain namespace lookup prevents arbitrary SQF text from being compiled, but it could still resolve another global `CODE` variable if a forged payload names it. The allowlist limits dispatch to exactly the registered PVF handlers.

Arma 2 OA syntax guardrail: do not use `isEqualTo`, `params`, `remoteExec`, `remoteExecCall`, `BIS_fnc_MP`, `parseSimpleArray` or CBA helpers in this patch unless an official OA command page proves availability. `missionNamespace getVariable _script` plus `typeName _handler != "CODE"` is the intended OA-safe shape.

### 2. Harden the server dispatcher

Replace the final `Call Compile` line in `Server/Functions/Server_HandlePVF.sqf` with allowlist membership and namespace lookup.

```sqf
Private ["_handler","_parameters","_publicVar","_script"];

_publicVar = _this;

_script = _publicVar select 0;
_parameters = if (count _publicVar > 1) then {_publicVar select 1} else {[]};

if !(_script in WFBE_SE_PVF_ALLOWED) exitWith {
    ["WARNING", Format ["Server_HandlePVF: rejected unregistered PVF handler [%1].", _script]] Call WFBE_CO_FNC_LogContent;
};

_handler = missionNamespace getVariable _script;
if (typeName _handler != "CODE") exitWith {
    ["WARNING", Format ["Server_HandlePVF: registered PVF handler [%1] is not CODE.", _script]] Call WFBE_CO_FNC_LogContent;
};

_parameters Spawn _handler;
```

### 3. Harden the client dispatcher

Keep the destination filter intact. Replace only the final dispatch in `Client/Functions/Client_HandlePVF.sqf`.

```sqf
_script = _publicVar select 1;
_parameters = if (count _this > 2) then {_publicVar select 2} else {[]};

if !(_script in WFBE_CL_PVF_ALLOWED) exitWith {
    ["WARNING", Format ["Client_HandlePVF: rejected unregistered PVF handler [%1].", _script]] Call WFBE_CO_FNC_LogContent;
};

_handler = missionNamespace getVariable _script;
if (typeName _handler != "CODE") exitWith {
    ["WARNING", Format ["Client_HandlePVF: registered PVF handler [%1] is not CODE.", _script]] Call WFBE_CO_FNC_LogContent;
};

_parameters Spawn _handler;
```

### 4. Keep `Spawn`

Do not convert dispatch to `Call` in this patch. Existing PVF functions are scheduled through `Spawn`; some handlers or downstream calls may sleep, wait or spawn their own work. Changing scheduling semantics belongs to a separate handler-by-handler audit.

## Boundary: Dispatcher Hardening Vs Authority Validation

This patch is the PVF foundation, not the whole server-authority migration.

| Layer | Fixed by this playbook? | Example |
| --- | --- | --- |
| Sender-chosen arbitrary handler string | Yes | Forged payload trying to compile arbitrary SQF text instead of `SRVFNCRequestJoin`. |
| Avoidable per-message compile | Yes | `Server_HandlePVF.sqf:14`, `Client_HandlePVF.sqf:22`. |
| Legitimate handler with forged payload | No | `RequestSpecial` `ICBM` branch, `RequestStructure`, `RequestUpgrade`, `RequestChangeScore`. |
| Direct publicVariable channel outside PVF | No | `ATTACK_WAVE_INIT`, side-supply temp PVs, supply mission PVs, MASH marker relay, HQ state channels. |
| BattlEye defense-in-depth | No | Repo `BattlEyeFilter/publicvariable.txt` still only ships the `kickAFK` feature rule. |

After this patch, a forged command name should be rejected. A forged payload sent to a real registered handler still reaches that handler and must be validated there.

### Registered Server Handler Payload Drilldown

Use this table after the dispatcher allowlist patch. It maps the highest-risk registered server-bound PVF handlers by payload trust and mutation surface; it does not replace the focused DR pages or economy playbooks.

| Handler family | Payload trust / mutation notes | Current source route |
| --- | --- | --- |
| Construction and HQ repair: `RequestStructure`, `RequestDefense`, `RequestMHQRepair` | Client payload supplies side, class, position, direction and manning/HQ-repair side. Server checks class membership only, then starts construction / defense creation / MHQ repair without re-deriving commander role, funds/supply, base area, side ownership or object eligibility. | `Client/Module/CoIn/coin_interface.sqf:494`, `:718`, `:722`; `Client/Action/Action_RepairMHQ.sqf:35`; `Server/PVFunctions/RequestStructure.sqf:3-22`; `RequestDefense.sqf:2-10`; `RequestMHQRepair.sqf:1`; DR-6. |
| `RequestSpecial` multiplexer | One legitimate PVF command carries many unrelated effects. High-risk cases include nuke/ICBM damage, supply-truck respawn, camp repair, HQ-killed processing, group changes, upgrade sync, HC/delegation state and UAV/paradrop requests. Payload tag and arguments are trusted by `Server_HandleSpecial`; per-tag validation is the actual hardening unit. | `Server/PVFunctions/RequestSpecial.sqf:1`; `Server/Functions/Server_HandleSpecial.sqf:5-170`; ICBM caller `Client/Module/Nuke/nukeincoming.sqf:23`; upgrade-sync caller `Client/GUI/GUI_UpgradeMenu.sqf:171`; DR-27 / DR-20 / DR-39. |
| Upgrade purchase: `RequestUpgrade` plus `upgrade-sync` | Client debits local funds and side supply, then asks the server to process `[side, upgrade id, current level, true]`; server starts the upgrade timer and increments replicated side upgrade state without commander/funds/dependency/sequence validation or server-side debit. Client later sends `RequestSpecial ["upgrade-sync", ...]` to release the sync variable. | `Client/GUI/GUI_UpgradeMenu.sqf:158-172`; `Server/PVFunctions/RequestUpgrade.sqf:5`; `Server/Functions/Server_ProcessUpgrade.sqf:12-47`; `Server/Functions/Server_HandleSpecial.sqf:67-74`; DR-23. |
| Score mutation: `RequestChangeScore` and kill/HQ award callers | Handler sets a player's absolute score from payload by removing current score and adding the supplied value, then broadcasts `ChangeScore`. Legitimate callers include town/camp capture, upgrade score, supply mission score, unit kill and HQ kill; forged payloads can choose player and score unless a future handler validates the event source/award. | `Server/PVFunctions/RequestChangeScore.sqf:3-13`; `Server/PVFunctions/RequestOnUnitKilled.sqf:77-81`; `Server/Functions/Server_OnHQKilled.sqf:49`; client callers in `Client/PVFunctions/TownCaptured.sqf:71-79`, `CampCaptured.sqf:38`, `Client/Functions/Client_FNC_Special.sqf:118`, `Client/Module/supplyMission/supplyMissionCompletedMessage.sqf:32`; DR-20. |
| Commander/vote PVFs: `RequestCommanderVote`, `RequestNewCommander` | Client supplies side/name or side/assigned commander. Vote request only checks `wfbe_votetime <= 0`; new-commander request writes `wfbe_commander`, spawns assignment and broadcasts the result. DR-15 is the downstream call-shape bug in `Server_AssignNewCommander`, but the PVF payload also needs role/requester validation before a public-server hardening claim. | `Client/GUI/GUI_Menu.sqf:75-91`; `Client/GUI/GUI_Commander_VoteMenu.sqf:46`; `Server/PVFunctions/RequestCommanderVote.sqf:3-22`; `RequestNewCommander.sqf:3-16`; DR-15. |
| Team/order mutation: `RequestTeamUpdate` | Client supplies a team array or whole side plus behavior/combat/formation/speed values. Server applies those values directly to each target group or every team for that side. Treat as commander-authority/order-surface validation, not economy authority. | `Client/GUI/GUI_Menu_Command.sqf:425-428`; `Server/PVFunctions/RequestTeamUpdate.sqf:3-26`. |
| Vehicle lock and auto-wall toggles: `RequestVehicleLock`, `RequestAutoWallConstructinChange` | Vehicle lock applies payload object/locked state and rebroadcasts. Auto-wall toggles global `isAutoWallConstructingEnabled` from a client boolean and replies to the supplied player. These are smaller blast-radius than economy/superweapon paths but still legitimate-command payload trust. | `Client/Action/Action_ToggleMHQLock.sqf:15`; `Client/Module/Skill/Skill_SpecOps.sqf:52`; `Client/Module/CoIn/coin_interface.sqf:217`; `Server/PVFunctions/RequestVehicleLock.sqf:3-8`; `RequestAutoWallConstructinChange.sqf:3-7`. |
| Join handshake: `RequestJoin` | Server derives UID/name from the player object and checks remembered side-at-launch/JIP side plus AntiStack skill scores. It still trusts the payload's player/side pair enough to perform the join decision; keep it in robustness testing, but it is not in the same spend/effect class as construction, upgrade, ICBM or score. | `Server/PVFunctions/RequestJoin.sqf:3-91`; `Client/Init/Init_Client.sqf:367-502`; DR-37. |

Hardening order should follow blast radius: `RequestSpecial` ICBM/effect tags and construction/economy mutations first, then upgrade/score/commander/team-order surfaces. The dispatcher allowlist can land independently, but do not describe the PVF layer as authorized until these payload checks exist.

## Direct PublicVariable Boundary

Do not claim this patch hardens all public variables.

The generic PVF dispatcher only handles variables registered as `WFBE_PVF_<Command>` in `Init_PublicVariables.sqf`. DR-41 proved a separate surface: `ATTACK_WAVE_INIT` is a direct `publicVariableServer` channel and is not routed through `Server_HandlePVF.sqf` at all. Its fix is tracked in [Networking](Networking-And-Public-Variables#authority-surfaces-to-audit-together) and [Economy](Economy-Towns-And-Supply#authority-model): re-derive side supply server-side, validate requester/side, deduct cost server-side and clamp the resulting modifier/duration.

Other direct-channel families remain separate review targets in [Networking and public variables](Networking-And-Public-Variables): side supply temps, supply mission PVs, MASH marker relay, HQ state, AntiStack compensation, day/night, server FPS, AFK and marker/message channels.

## Validation Plan

Source-only checks:

1. Confirm `WFBE_SE_PVF_ALLOWED` contains one `SRVFNC*` name for every `_serverCommandPV` entry.
2. Confirm `WFBE_CL_PVF_ALLOWED` contains one `CLTFNC*` name for every `_clientCommandPV` entry.
3. Confirm every allowlisted name resolves to `typeName == "CODE"` after `Init_PublicVariables.sqf`.
4. Confirm `Server_HandlePVF.sqf` and `Client_HandlePVF.sqf` no longer contain `Spawn (Call Compile _script)`.
5. Confirm no new Arma 3-only syntax such as `isEqualTo`, `params`, `remoteExec`, `BIS_fnc_MP` or CBA helpers was introduced.

Hosted/local smoke:

1. Start a hosted mission.
2. Verify `RequestJoin` still completes and the join-answer path reaches the player.
3. Toggle a vehicle or MHQ lock, or perform another small `RequestVehicleLock` flow.
4. Trigger one client-bound message such as `LocalizeMessage` or `HandleSpecial`.
5. Inject or temporarily call a bogus handler name in a test-only path and confirm it logs one `WARNING` and no-ops.

Dedicated smoke:

1. Repeat one server-bound PVF (`RequestJoin` or `RequestVehicleLock`).
2. Repeat one server-to-client PVF (`LocalizeMessage`, `SetVehicleLock` or `HandleSpecial`).
3. Watch the RPT for rejected-handler spam. Legitimate traffic should not hit the warning path.
4. JIP sanity: late joiner still passes the existing RequestJoin and post-join state sync chain. DR-37 already marks PVF event replay as separate from durable state sync.

Security/authority negative checks:

1. Forged unregistered handler name should no-op and log.
2. Forged registered handler with bad payload may still execute the handler; record it under the relevant per-handler authority item, not as a PVF dispatch regression.
3. Forged `ATTACK_WAVE_INIT` is unchanged by this patch; validate that under [Networking](Networking-And-Public-Variables#authority-surfaces-to-audit-together) and [Economy](Economy-Towns-And-Supply#authority-model).

## Handoff

Future code owner:

1. Implement this as branch `hardening/pvf-dispatch`.
2. Edit the Chernarus source mission first.
3. Run `Tools/LoadoutManager` after mission edits so vanilla Takistan receives the source change.
4. Record validation in [Tools and build workflow](Tools-And-Build-Workflow) terms. Source-only review is useful but does not prove hosted/dedicated/JIP behavior.
5. After merge, update [Feature status](Feature-Status-Register), [Implementation plan](Documentation-Implementation-Plan), [Codebase coverage ledger](Codebase-Coverage-Ledger), [`agent-context.json`](agent-context.json), [Agent worklog](Agent-Worklog) and any refreshed backlog file that has been made active again.

Codex or Claude follow-up:

- Review the allowlist patch before merge for Arma 2 OA syntax and hosted/dedicated path preservation.
- Then move to P0 `ICBM RequestSpecial` or P1 attack-wave authority; those are per-handler/direct-channel authority fixes and should not be bundled into the dispatcher patch.

## Continue Reading

Previous: [Networking and public variables](Networking-And-Public-Variables) | Next: [Economy authority model](Economy-Towns-And-Supply#authority-model)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
