# PVF Dispatch Implementation Playbook

This page turns DR-1 and DR-38 into a patch-ready guide for hardening the generic PVF dispatch layer.

Scope: Chernarus source mission first, then LoadoutManager propagation. All source paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/` unless noted. Arma 2 Operation Arrowhead 1.64 only.

Use this with [Networking and public variables](Networking-And-Public-Variables), [Hardening roadmap](Hardening-Implementation-Roadmap), [Server authority map](Server-Authority-Migration-Map), [Testing workflow](Testing-Debugging-And-Release-Workflow) and [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl).

## Status

| Item | State |
| --- | --- |
| Finding | Confirmed high live-server hardening gap: DR-1. |
| Performance note | Confirmed low/medium perf win: DR-38. |
| Current code | Branch-split: current stable/B74.1 `origin/master@f8a76de34` / `origin/claude/b74.1-aicom@f8a76de34`, current B69 `origin/claude/b69@8d465fce` and adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` Chernarus plus maintained Vanilla use `missionNamespace getVariable _script` plus a `typeName == "CODE"` guard in both PVF dispatchers; old docs/Miksuu/perf/historical refs still use dispatch-time `Call Compile`. |
| Remaining dispatcher fix | Add registered `SRVFNC*` / `CLTFNC*` allowlists and rejection logging before calling the current lookup fully hardened; backport the namespace lookup to old branches that still use `Call Compile`. |
| What current stable fixes | Dispatch-time arbitrary SQF-text compilation and avoidable per-message recompilation in the generic PVF dispatch. |
| What remains in this layer | Forged payloads can still name any existing global `CODE` value unless a registered-handler allowlist is added; bad names silently no-op instead of logging. |
| What it does not fix | Payload forgery inside legitimate handlers, missing authenticated sender context (DR-55), direct publicVariable channels outside `WFBE_PVF_*`, or missing BattlEye defense-in-depth. |

## Current Branch Matrix

Branch routes `pvf-dispatcher-current-stable-closeout-2026-06-21`, `pvf-dispatch-current-stable-partial-closeout`, `pvf-sender-auth-current-b69-head-refresh-2026-06-22` and `pvf-dispatch-current-b74-refresh-2026-06-22` rechecked the generic PVF dispatcher across maintained roots and active candidate branches after `origin/master` advanced to `0139a346`, B69 advanced to `8d465fce` and adjacent B74 appeared at `b23f557f`; current `origin` exposes no `release/*`, `feat/*pvf*`, `feat/*network*`, `feat/*auth*` or `feat/*public*` heads on 2026-06-22:

| Scope checked | Server dispatcher | Client dispatcher | PVF init / registry | Practical meaning |
| --- | --- | --- | --- | --- |
| Docs checkout `HEAD@925d56e01a1e` Chernarus and maintained Vanilla Takistan | Both roots still read `_script` from payload index `0` and run `_parameters Spawn (Call Compile _script)` at `Server/Functions/Server_HandlePVF.sqf:14`. | Both roots still run `_parameters Spawn (Call Compile _script)` at `Client/Functions/Client_HandlePVF.sqf:22`. | Both roots keep the older registry shape; no `missionNamespace getVariable _script` / `PVF_ALLOWED` guard is present in the checked dispatcher files. The checked PVF paths are unchanged from `a0721301d4f5`. | Patch/port is still required if this docs/source branch becomes the code target. |
| Current `origin/master@f8a76de34` / `origin/claude/b74.1-aicom@f8a76de34` Chernarus and maintained Vanilla Takistan | Both roots read `_script` from payload index `0`, resolve `_code = missionNamespace getVariable _script` at `Server/Functions/Server_HandlePVF.sqf:14`, and spawn only when `typeName _code == "CODE"` at `:15`. Chernarus blame is `7d60b02b4`; maintained Vanilla propagation blame is `9b49883cb`. | Both roots keep the adjacent headless-client destination filter, then resolve `_code = missionNamespace getVariable _script` at `Client/Functions/Client_HandlePVF.sqf:32` and spawn only `CODE` at `:33`. | Both roots precompile 20 client handlers and 19 server handlers, then add PVEHs at `Common/Init/Init_PublicVariables.sqf:55-61`. No `WFBE_CL_PVF_ALLOWED`, `WFBE_SE_PVF_ALLOWED`, `PVF_ALLOWED`, allowlist, rejection-log, sender or requester guard exists in checked current dispatcher/init files. | DR-38 and the raw dispatch-time `Call Compile` part of DR-1 are source-present/fixed on current stable/B74.1; registered-handler allowlist, warning logs, Arma smoke and DR-55 sender authentication remain open. |
| Current B69 `origin/claude/b69@8d465fce` and adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` Chernarus and maintained Vanilla Takistan | Same namespace/CODE server dispatcher as current stable/B74.1 at `Server_HandlePVF.sqf:14-15` in both maintained roots. | Same namespace/CODE client dispatcher as current stable/B74.1 at `Client_HandlePVF.sqf:32-33` in both maintained roots. B69 adds a default-off `aicom-team-merge` case to `Client/PVFunctions/HandleSpecial.sqf:57` with `WFBE_C_AICOM_HC_MERGE_ENABLE` gate at `:59`; B74 has no checked dispatcher/init delta from B69. | Same value-only PVEH registration at `Init_PublicVariables.sqf:56,61`; no sender context, registered-handler allowlist or warning log was found. `git diff --name-status 0a1ccb4d..origin/claude/b69` changes only `Client/PVFunctions/HandleSpecial.sqf` among the checked PVF/PVEH paths; `git diff --name-status origin/claude/b69..origin/claude/b74-aicom-spend` and `origin/claude/b74-aicom-spend..origin/master` are empty for the checked generic PVF dispatcher/init paths. | Treat B69/B74 as branch-only evidence that dispatch lookup matches current stable/B74.1 but DR-55 remains open. The client special tag is not a sender-authentication fix. |
| Miksuu upstream `miksuu/master` `b8389e74` | Same server dispatcher compile at `Server_HandlePVF.sqf:14` in both maintained roots. | Same client dispatcher compile at `Client_HandlePVF.sqf:22` in both maintained roots. | Same precompile-and-PVEH registry shape at `Init_PublicVariables.sqf:45,50`; no allowlist or `missionNamespace getVariable` dispatch guard. | No upstream rescue exists. |
| `origin/perf/quick-wins` `0076040f` | Same server dispatcher compile at `:14` in Chernarus and maintained Vanilla. | Same client dispatcher compile at `:22` in Chernarus and maintained Vanilla. | Same registry shape; Chernarus PVEH lines are `Init_PublicVariables.sqf:46,51`, Vanilla remains `:45,50`. | Performance branch does not cover DR-1/DR-38 despite this being a small perf/security patch. |
| Current `origin` release/PVF/network/auth/public heads | Remote branch scan returned no `release/*`, `*pvf*`, `*network*`, `*auth*` or `*public*` heads on 2026-06-23. | Same. | Same. | Older `origin/release/2026-06-feature-bundle@a96fdda2` evidence is historical target-commit evidence only, not a current remote branch head. Recheck that commit explicitly if it becomes a target again. |

The current stable partial fix is split across two source commits: `7d60b02b4` changes the Chernarus dispatchers from `Spawn (Call Compile _script)` to `missionNamespace getVariable _script` plus a `CODE` guard, and `9b49883cb` propagates the same dispatcher change into maintained Vanilla Takistan. Neither commit adds a registered-handler allowlist or a rejected-handler warning log.

Bohemia's Community Wiki lists `missionNamespace` as introduced with Arma 2 1.00 and shows `missionNamespace getVariable` as the supported namespace lookup shape, so the recommended lookup is Arma 2 OA-compatible rather than an Arma 3 import.

## What I Read

- `Common/Init/Init_PublicVariables.sqf:9-29`, `:31-52`, `:54-62`
- `Server/Functions/Server_HandlePVF.sqf:7-15`
- `Client/Functions/Client_HandlePVF.sqf:7-33`
- `Common/Functions/Common_SendToServer.sqf:12-18`
- `Common/Functions/Common_SendToServerOptimized.sqf:12-18`
- `Common/Functions/Common_SendToClient.sqf:13-21`
- `Common/Functions/Common_SendToClients.sqf:12-19`
- `Client/Module/supplyMission/supplyMissionCompletedMessage.sqf:22`
- Current stable/B74.1 `origin/master@f8a76de34` / `origin/claude/b74.1-aicom@f8a76de34` maintained-root dispatcher proof: Chernarus `Server_HandlePVF.sqf:14-15`, `Client_HandlePVF.sqf:32-33`; Vanilla `Server_HandlePVF.sqf:14-15`, `Client_HandlePVF.sqf:32-33`; no `PVF_ALLOWED`/allowlist/sender/requester hits in the checked maintained-root dispatcher/init files.
- Current B69 `origin/claude/b69@8d465fce` and adjacent B74 `origin/claude/b74-aicom-spend@b23f557f` maintained-root dispatcher proof: same PVF init/dispatcher line shape as current stable at `Init_PublicVariables.sqf:56,61`, `Server_HandlePVF.sqf:14-15` and `Client_HandlePVF.sqf:32-33`; checked B69 movement since `0a1ccb4d` is `Client/PVFunctions/HandleSpecial.sqf:57,59` for the default-off `aicom-team-merge` tag, and the checked B69..B74 generic dispatcher/init delta is empty.
- [Deep-review findings](Deep-Review-Findings) DR-1 and DR-38
- [Networking and public variables](Networking-And-Public-Variables), especially direct-PV and residual authority sections
- [Server authority map](Server-Authority-Migration-Map) PVF dispatch row
- [Hardening roadmap](Hardening-Implementation-Roadmap) P0 PVF section
- Bohemia Interactive `missionNamespace` page, which lists it as an Arma 2 OA scripting command and demonstrates `missionNamespace getVariable`: https://community.bistudio.com/wiki/missionNamespace

## What The Code Actually Does

`Init_PublicVariables.sqf` builds two command arrays on current stable. The server command list has 19 active entries at `:9-27`, from `RequestVehicleLock` through `HCStat`. The client command list has 20 active entries at `:31-50`, from `AllCampsCaptured` through `DashboardAnnounce`; `DatabaseDebug` is still commented at `:36` and is not active.

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

On current stable, the dispatchers no longer compile the string from the payload. They look up the named missionNamespace value and only spawn it if it resolves to `CODE`. Docs checkout, `origin/perf/quick-wins` and the older Miksuu/release evidence rows above still use the old dispatch-time compile shape.

```sqf
// Server_HandlePVF.sqf:11-15
_script = _publicVar select 0;
_parameters = if (count _publicVar > 1) then {_publicVar select 1} else {[]};
_code = missionNamespace getVariable _script;
if (!(isNil "_code") && {typeName _code == "CODE"}) then {_parameters Spawn _code};

// Client_HandlePVF.sqf:13-33, after destination filtering
_script = _publicVar select 1;
_parameters = if (count _this > 2) then {_publicVar select 2} else {[]};
_code = missionNamespace getVariable _script;
if (!(isNil "_code") && {typeName _code == "CODE"}) then {_parameters Spawn _code};
```

This closes the dispatch-time arbitrary text compilation class on current stable/B74.1 `origin/master@f8a76de34`, but it is not the full playbook patch yet because the lookup accepts any existing global `CODE` value and silently ignores bad names. Add a registered-handler allowlist before treating dispatch as fully hardened.

## Why It Matters

DR-1 is the security boundary: the receiver runs a handler name chosen by the sender. Current stable no longer compiles that string at dispatch time, but it still does not prove the name came from the registered `SRVFNC*` / `CLTFNC*` set before spawning the resolved `CODE` value.

DR-38 is the performance angle on old branches: registered handlers were already compiled at init, so dispatch-time `Call Compile _script` was just doing a variable lookup in the slowest and riskiest way. Current stable has removed that recompile class; the remaining current-stable work is allowlisting and logging.

The source-backed opportunity is now smaller on current stable: complete the existing namespace-lookup patch with a registered-handler allowlist and logging, then smoke valid traffic and forged unregistered names. Older target branches such as Miksuu and `perf/quick-wins` still need the full `Call Compile` replacement.

## Implementation Shape

For current `origin/master`, patch the registry and both dispatchers together to add explicit allowlists and rejection logs. For older branches that still use `Call Compile`, apply the lookup replacement and the allowlist in the same pass.

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
| Avoidable per-message compile | Already resolved on master | Dispatchers use `missionNamespace getVariable` + CODE guard; no `Call Compile` at dispatch time. |
| Legitimate handler with forged payload | No | `RequestSpecial` `ICBM` branch, `RequestStructure`, `RequestUpgrade`, `RequestChangeScore`. |
| Missing authenticated sender context | No | DR-55: docs/source `HEAD@925d56e01a1e` is unchanged from `a0721301d4f5` for checked PVF init/dispatcher paths, while Miksuu `b8389e74` and perf `0076040f` forward only the public-variable value into `WFBE_SE_FNC_HandlePVF` and keep old dispatcher `Call Compile`; current stable `origin/master@f8a76de34` / B74.1, B69 `8d465fce` and B74 `b23f557f` use namespace/CODE dispatch but still pass only `(_this select 1)` at `Init_PublicVariables.sqf:56,61`, so handlers receive parameters without publisher context. |
| Direct publicVariable channel outside PVF | No | `ATTACK_WAVE_INIT`, side-supply temp PVs, supply mission PVs, MASH marker relay, HQ state channels. |
| BattlEye defense-in-depth | No | Repo `BattlEyeFilter/publicvariable.txt` still only ships the `kickAFK` feature rule. |

After this patch, a forged command name should be rejected. A forged payload sent to a real registered handler still reaches that handler and must be validated there.

## Sender Authentication Boundary

Do not treat handler-name allowlisting as full PVF hardening. DR-55 found that the server PVEH registration calls `(_this select 1) Spawn WFBE_SE_FNC_HandlePVF`, so the dispatcher receives the value tuple without the publisher identity. The 2026-06-23 current-B74.1 refresh keeps that split: current stable `origin/master@f8a76de34` equals `origin/claude/b74.1-aicom@f8a76de34`, B69 `8d465fce` and B74 `b23f557f` removed dispatch-time `Call Compile` but still register value-only PVEHs at `Init_PublicVariables.sqf:56,61`, while docs/source `HEAD@925d56e01a1e` (PVF paths unchanged from `a0721301d4f5`), Miksuu `b8389e74` and perf `0076040f` keep both value-only PVEHs and old compile dispatchers. The checked B69..B74 and B74..B74.1 generic PVF dispatcher/init deltas are empty, and no allowlist/sender/requester symbol was found in checked current-stable/B69/B74 dispatcher/init files. The server dispatcher then selects `_script` and `_parameters` and spawns the handler, which leaves legitimate handlers unable to distinguish a real requester from a forged client payload unless each handler re-derives authority from trusted server state.

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
