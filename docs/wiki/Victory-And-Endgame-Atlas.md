# Victory And Endgame Atlas

> Canonical developer map for match end detection, winner/loser semantics, client outro flow, win-stat persistence and the patch-ready victory correctness risks. This page turns [Deep-review findings](Deep-Review-Findings) DR-11, DR-12, DR-13 and DR-36 into a practical source-backed implementation guide.

All source paths below are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## Why This Matters

Victory is a small script with huge consequences. It ends the mission, broadcasts the outro, stops long-running loops, stores AntiStack score deltas, flushes player lists and optionally increments persistent side win counters. A one-line logic mistake here can announce the wrong side, double-fire the endgame, overwrite winner state or permanently skew `profileNamespace` win statistics.

The important split:

- `Server/FSM/server_victory_threeway.sqf` owns default server-side detection and mission shutdown.
- `Client/Functions/Client_FNC_Special.sqf` receives the endgame special message and starts the client outro.
- `Client/Client_EndGame.sqf` treats its input as the losing side and flips it to display winner stats/camera focus.
- `Server/Functions/Server_LogGameEnd.sqf` is the live win-stat logger.
- `Server/PVFunctions/LogGameEnd.sqf` is a stale, buggy duplicate that is not registered in the current PVF list.

## Source Map

| Role | Files |
| --- | --- |
| Global initial state | `initJIPCompatible.sqf:84-85` |
| Victory mode fallback constant | `Common/Init/Init_CommonConstants.sqf:400-402` |
| Server compile/startup | `Server/Init/Init_Server.sqf:64,89,526-529` |
| Victory loop | `Server/FSM/server_victory_threeway.sqf:1-88` |
| Live win-stat logger | `Server/Functions/Server_LogGameEnd.sqf:7-44` |
| Stale duplicate logger | `Server/PVFunctions/LogGameEnd.sqf:7-43` |
| Client special receiver | `Client/PVFunctions/HandleSpecial.sqf:16`, `Client/Functions/Client_FNC_Special.sqf:61-68` |
| Client outro/camera/failMission | `Client/Client_EndGame.sqf:3-89` |
| Common loop stop flags | `gameOver`, `WFBE_GameOver` used across client/server FSMs |
| AntiStack final persistence | `Server/FSM/server_victory_threeway.sqf:51-84`, [AntiStack database extension audit](AntiStack-Database-Extension-Audit) |

## Startup And Ownership

`initJIPCompatible.sqf` initializes both `gameOver` and `WFBE_GameOver` to `false` (`initJIPCompatible.sqf:84-85`). Many client and server loops use one or the other as their stop condition.

`Init_Server.sqf` compiles the live logger twice, both times to the same file (`Init_Server.sqf:64,89`). This is harmless today because the second bind overwrites the same code, but it is a maintenance trap and is tracked separately as the DR-43 duplicate-bind cleanup.

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

Every 80 seconds, when `_victory == 0`, it checks each present side except `WFBE_DEFENDER` (`server_victory_threeway.sqf:9-46`).

For each side `_x`, it computes:

| Value | Meaning | Source |
| --- | --- | --- |
| `_hq` | Side HQ/MHQ object from side logic. | `server_victory_threeway.sqf:14` |
| `_structures` | Side base structures. | `:15` |
| `_towns` | Count of towns held by side. | `:16` |
| `_factories` | Count of barracks, light, heavy and aircraft factories found from side structures. | `:18-21` |

The current condition is:

```sqf
if (!(alive _hq) && _factories == 0 || _towns == _total && !WFBE_GameOver) then {
```

Because SQF `&&` binds tighter than `||`, this behaves like:

```sqf
((!alive _hq) && (_factories == 0)) || ((_towns == _total) && !WFBE_GameOver)
```

That means `!WFBE_GameOver` guards only the all-towns clause, not the HQ/factory elimination clause.

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

So the current client payload is semantically "loser side id", not "winner side id." This is easy to misread because the server also writes `WF_Winner` in the same block. Any patch must pick a single explicit semantic and keep the client, logger and messages consistent.

The client outro:

- runs end-of-game stats for the flipped side (`Client_EndGame.sqf:13`);
- plays `wf_outro` (`:14-16`);
- builds a camera target list from the winner and opponent HQ/structures (`:18-30`);
- ejects and moves the player near friendly HQ as a safety position (`:40-45`);
- terminates death camera effects if needed (`:47-52`);
- runs a camera tour (`:54-86`);
- calls `failMission "END1"` after a short delay (`:88-89`).

## Winner Logging

Inside the server victory block, the code writes:

```sqf
WF_Logic setVariable ["WF_Winner", _x];
...
_side = west;
if (_x == west) then {
    _side = east;
};
[_side] call WFBE_CO_FNC_LogGameEnd;
```

The live logger expects its first argument to be the winning side (`Server_LogGameEnd.sqf:9-12`). It increments `profileNamespace` key `"%1_WIN_CHERNARUS"` for that side when `WFBE_Server_LogMatchWin` is enabled (`Server_LogGameEnd.sqf:21-44`).

This is correct for a side being eliminated: if `_x` is the loser, the opposite side should be logged as winner. It is wrong for an all-towns victory: if `_x` holds all towns, `_x` is the winner, but the current block still logs the opposite side.

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

## Stale Duplicate Logger

`Server/PVFunctions/LogGameEnd.sqf` is present but is not registered by `Common/Init/Init_PublicVariables.sqf`. `SQF-Code-Atlas` already notes the live compile uses `Server/Functions/Server_LogGameEnd.sqf`.

The duplicate is dangerous archaeology:

- it treats `_this` directly as `_winnerTeam` instead of `_this select 0` (`PVFunctions/LogGameEnd.sqf:9`);
- it uses a `profileNamespace getVariable` result as the `setVariable` key (`:31`);
- it reads `WEST_WIN_CHERNARUS` and `EAST_WIN_CHERNARUS` as bare globals instead of string keys (`:40-41`).

Do not wire this PVF copy. Delete it or mark it retired when doing the victory cleanup.

## Patch-Ready Risks

| Status | Risk | Evidence | Patch direction |
| --- | --- | --- | --- |
| P1 correctness | All-towns victory logs the opposite side as winner. | `server_victory_threeway.sqf:23-41`, `Server_LogGameEnd.sqf:9-44`, DR-11. | Split elimination and all-towns branches or compute `winnerSide` explicitly per branch. |
| P1 correctness | `!WFBE_GameOver` only guards the all-towns clause. HQ/factory elimination can fire again after gameOver within the same side loop. | `server_victory_threeway.sqf:23`, DR-36. | Parenthesize the full condition or compute booleans, then guard the combined result with `!WFBE_GameOver`. |
| P1 correctness | Side loop has no break after a winner is recorded. Same-tick eliminations can double-broadcast and double-log. | `server_victory_threeway.sqf:12-43`, DR-36. | Exit the side loop and/or outer loop once `gameOver` is set. |
| Owner decision | Non-zero `WFBE_C_VICTORY_THREEWAY` skips the only detection block. | `CommonConstants.sqf:401`, `server_victory_threeway.sqf:3,11`, DR-12. | Implement non-default mode or keep it undocumented/disabled with a clear guardrail. |
| Cleanup | Stale `Server/PVFunctions/LogGameEnd.sqf` is buggy if ever wired. | `PVFunctions/LogGameEnd.sqf:9-43`, DR-13. | Delete/retire the duplicate and keep the live `Server/Functions/Server_LogGameEnd.sqf`. |
| Cleanup | `WFBE_CO_FNC_LogGameEnd` is compiled twice in server init. | `Init_Server.sqf:64,89`, DR-43. | De-duplicate live binds after or alongside the victory cleanup. |
| Semantics risk | Client endgame script expects loser side, while server variable name `WF_Winner` implies winner. | `Client_EndGame.sqf:3-13`, `server_victory_threeway.sqf:24,31-41`. | Pick explicit payload naming and keep server broadcast, client stats/camera and logger aligned. |

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
6. Call `WFBE_CO_FNC_LogGameEnd` with `[_winnerSide]`.
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

Main map: [Home](Home) | Evidence log: [Deep-review findings](Deep-Review-Findings) | Patch order: [Hardening roadmap](Hardening-Implementation-Roadmap)
