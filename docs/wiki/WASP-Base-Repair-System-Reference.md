# WASP Base-Repair System Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The `WASP/baserep/` subtree is a client-side, commander-only base-repair feature layered on top of stock Warfare BE. When the player's group is the commander team, looking at a friendly base structure with the cursor shows a live damage HUD; if the structure is damaged and within range, a "Repair" scroll action appears. Activating it plays a medic animation and slowly heals the building, draining that side's supply by 15 every tick. Spotters get a read-only variant that shows enemy building health at range. This page documents the four-file subtree end to end. The broader WASP additions are mapped in [WASP overlay](WASP-Overlay); this is the dedicated baserep reference.

The subtree is bootstrapped from one wiring line: `Client/Init/Init_Client.sqf:649` runs `[] execVM "WASP\baserep\init.sqf";`. Because it executes from per-player client init, it never runs on the dedicated server or a headless client — base repair is entirely a player-local UI/loop feature, and authority concerns follow from that (see Locality below).

## Files And Wiring

| File | Role | Entry / status |
| --- | --- | --- |
| `WASP/baserep/init.sqf` | Bootstrap. `#include "data.sqf";` then `#include "viem.sqf"` (`WASP/baserep/init.sqf:1-2`). | **Live** — `execVM` from `Client/Init/Init_Client.sqf:649`. |
| `WASP/baserep/data.sqf` | Defines the global `baseb` table: building class → display name, interaction distance, repair-rate % (`WASP/baserep/data.sqf:1-13`). | Data include (compiled inline by `init.sqf:1`). |
| `WASP/baserep/viem.sqf` | The main `waitUntil` loop: Spotter enemy-building inspect, plus commander cursorTarget health HUD and add/remove of the Repair action (`WASP/baserep/viem.sqf:13-75`). | Loop (included by `init.sqf:2`). |
| `WASP/baserep/repair.sqf` | The action handler: supply gate, medic animation, supply drain, per-tick HP increment (`WASP/baserep/repair.sqf:1-37`). | Attached as a player scroll action by `viem.sqf:52`. |

## The `baseb` Building-Class Table

`WASP/baserep/data.sqf:1-13` builds the global array `baseb`. Each row is `[class, name, dis, %]` where `dis` is the interaction distance in metres and `%` is the per-tick repair rate added to the building's health percentage. Every building uses the same 10 m range; the rate is what varies. Names are pulled via `localize` from the stringtable (English values verified in `stringtable.xml:4907-4946`).

| Building class (`isKindOf` match) | Display name (key) | Dist | Repair rate % | data.sqf line |
| --- | --- | --- | --- | --- |
| `Base_WarfareBBarracks` | Barracks (`RB_Barracks`) | 10 | 3 | `WASP/baserep/data.sqf:3` |
| `Base_WarfareBLightFactory` | Light Factory (`RB_Light_Factory`) | 10 | 2 | `WASP/baserep/data.sqf:4` |
| `Base_WarfareBHeavyFactory` | Heavy Factory (`RB_Heavy_Factory`) | 10 | 1 | `WASP/baserep/data.sqf:5` |
| `Base_WarfareBUAVterminal` | Command Center (`RB_Command_Center`) | 10 | 1 | `WASP/baserep/data.sqf:6` |
| `Base_WarfareBAircraftFactory` | Aircraft factory (`RB_Aircraft_factory`) | 10 | 0.5 | `WASP/baserep/data.sqf:7` |
| `BASE_WarfareBAntiAirRadar` | AAR (`RB_Air_Defense_Radar`) | 10 | 1.5 | `WASP/baserep/data.sqf:8` |
| `BASE_WarfareBArtilleryRadar` | Artillery Radar (`RB_Artillery_Radar`) | 10 | 1.5 | `WASP/baserep/data.sqf:9` |
| `Warfare_HQ_base_unfolded` | Headquarters (`RB_Headquarters`) | 10 | 0.5 | `WASP/baserep/data.sqf:10` |
| `BASE_WarfareBFieldhHospital` | Field Hospital (`RB_Field_Hospital`) | 10 | 3 | `WASP/baserep/data.sqf:11` |
| `Base_WarfareBVehicleServicePoint` | Service Point (`RB_Service_Point`) | 10 | 2 | `WASP/baserep/data.sqf:12` |

Higher-value strategic assets (Aircraft factory, HQ) repair slowest at 0.5%/tick; Barracks and Field Hospital are fastest at 3%/tick. Matching is by `isKindOf` (`viem.sqf:21,39`), so subclasses of these base classes are also covered. The `Base_` / `BASE_` casing in the class strings is preserved exactly as written; `isKindOf` class-name matching is case-insensitive in the engine, so the mixed casing does not break matching.

## Commander HUD + Action Loop (`viem.sqf`)

`viem.sqf` is one unscheduled-spawned `waitUntil` loop (`WASP/baserep/viem.sqf:13`) that body-returns `false` implicitly, so it runs forever with a `sleep 3` throttle inside the commander branch (`viem.sqf:73`). State is held in script-local and a small set of shared globals.

| Concern | Detail | Source |
| --- | --- | --- |
| Per-player action handle | Init clears any stale action: if `WASP_BaseRepair_Action >= 0`, `removeAction` it, then reset to `-1`. Marty's note: the old global `rep` could point at a stale addAction ID after respawn. | `WASP/baserep/viem.sqf:4-9` |
| Legacy global cleared | `rep = Nil;` left cleared "for compatibility with old scripts that may still check the global." | `WASP/baserep/viem.sqf:10-11` |
| Spotter inspect (read-only) | If `WFBE_SK_V_Type == "Spotter"`, cursorTarget that is an enemy `baseb` building within `1000` m shows a `hintSilent` "State" readout of remaining health. | `WASP/baserep/viem.sqf:16-30` |
| Commander gate | `_isCommander` is set true only when `commanderTeam` is non-null and `commanderTeam == group player`. The entire repair branch is inside `if (_isCommander)`. | `WASP/baserep/viem.sqf:33-34` |
| Friendly-side gate | Repair branch requires cursorTarget non-null and `side group player == side _obj`. | `WASP/baserep/viem.sqf:37` |
| Health HUD | `_dam = (1 - getDammage _obj)*100` (remaining health %). `hintSilent` shows building name + "State" + colored %; color is green > 67, yellow > 37, else red. | `WASP/baserep/viem.sqf:40-45` |
| Add Repair action | When `_dis < dist`, `_dam < 100` (i.e. damaged), and no action yet, it sets shared globals `obj`/`objnum`, flips `repairprocess = "yes"`, adds the action via `STR_WASP_actions_brepair` → `WASP\baserep\repair.sqf`, and stores the handle in `WASP_BaseRepair_Action`. | `WASP/baserep/viem.sqf:49-54` |
| Remove (out of range / full) | If out of range OR `_dam == 100` and an action exists, `removeAction` and reset the handle to `-1`. | `WASP/baserep/viem.sqf:55-59` |
| In-progress cleanup | When `repairprocess != "no"`, the loop only checks distance to the stored `obj`; walking out of range removes the action and resets `repairprocess = "no"`. | `WASP/baserep/viem.sqf:63-72` |

The action label uses key `STR_WASP_actions_brepair` → English "Repair" (`stringtable.xml:4899-4902`); the "State" label is `RB_state` → "State" (`stringtable.xml:4903-4906`).

## The Repair Tick (`repair.sqf`)

`repair.sqf` is the addAction handler. It reads the shared globals `obj` and `objnum` set by `viem.sqf` to know which building and which `baseb` row to use.

| Step | Behavior | Source |
| --- | --- | --- |
| Supply snapshot | `sleep 1`, then `_currentSupply = (sideJoined) Call GetSideSupply;`. `sideJoined` is the player's side, set at `Client/Init/Init_Client.sqf:5`. | `WASP/baserep/repair.sqf:5-7` |
| Supply gate | Only proceeds if `_currentSupply > 5`; otherwise it `hint`s the no-supply message and exits. | `WASP/baserep/repair.sqf:8,31-33` |
| Repair passes | Outer loop `for "_j" from 0 to 1` (two passes); each pass plays `AinvPknlMstpSlayWrflDnon_medic` then runs the inner tick loop `for "_i" from 0 to 6` (7 ticks). | `WASP/baserep/repair.sqf:9-14` |
| Per-tick HUD | Recomputes `_dam`, re-colors green/yellow/red, `hintSilent`s building name + State %. | `WASP/baserep/repair.sqf:16-22` |
| Supply drain | Each tick calls `[sideJoined, -15, "Factory being repaired...", false] Call ChangeSideSupply;` — a flat **-15 supply per tick**. | `WASP/baserep/repair.sqf:24` |
| HP increment | `_dam = _dam + (baseb select objnum select 3)` adds that building's repair-rate %, then `obj setDamage (1 - _dam/100)` writes the new damage. `sleep 1` between ticks. | `WASP/baserep/repair.sqf:25-28` |
| End | After both passes, `repairprocess = "no"` re-arms the `viem.sqf` add/remove logic. | `WASP/baserep/repair.sqf:36` |

Total work per activation: 2 passes × 7 ticks = up to 14 ticks, each spending 15 supply (up to 210 supply) and adding the building's rate % to health. At 1 s per tick plus the per-pass animation, one activation runs roughly 15-16 seconds.

## Known Issues And Hardening Notes

| Issue | Detail | Source |
| --- | --- | --- |
| Supply snapshot not rechecked | `_currentSupply` is captured once at the start (`:7`). The drain at `:24` spends `-15`/tick unconditionally without re-reading supply, and the only early-out (`:23`) requires both `_dam == 100` AND the stale `_currentSupply == 0`. Repair can continue past the side's actual available supply. | `WASP/baserep/repair.sqf:7,23,24` |
| Shared-global target state | The selected building and row index live in plain globals `obj`/`objnum` (`viem.sqf:50`), consumed by `repair.sqf:16,20,25,27`. Two overlapping repair flows can stomp each other's target. Convert to action arguments or player-local variables before making the feature more prominent. | `WASP/baserep/viem.sqf:50`; `WASP/baserep/repair.sqf:16,20,25,27` |
| Missing localization key | The no-supply branch localizes `RB_have_no_suppluys_for_rep` (`repair.sqf:31`), but no such key exists in `stringtable.xml`. The player would see the raw key string instead of a translated message. | `WASP/baserep/repair.sqf:31` |
| Undefined `_i` in no-supply text | The no-supply `hint` text uses `(baseb select _i) select 1` (`repair.sqf:31`), but `_i` is the inner-loop counter and is not in scope at that point — this branch is outside the `for "_i"` loop. | `WASP/baserep/repair.sqf:31` |
| Client-side authority | The whole flow runs on the commander's client (`setDamage` and `ChangeSideSupply` from the player). `ChangeSideSupply` publishes a `wfbe_supply_temp_%1` request to the server (`Common/Functions/Common_ChangeSideSupply.sqf:28-30`), but the building `setDamage` is client-local. Treat as authority-light legacy code; route building HP and supply ledger server-side if hardened. | `WASP/baserep/repair.sqf:24,27` |

Do not confuse this with the stock `Server_HandleBuildingRepair.sqf` path: WASP base repair is the live client-side chain from `Init_Client.sqf:649`, whereas the stock server handler had no active source caller during the construction audit (see [WASP overlay](WASP-Overlay)).

## Continue Reading

- [WASP overlay](WASP-Overlay) — the full `WASP/` subtree map this page expands on.
- [Economy, towns and supply](Economy-Towns-And-Supply) — how side supply (the `-15`/tick resource drained here) is produced and spent.
- [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas) — the base building classes that `baseb` repairs.
- [Commander HQ lifecycle atlas](Commander-HQ-Lifecycle-Atlas) — commander-team gating and the related HQ recovery action.
- [Faction base structures catalog](Faction-Base-Structures-Catalog) — the `Base_WarfareB*` structure classnames.
