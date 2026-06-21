# PVF Dispatch Implementation Playbook

This page turns DR-1 and DR-38 into a patch-ready guide for hardening the generic PVF dispatch layer.

Scope: Chernarus source mission first, then LoadoutManager propagation. All source paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/` unless noted. Arma 2 Operation Arrowhead 1.64 only.

Use this with [Networking and public variables](Networking-And-Public-Variables), [Hardening roadmap](Hardening-Implementation-Roadmap), [Server authority map](Server-Authority-Migration-Map), [Testing workflow](Testing-Debugging-And-Release-Workflow) and [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl).

## Status

| Item | State |
| --- | --- |
| Finding | Confirmed high live-server hardening gap: DR-1. |
| Performance note | Confirmed low/medium perf win: DR-38. |
| Current code | Branch-split: docs checkout and `origin/perf/quick-wins` still use dispatch-time `Call Compile`; current stable `origin/master@0139a346` uses `missionNamespace getVariable` plus a `CODE` type check in both maintained roots, but has no explicit PVF allowlist and still needs smoke. |
| Recommended fix | Keep the current stable namespace lookup, add/port a registered allowlist plus rejection logging where absent, and keep `Spawn`. |
| What this fixes | Arbitrary handler-string compilation and avoidable per-message recompile in generic PVF dispatch. |
| What it does not fix | Payload forgery inside legitimate handlers, missing authenticated sender context (DR-55), direct publicVariable channels outside `WFBE_PVF_*`, or missing BattlEye defense-in-depth. |

## Current Branch Matrix

Branch route `pvf-dispatcher-current-stable-closeout-2026-06-21` rechecked current stable after `origin/master` advanced to `0139a346`. Earlier Miksuu/release rows below preserve the 2026-06-13 lane evidence until those refs are fetched/rechecked in this worktree:

| Scope checked | Server dispatcher | Client dispatcher | PVF init / registry | Practical meaning |
| --- | --- | --- | --- | --- |
| Docs checkout `docs/developer-wiki-index` Chernarus and maintained Vanilla Takistan | Both roots still read `_script` from payload index `0` and run `_parameters Spawn (Call Compile _script)` at `Server/Functions/Server_HandlePVF.sqf:14`. | Both roots still run `_parameters Spawn (Call Compile _script)` at `Client/Functions/Client_HandlePVF.sqf:22`. | Both roots keep the older registry shape; no `missionNamespace getVariable _script` / `PVF_ALLOWED` guard is present in the checked dispatcher files. | Patch/port is still required if this docs/source branch becomes the code target. |
| Current stable `origin/master@0139a346` Chernarus and maintained Vanilla Takistan | Both roots read `_script` from payload index `0`, lookup `_code = missionNamespace getVariable _script` at `Server/Functions/Server_HandlePVF.sqf:14`, and spawn only when `typeName _code == "CODE"` at `:15`. | Both roots keep the headless-client destination filter, then lookup `_code = missionNamespace getVariable _script` at `Client/Functions/Client_HandlePVF.sqf:32` and spawn only when it is `CODE` at `:33`. | Current stable registers 19 server and 19 client PV command names in both maintained roots (`RequestEnqueue` at `Init_PublicVariables.sqf:22`, `RequestAIComDonate` at `:26`, `HCStat` at `:27`; client `DashboardAnnounce` at `:50`; PVEH wiring at `:56-57` and `:61-62`). `git grep` found no `PVF_ALLOWED` symbol in the checked maintained roots. | DR-1/DR-38 compile removal is source-present on current stable, but only as namespace+CODE lookup. Explicit allowlist/logging, Arma smoke, DR-55 sender authentication and direct-PV `SEND_MESSAGE` remain separate/open. |
| Miksuu upstream `miksuu/master` `b8389e74` | Same server dispatcher compile at `Server_HandlePVF.sqf:14` in both maintained roots. | Same client dispatcher compile at `Client_HandlePVF.sqf:22` in both maintained roots. | Same precompile-and-PVEH registry shape at `Init_PublicVariables.sqf:45,50`; no allowlist or `missionNamespace getVariable` dispatch guard. | No upstream rescue exists. |
| `origin/perf/quick-wins` `0076040f` | Same server dispatcher compile at `:14` in Chernarus and maintained Vanilla. | Same client dispatcher compile at `:22` in Chernarus and maintained Vanilla. | Same registry shape; Chernarus PVEH lines are `Init_PublicVariables.sqf:46,51`, Vanilla remains `:45,50`. | Performance branch does not cover DR-1/DR-38 despite this being a small perf/security patch. |
| `origin/release/2026-06-feature-bundle` `a96fdda2` | Same server dispatcher compile at `:14` in release Chernarus and release maintained Vanilla. | Release keeps headless-client destination filtering, shifting the final compile to `Client_HandlePVF.sqf:32`, but still runs `Spawn (Call Compile _script)` in both release roots. | Release PVEH lines match current master at `Init_PublicVariables.sqf:48,53`; no allowlist or `missionNamespace getVariable` dispatch guard. | Release head is not fixed; its HC client filter is adjacent behavior, not a dispatcher hardening substitute. |

The historical `89ae9dad..cf2a6d6a` delta touches the client dispatcher, `Init_PublicVariables.sqf` and `updateclient.sqf`, but not `Server_HandlePVF.sqf`. The later `cf2a6d6a..origin/master@0139a346` delta changes all six maintained PVF dispatcher/init files checked in this lane. Current stable dispatcher replacement blame is `7d60b02b4` for Chernarus and `9b49883c` for maintained Vanilla; no maintained current-stable dispatcher still matched `Call Compile _script`.

Bohemia's Community Wiki lists `missionNamespace` as introduced with Arma 2 1.00 and shows `missionNamespace getVariable` as the supported namespace lookup shape, so the recommended lookup is Arma 2 OA-compatible rather than an Arma 3 import.

## What I Read

- `Common/Init/Init_PublicVariables.sqf:9-24`, `:26-44`, `:46-54`
- `Server/Functions/Server_HandlePVF.sqf:7-14`
- `Client/Functions/Client_HandlePVF.sqf:7-32`
- `Common/Functions/Common_SendToServer.sqf:12-18`
- `Common/Functions/Common_SendToServerOptimized.sqf:12-18`
- `Common/Functions/Common_SendToClient.sqf:13-21`
- `Common/Functions/Common_SendToClients.sqf:12-19`
- `Client/Module/supplyMission/supplyMissionCompletedMessage.sqf:22`
- Current stable `origin/master@0139a346` maintained-root dispatcher proof: Chernarus `Server_HandlePVF.sqf:14-15`, `Client_HandlePVF.sqf:32-33`; Vanilla `Server_HandlePVF.sqf:14-15`, `Client_HandlePVF.sqf:32-33`; no `PVF_ALLOWED` hits in the checked maintained roots.
- [Deep-review findings](Deep-Review-Findings) DR-1 and DR-38
- [Networking and public variables](Networking-And-Public-Variables), especially direct-PV and residual authority sections
- [Server authority map](Server-Authority-Migration-Map) PVF dispatch row
- [Hardening roadmap](Hardening-Implementation-Roadmap) P0 PVF section
- Bohemia Interactive `missionNamespace` page, which lists it as an Arma 2 OA scripting command and demonstrates `missionNamespace getVariable`: https://community.bistudio.com/wiki/missionNamespace

## What The Code Actually Does

`Init_PublicVariables.sqf` builds two command arrays. The server command list includes `RequestVehicleLock`, `RequestChangeScore`, `RequestStructure`, `RequestDefense`, `RequestJoin`, `RequestSpecial`, `RequestUpgrade` and related server handlers at `:9-23`. The current client command list has 15 active entries at `:25-40`: `AllCampsCaptured`, `AwardBounty`, `AwardBountyPlayer`, `CampCaptured`, `ChangeScore`, `HandleSpecial`, `LocalizeMessage`, `SetTask`, `SetVehicleLock`, `TownCaptured`, `SetMHQLock`, `Available`, `RequestBaseArea`, `HandleParatrooperMarkerCreation` and `NukeIncoming`. `DatabaseDebug` is still commented at `:30` and is not active.

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

On docs checkout, `origin/perf/quick-wins` and the older Miksuu/release evidence rows above, the dispatchers compile the string from the payload on every message:

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

Current stable `origin/master@0139a346` has already replaced that final dispatch in both maintained roots with namespace lookup plus a `CODE` type check:

```sqf
// Server_HandlePVF.sqf:14-15; Client_HandlePVF.sqf:32-33
_code = missionNamespace getVariable _script;
if (!(isNil "_code") && {typeName _code == "CODE"}) then {_parameters Spawn _code};
```

## Why It Matters

DR-1 is the security boundary: on old-shape branches the receiver compiles a handler string chosen by the sender. Legitimate traffic names `SRVFNC*` or `CLTFNC*`, but those branches do not prove that before compiling.

DR-38 is the performance angle: the compile is also redundant. Registered handlers were already compiled at init, so dispatch-time `Call Compile _script` is just doing a variable lookup in the slowest and riskiest way. Current stable removes that compile cost, but a plain namespace lookup can still resolve any global `CODE` variable named by a forged payload; an explicit registered allowlist is the remaining DR-1 closeout.

The source-backed opportunity is unusually clean: one bounded patch can close the arbitrary handler-string compilation class and remove per-message recompilation without changing legitimate PVF payload shape.

## Implementation Shape

Patch all three files together on old-shape branches. On current stable `origin/master@0139a346`, the dispatcher lookup part is already present; finish with the allowlist/logging portion before treating the lane as fully hardened.

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
| Missing authenticated sender context | No | DR-55: `Init_PublicVariables.sqf:51-53` forwards only the public-variable value into `WFBE_SE_FNC_HandlePVF`, and `Server_HandlePVF.sqf:9-14` forwards only handler parameters. |
| Direct publicVariable channel outside PVF | No | `ATTACK_WAVE_INIT`, side-supply temp PVs, supply mission PVs, MASH marker relay, HQ state channels. |
| BattlEye defense-in-depth | No | Repo `BattlEyeFilter/publicvariable.txt` still only ships the `kickAFK` feature rule. |

After this patch, a forged command name should be rejected. A forged payload sent to a real registered handler still reaches that handler and must be validated there.

## Sender Authentication Boundary

Do not treat handler-name allowlisting as full PVF hardening. DR-55 found that the server PVEH registration calls `(_this select 1) Spawn WFBE_SE_FNC_HandlePVF`, so the dispatcher receives the value tuple without the publisher identity. The server dispatcher then selects `_script` and `_parameters` and spawns the handler, which leaves legitimate handlers unable to distinguish a real requester from a forged client payload unless each handler re-derives authority from trusted server state.

The DR-55 lane belongs in [Server authority migration map](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix) and `agent-hardening-backlog.jsonl#pvf-handler-sender-authentication`: carry authenticated requester context to the server handler layer, then validate side, commander/team role, funds, target objects and ownership per handler.

## Direct PublicVariable Boundary

Do not claim this patch hardens all public variables.

The generic PVF dispatcher only handles variables registered as `WFBE_PVF_<Command>` in `Init_PublicVariables.sqf`. DR-41 proved a separate surface: `ATTACK_WAVE_INIT` is a direct `publicVariableServer` channel and is not routed through `Server_HandlePVF.sqf` at all. Its fix is [Attack-wave authority playbook](Attack-Wave-Authority-Playbook): re-derive side supply server-side, validate requester/side, deduct cost server-side and clamp the resulting modifier/duration.

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
3. Forged `ATTACK_WAVE_INIT` is unchanged by this patch; validate that under [Attack-wave authority playbook](Attack-Wave-Authority-Playbook).

## Handoff

Future code owner:

1. Implement this as branch `hardening/pvf-dispatch`.
2. Edit the Chernarus source mission first.
3. Run `Tools/LoadoutManager` after mission edits so vanilla Takistan receives the source change.
4. Record validation in [Testing workflow](Testing-Debugging-And-Release-Workflow) terms. Source-only review is useful but does not prove hosted/dedicated/JIP behavior.
5. After merge, update [Feature status](Feature-Status-Register), [Hardening roadmap](Hardening-Implementation-Roadmap), [Server authority map](Server-Authority-Migration-Map), [Codebase coverage ledger](Codebase-Coverage-Ledger), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl), [`agent-context.json`](agent-context.json) and [Agent worklog](Agent-Worklog).

Codex or Claude follow-up:

- Review the allowlist patch before merge for Arma 2 OA syntax and hosted/dedicated path preservation.
- Then move to P0 `ICBM RequestSpecial` or P1 attack-wave authority; those are per-handler/direct-channel authority fixes and should not be bundled into the dispatcher patch.

## Continue Reading

Previous: [Server authority map](Server-Authority-Migration-Map) | Next: [Attack-wave authority playbook](Attack-Wave-Authority-Playbook)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
