# Server Gameplay Runtime Atlas

This atlas maps long-running server gameplay loops and runtime surfaces that future owners should treat carefully. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## Runtime Loops

| Runtime surface | Source anchors | Notes |
| --- | --- | --- |
| Town capture loop | `Server/Init/Init_Server.sqf:510`; `Server/FSM/server_town.sqf` | Server-owned capture, supply value changes, camp side updates and performance audit rows. |
| Town AI loop | `Server/Init/Init_Server.sqf:512-514`; `Server/FSM/server_town_ai.sqf` | Defender/occupation activation, town AI delegation, static defense operation and despawn behavior. |
| Resource loop | `Server/Init/Init_Server.sqf:531`; `Server/FSM/updateresources.sqf` | Side supply/player funds/commander funds. Economy and AntiStack changes can alter income behavior. |
| Victory loop | `Server/Init/Init_Server.sqf:528`; `Server/FSM/server_victory_threeway.sqf` | Winner inversion/double-fire hazards live here; route through DR-11/DR-36 before patching. |
| Supply mission tracking | `Server/Module/supplyMission/supplyMissionStarted.sqf`; `Server/Module/supplyMission/supplyMissionCompleted.sqf` | Client-stamped cargo/reward state remains an authority cleanup lane; completion calls `ChangeSideSupply`, so rewards hit the DR-44 `wfbe_supply_temp_<side>` final mutation channel. Scan narrowing remains current-source-unpatched. |
| HQ killed processing | `Server/Construction/Construction_HQSite.sqf:89,91`; `Client/Init/Init_Client.sqf:500-503`; `Server/Functions/Server_OnHQKilled.sqf:46-81,96-114` | Mobile-HQ killed EHs can fire from multiple owning-side clients; `Server_OnHQKilled.sqf` currently has no processed-once guard before score awards, messages and HQ marker/state broadcasts. Canonical finding: [Deep-review findings](Deep-Review-Findings) DR-20. |
| Server FPS publishing | `Server/GUI/serverFpsGUI.sqf`; `Server/Module/serverFPS/monitorServerFPS.sqf`; `Server/Init/Init_Server.sqf:578,595` | Current source/Vanilla still enter FPS loops before checking `isDedicated`; sleep is only in the dedicated branch. Canonical finding: [Deep-review findings](Deep-Review-Findings) DR-19. |

## Current Runtime Risks

| Risk | Status | Owner route |
| --- | --- | --- |
| Hosted/listen FPS busy loop | Patch-ready/current-source-unpatched; DR-19 | [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep) and [Deep-review findings](Deep-Review-Findings) DR-19 |
| Supply command-center broad scan | Patch-ready/current-source-unpatched | [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing) |
| Supply reward/cooldown authority | Open hardening; includes DR-44 final side-supply mutation channel | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) |
| Victory double-fire/winner inversion | Open correctness | [Deep-review findings](Deep-Review-Findings) DR-11/DR-36 |
| HQ-killed duplicate processing / score exploit | Open correctness; DR-20 | [Deep-review findings](Deep-Review-Findings) DR-20 |
| Direct PV authority | Open hardening | [Public variable channel index](Public-Variable-Channel-Index) |
| AntiStack/database loops | High-sensitivity | [External integrations](External-Integrations) and [AI, headless and performance](AI-Headless-And-Performance) |

## Safe Runtime Rules

- Do not remove sleeps or change scan cadence without measuring gameplay and performance effects.
- Keep Arma 2 OA hosted/dedicated/headless differences explicit; do not import Arma 3 locality/JIP examples.
- Treat publicVariable handlers as lacking a trusted sender identity unless source proves a server-owned anchor.
- When gameplay code is requested later, patch source Chernarus first and propagate generated Vanilla Takistan through LoadoutManager.

## Continue Reading

Systems: [Gameplay systems atlas](Gameplay-Systems-Atlas) | Performance: [Performance opportunity sweep](Performance-Opportunity-Sweep) | Current truth: [Current source status snapshot](Current-Source-Status-Snapshot)

