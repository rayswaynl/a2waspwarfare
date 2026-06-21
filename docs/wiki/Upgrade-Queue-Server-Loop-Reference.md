# UpgradeQueue Server Loop — Scan Algorithm and Stacking Semantics

> Source-verified 2026-06-21 against master cf2a6d6a4. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`Server/FSM/upgradeQueue.sqf` is the server-side driver introduced with PR8 that lets commanders queue upgrades for automatic sequential execution. Every 5 seconds it walks each present side's queue, applies stacking semantics, and fires the first startable entry via `WFBE_SE_FNC_ProcessUpgrade`. It is the only code path that does so outside of direct player interaction (`RequestUpgrade`) and the AI commander (`Server_AI_Com_Upgrade.sqf`).

---

## Lifecycle and Spawn Point

`upgradeQueue.sqf` is launched via `[] ExecVM "Server\FSM\upgradeQueue.sqf"` from within the deferred spawn block in `Init_Server.sqf`:532 — the same block that also starts `updateresources.sqf` and `server_side_patrols.sqf`. This block waits on `townInit` before executing, so the queue loop never starts before town initialization completes.

The loop guard is `while {!gameOver}` (`Server/FSM/upgradeQueue.sqf:25`). Each iteration ends with `sleep _interval` (`upgradeQueue.sqf:121`), giving a fixed **5-second tick** (`upgradeQueue.sqf:22`).

### Initialization of Queue State

Per-side queue variables are written during `Init_Server.sqf` side-logic initialization:

| Variable | Initial value | Broadcast | Source |
|---|---|---|---|
| `wfbe_upgrade_queue` | `[]` | `true` | `Server/Init/Init_Server.sqf:370` |
| `wfbe_upgrading` | `false` | `true` | `Server/Init/Init_Server.sqf:367` |
| `wfbe_upgrading_id` | `-1` | `true` | `Server/Init/Init_Server.sqf:369` |

All three are stored on the side-logic object returned by `WFBE_CO_FNC_GetSideLogic`.

---

## Per-Tick Outer Loop

```sqf
{
    _logik = (_x) Call WFBE_CO_FNC_GetSideLogic;
    if (!isNull _logik && {!(_logik getVariable ["wfbe_upgrading", false])}) then {
        ...
    };
} forEach WFBE_PRESENTSIDES;
```
(`upgradeQueue.sqf:26-119`)

`WFBE_PRESENTSIDES` is a global array built in `Common/Init/Init_Common.sqf:275-283` containing every side that has a present logic object (`west`, `east`, and/or `resistance`). The getVariable default-value form is intentional: the comment at `upgradeQueue.sqf:28-30` explicitly documents that a resistance side can appear in `WFBE_PRESENTSIDES` while its logic never received the queue variables (a future three-way setup scenario). The defaults prevent a nil crash in that case.

The outer guard skips a side entirely if:

1. `_logik` is null — the side has no logic object.
2. `wfbe_upgrading` is `true` — an upgrade is already running for that side.

---

## Currency Mode: `_dual` Flag

```sqf
_dual = (missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0;
```
(`upgradeQueue.sqf:23`)

`WFBE_C_ECONOMY_CURRENCY_SYSTEM` is a mission parameter (`Rsc/Parameters.hpp:159`) with values `0` = Supply+Funds (dual) or `1` = Funds-only. When `_dual` is `true` the loop checks **both** side supply and commander team funds for affordability and deducts both on start. When `false` only the funds check applies.

---

## Scan Algorithm

For each eligible side the loop takes a deep copy of the queue (`+ (_logik getVariable ["wfbe_upgrade_queue", []])`, `upgradeQueue.sqf:32`), then iterates all entries with a `for "_k"` loop — not `forEach`, deliberately, because `_x` is bound to the current side from the enclosing `forEach WFBE_PRESENTSIDES` and must not be shadowed (`upgradeQueue.sqf:45`).

The loop tracks four state variables:

| Variable | Role |
|---|---|
| `_seen` | Array of upgrade IDs already encountered this tick |
| `_startIdx` | Index of the entry selected to start; `-1` = nothing found yet |
| `_stop` | When `true`, stop scanning (affordability block) |
| `_dirty` | When `true`, stale entries were marked and need flushing |

For each queue entry, the scan applies the following rules in order:

### Rule 1 — Stacking: Only the First Copy of Each ID Is Actionable

```sqf
if !(_id in _seen) then {
    _seen = _seen + [_id];
    ...
} // else: skip silently
```
(`upgradeQueue.sqf:48-87`)

Duplicate copies of the same upgrade ID in the queue represent "one more level" (queuing `[LF, LF, LF]` will run Light Factories 1→2→3 across three ticks). On any single tick only the **first** occurrence of an ID can be selected; later copies are silently skipped. They become actionable on subsequent ticks once the first copy has been processed.

### Rule 2 — Stale-Maxed Pruning

```sqf
if (_current >= (_levels select _id)) then {
    _queue set [_k, objNull];
    _dirty = true;
};
```
(`upgradeQueue.sqf:52-55`)

If the live upgrade level already equals or exceeds the configured max level for that ID, the first copy is a stale entry (the upgrade was completed outside the queue, or the queue was enqueued redundantly). The entry is marked `objNull` in-place and `_dirty` is set. Scanning continues — other IDs can still be started this tick.

The flush happens at `upgradeQueue.sqf:110-114` when no startable entry was found but `_dirty` is true: `_queue - [objNull]` compacts the array and writes it back with broadcast.

### Rule 3 — Prerequisite Check: SKIP (Not STOP)

```sqf
_lnk = (missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LINKS", str _x]) select _id;
_lnk = _lnk select _current;
...
if (!_linkNeeded) then { ... } // else: fall through silently
```
(`upgradeQueue.sqf:58-84`)

Prerequisites are read from `WFBE_C_UPGRADES_%1_LINKS` for the **current live level** (not the queued level). The prerequisite structure can be either a flat two-element array `[upgradeId, requiredLevel]` or an array of such pairs for multi-prerequisite upgrades (`upgradeQueue.sqf:62-69`).

If a prerequisite is not yet live, the entry is **skipped** — scan continues to the next entry. This is a deliberate deadlock-prevention design: a prerequisite may itself be queued behind the blocked entry, and stopping would prevent it from running.

### Rule 4 — Affordability Check: STOP

```sqf
if (_dual && {((_x) Call WFBE_CO_FNC_GetSideSupply) < (_cost select 0)}) then {_canStart = false};
if (_canStart && {(_comTeam Call WFBE_CO_FNC_GetTeamFunds) < (_cost select 1)}) then {_canStart = false};
if (_canStart) then {
    _startIdx = _k;
} else {
    _stop = true;
};
```
(`upgradeQueue.sqf:76-83`)

Cost is read as `(_costs select _id) select _current` — a two-element array `[supply, funds]` (`upgradeQueue.sqf:74`). If the side cannot afford the entry, `_stop` is set to `true`, halting the scan for the remainder of the tick. This prevents queue-jumping on funds: the side saves up for the front-of-queue entry rather than skipping it in favor of a cheaper one behind it.

---

## Start Sequence

When `_startIdx >= 0` after the scan (`upgradeQueue.sqf:90`):

| Step | Code | Source line |
|---|---|---|
| Read selected id and level | `_id = _queue select _startIdx` | `upgradeQueue.sqf:91` |
| Mark selected slot `objNull`, compact | `_queue set [_startIdx, objNull]; _queue = _queue - [objNull]` | `upgradeQueue.sqf:95-96` |
| Broadcast updated queue | `_logik setVariable ["wfbe_upgrade_queue", _queue, true]` | `upgradeQueue.sqf:97` |
| Set synchronous gate | `_logik setVariable ["wfbe_upgrading", true, true]` | `upgradeQueue.sqf:99` |
| Record running ID | `_logik setVariable ["wfbe_upgrading_id", _id, true]` | `upgradeQueue.sqf:100` |
| Deduct supply (dual mode only) | `[_x, -(_cost select 0), "Queued tech upgrade.", false] Call ChangeSideSupply` | `upgradeQueue.sqf:103` |
| Deduct funds | `[_comTeam, -(_cost select 1)] Call WFBE_CO_FNC_ChangeTeamFunds` | `upgradeQueue.sqf:105` |
| Spawn upgrade | `[_x, _id, _current, false] Spawn WFBE_SE_FNC_ProcessUpgrade` | `upgradeQueue.sqf:107` |
| Log | `WFBE_CO_FNC_LogContent` | `upgradeQueue.sqf:108` |

The `false` fourth argument to `WFBE_SE_FNC_ProcessUpgrade` selects the **server-initiated (full-timer) path** inside `Server_ProcessUpgrade.sqf:36-38` — a plain `sleep _upgrade_time` with no client sync variable. The client-sync path (`Server_ProcessUpgrade.sqf:23-35`) is used only when a human player triggers an upgrade via `RequestUpgrade`.

### Synchronous Double-Start Guard

The gate at `upgradeQueue.sqf:99` — setting `wfbe_upgrading = true` **before** the `Spawn` call — prevents the next tick from starting a second upgrade for the same side. Because `Spawn` in Arma 2 OA returns immediately, without the pre-Spawn gate the 5-second sleep could expire before `WFBE_SE_FNC_ProcessUpgrade` executes its own `wfbe_upgrading = true` write at `Server_ProcessUpgrade.sqf:20`. Note that `Server_AI_Com_Upgrade.sqf` uses the **opposite** ordering: its `Spawn` is at line 41 and the `setVariable` gate writes come after it at lines 43-44. `upgradeQueue.sqf` deliberately inverts this — setting the gate before `Spawn` — to close the race window that the AI commander's post-Spawn ordering leaves open.

`WFBE_SE_FNC_ProcessUpgrade` resets `wfbe_upgrading` to `false` and `wfbe_upgrading_id` to `-1` when the upgrade timer completes (`Server_ProcessUpgrade.sqf:44-46`), releasing the gate for the next queue tick.

---

## PVF Client Entry Points

The queue is populated and drained from the client side via two public variable functions registered in `Common/Init/Init_PublicVariables.sqf:22-23`. Both are server-side handlers dispatched through `WFBE_SE_FNC_HandlePVF`.

| PVF name | File | Parameters | Action |
|---|---|---|---|
| `RequestEnqueue` | `Server/PVFunctions/RequestEnqueue.sqf` | `[side, upgradeId]` | Server re-validates all preconditions; appends one copy of `upgradeId` to the queue |
| `RequestDequeue` | `Server/PVFunctions/RequestDequeue.sqf` | `[side, upgradeId]` | Removes the **last** queued copy of `upgradeId` (plain array subtraction is avoided to preserve stacked copies) |

`RequestEnqueue` validation gates (`RequestEnqueue.sqf:17-64`):

- Logic object must not be null.
- A human commander team must exist (`isNull` check on `WFBE_CO_FNC_GetCommanderTeam`).
- `upgradeId` must be within bounds and enabled in `WFBE_C_UPGRADES_%1_ENABLED`.
- `_current + _pending` must be less than `_levels select _id` — where `_pending` counts queued copies **plus** the in-progress upgrade if `wfbe_upgrading_id` matches (`RequestEnqueue.sqf:33-37`).
- Prerequisite check is **queue-aware**: a linked upgrade counts as met if it is live or pending (queued or currently running), preventing dependency ordering from blocking the user from building a full upgrade chain upfront (`RequestEnqueue.sqf:39-64`).

`RequestDequeue` removes the last occurrence by walking forward to find the highest index, marking it `objNull`, then compacting — the same pattern used by upgradeQueue's start-pop to avoid stripping all stacked copies in one subtraction (`RequestDequeue.sqf:21-28`).

---

## Known Bug: Resistance Nil Hazard (Dormant)

`RequestEnqueue.sqf:30` reads `_logik getVariable "wfbe_upgrade_queue"` **without** a default value:

```sqf
_queue = + (_logik getVariable "wfbe_upgrade_queue");
```

If a resistance-side logic object exists in `WFBE_PRESENTSIDES` but was never initialized with `wfbe_upgrade_queue`, this read returns `nil`, and the subsequent `+` (deep-copy operator) throws a type error. `upgradeQueue.sqf` itself guards against this with the two-argument form at `upgradeQueue.sqf:32`, but `RequestEnqueue` and `RequestDequeue` do not.

In the current mission configuration, resistance (`WFBE_L_GUE`) is a town-defender side with no human teams and no commander, so `RequestEnqueue.sqf:20` exits early before reaching line 30. The hazard is dormant but will surface if resistance is ever made a playable side with its own queue.

The Coordination-Board (2026-06-07 entry) classifies this as a **low-severity dormant bug**.

---

## Variable Reference

| Variable | Scope | Owner | Broadcast | Description |
|---|---|---|---|---|
| `wfbe_upgrade_queue` | logic object | server | `true` | Array of queued upgrade IDs; duplicate entries = stacked levels |
| `wfbe_upgrading` | logic object | server | `true` | `true` while any upgrade is in progress for this side |
| `wfbe_upgrading_id` | logic object | server | `true` | ID of the currently running upgrade; `-1` when idle |
| `WFBE_C_ECONOMY_CURRENCY_SYSTEM` | missionNamespace | mission param | — | `0` = dual (supply+funds), `1` = funds-only; controls `_dual` flag |
| `WFBE_C_UPGRADES_%1_LEVELS` | missionNamespace | config | — | Array of max levels per upgrade ID, per side |
| `WFBE_C_UPGRADES_%1_COSTS` | missionNamespace | config | — | Array of `[[supply,funds],...]` per upgrade ID per level |
| `WFBE_C_UPGRADES_%1_LINKS` | missionNamespace | config | — | Prerequisite arrays per upgrade ID per level |
| `WFBE_C_UPGRADES_%1_ENABLED` | missionNamespace | config | — | Boolean enable flags per upgrade ID |

---

## Function Summary

| Function ref | Compiled in | Source file |
|---|---|---|
| `WFBE_CO_FNC_GetSideLogic` | `Common/Init/Init_Common.sqf:130` | `Common/Functions/Common_GetSideLogic.sqf` |
| `WFBE_CO_FNC_GetCommanderTeam` | `Common/Init/Init_Common.sqf:115` | `Common/Functions/Common_GetCommanderTeam.sqf` |
| `WFBE_CO_FNC_GetSideUpgrades` | `Common/Init/Init_Common.sqf:134` | `Common/Functions/Common_GetSideUpgrades.sqf` |
| `WFBE_CO_FNC_GetSideSupply` | `Common/Init/Init_Common.sqf:131` | `Common/Functions/Common_GetSideSupply.sqf` |
| `WFBE_CO_FNC_GetTeamFunds` | `Common/Init/Init_Common.sqf:135` | `Common/Functions/Common_GetTeamFunds.sqf` |
| `WFBE_CO_FNC_ChangeTeamFunds` | `Common/Init/Init_Common.sqf:99` | `Common/Functions/Common_ChangeTeamFunds.sqf` |
| `WFBE_SE_FNC_ProcessUpgrade` | `Server/Init/Init_Server.sqf:58` | `Server/Functions/Server_ProcessUpgrade.sqf` |
| `ChangeSideSupply` | `Common/Init/Init_Common.sqf:19` | `Common/Functions/Common_ChangeSideSupply.sqf` |
| `WFBE_SE_FNC_ChangeSideSupply` | `Server/Init/Init_Server.sqf:82` | `Server/Functions/Server_ChangeSideSupply.sqf` |
| `WFBE_CO_FNC_LogContent` | `initJIPCompatible.sqf:37` | `Common/Functions/Common_LogContent.sqf` |

---

## Continue Reading

- [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas) — upgrade IDs, level counts, cost tables, and research order per faction
- [Upgrade-Research-Cross-Faction-Reference](Upgrade-Research-Cross-Faction-Reference) — cross-faction upgrade availability and config structure
- [Networking-And-Public-Variables](Networking-And-Public-Variables) — full PVF dispatch architecture including `RequestEnqueue` / `RequestDequeue` registration
- [Public-Variable-Channel-Index](Public-Variable-Channel-Index) — canonical index of all server and client PVFs
- [Server-Gameplay-Runtime-Atlas](Server-Gameplay-Runtime-Atlas) — overview of all server-side FSM loops including the tick cadences of `upgradeQueue.sqf`, `updateresources.sqf`, and related drivers
