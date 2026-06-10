# WASPSTAT v1 Wire Format

This document is the contract for all `WASPSTAT|v1|` lines emitted to the Arma 2 OA RPT log
by the WFBE Warfare mission (experital branch). A Phase-2 website parser will tail the RPT and
ingest these lines to build lifetime player stats, kill feeds, and match history.

> **Note:** The DiscordBot (`DiscordBot/`) does **not** currently tail the RPT. The comment in
> the original StatsFlush header ("the DiscordBot tails the RPT") is aspirational; the actual
> parser is future work.

---

## Common prefix

Every WASPSTAT line starts with:

```
WASPSTAT|v1|<seq>|<record-type>|...
```

| Field | Description |
|-------|-------------|
| `WASPSTAT` | Fixed literal marker — grep anchor for the RPT parser. |
| `v1` | Format version. Increment if the field layout changes incompatibly. |
| `seq` | Monotonically increasing integer, server-global, shared across **all** record types. Counter name: `WFBE_WASPSTAT_SEQ`. |
| `record-type` | One of: `KILL`, `CAPTURE`, `ROUNDEND`. Per-player stat records have **no** keyword here — the parser identifies them by the absence of a keyword after `seq` (see PLAYERSTATS below). |

The sequence is initialised lazily to `0` by the first emitter that runs and is incremented once
per emitted line. Lines from different record types are totally ordered by `seq`.

Gate: all emitters check `WFBE_C_STATLOG == 1` (defined in `Init_CommonConstants.sqf`).
When the gate is `0` no WASPSTAT lines are written and there is zero runtime overhead beyond the
constant check.

---

## Record types

### PLAYERSTATS — periodic per-player delta flush

Emitted by `Server/Stats/StatsFlush.sqf` every `WFBE_C_STATS_FLUSH_INTERVAL` seconds (default
60 s). One line covers **all dirty players** in a single flush; each player's data is a
`uid:fields` token separated by `|`.

```
WASPSTAT|v1|<seq>|<uid1>:<d0>,<d1>,...,<d14>,<side>|<uid2>:...|...
```

Note: the record-type token for PLAYERSTATS is the first `uid` token (there is no explicit
`PLAYERSTATS` keyword in the line — the parser identifies this record by the absence of a keyword
after `seq`).

| Position | Field | Notes |
|----------|-------|-------|
| after `seq` | `uid:d0,...,d14,side` | One token per dirty player. |

Player stat field indices (0-based, matching `WFBE_STAT_*` constants):

| Index | Constant | Description |
|-------|----------|-------------|
| 0 | `WFBE_STAT_KILLS_INFANTRY` | Infantry kills (delta since last flush) |
| 1 | `WFBE_STAT_KILLS_VEHICLE` | Vehicle kills |
| 2 | `WFBE_STAT_KILLS_AIR` | Air kills |
| 3 | `WFBE_STAT_KILLS_STATIC` | Static weapon kills |
| 4 | `WFBE_STAT_KILLS_FACTORY` | Factory destructions |
| 5 | `WFBE_STAT_KILLS_HQ` | HQ destructions |
| 6 | `WFBE_STAT_DEATHS` | Deaths |
| 7 | `WFBE_STAT_PVP_KILLS` | PvP kills (victim was a human player) |
| 8 | `WFBE_STAT_SUPPLY_RUNS` | Supply runs completed |
| 9 | `WFBE_STAT_SUPPLY_VALUE` | Supply value delivered |
| 10 | `WFBE_STAT_CAPTURES_TOWN` | Town captures |
| 11 | `WFBE_STAT_CAPTURES_CAMP` | Camp captures |
| 12 | `WFBE_STAT_STRUCTURES_BUILT` | Structures built |
| 13 | `WFBE_STAT_DEFENSES_BUILT` | Defenses built |
| 14 | `WFBE_STAT_PLAYTIME` | Seconds of playtime (flush interval sized chunks) |
| 15 (trailing) | side | Numeric side at flush time: 1=WEST, 2=EAST, 0=other |

Gate: only emitted when `WFBE_C_STATS_ENABLED` is also `true` (separate flag from
`WFBE_C_STATLOG`).

---

### KILL — unit killed event

Emitted by `Server/PVFunctions/RequestOnUnitKilled.sqf` once per kill, server-side, after delayed
vehicle attribution has resolved.

```
WASPSTAT|v1|<seq>|KILL|<killerUID>|<victimUID>|<killerSide>|<victimSide>|<weaponOrVehicleClass>|<distance_m>|<category>
```

| Field | Description |
|-------|-------------|
| `killerUID` | `getPlayerUID` of the killer. Empty string `""` if killer is AI. |
| `victimUID` | `getPlayerUID` of the victim. Empty string `""` if victim is AI. |
| `killerSide` | `str` of the killer's side (e.g. `"WEST"`, `"EAST"`, `"RESISTANCE"`). |
| `victimSide` | `str` of the victim's side. |
| `weaponOrVehicleClass` | `typeOf (vehicle _killer)` — the vehicle/unit class doing the killing. Falls back to `typeOf _killer` if vehicle returns empty. |
| `distance_m` | Integer metres, `round(_killer distance _killed)`. `-1` if distance could not be computed. |
| `category` | See category enum below. |

**Category enum:**

| Value | Meaning | Condition |
|-------|---------|-----------|
| `INF` | Infantry | Killed unit `isKindOf "Man"` |
| `VEH` | Ground vehicle | Not Man, not Air, not StaticWeapon, not Building |
| `AIR` | Aircraft / helicopter | `isKindOf "Air"` |
| `STATIC` | Static weapon (e.g. HMG, mortar) | `isKindOf "StaticWeapon"` |
| `STRUCT` | Structure / building (non-HQ) | `isKindOf "Building"` and `wfbe_structure_type != "Headquarters"` |
| `HQ` | Headquarters building | `isKindOf "Building"` and `wfbe_structure_type == "Headquarters"` |

**PvP rule:** a kill is PvP if and only if **both** `killerUID` and `victimUID` are non-empty
strings (i.e. both killer and victim are human players). The parser should not rely on the
PLAYERSTATS `WFBE_STAT_PVP_KILLS` delta alone — cross-reference with KILL lines when precise
per-kill PvP attribution is needed.

---

### CAPTURE — town ownership change

Emitted by `Server/FSM/server_town.sqf` once per successful town capture, inside the
`if(_captured)` block immediately after `sideID` is updated.

```
WASPSTAT|v1|<seq>|CAPTURE|<townName>|<oldSide>|<newSide>
```

| Field | Description |
|-------|-------------|
| `townName` | `_location getVariable "name"` — the town's string name. Falls back to `"unknown"` if unset. |
| `oldSide` | Numeric side ID of the previous owner (`WFBE_C_WEST_ID`=0, `WFBE_C_EAST_ID`=1, `WFBE_C_GUER_ID`=2, `WFBE_C_UNKNOWN_ID`=4). |
| `newSide` | Numeric side ID of the new owner. |

---

### ROUNDEND — match end

Emitted by `Server/FSM/server_victory_threeway.sqf` exactly once per match, immediately after
`WFBE_GameOver` is set to `true`, before the game-end routine runs.

```
WASPSTAT|v1|<seq>|ROUNDEND|<winnerSide>|<durationSec>|<map>
```

| Field | Description |
|-------|-------------|
| `winnerSide` | `str _x` — the winning side object (e.g. `"WEST"`, `"EAST"`, `"RESISTANCE"`). |
| `durationSec` | `round(time)` — mission uptime in seconds at match end. Same source as `GlobalGameStats.sqf`'s `_uptime`. |
| `map` | `worldName` — Arma 2 world name string (e.g. `"chernarus"`, `"takistan"`). |

---

## Example lines

```
WASPSTAT|v1|1|76561198012345678:0,0,0,0,0,0,1,0,0,0,0,0,0,0,60,1|76561198087654321:1,0,0,0,0,0,0,0,0,0,0,0,0,0,60,2
WASPSTAT|v1|2|KILL|76561198012345678||WEST|EAST|USMC_Soldier_MG|143|INF
WASPSTAT|v1|3|KILL|||WEST|EAST|T72|56|VEH
WASPSTAT|v1|4|CAPTURE|Elektrozavodsk|2|0
WASPSTAT|v1|5|ROUNDEND|WEST|5432|chernarus
```

---

## Parser notes

- Lines are pipe-delimited (`|`). Split on `|` with a max of the expected field count per record.
- Sequence gaps are possible if the game crashes mid-session; gaps do not indicate data loss —
  the counter simply may have been incremented without a corresponding `diag_log`.
- All emitters are server-side; no client-originated WASPSTAT lines exist.
- The gate constant `WFBE_C_STATLOG` lives in `Common/Init/Init_CommonConstants.sqf` and
  defaults to `1` on the experital branch.
