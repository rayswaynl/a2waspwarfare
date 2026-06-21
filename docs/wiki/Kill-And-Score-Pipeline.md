# Kill and Score Pipeline (OnUnitKilled flow, per-class formula, bounty routing)

> Source-verified 2026-06-21 against master cf2a6d6a4. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

## Overview

Every kill in WASP Warfare travels through a multi-stage chain: event handler attachment at spawn time, a local Common handler that fires on the killing machine, a server PVF that resolves kill credit, optional per-kill statistics, garbage-collection, a score formula call, bounty disbursement to the player via a client PVF, and faction-level counter updates. The diagram below shows the authoritative execution order.

```
[Unit/Vehicle spawned]
  Common_CreateUnit.sqf:110  → addEventHandler ['Killed', ... WFBE_CO_FNC_OnUnitKilled]
  Common_CreateVehicle.sqf:43 → addEventHandler ["killed", ... WFBE_CO_FNC_OnUnitKilled]
  Common_CreateVehicle.sqf:44 → addEventHandler ["hit",   ... WFBE_CO_FNC_OnUnitHit]

[Kill fires EH on local machine]
  Common_OnUnitKilled.sqf:15
    → ["RequestOnUnitKilled", [killed, killer, killed_id]] Call WFBE_CO_FNC_SendToServer
        (PV channel: WFBE_PVF_RequestOnUnitKilled)

[Server: Server/PVFunctions/RequestOnUnitKilled.sqf]
  1. Delayed-vehicle attribution (last-hit fallback, line 16–27)
  2. Guard: !alive _killer → exitWith (line 31)
  3. Guard: _killer_side == civilian → exitWith (line 52)
  4. Stats recording (guarded by WFBE_C_STATS_ENABLED, lines 54–72)
  5. Garbage-collection: Spawn TrashObject (lines 74–79)
  6. Statistics counter: UpdateStatistics Casualties / VehiclesLost (line 82)
  7. Guard: isNil '_get' || !_killer_iswfteam → skip award (line 87)
  8. Normal kill, player-led team:
       a. [_killed_type, _get] call WFBE_SE_FNC_AwardScorePlayer  → _points (line 95)
       b. leader group score += _points via SRVFNCREQUESTCHANGESCORE (line 101–105)
       c. If WFBE_C_UNITS_BOUNTY > 0: AwardBounty / AwardBountyPlayer to client (line 107–117)
  9. Normal kill, AI-led team:
       If WFBE_C_AI_TEAMS_ENABLED > 0: ChangeTeamFunds on the AI group (line 121–124)
 10. Team-kill branch → LocalizeMessage 'Teamkill' (line 127–132)
 11. AI infantry EH cleanup: removeEventHandler ["killed", 0] (line 136–138)
```

---

## Step 1: Hit-Assist Variable (Common_OnUnitHit.sqf)

Vehicles and units carrying a `hit` EH update two object-local variables on every hit of significance (damage threshold ≥ 0.05, non-self damage, killer not null).

| Variable | Written | Purpose |
|---|---|---|
| `wfbe_lasthitby` | `Common_OnUnitHit.sqf:16` | Last non-self entity that dealt ≥ 0.05 damage |
| `wfbe_lasthittime` | `Common_OnUnitHit.sqf:17` | `time` at which that hit occurred |

Both are broadcast globally (`true` third arg to `setVariable`). The `hit` EH is added only when the vehicle/unit is spawned with `_bounty = true` (`Common_CreateVehicle.sqf:44`).

**Threshold constant:** `WFBE_C_UNITS_LAST_HIT_REWARD_WINDOW = 60` (seconds, default; set in `Init_CommonConstants.sqf:367`). Configurable via mission parameter; the guard on line 19 of `RequestOnUnitKilled.sqf` reads it with a `getVariable [name, default]` fallback of 60.

---

## Step 2: Common_OnUnitKilled.sqf (local machine, any peer)

| Line | Action |
|---|---|
| 8 | `Private ["_killed","_killer","_killed_id"]` declaration |
| 10–12 | Extract `_killed`, `_killer`, `_killed_id` from `_this` |
| 15 | Forward to server via `["RequestOnUnitKilled", [_killed, _killer, _killed_id]] Call WFBE_CO_FNC_SendToServer` |

This function is compiled at mission start as `WFBE_CO_FNC_OnUnitKilled` (`Init_Common.sqf:144`). When it fires, it routes to the server via `WFBE_CO_FNC_SendToServer` which publishes on the `WFBE_PVF_RequestOnUnitKilled` channel. That channel's server handler (`SRVFNCREQUESTCHANGESCORE`) is compiled via the forEach loop in `Init_PublicVariables.sqf` (lines 51–54). The `_killed_id` is the numeric side ID baked into the EH closure at spawn time (e.g., `[_this select 0, _this select 1, 1] Spawn WFBE_CO_FNC_OnUnitKilled`).

---

## Step 3: Delayed Vehicle Attribution (RequestOnUnitKilled.sqf:16–27)

When a vehicle burns out or crashes after a valid player hit (i.e., the engine killer is the vehicle itself, null, or dead), the server falls back to the `wfbe_lasthitby` trail:

```sqf
if (!(_killed isKindOf "Man") && (_killer == _killed || isNull _killer || !alive _killer)) then {
    _last_hit = _killed getVariable ["wfbe_lasthitby", objNull];
    _last_hit_time = _killed getVariable ["wfbe_lasthittime", -1];
    _last_hit_window = missionNamespace getVariable ["WFBE_C_UNITS_LAST_HIT_REWARD_WINDOW", 60];
    if !(isNull _last_hit) then {
        if (alive _last_hit && side _last_hit != _killed_side
            && _last_hit_time >= 0 && (time - _last_hit_time) <= _last_hit_window) then {
            _killer = _last_hit;
        };
    };
};
```

`RequestOnUnitKilled.sqf:16–27`. If attribution succeeds, `_killer` is replaced with the last valid hitter and processing continues normally. The event is logged at `INFORMATION` level with elapsed seconds.

---

## Step 4: Per-Kill Statistics (optional)

The stats recording block fires immediately after the civilian guard and before the garbage-collector, score formula, and bounty award (`RequestOnUnitKilled.sqf:54–72`). It is guarded by the feature flag:

```sqf
WFBE_C_STATS_ENABLED = false;   // Init_CommonConstants.sqf:461
```

When enabled, `WFBE_SE_FNC_RecordStat` increments one of five stat indices for the resolved killer's UID:

| Constant | Index | Condition |
|---|---|---|
| `WFBE_STAT_KILLS_INFANTRY` | 0 | `_killed_isman` |
| `WFBE_STAT_KILLS_VEHICLE` | 1 | not air, not static |
| `WFBE_STAT_KILLS_AIR` | 2 | `_killed isKindOf "Air"` |
| `WFBE_STAT_KILLS_STATIC` | 3 | `_killed isKindOf "StaticWeapon"` |
| `WFBE_STAT_PVP_KILLS` | 7 | `_killed_isplayer` (stacked on top of above) |

`Init_CommonConstants.sqf:463–470`, `RequestOnUnitKilled.sqf:60–69`.

---

## Step 5: Garbage-Collection (TrashObject)

After stats, the server schedules the dead unit for removal. `RequestOnUnitKilled.sqf:74–79`.

---

## Step 6: UpdateStatistics (faction-level counters)

Separate from per-player stats, `UpdateStatistics` (`Common_UpdateStatistics.sqf:1`) increments global side counters on `WF_Logic`:

| Event | Counter |
|---|---|
| `_killed_isman` | `WF_Logic` var `str(_killed_side) + "Casualties"` |
| vehicle or structure | `WF_Logic` var `str(_killed_side) + "VehiclesLost"` |

`RequestOnUnitKilled.sqf:81–83`. These counters are broadcast globally via the `true` flag inside `Common_UpdateStatistics.sqf`.

---

## Step 7: Award Eligibility Guard (RequestOnUnitKilled.sqf:87)

Before computing any score or bounty, the server checks two conditions:

```sqf
if (!isNil '_get' && _killer_iswfteam) then {
```

- `!isNil '_get'` — the killed unit's class must be registered in `missionNamespace` (i.e., it has a price/label/faction entry). Unregistered classes (editor-placed objects, mod units not in the unit table) are silently skipped.
- `_killer_iswfteam` — the killer must belong to one of the active WF sides. Kills by civilians, null killers, or already-dead entities have already been exited at earlier guards (lines 31 and 52); this catches any remaining non-WF killer.

If either condition fails, the entire award block (score, bounty, AI-team funds) is skipped. `RequestOnUnitKilled.sqf:87`.

---

## Step 8: Score Formula (AwardScorePlayer)

`WFBE_SE_FNC_AwardScorePlayer` is compiled from `Server/Functions/Server_AwardScorePlayer.sqf` (`Init_Server.sqf:83`). It is called on the server at `RequestOnUnitKilled.sqf:95`, inside the `!isNil '_get' && _killer_iswfteam` guard (line 87).

### Input

```
[_killed_type, _get] call WFBE_SE_FNC_AwardScorePlayer
```

- `_killed_type` — `typeOf _killed` (string class name)
- `_get` — the mission-namespace array for that class (`missionNamespace getVariable _killed_type`); `_get select QUERYUNITPRICE` (index 2) is the buy price

### Per-class formula table

| Class hierarchy check (`isKindOf`) | Coefficient | Rounding | Source line |
|---|---|---|---|
| `Man` | 0.7 | `ceil` | `Server_AwardScorePlayer.sqf:18` |
| `Car` | 0.45 | `round` | `Server_AwardScorePlayer.sqf:19` |
| `Ship` | 0.4 | `round` | `Server_AwardScorePlayer.sqf:20` |
| `Motorcycle` | 0.7 | `round` | `Server_AwardScorePlayer.sqf:21` |
| `Tank` | 0.4 | `round` | `Server_AwardScorePlayer.sqf:22` |
| `Helicopter` | 0.4 | `round` | `Server_AwardScorePlayer.sqf:23` |
| `Plane` | 0.35 | `round` | `Server_AwardScorePlayer.sqf:24` |
| `StaticWeapon` | 0.5 | `round` | `Server_AwardScorePlayer.sqf:25` |
| `Building` | 0.55 × `WFBE_C_BUILDINGS_SCORE_COEF` | `round` | `Server_AwardScorePlayer.sqf:26` |
| _(default)_ | flat 2 | — | `Server_AwardScorePlayer.sqf:27` |

**General formula (non-Building):**

```
points = round/ceil( price × coef × WFBE_C_UNITS_BOUNTY_COEF / 100 )
```

`WFBE_C_UNITS_BOUNTY_COEF = 1` (hardcoded, not guarded by `isNil`; `Init_CommonConstants.sqf:375`). With the default `WFBE_C_UNITS_BOUNTY_COEF = 1`, score simplifies to `price × coef / 100`; non-default COEF values scale linearly.

**Building formula:**

```
points = round( price × 0.55 × WFBE_C_UNITS_BOUNTY_COEF / 100 × WFBE_C_BUILDINGS_SCORE_COEF )
```

`WFBE_C_BUILDINGS_SCORE_COEF = 3` (hardcoded; `Init_CommonConstants.sqf:376`). Building class in this formula is `isKindOf "Building"` (capital B — Arma 2 class name).

**Man rounding note:** `Man` uses `ceil`, not `round`. All other killable classes use `round`. This means infantry kills always round up, producing a 1-point floor even for cheap units.

**Default fallback:** Any class that does not match any of the eight `isKindOf` checks returns a flat 2 points. This covers all unrecognized types.

### Duplicate function

`Common/Functions/Common_AwardScorePlayer.sqf` and `Server/Functions/Server_AwardScorePlayer.sqf` are byte-identical (same author comment, same logic, lines 1–30 match). Only `Server_AwardScorePlayer.sqf` is used at runtime (`Init_Server.sqf:83` → `WFBE_SE_FNC_AwardScorePlayer`). `Common_AwardScorePlayer.sqf` is compiled nowhere in master and is dead code. This is a maintenance hazard: patches to the score formula applied only to the Common copy will have no effect.

---

## Step 8a: Score Apply (RequestChangeScore flow)

Once `_points` is computed, the server applies it to the group leader's Arma score:

```sqf
['SRVFNCREQUESTCHANGESCORE', [leader _killer_group, (score leader _killer_group) + _points]]
    Spawn WFBE_SE_FNC_HandlePVF;
```

`RequestOnUnitKilled.sqf:101–102` (on dedicated server) or `RequestOnUnitKilled.sqf:104` (on listen server: `["RequestChangeScore", [...]] Call WFBE_CO_FNC_SendToServer`).

`SRVFNCREQUESTCHANGESCORE` is compiled by the PVF forEach loop in `Init_PublicVariables.sqf` (lines 51–54): each name in `_serverCommandPV` produces a `SRVFNC<Name>` variable via `Call Compile Format[...]`. The loop also registers `WFBE_PVF_RequestOnUnitKilled` (and every other server PVF) as a `addPublicVariableEventHandler` that spawns `WFBE_SE_FNC_HandlePVF` on receipt.

`Server_HandlePVF.sqf:14` executes it: `_parameters Spawn (Call Compile _script)`.

`Server/PVFunctions/RequestChangeScore.sqf` then:
1. Reads old score (`score _playerChanged`)
2. Strips it (`addScore -_oldScore`)
3. Applies new absolute value (`addScore _newScore`)
4. Broadcasts to clients: `[nil, "ChangeScore", [_playerChanged, _newScore]] Call WFBE_CO_FNC_SendToClients`

The client `ChangeScore` PVF (`Client/PVFunctions/ChangeScore.sqf:1–8`) mirrors the same addScore pattern locally.

---

## Step 8b: Bounty Disbursement (Client PVFs)

Bounty payout is gated by `WFBE_C_UNITS_BOUNTY > 0` (`Init_CommonConstants.sqf:366`, default 1).

### Kill routing decision

```
Player-led team (isPlayer (leader _killer_group)):
  If killed was a player AND killer is a player:
    → AwardBountyPlayer PVF to killer's UID   [kills a player]
  Always:
    → AwardBounty PVF to killer's UID, [_killed_type, false, _killer_award]
  If killed was in a vehicle (vehicle _killed != _killed && alive _killed):
    → AwardBounty PVF to each alive player in vehicle crew, assist flag = true

AI-led team (leader group is AI):
  If WFBE_C_AI_TEAMS_ENABLED > 0 (Init_CommonConstants.sqf:98, default 1) AND isServer:
    → ChangeTeamFunds on _killer_group: price × WFBE_C_UNITS_BOUNTY_COEF
```

`RequestOnUnitKilled.sqf:89–126`

### AwardBounty.sqf (Client/PVFunctions/AwardBounty.sqf)

Receives `[_killed_type, _assist_bool, _killer_ai_or_null]`. Fires only on the winning player's machine.

Guards (lines 3–4): `isHeadLessClient` → exit; `isNull player` → exit.

**Bounty formula (display + fund award):**

| Class | Coefficient | Notes |
|---|---|---|
| `Man` | `price × 0.7 × WFBE_C_UNITS_BOUNTY_COEF` | No `/100` — units are raw currency |
| `Car` | `price × 0.45 × WFBE_C_UNITS_BOUNTY_COEF` | |
| `Ship` | `price × 0.4 × WFBE_C_UNITS_BOUNTY_COEF` | |
| `Motorcycle` | `price × 0.7 × WFBE_C_UNITS_BOUNTY_COEF` | |
| `Tank` | `price × 0.4 × WFBE_C_UNITS_BOUNTY_COEF` | |
| `Helicopter` | `price × 0.4 × WFBE_C_UNITS_BOUNTY_COEF` | |
| `Plane` | `price × 0.35 × WFBE_C_UNITS_BOUNTY_COEF` | |
| `StaticWeapon` | `price × 0.5 × WFBE_C_UNITS_BOUNTY_COEF` | |
| `WarfareBBaseStructure` | flat 2000 | `AwardBounty.sqf:36` |
| `building` (lowercase) | `price × 0.55 × WFBE_C_UNITS_BOUNTY_COEF` | |

`AwardBounty.sqf:19–40`. Note: no `/100` divisor here — this is the **currency** payout formula, not the score-point formula.

> **Note:** Unlike the score formula (`Server_AwardScorePlayer.sqf` line 27), `AwardBounty.sqf` has no `default` branch. An unrecognized class type returns `nil` rather than a fallback value, which would cause `ChangePlayerFunds` to receive `nil`. This is a latent bug.

**Assist modifier:** if `_assist` is true, bounty is multiplied by `WFBE_C_UNITS_BOUNTY_ASSISTANCE_COEF = 0.5` (`Init_CommonConstants.sqf:377`). Chat notification fires with `STR_WF_CHAT_Award_Bounty_Assist` (`AwardBounty.sqf:47`).

**Payment:** `(_bounty) Call ChangePlayerFunds` → `Client_ChangePlayerFunds.sqf:1` → `[clientTeam, _bounty] Call ChangeTeamFunds`.

**Random sleep:** `sleep (random 3)` before payment (`AwardBounty.sqf:42`) staggers the group-chat message to reduce chat flood on multi-kill events.

**Dead AI skill improvement block (lines 53–74):** completely commented out. No AI skill progression occurs in master.

### AwardBountyPlayer.sqf (Client/PVFunctions/AwardBountyPlayer.sqf)

Fires only for player-vs-player kills. Receives the killed unit object.

**Formula (player-kill bounty):**

```
_coef = 7 × (score _killed)
_coef = _coef ^ (-0.1)
_bounty = if (score _killed <= 0) then { 180 } else { 100 + 14 × (score _killed) × _coef }
_bounty = round _bounty
```

`AwardBountyPlayer.sqf:9–18`. This is a soft-capped reward curve: a player with zero score yields 180; as score rises the bonus grows but the `^(-0.1)` factor slows growth and prevents unbounded bounty farming.

---

## Step 9: AI-Team Bounty Branch

When the killer group's leader is an AI (`!(isPlayer (leader _killer_group))`), the player-bounty chain is skipped entirely. Instead:

```
_bounty = (_get select QUERYUNITPRICE) * WFBE_C_UNITS_BOUNTY_COEF
_bounty = _bounty - (_bounty % 1)   // integer truncate
[_killer_group, _bounty] Call ChangeTeamFunds
```

`RequestOnUnitKilled.sqf:121–124`. The guard is `WFBE_C_AI_TEAMS_ENABLED > 0 && isServer`. There is no `/100` here, matching the `AwardBounty.sqf` currency scale, not the score-point scale.

---

## Known Bugs

### Kill-assist: `alive _killed` guard is always false

`RequestOnUnitKilled.sqf:115`:
```sqf
if (vehicle _killed != _killed && alive _killed) then { //--- Kill assist
```

By the time `OnUnitKilled` fires, `_killed` is already dead. On a dedicated server `alive _killed` is `false` at this point — the killed check is logically inverted. The intent is to check whether `_killed` was in a vehicle (it was in a vehicle, not itself), but the `alive _killed` guard causes the assist branch to never fire. Crew members riding in a vehicle killed by an enemy never receive the assist bounty.

### Kill-assist: `player` reference on dedicated server

`RequestOnUnitKilled.sqf:116`:
```sqf
forEach ((crew (vehicle _killed)) - [_killer, player])
```

On a dedicated server `player` is `objNull`. Subtracting `[objNull]` from the crew list does not remove any valid player — it only incidentally removes `objNull` if present. The intent was to exclude the calling player, but on dedicated server this guard is a no-op, meaning `_killer` may receive a duplicate `AwardBounty` (both as the primary killer and as a crew member).

Both bugs are present in the same `if`-block, so in practice the `alive _killed` guard prevents the branch from ever reaching the `player` bug on dedicated servers.

---

## Constants Reference

| Constant | Default | Source |
|---|---|---|
| `WFBE_C_UNITS_BOUNTY` | `1` (enabled) | `Init_CommonConstants.sqf:366` |
| `WFBE_C_UNITS_BOUNTY_COEF` | `1` | `Init_CommonConstants.sqf:375` |
| `WFBE_C_BUILDINGS_SCORE_COEF` | `3` | `Init_CommonConstants.sqf:376` |
| `WFBE_C_UNITS_BOUNTY_ASSISTANCE_COEF` | `0.5` | `Init_CommonConstants.sqf:377` |
| `WFBE_C_UNITS_LAST_HIT_REWARD_WINDOW` | `60` (seconds) | `Init_CommonConstants.sqf:367` |
| `WFBE_C_AI_TEAMS_ENABLED` | `1` (enabled) | `Init_CommonConstants.sqf:98` |
| `WFBE_C_STATS_ENABLED` | `false` (off) | `Init_CommonConstants.sqf:461` |
| `QUERYUNITPRICE` | `2` (array index) | `Init_CommonConstants.sqf:8` |

---

## File Index

| File | Role |
|---|---|
| `Common/Functions/Common_OnUnitHit.sqf` | Writes `wfbe_lasthitby` / `wfbe_lasthittime` per hit |
| `Common/Functions/Common_OnUnitKilled.sqf` | EH handler; forwards to server via `SendToServer` |
| `Common/Functions/Common_CreateUnit.sqf:110` | Attaches `Killed` EH to infantry |
| `Common/Functions/Common_CreateVehicle.sqf:43–44` | Attaches `killed` + `hit` EH to vehicles |
| `Common/Functions/Common_UpdateStatistics.sqf` | Increments side-level kill/loss counters on `WF_Logic` |
| `Common/Init/Init_PublicVariables.sqf:51–54` | forEach loop compiles all `SRVFNC<Name>` globals and registers server PVF EHs |
| `Common/Init/Init_CommonConstants.sqf:366–377` | Declares all bounty/score constants |
| `Server/PVFunctions/RequestOnUnitKilled.sqf` | Main server handler; resolves credit, awards score/bounty |
| `Server/Functions/Server_AwardScorePlayer.sqf` | Per-class score formula; called by `WFBE_SE_FNC_AwardScorePlayer` |
| `Common/Functions/Common_AwardScorePlayer.sqf` | Byte-identical duplicate of above; dead code (no callers) |
| `Server/PVFunctions/RequestChangeScore.sqf` | Applies score to leader; broadcasts `ChangeScore` to clients |
| `Client/PVFunctions/AwardBounty.sqf` | Currency bounty for unit/vehicle kills; handles assist flag |
| `Client/PVFunctions/AwardBountyPlayer.sqf` | Soft-curve bounty for player-vs-player kills |
| `Client/PVFunctions/ChangeScore.sqf` | Client-side score sync from server broadcast |
| `Client/Functions/Client_ChangePlayerFunds.sqf` | Delegates to `ChangeTeamFunds` on `clientTeam` |
| `Server/Init/Init_Server.sqf:83` | Compiles `WFBE_SE_FNC_AwardScorePlayer` |

---

## Continue Reading

- [Economy-Towns-And-Supply](Economy-Towns-And-Supply) — team funds (`wfbe_funds`), `ChangeTeamFunds`, side supply; downstream consumers of bounty payments
- [Networking-And-Public-Variables](Networking-And-Public-Variables) — how `SendToServer` / `SendToClients` and the PVF dispatch system work; `WFBE_PVF_*` channel registration
- [Respawn-And-Death-Lifecycle-Atlas](Respawn-And-Death-Lifecycle-Atlas) — what happens to the dead unit after kill credit is resolved; `TrashObject` and body cleanup
- [Variable-And-Naming-Conventions](Variable-And-Naming-Conventions) — `WFBE_C_*` constant naming rules; `QUERYUNIT*` index constants
- [Player-Join-Disconnect-And-AntiStack-Lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle) — AntiStack score consumers (`getTeamScore`, `compareTeamScores`); how kill score feeds the balance system
