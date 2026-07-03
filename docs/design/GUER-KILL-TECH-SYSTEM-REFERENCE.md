# GUER Kill-Tech System Reference

Source-verified 2026-07-03 against `github/claude/build84-cmdcon36` at `a26871e852470b86b68c2f4f58eb44b436d076d6`. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/` unless noted. This is a report-only lane: no mission source, constants, parameters, generated mirrors, package artifacts or live runtime settings changed.

This page documents the current playable-GUER kill-tech loop as source evidence for lane 308. It is broader than PR #433's GUER tier-progress status report: #433 focuses on visibility, while this report follows the side-wide kill counter, vehicle unlocks, FOB token grants and spend path, JIP durability, and the UI surfaces that expose them.

## Quick Model

GUER kill-tech has two server-owned counters:

| State | Meaning | Primary writers | Primary readers |
| --- | --- | --- | --- |
| `WFBE_GUER_PLAYER_KILLS` | Cumulative WEST/EAST units killed by resistance players. Drives heavy-vehicle tier, M113 VBIED, Ka-137 flare size and barracks AI cap. | `Server/PVFunctions/RequestOnUnitKilled.sqf:115-133` | `Server/Server_GuerStipend.sqf:43-50,58-75`, `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:59-112`, `Client/GUI/GUI_UpgradeMenu.sqf:23-36`, `Client/Client_UpdateRHUD.sqf:291-304,470-475` |
| `WFBE_GUER_FOB_AVAIL` | `[Barracks, Light, Heavy]` token counts for still-buildable GUER field factories. Earned by destroying enemy factories or holding the GUER wildcard checkpoint; spent by building a FOB. | `Server/Functions/Server_BuildingKilled.sqf:15-32`, `Server/Functions/Server_HandleSpecial.sqf:1283-1297`, `Server/Functions/AI_Commander_Wildcard_GUER.sqf:287-301`, `Server/PVFunctions/RequestFOBStructure.sqf:43-67` | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:65,105-112`, `Client/Action/Action_BuildFOB.sqf:24-45`, `Client/GUI/GUI_UpgradeMenu.sqf:23-31,72-74`, `Client/Client_UpdateRHUD.sqf:541-551` |

Both values are seeded in `Common/Init/Init_CommonConstants.sqf` and are explicitly sent to joiners in `Server/Functions/Server_OnPlayerConnected.sqf:156-158`. The stipend loop also re-broadcasts them every 60 seconds because A2 OA public variables are not JIP-replayed (`Server/Server_GuerStipend.sqf:63-75`).

## Boot And Gates

The playable side is still gated by `WFBE_C_GUER_PLAYERSIDE`. The current Build84 default is on (`1`) in `Common/Init/Init_CommonConstants.sqf:76`. Server hostility is symmetric only while this gate is on: resistance is always hostile to WEST/EAST, while WEST/EAST return hostility to resistance inside the gate at `Server/Init/Init_Server.sqf:7-14`.

The server registers the GUER player faction and economy under the same gate at `Server/Init/Init_Server.sqf:856-862`, then launches `Server/Server_GuerStipend.sqf` independently at `Server/Init/Init_Server.sqf:946-950`. The loop self-gates on `isServer` and `WFBE_C_GUER_PLAYERSIDE > 0` (`Server/Server_GuerStipend.sqf:14-15`).

## Current Constants

| Constant or global | Current default | Role | Source |
| --- | --- | --- | --- |
| `WFBE_GUER_PLAYER_KILLS` | `0` | Side-wide player kill counter. | `Common/Init/Init_CommonConstants.sqf:98-105` |
| `WFBE_C_GUER_KILLTIER_1` | `30` | Tier 1: BRDM-2 + T-34. | `Common/Init/Init_CommonConstants.sqf:106-108` |
| `WFBE_C_GUER_KILLTIER_2` | `80` | Tier 2: T-55. | `Common/Init/Init_CommonConstants.sqf:109` |
| `WFBE_C_GUER_KILLTIER_3` | `160` | Tier 3: Chernarus T-72 + BMP-2, Takistan/Zargabad ZU-23 Ural. | `Common/Init/Init_CommonConstants.sqf:110`, `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:81-99` |
| `WFBE_C_GUER_VBIED_M113_KILLS` | `50` | Unlocks the unarmed M113 VBIED. | `Common/Init/Init_CommonConstants.sqf:111-115` |
| `WFBE_C_GUER_KA137_FLARE_MAGS` | `60/120/240` flare magazines by tier. | Arms player-bought Ka-137s by current tier. | `Common/Init/Init_CommonConstants.sqf:116-122`, `Client/Functions/Client_BuildUnit.sqf:688-704` |
| `WFBE_GUER_FOB_AVAIL` | `[0,0,0]` | Available Barracks/Light/Heavy FOB tokens. | `Common/Init/Init_CommonConstants.sqf:124-129` |
| `WFBE_C_GUER_FOB_TRUCKS` | Chernarus: `Ural_INS`, `UralOpen_INS`, `GAZ_Vodnik`; Takistan/Zargabad: `Ural_TK_CIV_EP1`, `V3S_Open_TK_CIV_EP1`, `V3S_TK_EP1`. | Token-gated depot trucks, index-aligned with FOB structure type. | `Common/Init/Init_CommonConstants.sqf:134-145` |
| `WFBE_C_GUER_FOB_BUILD_DIST/RANGE/TOWN_BLOCK` | `22`, `30`, `600` | Placement offset, action range and enemy-town block distance. | `Common/Init/Init_CommonConstants.sqf:146-148,156-186` |
| `WFBE_C_GUER_BARRACKS_AI_BASE/MAX/PER_KILLS` | `4`, `12`, `20` | Per-player GUER barracks AI cap scales by kills. | `Common/Init/Init_CommonConstants.sqf:187-190`, `Client/Client_UpdateRHUD.sqf:470-475` |

## Kill Counter Flow

`RequestOnUnitKilled.sqf` increments `WFBE_GUER_PLAYER_KILLS` only when all of these are true: playable GUER is enabled, the killer is resistance, the killer is a player, the killed side is different, and the killed side is WEST or EAST (`Server/PVFunctions/RequestOnUnitKilled.sqf:110-117`). The block immediately broadcasts the new counter, logs it, and emits an unlock message when the exact new count matches one of the threshold constants (`Server/PVFunctions/RequestOnUnitKilled.sqf:118-133`).

The same kill event file pays normal GUER kill bounty later in the function. That is a funds path, not the tech counter path: the tech counter requires a resistance player killing WEST/EAST, while bounty has its own `wfbe_funds` team gate (`Server/PVFunctions/RequestOnUnitKilled.sqf:137-140`).

`Server_GuerStipend.sqf` converts the kill counter into `WFBE_GUER_VEHICLE_TIER`. It seeds the current tier before the first sleep (`Server/Server_GuerStipend.sqf:38-50`) and recalculates every interval (`Server/Server_GuerStipend.sqf:52-69`). The same interval also re-broadcasts `WFBE_GUER_PLAYER_KILLS` and `WFBE_GUER_FOB_AVAIL` for JIP convergence (`Server/Server_GuerStipend.sqf:70-75`).

## Depot Unlocks

The client overlay owns the live depot pool. `Root_GUE_PlayerOverlay.sqf` seeds `WFBE_GUERDEPOTUNITS` immediately (`Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:50-54`), then rebuilds it whenever the composite signature changes: vehicle tier, M113 unlock state, FOB availability or civilian-depot gate (`Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:55-68`).

| Unlock | Chernarus result | Takistan/Zargabad result | Source |
| --- | --- | --- | --- |
| Base pool | GUER infantry, `Offroad_DSHKM_Gue`, `V3S_Gue`, tier-0 BTR-40, truck VBIED, `Ka137_MG_PMC`. | TK_GUE infantry, `Offroad_DSHKM_TK_GUE_EP1`, `Pickup_PK_TK_GUE_EP1`, `V3S_TK_GUE_EP1`, tier-0 BTR-40 MG, datsun VBIED, `Ka137_MG_PMC`. | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:71-80,84-96` |
| Tier 1 | Adds `BRDM2_Gue`, `T34_TK_GUE_EP1`. | Adds `BRDM2_TK_GUE_EP1`, `T34_TK_GUE_EP1`. | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:81,97` |
| Tier 2 | Adds `T55_TK_GUE_EP1`. | Adds `T55_TK_GUE_EP1`. | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:82,98` |
| Tier 3 | Adds `T72_Gue`, `BMP2_Gue`. | Adds `Ural_ZU23_TK_GUE_EP1`. | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:83,99` |
| M113 VBIED | Appends `WFBE_C_GUER_VBIED_M113_TYPE` when kill threshold is met. | Same map-independent class. | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:101-104` |
| FOB trucks | Appends the matching truck class for each `WFBE_GUER_FOB_AVAIL` slot above zero. | Same logic with TK/ZG truck classes. | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:105-112` |

Buy-list presentation is separate from pool membership. `Client_UIFillListBuyUnits.sqf` labels the normal truck VBIED, M113 VBIED and FOB delivery trucks so GUER players can tell weaponized/support vehicles from donor classnames (`Client/Functions/Client_UIFillListBuyUnits.sqf:168-192`). `Client_BuildUnit.sqf` tags bought VBIEDs and FOB trucks with broadcast variables so later locality/action/spawn code can recognize them (`Client/Functions/Client_BuildUnit.sqf:496-510,618-623`).

## FOB Tokens

There are three token grant paths:

| Grant path | Trigger | Token type | Source |
| --- | --- | --- | --- |
| Normal factory destruction | A resistance killer destroys an enemy WEST/EAST Barracks, Light Factory or Heavy Factory. Counts player and AI GUER kills, excludes teamkills. | Barracks = index 0, Light = 1, Heavy = 2. | `Server/Functions/Server_BuildingKilled.sqf:15-32` |
| VBIED factory blast | A GUER VBIED blast levels an enemy Barracks/Light/Heavy structure. The FAB-250 blast has no normal killer instigator, so this is the only grant path for VBIED factory kills. | Same type mapping as normal factory destruction. | `Server/Functions/Server_HandleSpecial.sqf:1283-1297` |
| GUER wildcard checkpoint | GUER holds the insurgent checkpoint wildcard to timeout. Type is tier-scaled by code comment: tier 0-1 Barracks, tier 2 Light, tier 3 Heavy. | One token in the chosen type. | `Server/Functions/AI_Commander_Wildcard_GUER.sqf:287-301` |

Token spending is authoritative on the server. The truck action only pre-checks for immediate feedback (`Client/Action/Action_BuildFOB.sqf:24-45`); the server PVF re-validates the token, checks the no-build zone with `WFBE_FNC_GuerFobBlocked`, decrements and broadcasts `WFBE_GUER_FOB_AVAIL`, runs the standard resistance construction path, and deletes the delivery truck (`Server/PVFunctions/RequestFOBStructure.sqf:22-67`). The PVF is registered in `Common/Init/Init_PublicVariables.sqf:15-16`.

`Init_Unit.sqf` adds the `Build FOB` action to every class in `WFBE_C_GUER_FOB_TRUCKS`, but the action condition also requires the broadcast `wfbe_is_guer_fob` tag and a nearby resistance player (`Common/Init/Init_Unit.sqf:82-96`). This protects shared truck classnames that other factions can still buy.

Built GUER FOB factories have cleanup and player-facing support: destroying a GUER FOB emits the distinct `GuerFobCleared` message and removes the resistance structure from the registry (`Server/Functions/Server_BuildingKilled.sqf:69-75,160-168`). Live FOB delivery trucks and built FOB factories are also spawn candidates (`Client/Functions/Client_GetRespawnAvailable.sqf:114-118`, `Client/Functions/Client_OnRespawnHandler.sqf:85-90`).

## UI And Feedback Surfaces

| Surface | What it shows | Source |
| --- | --- | --- |
| Upgrade Center | Replaces the standard upgrade menu for resistance with a read-only GUER field-tech view: kills, heavy tier, M113 status, Ka-137 flares, barracks AI cap and FOB tokens. | `Client/GUI/GUI_UpgradeMenu.sqf:6-19,23-79` |
| RHUD | Adds GUER-only `Tech Kills` and `FOB` rows, shows next unlock progress and token counts. | `Client/Client_UpdateRHUD.sqf:243-246,291-304,377-384,541-551` |
| Buy menu row labels | Marks normal VBIED, M113 VBIED, mortar truck and FOB delivery trucks. | `Client/Functions/Client_UIFillListBuyUnits.sqf:168-192` |
| Unlock notification watcher | Overlay watches `WFBE_GUER_UNLOCK_MSG` and shows each new unlock once. | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:118-120`, `Server/PVFunctions/RequestOnUnitKilled.sqf:119-133` |
| Onboarding tip | Explains that GUER kills unlock field tech and destroyed enemy factories unlock FOB truck options. | `Client/Functions/Common_Onboarding.sqf:89-90` |
| JIP catch-up | Pushes kill count, vehicle tier and FOB availability directly to the joining client. | `Server/Functions/Server_OnPlayerConnected.sqf:156-158` |

## Review Notes

These are documentation findings only; this lane does not change behavior.

| Note | Evidence | Follow-up idea |
| --- | --- | --- |
| Several reader fallbacks still carry pre-retune values (`15/25/40/80` and `10`) even though boot constants now seed `30/50/80/160` and `20`. Normal mission boot initializes the constants first, so this is a resilience/readability issue rather than a live mismatch. | Current constants: `Init_CommonConstants.sqf:108-114,187-190`; reader fallbacks: `Server/Server_GuerStipend.sqf:45-47,60-62`, `Server/PVFunctions/RequestOnUnitKilled.sqf:123-126`, `Client/GUI/GUI_UpgradeMenu.sqf:28-35`, `Client/Client_UpdateRHUD.sqf:291-298,470-475`. | Tiny future cleanup can align fallback literals without changing live defaults. |
| FOB token grants are intentionally broader than player kill-tech. The kill counter increments only for resistance players killing WEST/EAST, but FOB tokens can come from resistance AI factory kills and the GUER wildcard checkpoint too. | Player kill gate: `RequestOnUnitKilled.sqf:115`; normal FOB grant: `Server_BuildingKilled.sqf:15-32`; wildcard grant: `AI_Commander_Wildcard_GUER.sqf:287-301`. | Keep future UI wording clear: kills unlock tech; factory destruction or checkpoint hold unlocks FOB trucks. |
| `RequestFOBStructure.sqf` is the authoritative path, not the client action. The client only checks token/placement for fast feedback. | Client pre-check: `Client/Action/Action_BuildFOB.sqf:29-45`; server checks and spend: `Server/PVFunctions/RequestFOBStructure.sqf:22-67`. | Security review should start at the PVF, not the addAction. |
| Adjacent PR #433 documents tier-progress visibility. This lane intentionally keeps a separate broader system map instead of editing that unmerged report. | PR #433 adds `docs/design/GUER-TIER-PROGRESS-STATUS-2026-07-03.md`. | If both PRs merge, cross-link the two docs in a later docs-only pass. |

## Verification

- Searched the Build84 Chernarus mission tree for `WFBE_GUER_PLAYER_KILLS`, `WFBE_GUER_FOB_AVAIL`, `WFBE_C_GUER_KILLTIER_*`, `WFBE_C_GUER_VBIED_M113_KILLS`, `RequestFOBStructure`, `wfbe_is_guer_fob`, `Build FOB`, `Tech Kills` and `GuerFobCleared`.
- Confirmed the branch descends from `github/claude/build84-cmdcon36@a26871e852470b86b68c2f4f58eb44b436d076d6`.
- Documentation-only scope; LoadoutManager was not run and no mission package was produced.