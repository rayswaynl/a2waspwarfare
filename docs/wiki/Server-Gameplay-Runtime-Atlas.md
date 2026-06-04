# Server Gameplay Runtime Atlas

Upstream-history note: Miksuu commit clusters show that server runtime changes around town AI, JIP and performance often need follow-up fixes. Read [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) before altering long-running server loops or wakeup logic.

This atlas maps long-running server gameplay loops and runtime surfaces that future owners should treat carefully. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## Runtime Loops

| Runtime surface | Source anchors | Notes |
| --- | --- | --- |
| Town capture loop | `Server/Init/Init_Server.sqf:510`; `Server/FSM/server_town.sqf` | Server-owned capture, supply value changes, camp side updates and performance audit rows. |
| Town AI loop | `Server/Init/Init_Server.sqf:512-514`; `Server/FSM/server_town_ai.sqf` | Defender/occupation activation, town AI delegation, static defense operation and despawn behavior. |
| Resource loop | `Server/Init/Init_Server.sqf:531`; `Server/FSM/updateresources.sqf:20-75` | Side supply/player funds/commander funds. The `_supply < WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT` gate wraps all three payout paths, so economy-cap changes can suppress paychecks and AI commander funds as well as side-supply growth. |
| Victory loop | `Server/Init/Init_Server.sqf:528`; `Server/FSM/server_victory_threeway.sqf` | Winner inversion/double-fire hazards live here; route through DR-11/DR-36 before patching. |
| Supply mission tracking | `Server/Module/supplyMission/supplyMissionStarted.sqf`; `Server/Module/supplyMission/supplyMissionCompleted.sqf` | Client-stamped cargo/reward state remains an authority cleanup lane; completion calls `ChangeSideSupply`, so rewards hit the DR-44 `wfbe_supply_temp_<side>` final mutation channel. Scan narrowing is docs/source propagated; use [Current source status snapshot](Current-Source-Status-Snapshot) before making stable-master or release claims. |
| HQ killed processing | `Server/Construction/Construction_HQSite.sqf:89,91`; `Client/Init/Init_Client.sqf:500-503`; `Server/Functions/Server_OnHQKilled.sqf:46-81,96-114` | Mobile-HQ killed EHs can fire from multiple owning-side clients; `Server_OnHQKilled.sqf` currently has no processed-once guard before score awards, messages and HQ marker/state broadcasts. Canonical finding: [Deep-review findings](Deep-Review-Findings) DR-20. |
| Server FPS publishing | `Server/GUI/serverFpsGUI.sqf`; `Server/Module/serverFPS/monitorServerFPS.sqf`; `Server/Init/Init_Server.sqf:578,595` | Current docs/source exits both publishers on `!isDedicated`; Arma smoke and branch-scope proof still decide release status. Canonical finding: [Deep-review findings](Deep-Review-Findings) DR-19. |
| Side radio/message pipeline | `Server/Init/Init_Server.sqf:32`; `Server/Functions/Server_SideMessage.sqf`; callers in `server_town.sqf:199,230,233`, `Server_BuildingKilled.sqf:92` and `Server_ProcessUpgrade.sqf:85` | Server-owned HQ-radio/kbTell messages for towns, bases, strongpoints, construction, commander votes and upgrades. Keep this separate from `LocalizeMessage` chat/PVF effects. See [SideMessage pipeline shape](#sidemessage-pipeline-shape). |

Mini-scout follow-up 2026-06-04 mapped the startup cluster around `Server/Init/Init_Server.sqf:507-626`: town runtime, town AI, victory, resources, garbage and empty-vehicle collectors, cleaner/restorer workers, server FPS publishers, Performance Audit, AFK kick, AntiStack loops, player-count monitor, commander vote workers and day/night control all start from this hub. Runtime edits should therefore be reviewed as a worker set, not as isolated scripts.

Lifecycle correction from the 2026-06-04 scout wave: the current checkout uses `Missions`, not an older `Migrations` path spelling. Current-source AntiStack loop evidence belongs under `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/AntiStack/`: `countPlayerScores.sqf` starts `updateScoreInternal.sqf`, `updateScoreInternal.sqf` runs a no-gameover score update loop, `skillDiffCompensation.sqf` loops while `!WFBE_GameOver`, and `clientHasConnectedAtLaunch` / `hasConnectedAtLaunchACK` form the launch-join ACK handshake. Keep path spelling and loop ownership exact when promoting scout notes into code tasks.

## SideMessage Pipeline Shape

`SideMessage` is a server-compiled radio wrapper, not the same path as client `LocalizeMessage`. Server init compiles it from `Server/Functions/Server_SideMessage.sqf` (`Server/Init/Init_Server.sqf:32`). The handler reads the side, message key and optional parameters (`Server_SideMessage.sqf:3-5`), resolves the side radio HQ speaker/receiver/topic from side logic (`:7-11`) and then calls `kbTell` through a compact switch (`:13-64`).

The payload shape is message-family dependent:

| Message family | Expected shape | Representative callers |
| --- | --- | --- |
| Town object messages | `[_side, "Lost" / "Captured" / "HostilesDetectedNear", _townLogic]` | town lost/captured uses `server_town.sqf:230,233`; town-AI activation uses `server_town_ai.sqf:134`. |
| Nearby strongpoint/town messages | `[_side, "LostAt" / "CapturedNear", ["Strongpoint", _townLogic]]` | camp side changes use `server_town_camp.sqf:127,130`; handler expects `select 0` as a spoken label and `select 1` as the town logic (`Server_SideMessage.sqf:23-30`). |
| Base or town attack/construction messages | `[_side, "Constructed" / "Destroyed" / "Deployed" / "Mobilized" / "IsUnderAttack", ["Base", _structure]]` or `["Town", _townLogic]` | construction/HQ paths use `Construction_SmallSite.sqf:115`, `Construction_MediumSite.sqf:130`, `Construction_HQSite.sqf:35,88`; base damage/kill/HQ kill use `Server_BuildingDamaged.sqf:13`, `Server_BuildingKilled.sqf:92`, `Server_OnHQKilled.sqf:53`; town attack uses `server_town.sqf:199`. |
| No-parameter radio topics | `[_side, "VotingForNewCommander" / "NewIntelAvailable" / "MMissionFailed" / "NewMissionAvailable"]` | commander vote uses `RequestCommanderVote.sqf:20`; upgrade completion uses `Server_ProcessUpgrade.sqf:85`. |
| Parameterized mission/extraction topics | `[_side, "MMissionComplete" / "ExtractionTeam" / "ExtractionTeamCancel", [spokenText, dubbingClass]]` | handled by `Server_SideMessage.sqf:61-62`; source-check the current caller before adding one. |

Do not collapse this into `LocalizeMessage`. `LocalizeMessage` is registered as a client PVF (`Common/Init/Init_PublicVariables.sqf:32`) and its client handler can show chat/title text or mutate local funds for some tags, for example `Teamkill`, `SecondaryAward` and `HeadHunterReceiveBounty` (`Client/PVFunctions/LocalizeMessage.sqf:49,53,57-68`). `SideMessage` is the server-owned radio/dubbing path. If you add radio lines, dubbing classes or new side-message keys, smoke each payload family in Arma 2 OA and inspect both the side radio output and the adjacent `LocalizeMessage` path if the same gameplay event also emits chat/economy feedback.

## Current Runtime Risks

| Risk | Status | Owner route |
| --- | --- | --- |
| Hosted/listen FPS busy loop | Docs/source propagated; stable/release branch status and Arma smoke decide shipped state; DR-19 | [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep), [Current source status snapshot](Current-Source-Status-Snapshot) and [Deep-review findings](Deep-Review-Findings) DR-19 |
| Supply command-center broad scan | Docs/source propagated; stable/release branch status and Arma smoke decide shipped state | [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing) |
| Supply reward/cooldown authority | Open hardening; includes DR-44 final side-supply mutation channel | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) |
| Victory double-fire/winner inversion | Open correctness | [Deep-review findings](Deep-Review-Findings) DR-11/DR-36 |
| HQ-killed duplicate processing / score exploit | Open correctness; DR-20 | [Deep-review findings](Deep-Review-Findings) DR-20 |
| Direct PV authority | Open hardening | [Public variable channel index](Public-Variable-Channel-Index) |
| Side-message payload shape | Source-cited runtime surface | Use [SideMessage pipeline shape](#sidemessage-pipeline-shape). `SideMessage` takes different parameter shapes for town, strongpoint, base/construction and no-parameter radio topics; keep it separate from `LocalizeMessage` before adding radio/dubbing or changing message text. |
| AntiStack/database loops | High-sensitivity | [External integrations](External-Integrations) and [AI, headless and performance](AI-Headless-And-Performance) |
| AntiStack loop family | Source-cited lifecycle surface | `countPlayerScores`, `updateScoreInternal`, `skillDiffCompensation` and launch ACK workers run from the server startup cluster. Measure and harden DB/loop behavior before changing cadence or join semantics. |
| Dormant maintenance hooks | `Init_Server.sqf:36` comments `UpdateSupplyTruck`; `:567` comments `groupsMonitor`; `:65,88-92` retain older commented AFK/server-FPS/MASH compile remnants. | Keep disabled hooks documented as historical or deliberately revive them with owner-scoped smoke. |

## Safe Runtime Rules

- Do not remove sleeps or change scan cadence without measuring gameplay and performance effects.
- Keep Arma 2 OA hosted/dedicated/headless differences explicit; do not import Arma 3 locality/JIP examples.
- Treat publicVariable handlers as lacking a trusted sender identity unless source proves a server-owned anchor.
- When gameplay code is requested later, patch source Chernarus first and propagate generated Vanilla Takistan through LoadoutManager.

## Continue Reading

Systems: [Gameplay systems atlas](Gameplay-Systems-Atlas) | Performance: [Performance opportunity sweep](Performance-Opportunity-Sweep) | Current truth: [Current source status snapshot](Current-Source-Status-Snapshot)
