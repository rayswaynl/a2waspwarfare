# Arma 2 OA External Reference Guide

This page maps official Bohemia Interactive Arma 2 OA scripting references to the Wasp Warfare systems where those engine rules matter. Use it before applying Arma 3-era assumptions to networking, locality, event handlers, object variables, object scans or UI/performance code.

Rule: prefer Bohemia Interactive Community Wiki pages that explicitly list Arma 2: Operation Arrowhead support. When a BI page also describes newer Arma 3 behavior, treat that newer behavior as out-of-scope unless the page or source proves OA support.

Current docs scan: [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) records the latest search for accidental Arma 3 references. The current result is that explicit Arma 3 terms are guardrails or contrast notes, not implementation advice.

Command support scan: [Arma 2 OA command version reference](Arma-2-OA-Command-Version-Reference) records BIKI version-badge checks for command forms that are easy to import by Arma 3 reflex. Treat `params`, `remoteExec`, `parseSimpleArray`, `apply`, `setGroupOwner`, multi-index `select` forms and inline `private _x = ...` as A3-only unless that page or another BI OA source proves otherwise.

## Fast Reference Matrix

| Topic | Official reference | Wasp source hotspots | Development implication |
| --- | --- | --- | --- |
| Multiplayer locality and JIP | [Multiplayer Scripting](https://community.bohemia.net/wiki/Multiplayer_Scripting) | `initJIPCompatible.sqf:176-184`, `Common/Init/Init_PublicVariables.sqf:45,50`, [Lifecycle wait-chain](Lifecycle-Wait-Chain) | Hosted, dedicated, client and JIP paths are not interchangeable. Validate producer/consumer timing before changing replicated flags or post-join waits. |
| `publicVariable` persistence and bandwidth | [publicVariable](https://community.bohemia.net/wiki/publicVariable) | `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:55-56`, [Public variable channel index](Public-Variable-Channel-Index), [Networking/PV](Networking-And-Public-Variables) | Broadcast variables are JIP-replayed, but repeated or large broadcasts can hurt bandwidth. Keep direct-channel additions rare and documented. |
| Public-variable event handlers | [addPublicVariableEventHandler](https://community.bohemia.net/wiki/addPublicVariableEventHandler) | `Common/Init/Init_PublicVariables.sqf:45,50`, [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) | PVEHs trigger on receipt, not on ordinary local assignment. There is no removal path, so registration timing and duplicate init guards matter. |
| Object and namespace variables | [setVariable](https://community.bohemia.net/wiki/setVariable) | `Common/Init/Init_Town.sqf:63,87-88,119-120`, `Client/Module/supplyMission/supplyMissionStart.sqf:20,34`, `Client/Module/CoIn/coin_interface.sqf:715` | The third `setVariable` argument controls network publication. Treat client-written public object vars as untrusted unless the server recomputes or validates them. |
| Event-handler stacking | [addEventHandler](https://community.bohemia.net/wiki/addEventHandler) | `Common/Init/Init_Unit.sqf:101-127,188,211`, `Common/Init/Init_Town.sqf:85,106`, [Current supply heli PR](Current-Work-Supply-Helicopters-PR1) | `addEventHandler` stacks instead of replacing old handlers. Use guard object vars or stored handler IDs before re-registering effects on reusable vehicles/units. |
| Object scans | [nearestObjects](https://community.bohemia.net/wiki/nearestObjects) | `Server/Module/supplyMission/supplyMissionStarted.sqf:28,44`, `Server/FSM/cleaners/crater_cleaner.sqf:15,28`, `Server/FSM/cleaners/droppeditems_cleaner.sqf:15,22,29` | Prefer narrow class filters and bounded cadence. Matching uses inheritance (`isKindOf`), and broad empty-type scans are review targets. |
| Compile/preprocess diagnostics | [preprocessFileLineNumbers](https://community.bohemia.net/wiki/preprocessFileLineNumbers) | `initJIPCompatible.sqf:37,56,62-63,121,123`, `Common/Init/Init_PublicVariables.sqf:44,49`, [SQF code atlas](SQF-Code-Atlas) | Keep `preprocessFileLineNumbers` for compiled functions because line numbers improve RPT debugging. Missing files are build/runtime risks, not cosmetic docs nits. |
| Command-version traps | [Arma 2 OA command version reference](Arma-2-OA-Command-Version-Reference) | [Deep-review findings](Deep-Review-Findings) DR-1 Fix 2, [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook), [Compatibility audit](Arma-2-OA-Compatibility-Audit) | Do not use A3-only syntax such as `apply`, `params`, `setGroupOwner`, multi-index `select` or inline private assignment in OA snippets. Also do not remove OA-safe inverse-trap commands like `diag_tickTime`, `uiSleep`, `setVehicleInit` or `processInitCommands` just because A3 changed them. |
| Simulation vs render scope | [Simulation vs Render Time Scope](https://community.bohemia.net/wiki/Simulation_vs_Render_Time_Scope) | `Common/Common_MarkerUpdate.sqf:78-88,103-218`, `Common/Common_AARadarMarkerUpdate.sqf:55-180`, [Client UI systems atlas](Client-UI-Systems-Atlas) | For visible HUD/marker work, distinguish smooth visual positions from lower-rate simulation state. Do not blindly replace position commands with Arma 3-only variants. |
| FPS/tick diagnostics | [diag_fps](https://community.bohemia.net/wiki/diag_fps), [diag_tickTime](https://community.bohemia.net/wiki/diag_tickTime) | `Common/Functions/Common_GetSleepFPS.sqf:5-9`, `Server/Module/serverFPS/monitorServerFPS.sqf:4`, `Common/Functions/Common_PerformanceAudit.sqf:84,154` | Performance docs and patches should preserve existing diagnostic vocabulary: FPS, tick time, RPT logs and PerformanceAudit records. |

## Repo-Specific Rules

1. Do not import Arma 3 networking patterns such as `remoteExec` into this mission. The live system is Arma 2 OA-era public variables, PVEHs and Wasp/WFBE wrapper functions.
2. For networked state, first classify it as missionNamespace global, object variable, group variable, UI namespace state, profile state or local script state.
3. For JIP, distinguish replayed public variables from live event-handler side effects. A late joiner can receive variable values without having seen the original event sequence.
4. For object variables with `true`, ask who wrote the value. If the client wrote authority-bearing cargo, price, side or reward data, document it as a trust boundary.
5. For event handlers, assume repeated initialization can stack handlers unless source shows a guard, a removed handler ID or a one-shot object lifecycle.
6. For command syntax, check the command-version reference before using modern forms such as `apply`, `params`, `setGroupOwner`, multi-index `select` or inline `private _x = ...`.
7. For object scans, avoid changing class filters or scan radii without checking inheritance behavior and runtime cadence.
8. For performance code, preserve source-backed RPT/PerformanceAudit evidence instead of replacing it with unsupported profiling assumptions.

## Wasp Examples To Recheck First

| Change area | Read these first | Why |
| --- | --- | --- |
| PVF dispatcher hardening | [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook), [Networking/PV](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index) | PVEH behavior, JIP replay and direct-channel exceptions define the safe migration path. |
| Supply mission or PR #1 supply heli work | [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Supply mission architecture](Supply-Mission-Architecture), [Current supply heli PR](Current-Work-Supply-Helicopters-PR1) | This area combines client-written object vars, server completion, reusable vehicles, event handlers and broad object scans. |
| Town/camp state | [Gameplay systems atlas](Gameplay-Systems-Atlas), [Economy/towns/supply](Economy-Towns-And-Supply) | Town variables use both local and public object vars; capture, SV and marker state are JIP-sensitive. |
| UI/marker/performance work | [Client UI systems atlas](Client-UI-Systems-Atlas), [AI/headless/performance](AI-Headless-And-Performance), [Testing workflow](Testing-Debugging-And-Release-Workflow) | Visible state, client loops and performance audit records need OA-compatible timing and position assumptions. |
| Generated mission propagation | [Tools/build](Tools-And-Build-Workflow), [Content/maps](Content-Structure-And-Maps) | Engine-correct source changes still need Chernarus-first edits and LoadoutManager propagation. |

## Open Reference Questions

| Question | Why it remains open | Suggested owner |
| --- | --- | --- |
| Exact Arma 2 OA behavior for removing vehicle `Killed` EHs in PR #1 supply-heli reuse | The BI `addEventHandler` page confirms stacking and removal by ID, but the PR branch needs an in-game smoke test for reusable supply vehicles. | Future supply code owner |
| Exact best class filter for command-center scans | `nearestObjects` supports class arrays and `isKindOf` matching, but the mission currently filters terminal type in script after broad scans. | Future supply/performance owner |
| Whether any visual-position command is worth adopting for map/HUD work | OA 1.60 introduced render/simulation split, but any command substitution must be verified for OA 1.64 and existing UI behavior. | UI/performance owner |

## Continue Reading

Previous: [Testing workflow](Testing-Debugging-And-Release-Workflow) | Next: [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
