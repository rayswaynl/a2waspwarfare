# Gameplay Systems Atlas

This atlas is the compact route map for the mission systems that make Warfare behave like Warfare: towns, economy, commander flow, upgrades, construction, factories and victory. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## First-Stop Map

| System | Source anchors | Use / risk |
| --- | --- | --- |
| Town setup and capture | `mission.sqm`; `Common/Init/Init_Town.sqf`; `Server/FSM/server_town.sqf`; `Server/FSM/server_town_camp.sqf` | Town logics seed supply value, side ownership, camps and capture state. Capture/camp logic is server-owned and performance-instrumented. |
| Town AI and patrols | `Server/FSM/server_town_ai.sqf`; `Server/FSM/server_patrols.sqf`; `Server/Init/Init_Towns.sqf` | Town AI activation is separate from town capture. Delegation mode can move creation to server, client or headless paths. DR-45: inactivity cleanup deletes active vehicles by group-leader player status only; see [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety). |
| Economy and side supply | `Server/FSM/updateresources.sqf`; `Common/Functions/Common_ChangeSideSupply.sqf`; `Server/Functions/Server_ChangeSideSupply.sqf` | Income, side supply and AntiStack modifiers interact. Direct side-supply public variables remain authority-sensitive. |
| Commander and votes | `Server/PVFunctions/RequestCommanderVote.sqf`; `Server/PVFunctions/RequestNewCommander.sqf`; `Server/Functions/Server_AssignNewCommander.sqf`; `Server/Functions/Server_VoteForCommander.sqf` | Vote flow works, but manual reassignment DR-15 remains patch-ready/current-source-unpatched. |
| Upgrades | `Server/PVFunctions/RequestUpgrade.sqf`; `Server/Functions/Server_ProcessUpgrade.sqf`; `Common/Config/Core_Upgrades/*` | Server processes upgrade completion, but request authority/cost validation remains part of the economy hardening class. |
| Construction and CoIn | `Client/Init/Init_Coin.sqf`; `Client/Module/CoIn/coin_interface.sqf`; `Server/PVFunctions/RequestStructure.sqf`; `Server/PVFunctions/RequestDefense.sqf`; `Server/Construction/*` | Client UI previews locally; server must remain the authority for final creation. DR-6 authority hardening is still open. |
| HQ deploy, mobilize and killed handling | `Server/Construction/Construction_HQSite.sqf:36,89,91`; `Client/Init/Init_Client.sqf:500-503`; `Server/Functions/Server_OnHQKilled.sqf:46-81` | Mobile-HQ killed detection is intentionally redundant across owner-local EHs, but the server-side action lacks an idempotency guard. Route duplicate score/message/state work through [Deep-review findings](Deep-Review-Findings) DR-20 before changing HQ death handling. |
| Factories and unit production | `Client/GUI/GUI_Menu_BuyUnits.sqf`; `Client/Functions/Client_BuildUnit.sqf`; `Server/Functions/Server_BuyUnit.sqf` | Player buy path is client-local; factory queue cleanup DR-33 remains patch-ready/current-source-unpatched. |
| Victory and endgame | `Server/FSM/server_victory_threeway.sqf`; `Server/Functions/Server_LogGameEnd.sqf` | Winner inversion/double-fire findings remain owner-ready correctness work. Route through DR-11/DR-36 before patching. |

## Current Cleanup Status

Use [Current source status snapshot](Current-Source-Status-Snapshot) as the current authority before trusting older worklog/event rows. As of the current snapshot:

| Lane | Status | Evidence summary |
| --- | --- | --- |
| Commander reassignment DR-15 | Patch-ready/current-source-unpatched | `Server_AssignNewCommander.sqf` still uses `_side = _this`; `RequestNewCommander.sqf` still sends a duplicate caller-side notification. |
| Factory queue DR-33 | Patch-ready/current-source-unpatched | `Client_BuildUnit.sqf` still uses random `varQueu` tokens and can exit a crewless purchase before the local queue decrement. |
| Duplicate client `Skill_Init` | Patch-ready/current-source-unpatched | `Client/Init/Init_Client.sqf` still calls `Skill_Init` twice before `WFBE_SK_FNC_Apply`. |
| Supply command-center scan | Patch-ready/current-source-unpatched | `supplyMissionStarted.sqf` still uses broad `nearestObjects [..., [], 80]` before filtering `Base_WarfareBUAVterminal`. |
| Town-AI vehicle despawn safety DR-45 | Patch-ready/current-source-unpatched | `server_town_ai.sqf:214` deletes active vehicles when `!(isPlayer leader group _x)`, missing player cargo/turret occupants. |

## Safe Extension Points

| Change type | Start here | Keep in mind |
| --- | --- | --- |
| New town behavior | `server_town.sqf` for ownership/SV; `server_town_ai.sqf` for AI activation. | Do not couple capture cadence and AI activation by accident. |
| New income behavior | `updateresources.sqf`, side supply helpers and relevant UI. | Re-derive side/requester authority server-side. |
| New commander action | Existing PVF wrapper plus `HandleSpecial` client notification if needed. | Fix DR-15 call shape before trusting manual reassignment semantics. |
| New upgrade effect | `Server_ProcessUpgrade.sqf` plus direct upgrade-level consumers. | Existing artillery refresh logic is special and should be preserved. |
| New structure | Side structure arrays, request handler mapping and matching construction script. | Final creation must be server-owned. |
| New purchasable unit | Unit config arrays, buy menu filtering, `Client_BuildUnit.sqf` and `Server_BuyUnit.sqf` if AI can use it. | Player purchase authority is still legacy/client-local. |

## Continue Reading

Architecture: [Architecture overview](Architecture-Overview) | Economy: [Economy, towns and supply](Economy-Towns-And-Supply) | Factory details: [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas) | Risks: [Feature status register](Feature-Status-Register)

