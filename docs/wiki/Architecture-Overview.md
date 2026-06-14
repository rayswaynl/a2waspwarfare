# Architecture Overview

For upstream development patterns and negative knowledge from Miksuu PRs, reverts and branch history, start with [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons). It helps distinguish current architecture from old experiments and abandoned merge attempts.

The repository is an Arma 2 OA Warfare/CTI mission derived from Benny's Warfare and actively modernized for the Miksuu/WASP server. The core runtime is SQF in a mission folder, surrounded by C# helper tools, a Discord status bot, and a Windows extension bridge.

Unless a row names another ref, source anchors below are valid for docs head `docs/developer-wiki-index` `adb9dbc8`. Rechecked 2026-06-14: targeted source diffs from `4277a2ad` to `HEAD` over the overview's cited runtime and tooling paths return no changes, preserving the earlier `1bef8801` / `1aa178f8` source-anchor snapshots. Treat stable `origin/master` `cf2a6d6a`, release `a96fdda2`, Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f` as branch-scope refs; follow the owner pages before citing line refs from those branches.

## How To Use This Page

Use this page to choose the right owner document. Keep detailed branch matrices, patch shapes and smoke checklists in the narrower pages.

| Need | Open this |
| --- | --- |
| Boot order, role detection and JIP waits | [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle), [Lifecycle wait-chain](Lifecycle-Wait-Chain), [SQF code atlas](SQF-Code-Atlas) |
| Function compile ownership and runtime wiring | [SQF code atlas](SQF-Code-Atlas), [Function and module index](Function-And-Module-Index), [Variable and naming conventions](Variable-And-Naming-Conventions) |
| Server loops, operations and integrations | [Server runtime and operations](Server-Runtime-And-Operations), [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas), [External integrations](External-Integrations) |
| Networking, PV/PVF and authority hardening | [Networking and public variables](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [Server authority migration map](Server-Authority-Migration-Map), [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook) |
| Client UI, menus, HUD and markers | [Client UI systems atlas](Client-UI-Systems-Atlas), [Player UI workflow map](Player-UI-Workflow-Map) |
| Economy, construction, upgrades, AI, supports and artillery | [Economy, towns and supply](Economy-Towns-And-Supply), [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas), [Upgrades and research](Upgrades-And-Research-Atlas), [AI/headless/performance](AI-Headless-And-Performance), [Support specials and tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas) |
| Generated targets, release propagation and branch status | [Tools and build workflow](Tools-And-Build-Workflow), [Agent release readiness ledger](Agent-Release-Readiness-Ledger), [Current source status snapshot](Current-Source-Status-Snapshot), [Feature status register](Feature-Status-Register) |

## Current Branch Scope

Use this table before turning an architecture overview anchor into a branch claim.

| Ref | Architecture source scope | Practical route |
| --- | --- | --- |
| Docs head `adb9dbc8` | Runtime/tooling anchors listed here are unchanged from `4277a2ad` and the earlier `1bef8801` / `1aa178f8` overview passes for `description.ext`, `initJIPCompatible.sqf`, `Init_Common.sqf`, `Init_Server.sqf`, `Init_Client.sqf`, `Init_HC.sqf`, `FileManager.cs`, `SqfFileGenerator.cs` and `ZipManager.cs`. | Use this page for orientation, then open the linked owner page for system behavior, branch matrices and smoke gates. |
| Stable `origin/master` `cf2a6d6a` and release `a96fdda2` | Same high-level source/generated-target architecture, but branch behavior and line refs differ for propagated fixes, server FPS shape, supply scan shape, commander ARTY, UI/runtime surfaces and tooling root discovery. | Start from [Current source status snapshot](Current-Source-Status-Snapshot), [Source fix propagation queue](Source-Fix-Propagation-Queue) and the subsystem owner page before citing stable/release line refs. |
| Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f` | Source shape is close enough for architecture orientation, but branch drift remains important, including tooling root-discovery differences. | Recheck exact source paths before making upstream/perf claims; use [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) for historical context. |

## Runtime Owner Map

| Partition | Primary responsibility | Source anchors | Deeper owner |
| --- | --- | --- | --- |
| `Common` | Shared constants, config imports, utility functions, public-variable registration, faction/core data, artillery and shared modules. | `Common/Init/Init_Common.sqf:6-85`, `:94-160`, `:289-323`, `:369-371` | [SQF code atlas](SQF-Code-Atlas), [Assets/config/localization atlas](Assets-Config-Localization-And-Parameters-Atlas) |
| `Server` | Authoritative side logic, economy state, towns, AI spawning, victory checks, PVF request handling, cleanup, extension hooks, AntiStack and server metrics. | `Server/Init/Init_Server.sqf:10-95`, `:355-386`, `:507-538`, `:577-620` | [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas), [Server runtime and operations](Server-Runtime-And-Operations) |
| `Client` | UI, menus, player actions, local HUD/marker loops, skill modules, supply mission start flow, map interactions and client PVF handlers. | `Client/Init/Init_Client.sqf:49-140`, `:324-339`, `:360-388`, `:490-509`, `:547-595`, `:773-789` | [Client UI systems atlas](Client-UI-Systems-Atlas), [Player UI workflow map](Player-UI-Workflow-Map) |
| `Headless` | Headless-client function subset and registration into server delegation. | `initJIPCompatible.sqf:164-170`, `:236-238`; `Headless/Init/Init_HC.sqf:4-15` | [AI/headless/performance](AI-Headless-And-Performance), [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) |
| `WASP` | Custom gameplay overlay such as RPG drop, base repair, marker monitor and start-vehicle additions. | `initJIPCompatible.sqf:241-245` keeps the old WASP bootstrap commented; live client wiring starts from `Client/Init/Init_Client.sqf:15`, `:573-574`, and WASP start vehicles are server-created in `Server/Init/Init_Server.sqf:425-463`. | [WASP overlay](WASP-Overlay), [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) |

Partition caveat: `Common/Init/Init_Common.sqf` is not purely client-safe shared code. It imports public variables at `:294-295`, but also has server-only group config under `if (isServer)` at `:302-308`. Confirm the owner before moving compile or config registration.

## Source And Generated Targets

`Missions/[55-2hc]warfarev2_073v48co.chernarus` is the source mission for gameplay edits. Maintained Vanilla/Takistan is generated or copied from that source family; modded folders are not a safe propagation target unless a tooling owner explicitly claims them.

| Target / tool | Current source-backed rule | Owner route |
| --- | --- | --- |
| Source mission | Edit Chernarus first for gameplay/source changes. `description.ext:39-58` includes generated `version.sqf`, sounds/music and the resource/dialog/title/parameter headers. | [Source inventory](Source-Inventory), [Tools and build workflow](Tools-And-Build-Workflow) |
| Generated `version.sqf` contract | `description.ext:39` includes `version.sqf`; clean checkouts need LoadoutManager-generated target files before pack/test claims. | [Mission config/version include graph](Mission-Config-Version-Include-Graph), [Tools and build workflow](Tools-And-Build-Workflow#operator-checklist) |
| LoadoutManager root | Branch-sensitive; this overview keeps only the docs-head anchor. Current docs head still accepts either an ancestor named `a2waspwarfare` or a repo-like root with `Missions`, `Missions_Vanilla` and `Tools/LoadoutManager/LoadoutManager.csproj` (`FileManager.cs:153,158,166,176,184-188`). Stable/release/Miksuu/perf branch splits belong on the tooling owner pages. | [Tools and build workflow](Tools-And-Build-Workflow), [Source fix propagation queue](Source-Fix-Propagation-Queue#current-branch-scope-2026-06-14) |
| Maintained generated targets | `SqfFileGenerator.cs:128-129` writes Chernarus and Takistan terrain outputs; `:131-132` keeps modded terrain writing commented. | [Tools and build workflow](Tools-And-Build-Workflow#generated-mission-status-table) |
| Packaging | `ZipManager.cs:16` packages `Missions` and `Missions_Vanilla`; `Modded_Missions` is commented out. `ZipManager.cs:96-100` supports `A2WASP_SKIP_ZIP` for propagation-only runs. | [Tools and build workflow](Tools-And-Build-Workflow#packaging-and-deployment-notes) |

## Bootstrap Shape

`initJIPCompatible.sqf` is the front-door role router. It imports MP parameters and constants at `:121-123`, applies Air Event/debug overrides at `:125-162`, gates headless support at `:164-170`, starts Common/Towns at `:214-215`, starts Server at `:217-220`, waits for side team state before Client at `:223-233`, and starts Headless at `:236-238`.

The exact wait graph belongs in [Lifecycle wait-chain](Lifecycle-Wait-Chain). The exact compile registry belongs in [SQF code atlas](SQF-Code-Atlas). The high-risk architecture fact is the separation of ownership: server creates replicated side/team/HQ state (`Init_Server.sqf:355-386`, `:465-502`), clients wait for that state and wire local UI/action/runtime surfaces (`Init_Client.sqf:360-388`, `:459-509`, `:787-789`), and headless clients still register after a fixed sleep rather than an explicit `serverInitFull` barrier (`Headless/Init/Init_HC.sqf:11-15` versus `Init_Server.sqf:507`).


## Representative Source Anchors

| Claim | Source anchors |
| --- | --- |
| Mission front door and include graph | `description.ext:39-58` includes `version.sqf`, sound/music headers and the `Rsc` header/style/parameter/resource/dialog/title files. |
| Runtime role dispatch | `initJIPCompatible.sqf:214-238` starts Common, Towns, Server, Client and Headless branches after parameter setup. |
| Common side-presence/defender setup | `Common/Init/Init_Common.sqf:273-287` detects which side logics exist and fills `WFBE_PRESENTSIDES`, then still fixes `WFBE_DEFENDER = resistance`; keep dynamic-defender work routed through the lifecycle/feature owner pages. |
| Server replicated state and loops | `Server/Init/Init_Server.sqf:355-386` seeds side logic state; `:507-538` starts town/victory/resource/collector loops; `:577-620` starts server FPS, PerformanceAudit, AntiStack and player-list follow-up work. |
| Client waits and local runtime surfaces | `Client/Init/Init_Client.sqf:360-388` waits for town/structure/commander state before client FSMs; `:459-509` handles spawn/HQ/CoIn setup; `:773-789` finishes load-in and vote-menu state. |
| Headless timing edge | `Headless/Init/Init_HC.sqf:11-15` uses `sleep 20` before `connected-hc`; it is not an explicit wait on `serverInitFull` from `Server/Init/Init_Server.sqf:507`. |

## Development Philosophy

This mission values runtime performance and live-server stability. Many systems have explicit audit logging, cached UI writes, deferred loops, and optional switches. Documentation and feature work should preserve those patterns instead of reintroducing large per-frame scans or unconditional global broadcasts.

## Continue Reading

Previous: [Quickstart](Quickstart-For-Humans-And-Agents) | Next: [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle)

Main map: [Home](Home) | Source map: [Source inventory](Source-Inventory) | Runtime: [Lifecycle wait-chain](Lifecycle-Wait-Chain)
