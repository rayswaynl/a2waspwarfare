# Victory And Endgame Atlas

> Canonical developer map for match end detection, winner/loser semantics, client outro flow, win-stat persistence and the patch-ready victory correctness risks. This page turns [Deep-review findings](Deep-Review-Findings) DR-11, DR-12, DR-13 and DR-36 into a practical source-backed implementation guide.

Source anchors below are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/` in the docs checkout unless a section names another ref. Current source-continuity checkpoint: docs head `d30d23466`; targeted diffs from `a0a86da2` and the earlier victory checkpoint `2f2132f8` to `HEAD` over the checked Chernarus and maintained Vanilla endgame/init/logger paths returned no source changes.

## How To Use This Atlas

| If you need to... | Start here | Then route to... |
| --- | --- | --- |
| Patch match-end winner/loser correctness | [Patch-ready risks](#patch-ready-risks), [Safer patch shape](#safer-patch-shape) | [Hardening roadmap](Hardening-Implementation-Roadmap), [Source fix propagation queue](Source-Fix-Propagation-Queue) |
| Understand server startup and loop ownership | [Startup and ownership](#startup-and-ownership), [Current default detection](#current-default-detection) | [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas), [Server runtime and operations](Server-Runtime-And-Operations) |
| Touch the client outro, RHUD or endgame display | [Endgame broadcast and client semantics](#endgame-broadcast-and-client-semantics) | [Client UI systems atlas](Client-UI-Systems-Atlas), [UI IDD collision repair](UI-IDD-Collision-Repair) |
| Audit final AntiStack persistence | [Final score persistence and mission shutdown](#final-score-persistence-and-mission-shutdown) | [AntiStack database extension audit](AntiStack-Database-Extension-Audit) |
| Clean stale logger/init bind archaeology | [Stale duplicate logger](#stale-duplicate-logger) | [Server init bind cleanup](Server-Init-Bind-Cleanup), [Dead/stale code register](Dead-Code-And-Stale-Code-Register) |
| Check current owner status | [Current branch scope](#current-branch-scope) | [Feature status](Feature-Status-Register), [Pending owner decisions](Pending-Owner-Decisions) |

## Current Branch Scope

Source refreshed: 2026-06-21. Checked refs: docs checkout `d30d23466` (source-unchanged from `a0a86da2` / `2f2132f8` for the paths below), current stable `origin/master@0139a346`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f`, historical release commit `a96fdda2`, and live-support branch `origin/claude/b57-soak-proposals@b8a1505f`. Current origin exposes no `release/*` heads on 2026-06-21.

| Scope | Current evidence | Development meaning |
| --- | --- | --- |
| Default victory condition | Docs checkout, Miksuu, `origin/perf/quick-wins` and historical `a96fdda2` keep the older Chernarus/Vanilla shape: `_victory == 0` at `server_victory_threeway.sqf:11`, mixed elimination/all-towns condition at `:23`, `HandleSpecial ["endgame", sideID]` at `:24`, `WF_Winner` at `:31`, `WFBE_GameOver` at `:33`, and opposite-side logger call at `:35-41`. Current stable `origin/master@0139a346` adds an HQ nil/null boot skip at `:18-22`, keeps the mixed condition at `:29`, broadcasts at `:30`, writes `WF_Winner` at `:37`, sets `WFBE_GameOver` at `:39`, writes WASPSTAT round-end telemetry with `_x` at `:41-46`, and calls the live logger with `[_x]` at `:49` in both maintained roots. | The exact wrong-winner symptom differs by branch, but explicit winner/loser semantics, full-condition guarding and a same-tick side-loop exit remain patch-ready for current stable and old-shape branches. |
| Victory constants | Docs/Miksuu/perf keep `WFBE_C_VICTORY_THREEWAY` at `Common/Init/Init_CommonConstants.sqf:401-402`; current stable uses `:631-632`; historical `a96fdda2` uses `:417-418`. | Cite the target branch when discussing line refs. Non-zero victory mode still needs an owner decision or implementation on stable; the Claude live-support branch removes the gate only in Chernarus. |
| Claude live-support branch | `origin/claude/b57-soak-proposals@b8a1505f` Chernarus removes the `_victory == 0` gate at `server_victory_threeway.sqf:11-16`, adds a same-tick `WFBE_GameOver` side-loop exit at `:23-26`, guards the combined condition at `:45`, removes the client inversion at `Client_EndGame.sqf:5-11`, and adds a Resistance label at `GUI_EndOfGameStats.sqf:8-9`. Its maintained Vanilla Takistan root still matches current stable for the checked victory files. | Treat this as branch-scoped/live Chernarus evidence, not stable parity or Vanilla propagation. It still does not compute explicit `_winnerSide` / `_loserSide` before using `_x`. |
| Stale `Server/PVFunctions/LogGameEnd.sqf` copy | Present in docs checkout, Miksuu and perf maintained roots; absent in current stable `origin/master@0139a346` and historical `a96fdda2` maintained roots. | Do not restore or wire this copy where it has already been removed; keep exact branch/removal proof in [Dead/stale code register](Dead-Code-And-Stale-Code-Register) and [Server init bind cleanup](Server-Init-Bind-Cleanup). |
| Server init duplicate binds | Docs checkout and Miksuu keep old live duplicate binds in Chernarus and Vanilla (`Init_Server.sqf:64,89`). Current stable has one live bind at `Init_Server.sqf:81`; historical `a96fdda2` has one at `:65`. Perf fixes Chernarus with one bind at `:64` but leaves Vanilla old-shape. | Treat duplicate-bind cleanup as branch-split. Use [Server init bind cleanup](Server-Init-Bind-Cleanup) for the authoritative DR-43b matrix. |

## Why This Matters

Victory is a small script with huge consequences. It ends the mission, broadcasts the outro, stops long-running loops, stores AntiStack score deltas, flushes player lists and optionally increments persistent side win counters. A one-line logic mistake here can announce the wrong side, double-fire the endgame, overwrite winner state or permanently skew `profileNamespace` win statistics.

The important split:

- `Server/FSM/server_victory_threeway.sqf` owns default server-side detection and mission shutdown.
- `Client/Functions/Client_FNC_Special.sqf` receives the endgame special message and starts the client outro.
- `Client/Client_EndGame.sqf` treats its input as the losing side and flips it to display winner stats/camera focus.
- `Server/Functions/Server_LogGameEnd.sqf` is the live win-stat logger.
- `Server/PVFunctions/LogGameEnd.sqf` is a stale, buggy duplicate where still present; stable/release maintained roots have already removed it.

## Source Map

| Role | Files |
| --- | --- |
| Global initial state | `initJIPCompatible.sqf:84-85` |
| Victory mode fallback constant | `Common/Init/Init_CommonConstants.sqf:400-402` |
| Server compile/startup | `Server/Init/Init_Server.sqf:64,89,526-529` |
| Victory loop | `Server/FSM/server_victory_threeway.sqf:1-88` |
| Live win-stat logger | `Server/Functions/Server_LogGameEnd.sqf:7-44` |
| Stale duplicate logger | `Server/PVFunctions/LogGameEnd.sqf:7-43` where present; absent from stable/release maintained roots |
| Client special receiver | `Client/PVFunctions/HandleSpecial.sqf:16`, `Client/Functions/Client_FNC_Special.sqf:61-68` |
| Client outro/camera/failMission | `Client/Client_EndGame.sqf:3-89` |
| Common loop stop flags | `gameOver`, `WFBE_GameOver` used across client/server FSMs |
| AntiStack final persistence | `Server/FSM/server_victory_threeway.sqf:51-84`, [AntiStack database extension audit](AntiStack-Database-Extension-Audit) |

## Startup And Ownership

`initJIPCompatible.sqf` initializes both `gameOver` and `WFBE_GameOver` to `false` (`initJIPCompatible.sqf:84-85`). Many client and server loops use one or the other as their stop condition.

In the docs checkout, `Init_Server.sqf` compiles the live logger twice, both times to the same file (`Init_Server.sqf:64,89`). This is harmless today because the second bind overwrites the same code, but it is a maintenance trap and is tracked separately as the DR-43 duplicate-bind cleanup. Keep exact branch propagation notes on [Server init bind cleanup](Server-Init-Bind-Cleanup).

After town initialization, the server starts the victory loop:

```sqf
[] Spawn {
    waitUntil {townInit};
    [] execVM "Server\FSM\server_victory_threeway.sqf";
    ["INITIALIZATION", "Init_Server.sqf: Victory Condition FSM is initialized."] Call WFBE_CO_FNC_LogContent;
    [] ExecVM "Server\FSM\updateresources.sqf";
};
```

The victory loop is therefore separate from town capture, economy/resources and HQ construction. Town ownership and HQ/factory state feed it, but they do not end the match directly.

## Current Default Detection

`server_victory_threeway.sqf` reads:

- `_victory = missionNamespace getVariable "WFBE_C_VICTORY_THREEWAY"` (`:3`);
- `_total = totalTowns` (`:4`);
- `_loopTimer = 80` (`:6`).

Every 80 seconds, when `_victory == 0`, it checks each present side except `WFBE_DEFENDER` (`server_victory_threeway.sqf:9-46` in the docs checkout). Current stable keeps that gate but inserts an HQ nil/null boot skip before factory counting, so the same detection condition has shifted to `server_victory_threeway.sqf:29`.

For each side `_x`, it computes:

| Value | Meaning | Source |
| --- | --- | --- |
| `_hq` | Side HQ/MHQ object from side logic. | `server_victory_threeway.sqf:14` |
| `_structures` | Side base structures. | `:15` |
| `_towns` | Count of towns held by side. | `:16` |
| `_factories` | Count of barracks, light, heavy and aircraft factories found from side structures. | `:18-21` in the docs checkout; current stable line-drifts to `:24-27` after the HQ boot guard. |

The current condition is:

```sqf
if (!(alive _hq) && _factories == 0 || _towns == _total && !WFBE_GameOver) then {
```

Because SQF `&&` binds tighter than `||`, this behaves like:

```sqf
((!alive _hq) && (_factories == 0)) || ((_towns == _total) && !WFBE_GameOver)
```

That means `!WFBE_GameOver` guards only the all-towns clause, not the HQ/factory elimination clause. Current stable `origin/master@0139a346` keeps the same source shape at `server_victory_threeway.sqf:29`; the added HQ boot guard does not close the same-tick double-fire risk.

## Endgame Broadcast And Client Semantics

When the condition fires, the server broadcasts:

```sqf
[nil, "HandleSpecial", ["endgame", (_x) Call WFBE_CO_FNC_GetSideID]] Call WFBE_CO_FNC_SendToClients;
```

The client receives `HandleSpecial` tag `"endgame"` and spawns `WFBE_CL_FNC_EndGame` (`Client/PVFunctions/HandleSpecial.sqf:16`). That function sets local `gameOver = true`, `WFBE_GameOver = true`, converts the side id to a side value and executes `Client\Client_EndGame.sqf` (`Client_FNC_Special.sqf:61-68`).

`Client_EndGame.sqf` then flips the side it receives:

```sqf
//todo improve that script, _side is the looser.
if (_side == west) then {
    _side = east;
} else {
    if (_side == east) then {_side = west};
};
```

So the current client payload is semantically "loser side id", not "winner side id." This is easy to misread because the server also writes `WF_Winner` in the same block. Wave S tightened this further: `_x` is the eliminated/losing side in the HQ/factory branch, but `_x` is the winning side in the all-towns branch. Any patch must compute explicit `_winnerSide` and `_loserSide` per branch, then keep the client, logger and messages consistent.

Current stable still carries this client inversion in both maintained roots. The live-support `origin/claude/b57-soak-proposals` branch removes it in Chernarus only (`Client_EndGame.sqf:5-11`) and treats the payload as the winner, so do not mix stable and live-branch payload semantics without checking the target branch.

The client outro:

- runs end-of-game stats for the flipped side (`Client_EndGame.sqf:13`);
- plays `wf_outro` (`:14-16`);
- builds a camera target list from the winner and opponent HQ/structures (`:18-30`);
- ejects and moves the player near friendly HQ as a safety position (`:40-45`);
- terminates death camera effects if needed (`:47-52`);
- runs a camera tour (`:54-86`);
- calls `failMission "END1"` after a short delay (`:88-89`).

UI note: endgame stats have a unique `idd`, but `GUI_EndOfGameStats.sqf` shares `uiNamespace["currentCutDisplay"]` with `OptionsAvailable`/RHUD action title recovery. Route visual fixes through [UI IDD collision repair](UI-IDD-Collision-Repair) so the outro, RHUD/FPS and action icons are smoked together.

## Winner Logging

Inside the server victory block, the code writes:

```sqf
WF_Logic setVariable ["WF_Winner", _x];
gameOver = true;
WFBE_GameOver = true;
...
[_side] call WFBE_CO_FNC_LogGameEnd;
```

That is the older docs/Miksuu/perf/historical-release shape: `_side` is set to the opposite of `_x` before the logger call (`server_victory_threeway.sqf:35-41`). The live logger (`Server_LogGameEnd.sqf:9-12`) treats its first argument as `_winnerTeam` and increments `profileNamespace` key `"%1_WIN_CHERNARUS"` for that side when `WFBE_Server_LogMatchWin` is enabled (`Server_LogGameEnd.sqf:21-44`).

Because older-shape branches pass the opposite side: in the HQ/factory elimination branch `_x` is the loser and `_side` is the winner, so the logger is correct; in the all-towns branch `_x` is the winner and `_side` is the loser, so the logger credits the loser. The client still receives `_x`, flips it, and therefore also shows the wrong side for all-towns wins.

Current stable `origin/master@0139a346` changed this logger call in both maintained roots: it removed the opposite-side `_side` block, writes WASPSTAT `ROUNDEND` with `_x` at `server_victory_threeway.sqf:41-46`, and calls `[_x] call WFBE_CO_FNC_LogGameEnd` at `:49`. That makes all-towns logging correct, but it makes HQ/factory elimination logging and WASPSTAT winner telemetry use the losing side. `WF_Winner` still stores `_x` verbatim, so it remains branch-dependent rather than an explicit winner variable.

Deep Review DR-11 owns this impact, and DR-36 owns the exact guard/precedence/no-break mechanism.

## Final Score Persistence And Mission Shutdown

After `gameOver` becomes true, the `while {!gameOver}` loop exits and the tail runs.

If AntiStack is disabled, the script logs that final DB persistence is skipped, sleeps 5 seconds, writes a final RPT line and calls `failMission "END1"` (`server_victory_threeway.sqf:51-57`). This disabled-mode shortcut is intentional because the sampling loop is not running; see [AntiStack database extension audit](AntiStack-Database-Extension-Audit).

If AntiStack is enabled, the script:

1. iterates `allUnits` (`server_victory_threeway.sqf:59-82`);
2. for player units, reads current and old score variables by UID (`:61-77`);
3. stores score delta through `WFBE_SE_FNC_CallDatabaseStore` (`:78`);
4. sleeps `_miniSleep = 0.05` per player (`:7,79`);
5. calls `WFBE_SE_FNC_CallDatabaseFlushPlayerList` (`:84`);
6. sleeps 5 seconds, logs and calls `failMission "END1"` (`:86-88`).

DR-36 found the loop cadence/performance posture clean: the victory check itself runs every 80 seconds and the final persistence tail is bounded by player count. The JIP gap is narrow: endgame broadcast and `WFBE_GameOver` are not replayed to a player who joins in the few seconds before `failMission`, but the mission is already ending.

AntiStack nuance from Wave S: `mainLoop.sqf` and `flushLoop.sqf` stop on `WFBE_GameOver`, but `updateScoreInternal.sqf:13` uses `while { true }`. Mission shutdown follows shortly after victory, so this is a low-risk cleanup nuance rather than a result-integrity root cause.

## Stale Duplicate Logger

`Server/PVFunctions/LogGameEnd.sqf` is present in the docs checkout, Miksuu and perf maintained roots, but is absent in stable `origin/master` and release maintained roots. Where present, it is not registered by `Common/Init/Init_PublicVariables.sqf`. `SQF-Code-Atlas` already notes the live compile uses `Server/Functions/Server_LogGameEnd.sqf`; the exact branch-removal matrix lives in [Dead/stale code register](Dead-Code-And-Stale-Code-Register) and [Server init bind cleanup](Server-Init-Bind-Cleanup).

The duplicate is dangerous archaeology:

- it treats `_this` directly as `_winnerTeam` instead of `_this select 0` (`PVFunctions/LogGameEnd.sqf:9`);
- it uses a `profileNamespace getVariable` result as the `setVariable` key (`:31`);
- it reads `WEST_WIN_CHERNARUS` and `EAST_WIN_CHERNARUS` as bare globals instead of string keys (`:40-41`).

Do not wire this PVF copy. Delete or mark it retired where present, and preserve the stable/release removal when merging from those branches.

## Patch-Ready Risks

| Status | Risk | Evidence | Patch direction |
| --- | --- | --- | --- |
| P1 correctness | Winner/logging semantics are branch-dependent. Older docs/Miksuu/perf/historical-release shape logs all-towns wins as the loser; current stable `origin/master@0139a346` logs HQ/factory eliminations and WASPSTAT round-end telemetry as the loser. | Older shape `server_victory_threeway.sqf:23-41`; current stable `:29-49`; `Server_LogGameEnd.sqf:9-44`; DR-11. | Split elimination and all-towns branches or compute `winnerSide` explicitly per branch before broadcast, `WF_Winner`, WASPSTAT and logger calls. |
| P1 correctness | `!WFBE_GameOver` only guards the all-towns clause on docs/current-stable/Miksuu/perf/historical-release. HQ/factory elimination can fire again after gameOver within the same side loop. | Older shape `server_victory_threeway.sqf:23`; current stable `:29`; DR-36. | Parenthesize the full condition or compute booleans, then guard the combined result with `!WFBE_GameOver`. |
| P1 correctness | Side loop has no break after a winner is recorded on docs/current-stable/Miksuu/perf/historical-release. Same-tick eliminations can double-broadcast and double-log. | Older shape `server_victory_threeway.sqf:12-43`; current stable `:12-51`; DR-36. | Exit the side loop and/or outer loop once `gameOver` is set. |
| Owner decision | Non-zero `WFBE_C_VICTORY_THREEWAY` skips the only detection block on docs/current-stable/Miksuu/perf/historical-release. | Docs/Miksuu/perf `CommonConstants.sqf:401`, current stable `:631`, historical release `:417`; `server_victory_threeway.sqf:3,11`; DR-12. | Implement non-default mode or keep it undocumented/disabled with a clear guardrail. |
| Cleanup | Stale `Server/PVFunctions/LogGameEnd.sqf` is buggy if ever wired. | `PVFunctions/LogGameEnd.sqf:9-43`, DR-13, [Dead/stale code register](Dead-Code-And-Stale-Code-Register). | Delete/retire the duplicate where present; preserve stable/release branches where it is already gone. |
| Cleanup | `WFBE_CO_FNC_LogGameEnd` is compiled twice in server init only on some refs/roots. | Docs checkout `Init_Server.sqf:64,89`, DR-43, [Server init bind cleanup](Server-Init-Bind-Cleanup). | De-duplicate live binds where still present; do not reintroduce duplicates into branches that already carry one live bind. |
| Semantics risk | Current stable still has client endgame script expecting loser side, while server variable/comment paths increasingly treat `_x` as winner. Claude live-support removes the inversion in Chernarus only. | Stable `Client_EndGame.sqf:3-13`, stable server `:30,37,41-49`; Claude Chernarus `Client_EndGame.sqf:5-11`. | Pick explicit payload naming and keep server broadcast, client stats/camera, GUER label, WASPSTAT and logger aligned on the target branch. |

## Safer Patch Shape

Keep the first code patch small and source-first:

1. Compute two named booleans:
   - `_sideEliminated = !(alive _hq) && _factories == 0`;
   - `_sideWonByTowns = _towns == _total`.
2. Guard both with `!WFBE_GameOver`.
3. Compute `_loserSide` and `_winnerSide` explicitly:
   - if eliminated, loser is `_x`, winner is the opposite active side;
   - if won by towns, winner is `_x`, loser is the opposite active side.
4. Send the current client payload as loser side id unless you intentionally update `Client_EndGame.sqf` at the same time.
5. Set `WF_Winner` to `_winnerSide` if keeping that variable.
6. Write WASPSTAT `ROUNDEND` and call `WFBE_CO_FNC_LogGameEnd` with `_winnerSide`, not the condition side.
7. `exitWith` after one accepted endgame path so only one endgame broadcast/log can happen per match.
8. Leave AntiStack final persistence and `failMission "END1"` tail unchanged.

Do not combine this with PVF dispatcher hardening or AntiStack DB wrapper hardening unless the branch is explicitly an endgame persistence branch. The match-outcome fix is valuable by itself and easier to smoke.

## Smoke Checklist

| Scenario | Expected result |
| --- | --- |
| West eliminated by dead HQ plus zero barracks/light/heavy/air factories | One endgame broadcast with west as loser; east logged as winner once. |
| East eliminated | One endgame broadcast with east as loser; west logged as winner once. |
| West holds all towns | West logged as winner, not east; client outro still shows correct winning side. |
| East holds all towns | East logged as winner, not west. |
| Same-tick mutual elimination | One winner decision only; no double `HandleSpecial ["endgame", ...]`, no double `LogGameEnd`, no overwritten `WF_Winner`. |
| AntiStack disabled | Final DB persistence is skipped cleanly and mission still ends. |
| AntiStack enabled | Player score deltas store/flush once, then mission ends. |
| Non-zero `WFBE_C_VICTORY_THREEWAY` | Either implemented and smoked, or explicitly guarded as unsupported so admins do not expect auto-end behavior. |
| Generated propagation | Chernarus source patch reaches Vanilla Takistan through LoadoutManager; modded forks are separately owned. |

## Continue Reading

Previous: [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas) | Next: [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas)

Main map: [Home](Home) | Evidence log: [Deep-review findings](Deep-Review-Findings) | Patch order: [Hardening roadmap](Hardening-Implementation-Roadmap) | Code-owner queue: [Source fix propagation queue](Source-Fix-Propagation-Queue)
