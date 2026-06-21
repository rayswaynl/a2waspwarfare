# Tactical Support Menu Player Guide

> Source-verified 2026-06-21 against then-current master cf2a6d6a4; current origin/master is 0139a346, so recheck cited paths before current-head claims. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The Tactical Support Menu is the commander's primary special-action surface. It is opened from the main WF Menu (the Special button is enabled only for the team leader). The menu lists up to nine support options; items are greyed out when their prerequisite upgrade is missing, their personal fund balance is too low, or the cooldown has not elapsed.

---

## Opening the Menu

The Special button in `Client/GUI/GUI_Menu.sqf` is enabled only when `commandInRange` is true and the player is `leader WFBE_Client_Team`. `commandInRange` is set by the client FSM whenever a friendly Command Center building is within range (`Client/FSM/updateavailableactions.fsm:199`).

---

## Support Item Catalog

The list is built at runtime from four parallel arrays: `_addToList` (display names), `_addToListID` (internal IDs), `_addToListFee` (personal-fund cost deducted at firing — not side supply), and `_addToListInterval` (per-item cooldown in seconds). The list is then alphabetically sorted with `lbSort`, so the in-game order differs from the declaration order below. (`Client/GUI/GUI_Menu_Tactical.sqf:56-62`)

| ID (internal) | Display name | Personal fee | Cooldown | Upgrade gate | Module gate |
|---|---|---|---|---|---|
| `Fast_Travel` | Fast Travel | $0 (free mode) or per-km fee (fee mode) | none | `WFBE_UP_FASTTRAVEL` (index 12) | `WFBE_C_GAMEPLAY_FAST_TRAVEL > 0` |
| `ICBM` | ICBM | $75,000 | — | `WFBE_UP_ICBM` (index 11) | `WFBE_C_MODULE_WFBE_ICBM > 0` AND `!IS_air_war_event` |
| `Paradrop_Ammo` | Paradrop Ammo | $9,500 | 800 s | `WFBE_UP_SUPPLYPARADROP` (index 16) | always available when upgrade bought |
| `Paradrop_Vehicle` | Paradrop Vehicle | $3,500 | 600 s | `WFBE_UP_SUPPLYPARADROP` (index 16) | always available when upgrade bought |
| `Paratroopers` | Paratroopers | $8,500 | `WFBE_C_PLAYERS_SUPPORT_PARATROOPERS_DELAY` (1200 s) | `WFBE_UP_PARATROOPERS` (index 4) | always available |
| `Units_Camera` | Unit Camera | $0 | none | `commandInRange` | always available |
| `UAV` | UAV | $12,500 | — (one active at a time) | `WFBE_UP_UAV` (index 5) | UAV classname set for side |
| `UAV_Destroy` | UAV Destroy | $0 | — | UAV must be alive | — |
| `UAV_Remote_Control` | UAV Remote Control | $0 | — | UAV must be alive | — |

Sources: `Client/GUI/GUI_Menu_Tactical.sqf:56-62` (arrays), `Client/GUI/GUI_Menu_Tactical.sqf:244-285` (enable checks), `Common/Init/Init_CommonConstants.sqf:286` (paratroopers delay).

> Paradrop Ammo uses an 800 s interval; Paradrop Vehicle uses a 600 s interval. Both read and write the same `lastSupplyCall` variable, so firing either resets the other. `Client/GUI/GUI_Menu_Tactical.sqf:61`.

---

## Fast Travel

**What it does.** Teleports the player (and nearby friendly group vehicles within `WFBE_C_GAMEPLAY_FAST_TRAVEL_RANGE` = 175 m) to the clicked map destination. A map animation plays during transit; the player is placed safely at the destination using `PlaceSafe`. `Client/GUI/GUI_Menu_Tactical.sqf:379-461`.

**Two modes** controlled by `WFBE_C_GAMEPLAY_FAST_TRAVEL` (`Common/Init/Init_CommonConstants.sqf:235`):

| Value | Behaviour |
|---|---|
| `0` | Disabled — item greyed out regardless of upgrade |
| `1` (default) | Free — no fee deducted |
| `2` | Fee per km — deducted from personal funds at travel time |

**Fee mode parameters** (all hardcoded, not mission parameters):

| Constant | Value | Meaning |
|---|---|---|
| `WFBE_C_GAMEPLAY_FAST_TRAVEL_RANGE` | 175 m | Proximity required to a valid origin (HQ, fully-capped town, or Command Center) |
| `WFBE_C_GAMEPLAY_FAST_TRAVEL_RANGE_MAX` | 3500 m | Maximum destination distance shown on map |
| `WFBE_C_GAMEPLAY_FAST_TRAVEL_PRICE_KM` | $215 | Cost per km in fee mode |
| `WFBE_C_GAMEPLAY_FAST_TRAVEL_TIME_COEF` | 0.8 | Scales map animation duration relative to distance |

Source: `Common/Init/Init_CommonConstants.sqf:244-247`.

**Valid origins.** The code checks (in priority order): deployed side HQ within range → closest fully-captured town within range → side Command Center within range. If none qualify, the button is disabled. `Client/GUI/GUI_Menu_Tactical.sqf:146-193`.

**Valid destinations.** Fully-captured friendly towns and side Command Centers that are more than 175 m away and no more than 3500 m away. In fee mode destinations the player cannot afford are also excluded. Yellow `mil_circle` markers appear on the map to indicate reachable destinations. Clicking within 500 m of a marker confirms the jump. `Client/GUI/GUI_Menu_Tactical.sqf:194-226, 381-424`.

**Vehicles carried.** Any vehicle in the player's group that is within `WFBE_C_GAMEPLAY_FAST_TRAVEL_RANGE` of the origin, is moving-capable (`canMove`), is not a static weapon, and is not stopped or on a WAIT/STOP command is teleported with the player. `Client/GUI/GUI_Menu_Tactical.sqf:409`.

**Upgrade cost (USMC baseline):** $1,500 (one level). Prerequisites: Light Factory level 1 + Supply level 1. `Common/Config/Core_Upgrades/Upgrades_USMC.sqf:44,103`. Costs shown are from `Upgrades_USMC.sqf`; Combined Ops (CO) Chernarus loads `Upgrades_CO_US.sqf` for the West side when `WF_A2_CombinedOps` is true. Verify against the CO file if values differ.

---

## UAV

**What it does.** Spawns a UAV at the nearest side Command Center and gives the player remote control via the OA interface (`Client/Module/UAV/uav_interface_oa.sqf`) plus a spotter script that marks enemy contacts on the map. `Client/Module/UAV/uav.sqf:1-55`.

**Cost.** $12,500 deducted from personal funds at the moment of spawn. `Client/Module/UAV/uav.sqf:50`.

**One active at a time.** Selecting UAV while `playerUAV` is already alive re-opens the interface rather than spawning a second aircraft. `Client/Module/UAV/uav.sqf:4-12`.

**Gunner slot is BLUFOR-only.** The gunner crew member (and Hellfire capability) is created only when `sideJoined == west`. OPFOR UAVs spawn with a driver only. `Client/Module/UAV/uav.sqf:42-46`.

**UAV classnames by faction:**

| Faction root | Vehicle classname |
|---|---|
| USMC | `MQ9PredatorB` |
| US | `MQ9PredatorB_US_EP1` |
| US Camo | `MQ9PredatorB_US_EP1` |
| CDF | `MQ9PredatorB` |
| RU | `Pchela1T` |
| INS | `Pchela1T` |
| GUE, TKA, TKGUE, PMC | no UAV variable set — UAV item disabled |

Sources: `Common/Config/Core_Root/Root_USMC.sqf:18`, `Root_US.sqf:18`, `Root_CDF.sqf:18`, `Root_RU.sqf:17`, `Root_INS.sqf:17`. GUE/TKA/TKGUE/PMC root files contain no UAV assignment; the `uav.sqf` exits early when the variable is nil or empty (`Client/Module/UAV/uav.sqf:15-16`).

**UAV Destroy.** Sets damage 1 on all crew and the vehicle and nulls `playerUAV`. No cost. Enabled only while the UAV is alive. `Client/GUI/GUI_Menu_Tactical.sqf:278-280,329-335`.

**UAV Remote Control.** Re-opens the UAV interface without respawning the aircraft. Enabled only while the UAV is alive. `Client/GUI/GUI_Menu_Tactical.sqf:281-283,336-339`.

**Upgrade cost (USMC baseline):** $2,000 (one level). Prerequisite: Air Factory level 2. Research time: 60 s. `Common/Config/Core_Upgrades/Upgrades_USMC.sqf:37,95,126`.

---

## Paratroopers

**What it does.** Sends a faction transport aircraft loaded with AI infantry to the clicked map position. The server selects a random map-edge spawn point, flies the aircraft to the target, and drops soldiers by parachute. `Server/Support/Support_Paratroopers.sqf`.

**Cost.** $8,500 from personal funds. Cooldown: 1200 s (20 minutes). `Client/GUI/GUI_Menu_Tactical.sqf:60,61`.

**Upgrade levels.** Three levels unlock progressively heavier squad compositions. Example for USMC:

| Level | Squad composition (classnames) |
|---|---|
| 1 | SL, LAT, Soldier ×2, AR, Medic |
| 2 | SL, AT ×3, AA, MG, Medic, Spotter, Sniper |
| 3 | FR Assault, HAT ×4, AA ×2, FR AR, FR AC, Medic, FR Marksman, AT, Sniper |

Source: `Common/Config/Core_Root/Root_USMC.sqf:31-33`. RU uses equivalent compositions from `Root_RU.sqf:30-32`. The aircraft is the faction PARACARGO vehicle (`C130J` for USMC, `Mi17_Ins` for RU).

**Upgrade cost (USMC baseline):** $1,500 / $2,500 / $3,500 for levels 1/2/3. Prerequisites: Barracks + Air Factory + Gear all at matching level. `Common/Config/Core_Upgrades/Upgrades_USMC.sqf:36,90-93`.

---

## Ammo Paradrop and Vehicle Paradrop

Both call `RequestSpecial` on the server and share the same `lastSupplyCall` cooldown variable. Both require the `WFBE_UP_SUPPLYPARADROP` upgrade (index 16). Paradrop Ammo interval is 800 s; Paradrop Vehicle interval is 600 s. `Client/GUI/GUI_Menu_Tactical.sqf:61,267-272,509-529`.

| Item | Fee | Cooldown | Server handler | Delivered asset (USMC) | Delivered asset (RU) |
|---|---|---|---|---|---|
| Paradrop Ammo | $9,500 | 800 s | `ParaAmmo` / `Server/Support/Support_ParaAmmo.sqf` | MH-60S dropping ammo crates (`USBasicAmmunitionBox`, `USBasicWeaponsBox`, `USLaunchersBox`) | Mi-17 dropping RU ammo crates (`RUBasicAmmunitionBox`, `RUBasicWeaponsBox`, `RULaunchersBox`) |
| Paradrop Vehicle | $3,500 | 600 s | `ParaVehi` / `Server/Support/Support_ParaVehicles.sqf` | MH-60S carrying parachuted `MtvrRepair` | Mi-17 carrying parachuted `KamazRepair` |

Sources: `Common/Config/Core_Root/Root_USMC.sqf:38-40`, `Root_RU.sqf:36-38`, `Server/Init/Init_Server.sqf:40,42`.

**Upgrade cost (USMC baseline):** $2,000 (one level). Prerequisite: Airlift upgrade level 1. Research time: 50 s. `Common/Config/Core_Upgrades/Upgrades_USMC.sqf:48,108,137`.

---

## ICBM

**What it does.** Launches a ballistic missile strike on the clicked map position. The commander sees a confirmation prompt before the fee is deducted. A red `mil_warning` marker and ellipse appear on the map; both are cleaned up after impact. All players on both sides receive an audio and text warning message. `Client/GUI/GUI_Menu_Tactical.sqf:463-507`.

**Costs.** The personal-fund fee is $75,000 (deducted client-side at fire). The upgrade purchase cost is $49,500 personal + $80,000 side supply (the second element of the cost tuple). Research time: 300 s. `Common/Config/Core_Upgrades/Upgrades_USMC.sqf:43,132`.

**Damage radius.** 800 m (`ICBM_DAMAGE_RADIUS`). Radiation zone radius: 900 m (`ICBM_RADIATION_RADIUS`). `Client/Module/Nuke/ICBM_Init.sqf:1-2`.

**Time to impact.** Default 1 minute (`WFBE_ICBM_TIME_TO_IMPACT = 1`). Configurable as a mission parameter. `Common/Init/Init_CommonConstants.sqf:256`.

**Gates.**

| Gate | Condition |
|---|---|
| Module | `WFBE_C_MODULE_WFBE_ICBM > 0` (default `1`) |
| Event exclusion | `IS_air_war_event` must be false — ICBM is disabled during the Air War event |
| Role | Caller must be in `commanderTeam` |
| Funds | Personal balance `>= $75,000` |
| Upgrade | `WFBE_UP_ICBM` (index 11) purchased — requires Air Factory level 3 |

Sources: `Client/GUI/GUI_Menu_Tactical.sqf:253-260`, `Common/Config/Core_Upgrades/Upgrades_USMC.sqf:17,43,101`, `Common/Init/Init_CommonConstants.sqf:254,256`, `initJIPCompatible.sqf:128-141`.

---

## Unit Camera

**What it does.** Opens the Unit Camera dialog (`RscMenu_UnitCamera`) which lists all human players in the side and lets the commander spectate any of them. No fee. `Client/GUI/GUI_Menu_Tactical.sqf:284-285,340-342`.

**Gate.** `commandInRange` must be true (player's group is near a Command Center). No upgrade required. The button is greyed out away from base.

---

## Continue Reading

- [Support-Specials-And-Tactical-Modules-Atlas](Support-Specials-And-Tactical-Modules-Atlas) — server-authority and trust-boundary detail for RequestSpecial calls
- [Upgrade-Research-Cross-Faction-Reference](Upgrade-Research-Cross-Faction-Reference) — full upgrade trees with costs, times, and prerequisites for all factions
- [Commanders-Handbook](Commanders-Handbook) — broader commander role overview including economy, construction, and unit management
- [Factory-And-Purchase-Systems-Atlas](Factory-And-Purchase-Systems-Atlas) — how the upgrade tree integrates with the factory build chain
- [Supply-Mission-Architecture](Supply-Mission-Architecture) — side supply mechanics that fund the ICBM upgrade purchase
