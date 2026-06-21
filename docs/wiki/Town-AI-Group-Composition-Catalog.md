# Town AI Group Composition Catalog (garrison & defender group selection per town)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page catalogs the **town AI group library** — the named infantry and vehicle group templates that populate towns, and the server logic that selects which ones spawn. These are the groups that occupy a town when a side captures it and the resistance garrison that defends an uncaptured town. They are loaded **server-side only** and are separate from the commander-deployable squads in the [AI Squad Team Templates Catalog](AI-Squad-Team-Templates-Catalog) (`Core_Squads/Squad_*.sqf`) and from the individual purchasable units in the [Faction Unit and Vehicle Roster Catalog](Faction-Unit-And-Vehicle-Roster-Catalog).

---

## Data Model and Loading

Each faction's `Common/Config/Groups/Groups_<faction>.sqf` builds two parallel arrays — `_k` (group-type keys) and `_l` (unit-classname rosters, one per key) — then hands them to `Config_Groups.sqf` (`Groups_US.sqf:273`):

```sqf
[_k,_l,_side,_faction] Call Compile preprocessFile "Common\Config\Config_Groups.sqf"
```

`Config_Groups.sqf` stores each roster into `missionNamespace` under `WFBE_<side>_GROUPS_<key>`, **appending** when a key repeats so the variable holds a list of interchangeable rosters (`Config_Groups.sqf:12-19`):

```sqf
WFBE_<side>_GROUPS_<key> = [ roster1, roster2, ... ]
```

At spawn time the selector picks one roster at random from that list (`Server_GetTownGroups.sqf:208`: `_get select floor(random count _get)`). This is why several `Groups_*.sqf` files define the same key twice (e.g. `Groups_CDF.sqf` lists `Squad` twice) — each duplicate adds a composition variant to the random pool.

The three active faction group files are loaded **only on the server**, indexed by the active faction per side (`Common/Init/Init_Common.sqf:313-317`):

```sqf
if (isServer) then {
    Call Compile preprocessFileLineNumbers Format["Common\Config\Groups\Groups_%1.sqf",_grpWest];
    Call Compile preprocessFileLineNumbers Format["Common\Config\Groups\Groups_%1.sqf",_grpEast];
    Call Compile preprocessFileLineNumbers Format["Common\Config\Groups\Groups_%1.sqf",_grpRes];
};
```

`_grpWest/East/Res` resolve to the active faction in each side's pool (WEST `CDF/US/USMC`, EAST `INS/RU/TKA`, GUER `GUE/PMC/TKGUE`; Chernarus actives are `USMC`/`RU`/`GUE`). See the [Defense Structures Catalog](Defense-Structures-Catalog) for the faction-pool resolution shared by both systems.

---

## Two Key Schemes

The faction group files fall into two distinct key schemes, matched to the two selectors below.

| Scheme | Keys | Faction files | Selected by |
|---|---|---|---|
| **Upgrade-suffixed** | `Squad_0..3`, `Squad_Advanced`, `Team_0..3`, `Team_MG_0..3`, `Team_AT_0..3`, `Team_AA`, `Team_Sniper_0..3`, `Motorized_0..4`, `AA_Light`, `AA_Heavy`, `Mechanized_0..4`, `Armored_0..4` | `Groups_US.sqf`, `Groups_USMC.sqf`, `Groups_RU.sqf`, `Groups_TKA.sqf` | Attacker selector (by supply + upgrade level) |
| **Non-suffixed** | `Squad`, `Squad_Advanced`, `Team`, `Team_MG`, `Team_AT`, `Team_AA`, `Team_Sniper`, `Motorized`, `AA_Light`, `AA_Heavy`, `Mechanized`, `Mechanized_Heavy`, `Armored_Light`, `Armored_Heavy` | `Groups_CDF.sqf`, `Groups_INS.sqf`, `Groups_GUE.sqf`, `Groups_PMC.sqf`, `Groups_TKGUE.sqf` | Defender selector (by town type) |

Source: `_k` key lists across `Common/Config/Groups/Groups_*.sqf`. On both Chernarus and Takistan the active WEST and EAST factions use suffixed files (attacker path), and the active GUER faction uses a non-suffixed file (defender/resistance path).

`server_town_ai.sqf` routes each side to the matching selector (`Server/FSM/server_town_ai.sqf:184-189`):

```sqf
if (_side == WFBE_DEFENDER) then {
    _groups = [_town, _side] Call WFBE_SE_FNC_GetTownGroupsDefender
} else {
    _groups = [_town, _side] Call WFBE_SE_FNC_GetTownGroups;
};
```

`WFBE_DEFENDER` is the resistance side (`Common/Init/Init_Common.sqf:296`: `WFBE_DEFENDER = resistance`). Both selectors are bound at `Server/Init/Init_Server.sqf:66-67`. When a town has only air threats and no ground enemies, the same calls run with a third `true` argument (`_aa_get`) that restricts the result to AA groups (`server_town_ai.sqf:200-202`).

---

## Attacker Garrison Selection — `Server_GetTownGroups.sqf`

A capturing/holding side garrisons a town with a group set scaled by the town's `supplyValue` (`_sv`). Each entry is `[group-type, force, kind]` where **force** is how many copies enter the weighted random pool (higher = more likely) and **kind** is `0` infantry / `1` vehicle. The infantry-key suffix is the side's current upgrade level: `Squad_<barracks>` / `Team_*_<barracks>` use `WFBE_UP_BARRACKS`, `Motorized_<light>` uses `WFBE_UP_LIGHT`, and `Mechanized_<heavy>` / `Armored_<heavy>` use `WFBE_UP_HEAVY` (`Server_GetTownGroups.sqf:25-27`; indices `WFBE_UP_BARRACKS=0`, `WFBE_UP_LIGHT=1`, `WFBE_UP_HEAVY=2` at `Common/Init/Init_CommonConstants.sqf:37-39`). Below, `B`/`L`/`H` denote those upgrade-level suffixes.

| supplyValue | Group types (force in parentheses) | % infantry | `_groups_max` | Source |
|---|---|---:|---:|---|
| `< 10` | `Team_B`, `Team_AT_B` | 100 | 2 | `:31-37` |
| `10–20` | `Team_B`(2), `Team_MG_B`(2), `Team_AT_B`, `Motorized_L` | 80 | 4 | `:39-47` |
| `20–40` | `Squad_B`, `Team_MG_B`, `Team_B`, `Team_AT_B`, `Team_AA`, `Team_Sniper_B`, `Motorized_L`, `Mechanized_H` | 80 | 4 | `:49-61` |
| `40–60` | `Squad_B`, `Team_MG_B`, `Team_B`, `Team_AT_B`, `Squad_Advanced`/`Squad_B`(2), `Motorized_L`, `AA_Light`, `Mechanized_H`(2) | 75 | 5 | `:64-76` |
| `60–80` | `Squad_B`, `Team_MG_B`, `Team_B`, `Team_AA`(2), `Team_AT_B`(2), `Team_Sniper_B`, `Motorized_L`(2), `Mechanized_H`(2) | 70 | 5 | `:79-91` |
| `80–100` | `Squad_B`, `Team_MG_B`, `Team_B`, `Team_AT_B`(2), `Squad_Advanced`/`Squad_B`(3), `Mechanized_H`(2), `Armored_H` | 70 | 6 | `:94-105` |
| `100–120` | `Squad_B`, `Team_MG_B`, `Team_B`, `Team_AA`, `Team_AT_B`(2), `Squad_Advanced`/`Squad_B`(2), `Team_Sniper_B`, `Mechanized_H`(2), `Armored_H`(3) | 70 | 6 | `:108-121` |
| `>= 120` | `Squad_B`, `Team_MG_B`, `Team_B`, `Team_AA`, `Team_AT_B`(3), `Squad_Advanced`/`Squad_B`(2), `Team_Sniper_B`, `Mechanized_H`, `Armored_H`(3) | 70 | 7 | `:123-136` |

The `Squad_Advanced`/`Squad_B` entries resolve to `Squad_Advanced` only when the barracks upgrade is at max level 3, otherwise `Squad_B` (`:70`, `:100`, `:115`, `:130`).

---

## Resistance Defender Selection — `Server_GetTownGroupsDefender.sqf`

The resistance garrison of an uncaptured town is scaled by the town's `wfbe_town_type` rather than supply, and uses the non-suffixed keys. Same `[group-type, force, kind]` shape.

| Town type | Group types (force in parentheses) | % infantry | `_groups_max` | Source |
|---|---|---:|---:|---|
| `TinyTown1` | `Squad`, `Team`, `Squad_Advanced`, `Team_MG` | 100 | 3 | `:24-27` |
| `SmallTown1` | `Squad`, `Team`(2), `Squad_Advanced`, `Team_AT`, `AA_Light`, `Motorized`, `Mechanized` | 80 | 5 | `:29-32` |
| `SmallTown2` | `Squad_Advanced`, `Team`, `Team_MG`, `Team_AT`(2), `Motorized`, `AA_Light`, `Armored_Light` | 80 | 5 | `:34-37` |
| `MediumTown1` | `Team`(3), `Team_Sniper`, `Team_MG`, `Team_AT`, `Motorized`, `Mechanized`, `AA_Light`, `Mechanized_Heavy`(2), `Armored_Light` | 80 | 6 | `:39-42` |
| `MediumTown2` | `Team`(3), `Team_Sniper`, `Team_MG`, `Team_AT`, `Motorized`, `Mechanized`(2), `AA_Light`, `Mechanized_Heavy`, `Armored_Light` | 80 | 6 | `:44-47` |
| `LargeTown1` | `Squad`, `Team`(2), `Team_Sniper`, `Team_MG`, `AA_Light`(2), `Team_AT`, `Mechanized_Heavy`(2), `Armored_Light`(2), `Armored_Heavy` | 75 | 7 | `:49-52` |
| `LargeTown2` | `Squad_Advanced`, `Team`(2), `Team_Sniper`, `Team_MG`, `AA_Light`(2), `Team_AT`(2), `Mechanized_Heavy`, `Armored_Light`, `Armored_Heavy`(2) | 75 | 7 | `:54-57` |
| `HugeTown1` | `Squad`(3), `Team`(2), `Squad_Advanced`(2), `Team_Sniper`, `Team_MG`, `AA_Heavy`(2), `Team_AT`(2), `Mechanized_Heavy`, `Armored_Light`(2), `Armored_Heavy`(2) | 75 | 8 | `:59-62` |
| `HugeTown2` | `Squad`(2), `Team`(3), `Squad_Advanced`(2), `Team_Sniper`, `Team_MG`, `AA_Heavy`(2), `Team_AT`(2), `Mechanized_Heavy`, `Armored_Light`(2), `Armored_Heavy`(2) | 75 | 8 | `:64-67` |
| `PMCAirfield` | `Squad`, `Team`, `Team_AT`, `Team_Sniper`, `Motorized`(2), `AA_Light` | 70 | 6 | `:69-72` |
| *default* | `Squad`, `Team`, `Team_AT`, `Motorized` | 80 | 3 | `:74-77` |

A faction's group file need not define every key the selector references — the build loop guards each lookup with `isNil` (`Server_GetTownGroups.sqf:149`, `Server_GetTownGroupsDefender.sqf` equivalent). A referenced key that the active faction lacks (e.g. `Groups_GUE.sqf` defines no `Team_MG`) is simply skipped, so that town spawns without that group type.

---

## Selection Mechanics

- **Group count.** `_groups_max` from the table is multiplied by an occupation coefficient and rounded. Attacker uses `WFBE_C_TOWNS_UNITS_COEF` (`Server_GetTownGroups.sqf:141`); defender uses `WFBE_C_TOWNS_UNITS_DEFENDER_COEF` (`Server_GetTownGroupsDefender.sqf:82`). Both ladder `1 / 1.5 / 2 / 2.5` off their occupation/defender setting (`Common/Init/Init_CommonConstants.sqf:678-679`).
- **Infantry / vehicle split.** The pool is split by the `% infantry` column into infantry (`kind 0`) and vehicle (`kind 1`) groups, each shuffled, then interleaved up to `_groups_max` (`Server_GetTownGroups.sqf:168-199`). If one kind is empty the split collapses to 100 % of the other (`:168-169`).
- **AA gating.** When called with `_aa_get = true` (air-only threat), only `AA_Light` / `AA_Heavy` / `Team_AA` groups are kept and `_groups_max` is capped at 3 (`Server_GetTownGroups.sqf:143,150-155`). Conversely, while a town already has active air (`wfbe_active_air`), those AA group types are excluded from a normal ground spawn (`:154`).
- **Group-count merge (server-FPS optimization).** Before returning, infantry rosters are fused into fewer flat groups targeting `WFBE_C_TOWNS_MERGE_TARGET` units each (default 5, hard cap 10), so a town spawns the same units in fewer server group-brains; vehicle rosters are never merged. Set the target to `0` to disable (`Server_GetTownGroups.sqf:214-244`; constant `Common/Init/Init_CommonConstants.sqf:680`). The defender variant has its own `WFBE_C_TOWNS_MERGE_TARGET_DEFENDER` / `WFBE_C_TOWNS_MERGE_CAP_DEFENDER` overrides (`Server_GetTownGroupsDefender.sqf` merge block).

---

## Composition Examples

The roster behind each key is a flat list of unit classnames. Two representative entries (Chernarus actives):

| Key | Faction file | Roster | Source |
|---|---|---|---|
| `Squad_0` (attacker) | `Groups_USMC.sqf` | `USMC_Soldier_GL`, `USMC_Soldier_MG`, `USMC_Soldier_LAT`, `USMC_Soldier_GL`, `USMC_Soldier_LAT`, `USMC_Soldier_Medic` | `Groups_USMC.sqf:12-19` |
| `Squad` (defender) | `Groups_GUE.sqf` | `GUE_Soldier_CO`, `GUE_Soldier_GL`, `GUE_Soldier_AR`, `GUE_Soldier_1` | `Groups_GUE.sqf:12-18` |

Vehicle keys carry vehicle classnames instead — e.g. `Armored_4` in `Groups_USMC.sqf` is three `M1A2_TUSK_MG` (`Groups_USMC.sqf:267-272`). Per-unit classname details live in the [Faction Unit and Vehicle Roster Catalog](Faction-Unit-And-Vehicle-Roster-Catalog).

---

## Continue Reading

- [AI-Squad-Team-Templates-Catalog](AI-Squad-Team-Templates-Catalog) — the sibling system: commander-deployable squad templates (`Core_Squads/Squad_*.sqf`), distinct from these town groups
- [Faction-Unit-And-Vehicle-Roster-Catalog](Faction-Unit-And-Vehicle-Roster-Catalog) — the individual unit and vehicle classnames that make up these rosters
- [Towns-Camps-And-Capture-Atlas](Towns-Camps-And-Capture-Atlas) — town types, capture flow, and the `server_town_ai.sqf` lifecycle that calls these selectors
- [Economy-Towns-And-Supply](Economy-Towns-And-Supply) — `supplyValue` and town economy that scale the attacker garrison
- [Upgrades-And-Research-Atlas](Upgrades-And-Research-Atlas) — the BARRACKS/LIGHT/HEAVY upgrades that drive the suffixed-key tier
