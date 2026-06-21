# Bank, Reserve and Artillery Radar (Experital Endgame Structures)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted (other roots: Server/, Common/, Client/). Arma 2 OA 1.64.

Three buildable structures ship under the source's **EXPERITAL FEATURES** block (`Common/Init/Init_CommonConstants.sqf:575`), each toggled by its own constant and **enabled by default** (`= 1`): the **Bank**, the **Reserve**, and the **Artillery Radar**. They are appended to the WEST and EAST structure build menus only. The fourth experital structure, the Counter-Battery Radar, has its own page — see [Counter-Battery Radar System](Counter-Battery-Radar-System).

The Bank is a full economy + raid subsystem (a periodic dividend to its side, and a large reward to whoever destroys it). The Reserve and Artillery Radar carry no unique gameplay logic of their own — they spawn a small decorative prop cluster and otherwise behave like any buildable structure (map-marker label, build announcement). This page documents all three on stable master.

## Overview

| Structure | Gate constant (default) | Menu label (WEST / EAST) | Cost | Build time | Model | Definition |
| --- | --- | --- | ---: | ---: | --- | --- |
| Bank | `WFBE_C_ECONOMY_BANK` (`1`) | Federal Reserve / Bank Rossii | $9500 | 300s | `Land_fortified_nest_big_EP1` | `Structures_CO_US.sqf:110-119` |
| Artillery Radar | `WFBE_C_STRUCTURES_ARTILLERYRADAR` (`1`) | Artillery Radar | $2400 | 60s | `Land_Antenna` (reskin) | `Structures_CO_US.sqf:121-130` |
| Reserve | `WFBE_C_STRUCTURES_RESERVE` (`1`) | Reserve | $2000 | 60s | `Land_fortified_nest_small` | `Structures_CO_US.sqf:132-141` |

Gate constants are set in the experital block at `Common/Init/Init_CommonConstants.sqf:577-579`. All three use the `MediumSite` construction site type (`Structures_CO_US.sqf:116`, `:127`, `:138`) and are valid structure types in the build dispatcher (`Server/PVFunctions/RequestStructure.sqf:14`). Build time is `1` second when `WF_Debug` is on (`Structures_CO_US.sqf:115`, `:126`, `:137`). Costs/models above are for the default Chernarus Combined-Operations factions (US for WEST, RU for EAST); the EAST file mirrors WEST and only the Bank's display label differs — `"Bank Rossii"` (`Common/Config/Core_Structures/Structures_CO_RU.sqf:113`) versus `"Federal Reserve"` (`Structures_CO_US.sqf:113`). Other faction roots load additional structure files (e.g. `Structures_USMC.sqf:109-111` also defines the Bank).

The Artillery Radar and Reserve models are deliberate reskins of small, proven-buildable objects: `_ARTRAD = "Land_Antenna"` (`Structures_CO_US.sqf:15`) and `_RES = "Land_fortified_nest_small"` (Chernarus) / `Land_fortified_nest_small_EP1` (other maps) (`Structures_CO_US.sqf:16`). The Artillery Radar's menu label is hardcoded because `Land_Antenna`'s `displayName` is "Antenna" (`Structures_CO_US.sqf:124`).

## The Bank (Federal Reserve / Bank Rossii)

### Build rules

The Bank is **single-instance per side** and must be placed **outside the side's own base protection area**, both enforced server-side in `RequestStructure.sqf`:

| Rule | Behavior | Evidence |
| --- | --- | --- |
| One per side | If the side's bank reference is non-null and alive, the build is rejected and the side is shown the `BankAlreadyBuilt` message. | `RequestStructure.sqf:37-40` |
| Outside own base | The placement is rejected with `BankTooCloseToBase` if it lies within `WFBE_C_BASE_PROTECTION_RANGE` (default `800` m) of the side's base areas. | `RequestStructure.sqf:45`, `:51-52` |

The per-side reference variables `WFBE_BANK_WEST` and `WFBE_BANK_EAST` are initialised to `objNull` at server start when the gate is on (`Server/Init/Init_Server.sqf:118-120`).

### On build

When a Bank finishes construction, `Server/Construction/Construction_MediumSite.sqf` (the `MediumSite` handler) runs the Bank branch (`:126-145`):

1. Spawns faction composition dressing from template `WFBE_NEURODEF_BANK_<SIDE>` via `WFBE_SE_FNC_SpawnStructureDressing` (`:128-129`; templates defined in `Server/Init/Init_Defenses.sqf`).
2. Registers itself in the single-instance reference `WFBE_BANK_WEST` / `WFBE_BANK_EAST` (`:131-132`).
3. Creates a global `mil_warning` map marker `wfbe_bank_<side>` — colored `ColorBlue` with text `"FEDERAL RESERVE"` for WEST, `ColorRed` with text `"BANK ROSSII"` for EAST (`:134-140`).
4. Spawns the income loop `WFBE_SE_FNC_BankIncome` (`:143`).

### Income dividend

`Server/Functions/Server_BankIncome.sqf` runs a per-bank loop for as long as the Bank is alive:

| Parameter | Value | Evidence |
| --- | --- | --- |
| Payout interval | 300 s (5 minutes) | `Server_BankIncome.sqf:20` |
| Dividend pool per tick | Fixed $6000, split among the side's living players | `Server_BankIncome.sqf:21`, `:38-41` |
| Per-player share | `round(6000 / (playerCount max 1))` | `Server_BankIncome.sqf:40` |
| No-HQ skip | Payout is skipped if the side has no deployed (alive) HQ | `Server_BankIncome.sqf:33-35` |

The pool is a **fixed total**, not a per-player amount: the loop counts living players on the owning side across `playableUnits`, divides the $6000, and sends the share side-targeted via `[_side, "BankPayout", [_share]] Call WFBE_CO_FNC_SendToClients` (`Server_BankIncome.sqf:38-41`) — not a raw public variable. The client handler `Client/PVFunctions/BankPayout.sqf` credits **only living players** (it exits early if the player is dead, `:16`), applies the amount with `WFBE_CL_FNC_ChangeClientFunds` (`:17`), and shows a `BankDividend` group-chat line (`:19`). The dead-player guard keeps total paid out within the $6000 pool.

### Destruction raid reward

When a Bank is destroyed, `Server/Functions/Server_BuildingKilled.sqf` runs the Bank special case (`:88-111`): it clears the side registry to `objNull` (`:91`), deletes the map marker (`:92-93`), and — only if the killer is a player and it is **not** a teamkill (`:94`) — pays a split reward:

| Reward | Value | Recipient | Evidence |
| --- | --- | --- | --- |
| Side supply | +10000 (clamped at the supply ceiling) | The raiding side (commander pool) | `Server_BuildingKilled.sqf:103` |
| Cash bonus | $25000 | The killing player, routed by real UID | `Server_BuildingKilled.sqf:102`, `:104` |

The cash bonus reuses the same `BankPayout` client handler, addressed to the killer's real `getPlayerUID` (`:104`) — the comment notes this avoids the display-masked UID paying $0 when `WFBE_C_GAMEPLAY_UID_SHOW == 0`. A global `BankDestroyed` message (with the killer's name and the bank's side name) is broadcast to everyone (`:108`).

## Artillery Radar and Reserve

Unlike the Bank, the Artillery Radar and Reserve carry **no unique gameplay logic** on stable master. Their `MediumSite` branch (`Construction_MediumSite.sqf:153-158`) only spawns a faction composition dressing from `WFBE_NEURODEF_<TYPE>_<SIDE>`. The effective templates are the **2026-06-14 owner-override** definitions — `WFBE_NEURODEF_ARTILLERYRADAR_WEST`/`_EAST` at `Server/Init/Init_Defenses.sqf:226`/`:233` and `WFBE_NEURODEF_RESERVE_WEST`/`_EAST` at `:240`/`:247` — which re-set the four variables *after* the earlier WDDM walled-compound versions (`:151`/`:173`/`:201`/`:221`), so the compound versions are overridden and dead. The override dressing is a **tight cluster of ≤6 themed props** (the core model plus ≤5 small items such as crates, a camo net, a bagfence and a flag, all within ~3.5 m) with **0 walls** (`Init_Defenses.sqf:223-225`).

Because the dressing is decorative props rather than wall rings, the Artillery Radar and Reserve (plus the Bank and AARadar) are **excluded from the auto-wall construction pass** (`Construction_MediumSite.sqf:160`, `:165-167`). Like every buildable, each still gets a structure map-marker label — `"AR"` for the Artillery Radar and `"RES"` for the Reserve (`Client/Functions/Client_GetStructureMarkerLabel.sqf:22-23`) — and a localized "building started" command-chat announcement (see [Localization keys](#localization-keys)). What they lack is any fire-mission, detection, income or other unique runtime behaviour.

The Artillery Radar carries no fire-mission or detection logic of its own — it is a buildable cosmetic/fort piece (the menu name is hardcoded; the model is a reskinned antenna). The actual counter-battery detection feature is a separate structure documented in [Counter-Battery Radar System](Counter-Battery-Radar-System).

## AI commander behaviour

The AI commander builds all three structures, gated behind an economy threshold so it does not waste early supply (`Server/AI/Commander/AI_Commander_Base.sqf:264-298`). The gate is human-player-agnostic — players are unaffected:

- The side must hold **more than `WFBE_C_AICOM_ECON_GATE_TOWNS` towns** (default `6`) — `AI_Commander_Base.sqf:265`, `:267`.
- And current supply must exceed **1.5× the structure's construction cost** — `AI_Commander_Base.sqf:272` (Bank), `:283` (Reserve), `:294` (Artillery Radar).

Only when both conditions hold is the structure added to the AI's build order.

## Localization keys

| Key | Used for | Evidence |
| --- | --- | --- |
| `BankDividend` | Per-tick dividend group-chat line | `stringtable.xml:9506` |
| `BankDestroyed` | Global bank-destroyed broadcast | `stringtable.xml:9503` |
| `BankAlreadyBuilt` | One-per-side build rejection | `stringtable.xml:9497` |
| `BankTooCloseToBase` | Base-proximity build rejection | `stringtable.xml:9500` |
| `RB_Artillery_Radar` | Localized building name in the "building started" chat line — **not** the build-menu label, which is the hardcoded literal at `Structures_CO_US.sqf:124` | `stringtable.xml:4931`; consumed at `Client/Functions/Client_FNC_Special.sqf:176`, `:188` |
| `RB_Reserve` | Localized building name in the "building started" chat line — menu label is hardcoded at `Structures_CO_US.sqf:135` | `stringtable.xml:4947`; consumed at `Client/Functions/Client_FNC_Special.sqf:179`, `:188` |

## Configuration

| Gate | Default | Effect |
| --- | --- | --- |
| `WFBE_C_ECONOMY_BANK` | `1` (on) | Adds the Bank to WEST/EAST build menus and enables its income, raid reward and registry (`Init_CommonConstants.sqf:577`). |
| `WFBE_C_STRUCTURES_ARTILLERYRADAR` | `1` (on) | Adds the Artillery Radar buildable (`Init_CommonConstants.sqf:578`). |
| `WFBE_C_STRUCTURES_RESERVE` | `1` (on) | Adds the Reserve buildable (`Init_CommonConstants.sqf:579`). |
| `WFBE_C_BASE_PROTECTION_RANGE` | `800` | Minimum distance the Bank must be placed from the side's own base; defined at `Init_CommonConstants.sqf:254`, read at `RequestStructure.sqf:45`. |
| `WFBE_C_AICOM_ECON_GATE_TOWNS` | `6` | Town count the AI commander must exceed before it builds Bank/Reserve/Artillery Radar (`AI_Commander_Base.sqf:265`). |

All three structure gates sit in the experimental feature block (`Init_CommonConstants.sqf:575-579`); set a gate to `0` to remove that structure from the build menu.

## Continue Reading

- [Counter-Battery Radar System](Counter-Battery-Radar-System) — the fourth experital structure (the one with active detection logic)
- [Construction and CoIn Systems Atlas](Construction-And-CoIn-Systems-Atlas) — how buildable structures are requested, sited and constructed
- [Economy, Towns and Supply](Economy-Towns-And-Supply) — the funds/supply economy the Bank feeds into
- [Faction Base Structures Catalog](Faction-Base-Structures-Catalog) — the standard (non-experital) base structures and their costs
- [Victory and Endgame Atlas](Victory-And-Endgame-Atlas) — endgame mechanics these structures are designed for
