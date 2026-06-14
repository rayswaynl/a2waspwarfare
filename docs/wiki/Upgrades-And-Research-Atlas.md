# Upgrades And Research Atlas

> Canonical map for the Warfare upgrade/research system. This page is source-backed from the Chernarus source mission and should be kept in sync with [Server Authority Migration Map](Server-Authority-Migration-Map), [Economy Authority First Cut](Economy-Authority-First-Cut), [Feature Status Register](Feature-Status-Register), and [AI Commander Autonomy Audit](AI-Commander-Autonomy-Audit).

## Why This Matters

Upgrades are not a cosmetic tech tree. They gate factory tiers, gear templates, EASA, artillery behavior, supply rate, respawn range, support actions, airlift, aircraft missiles, paratroopers, fast travel, Coin ammo, town defender composition and several WASP-specific additions. A wrong assumption here can silently unlock equipment, skip resources, break AI commander progression, or make branch-only features appear more complete than they are.

The critical implementation truth is split:

- the server owns the replicated upgrade state and completion timer;
- the live player UI owns commander gating, affordability checks, dependency checks and immediate resource deduction;
- the public variable entrypoint does not currently revalidate a player upgrade request before starting the server worker;
- AI commander upgrades have a separate server-side affordability path, but the broader AI commander scheduler/owner path is still incomplete.

## How To Use This Page

| Need | Start here | Then read |
| --- | --- | --- |
| Player upgrade purchase path | [Live Player Flow](#live-player-flow) and [Server Flow](#server-flow) | [Server Authority Migration Map](Server-Authority-Migration-Map), [Economy Authority First Cut](Economy-Authority-First-Cut) |
| Branch status and line drift | [Current Branch Scope](#current-branch-scope) | [Feature Status Register](Feature-Status-Register), [Source Fix Propagation Queue](Source-Fix-Propagation-Queue) |
| AI commander upgrade worker | [AI Commander Flow](#ai-commander-flow) | [AI Commander Autonomy Audit](AI-Commander-Autonomy-Audit#ai-upgrade-debit-branch-matrix) |
| `upgrade-sync` timer cleanup | [Live Player Flow](#live-player-flow) | [Support Specials And Tactical Modules Atlas](Support-Specials-And-Tactical-Modules-Atlas#upgrade-sync-branch-matrix) |
| Stale old upgrade UI | [Stale / Abandoned Upgrade UI](#stale--abandoned-upgrade-ui) | [UI Resource Parity Cleanup](UI-Resource-Parity-Cleanup) |
| Upgrade consumers | [Consumers](#consumers) | [Factory And Purchase Systems Atlas](Factory-And-Purchase-Systems-Atlas), [Gear Loadout And EASA Atlas](Gear-Loadout-And-EASA-Atlas), [Support Specials And Tactical Modules Atlas](Support-Specials-And-Tactical-Modules-Atlas) |

## Current Branch Scope

Checked 2026-06-14 against docs checkout `d4cfef80`, stable `origin/master` `cf2a6d6a`, Miksuu upstream `b8389e74`, `origin/perf/quick-wins` `0076040f`, release `origin/release/2026-06-feature-bundle` `a96fdda2`, `origin/feat/ai-commander` `c20ce153` and `origin/feat/upgrade-queue-stacking` `b061c905`. The cited docs-checkout upgrade files are unchanged from the earlier `e785f1e9` upgrade-atlas anchor snapshot, so existing line refs remain valid.

| Branch / root | Evidence | Status |
| --- | --- | --- |
| Docs checkout `d4cfef80` Chernarus and maintained Vanilla | Player UI treats costs as `[supply, funds]` (`GUI_UpgradeMenu.sqf:96-97,139-140`) and debits funds/supply at `:158-159`, then sends `RequestUpgrade` at `:161`. `RequestUpgrade.sqf:5` spawns `WFBE_SE_FNC_ProcessUpgrade`, while `Server_ProcessUpgrade.sqf:12-18` trusts side/id/level/player flag. AI worker reads raw AI-order level at `Server_AI_Com_Upgrade.sqf:27` and debits funds/supply swapped at `:47,50`. Both maintained roots still define stale `RscMenu_Upgrade` at `Rsc/Dialogs.hpp:2425,2428`. | Current docs/source checkout remains the high-risk authority/debit target. Treat player upgrades as client-authoritative and AI upgrade debit as patch-ready here. |
| Stable `origin/master` `cf2a6d6a` and release `a96fdda2` | Both maintained roots still keep `RequestUpgrade.sqf:5` as a spawn wrapper and `Server_HandleSpecial.sqf:67-73` as the mixed `_args` / `_this` `upgrade-sync` parser. Stable callers are at `GUI_UpgradeMenu.sqf:268`; release callers are at `:254`. AI worker debit order is fixed at `Server_AI_Com_Upgrade.sqf:47,50`, but `_cost` still uses raw `(_to_upgrade select 1)` at `:27`. `git grep` found no `RscMenu_Upgrade` / `GUI_Menu_Upgrade.sqf` hits in checked stable or release maintained roots. | Stable/release rescue the stale dialog and AI debit-order issue, but not player upgrade authority, `upgrade-sync` tuple cleanup or the AI cost-index question. Smoke remains required before release-ready wording. |
| Miksuu `b8389e74` and `perf/quick-wins` `0076040f` | Both branches keep the mixed `upgrade-sync` parser with callers at `GUI_UpgradeMenu.sqf:241`, the raw AI cost lookup at `Server_AI_Com_Upgrade.sqf:27`, swapped AI debit at `:47,50` and stale `RscMenu_Upgrade` / missing-controller onLoad at `Rsc/Dialogs.hpp:2435,2438` in both maintained roots. | No upstream/perf rescue for upgrade authority, AI debit, tuple cleanup or stale old dialog. |
| `origin/feat/ai-commander` `c20ce153` | Chernarus subtracts one from AI-order level before reading `_cost` at `Server_AI_Com_Upgrade.sqf:27` and debits funds/supply in the player-UI order at `:47,50`; maintained Vanilla on the same branch keeps the old raw lookup and swapped debit. | Useful branch-only Chernarus lesson, not a propagated AI upgrade fix. |
| `origin/feat/upgrade-queue-stacking` `b061c905` | Adds upgrade-queue UI state around `GUI_UpgradeMenu.sqf:66,170,255,268,283,301`, keeps `RequestUpgrade.sqf:5` as the server entry, keeps the mixed `upgrade-sync` parser at `Server_HandleSpecial.sqf:67-73`, keeps raw AI cost lookup at `Server_AI_Com_Upgrade.sqf:27`, and has no checked stale `RscMenu_Upgrade` hits. | Review as a UI/queue branch. It does not close server authority or `upgrade-sync` hardening by itself. |

## Source Files

| Area | Files |
| --- | --- |
| Constants | `Common/Init/Init_CommonConstants.sqf:36-58` |
| Side state init | `Server/Init/Init_Server.sqf:344-369` |
| Side state getter | `Common/Functions/Common_GetSideUpgrades.sqf:7-11` |
| Player menu class | `Rsc/Dialogs.hpp:3-142` |
| Stale legacy menu class | Docs checkout `d4cfef80` `Rsc/Dialogs.hpp:2424-2428`; branch status is below |
| Main menu route | `Client/GUI/GUI_Menu.sqf:21-26`, `Client/GUI/GUI_Menu.sqf:161-166` |
| Live player UI | Docs checkout `d4cfef80` `Client/GUI/GUI_UpgradeMenu.sqf:1-215`; line drift is in [Current Branch Scope](#current-branch-scope) |
| Server request PVF | `Server/PVFunctions/RequestUpgrade.sqf:1-5` |
| Server worker | `Server/Functions/Server_ProcessUpgrade.sqf:10-89` |
| Client upgrade notifications | `Client/PVFunctions/HandleSpecial.sqf`, `Client/Functions/Client_FNC_Special.sqf:111-124`, `Client/Functions/Client_FNC_Special.sqf:173-185` |
| Client timer sync | Docs checkout `Client/GUI/GUI_UpgradeMenu.sqf:167-172`, `Server/Functions/Server_HandleSpecial.sqf:67-74`; canonical matrix: [Support specials](Support-Specials-And-Tactical-Modules-Atlas#upgrade-sync-branch-matrix) |
| AI commander worker | `Server/Functions/Server_AI_Com_Upgrade.sqf:7-53` |
| Config arrays | `Common/Config/Core_Upgrades/Upgrades_*.sqf`, `Common/Config/Core_Upgrades/Labels_Upgrades.sqf`, `Common/Config/Core_Upgrades/Check_Upgrades.sqf` |

## Upgrade IDs

`Common/Init/Init_CommonConstants.sqf:36-58` defines the numeric indexes used by every side config and every consumer:

| ID | Constant | Meaning |
| --- | --- | --- |
| 0 | `WFBE_UP_BARRACKS` | Barracks / infantry tier |
| 1 | `WFBE_UP_LIGHT` | Light factory tier |
| 2 | `WFBE_UP_HEAVY` | Heavy factory tier |
| 3 | `WFBE_UP_AIR` | Aircraft factory tier |
| 4 | `WFBE_UP_PARATROOPERS` | Paratrooper support |
| 5 | `WFBE_UP_UAV` | UAV |
| 6 | `WFBE_UP_SUPPLYRATE` | Town/supply income rate |
| 7 | `WFBE_UP_RESPAWNRANGE` | Ambulance/MASH respawn range |
| 8 | `WFBE_UP_AIRLIFT` | Airlift |
| 9 | `WFBE_UP_FLARESCM` | Custom flares/countermeasures |
| 10 | `WFBE_UP_ARTYTIMEOUT` | Artillery timeout |
| 11 | `WFBE_UP_ICBM` | ICBM |
| 12 | `WFBE_UP_FASTTRAVEL` | Fast travel |
| 13 | `WFBE_UP_GEAR` | Gear tier |
| 14 | `WFBE_UP_AMMOCOIN` | Coin ammo category |
| 15 | `WFBE_UP_EASA` | EASA loadout/service system |
| 16 | `WFBE_UP_SUPPLYPARADROP` | Supply paradrop |
| 17 | `WFBE_UP_ARTYAMMO` | Artillery ammunition unlock |
| 18 | `WFBE_UP_IRSMOKE` | IR smoke |
| 19 | `WFBE_UP_AIRAAM` | Aircraft AA missiles |
| 20 | `WFBE_UP_AAR` | Anti-air radar |
| 21 | `WFBE_UP_UNITCOST` | Unit cost modifier/filter hook |

Treat these as array indexes, not namespaced objects. Adding, removing or reordering one upgrade means auditing every `WFBE_UP_*` consumer.

## Data Model

The server initializes each side logic with:

- `wfbe_upgrades`: the replicated array of current levels;
- `wfbe_upgrading`: a replicated boolean for "one upgrade currently running";
- `wfbe_upgrading_id`: a replicated upgrade ID, added so clients can display the running upgrade name.

Source: `Server/Init/Init_Server.sqf:344-369`.

When debug upgrades are enabled, the initial upgrade state is copied from the configured max-level array, then Artillery Ammunition is forced back to `0` so its one-level unlock flow remains testable (`Server/Init/Init_Server.sqf:348-353`). In normal mode, the upgrade array is built as one zero per configured level entry (`Server/Init/Init_Server.sqf:344-347`).

`Common_GetSideUpgrades.sqf` returns the side logic variable for west/east/resistance and returns `objNull` for unknown sides. Because most consumers immediately index the returned value, invalid side data can cascade into script errors rather than a graceful rejection.

## Config Shape

Each `Common/Config/Core_Upgrades/Upgrades_*.sqf` side file populates:

- `WFBE_C_UPGRADES_<side>_ENABLED`
- `WFBE_C_UPGRADES_<side>_COSTS`
- `WFBE_C_UPGRADES_<side>_LEVELS`
- `WFBE_C_UPGRADES_<side>_LINKS`
- `WFBE_C_UPGRADES_<side>_TIMES`
- `WFBE_C_UPGRADES_<side>_AI_ORDER`

`Labels_Upgrades.sqf` builds client-side display labels, descriptions and images. The live client init imports it with `ExecVM "Common\Config\Core_Upgrades\Labels_Upgrades.sqf"` (`Client/Init/Init_Client.sqf:324-325`).

`Check_Upgrades.sqf` is a helper that appends missing enabled upgrade levels into the AI commander order. It does not validate player requests and it does not normalize the live config arrays for length or dependency consistency.

### Config Drift Warning

The constants define 22 upgrade indexes through `WFBE_UP_UNITCOST = 21`, while the representative `Upgrades_USMC.sqf` arrays visible in Chernarus are not perfectly uniform: `ENABLED` and `COSTS` include Anti Air Radar, but the shown `LEVELS`, `LINKS` and `TIMES` arrays stop before `WFBE_UP_AAR` in that file (`Upgrades_USMC.sqf:5-76`, `Upgrades_USMC.sqf:78-132`). Other side configs may differ. Do not publish a new upgrade, price, level, or unit-cost feature until every `Upgrades_*.sqf` side file is checked for array length, index alignment and generated-mission propagation.

## Live Player Flow

Line refs in this section are docs checkout `d4cfef80` Chernarus. The checked upgrade UI/server files are unchanged from the earlier `e785f1e9` anchor; stable, release and feature branches have line drift in [Current Branch Scope](#current-branch-scope).

The main menu enables the upgrade button whenever the player is in command center range (`Client/GUI/GUI_Menu.sqf:21-26`) and opens `WFBE_UpgradeMenu` on menu action 7 (`Client/GUI/GUI_Menu.sqf:161-166`). The `WFBE_UpgradeMenu` class is the live dialog and executes `Client\GUI\GUI_UpgradeMenu.sqf` on load (`Rsc/Dialogs.hpp:3-7`).

Inside `GUI_UpgradeMenu.sqf`:

1. The client reads upgrade config arrays and the replicated side upgrades (`lines 8-21`).
2. The purchase button is disabled unless the local player's group is `commanderTeam` (`lines 39-41`).
3. The UI shows current level, cost, supply, time and dependencies (`lines 85-126`).
4. On purchase, the client checks no upgrade is running, the selected upgrade has levels remaining, funds/supply are enough, and dependency links are met (`lines 129-157`).
5. The client immediately deducts funds and side supply (`lines 158-159`).
6. The client sends `["RequestUpgrade", [WFBE_Client_SideJoined, _id, _upgrade_current, true]]` to the server (`line 161`).
7. Non-server clients spawn a local timer and later send `RequestSpecial ["upgrade-sync", ...]` (`lines 167-172`) so `Server_ProcessUpgrade.sqf` can release before the full server sleep if the sync flag arrives.

The `upgrade-sync` companion is branch-scoped in [Support specials](Support-Specials-And-Tactical-Modules-Atlas#upgrade-sync-branch-matrix). This pass confirms docs checkout `d4cfef80` still matches that owner shape: stable `cf2a6d6a`, Miksuu `b8389e74`, `perf/quick-wins` `0076040f`, release `a96fdda2` and `feat/upgrade-queue-stacking` `b061c905` all keep the same mixed `_args` / `_this` parser in `Server_HandleSpecial.sqf:67-73`. Because `_args = _this` at function entry, this is cleanup/fragility debt rather than a confirmed current break; future router work should still normalize the tuple before broader RequestSpecial hardening.

This is functional for normal honest commanders, but it is not server-authoritative.

## Server Flow

`RequestUpgrade.sqf` is currently only:

```sqf
_this Spawn WFBE_SE_FNC_ProcessUpgrade;
```

Source: `Server/PVFunctions/RequestUpgrade.sqf:1-5`.

`Server_ProcessUpgrade.sqf` trusts the provided side, upgrade ID, target level and player/AI flag. It reads the upgrade time from `WFBE_C_UPGRADES_<side>_TIMES`, marks the side logic as upgrading, waits for client sync or the configured time, increments the side upgrade level, clears running state, refreshes existing artillery when Artillery Ammunition completes, then broadcasts `upgrade-complete` (`Server_ProcessUpgrade.sqf:10-89`).

What it does not do for player requests:

- prove the requester is the current commander;
- prove the request side matches the requester;
- recompute current level, max level, dependencies, funds or supply;
- debit resources server-side;
- reject invalid upgrade IDs or impossible target levels before indexing config arrays;
- reject duplicate concurrent requests except by trusting client-side `wfbe_upgrading` checks.

## AI Commander Flow

`Server_AI_Com_Upgrade.sqf` is more authoritative than the player PV path. It reads `WFBE_C_UPGRADES_<side>_AI_ORDER`, finds the first desired upgrade level not yet met, checks AI commander funds and side supply, calls `WFBE_SE_FNC_ProcessUpgrade` with `_upgrade_isplayer = false`, sets running state, and deducts resources (`Server_AI_Com_Upgrade.sqf:7-53`).

Branch scope matters here. Docs checkout `d4cfef80`, Miksuu `b8389e74` and `perf/quick-wins` `0076040f` validate AI costs with the same `[supply, funds]` convention as the player UI (`GUI_UpgradeMenu.sqf:96-97,139-140`; `Server_AI_Com_Upgrade.sqf:34-36`) but debit AI funds with `_cost select 0` and side supply with `_cost select 1` at `Server_AI_Com_Upgrade.sqf:47,50`. Stable `cf2a6d6a`, release `a96fdda2` and `feat/upgrade-queue-stacking` `b061c905` fix debit order in both maintained roots but still use raw `(_to_upgrade select 1)` as the cost level at `:27`. `feat/ai-commander` `c20ce153` fixes both debit order and cost-index lookup only in Chernarus.

Use [AI Commander Autonomy Audit](AI-Commander-Autonomy-Audit#ai-upgrade-debit-branch-matrix) for the canonical branch matrix. Before enabling or scheduling AI commander upgrades, port or recreate the debit-order fix where needed, decide the cost-index correction, propagate maintained Vanilla and smoke AI upgrade affordability/debit.

This means the upgrade worker is real, but the broader AI commander autonomy still needs care. See [AI Commander Autonomy Audit](AI-Commander-Autonomy-Audit): the repo has AI commander upgrade code and state, but the current docs should not imply a complete autonomous commander loop until the scheduler/owner path is proven.

## Consumers

High-impact consumers found in the source mission include:

- factory and buy menus: `Client/GUI/GUI_Menu_BuyUnits.sqf`, `Client/Functions/Client_UIFillListBuyUnits.sqf`, `Server/Functions/Server_BuyUnit.sqf`;
- gear templates and buy gear: `Client/Functions/Client_UI_Gear_FillList.sqf`, `Client/Functions/Client_UI_Gear_FillTemplates.sqf`, `Client/Functions/Client_UI_Gear_SaveTemplateProfile.sqf`;
- EASA/service: `Client/GUI/GUI_Menu_EASA.sqf`, `Client/GUI/GUI_Menu_Service.sqf`;
- respawn range: `Client/Functions/Client_GetRespawnAvailable.sqf`, `Server/AI/AI_AdvancedRespawn.sqf`, `Server/AI/AI_SquadRespawn.sqf`;
- tactical/supports: `Client/GUI/GUI_Menu_Tactical.sqf`, `Server/Support/Support_Paratroopers.sqf`;
- airlift/countermeasures: `Common/Init/Init_Unit.sqf`, `Common/Functions/Common_RearmVehicle.sqf`, `Common/Functions/Common_RearmVehicleOA.sqf`;
- artillery: `Client/Functions/Client_RequestFireMission.sqf`, `Common/Functions/Common_EquipArtillery.sqf`, `Common/Functions/Common_GetArtilleryAmmoOptions.sqf`, `Server/Functions/Server_ProcessUpgrade.sqf`;
- supply systems: `Server/FSM/server_town.sqf`, `Client/Module/supplyMission/supplyMissionStart.sqf`;
- UI/HUD: `Client/GUI/GUI_Menu_Command.sqf`, `Client/Client_UpdateRHUD.sqf`;
- towns and AI composition: `Server/Functions/Server_GetTownGroups.sqf`;
- PR #1/supply helicopter: upgrade gating and supply economy should be checked against this page before merging branch behavior.

## Stale / Abandoned Upgrade UI

Do not confuse the live `WFBE_UpgradeMenu` with `RscMenu_Upgrade`.

`Rsc/Dialogs.hpp:2424-2428` still defines `class RscMenu_Upgrade` with `onLoad = "_this ExecVM ""Client\GUI\GUI_Menu_Upgrade.sqf"""`, but the referenced script is absent. The live menu route creates `WFBE_UpgradeMenu`, not `RscMenu_Upgrade`. This is stale dialog archaeology, not the active upgrade system.

Branch check 2026-06-14: docs checkout `d4cfef80` still carries the stale class in both maintained roots at `Rsc/Dialogs.hpp:2425` with the missing controller onLoad at `:2428`. Miksuu `b8389e74` and `perf/quick-wins` `0076040f` keep the same stale class in both roots at `:2435` / `:2438`. Stable `origin/master` `cf2a6d6a`, release `a96fdda2` and `feat/upgrade-queue-stacking` `b061c905` have no checked `RscMenu_Upgrade` / `GUI_Menu_Upgrade.sqf` hits in maintained Chernarus or Vanilla roots. If cleanup is promoted into the docs/source checkout, treat it as a parity task: remove or intentionally alias the old class in both maintained roots, then smoke the live `WFBE_UpgradeMenu` purchase/request path.

Related page: [Abandoned Feature Revival Review](Abandoned-Feature-Revival-Review).

## Risk Register

| Status | Finding | Evidence | Development guidance |
| --- | --- | --- | --- |
| Patch-ready | Player upgrade request is client-authoritative for affordability, dependencies and commander permission. | `GUI_UpgradeMenu.sqf:129-161`; `RequestUpgrade.sqf:1-5`; `Server_ProcessUpgrade.sqf:12-18` | Move validation/debit into a server authority wrapper before adding new upgrade mechanics or balancing expensive upgrades. |
| Patch-ready | Invalid side/upgrade/level payloads can index config arrays directly. | `Server_ProcessUpgrade.sqf:12-18`; `Common_GetSideUpgrades.sqf:7-11` | Add side, ID, current-level and max-level guards before reading `TIMES`/`COSTS`/`LINKS`. |
| Branch-split patch-ready | AI commander upgrade worker is fixed for debit order on stable/release/upgrade-queue, but docs checkout, Miksuu and perf still swap supply/funds; the cost-index correction is only Chernarus on `feat/ai-commander`. | [AI upgrade debit matrix](AI-Commander-Autonomy-Audit#ai-upgrade-debit-branch-matrix); docs checkout `d4cfef80` `Server_AI_Com_Upgrade.sqf:27,34-50`; stable/release `:27,47,50` | Port/recreate debit-order fix where still open, decide the cost-index correction, propagate maintained Vanilla and smoke before scheduling AI upgrades. |
| Research-needed | Config arrays may be length-misaligned around AAR/unit-cost. | `Init_CommonConstants.sqf:36-58`; representative `Upgrades_USMC.sqf` excerpt | Build a side-config validator before changing upgrade arrays or propagating generated missions. |
| Partial | AI commander upgrade worker exists, but full autonomous scheduling remains unproven. | `Server_AI_Com_Upgrade.sqf:7-53`; [AI Commander Autonomy Audit](AI-Commander-Autonomy-Audit) | Treat AI upgrade flow as a useful worker, not as proof of a complete AI commander. |
| Branch-split stale | `RscMenu_Upgrade` references missing `GUI_Menu_Upgrade.sqf` in docs checkout, Miksuu and perf; stable, release and upgrade-queue no longer show the stale class in checked maintained roots. | Docs checkout `d4cfef80` `Rsc/Dialogs.hpp:2425,2428`; Miksuu/perf `:2435,:2438`; no checked stable/release/upgrade-queue hits | Keep it documented as stale for older/docs roots; if patched in docs/source, remove or alias consistently across maintained Chernarus and Vanilla, then smoke the live upgrade menu. |

## Server-Authority Migration Plan

A safe future patch should add a server-side request wrapper before `WFBE_SE_FNC_ProcessUpgrade`:

1. Resolve requester identity from the PVF context or include an authenticated player/team argument following the repo's existing PV patterns.
2. Validate side is one of west/east/resistance and matches the requester's joined side.
3. Validate requester is the current commander/team permitted to buy upgrades.
4. Read current upgrades from side logic on the server.
5. Validate upgrade ID is in range and enabled for that side.
6. Validate requested level equals current level and is below configured max.
7. Recompute cost, supply cost and dependencies from server config.
8. Reject if another upgrade is running.
9. Debit commander/client funds and side supply on the server.
10. Start `WFBE_SE_FNC_ProcessUpgrade`.
11. Send explicit success/failure feedback so the client can avoid irreversible local-only debits.

Until this exists, the client UI should be treated as an affordance layer, not as the authority boundary.

## Continue Reading

Previous: [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) | Next: [Economy authority first cut](Economy-Authority-First-Cut)

- [Economy Authority First Cut](Economy-Authority-First-Cut)
- [Server Authority Migration Map](Server-Authority-Migration-Map)
- [Networking And Public Variables](Networking-And-Public-Variables)
- [Public Variable Channel Index](Public-Variable-Channel-Index)
- [AI Commander Autonomy Audit](AI-Commander-Autonomy-Audit)
- [Support Specials And Tactical Modules Atlas](Support-Specials-And-Tactical-Modules-Atlas#upgrade-sync-branch-matrix)
- [Factory And Purchase Systems Atlas](Factory-And-Purchase-Systems-Atlas)
- [Respawn And Death Lifecycle Atlas](Respawn-And-Death-Lifecycle-Atlas)
- [Gear Loadout And EASA Atlas](Gear-Loadout-And-EASA-Atlas)
