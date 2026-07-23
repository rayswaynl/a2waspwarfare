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

---

## MATCH family (Stats V2 step 1)

Added in `fable/match-facts-family` (2026-07-06). The `MATCH|v1|` family is a parallel,
independent prefix — it does **not** use the `WASPSTAT` prefix or the `WFBE_WASPSTAT_SEQ`
sequence counter. Gate: `WFBE_C_MATCH_TELEMETRY` (default `1`; registered in
`Common/Init/Init_CommonConstants.sqf`).

All lines have the form:

```
MATCH|v1|<subtype>|<key=value>|<key=value>|...
```

Volume budget: ≤ ~50 lines per match.

---

### MATCH|v1|START|

Emitted once per match from `Server/Init/Init_Server.sqf`, immediately after the `SELFTEST`
line (params + constants are final, before side-init).

```
MATCH|v1|START|world=<worldName>|build=<buildId>|towns=<townsActiveMax>|missionSlots=<missionSlots>|aiEnabled=<aicomEnabled>|delegation=<delegation>|statlog=<statlog>|guer=<guerPlayerside>|naval=<navalHVT>|oilfield=<oilfieldEnable>
```

| Field | Source | Notes |
|-------|--------|-------|
| `world` | `worldName` | Terrain string, e.g. `chernarus`, `takistan`, `zargabad`. |
| `build` | `"build89-cmdcon44"` (pipe-free literal) | Short build-id token; the full `WF_RELEASE_MARKER` string is not used here because it contains pipe characters that would shatter pipe-split parsers. |
| `towns` | `WFBE_C_TOWNS_ACTIVE_MAX` | Configured max active towns for this match. |
| `missionSlots` | `missionConfigFile >> Header >> maxPlayers` | Compiled mission slot count (renamed from `maxPlayers` in the dynamic-identity update; consumers must read `missionSlots=`). |
| `aiEnabled` | `WFBE_C_AI_COMMANDER_ENABLED` | Whether AI commander is enabled. |
| `delegation` | `WFBE_C_AI_DELEGATION` | HC delegation mode. |
| `statlog` | `WFBE_C_STATLOG` | Whether WASPSTAT pipeline is active. |
| `guer` | `WFBE_C_GUER_PLAYERSIDE` | Whether playable GUER faction is enabled. |
| `naval` | `WFBE_C_NAVAL_HVT` | Whether naval HVT carriers are enabled. |
| `oilfield` | `WFBE_C_OILFIELD_ENABLE` | Whether oilfield feature is enabled. |

---

### MATCH|v1|END|

Emitted exactly once per match from `Server/FSM/server_victory_threeway.sqf`, immediately
after the `WASPSTAT|ROUNDEND` line (or directly after `WFBE_GameOver = true` when
`WFBE_C_STATLOG = 0`). `winner` is reused from the victory block; `durationSec` and
town counts are recomputed independently so `END` is always correct regardless of
`WFBE_C_STATLOG`.

```
MATCH|v1|END|winner=<winSide>|durationSec=<durationSec>|world=<worldName>|townsW=<townsW>|townsE=<townsE>|townsG=<townsG>|casW=<casW>|casE=<casE>|vehLostW=<vehLostW>|vehLostE=<vehLostE>|players=<players>|totalTowns=<totalTowns>
```

| Field | Source | Notes |
|-------|--------|-------|
| `winner` | `str _winSide` | Winning side object, e.g. `WEST`, `EAST`, `RESISTANCE`. |
| `durationSec` | `round(time)` | Match uptime in seconds. Same source as `WASPSTAT|ROUNDEND`. |
| `world` | `worldName` | Terrain string. |
| `townsW` | `west Call GetTownsHeld` | Towns held by WEST at round end. |
| `townsE` | `east Call GetTownsHeld` | Towns held by EAST at round end. |
| `townsG` | `resistance Call GetTownsHeld` | Towns held by GUER at round end. |
| `casW` | `WF_Logic getVariable "WESTCasualties"` | WEST casualties across the match. |
| `casE` | `WF_Logic getVariable "EASTCasualties"` | EAST casualties across the match. |
| `vehLostW` | `WF_Logic getVariable "WESTVehiclesLost"` | WEST vehicles destroyed. |
| `vehLostE` | `WF_Logic getVariable "EASTVehiclesLost"` | EAST vehicles destroyed. |
| `players` | `{ isPlayer _x } count playableUnits` | Peak connected player count at round end. |
| `totalTowns` | `totalTowns` (local var in victory loop) | Total towns on the map. |

---

### MATCH|v1|MILESTONE|

Sparse narrative beats emitted across the match. Each site emits at most once (or once per
relevant event). Total volume: ≤ ~15 emission points per match, well within the 50-line budget.

#### FIRST_TOWN

```
MATCH|v1|MILESTONE|FIRST_TOWN|side=<side>|town=<townName>|tMin=<tMin>
```

Emitted from `Server/FSM/server_town.sqf` inside the existing `FIRST_TOWN` idempotency
block. One shot per side per round. Fires alongside the `AICOMSTAT|v1|FIRST_TOWN` line.

| Field | Source |
|-------|--------|
| `side` | `str _newSide` |
| `town` | `_location getVariable "name"` |
| `tMin` | `round (time / 60)` |

#### HQ_DESTROYED

```
MATCH|v1|MILESTONE|HQ_DESTROYED|side=<side>|tMin=<tMin>
```

Emitted from `Server/Functions/Server_OnHQKilled.sqf`. Only fires on a clean enemy kill
(teamkills excluded via the `!_teamkill` guard).

| Field | Source |
|-------|--------|
| `side` | `str _side` — the side whose HQ was destroyed. |
| `tMin` | `round (time / 60)` |

#### OILFIELD_CAP

```
MATCH|v1|MILESTONE|OILFIELD_CAP|owner=<newOwner>|tMin=<tMin>
```

Emitted from `Server/Server_Oilfields.sqf` at every ownership flip. Takistan-only (the
oilfield feature is TK-only). Fires alongside the existing `OILFIELD|v1|CAPTURE` line.

| Field | Source |
|-------|--------|
| `owner` | `str _owner` — the side that just took the oilfield. |
| `tMin` | `round (time / 60)` |

#### CARRIER_CAP

```
MATCH|v1|MILESTONE|CARRIER_CAP|carrier=<carrierName>|newSideID=<newSideID>|tMin=<tMin>
```

Emitted from `Server/FSM/server_town.sqf` inside the naval HVT capture block. Fires on
each carrier ownership flip when `WFBE_C_NAVAL_HVT = 1`.

| Field | Source |
|-------|--------|
| `carrier` | `_hvtName` — the carrier's town name (e.g. `Khe Sanh Alpha`). |
| `newSideID` | `_newSID` — numeric side ID of the new owner. |
| `tMin` | `round (time / 60)` |

---

## Example MATCH lines

```
MATCH|v1|START|world=chernarus|build=build89-cmdcon44|towns=20|missionSlots=55|aiEnabled=1|delegation=2|statlog=1|guer=0|naval=0|oilfield=0
MATCH|v1|MILESTONE|FIRST_TOWN|side=WEST|town=Elektrozavodsk|tMin=4
MATCH|v1|MILESTONE|FIRST_TOWN|side=EAST|town=Berezino|tMin=5
MATCH|v1|MILESTONE|HQ_DESTROYED|side=EAST|tMin=82
MATCH|v1|END|winner=WEST|durationSec=5183|world=chernarus|townsW=18|townsE=0|townsG=2|casW=74|casE=139|vehLostW=12|vehLostE=28|players=22|totalTowns=20
```
