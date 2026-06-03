# Agent Worklog

Append entries here so Codex, Claude and future assistants can see what each agent did.

## 2026-06-03 - Codex Documentation Finisher: PVF Dispatch Playbook List / Range Correction

- Closed [Instructions for Codex](Instructions-For-Codex) item 22.
- Source-checked `Common/Init/Init_PublicVariables.sqf`: current `_clientCommandPV` has 15 active entries at `:25-42`, including `HandleParatrooperMarkerCreation`; `DatabaseDebug` remains commented.
- Corrected [PVF dispatch implementation](PVF-Dispatch-Implementation-Playbook) so a reader building an allowlist from the prose would include all active client handlers.
- Corrected current line ranges for PVF wiring and SendTo helpers: `Init_PublicVariables.sqf:44-52`, `Common_SendToServer*.sqf:12-18`, `Common_SendToClient.sqf:13-21` and `Common_SendToClients.sqf:12-19`.
- Source-checked `Client/Module/supplyMission/supplyMissionCompletedMessage.sqf:22` as the `RequestChangeScore` send point.

## 2026-06-03 - Codex Documentation Finisher: Function / Module Index Reaktiv Correction

- Closed [Instructions for Codex](Instructions-For-Codex) item 21.
- Source-checked `Common/Module/Reaktiv`: `Common/Module/Reaktiv/Reaktiv_Init.sqf:5` compiles `WFBE_CO_MOD_Reaktiv_OnDamageReceived`, but `rg` finds no caller outside the Reaktiv folder. `Init_Common.sqf:319-323` initializes ICBM, IRS and CIPHER but not Reaktiv.
- Corrected [Function and module index](Function-And-Module-Index): depot lookup is client-side (`WFBE_CL_FNC_GetClosestDepot` at `Init_Client.sqf:102`), `Common_Set*` describes team move-position/state setters, `Common_Handle*` no longer claims generic damage handling, and `Server_AI_Com_Upgrade.sqf:12` uses `Format ["WFBE_C_UPGRADES_%1_AI_ORDER", _side]`.
- Corrected [Modules atlas](Modules-Atlas) so Reaktiv is described as dormant/unreachable unless deliberately wired back in.

## 2026-06-03 - Codex Documentation Finisher: ICBM Authority Wording Recheck

- Closed [Instructions for Codex](Instructions-For-Codex) item 20 after source and page recheck.
- Corrected the [ICBM authority playbook](ICBM-Authority-Playbook) validation gate so `RequestSpecial` stays documented as a legitimate PVF command only after a future `"ICBM"` server-authority patch; it no longer reads as though live server validation already exists.
- Source evidence remains `Server/Functions/Server_HandleSpecial.sqf:97-111`: the `"ICBM"` case accepts `_side`, `_base`, `_target` and `_playerTeam` from the payload, only guards null/dead `_target`, waits on `_target` death/null and then spawns `NukeDammage` from `_base`.
- Scope remained docs-only; no gameplay source files were edited. Next queue item is [Instructions for Codex](Instructions-For-Codex) item 21: [Function and module index](Function-And-Module-Index) Reaktiv/family-summary drift.

## 2026-06-03 - Codex Documentation Finisher: Sidebar HC Delegation De-Dupe

- Claimed [Instructions for Codex](Instructions-For-Codex) item 11.
- Verified `_Sidebar.md` listed `Headless-Delegation-And-Failover-Playbook` twice: once under Gameplay next to AI/headless and once under Ops.
- Kept the Gameplay entry, because developers following AI/headless delegation source routing will naturally look there first, and removed the Ops duplicate.

## 2026-06-03 - Codex Documentation Finisher: P2 Structure Queue Reconciliation

- Claimed [Instructions for Codex](Instructions-For-Codex) items 12-14 after the sidebar de-duplication batch.
- Checked [Wiki quality audit](Wiki-Quality-Audit) MERGE-1, MERGE-2 and MERGE-3 against the current pages.
- Marked the P2 structure items complete in the queue because the current docs already implement the intended ownership split: roadmap versus server-authority design map, HUD/menus quick-ref versus full UI atlas, and mission entrypoints versus lifecycle wait-chain.
- Scope remained docs-only; no gameplay source files were edited.

## 2026-06-03 - Codex Documentation Finisher: Core / Architecture / Content Citation Uplift

- Closed [Instructions for Codex](Instructions-For-Codex) item 15 by adding representative `path:line` anchors to [Core systems index](Core-Systems-Index), [Architecture overview](Architecture-Overview) and [Content structure and maps](Content-Structure-And-Maps).
- Folded same-page audit fixes into the pass: Core Systems now treats Discord publishing as a separate `DiscordBot/` integration that consumes mission export data, and Architecture now says `initJIPCompatible.sqf` logs max player slots, not live player count.
- Evidence checked: `initJIPCompatible.sqf:26-32,52-56,111-123,214-238`, `description.ext:39-67`, `Common/Init/Init_Common.sqf:217-323`, `Server/Init/Init_Server.sqf:10-57,298,510-531,578`, `Client/Init/Init_Client.sqf:52,958`, `Tools/LoadoutManager/Data/Terrains/BaseTerrain.cs:102,139-145,194-212,246-256`, mission Discord text refs and `DiscordBot/src/*` status updater refs.

## 2026-06-03 - Codex Documentation Finisher: Factory Range / Token Correction

- Closed [Instructions for Codex](Instructions-For-Codex) item 27 in [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas).
- Corrected the depot range split: `updateavailableactions.fsm:39,194` uses `WFBE_C_TOWNS_CAPTURE_RANGE` (40 at `Init_CommonConstants.sqf:323`) for `depotInRange`, while `GUI_Menu_BuyUnits.sqf:217` uses `WFBE_C_TOWNS_PURCHASE_RANGE` (60 at `Init_CommonConstants.sqf:338`) for closest-depot lookup inside the buy menu.
- Reframed DR-33b as still open with exact token evidence: `Init_Common.sqf:164` initializes random `varQueu`; `Client_BuildUnit.sqf:167-172` uses/rerolls it and broadcasts `queu`, with later broadcasts at `:191` and `:207`.

## 2026-06-03 - Codex Documentation Finisher: Progress Dashboard Status-Drift Recheck

- Rechecked [Instructions for Codex](Instructions-For-Codex) item 46 against current source Chernarus and maintained Vanilla Takistan.
- Confirmed the dashboard rows for client skill init idempotency, supply mission scan narrowing and hosted/server FPS loop exits are accurate in the current checkout: both source trees have a single `Skill_Init.sqf` call at `Init_Client.sqf:547`, `WFBE_SK_FNC_Apply` at `:571`, class-filtered supply command-center scans at `supplyMissionStarted.sqf:28`, and non-dedicated early exits at `serverFpsGUI.sqf:1` / `monitorServerFPS.sqf:1`.
- Marked item 46 as a stale false-positive for the Progress Dashboard; Arma smoke remains the runtime gate, but the docs status is not currently misreporting those three source patches.
- Validation passed: `docs/validate-wiki.ps1`, `git diff --check`, JSON/JSONL parsing and docs/wiki-to-wiki mirror parity.

## 2026-06-03 - Codex Documentation Finisher: BattlEye DR-30 OA Filter Correction

- Closed [Instructions for Codex](Instructions-For-Codex) item 18.
- Source-checked the shipped BattlEye footprint: `BattlEyeFilter/publicvariable.txt:1-2` only contains the `kickAFK` rule, and `Client/FSM/updateclient.sqf:153-162` documents the local `publicVariable.txt` deployment beside `server.cfg` and broadcasts `kickAFK`.
- Updated [External integrations](External-Integrations) and [Deep-review findings](Deep-Review-Findings) so Arma 2 OA guidance names the relevant OA-era filter files, treats BattlEye as contingent local-filter defense in depth behind server authority, and does not list `remoteexec.txt` as a missing OA filter.

## 2026-06-03 - Codex Documentation Finisher: Supply PR #1 / Master Scoping Recheck

- Closed [Instructions for Codex](Instructions-For-Codex) item 19 by rechecking [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Current supply heli PR](Current-Work-Supply-Helicopters-PR1) and [Feature status](Feature-Status-Register) against current `master` plus `origin/feat/supply-helicopter`.
- Evidence checked: current `master` has no supply-vehicle `Killed` handler and no `SupplyByHeli`; PR #1 at `ffeea4c2` has `SupplyByHeli`, `WFBE_C_SUPPLY_TRUCK_TYPES` / `WFBE_C_SUPPLY_HELI_TYPES` / `WFBE_C_SUPPLY_VEHICLE_TYPES`, cash-run commander funds, and a guarded interdiction handler at `supplyMissionStarted.sqf:13-30`.
- Corrected stale T2/T3 constant names and stale "stacked handler" wording; the remaining PR gate is repeated load/deliver/destroy smoke plus loaded/tracking/authority cleanup.

## 2026-06-03 - Codex Documentation Finisher: Maintainability Leads Routing

- Closed [Instructions for Codex](Instructions-For-Codex) item 17 by verifying the maintenance leads against source and routing them to existing owner pages instead of filing them as new gameplay defects.
- Evidence checked: legacy short helper names and newer `WFBE_CO_FNC_*` helper names overlap in `Init_Common.sqf:24-63` and `:94-160`; `GetClosestEntity{,2,3,4}` is registered at `Init_Common.sqf:116-119`; support, construction and loadout sibling families are visible in `Client_Support*`, `Construction_*Site` and the ten `Common/Config/Loadout/Loadout_*.sqf` files.
- Added the guidance to [Variable/naming conventions](Variable-And-Naming-Conventions) and [SQF code atlas](SQF-Code-Atlas), including hardcoded English hint examples as localization/UX cleanup notes rather than new broken-feature findings.

## 2026-06-03 - Codex Documentation Finisher: Progress Dashboard At A Glance Refresh

- Claimed [Instructions for Codex](Instructions-For-Codex) item 10.
- Rechecked [Codebase coverage ledger](Codebase-Coverage-Ledger): Map, Perf, JIP/HC and Drift are complete; remaining yellow cells are Auth/PV owner decisions, not open review gaps.
- Updated [Progress dashboard](Progress-Dashboard) At A Glance so Claude is `Autonomous-ready / coverage-follow` and readers are routed to [Pending owner decisions](Pending-Owner-Decisions) for the remaining Auth/PV choices.
- Kept the larger patched-vs-proposed status drift from Instructions item 46 separate for a future dashboard reconciliation pass.

## 2026-06-03 - Codex Documentation Finisher: Coordination Board Current-State Cleanup

- Claimed [Instructions for Codex](Instructions-For-Codex) item 9 and rechecked [Coordination board](Coordination-Board) against `agent-status.json`, `agent-collaboration.json` and [Progress dashboard](Progress-Dashboard).
- Replaced stale active-role wording for old named scout lanes: Faraday, Mencius, Hilbert, Cicero, Curie and Meitner are harvested/closed unless explicitly respawned.
- Marked `victory-endgame-runtime-atlas` integrated, kept `documentation-finisher-loop` as the active Codex docs lane and updated Claude to `collaboration-follow-autonomous-ready` after DR-45+ / DR-46 handoffs.
- Updated the dashboard At A Glance Codex row away from the old DR-46 slice so it points back to this long-running documentation finisher lane.

## 2026-06-03 - Codex Documentation Finisher: C2 Cross-Link Completion

- Claimed [Instructions for Codex](Instructions-For-Codex) item 8 and checked the requested target pages for their DR labels.
- Verified Gameplay already routes DR-6/14/11/22/23/15; AI/headless routes DR-21/42; Construction routes DR-6; Mission entrypoints routes DR-37/43a.
- Source-checked the UI findings against `Rsc/Dialogs.hpp`, `Rsc/Titles.hpp`, `Rsc/Ressources.hpp`, `GUI_Menu_Economy.sqf` and `GUI_Menu.sqf`.
- Added the missing DR labels to [Client UI systems atlas](Client-UI-Systems-Atlas): DR-16 structure sale authority, DR-17 duplicate EASA/Economy dialog IDD, DR-24 stale upgrade dialog, and DR-25a/b title-ID/control-config defects.

## 2026-06-03 - Codex Documentation Finisher: DR-40/DR-19 Citation Routing

- Claimed [Instructions for Codex](Instructions-For-Codex) item 7.
- Source-checked DR-40 against `WASP/global_marking_monitor.sqf:62-72`, `Client/Init/Init_Client.sqf:15,267,573-574` and the dead old WASP bootstrap at `initJIPCompatible.sqf:241-245`.
- Source-checked DR-19 against current source Chernarus and maintained Vanilla Takistan: both `serverFpsGUI.sqf` and `monitorServerFPS.sqf` now have `if (!isDedicated) exitWith {};` at `:1`, while `Init_Server.sqf:578,595` still starts both publisher scripts.
- Routed DR-40 through [WASP overlay](WASP-Overlay), DR-19 through [Server runtime](Server-Gameplay-Runtime-Atlas), and corrected [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep) so its historical pre-patch table is not read as current source.

## 2026-06-03 - Codex Documentation Finisher: DR-45 Town-AI Vehicle Despawn Routing

- Claimed [Instructions for Codex](Instructions-For-Codex) item 6 and source-checked DR-45 against the Chernarus town inactivity cleanup path.
- Verified unsafe vehicle deletion at `Server/FSM/server_town_ai.sqf:211-216`: the guard checks only `isPlayer leader group _x` before `deleteVehicle _x`.
- Verified the separate empty-vehicle timeout is already crew-aware at `Server/Functions/Server_HandleEmptyVehicle.sqf:26-30`, so DR-45 belongs to town inactivity cleanup rather than the normal empty-vehicle handler.
- Routed the DR number and source distinction into [Town AI vehicle despawn safety](Town-AI-Vehicle-Despawn-Safety), [AI/headless](AI-Headless-And-Performance) and [Instructions for Codex](Instructions-For-Codex).

## 2026-06-03 - Codex Documentation Finisher: DR-20 HQ-Killed Routing

- Claimed [Instructions for Codex](Instructions-For-Codex) item 5 and source-checked DR-20 against the Chernarus HQ death path.
- Verified redundant HQ killed detection at `Server/Construction/Construction_HQSite.sqf:36,89,91` and `Client/Init/Init_Client.sqf:499-503`.
- Verified score side effects without a server-side done guard at `Server/Functions/Server_OnHQKilled.sqf:46-50` and `:74-81`.
- Routed the finding into [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas), [Gameplay systems atlas](Gameplay-Systems-Atlas), [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas) and [Instructions for Codex](Instructions-For-Codex).
- Validation passed: `docs/validate-wiki.ps1`, `git diff --check` in both worktrees, JSON/JSONL parsing and SHA256 parity for the changed wiki pages.

## 2026-06-02 - Codex Main Orchestrator: Wave S Spawn

- Corrected the progress dashboard's stale Wave R "running" status after the Wave R harvest was already published.
- Closed the completed Wave R subagent handles to free thread capacity.
- Spawned four read-only Wave S explorers with no docs or source write ownership: Hilbert (`victory-endgame-stat-integrity`), Dirac (`integration-deployment-trust-boundary`), Descartes (`generated-and-modded-drift-reality-check`) and Nash (`arma2-oa-doc-snippet-compatibility`).
- Updated [Discovery swarm](Subagent-Discovery-Swarm), [Progress dashboard](Progress-Dashboard), [`agent-status.json`](agent-status.json), [`agent-collaboration.json`](agent-collaboration.json) and [`agent-events.jsonl`](agent-events.jsonl) so other agents can see the running lanes.

## 2026-06-02 - Codex Main Orchestrator: Wave R Spawn

- Fresh subagent spawn succeeded after the older attached Wave Q IDs returned `not_found`.
- Spawned four read-only explorers with no docs or source write ownership: Ohm (economy/side-supply negative-risk), Godel (town AI/camp/patrol/repair authority), Zeno (factory player-buy path and queue semantics) and Dalton (direct-PV trust-boundary second pass).
- Updated [Discovery swarm](Subagent-Discovery-Swarm), [Progress dashboard](Progress-Dashboard), [`agent-status.json`](agent-status.json), [`agent-collaboration.json`](agent-collaboration.json) and [`agent-events.jsonl`](agent-events.jsonl) so other agents can see the running lanes.

## 2026-06-02 - Codex Main Orchestrator: Wave Q UI Handle Harvest

- Reused the six attached subagents after the thread cap blocked fresh spawns again; each now has a fresh read-only discovery lane and no write ownership.
- Source-checked Curie's Wave Q RHUD/endgame display lead against `Rsc/Titles.hpp`, `Client/Client_UpdateRHUD.sqf`, `Client/GUI/GUI_EndOfGameStats.sqf`, `Client_EndGame.sqf` and `updateavailableactions.fsm`.
- Promoted the confirmed `currentCutDisplay` collision into [Client UI systems atlas](Client-UI-Systems-Atlas), [UI IDD collision repair](UI-IDD-Collision-Repair), [Client UI/HUD](Client-UI-HUD-And-Menus), [Feature status](Feature-Status-Register) and [Source fix queue](Source-Fix-Propagation-Queue).
- Patch-ready shape: split title display handles between OptionsAvailable/RHUD/action icons and EndOfGameStats, or gate RHUD/action-icon recreation during endgame; smoke RHUD/FPS, action icons and endgame stat bars together.

## 2026-06-02 - Codex Main Orchestrator: Wave N Owner-Page Harvest + Sidecar Scouts

- Accepted Steff's explicit note that this tab is now the main LLM orchestrator: Codex owns canonical docs publishing, validation, dashboard/status updates and cross-agent handoffs.
- Reused the six already-attached agents after the subagent thread cap blocked fresh spawns. New read-only sidecar lanes are factories/economy authority, AI/headless cleanup, UI/IDDs/RHUD, server integrations/tooling drift, parameter/include/generated parity and abandoned-feature archaeology.
- Promoted the highest-risk Wave N findings from [Discovery swarm](Subagent-Discovery-Swarm) into owner pages instead of leaving them as raw summaries: [WASP overlay](WASP-Overlay), [join/disconnect lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle), [support/specials atlas](Support-Specials-And-Tactical-Modules-Atlas), [gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [towns/camps/capture atlas](Towns-Camps-And-Capture-Atlas) and [Feature status](Feature-Status-Register).
- Added owner-page evidence for unbounded join/launch ACK retries, RU para-ammo config swallowed by a line comment, missing `airRaid` on stale nuke warning path, profile import six-field bounds, dormant/broken town mortar scaffold, resistance/static-defense scaffolds and WASP action/procInitComm revival traps.

## 2026-06-02 - Codex Main Orchestrator: Assets/Config Atlas + Wave N Returns

- Accepted Steff's direction that this Codex tab is the main LLM orchestrator: Codex owns canonical navigation, mirror validation, progress reporting and publishing; Claude and other Codex tabs should claim bounded deep-review lanes and feed source-backed findings back through shared worklog/events/status files.
- Took the blocked seventh Wave N lane locally and added [Assets/config/localization/parameters atlas](Assets-Config-Localization-And-Parameters-Atlas), covering `description.ext`, `Rsc` includes, parameter export, stringtable, sound/music registries, media counts and missing/stale asset references.
- Recorded the immediate atlas findings: missing `airRaid` sound class used by `NukeIncoming.sqf`, unused support/ICBM message sounds, missing `Client\Images\wf_*.paa` tactical icons, missing relative vehicle texture files and stale commented unit-caching include.
- Confirmed all six Wave N read-only explorers returned. Their reports are now summarized in [Discovery swarm](Subagent-Discovery-Swarm); owner-page promotion remains the next harvest pass.

## 2026-06-02 - Codex Orchestrator Code Discovery Wave N

- Spawned six read-only code discovery explorers for non-overlapping source archaeology: Tesla (WASP overlay), Linnaeus (join/JIP/disconnect), Lorentz (PVF/special router tags), Hubble (gear/loadout/EASA/profile), Banach (support/specials/artillery/ICBM/UAV) and Curie (towns/camps/resistance/static defense).
- The agent thread limit blocked a seventh assets/config/localization/parameters explorer, so that lane remains a good next spawn when capacity frees up.
- Main Codex remains the orchestrator/publisher lane: it should harvest returned reports into owner pages, machine records and the progress dashboard instead of letting raw agent output become the source of truth.

## 2026-06-02 - Codex Depth Agent Harvest: UI, Runtime, Tooling

- Harvested returned high-depth reports from Feynman, Einstein and Epicurus into three owner pages: [Player UI workflow map](Player-UI-Workflow-Map), [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map) and [Tooling release-readiness audit](Tooling-Release-Readiness-Audit).
- Wired the new pages through Home, sidebar/footer navigation, MkDocs and the relevant owner pages for UI, AI/headless and Tools/build.
- Captured the immediate high-risk surfaces: client-authoritative UI actions and duplicate IDDs, AI supply-truck enablement hazards, HC delegation failback gaps, hosted/dedicated FPS loop semantics, LoadoutManager fresh-checkout hazards and integration trust boundaries.
- Left Herschel economy/supply authority and Boole commander/construction/factory/upgrades pending for a later harvest when their reports return.

## 2026-06-02 - Codex Source Inventory Refresh + Depth Agent Team

- Spawned a high-depth read-only discovery team for economy/supply authority, commander/construction/factory/upgrade flow, AI/headless/server runtime, player UI/action surfaces and tooling/integration/release readiness. Agents: Herschel, Boole, Einstein, Feynman and Epicurus.
- Regenerated [Source inventory](Source-Inventory) from `git ls-files` on `docs/developer-wiki-index`: current tracked total is **3432** files, with `docs/` (**110**), `.github` (**2**), `CLAUDE.md`, `mkdocs.yml`, `.md` (**104**), `.json` (**9**), `.jsonl` (**4**) and `.ogg` still **59** in this checkout.
- Added regeneration commands to the page so future agents can refresh top-level and extension counts instead of copying stale audit numbers.
- Rechecked Claude item 45: `git ls-files Tools` returns **199**, while filesystem recursion sees ignored build/bin output. Home and Source Inventory remain anchored to tracked source counts.

## 2026-06-02 - Codex Wave H Agent Team + Supply Player-Object Source Patch

- Spawned Wave H read-only scout agents for supply lifecycle, economy authority, respawn/MHQ/victory, UI/HUD, generated mission drift and PV/networking. The broad PV/networking scout hit context limits, was closed, and was replaced by a smaller direct-public-variable index scout.
- Patched Chernarus source `Server/Module/supplyMission/playerObjectsList.sqf` so `_i = 0` is initialized before the `WFBE_SE_PLAYERLIST` loop; matching reconnect/JIP UIDs now update their actual row instead of index 0.
- Confirmed Vanilla Takistan still has the old loop-index placement, so the fix is source-only until LoadoutManager propagation and Arma 2 OA reconnect/supply smoke run.
- Updated [Source fix propagation queue](Source-Fix-Propagation-Queue), [Join/disconnect lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle), [Feature status](Feature-Status-Register), [Progress dashboard](Progress-Dashboard), [Discovery swarm](Subagent-Discovery-Swarm) and machine ledgers.
- Harvested Darwin's generated-mission drift report: current propagation queue is accurate, LoadoutManager still packages only `Missions` + `Missions_Vanilla`, modded generation is disabled/stale, and the current `work/a` checkout still cannot run generation because it lacks an ancestor folder literally named `a2waspwarfare`.

## 2026-06-02 - Codex Source Fix Propagation Queue

- Source-checked Chernarus source and Vanilla Takistan for the active source-only patch set: paratrooper marker PV registration, client skill init idempotency, hosted server FPS loop exits and supply mission command-center scan narrowing.
- Confirmed Vanilla still lags for those fixes, while `Tools/LoadoutManager/FileManagement/FileManager.cs:140-152` requires a checkout ancestor folder named `a2waspwarfare`, so the current `work/a` checkout cannot run propagation directly.
- Added [Source fix propagation queue](Source-Fix-Propagation-Queue) as the canonical release-readiness ledger for "source patched; generated propagation/smoke pending" work.
- Routed it through Home, sidebar/footer, Tools/build, Feature Status, LLM entry files, MkDocs, `agent-context.json`, `agent-feature-status.jsonl`, `agent-hardening-backlog.jsonl`, dashboard/status/collaboration/events/knowledge.

## 2026-06-02 - Codex Service Menu Affordability Guards

- Source-read `GUI_Menu_Service.sqf` and the four support scripts: `Client_SupportRearm.sqf`, `Client_SupportRefuel.sqf`, `Client_SupportRepair.sqf` and `Client_SupportHeal.sqf`.
- Added [Service menu affordability guards](Service-Menu-Affordability-Guards) as the patch-ready guide for the local service-menu guard gap: cached-price button enables, unconditional rearm/refuel debit, and repair/heal missing fresh funds checks.
- Preserved the authority boundary: support scripts re-check distance/alive/airborne state, but funds are already debited by the menu; this is a local correctness patch, not full gear/EASA/service server authority.
- Routed the finding through [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status](Feature-Status-Register), [Server authority migration map](Server-Authority-Migration-Map), LLM entry files and machine backlog/status records.

## 2026-06-02 - Codex Vehicle Cargo Equip Loop Bounds

- Source-checked the old `Common_EquipVehicle.sqf` loop-bound scout note and confirmed inclusive `0..count(_items)` loops at vehicle weapon, magazine and backpack cargo application.
- Expanded the confirmed finding to `Common_EquipBackpack.sqf`, which uses the same inclusive pattern for backpack weapon and magazine contents.
- Added [Vehicle cargo equip loop bounds](Vehicle-Cargo-Equip-Loop-Bounds) and routed it through [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Feature status](Feature-Status-Register), [Client UI systems atlas](Client-UI-Systems-Atlas), `agent-feature-status.jsonl`, `agent-hardening-backlog.jsonl` and `agent-knowledge.jsonl`.

## 2026-06-02 - Codex Gear Template Profile Filter

- Source-read the buy-gear profile-template path across `GUI_BuyGearMenu.sqf`, `Client_UI_Gear_AddTemplate.sqf`, `Client_UI_Gear_SaveTemplateProfile.sqf`, `Init_ProfileVariables.sqf`, `Init_ProfileGear.sqf` and `Client_UI_Gear_FillTemplates.sqf`.
- Added [Gear template profile filter](Gear-Template-Profile-Filter) as the canonical patch-ready guide for the undefined `_u_upgrade` save-filter bug.
- Routed the finding through [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas), [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status](Feature-Status-Register), `agent-feature-status.jsonl`, `agent-hardening-backlog.jsonl` and `agent-knowledge.jsonl`.

## 2026-06-02 - Codex Arma 2 OA Compatibility Audit

- Audited docs/wiki Markdown and agent files for accidental Arma 3-era references including `remoteExec`, `remoteExecCall`, `BIS_fnc_MP`, `remoteExecutedOwner`, `parseSimpleArray`, `RVExtensionArgs`, `CfgFunctions`, CBA/ACE and Eden Editor wording.
- Added [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) to classify current hits as intentional guardrails, explicit non-options, evidence caveats or terrain/folder-name coincidences.
- Added [`agent-compatibility-audit.json`](agent-compatibility-audit.json) so agents can load the same risky-term classification without scraping prose.
- Wired the audit into Home, sidebar, footer, [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide), [AI assistant guide](AI-Assistant-Developer-Guide), [LLM agent entry pack](LLM-Agent-Entry-Pack), `llms.txt`, `agent-context.json` and MkDocs navigation.

## 2026-06-02 - Codex Wiki-Quality DUP-8 Construction Routing

- Resolved [Wiki quality audit](Wiki-Quality-Audit) DUP-8 by keeping exact construction-authority proof canonical in [Deep-review findings](Deep-Review-Findings) DR-6.
- Clarified [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas) owns the construction runtime map, request-handler map and safe extension checklist, while [Server authority migration map](Server-Authority-Migration-Map) owns migration design.
- Reduced [Gameplay systems atlas](Gameplay-Systems-Atlas), [Feature status](Feature-Status-Register) and [Hardening roadmap](Hardening-Implementation-Roadmap) so they route to the canonical construction pages instead of repeating class-existence evidence.

## 2026-06-02 - Codex Wiki-Quality DUP-7 Supply Cooldown Routing

- Resolved [Wiki quality audit](Wiki-Quality-Audit) DUP-7 by keeping the supply-mission cooldown flow canonical in [Supply mission architecture](Supply-Mission-Architecture) and the exact casing defect evidence canonical in [Deep-review findings](Deep-Review-Findings) DR-18.
- Reduced [Economy, towns and supply](Economy-Towns-And-Supply), [Server runtime atlas](Server-Gameplay-Runtime-Atlas), [Feature status](Feature-Status-Register) and [Hardening roadmap](Hardening-Implementation-Roadmap) so they route to the canonical supply pages.
- Preserved [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) as the implementation-ready patch guide for cooldown casing, loaded/tracking state, dead twin code and PR #1 stacked-handler risk.

## 2026-06-02 - Codex Wiki-Quality DUP-4 Generated Mission Routing

- Resolved [Wiki quality audit](Wiki-Quality-Audit) DUP-4 by making [Tools and build workflow](Tools-And-Build-Workflow) the operational owner for LoadoutManager skip-list, packaging and generated-mission status rules.
- Kept [Deep-review findings](Deep-Review-Findings) DR-4 and DR-32 as the full evidence owner for Chernarus/Takistan drift and modded mission tier analysis.
- Reduced [Content structure and maps](Content-Structure-And-Maps) to folder orientation plus links to Tools/build, DR-4, DR-32 and DR-43a instead of restating the same generated-folder warning.

## 2026-06-02 - Codex Wiki-Quality DUP-6 Lifecycle Routing

- Resolved [Wiki quality audit](Wiki-Quality-Audit) DUP-6 by keeping lifecycle flags, boot ordering, JIP waits and HC wait hazards canonical in [Lifecycle wait-chain](Lifecycle-Wait-Chain).
- Reduced [Server runtime atlas](Server-Gameplay-Runtime-Atlas) so its lifecycle section routes to the wait-chain page and stays focused on long-running `Init_Server.sqf` owners.
- Reduced [SQF code atlas](SQF-Code-Atlas) so `initJIPCompatible.sqf` remains compile/bootstrap orientation rather than another role truth-table copy.

## 2026-06-02 - Codex Wiki-Quality DUP-9 Victory Routing

- Resolved [Wiki quality audit](Wiki-Quality-Audit) DUP-9 by keeping the victory/endgame double-fire mechanism canonical in [Deep-review findings](Deep-Review-Findings) DR-11 and DR-36.
- Reduced [Server runtime atlas](Server-Gameplay-Runtime-Atlas) to a runtime-oriented summary that notes DR-36 found Perf/JIP/HC clean while routing the guard/precedence bug to Deep Review.
- Reduced [Hardening roadmap](Hardening-Implementation-Roadmap) and [Feature status](Feature-Status-Register) so they keep patch priority, impact and validation routing without repeating the full `server_victory_threeway.sqf:23` analysis.

## 2026-06-02 - Codex Wiki-Quality DUP-5 BattlEye Routing

- Resolved [Wiki quality audit](Wiki-Quality-Audit) DUP-5 by making [External integrations](External-Integrations) the canonical shipped BattlEye/server-filter posture page.
- Added a compact evidence table for the in-tree `BattlEyeFilter/publicvariable.txt` AFK rule, the missing broader filter/config bundle and the production `BEpath` owner question.
- Trimmed [Feature status](Feature-Status-Register), [Networking and public variables](Networking-And-Public-Variables), [Hardening roadmap](Hardening-Implementation-Roadmap) and [Server authority map](Server-Authority-Migration-Map) so they route to the canonical posture page instead of repeating DR-30 evidence.

## 2026-06-02 - Codex ICBM Authority Playbook

- Source-read the ICBM/Nuke path across Tactical menu gating, `Client/Module/Nuke/nukeincoming.sqf`, `Server/PVFunctions/RequestSpecial.sqf`, `Server/Functions/Server_HandleSpecial.sqf` and `Client/Module/Nuke/damage.sqf`.
- Added [ICBM authority](ICBM-Authority-Playbook) as the canonical DR-27 implementation playbook for server-side commander/team, side, module/upgrade, funds/cost, impact-anchor and idempotency validation.
- Routed [Hardening roadmap](Hardening-Implementation-Roadmap), [Server authority map](Server-Authority-Migration-Map), [Feature status](Feature-Status-Register), Home/sidebar/footer and [Wiki quality audit](Wiki-Quality-Audit) to the playbook so DUP-3 has one source of implementation detail.

## 2026-06-02 - Codex Wiki-Quality MERGE-1 Authority Routing

- Resolved [Wiki quality audit](Wiki-Quality-Audit) MERGE-1 by splitting ownership between [Hardening implementation roadmap](Hardening-Implementation-Roadmap) and [Server authority migration map](Server-Authority-Migration-Map).
- Made the roadmap the canonical patch-order hub for priorities, branch discipline and validation gates.
- Kept the server-authority map as the reusable design page for authority principles, flow table, handler validation checklist, "do not migrate casually" cautions and validation expectations.
- Reduced duplicate P0/P1 evidence in the roadmap by routing detailed PVF, attack-wave, supply and economy authority guidance to their focused playbooks.

## 2026-06-02 - Codex Wiki-Quality DUP-10 HC Routing

- Resolved [Wiki quality audit](Wiki-Quality-Audit) DUP-10 by making [Headless delegation and failover](Headless-Delegation-And-Failover-Playbook) the canonical implementation playbook for DR-21/DR-42.
- Reduced [AI, headless and performance](AI-Headless-And-Performance) to a concise HC source router for bootstrap, registration, town AI, static defense, disconnect and late-HC source anchors.
- Clarified [Lifecycle wait-chain](Lifecycle-Wait-Chain) owns only HC boot timing and the `Init_HC.sqf` fixed `sleep 20` vs `serverInitFull` wait-chain risk.
- Left future HC code owners a clean split: runtime orientation in AI/headless, boot timing in Lifecycle, update-back/work-record/disconnect policy in the HC playbook.

## 2026-06-02 - Codex Wiki-Quality C3 Gameplay Follow-Ups

- Resolved [Wiki quality audit](Wiki-Quality-Audit) C3 by replacing stale [Gameplay systems atlas](Gameplay-Systems-Atlas) open questions with a source-backed resolved follow-up table.
- Confirmed `wfbe_structures_logic` is created/removed by construction workers and consumed by `Server_HandleBuildingRepair.sqf`.
- Confirmed supply-income stagnation is live when `updateresources.sqf` calls `ChangeSideSupply` with stagnation enabled.
- Clarified that `Init_BaseStructure.sqf` owns local structure/range markers, while buy-menu range globals are initialized in `Init_Client.sqf`, updated by `updateavailableactions.fsm` and consumed by `GUI_Menu*.sqf`.

## 2026-06-02 - Codex Wiki-Quality DUP-11 PV Channel Index

- Resolved [Wiki quality audit](Wiki-Quality-Audit) DUP-11 by making [Public variable channel index](Public-Variable-Channel-Index) the canonical direct public-variable inventory.
- Added missing direct-channel rows to the index from the older Networking tables: server FPS publications, HQ alive/marker broadcasts, AntiStack compensation and no-player stagnation counters.
- Replaced duplicate direct-channel tables in [Networking and public variables](Networking-And-Public-Variables) and [SQF code atlas](SQF-Code-Atlas) with concise cross-links to the index.
- Kept Networking focused on dispatcher mechanics, hardening order, JIP/replay rules and specific authority risks.

## 2026-06-02 - Codex Wiki-Quality MERGE-3 Lifecycle Split

- Resolved [Wiki quality audit](Wiki-Quality-Audit) MERGE-3 by separating page ownership between [Mission entrypoints and lifecycle](Mission-Entrypoints-And-Lifecycle) and [Lifecycle wait-chain](Lifecycle-Wait-Chain).
- Reduced duplicated boot timeline and lifecycle report-verification detail from Mission entrypoints.
- Kept Mission entrypoints focused on `description.ext`, `initJIPCompatible.sqf`, role dispatch, mission-object town init and per-role init responsibilities.
- Made Lifecycle wait-chain the canonical page for boot ordering, global flag dependencies, JIP waits and HC timing caveats.

## 2026-06-02 - Codex Wiki-Quality MERGE-2 UI Quick Reference

- Resolved [Wiki quality audit](Wiki-Quality-Audit) MERGE-2 by reducing [Client UI, HUD and menus](Client-UI-HUD-And-Menus) from a duplicate mini-atlas into a compact quick-reference gateway.
- Kept source anchors for the common UI entrypoints: main menu, buy units, gear/service/EASA, upgrades/economy, RHUD/FPS title resources, respawn selector and marker loops.
- Updated [Client UI systems atlas](Client-UI-Systems-Atlas) to state that it is the canonical implementation map and the HUD/menus page is the quick router.
- Updated [Progress dashboard](Progress-Dashboard), `agent-status.json`, `agent-collaboration.json` and `agent-events.jsonl` for the published lane.

## 2026-06-02 - Codex Wiki-Quality REDUCE-4 Gameplay Gateway Cleanup

- Reduced duplicated economy, construction and factory explanation in [Gameplay systems atlas](Gameplay-Systems-Atlas).
- Added explicit gateway links to [Economy, towns and supply](Economy-Towns-And-Supply), [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas) and [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas).
- Preserved the new path:line anchors from the C6 citation pass while moving detailed mechanics back to the canonical subsystem atlases.
- Marked [Wiki quality audit](Wiki-Quality-Audit) REDUCE-4 resolved and surfaced the lane on [Progress dashboard](Progress-Dashboard).

## 2026-06-02 - Codex Wiki-Quality C6 Gameplay Citation Uplift

- Finished the remaining [Wiki quality audit](Wiki-Quality-Audit) C6 citation gap on [Gameplay systems atlas](Gameplay-Systems-Atlas).
- Added path:line anchors for town initialization, starting mode/patrol flags, town capture/SV/performance loop, town AI activation/delegation/cleanup, resource ticks, commander voting/assignment, upgrade processing, CoIn construction, factory production and attack-wave production.
- Updated [Progress dashboard](Progress-Dashboard), [Wiki quality audit](Wiki-Quality-Audit), `agent-status.json` and `agent-events.jsonl` so C6 now reads as resolved across UI/HUD, AI/headless and Gameplay.
- Preserved Codex-2's active `supply-mission-authority-cleanup-playbook` claim while updating shared status files.

## 2026-06-02 - Codex Markdown Research Report Intake

- Read nine Steff-provided Markdown deep-research reports from `C:\Users\Steff\Downloads\deep-research-report (1).md` through `(9).md`.
- Added sanitized metadata, hashes, sizes and titles to `external-research-report-manifest.json`; raw Markdown report bodies are not mirrored into the wiki or docs branch.
- Added a Markdown intake section to [External research reports](External-Research-Reports), including report scopes, promotion rules and a source-check lead table.
- Source-checked the modded mission/tooling claim against `Tools/LoadoutManager/ZipManager.cs` and `Tools/LoadoutManager/SqfFileGenerators/SqfFileGenerator.cs`; it matches already-documented disabled modded propagation and packaging scope in [Tools/build](Tools-And-Build-Workflow).
- Left the deeper claims as leads only; next high-value follow-ups are a PVF dispatch playbook, headless delegation/failover design review and staged server-side economy ledger design.

## 2026-06-01 - Codex

- Created initial developer wiki structure and `docs/wiki` mirror plan.
- Indexed repository shape, mission subsystems, modules, PVF registration, source mission/generator relationship, tooling, integrations and PR #1 supply helicopter context.
- Documented the clearest broken/deferred feature: autonomous AI supply logistics depends on disabled `UpdateSupplyTruck` and missing `Server/FSM/supplytruck.fsm`.
- Added coordination files for Claude and future agents.
- Added machine-readable `agent-context.json`.

## 2026-06-01 - Codex Deep-Dive Pass 1

- Synced repo/wiki remotes and confirmed PR #2 still only contains the initial docs mirror commit.
- Scanned the Chernarus source mission for `preprocessFile` and `preprocessFileLineNumbers` registrations.
- Added `SQF-Code-Atlas.md` with compile registry counts, init ownership notes, PVF command lists, direct publicVariable channels, disabled compile signals and FSM inventory.
- Recorded the PowerShell `-LiteralPath` rule for the `[55-2hc]` mission folder.
- Added GitHub wiki `_Sidebar.md` persistent navigation so readers can click through pages without returning to the page picker.

## 2026-06-01 - Codex Coordination Pass

- Added `Claude-Long-Term-Goal.md` so Claude has a complementary long-running role: independent reviewer, contradiction hunter and subsystem archaeologist.
- Updated navigation and agent context to distinguish focused Claude review from long-term Claude collaboration.

## 2026-06-01 - Codex Wiki UX Pass

- Reworked `Home.md` into a task-oriented portal for humans, reviewers, implementers and AI assistants.
- Reworked `_Sidebar.md` into shorter persistent navigation grouped by architecture, code, gameplay, operations, current work and Claude.
- Added `_Footer.md` for shared bottom navigation and source-backed documentation rules.
- Added `Quickstart-For-Humans-And-Agents.md` with first-read paths, safe edit checklist, common task routing and agent collaboration roles.

## 2026-06-01 - Codex Gameplay Systems Pass 1

- Read town initialization, town starting modes, town capture/SV loop, town AI activation, resource loop, commander PVFs, upgrade processing, CoIn construction, server construction scripts and factory/unit production paths.
- Added `Gameplay-Systems-Atlas.md` with mermaid system flow diagrams, source ownership notes, risk notes and safe extension points.
- Updated Home, sidebar, quickstart and agent context to route humans and LLMs to the gameplay atlas before core gameplay edits.

## 2026-06-01 - Codex Background Reviewer

- Reviewed the repo read-only for missing docs before publish.
- Requested stronger supply mission architecture coverage, explicit Claude coordination files, expanded partial/disabled feature inventory, external runtime dependency notes and performance-risk notes.
- Flagged PR #1 duplicate `Killed` event-handler risk for repeated supply vehicle reloads.

## 2026-06-01 - Claude Independent Review

- Reviewed Codex wiki against source on `feat/supply-helicopter` using parallel read-only sweeps across lifecycle, PV networking, economy/town/supply, AI/headless/performance, tooling/integrations, WASP overlay and broken-feature inventory.
- Added `Lifecycle-Wait-Chain.md` for role truth table, boot timelines and global flag -> `waitUntil` dependencies.
- Added `WASP-Overlay.md` for the project-specific `WASP/` subtree, live wiring, orphaned actions, base repair, RPG dropping, start vehicles and dead/missing legacy references.
- Sharpened PVF internals: one PV variable per command, client element-0 routing, wrapper-to-engine primitive mapping, second-level `HandleSpecial` and `LocalizeMessage` multiplexers.
- Sharpened AI/headless notes: town AI is spawn/delete distance activation, HC owns units through remote creation, late HC joins can miss delegation after init downgrade and `GetSleepFPS` intentionally shortens sleeps under low FPS.
- Confirmed Supply System 0 plus AI commanders is config-gated latent breakage because `UpdateSupplyTruck` is not compiled but the call site remains live under that configuration.
- Confirmed PR #1 stacks `Killed` event handlers on reused supply vehicles; double payment is currently bounded by `SupplyAmount = 0`, but the handler leak should be fixed.

## 2026-06-01 - Codex UX + Claude Integration Pass

- Integrated Claude's two new pages and targeted findings into the current wiki/docs branch without merging the older branch wholesale.
- Corrected one integration claim after checking source: the economy override in `initJIPCompatible.sqf:151-162` is `WF_Debug`-gated in the current source, not unconditional.
- Reworked wiki navigation for click-through reading: task-oriented Home tours, numbered sidebar start path, footer links to the new deep-dive pages and per-page **Continue Reading** links.
- Updated `agent-context.json` with the new page map, navigation metadata, Claude review pass and sharpened known risks.

## 2026-06-01 - Codex UI Systems Pass 1

- Read `description.ext`, `Rsc/Dialogs.hpp`, `Rsc/Titles.hpp`, `Rsc/Ressources.hpp`, `Client/GUI`, client UI helper compiles, RHUD, respawn selector, marker/action FSMs, CoIn title usage and WASP UI overlays.
- Added `Client-UI-Systems-Atlas.md` with dialog IDD map, title/HUD ownership, main menu router, buy/gear/command/tactical/upgrade/economy/respawn flows, map marker loops, action surfaces, UI asset inventory and safe extension points.
- Flagged UI risks: duplicate `idd = 23000` for EASA/economy, shared title `idd = 10200` for `RscOverlay`/`OptionsAvailable`, polling dialog loops, hot marker loops, respawn selector frequency and economy UI linkage to broken supply-truck work.

## 2026-06-01 - Claude Deep-Review Round 2

- Added `Deep-Review-Findings.md` with source-cited DR-1 through DR-5.
- Confirmed PVF dispatch is a live-server hardening gap: server/client handlers `Call Compile` the sender-chosen command string without validation, while BattlEye filters only contain the `kickAFK` feature rule.
- Confirmed paratrooper drop markers and MASH tent markers are dead receive-side paths.
- Confirmed Chernarus and Takistan are currently in sync except for LoadoutManager skip-list/blacklist differences, while `Modded_Missions/*` are stale or stubbed because modded propagation is commented out.
- Updated feature status, networking, tooling and agent context with round-2 risks.

## 2026-06-01 - Codex Collaboration Protocol Pass

- Added `Agent-Collaboration-Protocol.md` so Codex, Claude and future assistants have explicit claim, handoff, event and stale-branch rules.
- Added `agent-collaboration.json` for machine-readable active lanes and ownership.
- Added `agent-events.jsonl` as an append-only coordination feed for claims, findings, handoffs, completions and sync events.
- Promoted Claude's `Deep-Review-Findings.md` into the mirrored docs set as a first-class review artifact and preserved Claude's ownership-matrix/message-channel proposal.
- Updated Home, sidebar, footer, quickstart, agent context, coordination board, Claude goal pages and `CLAUDE.md` so future Claude/Codex sessions start from the same shared state.

## 2026-06-01 - Codex Construction/CoIn Systems Pass 1

- Read construction entrypoints, `Init_Coin`, `coin_interface`, server request handlers, server construction workers, HQ deploy/mobilize/repair, structure sale, repair-truck CoIn and representative structure config.
- Added `Construction-And-CoIn-Systems-Atlas.md` covering the client CoIn flow, server creation path, structure arrays, HQ lifecycle, repair flows, sale paths, base-area logic and safe extension points.
- Flagged a source-backed hardening gap: construction cost, role and placement checks are mostly client-side while `RequestStructure` / `RequestDefense` do only light class-existence checks before server-side object creation.
- Updated navigation, quickstart, agent context and collaboration state so future gameplay work routes through the construction atlas.

## 2026-06-01 - Codex Claude Autonomy Update

- Expanded `Claude-Long-Term-Goal.md` so Claude can keep working for longer by self-selecting bounded source-backed lanes instead of waiting for Codex to assign every pass.
- Updated `Agent-Collaboration-Protocol.md` and `agent-collaboration.json` to make Claude autonomous for deep reviews, Claude-owned pages, append-only shared files and focused review commits.
- Preserved Codex ownership of broad navigation, mirror parity and primary tour ordering unless Steff explicitly hands those over.

## 2026-06-01 - Claude Deep-Review Round 3 (pvf-hardening-review lane)

- Claimed the `pvf-hardening-review` lane via `agent-collaboration.json` and `agent-events.jsonl`.
- Turned DR-1 into a behavior-preserving implementation playbook in `Deep-Review-Findings.md`.
- Verified that `SRVFNC<cmd>` / `CLTFNC<cmd>` are `missionNamespace` globals, so `Spawn (Call Compile _script)` can become `Spawn (missionNamespace getVariable [_script, {}])`.
- Added optional allow-list and BattlEye filter design notes.
- Scoped the residual risk clearly: this closes arbitrary code execution, but legitimate-command forgery still needs per-handler sender and parameter validation.

## 2026-06-01 - Codex Progress Interface Pass

- Added `Progress-Dashboard.md` as the single human-facing page for current Codex/Claude lanes, event feed links, status legend and update ritual.
- Added `agent-status.json` as a compact machine-readable progress snapshot for agents and external tooling.
- Updated Home, Quickstart, sidebar, footer, Agent Context, Coordination Board and Collaboration Protocol so status checks route through the new dashboard first.

## 2026-06-01 - Claude Deep-Review Round 4 (construction-authority-review lane)

- Took Codex's handoff from the `construction-coin-atlas` lane and concretized the DR-1 command-forgery residual for the build system. New finding **DR-6** in `Deep-Review-Findings.md`.
- Verified at source: `RequestStructure.sqf` and `RequestDefense.sqf` take `_side` (and `_manned`) straight from the client payload and only check that the class exists in the side arrays; `RequestMHQRepair.sqf` is literally `[_this] Spawn MHQRepair;` and `Server_MHQRepair.sqf:3` derives everything from the client `_side`. No commander/funds/dead-HQ/base-area checks — those live only in client CoIn/actions.
- Forgery impact (source-proven, per-handler table in DR-6): a modified client can mint **free** factories, AI-manned defenses/minefields, and HQ repairs for any side, bypassing the economy and base-area `avail` budget.
- Root cause articulated: payloads omit the requesting player, and Arma 2 OA `addPublicVariableEventHandler` exposes no sender identity (`_this = [varName,value]`), so authority must be reconstructed server-side — which is why DR-1's command-name validation does not, by itself, stop forgery.
- Wrote a behavior-preserving validation playbook (add player to payload; server validates side+commander+funds; move base-area `avail` server-side; keep client previews/instant UX). Pairs with DR-1: DR-1 stops arbitrary code, DR-6 stops forged legitimate commands.
- This deepens (does not duplicate) the `Construction-And-CoIn-Systems-Atlas` "Authority Boundary" section. Handoff to code owners; optional cross-link for Codex. `ready-for-review`.

## 2026-06-02 - Claude Self-Authored Long-Term Goal + Coverage Ledger

- Authored a standing long-term goal: drive every subsystem to source-verified comprehension + implementation-hardening until there are no dark corners. Operationalized as **`Codebase-Coverage-Ledger.md`** — a subsystem × dimension (Map/Auth/PV/Perf/JIP-HC/Drift) scoreboard that makes "highest-value next lane" objective (pick the emptiest high-traffic cell).
- Seeded the matrix from current state: boot/PV/construction are deep+hardened; the biggest open cells are Integrations (AntiStack DB extension trust), Factory/purchase authority (blocked on Codex's atlas), UI/HUD adversarial pass, a JIP/HC cross-cut, and victory/endgame+DB-flush.
- Claimed the next lane **`antistack-db-trust`** (external `A2WaspDatabase` DLL boundary, `Server/Module/AntiStack/callDatabase*.sqf`) — deep review to follow next pass.
- **Handoff to Codex (nav is Codex-owned):** please add `Codebase-Coverage-Ledger` to `_Sidebar`/`Home`/`agent-context.json` pages list. Message left in the Coordination Board.

## 2026-06-02 - Claude Deep-Review Round 5 (antistack-db-trust lane)

- First lane executed under the standing Coverage-Ledger goal. Deep-reviewed the AntiStack external DB integration (`Server/Module/AntiStack/callDatabase*.sqf` + the `A2WaspDatabase` DLL, which is NOT in the repo). New findings **DR-7..DR-10** in `Deep-Review-Findings.md`.
- **DR-7 (High):** all seven handlers `call compile` the `callExtension` return — the server executes the external DLL's stdout as SQF. Empty/garbage return → `call compile ""` → `nil select 0` throws. Arma 2 OA has no `parseSimpleArray`, so the fix is defensive shape-validation (guard empty → compile → assert ARRAY of SCALARs → then read), not a parser swap.
- **DR-8 (Med):** blocking DB poll on join/skill path (RETRIEVE ≤12s, REQUEST_SIDE_SKILL ≤27s) — add circuit-breaker. **DR-9 (Med):** SEND_PLAYERLIST packs the whole roster into one `callExtension` call vs A2 OA length limits → truncation → compounds DR-7; chunk it. **DR-10 (Med):** `WFBE_C_ANTISTACK_ENABLED` defaults to 1 (`Init_CommonConstants.sqf:171`) against an absent external DLL → error spam unless disabled; auto-detect the DLL.
- Advanced ledger Integrations row (Auth/PV/Perf/JIP → 🟡; AntiStack covered, Extension/Discord/BattlEye still ⬜). Handoff to code owners (harden the 7 handlers) + Codex (document the external dependency on External-Integrations). `ready-for-review`.

## 2026-06-01 - Codex Factory/Purchase Systems Pass 1

- Read the buy-unit dialog/controller, client action range FSM, client build worker, common unit/vehicle creation helpers, unit metadata cores, factory unit lists, faction filter builder, attack-wave price path and server `AIBuyUnit` worker.
- Added `Factory-And-Purchase-Systems-Atlas.md` with the config chain, player purchase flow, queue model, spawn-pad conventions, common creation behavior, attack-wave/unit-cost modifiers, and implementation checklist.
- Corrected a false assumption in the initial lane scope: no `Server/PVFunctions/RequestBuyUnit.sqf` exists and `RequestBuyUnit` is not registered in `Init_PublicVariables.sqf`; player purchases are client-local.
- Flagged `Server_BuyUnit.sqf` / `AIBuyUnit` as latent/unused unless a dynamic caller is later proven.

## 2026-06-01 - Codex Sub-Agent Fleet Pass 1

- Spawned four read-only sub-agents with disjoint source lanes: Hilbert for network/PV, Cicero for server gameplay loops, Curie for UI/HUD/dialogs and Meitner for tooling/integrations.
- Integrated Hilbert's network findings into [Networking and public variables](Networking-And-Public-Variables), [Feature status](Feature-Status-Register) and `agent-context.json`: direct PV channel table, residual legitimate-command forgery examples and BattlEye filter scope.
- Integrated Cicero's server findings by adding [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas): lifecycle graph, data ownership, load risks, supply mission trust boundary, AI commander caveat and server end conditions.
- Integrated Curie's UI findings into [Client UI systems atlas](Client-UI-Systems-Atlas) and [Feature status](Feature-Status-Register): stale `RscMenu_Upgrade`, duplicate IDDs, suspect `RscClickableText.soundPush[]` and buy-gear partials.
- Integrated Meitner's tooling findings into [Tools/build](Tools-And-Build-Workflow), [External integrations](External-Integrations), [Content/maps](Content-Structure-And-Maps) and `agent-context.json`: LoadoutManager path/7za hazards, generated mission rules, extension-to-Discord JSON flow and stale modded missions.

## 2026-06-02 - Claude Deep-Review Round 6 (victory-endgame-review lane)

- Ledger-driven pick: victory/endgame was fully ⬜ + high-traffic. Reviewed `Server/FSM/server_victory_threeway.sqf` (the ONLY gameOver/failMission setter in `Server/`), `Server_LogGameEnd.sqf`, `PVFunctions/LogGameEnd.sqf`, `Init_CommonConstants.sqf:401`. New findings **DR-11..DR-13**.
- **DR-11 (Med-High, correctness):** the trigger merges a lose-test (`_x` HQ dead + no factories) and a win-test (`_x` holds all towns) into one `if` and handles both identically. `WFBE_CO_FNC_LogGameEnd` (arg = winner) is called with the *opposite* of `_x`, so the persisted `*_WIN_CHERNARUS` profile tally is **inverted for all-towns victories**. `WF_Winner` is a dead write (no reader). `&&` binds before `||`, `!WFBE_GameOver` guards only the towns branch, and the `forEach` has no break → endgame can double-fire.
- **DR-12 (Med, broken feature):** `WFBE_C_VICTORY_THREEWAY` defaults 0; detection gated `if(_victory==0)`; sole victory setter → non-zero (threeway) = matches never auto-end.
- **DR-13 (Low, cleanup):** duplicate `PVFunctions/LogGameEnd.sqf` is buggy (getVariable result used as setVariable key; bare-global `WEST_WIN_CHERNARUS`) — delete to prevent mis-wiring. The clean `Server_LogGameEnd.sqf` is the one wired (Init_Server:64,89).
- Advanced ledger Victory/endgame row. Handoffs to code owners; follow-up review item `WFBE_CL_FNC_EndGame` payload semantics. `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 7 (factory-purchase-authority lane)

- Unblocked by Codex's `Factory-And-Purchase-Systems-Atlas`. New findings **DR-14, DR-15**; also an adversarial cross-check of Cicero's commander-assign candidate.
- **DR-14 (High, architectural):** player purchasing has **no server authority** — `GUI_Menu_BuyUnits.sqf:155-156` spawns `BuildUnit` (client `createVehicle`/`createUnit` in `Client_BuildUnit.sqf`) and deducts client-side; there is no `RequestBuyUnit` PVF. With `wfbe_funds` broadcast-writable, the player economy + unit production are fully client-trusted. This is the **ceiling** on the DR-1/DR-6 hardening thread (WFBE locality model); the only real defense is a BattlEye `scripts.txt` filter, not a PV filter. Documented so future hardening targets the right layer.
- **DR-15 (Med, confirmed):** verified Cicero's candidate end-to-end. `Init_Server.sqf:62` compiles `Server_AssignNewCommander.sqf` as `WFBE_SE_FNC_AssignForCommander`; sole caller `RequestNewCommander.sqf:13` passes `[_side,_commander]`; but `Server_AssignNewCommander.sqf:3` does `_side = _this` (the whole array) → `GetSideLogic` fails → AI-commander-stop block mis-fires. Fix: `_side = _this select 0`. Plus a redundant `new-commander-assigned` broadcast.
- Advanced ledger Factory/purchase row (Map ✅ from Codex atlas; Auth/PV 🟡). Handoffs to code owners. `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 8 (ui-hud-authority-review lane)

- New findings **DR-16, DR-17**. Completes the economy authority picture and cross-checks Curie's UI candidates.
- **DR-16 (High):** `GUI_Menu_Economy.sqf:104-152` structure sale is fully client-authoritative — client-side commander check, client refund (`ChangeSideSupply`/`ChangePlayerFunds`), and `_closest setDammage 1` destruction on the client; no server PVF. So **build (DR-6), buy (DR-14), and sell (DR-16) are all client-authoritative** — the WFBE economy has no server enforcement; BattlEye `scripts.txt` is the only practical anti-cheat layer short of a server-PVF redesign.
- **DR-17 (Low-Med, confirms Curie):** `RscMenu_EASA` and `RscMenu_Economy` both `idd = 23000` (`Rsc/Dialogs.hpp:3211, :3289`) → `findDisplay 23000` ambiguous. Assign distinct IDDs.
- Advanced ledger UI/HUD row (Auth/PV 🟡). Remaining UI follow-ups (Curie): title IDD 10200, stale `RscMenu_Upgrade`, `RscClickableText.soundPush[]`. `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 9 (server-loop-candidates-verify lane)

- Adversarially verified two Cicero candidates at source; both **confirmed** with exact impact. New findings **DR-18, DR-19**.
- **DR-18 (Med):** supply-cooldown key casing mismatch — `Init_Town.sqf:35` seeds `"lastSupplyMissionRun"` (lowercase) but supply logic uses `"LastSupplyMissionRun"` (capital). `setVariable` keys are case-sensitive in A2 OA, so the `0` seed is dead and the key is nil on first check → `isSupplyMissionActiveInTown.sqf:11` `nil + interval` throws, defeating the `!= 0` guard. Fix: align casing or `getVariable ["LastSupplyMissionRun", 0]`.
- **DR-19 (Med, non-dedicated):** `serverFpsGUI.sqf` + `monitorServerFPS.sqf` put `sleep 8` inside `if (isDedicated)`, so on a hosted/listen server `while {true}` busy-loops (two of them). Fix: hoist the sleep / early-exit when not dedicated; also two redundant FPS publishers (`SERVER_FPS_GUI`/`WFBE_VAR_SERVER_FPS`).
- Advanced ledger Supply JIP/HC. Handoffs to code owners (both one-liners). `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 10 (jip-headless-crosscut lane)

- Traced HQ-death detection end-to-end across server / existing clients / JIP. New finding **DR-20**.
- **DR-20 (High, multiplayer correctness / score exploit):** the HQ `Killed` EH is registered on **every owning-side client** (`set-hq-killed-eh` broadcast from `Construction_HQSite.sqf:91` / `Server_MHQRepair.sqf:43` + the JIP path `Init_Client.sqf:500-503`), but `Server_OnHQKilled.sqf` has **no idempotency guard** → on mobile-HQ death the server runs it once per owning-side client: ~2N× killer score award + N× messages. Fix: per-HQ "processed" flag in `OnHQKilled` (detect redundantly, act once). Keep the redundant EH registration.
- Verified JIP detection itself is correct (the `!_isDeployed` guard at `Init_Client.sqf:500`; deployed HQ covered by the server-side EH). The defect is downstream duplication, not a JIP miss.
- Advanced ledger JIP/HC cells (economy/construction). Remaining JIP/HC: attack-wave sync, marker re-init, headless orphan-on-disconnect. `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 11 (headless-disconnect-review lane)

- Verified the round-1 HC-disconnect hypothesis at `Server_OnPlayerDisconnected.sqf`. New finding **DR-21** + a **self-correction**.
- **Correction:** round-1's "HC disconnect orphans units" is wrong — Arma 2 OA migrates a disconnecting machine's local units/groups to the **server** (ownership transfer, no loss). Logged the downgrade explicitly rather than dropping it.
- **DR-21 (Med, perf/operational):** HC delegation has **no failover** — on HC disconnect the offloaded AI lands back on the server (load spike), the disconnect handler does no re-delegation, and `WFBE_C_AI_DELEGATION` is only evaluated at boot (a reconnecting HC doesn't resume offload). Suggest `setGroupOwner`-based rebalancing on HC connect/disconnect (the mission currently never uses `setGroupOwner`).
- Advanced ledger AI/Headless JIP/HC cell. `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 12 (side-supply-delta-verify lane)

- Confirmed + sharpened Faraday's "negative side-supply delta" candidate (and my round-1 inverted-guard note). New finding **DR-22**.
- **DR-22 (High, economy exploit):** the supply clamp `if (_change < 0) then {_change = _currentSupply - _amount}` is a broken floor — `_amount` is signed (deductions negative), so overspending yields `_currentSupply + |amount|` (spend 300 from 100 → 400). Live in `Server/Functions/Server_ChangeSideSupply.sqf` (both west/east handlers); the identical block in `Common_ChangeSideSupply.sqf` is **dead** (PV carries `_amount`; server recomputes). Fix: `{_change = 0}`. Resistance-side handler still missing (round-1).
- Advanced ledger Economy Auth/PV (confirmed exploit). `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 13 (upgrade-authority-verify lane)

- Confirmed Faraday's "upgrade authority gap" and closed the economy-authority thread. New finding **DR-23**.
- **DR-23 (High):** `RequestUpgrade.sqf` = `_this Spawn WFBE_SE_FNC_ProcessUpgrade` (raw payload, no validation); `Server_ProcessUpgrade.sqf` does no commander/funds/sequence/dependency check and **never deducts cost** (client-side only). Forge free upgrades for any side; client-controlled `select _upgrade_id select _upgrade_level` → out-of-range error. Fix: validate + server-side cost.
- **Synthesis:** with DR-6/14/16/22/23, the **entire WFBE economy is client-authoritative** (build/buy/sell/supply/upgrade). One architectural owner decision (server-PVF validation vs BattlEye `scripts.txt`) covers the class — piecemeal fixes won't.
- Ledger Economy authority characterized across the board. `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 14 (missing-reference-inventory lane)

- Confirmed Curie's dead-dialog candidate. New finding **DR-24 (Low)**: `RscMenu_Upgrade` (`Rsc/Dialogs.hpp:2425`) `onLoad` ExecVMs `Client/GUI/GUI_Menu_Upgrade.sqf` which **doesn't exist** (only `GUI_UpgradeMenu.sqf` does); the dialog is never opened; the live upgrade UI is `GUI_UpgradeMenu.sqf`. Dead/naming-drift reference — inert today. Fix: delete or repoint.
- Tried an automated "live reference → missing file" scan; its Windows backslash path-normalization was unreliable (false positives), so I confirmed by hand and **handed a reliable missing-reference scanner to Codex/tooling** as a future task.
- Severity gradient note: the campaign is now in the long tail (Low/cleanup findings), a sign the high-traffic Auth/PV/JIP cells are largely reviewed. Open abandoned-code candidates remain (TaskSystem, blink loops, WASP OnArmor/KeyDown — see WASP-Overlay + Feature-Status).

## 2026-06-02 - Claude Deep-Review Round 15 (ui-followups-verify lane)

- Confirmed Curie's last two UI candidates; closed the UI follow-up items. New findings **DR-25a/b (both Low)**.
- **DR-25a:** `RscOverlay` (`Titles.hpp:46`) and `OptionsAvailable` (`:165`) share `idd=10200` (title-resource dup; sibling of DR-17). Assign distinct IDDs.
- **DR-25b:** `RscClickableText.soundPush[] = {, 0.2, 1}` (`Ressources.hpp:556`) is malformed (empty leading element; correct form `{"", 0.2, 1}` as at `:92`); base class so it propagates. Fix the array.
- Ledger UI candidates closed. `ready-for-review`.

## 2026-06-01 - Codex External PDF Research Intake

- Steff provided three Dutch deep-research PDFs and also handed them to Claude: `Analytisch rapport over rayswaynl_a2waspwarfare.pdf`, `Analyse van rayswaynl_a2waspwarfare.pdf` and `Diepgaande analyse van rayswaynl_a2waspwarfare.pdf`.
- Spawned three cheap read-only PDF scouts: Sagan, Helmholtz and Parfit. Each produced a compact digest with all claims marked `EXTERNAL_PDF_UNVERIFIED`.
- Added [External research reports](External-Research-Reports) as the intake ledger. It separates claims already source-backed by the wiki from leads that still need repo verification before promotion.
- Claude's later Round 16 cross-check found the PDFs are mostly downstream of the wiki/upstream proxy, making them corroboration rather than independent source verification.

## 2026-06-02 - Claude Deep-Review Round 16 (external-research-integration lane)

- Integrated Steff's 3 deep-research PDFs (also sent to Codex). Read two in full; all are the same genre. **Provenance:** their citations are `raw.githubusercontent.com/wiki/rayswaynl/...` — generated FROM our wiki (+ Miksuu upstream proxy), so **downstream corroboration**, not independent source verification.
- They re-derive our spine (DR-1 call compile, DR-6 construction authority, DR-7 callExtension, UpdateSupplyTruck latent breakage, despawn player-vehicle risk, PR#1 EH leak, MASH broken) and recommend our fixes. **Our source-verified findings are a superset** (reports lack DR-11/15/18/19/20/22/23). Good external validation; nothing higher-severity missed in code.
- **DR-26 (Low, governance):** resolved the reports' "license unspecified" — `LICENSE.md` is a **custom proprietary-style license** (Spayker 2016 / Miksuu 2025; contributions assigned to owner; reuse restricted), NOT OSI → source-available, not open-source.
- Confirmed governance/ops asks at source (handoff to Codex/owners): `DiscordBot/preferences_sample.json` ships a real `GuildID` + hardcoded `DataSourcePath`; no CI (only `FUNDING.yml`). MASH Working/broken wiki contradiction the reports flagged was **already fixed by Codex**.
- `ready-for-review`.

## 2026-06-02 - Claude Deep-Review Round 17 (weather-daynight-review lane)

- Reviewed `Server_DayNightCycle.sqf` + client receiver/animation (`initJIPCompatible.sqf:174-210`, `Client_DayNightCycle.sqf`). **Clean review — no defect.** Recorded the negative result so it isn't re-reviewed (Round 17 in Deep-Review-Findings).
- Verified: no divide-by-zero (twilight weight is the non-zero constant 3; day-duration param min is 1); JIP covered via engine-synced `WFBE_DAYNIGHT_DATE` + init `setDate`; server-authoritative clock + per-machine local animation + 30 s absolute-date drift sync is coherent (consistent with `skipTime`/`setDate` being local-effect in A2 OA).
- Ledger weather/day-night cell → **reviewed-clean**. Integrity note: not manufacturing a finding where the code is correct is as important as finding bugs.

## 2026-06-02 - Claude Deep-Review Round 18 (modules-review lane) — DR-27 CRITICAL

- Reviewed the `Client/Module/` + `Server/Module/` set. Most modules are config-gated (`WFBE_C_MODULE_*`) cosmetic/QoL; the UAV `_button == 007` branch is `comment 'DISABLED'` in both `uav_interface.sqf:226` and `uav_interface_oa.sqf:100` (confirms Feature-Status "UAV partial").
- **DR-27 (Critical, network authority):** the ICBM/Nuke module is **fully client-authoritative**. Commander's Tactical-menu strike (`GUI_Menu_Tactical.sqf` MenuAction==8) runs entirely client-side, then `Client/Module/Nuke/nukeincoming.sqf:23` sends `["RequestSpecial",["ICBM",side,baseObj,cruiseObj,team]]`. `Server/PVFunctions/RequestSpecial.sqf` is `_this Spawn HandleSpecial;` → `Server/Functions/Server_HandleSpecial.sqf:97-112` spawns `NukeDammage` at the **client-supplied position** with **no** upgrade/commander/funds validation. The `waitUntil {!alive _target}` is timing-only, not a guard. One forged publicVariable = a server-applied, map-wide mass-kill. This is the apex of the client-authoritative class (DR-6/14/16/22/23) with match-wide blast radius.
- Ledger Modules cell → Map ✅, Auth/PV/Perf/JIP-HC 🟡 (DR-27). Handoff to Codex: add DR-27 to the Networking PVF-hazard table + a Nuke-module Feature-Status note; the fix is the shared economy-authority owner decision (server-side authority in the `"ICBM"` case + BattlEye `RequestSpecial` restriction), prioritised above the wallet exploits.

## 2026-06-02 - Claude Deep-Review Round 19 (gear-easa-review lane) — DR-28, economy class complete

- Reviewed EASA aircraft-loadout module (`Client/Module/EASA/`, `GUI_Menu_EASA.sqf`) + vehicle Service point (`GUI_Menu_Service.sqf`).
- **DR-28 (High):** gear/EASA loadouts and vehicle rearm/repair/refuel/heal are **client-authoritative**. No server PVF anywhere in the flow; EASA cost is a client-side `if (_funds > price)` honor check + `ChangePlayerFunds` (`GUI_Menu_EASA.sqf:46-50`); `EASA_Equip` applies `addWeapon/addMagazine` locally and broadcasts only the setup index. Service **rearm** (`:196-200`) and **refuel** (`:217-219`) deduct *unconditionally* — no affordability guard, unlike repair/heal.
- **Class now complete:** every WFBE spend path is source-confirmed client-authoritative — build (DR-6), buy (DR-14), sell (DR-16), supply (DR-22), upgrade (DR-23), ICBM (DR-27), gear/rearm (DR-28). One owner decision (server funds ledger vs BattlEye) covers all of them.
- Ledger: Gear/EASA row Auth → ✅ (characterized); Economy row note extended. Handoff to Codex: fold DR-28 into Economy page + gear atlas; minor parity fix = add `if(_funds>=price)` to Service rearm/refuel.

## 2026-06-02 - Claude Deep-Review Round 20 (extension-globalgamestats-review lane) — DR-29

- Reviewed the in-repo .NET `callExtension` DLL (`Extension/src/**`) + sole SQF caller (`Server/CallExtensions/GlobalGameStats.sqf`). Second extension trust boundary, distinct from the AntiStack `A2WaspDatabase` DLL (DR-7..DR-10, not in repo).
- **DR-29 (Medium, latent Critical):** GLOBALGAMESTATS is a one-way telemetry exporter and is **safe today** — `RvExtension._output` is never written and the SQF call discards the return (`GlobalGameStats.sqf:22`, bare statement), so nothing is `call compile`d from it (the safe contrast to DR-7); reflection is enum-gated. **But:** (2) a dormant **deserialization-RCE landmine** — the commented load path (`SerializationManager.cs:115-120`) uses `TypeNameHandling.Auto` + `JsonConvert.DeserializeObject` (Newtonsoft `$type` gadget), Critical if re-enabled (and a load path is required for real persistence); (3) **write-only/abandoned-refactor stub** — no cross-restart persistence, load path commented + references a different type graph (`Database` vs live `GameData`), stale `new string[2]` + `Todo` comments; (4) **`async void` race** — `SerializeDB` calls the also-`async void` file-create unawaited then `File.Replace` → first-run `FileNotFound`, and `async void` exceptions can crash the .NET host; (5) minor SQF `abs(playerCount-1)` HC heuristic misreports player count.
- Ledger Integrations row: Extension sub-target reviewed (AntiStack DB + Extension both done; Discord + BattlEye remain ⬜). Handoff to Codex: document GLOBALGAMESTATS in External-Integrations as a one-way, output-discarded exporter (explicitly NOT an RCE-into-SQF path); 3 code-owner asks (delete/harden dead deser path, fix async-void `File.Replace` race, fix `abs(playerCount-1)` + stale comments).

## 2026-06-02 - Claude Deep-Review Round 21 (battleye-posture-review lane) — DR-30, campaign-wide

- Source-verified the repo's entire BattlEye footprint to close the loop on the "rely on BattlEye" option offered in 8 prior findings (DR-1 + DR-6/14/16/22/23/27/28).
- **DR-30 (High):** the BattlEye mitigation is **not shipped**. The only BE filter in the repo is `BattlEyeFilter/publicvariable.txt` — **22 bytes**, one rule `5 "kickAFK"` which is the AFK-kick *feature* plumbing, not a security control. No default-deny catch-all → no restriction on any forgery-class PV (`RequestSpecial`/ICBM DR-27, `RequestStructure` DR-6, `RequestUpgrade` DR-23, `HandlePVF` DR-1). **`scripts.txt` is absent** (plus A2/OA-relevant filters such as createvehicle/setvariable/setpos/setdamage/deletevehicle/mpeventhandler/cargo filters) → nothing in-repo blunts the DR-1 `call compile` RCE. A 716 KB README `.docx` exists but was not parsed (binary/untrusted-content rule).
- **Implication:** option (b) "rely on BattlEye" across the whole economy/forgery class is illusory as-shipped; realistic remediation collapses to **(a) server-side authority in SQF**. Honest caveat documented: BE filters normally live in the server `BEpath` outside the mission PBO, so production posture is an explicit owner question — the repo (source of truth) ships only the stub.
- Confirms the Codex `Gibbs` scout's high-level report at source; corroborates the accurate, non-overclaiming wiki text already in place (`External-Integrations.md:60`, `Feature-Status-Register.md:32`, `Networking-And-Public-Variables.md:122`).
- Ledger Integrations row: BattlEye sub-target done (AntiStack DB + Extension + BattlEye all reviewed; only **Discord data path** remains ⬜). Handoff to Codex: one-line cross-link to the DR-1 playbook + External-Integrations noting option (b) requires building the filter set; pose the production-BE-config question to the owner; bundle `scripts.txt`/`server.cfg`/`basic.cfg` absences into a hosting-hardening owner item.

## 2026-06-02 - Claude Deep-Review Round 22 (discord-datapath-review lane) — DR-31, Integrations row complete

- Reviewed the in-repo `DiscordBot/` (.NET / Discord.Net) — the consumer of GLOBALGAMESTATS `database.json`, closing the last Integrations sub-target. Data path: Arma server → extension writes `database.json` (DR-29) → bot reads on a 60 s timer → status embed.
- **DR-31 (High, insecure deserialization):** `GameData.LoadFromFile()` (`GameData.cs:49-56`) deserializes `database.json` with **`TypeNameHandling.All`** — the Newtonsoft `$type` gadget sink, worse than the dormant `.Auto` flagged in DR-29. Run **every 60 s** by `GameStatusUpdater` (`:9,19-22,84`) + at startup (`ProgramRuntime.cs:15`) + on a command (`CommandHandler.cs:211`), no interaction. Capability is gratuitous (data is a flat `string[] exportedArgs` DTO; the writer uses `.None`). Not remotely exploitable as-configured (file written by the trusted local extension), but any write-primitive to `C:/a2waspwarfare/Data/database.json` = **RCE in the token-holding bot process**. Trivial fix: `.All → .None` + delete the dead `.Auto` method (`GameDataDeSerialization.cs:32`, no callers). Closes DR-29 #2 end-to-end.
- **Secondary (Low):** secret hygiene is **good** — `.gitignore` excludes `token.txt` + `preferences.json`; `preferences_sample.json` is tokenless (resolves the external reports' "Discord sample hygiene" item; minor: sample commits a real `GuildID`/`AuthorizedUserID` snowflake — IDs, not secrets). Inbound commands are auth-gated (`IsUserAuthorized`, `CommandHandler.cs:49,127`). Three-way `exportedArgs` shape drift (ext `[2]` / bot `[4]` / SQF sends 5) — benign but document the canonical 5-field layout.
- Ledger Integrations row: **all four sub-targets done (AntiStack DB, Extension, BattlEye, Discord) → Map ✅.** Handoff to Codex: document the Discord data path in External-Integrations; the one actionable code-owner item is `TypeNameHandling.All → None`; cross-link DR-29/DR-31.
- Note: hit the recurring Bash-heredoc backslash-collapsing trap writing the Windows path into a JSONL event; repaired the one malformed line via a Write-tool Python script (forward slashes) and re-validated. Lesson reinforced: author any script containing Windows paths via the Write tool, not a Bash heredoc.

## 2026-06-02 - Codex PV/External Integration Batch A

- Integrated Archimedes/James/Galileo PV findings into [Networking and public variables](Networking-And-Public-Variables), adding a second-pass direct-channel inventory for attack waves, side supply, supply missions, MASH markers, HQ state, AntiStack compensation, server FPS, AFK, day/night and marker/message channels.
- Clarified that a `WFBE_PVF_*` dispatcher fix or whitelist does not harden direct publicVariable channels; BattlEye `publicvariable.txt` must cover both registered PVF commands and explicit direct channels.
- Integrated Faraday/Claude external-integration findings into [External integrations](External-Integrations): Discord sample/config hygiene, the in-repo `a2waspwarfare_Extension` vs absent out-of-repo `A2WaspDatabase`, async file export behavior, custom/source-available license and missing CI/reference validation.
- Folded Claude DR-27 into [Networking and public variables](Networking-And-Public-Variables) and [Feature status](Feature-Status-Register): `RequestSpecial` / `"ICBM"` is the highest-priority registered-command hardening target because a forged PV can create a server-applied map-wide nuke.
- Folded Claude DR-28 into [Economy](Economy-Towns-And-Supply), [Gear/loadout/EASA](Gear-Loadout-And-EASA-Atlas) and [Feature status](Feature-Status-Register): gear/EASA/service authority is now the final confirmed spend path in the client-authoritative economy class.
- Added matching entries to `agent-status.json`, `agent-collaboration.json`, `agent-context.json` and `agent-events.jsonl`.

## 2026-06-02 - Codex Cheap Explorer Wave C

- Spawned six read-only explorers for the next integration batch: Newton (broken references), Linnaeus (supply mission authority), Ampere (server runtime/FSM), Pascal (boot/include graph), Boyle (AI commander/autonomy) and Peirce (hosting/BattlEye).
- Reports received so far confirm latent AI supply truck breakage, broken MASH marker listener registration, stale upgrade dialog reference, missing `server.cfg`/`basic.cfg`/`scripts.txt` bundle, duplicate/hosted server FPS risk, partial AI commander autonomy and a missing root `version.sqf` boot dependency.
- These scout reports are queued for the next source-backed integration pass; they are not yet all promoted into owner pages.
## 2026-06-02 - Claude Deep-Review Round 23 (generated-mission-drift-review lane) — DR-32, Drift characterized campaign-wide

- Cross-cutting Drift pass: file-set (`comm`) + byte-level (`cmp`) comparison of the Chernarus source mission against all 8 generated missions (1 vanilla + 7 modded).
- **DR-32 (Medium, drift + abandoned-code), three tiers:**
  - **Vanilla Takistan = faithful regeneration.** 15/671 `.sqf` differ, all map-config (per-faction `Core_Artillery/*`, `Init_Server.sqf` sole diff = `SET_MAP 1→2`, help, start vehicles) + textures; **all logic byte-identical** → every DR-1..DR-31 finding propagates verbatim to vanilla; source fix + regen corrects both.
  - **Napf/eden/lingor = divergent hand-edited forks.** 104–123 logic files differ from source, incl. `Server_HandlePVF`, `Server_HandleSpecial`, `server_victory_threeway`, `Server_ProcessUpgrade`, `Server_OnHQKilled`, `Init_PublicVariables`, `initJIPCompatible`. Hand-customized behavior (Napf's ICBM additionally spawns 3× `BO_GBU12_LGB`). Not regenerated (DR-4: modded propagation commented at `SqfFileGenerator.cs:132`) → source fixes do NOT reach them; vuln classes persist with different lines.
  - **sahrani/dingor/tavi/isladuala = abandoned stubs.** 1–20 files each (a real mission ≈ 786 files / 671 `.sqf`); missing `Server/`, `mission.sqm`, `WASP/`, most logic → non-runnable scaffolds.
- Ledger: Drift cells for Construction/UI/Modules → done; added a global "Drift dimension — campaign-wide result (DR-32)" note below the matrix. Owner decisions: complete-or-delete the 4 stubs; pick a maintenance model for the 3 forks (regenerate from hardened source vs maintain-as-forks); apply DR fixes to source first then deliberately propagate. Handoff to Codex: add a generated-mission status table to Tools-And-Build-Workflow (its lane).

## 2026-06-02 - Claude Deep-Review Round 24 (factory-perf-jip-review lane) — DR-33

- Filled the two ⬜ cells on the Factory/purchase row by reviewing the production path: `GUI_Menu_BuyUnits.sqf` (queue gate) → `Spawn BuildUnit` → `Client_BuildUnit.sqf` (production loop) + `WFBE_C_QUEUE_*` counters in `Init_Client.sqf`. Production runs entirely on the **buyer's client**.
- **DR-33a (Medium, JIP/HC / client-state leak):** `WFBE_C_QUEUE_<type>` is a client-local counter (cap e.g. Light/Heavy=5) incremented at the buy gate (`GUI_Menu_BuyUnits.sqf:145-146`) and decremented at the script tail (`Client_BuildUnit.sqf:469`). The **empty-vehicle** path `if (!_driver && !_gunner && !_commander) exitWith {}` (`:365`) returns before the decrement → each crewless-vehicle buy permanently leaks the counter; after `_MAX` such buys the gate silently soft-locks that factory type for the rest of the match. Reachable in normal play. Fix: decrement on all exit paths.
- **DR-33b (Low/Medium, Perf):** per-unit `while {…} { sleep 4; … }` poll re-broadcasts the building's `queu` array via `setVariable [...,true]` on every enqueue/advance/complete (`:172/:191/:207`) → network churn proportional to queue activity. `varQueu = random(10)+random(100)+random(1000)` (`:168`) is **not unique** → front-of-queue collision risk. Buyer-disconnect orphans the broadcast `queu` token (self-heals only via another buyer's `_ret>_longest` cleanup). Fixes: unique token + reduce broadcast.
- Ledger Factory/purchase row: Perf + JIP/HC cells filled (DR-33). Remaining 🟡 Auth/PV = DR-14 client-authoritative-purchase ceiling (economy class). Handoff to Codex: document the production queue model in the Factory atlas. Both fixes propagate to vanilla Takistan verbatim (DR-32).

## 2026-06-02 - Claude Deep-Review Round 25 (respawn-mash-review lane) — DR-34

- Reviewed the respawn UI (`Client_UI_Respawn_Selector.sqf`) + MASH respawn-marker chain (`Server/Module/MASH/MASHMarker.sqf` ↔ `Client/Module/MASH/receiverMASHmarker.sqf`); resolved the DR-2 MASH dead-path note to a full both-ends diagnosis.
- **DR-34 (Low/Medium, broken/abandoned feature):** the MASH **map-marker** feature is dead on both ends — (1) client receiver commented out (`Init_Client.sqf:132`), (2) trigger PV `WFBE_CL_MASH_MARKER_CREATED` never broadcast by any client (only the server PVEH references it), (3) server handler `WFBE_SE_FNC_MASH_MARKER` live at `Init_Server.sqf:70` but **orphaned** (listens for a never-sent PV). MASH tents are a real officer feature (`Officer_Undeploy_MASH.sqf`) but produce **no map markers**. Confirms + extends DR-2.
- **Latent JIP gap if revived:** marker delivered by `publicVariable "WFBE_SE_MASH_MARKER_SENT"` — single overwritten global, not JIP-replayed/not a list → joiners miss prior MASH; only the last is carried. Revival recipe: server-held list + JIP re-send (like the construction `set-hq-killed` re-sends) + unique names.
- **Secondary (Low):** respawn selector is a ~33 Hz `sleep 0.03` **local** marker-animation loop while the respawn UI is open (network-free, bounded). MASH marker name uses `round random 50000` (non-unique, DR-33b class) and `deleteMarker` on a `createMarkerLocal` marker (local/global mismatch) — moot while disabled.
- Ledger Markers/cleaners row: PV + JIP/HC cells reviewed (DR-34). Handoff to Codex: mark MASH map-marker dead/abandoned in Feature-Status + marker docs; owner decision = revive or remove the dead receiver + orphaned server registration.

## 2026-06-02 - Claude Deep-Review Round 26 (params-localization-review lane) — DR-35 (reviewed clean)

- Reviewed the two never-covered cross-cutting areas: localization integrity + the mission parameters system.
- **Localization: clean.** 204 static `localize` keys; a case-sensitive diff flags 4 "missing", but Arma stringtable lookup is **case-insensitive** — after case-folding (drops `STR_WF_UPGRADE_uav_Desc` = defined `..._UAV_DESC`) and liveness-checking, the survivors are 1 engine-provided (`STR_EP1_UAV_action_exit`) and 2 in **commented-out** WASP code (`STR_WASP_actions_OnArmor`, `STR_WF_Gear` at `AddActions.sqf:4,10-12`). **No live broken-string bug.** Config-side `$STR_` all resolve. ~1085 stringtable keys are unused legacy (normal).
- **Parameters: live + correctly wired.** `Init_Parameters.sqf` (MP `paramsArray select _i` / SP `default`) ← `initJIPCompatible.sqf:121`; display dialog via `Rsc/Dialogs.hpp:3136` + `Rsc/Parameters.hpp`. Fragility note (not a defect): `paramsArray` is index-aligned to `class Params` order — keep order stable when editing.
- **Abandoned-code:** WASP `OnArmor` (ride-on-tank) + `GearYourUnit` actions are commented out in `AddActions.sqf` (confirms the earlier WASP-OnArmor suspicion).
- New ledger row **Parameters / localization → reviewed-clean (DR-35)**. Handoff to Codex: optionally note the dead WASP actions in WASP-Overlay + a keep-`class Params`-order caution in params docs. Method note for future passes: case-fold + liveness-check before reporting missing-key findings, or you generate false positives.

## 2026-06-02 - Claude Deep-Review Round 27 (victory-perf-jip-review lane) — DR-36

- Filled the Victory/endgame Perf + JIP/HC cells by reviewing `Server/FSM/server_victory_threeway.sqf` (the sole victory FSM, `execVM`'d at `Init_Server.sqf:528`) and the end-of-match DB-flush tail.
- **Perf: clean.** 80 s `_loopTimer`, cheap per-side checks (`GetSideHQ`/`GetSideStructures`/`GetTownsHeld`/`GetFactories`); `_innerTimer` is a dead unused variable; `_miniSleep=0.05` only paces the one-time end-of-match per-player DB `STORE`.
- **JIP/HC: server-authoritative (correct).** One narrow gap: the endgame `SendToClients` (`:24`) and the unbroadcast `WFBE_GameOver` (`:33`) aren't replayed to a player joining the ~10 s window before `failMission "END1"` (`:88`) — moot since the mission is ending.
- **Source mechanism for DR-11 + DR-13.** Win check (`:23`) `!(alive _hq) && _factories==0 || _towns==_total && !WFBE_GameOver` parses (`&&`>`||`) as `(HQ-dead && no-factories) || (holds-all-towns && !WFBE_GameOver)` — so `!WFBE_GameOver` guards **only** the towns clause, not the HQ-elimination clause; and the `forEach WFBE_PRESENTSIDES` (`:43`) has **no break** after a winner is set. Two same-tick eliminations → double `endgame` broadcast + double `LogGameEnd` + `WF_Winner` overwritten with the opposite side (`:31,35-39`). Exact root cause of DR-11 inversion + DR-13 duplication. Fix: parenthesize+guard both clauses + `exitWith`/break the forEach/while on `gameOver`. Re-confirms DR-12 (threeway `_victory!=0` skips detection).
- Ledger Victory/endgame row: Perf + JIP/HC filled (DR-36); Auth/PV remain 🟡 = the DR-11/12/13 owner fixes. Handoff to Codex: cross-link Feature-Status victory rows to DR-36.

## 2026-06-02 - Claude Deep-Review Round 28 (boot-lifecycle-perf-jip-review lane) — DR-37 (reviewed clean + robustness note)

- Filled the Boot/lifecycle Perf + JIP/HC cells by reviewing the role router (`initJIPCompatible.sqf`) + client boot chain (`Init_Client.sqf`).
- **Perf: clean.** All boot blocking-waits are frame-throttled bare `waitUntil` with cheap conditions; `Init_Client.sqf:248` uses the `waitUntil {sleep 0.5; cond}` throttle idiom; the `while {true} {sleep 0.1; … exitWith}` loops at `:419/:444` are **bounded join-handshake polls** (exit on ACK, 30 s retry) — not perpetual 10 Hz loops. No boot perf trap.
- **JIP/HC: comprehensive + correct.** `initJIPCompatible` routes server/client-II/HC; a JIP client syncs time/date (`WFBE_DAYNIGHT_DATE`, Round 17), teams (`WFBE_PRESENTSIDES` + `wfbe_teams`), and all client state via broadcast logic-object vars; the `RequestJoin` handshake has a 30 s retry + lobby fallback.
- **Robustness note (not a live bug):** the post-join serial `waitUntil {!isNil {WFBE_Client_Logic getVariable "wfbe_…"}}` chain (`Init_Client.sqf:367-502`) has **no timeouts** — if a server-side regression ever fails to set one synced var, the JIP client hangs forever with no fallback or log past that step. Unlike the handshake, which retries. Suggested: add defensive timeouts mirroring the handshake.
- Ledger Boot/lifecycle row: Perf + JIP/HC reviewed clean (DR-37). Handoff to Codex: optionally note the timeout-less post-join waits in Lifecycle-Wait-Chain.

## 2026-06-02 - Codex Explorer Wave C Integration

- Integrated Ampere, Pascal, Boyle and Peirce into owner pages: [Server runtime](Server-Gameplay-Runtime-Atlas), [Mission lifecycle](Mission-Entrypoints-And-Lifecycle), [AI/headless](AI-Headless-And-Performance), [Function/module index](Function-And-Module-Index) and [Feature status](Feature-Status-Register).
- Promoted source-backed facts: generated/missing root `version.sqf` include dependency, live AI commander upgrade worker without proven scheduler, hosted/listen FPS loop risk, no shipped server config bundle, no shipped BattlEye hardening beyond AFK publicVariable support, AI commander assignment argument bug and no HC rebalancing.
- Partly integrated Newton's broken-reference pass: AI supply truck missing `supplytruck.fsm`, MASH marker receiver not registered and stale `RscMenu_Upgrade` file name are now visible in the risk/status pages. Lower-risk cleanup/resource/localization candidates remain queued.
- Integrated Linnaeus' supply-mission authority lane: master is truck-only and authority-light; PR #1 is additive heli/cash/interdiction work on the same trust model; AI logistics remain deferred and the stacked `Killed` EH issue remains unresolved.

## 2026-06-02 - Codex External PDF Reconciliation Wave D

- Steff re-shared three Dutch deep-research PDFs and is also handing them to Claude.
- Codex extracted them into shared text artifacts under `outputs/external-reports/` with `manifest.json` so all agents can read the same normalized corpus.
- Spawned five cheap read-only explorers: Erdos (architecture/lifecycle), Arendt (broken/partial/missing features), Carver (server/security/networking/integrations), Laplace (UI/HUD/wiki UX) and Tesla (agent-readable artifact schema).
- Updated [External research reports](External-Research-Reports) with the extracted text paths and second-wave promotion rule: report claims are leads until repo evidence confirms them.
- Created [`agent-knowledge.jsonl`](agent-knowledge.jsonl), an agent-readable JSONL artifact for source documents, topic clusters, claims and gaps.
## 2026-06-02 - Claude Deep-Review Round 29 (pv-dispatch-perf-jip-review lane) — DR-38

- Filled the PV/networking dispatch Perf + JIP/HC cells by reviewing the hot path (`Server/Client_HandlePVF.sqf`) + registration/precompile (`Init_PublicVariables.sqf`). (Auth/PV/RCE already DR-1.)
- **Perf:** both dispatchers do `_parameters Spawn (Call Compile _script)` (`Server_HandlePVF.sqf:14`, `Client_HandlePVF.sqf:22`) → a per-message runtime recompile of the sender string. **Redundant** — `Init_PublicVariables.sqf:44/49` already pre-compiles every PVFunction into `SRVFNC<name>`/`CLTFNC<name>` globals at init. A validated `getVariable` lookup removes the recompile **and closes the DR-1 RCE in the same one change** (Perf–Security convergence). `Spawn`-per-message adds scheduler pressure under floods (justified for sleep-using handlers; lower priority).
- **JIP/HC: clean.** Dispatchers registered via `addPublicVariableEventHandler` in `Init_PublicVariables.sqf:45/50`, which runs in `Init_Common` on all machines incl JIP clients; PVFs are **transient events** (no replay needed — state sync is the separate DR-37 layer); destination routing (nil/SIDE/UID, `Client_HandlePVF.sqf:12-15`) matches joiners.
- Ledger PV/networking dispatch row: Perf + JIP/HC filled (DR-38). Handoff to Codex: fold the Perf note into the Networking DR-1 remediation section (the security fix is free on Perf).
- **Integrity/recovery note:** this Round 29 commit (`0c1832b`) was pushed to wiki master, then **orphaned** when Codex's `28b9b2d` ("docs: integrate explorer and PDF reconciliation") was built on Round 28 (`891fb5c`) and force-pushed over master — dropping DR-38 from Deep-Review-Findings + ledger + context. Recovered by cherry-picking `0c1832b` from the local object store onto current master; the `docs/wiki` mirror branch had preserved DR-38 throughout. **Coordination ask to Codex: pull-rebase wiki master rather than force-push, so `claude:`-prefixed commits aren't dropped.**

## 2026-06-02 - Claude Deep-Review Round 30 (supply-missions-perf-jip-review lane) — DR-39

- Filled the Supply-missions Perf + JIP/HC cells by reviewing `Server/Module/supplyMission/*` + client consumers.
- **Abandoned-code:** `supplyMissionActive.sqf` is a **dead twin** — a plain function body (no PVEH), compiled to `WFBE_SE_FNC_SupplyMissionActive` (`Init_Server.sqf:81`) but **never called**; superseded by the live `supplyMissionStarted.sqf` (self-registers `WFBE_Client_PV_SupplyMissionStarted` PVEH at `:1`). Remove the dead twin + its compile.
- **Perf:** the live per-mission `while {alive truck} {sleep 3}` server loop does `nearestObjects [pos, [], 80]` (**all** object types) every 3 s just to detect a `Base_WarfareBUAVterminal` — narrow the type filter; bounded by concurrent missions otherwise.
- **JIP/HC: done right (positive counterexample to DR-34).** Cooldown status is **pull-based request/response** (`WFBE_Client_PV_IsSupplyMissionActiveInTown` → server computes from `LastSupplyMissionRun` → `WFBE_Server_PV_IsSupplyMissionActiveInTown` → client stores), so JIP joiners get correct state by asking — no replay needed. The server-side tracking loop is truck-keyed and survives the starting player's disconnect. Minor: the cooldown answer is broadcast to all clients rather than targeted to the requester.
- Ledger Supply missions row: Perf + JIP/HC filled (DR-39); Auth 🟡 remains DR-18 + PR#1 (owner). Handoff to Codex: note the dead twin + the pull-based JIP pattern in Supply-Mission-Architecture.

## 2026-06-02 - Claude Deep-Review Round 31 (wasp-overlay-perf-jip-review lane) — DR-40 (last Perf/JIP-HC cell)

- Filled the final 🟡 Perf cell + ⬜ JIP/HC cell: the WASP overlay (`WASP/*`).
- **Perf: mostly clean, one nit.** `global_marking_monitor.sqf:62` `while {time < _this} do { findDisplay 54 … }` is a **sleepless busy-spin** (polls every frame for up to a 2 s window, input-disabled, one-time at init) — its own sibling at `:80` correctly uses `waitUntil {sleep 0.1; !isNull (findDisplay 12)}`. Convert `:62` likewise. The rest are bounded: `baserep/repair.sqf` 1 Hz only while repairing; `DropRPG.sqf` `sleep 30` cooldown; `AddActions.sqf:2` `While {!alive player}{sleep 2}` one-shot wait. No sustained per-frame loop in live WASP.
- **JIP/HC: clean.** Live WASP wired per-client from `Init_Client.sqf` (`:15` DropRPG, `:267` marking monitor, `:574` baserep, `:575` AddActions) → joiners init locally; `local player` guards correct; HC skips player-local features. Dead: the old `WASP/Init_Client.sqf` path in `initJIPCompatible.sqf:243-244` is inside the commented "old wasp script" block.
- Auth/PV scoped out (WASP action authority = owner economy-class follow-up).
- **MILESTONE:** DR-40 was the **last outstanding Perf/JIP-HC cell** in the matrix. Every subsystem's Perf and JIP/HC dimension is now source-reviewed. The residual 🟡 across the ledger is **exclusively Auth/PV owner decisions** — the client-authoritative economy/forgery class (DR-1/6/14/16/22/23/27/28), the victory fixes (DR-11/12/13), supply (DR-18/PR#1), and the WASP/modules Auth follow-ups.
- Handoff to Codex: note `global_marking_monitor.sqf:62` throttle + dead `initJIPCompatible:243-244` WASP path on the WASP-Overlay page.

## 2026-06-02 - Codex Cheap Explorer Wave E

- Spawned six cheap read-only explorers against remaining thin cells: Godel (UI JIP/HC), Gauss (WASP overlay), Popper (modules/support), Locke (direct PV replay semantics), Planck (generated mission docs QA) and Schrodinger (agent-readable docs QA).
- Integrated source-backed improvements into owner pages: generated mission tiers and fresh-checkout `version.sqf` warning, factory DR-33 queue hazards, lifecycle DR-37 timeout-less JIP wait chain, WASP HQ-recovery locality and dead-action notes, victory DR-36 root cause, MASH/paratrooper marker status and direct publicVariable replay semantics.
- Schrodinger confirmed the agent docs are usable but schema-shaped too flat; added compact `openLanes`, `coordinationProtocol` and `pr1SupplyHeliContext` sections to `agent-context.json` so future agents do not have to scrape dashboard prose.

## 2026-06-02 - Codex Hardening Roadmap

- Added [Hardening implementation roadmap](Hardening-Implementation-Roadmap) to convert the reviewed residual Auth/PV owner decisions into implementation work packages.
- The roadmap defines patch order and validation gates for PVF dispatcher lookup, ICBM server validation, victory/endgame correctness, economy authority, supply mission cleanup/PR #1 readiness, factory queue fixes and smaller WASP/MASH/paratrooper cleanup.
- Wired the roadmap into Home, sidebar, footer, Quickstart, AI guide, documentation plan and `agent-context.json` so future agents find it before editing risky mission code.

## 2026-06-02 - Codex Agent Backlog And Discovery Wave F

- Extracted the three Steff-provided PDF reports into local workspace cache and published sanitized metadata in [`external-research-report-manifest.json`](external-research-report-manifest.json). Raw extracted text stays local and is not mirrored into the wiki.
- Added [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl), a machine-readable backlog for future Codex/Claude/code-owner runs. It covers PVF dispatch lookup, ICBM, attack waves, victory, economy authority, supply missions, factory queues, marker/support cleanup, BattlEye/hosting, static-defense HC sync, hosted FPS sleep, town-AI vehicle safety, tooling checklist, JIP wait-chain timeouts and UI/player-map debt.
- Spawned and harvested Wave F cheap explorers: lifecycle, PV/security, economy, AI/performance, UI, support modules, tooling, PDF triage, town-AI vehicle safety and lifecycle wait-chain audit.
- Promoted the most important new confirmed bug: `server_town_ai.sqf:211-216` can delete a town-AI vehicle containing a player passenger/crew member when the player is not group leader. This is now in [Feature status](Feature-Status-Register), [AI/headless](AI-Headless-And-Performance), [Hardening roadmap](Hardening-Implementation-Roadmap) and the backlog.
- Added the post-join wait-chain audit to [Lifecycle wait-chain](Lifecycle-Wait-Chain): handshake gates retry every 30 seconds but have no terminal timeout, while later replicated-variable waits have no retry/timeout/log fallback.
- Added an operator checklist to [Tools/build](Tools-And-Build-Workflow) for LoadoutManager checkout path, `7za`, generated `version.sqf`, DiscordBot config and the in-repo Extension versus out-of-repo AntiStack DLL distinction.

## 2026-06-02 - Codex Dashboard Current-State Cleanup

- Reworked [Progress dashboard](Progress-Dashboard) so the first screen shows the current state, open lanes and recent published work instead of a stale historical roster.
- Moved detailed scout history responsibility to [Discovery swarm](Subagent-Discovery-Swarm) and this worklog.
- Updated `agent-status.json`, `agent-collaboration.json` and `agent-context.json` so machine readers agree that the Wave F backlog batch is published and the only active Codex lane is dashboard cleanup/validation.

## 2026-06-02 - Codex Town-AI Vehicle Safety Playbook

- Added [Town AI vehicle safety](Town-AI-Vehicle-Despawn-Safety) as a dedicated implementation playbook for the confirmed `server_town_ai.sqf:211-216` occupied-vehicle deletion bug.
- Wired the page into Home, sidebar, footer, [AI/headless](AI-Headless-And-Performance), [Feature status](Feature-Status-Register), [Hardening roadmap](Hardening-Implementation-Roadmap), dashboard and machine-readable agent files.
- The page documents the source chain, exact failure condition, behavior-preserving SQF guard shape and validation gates for a future gameplay patch in the Chernarus source mission.
- Queued the Anscombe lifecycle subagent report as a separate verification lead; it contains useful boot/lifecycle notes but also uses a `Migrations` path typo, so it should be source-checked before integration.

## 2026-06-02 - Codex Lifecycle Runtime Verification

- Source-checked Anscombe's lifecycle report against `Missions/[55-2hc]warfarev2_073v48co.chernarus`; the report's `Migrations` path was a typo, not a repo path.
- Confirmed the main lifecycle claims: `description.ext` resource front door, `initJIPCompatible.sqf` branch dispatch, `Init_Parameters.sqf` missionNamespace globals, `Init_Common.sqf` shared compile/config hub, server/client readiness gates and HC registration.
- Promoted the most useful missing nuance into [Mission lifecycle](Mission-Entrypoints-And-Lifecycle) and [Lifecycle wait-chain](Lifecycle-Wait-Chain): town startup begins from `mission.sqm` object `init` fields, with `WF_Logic` at `mission.sqm:3265` starting `Init_TownMode.sqf`.
- Reconfirmed the HC timing caveat: `Init_HC.sqf:12` uses `sleep 20` before sending `connected-hc`, while `serverInitFull` is not set until `Init_Server.sqf:507`.

## 2026-06-02 - Codex Testing Workflow And Agent Schema

- Added [Testing workflow](Testing-Debugging-And-Release-Workflow) as the repo's practical validation page for source-only checks, local tooling, hosted/dedicated/JIP/HC smoke tests and live-server-sensitive release gates.
- Added [`agent-test-plan.schema.json`](agent-test-plan.schema.json) so Codex, Claude and future agents can record test evidence without blurring source review and in-game smoke results.
- Wired the page into Home, sidebar, footer, hardening roadmap, AI guide, progress dashboard and machine-readable context/status/collaboration files.

## 2026-06-02 - Claude operating-mode change (Ray)

- Phase 1 (self-select the emptiest ledger cell) reached completion: Map + Perf + JIP/HC + Drift are reviewed for every subsystem (DR-1..DR-40); residual `🟡` is exclusively Auth/PV owner decisions.
- New standing mode set by Ray: **collaboration-follow loop with research autonomy, self-paced** — each pass read the shared coordination state and follow Codex's lead (verify at source before claiming), with autonomy to pull own threads on idle passes. Docs-only. Recorded as `Claude-Loop-Goal.md`. **Codex:** link it from nav at your convenience (your lane). Done = nothing pending from Codex + only owner-decisions left.

## 2026-06-02 - Claude Deep-Review Round 32 (attack-wave-authority-verify lane) — DR-41 [first collaboration-follow pass]

- First pass under the new mode: read Codex's recent work (hardening roadmap, agent-hardening-backlog.jsonl, wave E/F), picked the raw scout candidate `attack-wave-authority` (status `new-from-2026-06-02-pv-scout`) and source-verified it.
- **DR-41 (High, economy authority / forgery — new direct-PV channel):** `ATTACK_WAVE_INIT` is forgeable. `Server/Functions/Server_AttackWave.sqf:5-6` takes `_supply`/`_side` **directly from the client payload** — no `GetSideSupply` re-derivation, no `_side`-vs-sender check, no server-side cost deduction; the `GetSideSupply >= 25000` gate (`updateclient.sqf:240`) is **client-side only**. With `SUPPLY_MAX = 50000` (`Init_CommonConstants.sqf:166`), a forged `_supply >= 70000` drives `ATTACK_WAVE_PRICE_MODIFIER` (a side-wide unit-price multiplier) to **0 → free units side-wide**; larger → negative pricing. Not in `BattlEyeFilter/publicvariable.txt` (DR-30).
- **Architectural point:** the forgery class has **two surfaces** — the registered PVF dispatcher (DR-1, fixed by validated lookup) **and** direct `publicVariableServer` channels (DR-41). The DR-1 fix does NOT cover direct channels; each direct PVEH must re-derive trusted values server-side. Other direct channels (side-supply, supply-mission, MASH) share this surface.
- Confirms Codex backlog item `attack-wave-authority` → confirmed/High. Ledger Economy row + DR-41. Handoff to Codex: flip backlog status, cross-link DR-41 from Networking direct-PV table + economy roadmap, fold into the economy-authority owner decision with the two-surfaces note.

## 2026-06-02 - Codex Server Authority Migration Map

- Added [Server authority migration map](Server-Authority-Migration-Map) as the design layer between the hardening roadmap and testing workflow.
- Consolidated the client-authoritative/payload-authoritative class into one migration table: PVF dispatch, ICBM, construction/defense, player buys, upgrades, side supply, supply missions, attack waves, gear/EASA/service, structure sale and WASP HQ recovery.
- Wired the page into Home, sidebar, footer, AI guide, adjacent Continue Reading links and the machine-readable context/status/collaboration files.
- Handoff: future code owners should read this page before claiming `network-authority`, `economy`, `gameplay-security`, `support-systems` or BattlEye-sensitive backlog items.

## 2026-06-02 - Codex DR-41 Attack-Wave Integration

- Source-checked Claude DR-41 against `Common_AttackWaveActivate.sqf`, `Server_AttackWave.sqf`, `updateclient.sqf`, `Init_CommonConstants.sqf` and `BattlEyeFilter/publicvariable.txt`.
- Promoted `attack-wave-authority` in [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) from scout candidate to `confirmed-high-dr41`.
- Cross-linked the finding through [Networking/PV](Networking-And-Public-Variables), [Hardening roadmap](Hardening-Implementation-Roadmap), [Server authority map](Server-Authority-Migration-Map), [Economy](Economy-Towns-And-Supply) and [Feature status](Feature-Status-Register).
- Key handoff for future patch owner: the server-authority redesign must cover both registered PVF handlers and direct `publicVariableServer` channels; the PVF dispatcher fix alone does not harden `ATTACK_WAVE_INIT`.

## 2026-06-02 - Codex Attack-Wave Authority Playbook

- Added [Attack-wave authority playbook](Attack-Wave-Authority-Playbook) as the implementation-ready DR-41 guide.
- Documented the exact source chain through `updateclient.sqf`, `Common_AttackWaveActivate.sqf`, `Server_AttackWave.sqf`, `AttackWave.sqf`, buy-unit UI pricing and `BattlEyeFilter/publicvariable.txt`.
- Captured the important design nuance: `25000` supply is currently only the action gate; the live debit spends all current side supply. Default hardening should preserve that model by re-deriving and debiting server-held side supply unless the owner approves a fixed-cost design change.
- Wired the page into Home, sidebar, footer, Networking/PV, Economy, Feature status, Hardening roadmap, Server authority map, Testing workflow, AI guide, dashboard and machine-readable agent files.
## 2026-06-02 - Claude Deep-Review Round 33 (hc-static-defense-verify lane) — DR-42 + DR-19 dedup

- Adjudicated two raw backlog scout candidates at source. **DR-42 (Low/Med):** static-defence HC delegation's update-back is **commented out** (`Client_DelegateAIStaticDefence.sqf:28`), unlike town-AI delegation which reports back (`Client_DelegateTownAI.sqf:35` → `update-town-delegation`). Server never tracks HC-created static-defence units → no cleanup/accounting/re-delegation; compounds DR-21. Owner: restore the update-back (define the server `update-delegation-static_defence` handler) or document as fire-and-forget. Confirms `hc-static-defense-sync`.
- **DR-19 dedup:** backlog `server-fps-hosted-loop-sleep` is the same defect as DR-19 (`monitorServerFPS.sqf:1-7` — `sleep` inside `isDedicated` busy-spins on hosted/listen servers). Not new; fold into DR-19.
- Ledger AI/headless row + DR-42. Handoff to Codex: flip backlog statuses + cross-link DR-42 near DR-21.

## 2026-06-02 - Claude Deep-Review Round 34 (external-research-intake-2 lane) — DR-43

- Ray supplied 9 new deep-research reports (`deep-research-report (1..9).md`). Triaged all 9 (treated as untrusted leads; cross-checked at source). They are downstream syntheses corroborating DR-1..DR-42 — notably report 8 ("Server Authority Refactor") is an independent restatement of the economy-authority thesis (funds/supply mutated client-side then announced; ledger ≠ server source of truth) + DR-1. No contradictions. Same posture as DR-26.
- **DR-43 (Low) — two new source-confirmed leads:** (a) `description.ext:39` `#include "version.sqf"` but `version.sqf` is absent from the whole committed tree -> the repo is **not buildable from source as-is** (version.sqf is supplied at pack time per AGENTS.md); source-completeness/drift note (ties DR-4/32). (b) `Server/Init/Init_Server.sqf` has duplicate compile/bind rows. Codex later corrected the live count: `LogGameEnd`, `PlayerObjectsList` and `AwardScorePlayer` are live duplicate binds; `InitAFKkickHandler`, `monitorServerFPS` and `MASH_MARKER` are commented duplicate remnants. **LogGameEnd duplication ties DR-13**.
- Ledger Tooling row + DR-43a. Handoff to Codex: add the 9 reports to `external-research-report-manifest.json` (your lane); DR-43a = commit a source `version.sqf` or document pack-time generation; DR-43b = de-dup the Init_Server binds.

## 2026-06-02 - Codex DR-42/DR-43 Reconciliation

- Promoted `hc-static-defense-sync` from raw scout backlog to `confirmed-low-dr42`, linked it into [AI/headless](AI-Headless-And-Performance), [Feature status](Feature-Status-Register) and the hardening roadmap.
- Marked `server-fps-hosted-loop-sleep` as `duplicate-of-dr19` instead of a separate finding.
- Source-checked DR-43's duplicate-bind claim against `Server/Init/Init_Server.sqf:63-93` and corrected the count: three live duplicate binds plus three commented duplicate remnants.
- Added backlog work packages for `source-version-sqf-build-gap` and `init-server-duplicate-binds`.

## 2026-06-02 - Claude Wiki-Quality Program, Pass 1 (Ray-approved plan)

- Ray asked for a wiki quality pass (dedup / audit entries / additional context). Ran 3 parallel audits (duplication, accuracy, gaps); approved plan = Claude fixes its own lane directly + creates connective pages + a source-verified module atlas, and produces ONE audit-handoff for Codex's pages (dedup/merge/cross-link). Plan: `~/.claude/plans/drifting-tickling-platypus.md`.
- **Pass 1 (Claude-lane accuracy):** Codebase-Coverage-Ledger — matrix timestamp → 2026-06-02; legend clarified (✅ = reviewed-clean *or* reviewed-with-finding; Map ✅ = a flow/source map exists); **Modules Map ✅→🟡** (only ICBM/Nuke DR-27 + UAV mapped; full modules atlas pending) and **Markers/cleaners Map ✅→🟡** (cleaners/restorers not yet atlas'd). Deep-Review-Findings — **DR-11 severity Medium-High → High** (inverted persisted win-tally); **DR-36** given a dual-purpose disambiguation note (clean Perf/JIP result vs root-cause for DR-11/13).
- Upcoming passes: agent-context systems map; Wiki-Quality-Audit handoff page; WFBE_* glossary; consolidated PV-channel index; Modules atlas (source-verified); Pending-Owner-Decisions page; then nav handoff to Codex.
- **Pass 2 done:** `agent-context.json` `systems` map +5 entries (`modules`, `victoryEndgame`, `weatherDayNight`, `markersCleanersRestorers`, `parametersLocalization`) — all 22 ledger subsystems now represented so agents loading context see them.
- **Pass 3 done:** new `Wiki-Quality-Audit.md` — a Codex-lane punch-list: (A) 11 dedup→cross-link rows, (B) page merges (Hardening-roadmap≈Server-authority-map ~70%; Client-UI-HUD ⊂ Client-UI-Systems-Atlas; Mission-entrypoints≈Lifecycle-wait-chain ~50%; Gameplay-atlas reduce-to-summary), (C) accuracy fixes (C1 HIGH: Networking MASH row contradicts DR-34; C2 HIGH: orphaned-DR cross-links to add per atlas; C3 stale Gameplay open-questions; C4 cite DR-11 by number; C5 sidebar dup entries; C6 thin citations). **Codex handoff event posted** to action A/B/C on its pages + wire upcoming new Claude pages into nav.
- **Pass 4 done:** new `Variable-And-Naming-Conventions.md` — source-cited WFBE_* prefix glossary (config/CO_FNC/SE_FNC/CL_FNC/SRVFNC/CLTFNC/WFBE_PVF_/wfbe_ object vars) + key implications (module gates, pre-compiled-vs-recompile DR-1/38, setVariable-true replication, case-sensitive getVariable keys DR-18). Sibling-new-page links backticked pending creation; final relink pass at the end.
- **Pass 5 done:** new `Public-Variable-Channel-Index.md` — canonical inventory of ALL PV channels: 13 server-bound + 14 client-bound registered PVF commands (`Init_PublicVariables.sqf:8-20`/`:23-37`, each annotated with its notable DR) + ~23 direct channels (ATTACK_WAVE_INIT DR-41, MASH DR-34, supply DR-39/DR-22, ICBM/radiation FX, AFK/kickAFK DR-30, daynight, handshakes DR-37). Trust legend + BattlEye-filter design surface. Supersedes the 2 Networking tables + SQF-atlas duplicate (DUP-11 handoff to Codex).

## 2026-06-02 - Codex HC Delegation/Failover Playbook

- Read `Headless/Init/Init_HC.sqf`, HC registration/disconnect handling, `Server_DelegateAITownHeadless.sqf`, `Server_DelegateAIStaticDefenceHeadless.sqf`, `Client_DelegateTownAI.sqf`, `Client_DelegateAIStaticDefence.sqf`, `Server_FNC_Delegation.sqf`, `Server_HandleDefense.sqf`, `Server_OperateTownDefensesUnits.sqf` and `server_town_ai.sqf`.
- Added [HC delegation/failover](Headless-Delegation-And-Failover-Playbook) as an implementation-ready DR-21/DR-42 guide.
- Captured the key model split: HC mode is remote creation on the HC, client-FPS delegation is a separate player-client mode, town AI has vehicle update-back, and static defense currently does not.
- Documented phased patch shape: explicit static-defense update-back decision, HC work records, disconnect policy and late-HC behavior.

## 2026-06-02 - Claude Wiki-Quality Program, Pass 6 (Modules atlas)

- New `Modules-Atlas.md` — source-verified sections for the ~10 previously-undocumented modules: **IRS** (IR smoke; gate `WFBE_C_MODULE_WFBE_IRSMOKE` + `WFBE_UP_IRSMOKE`), **CM** (flares/chaff; vanilla-only gate), **Reaktiv** (ERA armor via `HandleDamage`), **Engines** (stealth = save fuel + `setFuel 0`), **AutoFlip** (Marty; flip-righting poll, tilt 0.35/cooldown 45), **ZetaCargo** (Benny sling-load; lifter allow-list + cargo types), **Valhalla** (low-gear/high-climb; display-46 key EHs), **Skill** (Benny class abilities; Engineer/Soldier/Officer/…), **NEURO** (Benny AI taxi; `NEURO_TAXI_CONDITION` hook), **CIPHER** (Benny sort util; no side effects). Cross-links the already-covered modules (Nuke DR-27, EASA DR-28, AntiStack DR-7-10, supplyMission DR-39, MASH DR-34, UAV, serverFPS DR-19, AFK DR-30).
- Ledger **Modules Map 🟡→✅** (restored; atlas now exists) and row title/anchor expanded to name the documented modules.
- **Pass 7 done (program complete):** new `Pending-Owner-Decisions.md` — consolidates every open owner decision (economy/forgery class as one two-surface decision; correctness fixes; keep-or-remove; robustness) with finding + severity + page links; it operationalizes the loop's "done = only owner decisions remain". Final relink pass converted all backticked sibling refs to real links now that the 5 new pages exist; **full-wiki link gate: no broken links**. **Codex handoff posted:** wire the 5 new pages (`Wiki-Quality-Audit`, `Variable-And-Naming-Conventions`, `Public-Variable-Channel-Index`, `Modules-Atlas`, `Pending-Owner-Decisions`) into nav, and action the Wiki-Quality-Audit A/B/C punch-list on your pages.

## 2026-06-02 - Codex Wiki-Quality C1 MASH Networking Fix

- Actioned [Wiki quality audit](Wiki-Quality-Audit) C1 on [Networking/PV](Networking-And-Public-Variables).
- Corrected the MASH direct-PV row to DR-34: the server PVEH is registered but orphaned, the client never broadcasts `WFBE_CL_MASH_MARKER_CREATED`, and the client receiver compile is commented.
- Updated replay/JIP notes to say a revival needs a server-held marker list, JIP re-send and unique marker names.

## 2026-06-02 - Codex Wiki-Quality Navigation / C5

- Wired Claude's new canonical pages into primary navigation: [Variable and naming conventions](Variable-And-Naming-Conventions), [Public variable channel index](Public-Variable-Channel-Index), [Modules atlas](Modules-Atlas), [Pending owner decisions](Pending-Owner-Decisions) and [Wiki quality audit](Wiki-Quality-Audit).
- Mirrored and surfaced Codex-2's [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook) as the DR-1/DR-38 hardening guide.
- Resolved [Wiki quality audit](Wiki-Quality-Audit) C5 by keeping hardening roadmap, server authority map, attack-wave authority and testing workflow in Ops, while Current Work now focuses on dashboard/coordination/review pages.
- Added the new pages into Home reading paths/current map, `_Footer.md` and `agent-context.json`.

## 2026-06-02 - Codex Wiki-Quality C2 Atlas Cross-Links

- Actioned [Wiki quality audit](Wiki-Quality-Audit) C2 across developer-facing atlas pages.
- Added DR links in [Gameplay atlas](Gameplay-Systems-Atlas) for construction authority DR-6, purchase authority DR-14, victory/endgame DR-11/12/13/36, supply windfall DR-22, upgrade forgery DR-23 and commander assign DR-15.
- Added UI risk links for gear/template/cargo DR-16/17/24 and EASA/service DR-25a/b, plus AI/headless DR-21/DR-42, construction DR-6 and lifecycle DR-37/DR-43a.
- Partially resolved C3 by replacing the stale commander open question with a DR-15 confirmed-finding note.

## 2026-06-02 - Codex Wiki-Quality C4 Victory Searchability

- Actioned [Wiki quality audit](Wiki-Quality-Audit) C4.
- Updated [Feature status](Feature-Status-Register) and [Hardening roadmap](Hardening-Implementation-Roadmap) so the victory/endgame winner-inversion bug is searchable as DR-11, while DR-36 remains the mechanism/perf-JIP explanation.

## 2026-06-02 - Codex Wiki-Quality C6 UI Citation Uplift

- Started [Wiki quality audit](Wiki-Quality-Audit) C6 with the thinnest page, [Client UI/HUD](Client-UI-HUD-And-Menus).
- Added path:line anchors for `description.ext` Rsc includes, `Rsc/Dialogs.hpp` dialog classes/IDDs, `Rsc/Titles.hpp` HUD/title resources, `GUI_Menu.sqf` menu routing and HUD toggles, `Client_UpdateRHUD.sqf` HUD ownership, and `GUI_RespawnMenu.sqf` / `Client_UI_Respawn_Selector.sqf` marker tracking.
- Reconciled Codex-2's new `economy-authority-first-cut` claim into `agent-collaboration.json`, `agent-status.json`, `Progress-Dashboard.md` and the append-only event feed while preserving the UI citation lane.
- Left Gameplay and AI/headless citation uplift open for later passes.

## 2026-06-02 - Codex-2 PVF Dispatch Implementation Playbook

- Claimed pvf-dispatch-implementation-playbook after reading the required dashboard, protocol, machine state, DR register, roadmap, server-authority map and external-report intake files.
- Source-checked Init_PublicVariables.sqf, Server_HandlePVF.sqf, Client_HandlePVF.sqf and the PVF send helpers in the Chernarus source mission.
- Published [PVF dispatch implementation playbook](PVF-Dispatch-Implementation-Playbook), turning DR-1 and DR-38 into a P0 patch guide with registered allowlists, missionNamespace getVariable, hosted/dedicated validation and a clear boundary against per-handler authority and direct publicVariable channels.
- Handoff: future code owner should implement this as hardening/pvf-dispatch, then validate one server-bound PVF, one client-bound PVF and a bogus handler rejection before moving to ICBM or attack-wave authority.

## 2026-06-02 - Codex-2 Economy Authority First Cut

- Claimed `economy-authority-first-cut` after checking the live dashboard/collaboration state and avoiding the already-published HC/failover lane.
- Source-checked side supply, group funds, upgrades, construction/defense, player buys, service/EASA, MHQ repair and supply mission entrypoints in the Chernarus source mission.
- Published [Economy authority first cut](Economy-Authority-First-Cut), recommending side-supply-clamp as the first small code branch, then server-owned upgrades and construction/defense, while keeping player factory buys as a separate locality redesign.
- Handoff: future code owner should patch the side-supply negative floor and temp-channel validation first; it is small, source-backed and does not claim to solve the broader client-authoritative economy.

## 2026-06-02 - Codex Wiki-Quality C6 AI Citation Uplift

- Continued [Wiki quality audit](Wiki-Quality-Audit) C6 after the UI citation pass.
- Added path:line anchors to [AI/headless](AI-Headless-And-Performance) for delegation parameters/constants, HC bootstrap, HC registry, town-AI HC delegation, static-defense HC delegation, HC disconnect handling, town-AI cleanup, server-FPS publishers and the `GetSleepFPS` scheduling tradeoff.
- Corrected loose shorthand to the real `Server_DelegateAITownHeadless.sqf` / `Server_DelegateAIStaticDefenceHeadless.sqf` source files.
- Left Gameplay atlas citation uplift as the remaining C6 item.

## 2026-06-02 - Codex-2 Supply Mission Authority Cleanup Playbook

- Claimed `supply-mission-authority-cleanup-playbook` after publishing the economy authority first cut and confirming PR #1 supply helicopters remain additive to the existing object-var trust model.
- Source-checked supply mission start, cooldown query/response, server tracking/completion, PR #1 helicopter constants/action/message changes, player resolution and the dead `supplyMissionActive.sqf` twin.
- Published [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), turning DR-18/DR-39 and the PR #1 stacked-`Killed` handler review into a practical patch guide.
- Handoff: future code owner should add server-owned loaded/tracking state and `Killed` handler idempotency first, then standardize cooldown casing and validate/recompute cargo server-side before merging supply helicopters as baseline.

## 2026-06-02 - Codex-2 Abandoned Feature Revival Review

- Published [Abandoned feature revival](Abandoned-Feature-Revival-Review) after source-checking MASH marker relay, paratrooper marker PVF, AI supply-truck logistics, UAV 007 UI branch, WASP legacy actions, stale upgrade dialog and modded mission propagation.
- Key conclusions: MASH tents are live but map markers are dead on both ends unless rebuilt with server-held/JIP-safe state; paratrooper drops are live but the marker callback is absent from `_clientCommandPV`; AI supply trucks are broken/dormant because compile is commented, a gated call remains and `Server\FSM\supplytruck.fsm` is missing.
- Handoff: future code owner should pick one bounded cleanup from the page; Claude can contradiction-check hidden marker senders or stale UI callers.

## 2026-06-02 - Codex External Arma 2 OA Reference Guide

- Published [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide) as the official-reference router for future mission changes.
- Mapped BI Community Wiki references for multiplayer/JIP, `publicVariable`, PVEHs, `setVariable`, event handlers, `nearestObjects`, `preprocessFileLineNumbers`, render/simulation scope and diagnostic timing to concrete Wasp source hotspots.
- Handoff: future agents should link engine claims to this guide instead of repeating broad warnings or importing Arma 3 networking assumptions.

## 2026-06-02 - Claude Deep-Review Round 35 (direct-pv-supply-authority lane) — DR-44

- Research-autonomy pass walking the direct `publicVariableServer` channels from the new PV-channel index for the forgery class DR-41 opened.
- **DR-44 (High, economy authority/forgery):** `wfbe_supply_temp_<side>` is forgeable. `Common_ChangeSideSupply.sqf:28-30` broadcasts `[_side,_amount,_reason]`; `Server_ChangeSideSupply.sqf` (PVEH `:1` west / `:25` east) takes `_amount` straight from the payload and sets `wfbe_supply_<side> = currentSupply + _amount` (capped at max) with **no sender auth, no `_side`-vs-sender check, no re-derivation** → any client can arbitrarily inflate a side's supply (which gates attack-wave/funds/production). The `_reason` fallback string even admits "might indicate a malicious supply update request" — a log breadcrumb instead of authority. **Second** confirmed direct-PV forgery after DR-41 → the direct-channel surface is a class, and the supply **ledger itself** is client-writable. Distinct axis from DR-22 (broken floor, same file).
- Updated DRF (Round 35), ledger Economy row, `Public-Variable-Channel-Index` supply row, `Pending-Owner-Decisions` economy table, agent-context risk/reviewPass. Folds into the economy-authority owner decision (two surfaces: PVF dispatcher DR-1 + direct channels DR-41/DR-44); BattlEye should restrict `wfbe_supply_temp_*` (not shipped, DR-30).

## 2026-06-02 - Claude full-wiki audit follow-through (Round 36) — DR-45 + direct-PV closed + coverage gaps

- Ran a 3-agent full audit of all 60 pages (accuracy/consistency/coverage). Wiki healthy: **no broken links, no orphans, DR severities consistent, dedup clean.** Verified two audit findings at source and found them **false positives** (PV-index PVF line ranges `:8-20`/`:23-37` and DR-15 `_side=_this` `:3` are correct — agents miscounted blank lines); did not change.
- **DR-45 (Medium):** `server_town_ai.sqf:213-216` despawn deletes `wfbe_active_vehicles` guarded only by `!(isPlayer leader group _x)` — no crew/cargo check → a player riding as passenger in an AI-led vehicle loses it. Promotes the un-numbered `Town-AI-Vehicle-Despawn-Safety` playbook to a DR; ledger AI/headless row updated.
- **Direct-PV forgery surface CLOSED:** checked the remaining direct channels — `REQUEST_SUPPLY_VALUE` (read-only query) and `MARKER_CREATION` (cosmetic local marker) are **clean**. Forgery surface bounded to DR-41 + DR-44.
- **Coverage-gap assessment** (answers "did we miss code spots / depth"): unreviewed-to-depth = Server/AI respawn+orders, cleaners/restorers Perf, the Config data model, `basearea`/`groupsMonitor`/`Support_*` trigger chains, PR#1 line-by-line. Economy/PVF classes are at exploit-and-fix depth; AI/respawn/cleaners are map-only depth — the next review lanes.
- **Claude-lane audit fixes applied:** `DR-8-class`→economy-authority class (conventions page); `Server_HandlePVF.sqf`/`Client_HandlePVF.sqf` path clarity (owner-decisions page).
- **Codex-lane handoff:** `Wiki-Quality-Audit` "Round 2" punch-list — R2-1 UI atlas finding mislabels (DR-16 is structure-sale, not gear; DR-25a/b are IDD/soundPush, not EASA), R2-2 SQF compile counts (DR-5), R2-3 MASH hedge (DR-34), R2-4 DR-44 / R2-5 DR-20 / R2-6 DR-40+DR-19 / R2-7 DR-45 atlas cross-links, R2-8 Coordination-Board stale lanes/roles, R2-9 Progress-Dashboard, R2-10 sidebar HC-delegation dup.
- **Created `Instructions-For-Codex.md`** — one consolidated, current, prioritized action queue (P0 accuracy → P1 cross-links + current-work reconcile → P2 page merges → P3 thin citations), marking already-done items (nav wiring, dedup routing, MASH C1) and the 2 audit false-positives not to change. State-checked first: Codex already wired the 5 new pages into the sidebar; page merges + UI-atlas mislabels + current-work reconcile remain outstanding. Codex works from this page.

## Future Agents

- Add dated entries here before and after substantial documentation or code changes.

## Continue Reading

Previous: [Agent collaboration protocol](Agent-Collaboration-Protocol) | Next: [Deep-review findings](Deep-Review-Findings)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)

## 2026-06-02T08:46:54+02:00 - Codex-2 performance opportunity sweep

Published [Performance opportunity sweep](Performance-Opportunity-Sweep) after source-checking hosted server FPS loops, supply mission scans, WASP marker polling, factory queue broadcasts, PVF dispatch, client marker loops, RHUD, cleaners/restorers and skill initialization.

Key conclusions:

- Highest-value performance-adjacent patch remains PVF dispatcher lookup because it also closes DR-1/DR-38.
- Smallest server patch is hosted/listen FPS loop sleep or exit; current sleep is inside isDedicated.
- New finding: Skill_Init.sqf runs twice in client init and can compound Soldier WFBE_C_PLAYERS_AI_MAX; added client-skill-init-idempotency to the backlog.
- Supply scan narrowing, factory queue cleanup and WASP marker wait cleanup are bounded follow-ups; marker/town/cleaner cadence changes should be driven by PerformanceAudit rows.

## 2026-06-02T09:14:43+02:00 - Codex-2 Paratrooper Marker Revival

- Claimed `paratrooper-marker-revival` after the dashboard identified paratrooper markers as one of the next best Codex-2 lanes.
- Initial source check found the server sender and client handler exist; the lane will verify PVF registration, side filtering, marker lifecycle and validation before publishing or patching.

## 2026-06-02T12:14:00+02:00 - Claude SEND_MESSAGE RCE (DR-46) + improvements PDF

- Produced a standalone "20 improvements" review PDF for the owner (`Desktop/a2waspwarfare-improvements/a2waspwarfare-20-improvements.pdf`): 20 ranked, source-verified improvements (effort/gains/complexity, before/after snippets) distilled from DR-1..DR-45 + a fresh source pass, plus a ranked appendix and rollout sequence.
- Filed **DR-46**: `Client_onEventHandler_SEND_MESSAGE.sqf:27` `call compile`s network text on the SEND_MESSAGE direct-PV channel (multi-language branch) — a second client-side RCE independent of the PVF dispatcher; corrects DR-1's single-compile-site assumption (~line 159). `Common_SendMessage.sqf:26` shares the pattern. Added `agent-hardening-backlog.jsonl#send-message-call-compile-rce`, a `pv-network-trust` knowledge record, claim/finding/handoff events, and a New-findings block in Instructions-For-Codex.
- Handed Codex source-verified **maintainability leads** (Init_Common double-compile dup-pairs + un-prefixed globals + GetClosestEntity variants; Support/Construction/Loadout copy-paste families; ~12 hardcoded hints) to verify against Variable-And-Naming-Conventions / SQF-Code-Atlas before documenting.
- NOTE: the docs/wiki mirror (`a2waspwarfare-docs` @ `docs/developer-wiki-claude`) had pre-existing uncommitted local changes (Agent-Worklog, Coordination-Board, Content-Structure-And-Maps, Factory atlas, …) made outside this pass — left untouched; DR-46 mirror parity deferred to avoid capturing unrelated edits.

## 2026-06-02T15:21:42+02:00 - Claude consistency Batch-4 + Batch-2 clobber recovery

- **Batch-4 wiki↔source audit** (7 playbook/index pages, ~190 claims, 29 confirmed inconsistencies, every one re-verified at source). [Attack-wave authority playbook] clean (0/8). Routed all to `Instructions-For-Codex.md` items 19–25 (not the findings page — see below).
- **Headline (HIGH):** [Supply-mission authority cleanup playbook] documents code that does **not** exist in current source — a `Killed` EH on the supply vehicle (0 grep hits for `addEventHandler`/`Killed` in the supply module), a `SupplyByHeli` object var (0 grep hits anywhere), a heavy-heli cash-run + commander-funds completion branch, and recommended-patch constants `WFBE_C_SUPPLY_TRUCK_TYPES`/`…HELI_TYPES_T2`/`_T3`. Reads like a draft "PR #1" written up as shipped. Its status table also marks the supply scan "Source/Vanilla claimed-patched" though `supplyMissionStarted.sqf:28` is still `nearestObjects [...,[],80]` (DR-39 not applied) — and the page self-contradicts (Step 5 shows `[]`).
- Other confirmed: ICBM playbook authority-boundary line reads as factual but `Server_HandleSpecial.sqf:97-112` has no validation (DR-27); `Reaktiv` listed "Live" but `Reaktiv_Init` has zero callers (dead/unreachable); PVF playbook client-command list enumerates 9 of 14; plus family-summary + line-drift LOWs on Function-And-Module-Index / Variable-And-Naming / Economy-Authority-First-Cut.
- **Batch-2 clobber recovery:** diagnosed that my batch-3 commit `89f848f` silently dropped the Batch-2 section of `Wiki-Source-Consistency-Findings` (shared-worktree revert between Edit and `git add`, same mechanism as the HC-page `41c5a20` clobber). Re-verified the 5 still-live Batch-2 items at source (all still wrong on the live wiki) and **routed them to their owning pages** (Modules-Atlas ×4 + Economy-Towns-And-Supply dead-constant) as item 25, rather than re-adding a section — Codex is actively curating that findings page (uncommitted slimming of Batch 3 + a 15:05 note), so I stayed out of its lane.
- Published from the clean clone `_wasp_wiki_claude` (clobber-free), committing only my own coordination files; appended 2 events + 3 `repo_verified` knowledge records (all JSONL re-validated, 0 parse failures).

## 2026-06-02T15:35:10+02:00 - Claude consistency Batch-5

- **Batch-5 audit** (4 pages, 133 claims, 4 confirmed, all self-verified at source → Instructions-For-Codex items 26–28).
- (HIGH) [Core-Systems-Index] lists "Discord bot status publishing" as an in-mission operational system — no Discord code in the mission (only plain-text mentions: `Init_Client.sqf:959`, `briefing.sqf`, `stringtable.xml`); the real mission role is the separately-listed extension stats export, and Discord publishing is the external `DiscordBot/` repo component.
- (HIGH) [Factory-And-Purchase-Systems-Atlas] FSM `depotInRange` gate uses `WFBE_C_TOWNS_CAPTURE_RANGE` (40, `updateavailableactions.fsm:39,194`), not the `WFBE_C_TOWNS_PURCHASE_RANGE` (60) the page labels it; (MED/DR-33b) the varQueu factory token is still `random(...)` (`Client_BuildUnit.sqf:167-168`, comment "to remove with new sys later on"), not the UID/counter token the page calls "current source".
- (LOW) [Architecture-Overview] `initJIPCompatible.sqf:31` logs `WF_MAXPLAYERS` ("Max players Defined", a slot ceiling), described on the page as "player count".
- Coverage: [Attack-Wave-Authority-Playbook] genuinely clean (0/8, batch 4). [Headless-Delegation-And-Failover-Playbook] auditor returned 0 claims (a whiff) — re-queued for batch 6.
- Inventory: 78 wiki pages total; ~26 content pages audited across batches 1–5. NOTE a `Current-Work-Supply-Helicopters-PR1` page exists — likely the source of the Supply-Mission-Authority-Cleanup-Playbook's "PR1 documented as shipped" problem (batch-4 item 19). Batch 6 audits the PR1/supply cluster (Current-Work-Supply-Helicopters-PR1, Supply-Mission-Architecture, Supply-Mission-Scan-Narrowing, Resistance-Supply-Scaffold) + re-audits the Headless-Delegation playbook + more.
- Appended 2 events + 2 `repo_verified` knowledge records (JSONL re-validated, 0 parse failures); committed only my own files from the clean clone.

## 2026-06-02T15:43:13+02:00 - Claude consistency Batch-6 + PR1 investigation + item-19 correction

- **Batch-6 audit** (9 pages, 193 claims, 18 confirmed → Instructions-For-Codex items 30–35). Clean: Headless-Delegation-And-Failover-Playbook (0/6, prior whiff resolved), Current-Work-Supply-Helicopters-PR1 (0/24), Resistance-Supply-Scaffold (0/6). Town-AI-Vehicle-Despawn-Safety returned 0 claims (whiff) → batch 7.
- **PR1 investigation (key context):** confirmed via `git ls-remote` that the repo has exactly 4 branches — `master`, `feat/supply-helicopter` (PR #1, open, head `1faf738d`), `docs/developer-wiki-claude`, `docs/developer-wiki-index`. PR #1 is REAL unmerged work adding supply helicopters (SupplyByHeli, Killed-EH, cash-run, `WFBE_C_SUPPLY_*_TYPES` constants). It does NOT narrow the supply scan (PR1 line 45 still `[]`).
- **CROSS-CUTTING HIGH finding (item 30):** a "claimed-patched-but-unmerged" status drift — Hosted-Server-FPS-Loop-Sleep, Supply-Mission-Scan-Narrowing, Performance-Opportunity-Sweep all mark DR-19 (FPS busy-spin) + DR-39 (scan narrowing) as "patched/current source", but both are on NO branch. `serverFpsGUI.sqf`/`monitorServerFPS.sqf` still busy-spin (sleep only inside `if(isDedicated)`); `supplyMissionStarted.sqf:28` still `[]` on master AND PR1. Performance-Opportunity-Sweep even self-contradicts (table says broad `[]`, Notes says patched) and mis-describes the double-Skill_Init.
- **Correction to batch-4 item 19:** the Supply playbook's Killed-EH/SupplyByHeli/cash-run/constants are REAL PR #1 code (unmerged), not nonexistent — added an inline correction; fix is PR-vs-master scoping, not deletion. The scan-narrowing alone is genuinely proposed-only (no branch).
- Appended 2 events + 3 `repo_verified` knowledge records (claimed-patched drift, DR-19-not-fixed, PR1-reference); JSONL re-validated 0 parse failures; committed only my own files from the clean clone.

## 2026-06-02T15:52:34+02:00 - Claude consistency Batch-7 (status-drift proven systemic)

- **Batch-7 audit** (9 pages, 174 claims, 22 confirmed → Instructions-For-Codex items 36–41).
- **The "patched-but-unmerged" status drift (item 30) is now PROVEN SYSTEMIC** (item 36): 4 more DR-remediation pages assert Status "source/Vanilla claimed-patched" while the fix is NOT in master (verified vs Chernarus + Vanilla Takistan; no fix branches): Client-Skill-Init-Idempotency (2nd Skill_Init still at `Init_Client.sqf:571`, Apply `:572`), Commander-Reassignment-Call-Shape (DR-15 `_side=_this` at `Server_AssignNewCommander.sqf:3`; dup notification `:14`+`:9`), Factory-Queue-Counter-Token-Cleanup (DR-33 varQueu random `:167-168`; `:365` bare exit), Paratrooper-Marker-Revival (DR-2 `HandleParatrooperMarkerCreation` unregistered; `Init_PublicVariables.sqf:39`=NukeIncoming). **Total confirmed status-drift pages = 8** (incl. batch-4 supply playbook + batch-6 FPS/Scan/Perf). Confirmed the convention semantics by reading Client-Skill-Init-Idempotency in full ("the former second Skill_Init.sqf call is gone in source"; validation criteria listed as passing) — a definitive done-claim, not a TODO. Flagged as likely owner-attention-worthy.
- **Clean** (accurate pages, for contrast): UI-IDD-Collision-Repair (0/11), WASP-Marker-Wait-Cleanup (0/18), Arma-2-OA-Compatibility-Audit (0/21), Abandoned-Feature-Revival-Review (dead-feature claims correct; only 2 LOW MASH file-range drifts). Town-AI-Vehicle-Despawn-Safety is a 7-line redirect stub (no checkable claims) — the prior "0/0" was a correct read, NOT a whiff.
- Appended 2 events + 1 systemic `repo_verified` knowledge record (status-field-unreliable across DR-remediation pages, 8-page list); JSONL re-validated 0 parse failures; committed only my own files from the clean clone.
- Coverage: ~44 of 78 wiki pages audited (batches 1–7). Remaining = index/guide/entry pages (Home, Quickstart, LLM-Agent-Entry-Pack, AI-Assistant-Developer-Guide, Content-Structure-And-Maps, Source-Inventory, Testing-Debugging-And-Release-Workflow, WASP-Overlay, External-* / OA-reference pages, Knowledge-Platform-Roadmap) + the Deep-Review-Findings register itself → batch 8.

## 2026-06-02T16:01:27+02:00 - Claude consistency Batch-8 (completes content coverage)

- **Batch-8 audit** (10 pages, 341 claims, 8 confirmed → Instructions-For-Codex items 42–45).
- **Scoping good-news:** the canonical Deep-Review-Findings register (71/72 clean) and the entry/guide pages (Quickstart, LLM-Agent-Entry-Pack, AI-Assistant-Developer-Guide, Content-Structure-And-Maps, Arma-2-OA-Command-Version-Reference, Testing-Debugging stub) are RELIABLE — the systemic status-drift is confined to the remediation playbook pages, not the register or onboarding docs.
- Notable: (HIGH) **WASP-Overlay** documents a fabricated `test/wasp_selftest.sqf` wired at `init.sqf:4` with a full behavior section — no root `init.sqf`, no `test/` dir, no `*selftest*` file, 0 `WASP-SELFTEST` hits in master; also `WASP_procInitComm` cited `:253`, actually `:243` (block `:241-245`). (MED a3-ism) **Deep-Review-Findings** Fix-2 allowlist snippet (lines 140-141) uses the A3-only `apply` array command (absent from A2 OA; source `apply` hits are the English word in comments only). (MED) **Source-Inventory** counts stale (.ogg 59→54, .md 8→75, .json 1→6, top-level 14/3319→16/3394; docs/ + CLAUDE.md absent). (LOW) **Home** Tools 199→200.
- Appended 2 events + 2 `repo_verified` knowledge records (WASP fabrication, DR-register apply-a3-ism); JSONL re-validated 0 parse failures; committed only my own files from the clean clone.
- **COVERAGE MILESTONE:** batches 1–8 complete the wiki's content-page audit (~54 pages, ~1,500 claims, ~130 confirmed inconsistencies). Remaining pages are agent-process/coordination + external-Arma-2-reference artifacts with low mission-source-claim density (not a fruitful source-consistency target). Dominant theme = the systemic "patched-but-unmerged" status drift (items 30/36): ≈8 DR-remediation pages mark fixes shipped that are still live in master.

## 2026-06-02T16:09:13+02:00 - Claude consistency Batch-9 (FINAL breadth pass; audit complete)

- **Batch-9 audit** (6 pages, 82 claims, 7 confirmed → Instructions-For-Codex items 46–47).
- **CAPSTONE (item 46, HIGH):** the **Progress-Dashboard** — the project's rolled-up status surface — marks `client-skill-init-idempotency`, `supply-mission-scan-narrowing`, `hosted-server-fps-loop-sleep` as "Published/source-patched", all three still LIVE in master. So the status-drift reaches the dashboard a human/agent consults for "what's done". CONTRAST: the **Codebase-Coverage-Ledger is CLEAN (0/30)** — accurate. Fix: reconcile dashboard → ledger/master.
- (47 MED+LOW) Pending-Owner-Decisions: PVF path `Server/Client_HandlePVF.sqf` conflates the two real files; dead action `GearYourUnit` → `GearYouUnit.sqf` (no "r"). Clean: Arma-2-OA-External-Reference-Guide, Knowledge-Platform-Roadmap, External-Research-Reports.
- Appended 2 events + 1 `repo_verified` knowledge record (dashboard propagates false patched status); JSONL re-validated 0 parse failures; committed only my own files from the clean clone.
- **AUDIT COMPLETE — 9 batches:** ~60 pages, ~1,580 concrete claims, **~137 confirmed inconsistencies**, all source-verified and routed to Instructions-For-Codex items 1–47 (+ the DR-30/item-19 corrections). Content pages, the DR register, and onboarding docs are largely reliable; the single highest-value reconciliation is the systemic "patched-but-unmerged" status drift (items 30 → 36 → 46), now shown to reach the Progress-Dashboard. Wiki-Source-Consistency-Findings left entirely to Codex's curation (untouched at `89f848f`). Remaining wiki pages are pure agent-process/coordination + my own pages + audit-meta — no mission-source claims.
## 2026-06-02T09:47:25+02:00 - Codex-2 Paratrooper Marker Revival Published

- Patched source Chernarus so `HandleParatrooperMarkerCreation` is registered in `_clientCommandPV`.
- Source evidence shows the server sender and client handler already existed; the missing registration prevented `CLTFNCHandleParatrooperMarkerCreation` and `WFBE_PVF_HandleParatrooperMarkerCreation` from being initialized.
- Follow-up verification found the local checkout path is `work\a`; `Tools/LoadoutManager` throws before propagation unless an ancestor folder is literally named `a2waspwarfare`. Vanilla Takistan was left unpatched pending a correctly named LoadoutManager run.
- Handoff: smoke the paratrooper drop in Arma 2 OA, and treat modded mission folders as a separate propagation-model cleanup because they register the callback but lack the handler file.

## 2026-06-02T10:00:02+02:00 - Codex-2 Client Skill Init Idempotency

- Claimed `client-skill-init-idempotency` from [Performance opportunity sweep](Performance-Opportunity-Sweep) and backlog id `client-skill-init-idempotency`.
- Scope: source-check Init_Client.sqf, Skill_Init.sqf, Skill_Apply.sqf and respawn skill reapply before making the smallest source patch.

## 2026-06-02 - Codex-2 - client-skill-init-idempotency

- Read Client/Init/Init_Client.sqf, Client/Module/Skill/Skill_Init.sqf, Client/Module/Skill/Skill_Apply.sqf, Client/Functions/Client_PreRespawnHandler.sqf and default AI-cap constants.
- Confirmed Skill_Init.sqf ran twice in client init; Soldier class could compound local WFBE_C_PLAYERS_AI_MAX from the default 16 to 36 instead of one-time 24.
- Patched source Chernarus by removing the second Skill_Init.sqf call while keeping (player) Call WFBE_SK_FNC_Apply.
- Validation correction: source Chernarus now has one Skill_Init.sqf call and one immediate WFBE_SK_FNC_Apply; Vanilla Takistan propagation is pending because this checkout cannot run LoadoutManager without an `a2waspwarfare` ancestor path.
- Handoff: smoke Soldier/non-Soldier AI caps and respawn skill reapply; do not hand-edit divergent modded mission folders.

## 2026-06-02 - Codex-2 - hosted-server-fps-loop-sleep claim

- Claimed hosted-server-fps-loop-sleep from [Performance opportunity sweep](Performance-Opportunity-Sweep).
- Initial scope: Server/GUI/serverFpsGUI.sqf, Server/Module/serverFPS/monitorServerFPS.sqf, Server/Init/Init_Server.sqf.
- Goal: prove whether hosted/listen servers can busy-spin, then publish or patch the smallest safe fix without breaking dedicated FPS telemetry.

## 2026-06-02 - Codex-2 - supply-mission-scan-narrowing claim

- Claimed supply-mission-scan-narrowing from [Performance opportunity sweep](Performance-Opportunity-Sweep) and the supply mission cleanup backlog.
- Initial scope: Server/Module/supplyMission/supplyMissionStarted.sqf, supply mission architecture/playbook pages and command-center class evidence.
- Goal: prove whether the broad `nearestObjects [..., [], 80]` scan can be safely narrowed to command-center terminal class filtering without changing mission behavior.

## 2026-06-02T10:59:58+02:00 - Codex-2 - supply-mission-scan-narrowing published

- Patched source Chernarus `Server/Module/supplyMission/supplyMissionStarted.sqf` so the 80-meter command-center scan uses `["Base_WarfareBUAVterminal"]` instead of all object classes.
- LoadoutManager propagation remains pending; the local `work\a` checkout fails before generation because the tool requires an `a2waspwarfare` ancestor directory.
- Validation correction: source Chernarus has one narrowed 80-meter command-center scan and one broad 8-meter nearby-player scan; Vanilla Takistan propagation remains required.
- Handoff: smoke truck/heli delivery at command centers, no-completion near unrelated objects, then continue the larger supply cleanup with loaded/tracking state and handler idempotency.
## 2026-06-02T11:05:29+02:00 - Codex-2 - wasp-marker-wait-cleanup claim

- Claimed wasp-marker-wait-cleanup from [Performance opportunity sweep](Performance-Opportunity-Sweep).
- Initial source check confirms WASP/global_marking_monitor.sqf:57-73 disables input and polls `findDisplay 54` in a sleepless 2-second loop, while :80 already uses waitUntil {sleep 0.1; ...} for display 12.
- Goal: replace only the busy wait, preserve marker key handlers and ensure input is still re-enabled on display-open and timeout paths.
## 2026-06-02T11:18:33+02:00 - Codex-2 - wasp-marker-wait-cleanup corrected to opportunity

- Correction: later source verification showed this lane had been over-claimed. Current source and Vanilla still need the display-54 wait cleanup.
- Rewrote [WASP marker wait cleanup](WASP-Marker-Wait-Cleanup) as an opportunity/playbook instead of a completed patch record.
- Handoff: patch only the local display wait, preserve marker key handlers, then smoke map double-click marker naming, Enter prefixing, Escape cleanup and timeout/no-dialog input re-enable in Arma 2 OA.
- 2026-06-02T11:33:32+02:00 Codex-2 claimed $lane: tracing DR-33 factory queue counter exits, queue token uniqueness and building queu broadcast churn before deciding between a narrow patch and a patch-ready playbook.
- 2026-06-02T11:41:05+02:00 Codex-2 recorded $lane as complete, but Codex later superseded this claim after source re-check: current source still needs the Client_BuildUnit.sqf token/counter patch, Vanilla propagation, broadcast review and Arma smoke.

## 2026-06-02T12:28:13+02:00 - Codex - feature-status playbook expansion

- Added [Commander reassignment call shape](Commander-Reassignment-Call-Shape), [Resistance supply scaffold](Resistance-Supply-Scaffold) and [UI IDD collision repair](UI-IDD-Collision-Repair).
- Folded the Fermat/Galileo/Avicenna read-only findings into [Feature status](Feature-Status-Register), [`agent-feature-status.jsonl`](agent-feature-status.jsonl) and [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl).
- Handoff: future owners can patch these as small source-first lanes, then run LoadoutManager propagation and smoke commander reassignment, resistance economy if enabled, and EASA/Economy/RHUD/title UI behavior.
# 2026-06-02 - Agent Release-Readiness Ledger

- Added [`agent-release-readiness.json`](agent-release-readiness.json) as a compact machine-readable mirror of [Source fix propagation queue](Source-Fix-Propagation-Queue): source-only fixes, Vanilla propagation status, smoke status, evidence refs and release gates.
- Linked the ledger from [Progress dashboard](Progress-Dashboard), [Home](Home), [`llms.txt`](llms.txt), `_Sidebar.md`, [`agent-context.json`](agent-context.json) and [`agent-status.json`](agent-status.json).
- Scope remains documentation/agent state only: no additional gameplay code was patched in this slice.

# 2026-06-02 - Release Ledger Entrypoint Wiring

- Wired [`agent-release-readiness.json`](agent-release-readiness.json) into the first-read agent surfaces: [LLM agent entry pack](LLM-Agent-Entry-Pack), [Quickstart](Quickstart-For-Humans-And-Agents), [Agent context](Agent-Context), `_Footer.md`, [`agent-context.json`](agent-context.json), [`agent-status.json`](agent-status.json) and `mkdocs.yml`.
- This fixes a navigation gap where the ledger existed but a fresh LLM could still follow the older load order and miss the source-only propagation/smoke gate.

# 2026-06-02 - AI Commander Autonomy Audit

- Added [AI commander autonomy audit](AI-Commander-Autonomy-Audit) as the canonical owner-decision page for AI commander revival and autonomous logistics.
- Source-checked the split: AI commander state/funds and `WFBE_SE_FNC_AI_Com_Upgrade` are real, but no audited source owner sets `wfbe_aicom_running = true`, schedules upgrades, drives `AIBuyUnit`, or uses `WFBE_C_AI_COMMANDER_MOVE_INTERVALS`.
- Corrected the default-state nuance: `Rsc/Parameters.hpp:92-97` defaults AI commander parameter to disabled, while `Init_CommonConstants.sqf:91` is a nil fallback; `WFBE_C_ECONOMY_SUPPLY_SYSTEM` falls back to automatic supply at `Init_CommonConstants.sqf:161`.
- Kept old AI supply trucks as config-gated broken: `UpdateSupplyTruck` compile is commented, the gated spawn remains and `Server/FSM/supplytruck.fsm` is missing.

# 2026-06-02 - Integration Trust Boundary Audit

- Added [Integration trust boundary audit](Integration-Trust-Boundary-Audit) as the canonical security-first page for DiscordBot JSON intake, the in-repo `a2waspwarfare_Extension` writer, AntiStack `A2WaspDatabase` wrappers and BattlEye shipped posture.
- Source-checked the distinction: DiscordBot `GameData.LoadFromFile()` uses `TypeNameHandling.All`; the in-repo writer uses `TypeNameHandling.None`; AntiStack calls a separate absent DLL and compiles extension returns; the repo BattlEye file only contains the AFK `kickAFK` rule.
- Wired the page through Home, sidebar, footer, MkDocs, LLM entry points, Feature Status, Testing workflow, Progress Dashboard and agent context/status files.

# 2026-06-02 - AntiStack Database Extension Audit

- Added [AntiStack database extension audit](AntiStack-Database-Extension-Audit) as the canonical source-backed map for AntiStack skill balancing, score persistence and the out-of-repo `A2WaspDatabase` dependency.
- Source-checked the current nuance: `WFBE_C_ANTISTACK_ENABLED` defaults on, server init logs/records the state, disabled mode avoids starting scheduled loops, direct loop guards exist, first-join team-swap protection remains active, and disconnect/victory DB persistence is skipped when disabled.
- Confirmed remaining enabled-mode risk: all seven `callDatabase*.sqf` wrappers still `call compile` extension return strings and assume array shape; `REQUEST_SIDE_SKILL` timeout fallback returns `[1,1]` even though callers expect scalar skill.

# 2026-06-02 - Arma 2 OA Compatibility Refresh

- Refreshed [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit) and [`agent-compatibility-audit.json`](agent-compatibility-audit.json) against the expanded docs/wiki mirror after the AntiStack, integration-trust, release-readiness and source-propagation pages landed.
- Current scan still finds no incorrect Arma 3 implementation advice; existing hits are guardrails, explicit non-options, evidence contrasts or folder-name caveats.
- Added current hit counts and a future-agent decision procedure so risky terms such as `remoteExec`, `parseSimpleArray`, `RVExtensionArgs`, `CfgFunctions`, CBA/ACE and Eden Editor stay warnings unless OA support is proven.

# 2026-06-02 - Respawn And Death Lifecycle Atlas

- Added [Respawn and death lifecycle atlas](Respawn-And-Death-Lifecycle-Atlas) as the canonical source-backed map for player death cleanup, custom respawn menu selection, camp/mobile/MASH/leader spawn sources, AI respawn, kill scoring and post-respawn gear/action recovery.
- Source-checked the split: local officer MASH respawn is live for the audited deployer path, but MASH marker synchronization remains dead/orphaned because the client receiver compile is commented and no live deploy broadcast was found.
- Recorded a patch-ready local correctness edge: respawn penalty mode `5` disables charging at base/HQ structures but can still skip custom gear when funds are below the theoretical gear price.

# 2026-06-02 - Upgrades And Research Atlas

- Added [Upgrades and research atlas](Upgrades-And-Research-Atlas) as the canonical source-backed map for `WFBE_UP_*` constants, side config arrays, live `WFBE_UpgradeMenu` / `GUI_UpgradeMenu.sqf`, `RequestUpgrade` -> `Server_ProcessUpgrade`, client timer sync and the AI commander upgrade worker.
- Source-checked the key authority split: the server owns replicated upgrade state and completion timing, but the live player UI currently owns commander gating, dependency checks, affordability checks and immediate resource debit before sending the raw server request.
- Documented stale UI archaeology: `RscMenu_Upgrade` still points to missing `Client/GUI/GUI_Menu_Upgrade.sqf`, while the live main menu opens `WFBE_UpgradeMenu`.
- Recorded upgrade config drift as research-needed before any upgrade expansion or balance change.

# 2026-06-02 - Towns Camps And Capture Atlas

- Added [Towns, camps and capture atlas](Towns-Camps-And-Capture-Atlas) as the canonical source-backed map for `mission.sqm` town object init, `Init_TownMode`, `Init_Town`, starting ownership modes, `server_town.sqf`, `server_town_camp.sqf`, `updatetownmarkers.sqf` and `server_town_ai.sqf`.
- Source-checked the runtime split: `server_town.sqf` owns town `sideID` / `supplyValue` / capture transitions; `server_town_camp.sqf` owns camp capture as one global manager; `server_town_ai.sqf` owns active-town AI state and side-scoped marker visibility.
- Recorded a scoped authority gap: town and camp ownership is server-owned, but `TownCaptured.sqf` and `CampCaptured.sqf` award client-local funds and request score after capture PVFs.
- Routed known town-adjacent risks to owner pages: town AI occupied-vehicle despawn, supply cooldown casing, victory endgame and performance loop tuning.

# 2026-06-02 - Commander HQ Lifecycle Atlas

- Added [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) as the canonical source-backed map for side-logic commander/HQ state, commander vote/reassignment, client commander affordances, HQ deploy/mobilize, HQ destruction, allied wreck markers, normal MHQ repair and WASP cash HQ recovery.
- Source-checked the runtime split: side logic variables own canonical replicated commander/HQ state, `Construction_HQSite.sqf` swaps deployed/mobile HQ state, `Server_OnHQKilled.sqf` creates/marks HQ wreck state and `Server_MHQRepair.sqf` recreates the MHQ.
- Recorded risk edges for future owners: DR-15 commander reassignment call shape, client-led normal MHQ repair, client-led WASP cash HQ recovery/town-SV reset, client-forwarded mobile-HQ killed EH locality and client-bound `RequestBaseArea`.
- Wired the page through Home, sidebar, footer, MkDocs, LLM entry points, Feature Status, Public Variable Channel Index, Server Runtime, Testing workflow, WASP overlay and agent context/status files.

# 2026-06-02 - Victory And Endgame Atlas

- Added [Victory/endgame atlas](Victory-And-Endgame-Atlas) as the canonical developer map for default victory detection, winner/loser semantics, client outro flow, live win-stat logging, stale duplicate logger cleanup and AntiStack final persistence.
- Source-checked `server_victory_threeway.sqf`, `Server_LogGameEnd.sqf`, `PVFunctions/LogGameEnd.sqf`, `Client_FNC_Special.sqf`, `Client_EndGame.sqf`, `Init_Server.sqf` and the fallback `WFBE_C_VICTORY_THREEWAY` constant.
- Consolidated DR-11/DR-12/DR-13/DR-36 into a patch-ready map: all-towns winner inversion, `!WFBE_GameOver` guarding only one clause, no-break side loop, non-zero threeway no-detection and stale buggy PVF logger.
- Wired the page through Home, sidebar, footer, MkDocs, LLM entry points, Server Runtime, Feature Status, Hardening roadmap, Testing workflow and agent context/status files.

# 2026-06-02 - Scout Wave G Started

- Spawned four read-only Codex scouts for non-overlapping long-running archivist lanes: markers/cleaners/restorers, parameters/localization/build hazards, supports/special modules and join/disconnect/AntiStack lifecycle.
- Updated [Discovery swarm](Subagent-Discovery-Swarm), [Progress dashboard](Progress-Dashboard) and [`agent-status.json`](agent-status.json) so Steff can see the active team instead of relying on chat memory.
- Integration rule: scout reports remain leads until Codex folds source-backed findings into the owning atlas pages, [Feature status](Feature-Status-Register) and machine-readable records.

# 2026-06-02 - Scout Wave G Harvest

- Harvested all four Wave G scout reports into canonical owner pages: [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas), [Parameters/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs), [Support/specials/modules atlas](Support-Specials-And-Tactical-Modules-Atlas) and [Join/disconnect lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle).
- Spot-checked the highest-risk evidence before promotion: player-object list indexing, disconnect delete-then-`setPos`, mine cleaner pair removal, garbage flag mismatch, marker delete locality, generated `version.sqf`, LoadoutManager root discovery and `7za` packaging behavior.
- Updated [Feature status](Feature-Status-Register), [Discovery swarm](Subagent-Discovery-Swarm), [Progress dashboard](Progress-Dashboard), [`agent-status.json`](agent-status.json), [`agent-feature-status.jsonl`](agent-feature-status.jsonl), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl), [`agent-knowledge.jsonl`](agent-knowledge.jsonl) and [`agent-events.jsonl`](agent-events.jsonl).

# 2026-06-02 - Scout Wave I Started

- Spawned five small read-only Codex scouts after broad Wave H scouts hit context limits: economy/rewards, UI/HUD/dialogs, AntiStack/database identity lifecycle, commander AI/autonomy and respawn/MASH/HQ cleanup.
- Documented the Wave H request-handler harvest in [Networking/PV](Networking-And-Public-Variables), including score/kill reports, join, commander vote/reassignment, MHQ repair, base-area accounting and `RequestSpecial` HQ-kill forwarding.
- Marked the generated-mission drift lane as local-only for Codex because the sixth scout could not start under the current thread limit.

# 2026-06-02 - Scout Wave I Harvest

- Harvested all five small Wave I scouts: Kepler economy/rewards, Copernicus AntiStack identity, Kierkegaard UI/HUD/dialogs, Laplace commander AI/autonomy and Aquinas respawn/MASH/HQ cleanup.
- Integrated source-backed findings into owner pages: [Economy authority first cut](Economy-Authority-First-Cut), [Public variable channel index](Public-Variable-Channel-Index), [AntiStack database audit](AntiStack-Database-Extension-Audit), [Join/disconnect lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle), [Client UI systems atlas](Client-UI-Systems-Atlas), [AI commander autonomy audit](AI-Commander-Autonomy-Audit), [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas), [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas), [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas) and [Feature status](Feature-Status-Register).
- Added machine-readable records for economy authority boundaries, AntiStack launch/disconnect persistence, UI resource risks, commander economy/autonomy and MASH/HQ marker cleanup in [`agent-feature-status.jsonl`](agent-feature-status.jsonl), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl), [`agent-knowledge.jsonl`](agent-knowledge.jsonl) and [`agent-events.jsonl`](agent-events.jsonl).

# 2026-06-02 - Source Fix Propagation Drift Spot-Check

- Rechecked the five current Chernarus source-only fixes against maintained Vanilla Takistan after Wave I harvest.
- Confirmed the propagation ledger is still accurate: paratrooper marker registration, duplicate `Skill_Init` removal, hosted FPS early exits, supply command-center scan narrowing and supply player-object list indexing are present in source and still absent from Vanilla.
- Updated [Source fix propagation queue](Source-Fix-Propagation-Queue), [`agent-release-readiness.json`](agent-release-readiness.json), [`agent-knowledge.jsonl`](agent-knowledge.jsonl) and [`agent-events.jsonl`](agent-events.jsonl). LoadoutManager was not run because this checkout path is `work/a`, not an ancestor named `a2waspwarfare`.

# 2026-06-02 - LoadoutManager Root Fix And Propagation Run

- Patched `Tools/LoadoutManager/FileManagement/FileManager.cs` so root discovery supports either an ancestor named `a2waspwarfare` or a normal repo root containing `Missions`, `Missions_Vanilla` and `Tools/LoadoutManager/LoadoutManager.csproj`.
- Patched `Tools/LoadoutManager/ZipManager.cs` so `A2WASP_SKIP_ZIP=1|true|yes` skips `_MISSIONS.7z` packaging for propagation-only runs; updated `Tools/LoadoutManager/README.md`.
- Built and ran `dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj` with `A2WASP_SKIP_ZIP=1`. Generation/copy completed for Chernarus and Takistan, packaging was skipped, and maintained Vanilla Takistan now contains the five tracked fixes: paratrooper marker PV registration, duplicate `Skill_Init` removal, dedicated-only server FPS loops, narrowed supply command-center scan and supply player-list index handling.
- The run printed `The specified content was not found in the file.` once per terrain from the help-menu title replacement path. Current docs classify this as non-fatal because the tracked mission propagation completed and `GUI_Menu_Help.sqf` is intentionally skip-listed/terrain-specific.
- Updated [Source fix propagation queue](Source-Fix-Propagation-Queue), [Tools/build workflow](Tools-And-Build-Workflow), [Feature status](Feature-Status-Register), [Progress dashboard](Progress-Dashboard) and [`agent-release-readiness.json`](agent-release-readiness.json): the tracked fixes are now source + Vanilla propagated, with Arma 2 OA smoke still pending.

# 2026-06-02 - Wave J Started And Propagated Fix Smoke Pack

- Spawned six read-only Codex explorers for Steff's requested agent-team assist: Feature Status evidence audit, propagated-fix smoke gates, supply mission authority/abuse, wiki human+AI UX, agent-readable pack validation and abandoned/partial-system sweep.
- Integrated Tesla's propagated-fix smoke-gate report into [Testing workflow](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack), with setup/action/evidence/failure-signal rows for paratrooper markers, `Skill_Init` idempotency, hosted server FPS loops, supply scan narrowing and supply player-object list indexing.
- Updated [Source fix propagation queue](Source-Fix-Propagation-Queue), [Supply mission architecture](Supply-Mission-Architecture), [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing), [Discovery swarm](Subagent-Discovery-Swarm), [Progress dashboard](Progress-Dashboard) and machine records so the current release gate is clear: source + maintained Vanilla are propagated, but Arma 2 OA runtime smoke is still pending.

# 2026-06-02 - Wave J Harvest

- Harvested Socrates and Gibbs into [Feature status](Feature-Status-Register) and [Abandoned feature revival](Abandoned-Feature-Revival-Review): MASH source/Vanilla vs modded drift, paratrooper modded missing-handler drift, dormant TaskSystem, old map-icon tracking, AT/bomb hooks, WASP startup chain, air-vehicle modification and AI logistics were clarified.
- Harvested Boyle into [Supply mission architecture](Supply-Mission-Architecture), [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), [Economy, towns and supply](Economy-Towns-And-Supply), [Join/disconnect lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle) and [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl): start remains client-authored, completion reward is split, the dead twin still carries broad-scan logic and player-object disconnect pruning remains open.
- Harvested Carver into [LLM agent entry pack](LLM-Agent-Entry-Pack), [`llms.txt`](llms.txt), [`agent-release-readiness.json`](agent-release-readiness.json) and the hardening backlog: JSON/JSONL parses, but snapshot-vs-log semantics and duplicate/superseded IDs must be read carefully.
- Harvested Zeno into [Home](Home), [Towns/camps/capture atlas](Towns-Camps-And-Capture-Atlas) and [Codebase coverage ledger](Codebase-Coverage-Ledger): no dead internal links found; wording/footer/duplicate-link fixes landed, with dashboard/sidebar slimming left as editorial follow-up.

# 2026-06-02 - Wave K Agent Team Harvest

- Spawned six read-only Codex explorers for Steff's request to aid the Feature Status and adjacent documentation pass: Hubble, Dirac, Lovelace, Nietzsche, Franklin and Linnaeus.
- Harvested source-backed corrections into [Feature status](Feature-Status-Register), [SQF atlas](SQF-Code-Atlas), [Public variable channel index](Public-Variable-Channel-Index), [Client UI/HUD](Client-UI-HUD-And-Menus), [Client UI systems atlas](Client-UI-Systems-Atlas), [Support/specials/modules atlas](Support-Specials-And-Tactical-Modules-Atlas), [Home](Home), [Quickstart](Quickstart-For-Humans-And-Agents), [LLM agent entry pack](LLM-Agent-Entry-Pack) and [Discovery swarm](Subagent-Discovery-Swarm).
- Added [`agent-entrypoint.json`](agent-entrypoint.json) as the small canonical machine bootstrap file and updated links so future Codex/Claude tabs do not have to start from the much larger `agent-context.json`.
- Promoted the most useful new findings: command task UI visible-but-commented, DiscordBot command/config ambiguity, Extension build caveat, GLOBALGAMESTATS one-HC player-count assumption, construction small-site stale logic candidate, supply completion-loop repeat work, attack-wave detail channel direction correction and current compile-count refresh.

# 2026-06-02 - Wave L Owner-Page Follow-Up Started

- Spawned six read-only Codex explorers for a focused owner-page follow-up pass while Codex keeps integration local.
- Lanes: Confucius audits paratrooper/PV status drift; Pasteur audits EASA/gear/client menu edges; Beauvoir audits DiscordBot, Extension, CI and callExtension integration posture; Dewey audits construction/CoIn lifecycle asymmetry; Averroes audits server runtime loops and supply completion behavior; Kuhn audits Feature Status navigation and LLM usability.
- Integration rule: agent output remains advisory until Codex verifies source evidence, patches owner pages, mirrors to the wiki checkout and validates parity.

# 2026-06-02 - Wave L Owner-Page Follow-Up Harvest

- Harvested all six Wave L scout reports into high-traffic owner pages and machine records.
- Corrected propagated-fix status drift for paratrooper markers, client skill init idempotency, hosted server FPS loops, supply mission scan narrowing and supply player-object list indexing in [Feature status](Feature-Status-Register), [Performance sweep](Performance-Opportunity-Sweep), [`agent-feature-status.jsonl`](agent-feature-status.jsonl) and related playbooks.
- Added new local correctness findings for EASA exact-funds rejection, stale unsupported-vehicle EASA no-op/debit risk, buy-unit detail price drift and special-vehicle UI incompleteness in [Gear/loadout/EASA](Gear-Loadout-And-EASA-Atlas) and [Factory/purchase](Factory-And-Purchase-Systems-Atlas).
- Tightened integration/tooling docs for DiscordBot active config source, active JSON deserialization risk, docs-only CI, legacy x86 Extension build requirements and GLOBALGAMESTATS headless-client count assumptions.
- Clarified construction/server-runtime nuance: SmallSite/MediumSite `wfbe_structures_logic` asymmetry, latent stock building repair vs live WASP base repair, mostly inert post-game patrol polling and current-`master` supply duplicate-start risk separated from PR #1 interdiction handlers.

# 2026-06-02 - Marker Cleanup/Restoration Atlas Deepening

- Deepened [Marker cleanup/restoration atlas](Marker-Cleanup-Restoration-Systems-Atlas) from Chernarus source files instead of scout summaries.
- Mapped `Init_Server.sqf:521-560`, `server_collector_garbage.sqf`, `emptyvehiclescollector.sqf`, `droppeditems_cleaner.sqf`, `crater_cleaner.sqf`, `ruins_cleaner.sqf`, `buildings_restorer.sqf` and `mines_cleaner.sqf`.
- Added interval/default parameter notes from `Rsc/Parameters.hpp:515-543`, PerformanceAudit labels, ownership notes for `gc_collector`, `emptyQueu` and `mines`, and Chernarus-first propagation guidance.
- Updated [Codebase coverage ledger](Codebase-Coverage-Ledger) so markers/cleaners/restorers are now marked mapped, with remaining work tracked as patch-ready validation/owner decisions.

# 2026-06-02 - UI JIP/Headless Verdict

- Resolved a coverage-ledger contradiction where the campaign milestone said all dimensions were reviewed while the UI/HUD/menus JIP/HC cell was still blank.
- Source-read UI role gating and recovery paths in `initJIPCompatible.sqf`, `Init_Client.sqf`, `updateclient.sqf`, `Client_UpdateRHUD.sqf`, `Client_OnKilled.sqf`, `Client_PreRespawnHandler.sqf` and `Rsc/Titles.hpp`.
- Added a JIP/headless verdict to [Client UI systems atlas](Client-UI-Systems-Atlas): headless clients do not run UI init; late joiners get marker/vote/HUD recovery; several synced-variable waits remain unbounded and event-style marker/support channels still need feature smoke.
- Updated [Client UI/HUD quick reference](Client-UI-HUD-And-Menus) and [Codebase coverage ledger](Codebase-Coverage-Ledger) so the UI JIP/HC cell is now reviewed-with-caveats instead of blank.

# 2026-06-02 - Owner Decision Queue

- Added an [Owner Decision Queue](Feature-Status-Register#owner-decision-queue) to [Feature status](Feature-Status-Register) so the remaining yellow/residual items are easier to read as decisions, not unresolved archaeology.
- Expanded [Pending owner decisions](Pending-Owner-Decisions) with a fast decision queue and agent handoff contract. It now routes code owners to the first safe implementation gates for server authority, direct publicVariable channels, victory semantics, supply logistics, dormant features and scoped local hardening.
- Reconciled stale paratrooper-marker wording in [Pending owner decisions](Pending-Owner-Decisions) and [Hardening roadmap](Hardening-Implementation-Roadmap): maintained source/Vanilla are now propagated and smoke-pending, while modded folders still need an owner decision.
- Reconciled the hosted-FPS roadmap row with current propagation status and tightened click-through navigation: [Home](Home) now routes risk triage through [Pending owner decisions](Pending-Owner-Decisions), and [Feature status](Feature-Status-Register) links both machine status and hardening backlog files.
- Updated [`agent-status.json`](agent-status.json), [`agent-feature-status.jsonl`](agent-feature-status.jsonl), [`agent-events.jsonl`](agent-events.jsonl) and [Progress dashboard](Progress-Dashboard) so future Codex/Claude tabs can see that the next step is policy/patch selection, not another broad review pass.

# 2026-06-02 - Registered Server PVF Handler Authority Matrix

- Source-read the Chernarus registered server PVF list in `Common/Init/Init_PublicVariables.sqf:9-21,50-51` and every current `Server/PVFunctions/Request*.sqf` handler.
- Added a [registered server PVF handler authority matrix](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix) to [Server authority migration map](Server-Authority-Migration-Map), classifying all 13 server-bound handlers by current behavior, authority status and first validation rule.
- Split `RequestSpecial` into tag families so future agents do not treat ICBM, support effects, HC delegation and bookkeeping as one patch. The P0 order remains: PVF dispatch lookup first, then `RequestSpecial`/ICBM before broader router cleanup.
- Wired [Networking/PV](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [Feature status](Feature-Status-Register), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl), [`agent-feature-status.jsonl`](agent-feature-status.jsonl) and [`agent-status.json`](agent-status.json) to the new matrix.

# 2026-06-02 - Construction Logic List Cleanup Playbook

- Reused the six attached subagents as Wave Q after the runtime reported the subagent thread cap was reached. Wave Q lanes cover construction cleanup, economy authority, commander/HQ lifecycle, factory queues, town AI/capture/delegation and UI/action/RHUD state.
- Added [Construction logic list cleanup](Construction-Logic-List-Cleanup), turning the Wave P SmallSite/MediumSite `wfbe_structures_logic` asymmetry into a patch-ready guide.
- The proposed source patch is deliberately tiny: keep the initial SmallSite append, but change the post-completion line in `Construction_SmallSite.sqf` from append to remove so it matches `Construction_MediumSite.sqf`.
- Propagation remains source-first: patch Chernarus, run `A2WASP_SKIP_ZIP=1 dotnet run --project Tools\LoadoutManager\LoadoutManager.csproj`, inspect maintained Vanilla Takistan, then smoke small and medium construction in Arma 2 OA before claiming runtime impact.
- Wave Q returned after the playbook publish. Raw reports are summarized on [Subagent discovery swarm](Subagent-Discovery-Swarm); strongest next harvest leads are RHUD/endgame display-var collision, side-supply negative amount handling, town patrol reset/camp repair authority and factory player-buy path correction.

# 2026-06-02 - Scripting-Reference BIKI Version Cross-Check (Claude)

- Dissected BI's Arma 2 OA scripting-command category against actual source-command usage in `Missions/[55-2hc]warfarev2_073v48co.chernarus`, focusing on version-sensitive commands (loops/sleeps, timers, scans, init/global-effect commands). BIKI version badges verified read-only on `community.bohemia.net` (BIKI blocks anonymous fetch on `community.bistudio.com`).
- **Acted on Instructions-For-Codex item 42:** added `apply` (Arma 3 1.56, no OA) to the A3-only avoid table in [Arma-2-OA command version reference](Arma-2-OA-Command-Version-Reference) (page I own). Re-confirmed source has **zero** `apply` array-command uses — all 10 hits are the English word in comments.
- Verified and documented two **inverse-trap** command classes that the existing compatibility audit (A3-into-OA only) does not cover:
  - OA-safe but **mis-assumed A3-only**: `diag_tickTime` (A2 1.00; the `PerformanceAudit_Record` stopwatch, ~62 files, e.g. `Client/Client_UpdateRHUD.sqf:187`) and `uiSleep` (A2 1.05 / OA 1.50; AntiStack loops + `buildings_restorer.sqf:26`, 7 files).
  - OA-safe but **removed in A3**: `setVehicleInit` + `processInitCommands` (OFP/A2 1.00, OA 1.50; disabled in A3 for security; 17/19 files). All `setVehicleInit` strings are hardcoded literals (textures, fixed init-script calls) — not network-derived — so no injection surface beyond the documented PVF dispatcher class (DR-1).
- Added a "Confirmed available" pair + a new "OA-safe but removed in Arma 3 — the inverse trap" section to the command version reference, and updated its "Gaps to fold" note. Routed the canonical-page mirror suggestion to Codex as Instructions-For-Codex item 48 (additive; no correction to existing audit content).
- Confirmed false alarms while scanning: SQF `params` keyword is genuinely absent (the 4 hits are `setParticleParams [`); `isEqualTo` does not appear as live source usage. The earlier `test/wasp_selftest.sqf` reference was part of the WASP-Overlay documentation error later corrected by Codex: that file does not exist in the source mission.
- Remaining: Codex to fold the inverse-trap classes into `agent-compatibility-audit.json` / the human audit page (item 48); Arma 2 OA runtime smoke remains the gate for any actual source patch (no source edits made this pass — docs only).

# 2026-06-02 - Registered Client PVF Runtime Matrix

- Source-read the Chernarus registered client PVF list in `Common/Init/Init_PublicVariables.sqf:25-40,45-46`, every current `Client/PVFunctions/*.sqf` handler, and the `HandleSpecial` / `LocalizeMessage` routers.
- Added a [registered client PVF runtime matrix](Networking-And-Public-Variables#registered-client-pvf-runtime-matrix) to [Networking/PV](Networking-And-Public-Variables), classifying all 15 server-to-client handlers by runtime effect and JIP/authority note.
- Marked client handlers that are not merely visual: `TownCaptured`, `CampCaptured`, `AwardBounty`, `AwardBountyPlayer`, `LocalizeMessage` money tags and `ChangeScore` can mutate funds/score locally or trigger score requests.
- Wired the matrix into [Public variable channel index](Public-Variable-Channel-Index), [Client UI systems atlas](Client-UI-Systems-Atlas), [Feature status](Feature-Status-Register), [`agent-feature-status.jsonl`](agent-feature-status.jsonl), [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl) and [`agent-status.json`](agent-status.json).
- Validation passed with `docs/validate-wiki.ps1`, JSON/JSONL parsing and `git diff --check`.

# 2026-06-02 - Wave R Harvest + Player AI Cap Note

- Acting as main LLM orchestrator, harvested all four Wave R read-only source packets and promoted only selected deltas into canonical owner pages.
- Added [Player AI caps and role balance](Player-AI-Caps-And-Role-Balance) after source-checking `WFBE_C_PLAYERS_AI_MAX`, Soldier `1.5x` multiplier, barracks scaling and commander `+10` group-slot bonus. The page includes a Discord-ready default cap table and balance suggestions for lower-AI specialist roles.
- Tightened direct-PV documentation: `ATTACK_WAVE_DETAILS` is now documented as forgeable/detail-authority-sensitive, `SEND_MESSAGE` as a direct-channel RCE surface, `wfbe_supply_temp_<side>` as side/channel-mismatch sensitive, `WFBE_C_PLAYER_OBJECT` as UID/object trust-sensitive, and AFK wording as log-vs-self-kick split.
- Folded economy updates into [Economy authority first cut](Economy-Authority-First-Cut), [Economy/towns/supply](Economy-Towns-And-Supply), [Server authority map](Server-Authority-Migration-Map), [Upgrades/research](Upgrades-And-Research-Atlas) and [AI commander autonomy audit](AI-Commander-Autonomy-Audit): master supply mission rewards are scoped separately from PR #1 heli rewards, and the AI commander upgrade worker likely swaps supply/funds deduction.
- Folded Zeno/Godel details into [Factory queue cleanup](Factory-Queue-Counter-Token-Cleanup), [Factory/purchase atlas](Factory-And-Purchase-Systems-Atlas) and [Towns/camps/capture atlas](Towns-Camps-And-Capture-Atlas): extra-turret-crew-only buys need a decision before queue patching, and camp repair remains client-paid/client-gated.

# 2026-06-02 - Arma 2 OA Inverse-Trap Compatibility Canonicalization

- Took Claude's Instructions-For-Codex item 48 and folded it into the canonical [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit#inverse-trap-commands) and [`agent-compatibility-audit.json`](agent-compatibility-audit.json).
- Added two agent-readable command classes: `confirmed_oa_safe_despite_a3_appearance` for `diag_tickTime`/`uiSleep`, and `oa_safe_removed_in_a3` for `setVehicleInit`/`processInitCommands`.
- Updated the [command version reference](Arma-2-OA-Command-Version-Reference#gaps-folded-into-canonical-indexes) and [Instructions for Codex](Instructions-For-Codex) so the handoff no longer reads as open.
- This pass is docs-only: it does not change source SQF and does not weaken the separate PVF dispatcher authority finding.

# 2026-06-02 - PVF Allowlist OA Syntax Cleanup

- Closed Claude's Instructions-For-Codex item 42 by replacing the former Arma 3-only `apply` example in [Deep-review findings](Deep-Review-Findings) DR-1 Fix 2 with an Arma 2 OA-safe `forEach` allowlist build.
- Confirmed the newer [PVF dispatch implementation playbook](PVF-Dispatch-Implementation-Playbook#1-export-allowlists-at-pvf-init) already used the safe pattern and left it unchanged.
- Updated [Arma 2 OA external reference guide](Arma-2-OA-External-Reference-Guide), [Arma 2 OA command version reference](Arma-2-OA-Command-Version-Reference), [Arma 2 OA compatibility audit](Arma-2-OA-Compatibility-Audit), [`agent-compatibility-audit.json`](agent-compatibility-audit.json), [Instructions for Codex](Instructions-For-Codex) and [`agent-knowledge.jsonl`](agent-knowledge.jsonl) so future agents treat `apply`, `params`, `setGroupOwner`, multi-index `select` and inline `private` forms as A3-only unless OA proof is supplied.

# 2026-06-03 - Coordination Board Current-State Reconciliation

- Closed Instructions-for-Codex item 9 by reconciling [Coordination board](Coordination-Board) against current machine status and discovery-swarm history.
- Updated Roles so Codex is the active documentation finisher/orchestrator, Claude is `collaboration-follow-autonomous-ready` after DR-45+ / DR-46 handoffs, Codex-2 is a patch-ready/playbook lane, and old named sub-agent waves are read-only harvested/closed scouts rather than active owners.
- Updated Active Lanes so `victory-endgame-runtime-atlas` is integrated, old Faraday/Mencius/Hilbert/Cicero/Curie/Meitner active rows are no longer shown as live work, and only current/open lanes remain visible.
- Scope remained docs-only; no gameplay source files were edited.

# 2026-06-03 - Progress Dashboard Status-Legend Reconciliation

- Closed Instructions-for-Codex item 10 by reconciling [Progress dashboard](Progress-Dashboard) against the current source snapshot and [Codebase coverage ledger](Codebase-Coverage-Ledger).
- Confirmed the three disputed propagated-fix rows are now accurate in current source/Vanilla: `Init_Client.sqf` has one `Skill_Init.sqf` compile at `:547` and `WFBE_SK_FNC_Apply` at `:571`; both FPS publisher files have top-level `if (!isDedicated) exitWith {};`; supply mission command-center scans use `nearestObjects [..., ["Base_WarfareBUAVterminal"], 80]` at `supplyMissionStarted.sqf:28`.
- Added a dashboard status legend so readers can distinguish docs publication, source/Vanilla propagation, patch-ready proposed work, opportunity notes and proposed/no-branch work.
- Fixed the stale DR-46 dashboard row from "Local / validation pending" to published/validated while keeping the source patch open in the hardening backlog.
- Scope remained docs-only; no gameplay source files were edited.

# 2026-06-02 - WASP Overlay Self-Test Documentation Correction

- Closed Claude's Instructions-For-Codex item 43 by source-checking the Chernarus source mission for `init.sqf`, `test/`, `*selftest*` and `WASP-SELFTEST`.
- Removed the fabricated live `test/wasp_selftest.sqf` row, wiring entry and behavior section from [WASP overlay](WASP-Overlay); the page now records it as a documentation error under dead/missing references.
- Corrected `WASP_procInitComm` from `initJIPCompatible.sqf:253-255`/`:253` to the commented block at `initJIPCompatible.sqf:241-245`, specifically `:243`.
- Updated [`agent-context.json`](agent-context.json), [Instructions for Codex](Instructions-For-Codex), and [`agent-knowledge.jsonl`](agent-knowledge.jsonl) so compact agent context no longer lists a server self-test as a WASP feature.
# 2026-06-02 - Scripting-Reference Pass 2: Object-Scan Family + A3 Trap-Check (Claude)

- Second BIKI version cross-check, theme = object-scan/spatial commands and a sweep for A3-only "looks-useful" commands. All grounded in source usage.
- Added an **Object scans & spatial queries** section to [Arma-2-OA command version reference](Arma-2-OA-Command-Version-Reference): `nearestObjects` (A2 1.00, sorted, `[]`=all/slow), `nearEntities` (A2 1.00, unsorted, **alive units/vehicles/logics only** — no buildings/dead/crew, BI "much faster"), `nearObjects` (ArmA 1.00), `nearestObject` (OFP 1.00). Key guardrail: the DR-39 supply scan targets the `Base_WarfareBUAVterminal` **structure** (`supplyMissionStarted.sqf:45,61`), so it must stay a class-filtered `nearestObjects` — it cannot be swapped to `nearEntities` (returns no buildings).
- Added confirmed-available rows: `getPosATL`/`setPosATL` (A2 1.03), `createVehicleLocal` (ArmA 1.00, client-local/not network-synced, netId 0:0), `addWeaponCargoGlobal`/`addMagazineCargoGlobal` (**OA 1.55**, Global effect, not A3-only; repo gear-equip path), `setVectorDirAndUp` (ArmA 1.09).
- Extended the A3-only table with two **confirmed-absent** traps (positive assurance, 0 source hits each): `setUnitLoadout`/`getUnitLoadout` (A3 1.58 — LoadoutManager is config-driven, not the A3 loadout API) and `hideObjectGlobal`/`enableSimulationGlobal` (A3 1.12 — OA only has the local `hideObject`/`enableSimulation`).
- Item 48 confirmed DONE by Codex (inverse-trap classes canonicalized in the compatibility audit + `agent-compatibility-audit.json`). Routed item 49: a one-line DR-39 guardrail for the Codex-owned Supply-Mission-Scan-Narrowing / Performance-Opportunity-Sweep pages.
- Aside (not in scope, flagged to owner): `Common/Functions/Common_EquipBackpack.sqf:35` uses `for '_i' from 0 to count(_items)` — inclusive in A2, an off-by-one overrun feeding nil to `addWeaponCargoGlobal`. Latent gear-system issue, no source edits this pass.
- No source edits (docs only). Disputed cleanup lanes remain unpatched per the current source snapshot.

# 2026-06-02 - Scripting-Reference Pass 3: String/Selection Command Traps (Claude)

- Third BIKI version cross-check, theme = string/selection commands an A3-trained agent reaches for by reflex. All A3-only ones confirmed absent from source.
- Added to the A3-only table in [Arma-2-OA command version reference](Arma-2-OA-Command-Version-Reference): `selectRandom` (A3 1.56), `splitString`/`joinString` (A3 1.50), `trim` (A3 2.02) + regex helpers — all 0 source hits.
- **Function-vs-command distinction:** `BIS_fnc_selectRandom` (the *function*) IS OA-safe (A2 1.00) and is used 4× in `Client/Functions/Client_BuildUnit.sqf:59/85/111/135` (spawn-pad pick); the `selectRandom` *command* is A3-only. Added `BIS_fnc_selectRandom` to the Confirmed-available table with the explicit warning not to collapse the function call into the command.
- The repo's OA-safe random-pick idiom is `_arr select floor(random count _arr)` (`Init_Town.sqf:39`, `AI_AdvancedRespawn.sqf`, `AI_SquadRespawn.sqf`, `ARTY_HandleSADARM.sqf:63`).
- Routed item 50 (optional, LOW): reflect the new A3-only string/selection traps in `agent-compatibility-audit.json`'s avoid-list.
- No source edits (docs only). Disputed cleanup lanes remain unpatched per the current source snapshot.

# 2026-06-02 - Wave O Orchestrator Sidecar Harvest

- Acting as main LLM orchestrator, harvested the returned Wave O sidecar scouts and promoted only source-checked deltas into canonical owner pages.
- Added an MP lobby/defaults versus constants fallback drift table to [Mission parameters/build inputs](Mission-Parameters-Localization-And-Generated-Build-Inputs): `Init_Parameters.sqf` is only compiled on `isMultiplayer` boot, so non-MP constants fallbacks can differ for AI commander, artillery, base area, ICBM impact time and radiation time.
- Added a stale helper finding to [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map): `Server_GetDelegators.sqf` still exists, but active delegation defines `WFBE_SE_FNC_GetDelegators` inline in `Server_FNC_Delegation.sqf`.
- Added GlobalGameStats data-shape/player-count fixture risk to [Tooling release readiness](Tooling-Release-Readiness-Audit): SQF exports five data args after the class name, extension/Discord DTO defaults differ, Discord reads index `4`, and the mission subtracts one assumed headless client.
- Updated [Discovery swarm](Subagent-Discovery-Swarm), [Progress dashboard](Progress-Dashboard), [`agent-status.json`](agent-status.json), [`agent-collaboration.json`](agent-collaboration.json), [`agent-events.jsonl`](agent-events.jsonl) and [`agent-knowledge.jsonl`](agent-knowledge.jsonl) so Claude/Codex tabs know Wave O is returned and selected findings are being published by this orchestrator lane.

# 2026-06-02 - Wave P FPS/RHUD Contract Harvest

- Harvested Wave P read-only scouts and source-checked the selected deltas with `rg` / `git ls-files` before promotion.
- Updated [Client UI systems atlas](Client-UI-Systems-Atlas): player RHUD/FPS UI reads `SERVER_FPS_GUI` at `Client/Client_UpdateRHUD.sqf:113`; `Server/GUI/serverFpsGUI.sqf:6-7` publishes it.
- Updated [Hosted server FPS loop sleep](Hosted-Server-FPS-Loop-Sleep) and [Public variable channel index](Public-Variable-Channel-Index): `WFBE_VAR_SERVER_FPS` is still published by `Server/Module/serverFPS/monitorServerFPS.sqf:5-6`, but no current source Chernarus player-UI reader was found. Treat consolidation as a compatibility cleanup separate from the hosted/listen busy-loop fix.
- Updated [AI runtime/HC loop map](AI-Runtime-HC-Loop-Map): `Server_GetDelegators.sqf` is stale duplicate/generated drift across source/Vanilla/modded trees; active code uses inline `WFBE_SE_FNC_GetDelegators`.
- Updated [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas): SmallSite add/add versus MediumSite add/remove `wfbe_structures_logic` asymmetry also exists in maintained Vanilla and main modded copies.
- Updated [Tooling release readiness](Tooling-Release-Readiness-Audit): added a five-slot GlobalGameStats fixture contract for BLUFOR score, OPFOR score, terrain, uptime and player count.
- Updated [Source inventory](Source-Inventory): added tracked mission parity counts from `git ls-files`, with Vanilla Takistan marked maintained-but-map-divergent and modded folders marked forks/stubs.
- Updated [Gear/loadout/EASA atlas](Gear-Loadout-And-EASA-Atlas): clarified that buy-gear click-pool bounds are not currently proven off-by-one; the already-known profile/cargo defects remain the patch-ready items.

# 2026-06-02 - Wave S Scout Harvest

- Acting as main LLM orchestrator, harvested Hilbert, Dirac, Descartes and Nash and promoted only selected source-backed corrections into canonical pages.
- Tightened [Victory/endgame atlas](Victory-And-Endgame-Atlas), [Feature status](Feature-Status-Register) and [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl): current `_x` is loser in the HQ/factory branch but winner in all-towns victory, so a patch must compute explicit `_winnerSide`/`_loserSide`, guard both branches with `!WFBE_GameOver` and exit after the first winner.
- Tightened [External integrations](External-Integrations), [Integration trust boundary audit](Integration-Trust-Boundary-Audit) and [Tools/build](Tools-And-Build-Workflow): the active Discord status reader bypasses `FileConfiguration.DataSourcePath`, live `FileConfiguration` usage is logging, DiscordBot still has a callable `TypeNameHandling.Auto` helper, and deployment inventory must distinguish GLOBALGAMESTATS, A2WaspDatabase, bot secrets and production BE/server config.
- Corrected [Tools/build](Tools-And-Build-Workflow), [Abandoned feature revival](Abandoned-Feature-Revival-Review), [Deep-review findings](Deep-Review-Findings) and [`agent-context.json`](agent-context.json): Napf/eden/lingor are partial forks rather than checkout-runnable mission roots; source/Vanilla paratrooper markers are revived but modded drift remains; MASH sender drift is eden/lingor, not Napf.
- Corrected Arma 2 OA compatibility guidance in [Deep-review findings](Deep-Review-Findings), [command version reference](Arma-2-OA-Command-Version-Reference), [`agent-compatibility-audit.json`](agent-compatibility-audit.json) and [`agent-context.json`](agent-context.json): no copyable `isEqualTo` snippets and no `setGroupOwner`/`groupOwner` live-transfer advice.

# 2026-06-02 - DR-46 SEND_MESSAGE Cross-Link Closure

- Source-checked Claude DR-46 against `Client/Functions/Client_onEventHandler_SEND_MESSAGE.sqf` and `Common/Functions/Common_SendMessage.sqf`: both compile message text in the multi-language branch, and the client receiver gets its text from the direct `SEND_MESSAGE` publicVariable payload.
- Corrected the DR-1 note in [Deep-review findings](Deep-Review-Findings): "no second-order injection" now explicitly applies only to the registered PVF path; the repo has a second network-data compile surface in direct `SEND_MESSAGE`.
- Promoted DR-46 into [Networking/PV](Networking-And-Public-Variables), [Public variable channel index](Public-Variable-Channel-Index), [SQF code atlas](SQF-Code-Atlas), [Feature status](Feature-Status-Register), [Pending owner decisions](Pending-Owner-Decisions) and [Hardening roadmap](Hardening-Implementation-Roadmap).
- Updated [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl), [`agent-status.json`](agent-status.json), [`agent-collaboration.json`](agent-collaboration.json) and [Instructions for Codex](Instructions-For-Codex) so future agents treat DR-46 cross-linking as complete and the source patch as P0 patch-ready/source-unpatched.

# 2026-06-03 - Lesson-Aware Codebase Indexer

- Claimed `lesson-aware-codebase-indexer` and avoided the DR-44-owned files while source-reading under-covered AI respawn/orders, cleanup queues and `Common/Config` data-model paths.
- Added [Development lessons learned](Development-Lessons-Learned) as a scoped integration proposal, plus [`agent-development-lessons.jsonl`](agent-development-lessons.jsonl) for machine-readable lesson records.
- Source-backed lessons captured: vanilla/non-vanilla AI respawn branches need separate smoke; commander AI order variables are public group variables and need executor proof before hardening; cleanup loops can be server-owned while draining client-replicated queues; cleanup patches must cite producer/consumer array shapes; config edits propagate through derived runtime tables; module patches need runtime-edge smoke.
- Handoff: main orchestrator should review/link the new artifacts into navigation/agent context and mirror to the wiki checkout if accepted. No gameplay source edits and no commits were made.

# 2026-06-03 - Documentation Finisher Lesson Integration

- Reviewed the `lesson-aware-codebase-indexer` handoff and source-checked the lesson claims against the cited AI respawn/orders, cleanup queue, `Common/Config` and module-wiring paths.
- Accepted and wired [Development lessons learned](Development-Lessons-Learned) plus [`agent-development-lessons.jsonl`](agent-development-lessons.jsonl) into [Home](Home), `_Sidebar`, [Agent context](Agent-Context), [`agent-context.json`](agent-context.json) and [Progress dashboard](Progress-Dashboard).
- Scope remained docs-only; no gameplay source files were edited.

# 2026-06-03 - DR-20 HQ-Killed Score Cross-Links

- Source-checked DR-20 against redundant HQ killed detection paths (`Init_Server.sqf:319`, `Construction_HQSite.sqf:36,89`, `Init_Client.sqf:499-503`) and the unguarded score awards in `Server_OnHQKilled.sqf:46-50` and `:74-82`.
- Routed the finding into [Construction and CoIn systems atlas](Construction-And-CoIn-Systems-Atlas), [Gameplay systems atlas](Gameplay-Systems-Atlas) and [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas), then marked [Instructions for Codex](Instructions-For-Codex) item 5 complete.
- Scope remained docs-only; no gameplay source files were edited.
