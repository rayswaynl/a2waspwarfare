# GUER Insurgent Player Economy

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted (other roots: Server/, Common/, Client/). Arma 2 OA 1.64.

The optional GUER "Insurgents" playable faction has no commander, no factory, and no town-supply economy. Instead it runs a self-contained two-part loop on the server: a per-minute **stipend** paid straight into each living resistance player's team funds, and a **time-tier broadcast** that progressively unlocks heavier ground vehicles in the buy menu. Both halves live in a single server loop (`Server/Server_GuerStipend.sqf`) and a client overlay (`Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf`). The entire system is dormant unless the master gate `WFBE_C_GUER_PLAYERSIDE` is greater than 0 — default is OFF, so vanilla behaviour is byte-for-byte unchanged.

## Master Gate

Everything keys off one constant. Default is OFF so the insurgent faction never affects a normal match.

| Item | Value / Behaviour | Source |
|---|---|---|
| Constant default | `WFBE_C_GUER_PLAYERSIDE = 0` (0=off, 1=on) | `Common/Init/Init_CommonConstants.sqf:76` |
| Resistance side ID | `WFBE_C_GUER_ID = 2` | `Common/Init/Init_CommonConstants.sqf:32` |
| Server loop spawn gate | `Init_Server.sqf` runs `execVM "Server\Server_GuerStipend.sqf"` only inside `if ((... WFBE_C_GUER_PLAYERSIDE > 0) && {!isNil "WFBE_L_GUE"})` | `Server/Init/Init_Server.sqf:587,612` |
| Server loop self-gate | `if ((... "WFBE_C_GUER_PLAYERSIDE", 0) < 1) exitWith {}` | `Server/Server_GuerStipend.sqf:14` |
| Client overlay load gate | `Root_GUE.sqf` compiles the overlay only when `WFBE_C_GUER_PLAYERSIDE > 0` | `Common/Config/Core_Root/Root_GUE.sqf:129-130` |
| Client overlay self-gate | `if !((... "WFBE_C_GUER_PLAYERSIDE", 0) > 0) exitWith {}`; also exits if not `local player` or not resistance | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:22-24` |

When the gate is OFF, `Init_Server.sqf` additionally deletes the synced GUER player-slot units so nobody can join a non-functional insurgent slot (`Server/Init/Init_Server.sqf:621-626`).

## Team Registration

When the gate is ON, `Init_Server.sqf` registers the four RESISTANCE player slots (synced to `WFBE_L_GUE`, the `LocationLogicOwnerResistance`) as harass teams before the stipend loop starts.

| Item | Value | Source |
|---|---|---|
| Registration gate | `WFBE_C_GUER_PLAYERSIDE > 0 && !isNil "WFBE_L_GUE"` | `Server/Init/Init_Server.sqf:587` |
| GUER starting funds | `wfbe_funds = 50000` per team | `Server/Init/Init_Server.sqf:596` |
| Team side flag | `wfbe_side = resistance` | `Server/Init/Init_Server.sqf:597` |
| Persistent flag | `wfbe_persistent = true` | `Server/Init/Init_Server.sqf:598` |
| Autonomy | `[_group, false] Call SetTeamAutonomous` | `Server/Init/Init_Server.sqf:601` |

Note the registration comment at `Server/Init/Init_Server.sqf:586` calls GUER a "zero-fund harass team", but the live registration seeds each team with 50000 funds (`Server/Init/Init_Server.sqf:596`) — the stipend tops that up from minute to minute.

## The Stipend (Per-Minute Cash)

The loop pays a town-deficit-scaled rate to every living resistance player's group, once per interval, via `WFBE_CO_FNC_ChangeTeamFunds`.

| Parameter | Value | Source |
|---|---|---|
| Interval | `_interval = 60` seconds | `Server/Server_GuerStipend.sqf:18,33` |
| Base rate | `_baseRate = 150` per interval | `Server/Server_GuerStipend.sqf:19` |
| Per-town bonus | `_townBonus = 10` per GUER-held town below start count | `Server/Server_GuerStipend.sqf:20` |
| Cap | `_baseRate * 3` = 450 per interval (deep deficit) | `Server/Server_GuerStipend.sqf:49` |
| Rate formula | `(_baseRate + (_deficit * _townBonus)) min (_baseRate * 3)` | `Server/Server_GuerStipend.sqf:49` |
| Deficit formula | `(_startTownCount - _curTowns) max 0` | `Server/Server_GuerStipend.sqf:48` |
| Recipient filter | `alive _x && side _x == resistance && isPlayer _x`, iterated over `playableUnits` | `Server/Server_GuerStipend.sqf:51-52,58` |
| Payment call | `[_g, _rate] Call WFBE_CO_FNC_ChangeTeamFunds` on the player's group | `Server/Server_GuerStipend.sqf:56` |

`WFBE_CO_FNC_ChangeTeamFunds` simply adds `_amount` to the team's `wfbe_funds` (broadcast public): `_team setVariable ["wfbe_funds", (_team getVariable "wfbe_funds") + _amount, true]` (`Common/Functions/Common_ChangeTeamFunds.sqf:8`). Before paying, the loop initialises a missing `wfbe_funds` to 0 on the player's group (`Server/Server_GuerStipend.sqf:55`).

### Town-Deficit Snapshot

The "starting" town count is captured once, after ownership has had time to settle, and the loop never re-baselines it — so capturing towns back from GUER raises the stipend, while GUER expanding past its start does not reduce it below base.

| Step | Behaviour | Source |
|---|---|---|
| Wait condition | `waitUntil` `towns` populated AND `WFBE_L_GUE` exists & non-null | `Server/Server_GuerStipend.sqf:23-26` |
| Settle delay | `sleep 30` after the wait | `Server/Server_GuerStipend.sqf:27` |
| Snapshot | `_startTownCount = {(_x getVariable ["sideID", -1]) == WFBE_C_GUER_ID} count towns` | `Server/Server_GuerStipend.sqf:29` |
| Current count | recomputed each tick by the same `sideID == WFBE_C_GUER_ID` count | `Server/Server_GuerStipend.sqf:47` |
| Loop guard | `while {!WFBE_GameOver}` | `Server/Server_GuerStipend.sqf:32` |
| Start log | `["INITIALIZATION", ... "GUER player economy started (start towns=%1)."]` | `Server/Server_GuerStipend.sqf:30` |

Because the snapshot uses `sideID == 2` (`WFBE_C_GUER_ID`), only towns the resistance actually owns at settle time count toward the baseline. Deficit is clamped at 0 (`max 0`), so the rate never drops below the 150 base.

## Vehicle Time-Tier Broadcast

The same loop publishes `WFBE_GUER_VEHICLE_TIER` purely from elapsed match time (`time`), so the buy menu can time-gate ground vehicles without a second loop. The value is only re-published when the tier actually changes.

| Tier | Unlock threshold (`time`) | Source |
|---|---|---|
| 0 (default) | from start | `Server/Server_GuerStipend.sqf:37` |
| 1 | `_elapsed >= 1800` (30 min) | `Server/Server_GuerStipend.sqf:38` |
| 2 | `_elapsed >= 5400` (1.5 h) | `Server/Server_GuerStipend.sqf:39` |
| 3 | `_elapsed >= 10800` (3 h) | `Server/Server_GuerStipend.sqf:40` |
| Broadcast | sets + `publicVariable "WFBE_GUER_VEHICLE_TIER"` only when changed | `Server/Server_GuerStipend.sqf:41-43` |

## Client Overlay: Depot Pool Rebuild

`Root_GUE_PlayerOverlay.sqf` runs on each GUER player and rebuilds the buy-menu depot pool `WFBE_GUERDEPOTUNITS` whenever the broadcast tier changes. The buy menu reads `WFBE_GUERDEPOTUNITS` at open time, so updating it dynamically is what time-gates the vehicles.

| Item | Value / Behaviour | Source |
|---|---|---|
| First-tick seed | `WFBE_GUERDEPOTUNITS` set synchronously before the watcher spawns | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:47` |
| Watcher loop | `[] spawn { while {!WFBE_GameOver && local player && side group player == resistance} ... }` | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:48-51` |
| Tier read | `_tier = ... getVariable ["WFBE_GUER_VEHICLE_TIER", 0]`; rebuild only when `_tier != _lastTier` | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:52-53` |
| Poll interval | `sleep 10` | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:84` |
| Map branch | `#ifdef IS_CHERNARUS_MAP_DEPENDENT` selects GUE_* roster, else TK_GUE_*_EP1 | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:56,67` |

### Chernarus Roster Per Tier

| Tier | Vehicles added | Source |
|---|---|---|
| 0 (always) | `Offroad_DSHKM_Gue`, `V3S_Gue`, `hilux1_civil_2_covered` (VBIED), `Ka137_MG_PMC` + GUE_Soldier_* infantry | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:58-63` |
| 1 (30 m) | `+ BRDM2_Gue`, `T34_TK_GUE_EP1` | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:64` |
| 2 (1.5 h) | `+ T55_TK_GUE_EP1`, `BTR40_TK_GUE_EP1` | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:65` |
| 3 (3 h) | `+ T72_Gue`, `BMP2_Gue` | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:66` |

### Takistan Roster Per Tier

The Takistan branch has no T-72/BMP-2 GUE (caps at the T-55 family) and repoints the VBIED type to the TK covered pickup.

| Tier | Vehicles added | Source |
|---|---|---|
| 0 (always) | `Offroad_DSHKM_TK_GUE_EP1`, `Pickup_PK_TK_GUE_EP1`, `V3S_TK_GUE_EP1`, `datsun1_civil_2_covered` (VBIED), `Ka137_MG_PMC` + TK_GUE_*_EP1 infantry | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:71-77` |
| 1 (30 m) | `+ BRDM2_TK_GUE_EP1`, `T34_TK_GUE_EP1` | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:78` |
| 2 (1.5 h) | `+ T55_TK_GUE_EP1`, `BTR40_MG_TK_GUE_EP1` | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:79` |
| 3 (3 h) | `+ Ural_ZU23_TK_GUE_EP1` | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:80` |

The overlay also defines per-role respawn gear for the Engineer, Spotter/Sniper and Medic roles, identical on both maps (AKS-74 family): `WFBE_GUER_DefaultGearEngineer/Spot/Medic` (`Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:28-42`). The single overlay file is the persistent edit point for both maps — LoadoutManager copies Chernarus to Takistan on regen, and a separate `Root_TKGUE_PlayerOverlay.sqf` would be deleted by `DeleteExtraFiles` (`Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:9-12`).

## End-to-End Flow

| Stage | Actor | What happens |
|---|---|---|
| Boot | Server | `Init_Server.sqf` registers GUER teams (50000 funds) and `execVM`s the stipend loop when gate ON (`Server/Init/Init_Server.sqf:587,596,612`) |
| Settle | Server | Loop waits for towns + `WFBE_L_GUE`, sleeps 30 s, snapshots start-owned town count (`Server/Server_GuerStipend.sqf:23-29`) |
| Each 60 s | Server | Recomputes tier from `time`, publishes if changed; computes deficit-scaled rate, pays each living resistance player's group (`Server/Server_GuerStipend.sqf:33-58`) |
| On tier change | Client | Overlay watcher rebuilds `WFBE_GUERDEPOTUNITS` for the new tier (`Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:51-82`) |
| On buy-menu open | Client | Buy menu reads `WFBE_GUERDEPOTUNITS` as its depot pool |

## Continue Reading

- [Resistance Supply Scaffold](Resistance-Supply-Scaffold) — the separate (and incomplete) side-supply economy layer for resistance, distinct from this player stipend.
- [Economy Towns And Supply](Economy-Towns-And-Supply) — town ownership, supply ticks, and the wider funds model the stipend plugs into.
- [Faction Root Variables Reference](Faction-Root-Variables-Reference) — the `WFBE_C_GUER_*` constants and side-owner logics this system gates on.
- [Faction Unit And Vehicle Roster Catalog](Faction-Unit-And-Vehicle-Roster-Catalog) — full classname catalog for the GUE_*/TK_GUE_* units the depot pool draws from.
- [Gameplay Systems Atlas](Gameplay-Systems-Atlas) — the one-row atlas entry this page expands.
