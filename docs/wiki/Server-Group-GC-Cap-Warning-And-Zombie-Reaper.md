# Server Group GC, Group-Cap Warning, and Zombie Reaper

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Arma 2 OA enforces a hard engine ceiling of roughly 144 groups per side, and the engine does not automatically reclaim a group once its last unit dies or is deleted. Empty groups therefore accumulate as a slow leak: once a side reaches 144, `createGroup` returns `grpNull` and every downstream AI spawn fails silently with no error in the RPT. `Server\FSM\server_groupsGC.sqf` is the always-on server loop that keeps that ceiling unreachable in normal play. On a 60-second cadence it runs four jobs in one pass: an empty-group garbage-collection sweep, an orphaned-team "zombie" reaper, a debounced per-side cap-warning, and a telemetry suite (GCSTAT, GUERCAP, plus a throttled per-source audit). It also publishes a per-side group-count cache that other loops read instead of re-scanning `allGroups` themselves.

This page documents the GC loop itself. It is distinct from the AI-Headless delegation prose, from the marker/garbage/empty-vehicle collectors (`Marker-Cleanup-Restoration-Systems-Atlas`), and from the dormant debug-only `groupsMonitor.sqf` noted in the dead-code register.

## Launch and loop frame

The script is launched once, late in server init, after the garbage collector and empty-vehicle collector are defined.

| Aspect | Detail | Source |
|---|---|---|
| Launch | `[] ExecVM "Server\FSM\server_groupsGC.sqf";` then logs `Init_Server.sqf: Group GC is defined.` | `Server/Init/Init_Server.sqf:698-699` |
| Server guard | `if (!isServer) exitWith {};` — runs server-only | `Server/FSM/server_groupsGC.sqf:9` |
| Loop condition | `while {!WFBE_GameOver} do { sleep 60; ... }` — exits when the game ends | `Server/FSM/server_groupsGC.sqf:16-17` |
| Warn debounce | `_warnInterval = 300;` — 5 minutes between repeated warnings, same side and threshold | `Server/FSM/server_groupsGC.sqf:13` |
| Audit window counter | `_auditN = 0;` — counts elapsed 5-min windows; the expensive audit fires only every `WFBE_C_GROUPAUDIT_EVERY`-th window | `Server/FSM/server_groupsGC.sqf:14` |

The order within each 60s cycle is: empty-group sweep, zombie reaper, per-side count + cache publish, GCSTAT/GUERCAP, cap warnings, then the throttled source-attribution audit.

## Empty-group GC sweep

The first job iterates `allGroups`, finds every group with zero units, and deletes the non-persistent ones. Two counters are reset each pass: `_gcEmptyFound` counts all zero-unit groups seen (including persistent ones that are kept), and `_gcReaped` counts the non-persistent empties actually deleted.

| Step | Detail | Source |
|---|---|---|
| Empty test | `if (!isNull _grp && {(count (units _grp)) == 0}) then {...}` | `Server/FSM/server_groupsGC.sqf:25` |
| Persistence read | `_isPers = _grp getVariable "wfbe_persistent";` then `if (isNil "_isPers") then {_isPers = false};` | `Server/FSM/server_groupsGC.sqf:29-30` |
| Reap | `if (!_isPers) then { deleteGroup _grp; _gcReaped = _gcReaped + 1; };` | `Server/FSM/server_groupsGC.sqf:31-34` |

A group flagged `wfbe_persistent` is never reaped even when empty — this is the contract static-defense manning relies on so a temporarily-empty garrison slot is not collected (`Static-Defense-Manning-Reference`). The A2-OA trap is called out in the source itself: the two-argument `[name, default]` form of `getVariable` is unreliable on GROUP objects in this engine (it can yield nil instead of the supplied default), so the sweep uses the single-argument form plus an explicit `isNil` guard (`server_groupsGC.sqf:27-30`).

## Orphaned-team zombie reaper

The second job reclaims AI teams whose human player disconnected under JIP-preserve but never returned. When `WFBE_C_AI_TEAMS_JIP_PRESERVE == 1`, a disconnecting player's AI subordinates are kept alive and the team is stamped with the disconnect time. If the player never reconnects within the timeout, those units become orphaned "zombies" that consume a group slot and units forever; this reaper cleans them up.

| Aspect | Detail | Source |
|---|---|---|
| Timeout param | `_zombieTimeout = missionNamespace getVariable ["WFBE_C_DISCONNECT_ZOMBIE_TIMEOUT", 600];` — default 600s; set 0 to disable the whole block | `Server/FSM/server_groupsGC.sqf:42-43` |
| Orphan stamp read | `_orphanedAt = _grp getVariable "wfbe_orphaned_at";` then `if (isNil "_orphanedAt") then {_orphanedAt = -1};` | `Server/FSM/server_groupsGC.sqf:50-51` |
| Age gate | `if (_orphanedAt >= 0 && {(time - _orphanedAt) >= _zombieTimeout}) then {...}` | `Server/FSM/server_groupsGC.sqf:52` |
| Unclaimed check | `_uidVal = _grp getVariable "wfbe_uid"; if (isNil "_uidVal") then {...}` — only reaps if no player has re-claimed the team | `Server/FSM/server_groupsGC.sqf:54-55` |
| HQ exclusion | `_zombieHQ = (side _grp) Call WFBE_CO_FNC_GetSideHQ;` then subtracted from the kill list | `Server/FSM/server_groupsGC.sqf:58-61` |
| Vehicle gather | `_zombieVehicles = [_grp, false] Call GetTeamVehicles;` | `Server/FSM/server_groupsGC.sqf:60` |
| Kill loop | `{ if (!isPlayer _x && !(_x in playableUnits)) then { deleteVehicle _x; ... } } forEach _zombieUnits;` | `Server/FSM/server_groupsGC.sqf:63-68` |
| Clear stamp | `_grp setVariable ["wfbe_orphaned_at", nil];` — prevents re-reaping the now-empty husk | `Server/FSM/server_groupsGC.sqf:69` |
| Log | `INFORMATION ... reaped %1 zombie unit(s) from orphaned team %2 (disconnected %3s ago)` via `WFBE_CO_FNC_AICOMLog` | `Server/FSM/server_groupsGC.sqf:70` |

The reaper mirrors the preserve==0 deletion pattern from the disconnect handler (the same `isPlayer`/`playableUnits` guard and HQ exclusion, so a teammate crewing the MHQ is never deleted). After the units are removed, the now-empty group is left for the empty-group sweep above to delete on a later pass.

### Feeder and claim contract

The reaper is fed by the player-disconnect handler, and the unclaimed test relies on `wfbe_uid` being cleared.

| Event | Action | Source |
|---|---|---|
| Connect | `_team setVariable ["wfbe_uid", _uid];` — team is claimed | `Server/Functions/Server_OnPlayerConnected.sqf:65` |
| Disconnect, preserve==1 | `_team setVariable ["wfbe_orphaned_at", time];` — stamps the orphan clock | `Server/Functions/Server_OnPlayerDisconnected.sqf:110-113` |
| Disconnect, preserve==0 | Deletes the units immediately (same guard pattern) instead of stamping | `Server/Functions/Server_OnPlayerDisconnected.sqf:105-109` |
| Disconnect, both paths | `_team setVariable ["wfbe_uid", nil];` — marks the team unclaimed | `Server/Functions/Server_OnPlayerDisconnected.sqf:132` |

Because `wfbe_uid` is cleared on disconnect and re-set on connect, a player who reconnects before the timeout re-claims the team (`wfbe_uid` is non-nil), and the reaper's `isNil "_uidVal"` check at `server_groupsGC.sqf:55` skips it. `Player-Join-Disconnect-And-AntiStack-Lifecycle` documents the disconnect feeder; this loop is the GC consumer of the `wfbe_orphaned_at` stamp.

## Per-side count and group-count cache

After the reaper, the loop does one `allGroups` pass to count groups per side and to count untagged groups (those with no `wfbe_group_src`, i.e. created outside the `WFBE_CO_FNC_CreateGroup` wrapper). The per-side counts are published to `missionNamespace` so other loops do not re-scan `allGroups`.

| Variable | Meaning | Source |
|---|---|---|
| `wfbe_grpcnt_west` / `_east` / `_guer` | Per-side group count from this sweep | `Server/FSM/server_groupsGC.sqf:96-98` |
| `wfbe_grpcnt_t` | `time` of the last publish (cache freshness) | `Server/FSM/server_groupsGC.sqf:99` |
| `_untW` / `_untE` / `_untG` | Untagged-group count per side (wrapper-bypass leak signal) | `Server/FSM/server_groupsGC.sqf:86-91` |

`server_town_ai.sqf` reads `wfbe_grpcnt_guer` from this cache, falling back to a live `allGroups` scan only until the first GC sweep warms it (`server_town_ai.sqf:62`). The B7 efficiency note in the source explains this is precisely why the cache exists (`server_groupsGC.sqf:94-95`).

## Group-cap pre-warning (130 / 144)

Each pass, for WEST, EAST, and RESISTANCE, the loop emits a debounced RPT WARNING when the side's count crosses two thresholds: `>= 130` (approaching) and `>= 144` (at cap). Each threshold per side has its own debounce key in `missionNamespace` so a sustained high count does not spam the RPT more than once per `_warnInterval` (300s).

| Threshold | Debounce key | Message | Source |
|---|---|---|---|
| WEST >= 130 | `wfbe_groupcap_warn_west130` | `...approaching cap (>= 130); AI spawns will fail silently at 144.` | `server_groupsGC.sqf:126-132` |
| WEST >= 144 | `wfbe_groupcap_warn_west144` | `...AT CAP; createGroup will return grpNull and AI spawns will silently fail.` | `server_groupsGC.sqf:134-140` |
| EAST >= 130 / 144 | `wfbe_groupcap_warn_east130` / `_east144` | same approach / at-cap text | `server_groupsGC.sqf:142-157` |
| RESISTANCE >= 130 / 144 | `wfbe_groupcap_warn_guer130` / `_guer144` | same approach / at-cap text | `server_groupsGC.sqf:159-174` |

All six warnings route through `WFBE_CO_FNC_AICOMLog` at level `WARNING`. The debounce default sentinel is `-9999` so the first crossing always fires (`server_groupsGC.sqf:127`).

## GUER soft-cap monitor

For RESISTANCE the 144 engine cap is rarely the real limit. The mission imposes a soft cap, `WFBE_C_GUER_GROUPS_MAX` (default 80), and town AI defers new resistance garrisons once it is reached — so GUER town defense degrades long before the 130/144 engine warning would ever fire. The GC loop emits a GUERCAP telemetry line every pass tracking the soft cap.

| Aspect | Detail | Source |
|---|---|---|
| Soft cap read | `_guerMax = missionNamespace getVariable ["WFBE_C_GUER_GROUPS_MAX", 80];` (clamped to >= 1) | `server_groupsGC.sqf:115-116` |
| Percent | `_guerPct = round ((_cntGuer / _guerMax) * 100);` | `server_groupsGC.sqf:117` |
| 90% threshold | `_guerSoftThreshold = round (_guerMax * 0.9);` | `server_groupsGC.sqf:118` |
| GUERCAP line | `GUERCAP|v1|count=...|max=...|pct=...|t=...` | `server_groupsGC.sqf:119` |
| Enforcement (consumer) | `if (_side == resistance && _guerGroupCount >= _guerGroupsMax) then {...defer garrison...}` | `server_town_ai.sqf:168-173` |

The cap is re-read each pass so a live lobby-param change is honoured. `AI-Commander-Tunable-Constants-Reference` lists the constant; this loop and `server_town_ai.sqf` are where it is observed and enforced.

## Telemetry reference

The GC loop emits a structured set of `diag_log` lines. Two are cheap and fire every 60s pass; the rest live inside the 5-minute source-attribution audit, which is additionally throttled by `WFBE_C_GROUPAUDIT_EVERY`.

| Tag | Cadence | Payload | Source |
|---|---|---|---|
| `GCSTAT|v1` | every 60s | `reaped`, `emptyFound`, per-side `west/east/guer`, untagged `untW/untE/untG`, `t` (round min) | `server_groupsGC.sqf:107` |
| `GUERCAP|v1` | every 60s | `count`, `max`, `pct`, `t` | `server_groupsGC.sqf:119` |
| `EMPTYGRP|v1` | audit window | empty-group counts `west/east/guer` plus persistent-empty `persW/persE/persG` | `server_groupsGC.sqf:289` |
| `DELEGSTAT|v1` | audit window | `total`, `srvLocal`, `remote`, `remotePct` (HC offload proof) | `server_groupsGC.sqf:295` |
| `TOWNSTAT|v1` | audit window | town ownership `west/east/guer/total` by `sideID` | `server_groupsGC.sqf:311` |
| `ORBATSTAT|v1` | audit window | per-side crewed-vehicle order of battle (armor/car/heli/jet) + personnel | `server_groupsGC.sqf:333-334` |
| `server_groupsGC.sqf: group audit [side] N/144: ...` | audit window | per-(side, `wfbe_group_src`) breakdown + `srvFps`, `activeTowns`, `units`, `auditMs` | `server_groupsGC.sqf:283-340` |

### The throttled source-attribution audit

The expensive audit (full `allGroups` classification by `wfbe_group_src`, plus an `allUnits` pass and the per-side dump) is gated twice. First a 5-minute debounce on `wfbe_groupaudit_last` (`server_groupsGC.sqf:178-181`); then a modulo gate so the classification fires only on every `WFBE_C_GROUPAUDIT_EVERY`-th window (default 5, clamped to >= 1):

```
_every = missionNamespace getVariable ["WFBE_C_GROUPAUDIT_EVERY", 5];
if (_every < 1) then { _every = 1 };
if ((_auditN mod _every) == 0) then { ...expensive dump... };
```
(`server_groupsGC.sqf:190-192`). The source notes the dump costs ~2100ms on 276 groups, which is why it is throttled; critically, the husk-reap sweep, zombie reaper, and cap warnings all run earlier in the same 60s cycle, outside this branch, so the throttle never delays the actual GC work (`server_groupsGC.sqf:183-188`).

### wfbe_group_src tagging

The audit classifies each group by its `wfbe_group_src` tag; untagged groups show as `untagged`. Editor-placed player-slot groups in `mission.sqm` are born by the engine with no `createGroup` call, so the wrapper never tags them. A one-shot init sweep tags every still-untagged WEST/EAST/RESISTANCE group as `editor-player-slot` (audit-only; they already carry `wfbe_persistent=true` so the GC never reaps them):

| Step | Detail | Source |
|---|---|---|
| Guard | `if (isNil "WFBE_EDITOR_GROUPS_TAGGED") then {...}` (one-shot) | `Server/Init/Init_Server.sqf:636-637` |
| Tag | `_x setVariable ["wfbe_group_src", "editor-player-slot", true];` for untagged WEST/EAST/RESISTANCE groups | `Server/Init/Init_Server.sqf:640-643` |

A rising untagged count in GCSTAT/the audit is therefore a wrapper-bypass leak signal rather than expected editor slots. `Commander-HQ-Lifecycle-Atlas` describes the `wfbe_group_src` tagging from the producer side.

## Continue Reading

- [Static-Defense-Manning-Reference](Static-Defense-Manning-Reference) — the `wfbe_persistent` flag that exempts empty garrison groups from this sweep.
- [Player-Join-Disconnect-And-AntiStack-Lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle) — the disconnect handler that stamps `wfbe_orphaned_at` and feeds the zombie reaper.
- [Commander-HQ-Lifecycle-Atlas](Commander-HQ-Lifecycle-Atlas) — `wfbe_group_src` tagging from the group-creation producer side.
- [AI-Commander-Tunable-Constants-Reference](AI-Commander-Tunable-Constants-Reference) — `WFBE_C_GUER_GROUPS_MAX`, `WFBE_C_DISCONNECT_ZOMBIE_TIMEOUT`, and `WFBE_C_GROUPAUDIT_EVERY` constants.
- [Marker-Cleanup-Restoration-Systems-Atlas](Marker-Cleanup-Restoration-Systems-Atlas) — the sibling garbage, empty-vehicle, and map cleanup loops (distinct from group GC).
