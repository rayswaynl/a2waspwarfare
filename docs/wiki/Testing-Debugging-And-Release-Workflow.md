# Testing Debugging And Release Workflow

Practical validation model for ongoing Arma 2 Operation Arrowhead 1.64 mission development.

This repo cannot lean on a modern SQF unit-test suite. The safe workflow is a mix of source checks, local tooling checks, RPT-driven smoke tests and careful release gates. Every future change should record what was actually verified, not just what was source-reviewed.

Scope: gameplay edits start in `Missions/[55-2hc]warfarev2_073v48co.chernarus`; generated mission behavior is handled through `Tools/LoadoutManager` unless a skip-list file needs hand mirroring.

Machine schema for test evidence: [`agent-test-plan.schema.json`](agent-test-plan.schema.json).

## Test Levels

| Level | Use when | Evidence to record |
| --- | --- | --- |
| `source-only` | Static defects: missing files, commented compiles, compile registries, PV channel maps, IDD conflicts, generated drift. | Exact paths, line refs, search command or script, and whether the issue is confirmed or only a lead. |
| `local-tool` | LoadoutManager generation, PerformanceAuditAnalyzer parsing, DiscordBot/Extension build or config shape. | Command, cwd, exit code, generated files or expected non-blocking failure such as missing `7za`. |
| `hosted-smoke` | Locality-sensitive behavior where hosted server also runs client code. | Scenario, mission params, RPT snippets, observed player/server behavior. |
| `dedicated-smoke` | Server-authority, PV/PVF, economy, town AI, cleanup loops, BattlEye-sensitive behavior. | Dedicated server RPT, client RPT if available, result and regressions checked. |
| `jip-smoke` | Any state that late joiners must see: towns, markers, HQ, commander, supply cooldowns, MASH, endgame. | Join timing, expected replicated variables/events, client observations after join. |
| `hc-smoke` | AI delegation, town AI, static defenses and HC registration. | HC connection timing, `connected-hc` handling, delegated units, server FPS/load effect. |
| `live-server-sensitive` | BattlEye, AntiStack DB, public server economy authority, Discord token/data paths, extensions. | Owner approval, backup/rollback path, exact server config, and redacted logs only. |

## System Test Matrix

| System | Source paths | Minimum validation | Notes |
| --- | --- | --- | --- |
| Boot/lifecycle | `description.ext`, `initJIPCompatible.sqf`, `Common/Init/*`, `Server/Init/Init_Server.sqf`, `Client/Init/Init_Client.sqf`, `Headless/Init/Init_HC.sqf`, `mission.sqm` | `source-only`, then hosted or dedicated boot smoke for reordered init. | Check `version.sqf`, `WFBE_Parameters_Ready`, `commonInitComplete`, `townInit`, `serverInitFull`, `clientInitComplete`. `mission.sqm` town object init is part of runtime. |
| PV/PVF networking | `Common/Init/Init_PublicVariables.sqf`, `Server/Functions/Server_HandlePVF.sqf`, `Client/Functions/Client_HandlePVF.sqf`, `Server/PVFunctions/*`, `Client/PVFunctions/*` | `source-only` for registry, dedicated smoke for changed handlers, JIP smoke for stateful effects. | PVF dispatch hardening must test one server-bound and one client-bound message. Direct PV channels are outside the PVF list. |
| Economy authority | `Client/GUI/GUI_Menu_BuyUnits.sqf`, `Client/Functions/Client_BuildUnit.sqf`, `Server/PVFunctions/RequestStructure.sqf`, `Server/Functions/Server_ProcessUpgrade.sqf`, `Server/PVFunctions/RequestUpgrade.sqf`, gear/EASA GUI files | `source-only`, then dedicated smoke for each migrated spend path. | Record whether the server or client owns final funds/effect. Client menu checks are not authority. |
| Towns and town AI | `mission.sqm`, `Common/Init/Init_Town*.sqf`, `Server/FSM/server_town.sqf`, `Server/FSM/server_town_camp.sqf`, `Server/FSM/server_town_ai.sqf`, `Common/Functions/Common_CreateTownUnits.sqf` | Dedicated smoke; JIP smoke for town state; HC smoke when delegation is enabled. | Use [Towns/camps/capture atlas](Towns-Camps-And-Capture-Atlas). For [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety), test occupied and empty vehicle despawn cases. |
| Commander and HQ lifecycle | [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas), `Server_VoteForCommander.sqf`, `RequestNewCommander.sqf`, `Construction_HQSite.sqf`, `Server_OnHQKilled.sqf`, `Server_MHQRepair.sqf`, `Client/FSM/updateclient.sqf` | Dedicated plus JIP smoke for commander handoff, deploy/mobilize, HQ death, wreck marker visibility and repair. | Include hosted/locality smoke for mobile-HQ killed EH forwarding and one-message commander reassignment after DR-15 repair. |
| Construction and CoIn | `Client/Module/CoIn/coin_interface.sqf`, `Server/PVFunctions/RequestStructure.sqf`, `Server/PVFunctions/RequestDefense.sqf`, `Server/Functions/Server_Build*` | Dedicated smoke for accepted/rejected builds. | Validate commander/repair authority, funds, base area, dead HQ and side ownership server-side after hardening. |
| Factories and purchases | `Client/GUI/GUI_Menu_BuyUnits.sqf`, `Client/Functions/Client_BuildUnit.sqf`, `Server/Functions/Server_BuyUnit.sqf` | Hosted and dedicated smoke for spawn markers, queues and empty-vehicle cases. | DR-33 queue leak needs repeated empty-vehicle buy attempts to prove decrement behavior. |
| Upgrades | Live path: `WFBE_UpgradeMenu` / `Client/GUI/GUI_UpgradeMenu.sqf`; stale path: `RscMenu_Upgrade` / missing `Client/GUI/GUI_Menu_Upgrade.sqf`; server path: `Server/PVFunctions/RequestUpgrade.sqf`, `Server/Functions/Server_ProcessUpgrade.sqf` | Dedicated smoke for valid upgrade, invalid id, insufficient funds, wrong-side/role. | Server must recompute level, dependency and cost after hardening. Do not revive the stale dialog class without replacing its missing onLoad target. |
| Supply missions | `Client/Module/supplyMission/*`, `Server/Module/supplyMission/*`, `Server/Init/Init_Server.sqf`, `Server/Functions/Server_OnPlayerDisconnected.sqf` | Dedicated smoke, JIP cooldown smoke, reconnect/disconnect player-list smoke, PR #1 vehicle reuse/destruction smoke when relevant. | Keep the pull-based cooldown model; fix dead twin/casing/player-list/trust issues before expanding heli behavior. |
| Respawn and MASH | [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas), `Client/GUI/GUI_RespawnMenu.sqf`, `Client/Functions/*Respawn*`, `Server/AI/AI_*Respawn*.sqf`, `Server/Module/MASH/*`, `Client/Init/Init_Client.sqf` | Player death/menu/gear smoke, AI respawn smoke, source-only for dead marker path; JIP smoke if markers are revived. | Current MASH marker chain is dead/orphaned; local MASH respawn and mode-5 custom-gear penalty need separate smoke. |
| Supports and specials | `Client/Module/Nuke/*`, `Server/Functions/Server_HandleSpecial.sqf`, `Server/Support/*`, attack-wave files | Dedicated smoke for authority-sensitive actions; live-server-sensitive for ICBM and BattlEye. | ICBM and attack waves are high-risk because forged PV payloads can create server-side effects. |
| AI and HC delegation | `Headless/Init/Init_HC.sqf`, `Client/Functions/Client_Delegate*.sqf`, `Common/Functions/Common_Delegate*.sqf`, `Server/Functions/Server_OnPlayerDisconnected.sqf` | HC smoke for delegation and reconnect/disconnect behavior. | `Init_HC.sqf` uses `sleep 20`, not `waitUntil {serverInitFull}`. |
| UI/HUD/dialogs | `Rsc/*.hpp`, `Client/GUI/*`, `Client/Init/Init_Client.sqf`, `Client/Module/RHUD/*` | Source-only for IDD/resource conflicts; hosted smoke for display open/close and long text. | Duplicate IDDs exist; use display handles and avoid assuming IDD uniqueness. |
| WASP overlay | `WASP/*`, `Client/Init/Init_Client.sqf`, `initJIPCompatible.sqf` commented WASP block | Hosted/JIP smoke for per-client actions; source-only for dead old init path. | Live WASP features are wired from client init, not the old commented `WASP/Init_Client.sqf` block. |
| Tooling and generated missions | `Tools/LoadoutManager/*`, `Tools/PerformanceAuditAnalyzer/*`, `Missions_Vanilla/*`, `Modded_Missions/*` | `local-tool`, source-only drift checks. | Run LoadoutManager from an ancestor folder named `a2waspwarfare` or any repo root containing `Missions`, `Missions_Vanilla` and `Tools/LoadoutManager/LoadoutManager.csproj`. Use `A2WASP_SKIP_ZIP=1` for propagation-only runs; `7za` is only required for deployment packaging. |
| Integrations | `Extension/*`, `DiscordBot/*`, `BattlEyeFilter/*`, `Server/Module/AntiStack/*` | `source-only`, local build/config checks, live-server-sensitive for production. | Do not expose secrets. Distinguish in-repo `GLOBALGAMESTATS` extension from out-of-repo AntiStack DB DLL. |

## Static Analysis Checklist

Run these before any major gameplay patch and after large generated changes:

| Check | What it catches |
| --- | --- |
| Compile/preprocess registry scan | Commented or missing functions in `Init_Common.sqf`, `Init_Server.sqf`, `Init_Client.sqf`, `Init_PublicVariables.sqf`. |
| Missing file scan | Dead `execVM`, `preprocessFile`, `#include` and dialog onLoad references. |
| PV channel inventory | New direct `publicVariable`, `publicVariableServer`, `addPublicVariableEventHandler` channels not covered by PVF docs. |
| Client-authority scan | New client-side `createVehicle`, `createUnit`, `setDammage`, `ChangePlayerFunds`, side supply or upgrade mutations. |
| JIP replay scan | New transient PV events that should have replicated object variables or pull-based state requests. |
| IDD/resource scan | Duplicate display/title IDDs and missing Rsc class references. |
| Generated drift scan | Chernarus versus Takistan outside the LoadoutManager skip-list; modded missions are separate forks/stubs. |
| Extension trust scan | `callExtension` return handling, `call compile`, serialization settings and missing DLL/config assumptions; route through [Integration trust boundary audit](Integration-Trust-Boundary-Audit) and [AntiStack database extension audit](AntiStack-Database-Extension-Audit) for AntiStack-specific DB wrappers. |

## RPT Logging Conventions

Use the existing logging helper instead of ad hoc `hint` debugging:

| Log type | Use |
| --- | --- |
| `WFBE_CO_FNC_LogContent` with `INFORMATION` | Successful state transitions testers need to confirm in RPT, such as accepted high-value server transactions. |
| `WFBE_CO_FNC_LogContent` with `WARNING` | Rejected malformed/unauthorized network payloads, missing generated files or degraded but recoverable state. |
| `WF_Debug`-gated detail logs | Noisy values: prices, side IDs, object refs, queue ids, player occupancy decisions, PV payload summaries. |
| Performance audit records | Long-running loops or known hot paths such as town AI, supply mission tracking and UI/map loops. |

Do not add constant always-on logs inside hot loops. For tester-visible changes, one small always-on line at the transition point is better than frame-by-frame tracing.

## Minimal Smoke Packs

| Pack | Steps |
| --- | --- |
| Boot and JIP | Start hosted or dedicated mission, verify no init hang, join a second client after `time > 30`, confirm town markers, HQ state, commander/vote state and spawn location. |
| Commander/HQ | Vote or assign commander, deploy HQ, mobilize HQ, destroy deployed HQ, destroy mobile HQ, join late as allied/enemy client, repair MHQ, confirm build action, lock actions, local allied wreck marker and no enemy wreck marker. |
| PVF dispatcher hardening | Trigger one server request such as `RequestJoin` or `RequestVehicleLock`; trigger one client message such as `LocalizeMessage`; confirm rejected bogus handler logs once and does not execute. |
| Town AI vehicle despawn | Wake a town, board a town-AI vehicle as passenger/gunner, force inactivity or lower `WFBE_C_TOWNS_UNITS_INACTIVE`, confirm occupied vehicle survives and empty AI-only vehicles despawn. |
| Factory queue | Buy repeated empty/crewless vehicles from the relevant factory, confirm local queue count decrements and future buys are not soft-locked. |
| Supply mission | Start a truck mission, complete it once, repeat after cooldown, JIP during cooldown query, disconnect/reconnect same UID and verify `WFBE_SE_PLAYERLIST` replacement/no stale completion, tamper or stale `SupplyFromTown` / `SupplyAmount` and confirm server validation after hardening, destroy tracked vehicle once if PR #1 interdiction logic is in scope. |
| Victory/endgame | Use [Victory/endgame atlas](Victory-And-Endgame-Atlas). Simulate HQ/factory elimination and all-town capture paths, confirm one winner, one endgame broadcast and one stats log. |
| LoadoutManager | From the repo root or `Tools/LoadoutManager`, optionally set `A2WASP_SKIP_ZIP=1`, then run `dotnet run`; inspect generated EASA/balance outputs, Takistan copy, `version.sqf`, and whether packaging was skipped or failed only because `7za` is missing. |

## Propagated Fix Smoke Pack

These checks cover the 2026-06-02 source fixes that have been propagated from Chernarus source to maintained Vanilla Takistan. They are planned gates, not completed runtime evidence, until an Arma 2 OA hosted/dedicated run records RPT snippets and observations.

| Fix | Coverage | Setup | Steps | Expected evidence | Failure signals |
| --- | --- | --- | --- | --- | --- |
| Paratrooper marker revival | `dedicated-smoke`, client PVF | Dedicated or hosted run with a commander/player able to trigger tactical paratroopers. | Trigger paratrooper support from a client, observe the requesting client during drop creation and after units eject. | Client receives `HandleParatrooperMarkerCreation`, marker appears for the requesting player flow, and RPT has no missing/unregistered `WFBE_PVF_HandleParatrooperMarkerCreation` error. Source refs: `Common/Init/Init_PublicVariables.sqf`, `Server/Support/Support_Paratroopers.sqf`. | Drop works but marker never appears; undefined variable/function or rejected PVF handler in client RPT. |
| Client skill init idempotency | `hosted-smoke`, respawn smoke | Hosted or dedicated with one Soldier-class player and one non-Soldier class if available. | Join, inspect AI/team cap behavior, respawn, and confirm skill effects still apply after respawn. | `Skill_Init.sqf` effects are initialized once before `WFBE_SK_FNC_Apply`; Soldier cap is not boosted twice, non-Soldier keeps configured cap, respawn still reapplies skill effects. Source refs: `Client/Init/Init_Client.sqf`, `Client/Module/Skill/Skill_Init.sqf`, `Client/Module/Skill/Skill_Apply.sqf`. | Repeated cap inflation, lost skill action after respawn, or undefined skill globals after client init. |
| Hosted server FPS loop sleep | `dedicated-smoke`, `hosted-smoke` | One dedicated run and one hosted/listen run with RPT/perf observation. | On dedicated, wait at least two publish intervals; on hosted/listen, confirm server FPS scripts exit rather than running forever. | Dedicated still publishes `SERVER_FPS_GUI` / `WFBE_VAR_SERVER_FPS` roughly every 8 seconds; hosted/listen run has no busy FPS publisher loop. Source refs: `Server/GUI/serverFpsGUI.sqf`, `Server/Module/serverFPS/monitorServerFPS.sqf`. | Dedicated no longer publishes FPS; hosted/listen RPT or profiler shows repeated FPS loop work. |
| Supply mission scan narrowing | `dedicated-smoke`, optional PR #1 heli smoke | Dedicated run with a supply truck, real command center terminal and unrelated nearby objects. | Start supply mission, drive loaded vehicle to command center, repeat near unrelated objects inside 80m, and recheck cooldown after completion. | Delivery completes near a real `Base_WarfareBUAVterminal` command center, does not complete near unrelated objects, and pull-based cooldown behavior is unchanged. Source refs: `Server/Module/supplyMission/supplyMissionStarted.sqf`, `Common/Config/*/Config_Structures.sqf`. | No completion at command center; completion near unrelated objects; new cooldown/JIP regression. |
| Supply player-object list indexing | `dedicated-smoke`, `jip-smoke`, reconnect smoke | Dedicated run with at least one reconnecting player/client UID and an active supply completion. | Join, start or observe supply flow, disconnect/reconnect the same UID, complete supply near the vehicle/player, inspect server behavior. | Reconnecting UID replaces its own `WFBE_SE_PLAYERLIST` row rather than row 0; supply completion resolves the correct nearby real player object. Source refs: `Server/Module/supplyMission/playerObjectsList.sqf`, `Server/Module/supplyMission/supplyMissionStarted.sqf`. | Row 0 overwrite symptoms, stale player object used for reward/completion, or reconnect prevents nearby player detection. Disconnect pruning is still a separate open cleanup. |

## Release Checklist

| Gate | Requirement |
| --- | --- |
| Source state | Gameplay edits are in Chernarus source mission; generated targets are propagated or skip-listed files are hand-mirrored deliberately. |
| Documentation | Feature status, hardening roadmap, relevant atlas page and Agent worklog updated. |
| Machine evidence | A test record matching [`agent-test-plan.schema.json`](agent-test-plan.schema.json) is added or linked from agent files. |
| Runtime smoke | Required hosted/dedicated/JIP/HC smoke packs completed for the changed subsystem. |
| RPT review | No new scheduler, undefined variable, missing file or extension errors in relevant RPT logs. |
| Tooling | LoadoutManager run or explicitly not required; missing `7za` handled according to deployment need. |
| BattlEye/server config | Public-server release has reviewed `publicvariable.txt`, `scripts.txt`, server config and any production-only filters. Current repo does not ship a complete BE hardening set. |
| Integrations | DiscordBot tokens/configs and extension DLLs are present only in deployment, never committed; DiscordBot JSON intake, in-repo extension writes, AntiStack DB and BattlEye claims are checked against [Integration trust boundary audit](Integration-Trust-Boundary-Audit), with AntiStack runtime/DB validation in [AntiStack database extension audit](AntiStack-Database-Extension-Audit). |
| Rollback | Previous mission PBO/package and server config can be restored. |

## Agent Test Record Schema

Use [`agent-test-plan.schema.json`](agent-test-plan.schema.json) for future machine-readable test evidence. The important distinction is `coverageLevel`: a finding marked `source-only` is useful, but it is not proof of in-game behavior.

Minimal record example:

```json
{
  "schema": "a2waspwarfare-agent-test-plan-v1",
  "id": "town-ai-vehicle-despawn-smoke-2026-06-02",
  "status": "planned",
  "coverageLevel": ["dedicated-smoke"],
  "subsystems": ["town-ai", "vehicle-cleanup"],
  "sourceRefs": [
    "Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town_ai.sqf:211-216"
  ],
  "steps": [
    "Wake town AI with a vehicle template.",
    "Put player in cargo or turret.",
    "Force inactivity despawn.",
    "Confirm occupied vehicle survives and empty AI-only vehicles despawn."
  ],
  "evidence": [],
  "result": "not-run"
}
```

## Continue Reading

Previous: [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) | Next: [Deep-review findings](Deep-Review-Findings)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
