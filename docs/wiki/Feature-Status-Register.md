# Feature Status Register

This register separates working systems from partial, deferred or risky systems found during indexing. For revive/remove decisions on dormant feature paths, use [Abandoned feature revival](Abandoned-Feature-Revival-Review).

## Working / Active Systems

- Core Warfare loop: towns, commanders, bases, factories, upgrades, resources and victory checks.
- Client/server/common initialization split.
- Generic PVF request/response system.
- Player supply-truck missions on `master`.
- Enhanced day/night cycle with server authority and client smoothing.
- Server FPS publishing and RHUD/FPS HUD.
- Performance audit instrumentation plus analyzer.
- Anti-stack module with optional mission parameter.
- AFK kick through BattlEye publicVariable filter.
- MASH respawn module; marker synchronization is broken and tracked below.
- ICBM/radiation module; RequestSpecial authority risk is tracked below.
- EASA aircraft loadout module; client-side authority risk is tracked below.
- Client marker blinking guarded by parameter.
- LoadoutManager mission copy/generation workflow.
- Discord bot status updates from exported game data.

## Triage View

Use this view before turning a row below into code work. It separates match-breaking risks from dormant archaeology and low-priority TODOs, while keeping detailed source evidence in the longer table and linked finding pages.

Severity shorthand: **Critical/High** = authority, RCE, live-money-equivalent trust or match outcome risk; **Medium** = live defect, config-gated runtime breakage or release/tooling hazard; **Low/Info** = cleanup, intentionally disabled feature or local UX debt.

| Bucket | Includes | Severity | Blast radius | Canonical route |
| --- | --- | --- | --- | --- |
| Economy / PV authority class | PVF dispatcher, construction, buy/sell, side supply, upgrades, ICBM, gear/EASA/service and attack-wave direct PV | Critical/High | Public-server trust boundary and whole-match economy/effects | [Pending owner decisions](Pending-Owner-Decisions#1-the-big-one--economyforgery-authority-one-decision-whole-class), [Economy](Economy-Towns-And-Supply#authority-model), [PVF playbook](PVF-Dispatch-Implementation-Playbook) |
| Match outcome / persistence correctness | victory winner inversion, threeway no-detection, duplicate game-end logging, HQ-killed scoring idempotency | High/Medium | match end, persisted stats and score rewards | [Pending owner decisions](Pending-Owner-Decisions#2-other-correctness-fixes-owner-scoped-source-cited), [Deep-review findings](Deep-Review-Findings) DR-11/12/13/20/36 |
| Supply mission implementation | cooldown casing, PR #1 stacked `Killed` handlers, supply mission trust cleanup | Medium | supply-mission economy, interdiction rewards and PR #1 behavior | [Supply mission architecture](Supply-Mission-Architecture), [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook), DR-18/DR-39 |
| Broken-but-bounded feature edges | MASH map markers, paratrooper marker smoke/modded drift, old upgrade dialog, WASP legacy actions, UAV 007 branch | Low/Medium | single feature edge, UI marker state or dormant action path | [Abandoned feature revival](Abandoned-Feature-Revival-Review), [Pending owner decisions](Pending-Owner-Decisions#3-keep-or-remove--maintenance-model-decisions) |
| Config-gated runtime breakage | AI commander supply trucks with `WFBE_C_ECONOMY_SUPPLY_SYSTEM == 0` and AI commanders enabled | Medium | server init for truck-based AI logistics; default config avoids it | [Abandoned feature revival](Abandoned-Feature-Revival-Review#ai-commander-supply-trucks), this page's AI supply section |
| Tooling / release hazards | modded mission propagation, missing source `version.sqf`, CRV7PG loadout warning classes | Medium/High | release packaging, generated mission drift or loadout-induced game crash | [Tools and build](Tools-And-Build-Workflow), [Pending owner decisions](Pending-Owner-Decisions#3-keep-or-remove--maintenance-model-decisions), DR-32/DR-43a |
| Intentional disables / legacy replacements | volumetric clouds, old map blink loop, server map blinking units, duplicate commented MASH compile | Info/Low | no live defect unless a maintainer re-enables stale code | Keep row notes here; only promote after a source re-check and owner intent |
| Local enhancement TODOs | gear-menu cleanup, fast-travel fee, CoIn border movement, AI attack waypoint radio/tuning | Low | local UX or AI polish | Treat as backlog, not bug debt; source-check again before implementation |

## Partial / Deferred / Needs Review

| Area | Evidence | Status |
| --- | --- | --- |
| Autonomous AI supply trucks | `UpdateSupplyTruck` compile is commented at `Server/Init/Init_Server.sqf:36`, **but the call site `[_side] Spawn UpdateSupplyTruck;` at `:383` is live** — gated by `WFBE_C_ECONOMY_SUPPLY_SYSTEM == 0 && WFBE_C_AI_COMMANDER_ENABLED > 0` (`:381`). `AI_UpdateSupplyTruck.sqf` then `ExecFSM`s the missing `Server/FSM/supplytruck.fsm`. | **Config-gated latent breakage** (sharpened by Claude — see below). |
| Task system | `TaskSystem` compile and `TownAddComplete` spawn are commented in `Client/Init/Init_Client.sqf` though `Client_TaskSystem.sqf` still exists. | Disabled/partial. Re-enable only after checking task spam/JIP behavior. |
| MASH marker receiver | `receiverMASHmarker.sqf` (registers the `WFBE_SE_MASH_MARKER_SENT` client EH) is referenced **only** by the commented compile at `Client/Init/Init_Client.sqf:132`; the server re-broadcast (`Server/Module/MASH/MASHMarker.sqf`) is live, with one active compile at `Server/Init/Init_Server.sqf:70` and a later duplicate commented at `:92`. | **Confirmed broken (receiver never registered)** -> MASH map markers never appear; MASH respawn itself is independent. See [Deep-review findings](Deep-Review-Findings) DR-3/DR-34. |
| Paratrooper drop markers | `Server/Support/Support_Paratroopers.sqf:117` sends `HandleParatrooperMarkerCreation`; source Chernarus and Vanilla Takistan now register that client PVF in `Init_PublicVariables.sqf`, and the handler file exists. | **Patched source/Vanilla; smoke pending.** Use [Paratrooper marker revival](Paratrooper-Marker-Revival). Modded folders still drift: Napf/eden/lingor register the handler but lack the handler file. |
| PV dispatch trust boundary | `Server_HandlePVF.sqf` / `Client_HandlePVF.sqf` are the generic PVF dispatchers; source proof and patch shape live in [PVF dispatch playbook](PVF-Dispatch-Implementation-Playbook). | **Live-server hardening gap (High).** Apply the DR-1/DR-38 dispatch lookup patch; BattlEye posture is separate, see [External integrations](External-Integrations#battleye-filter) / DR-30. |
| ICBM RequestSpecial authority | `Client/Module/Nuke/nukeincoming.sqf:23` reaches `Server/Functions/Server_HandleSpecial.sqf:97-111` through `RequestSpecial`. | **Active high-risk authority gap.** Keep class synthesis in [Economy](Economy-Towns-And-Supply#authority-model), patch sequencing in [Economy authority first cut](Economy-Authority-First-Cut), and payload proof in DR-27. |
| Gear/EASA/service authority | UI/source anchors live in [Client UI/HUD](Client-UI-HUD-And-Menus#gear-easa-and-service-authority). | **Active client-authoritative spend/state mutation (High).** Part of the economy authority class; see [Economy](Economy-Towns-And-Supply#authority-model) and DR-28. |
| Attack wave direct PV authority | `Common/Functions/Common_AttackWaveActivate.sqf:6-8` sends client-supplied `[_supply, _side]` via `publicVariableServer`; `Server/Functions/Server_AttackWave.sqf:1-27` derives the price modifier from that payload. | **Active direct-PV authority gap (High).** Hardening must cover direct publicVariableServer channels as well as PVF. See DR-41. |
| Three-way victory race/idempotency | `Server/FSM/server_victory_threeway.sqf:23-43` is the source loop for win detection, endgame broadcast and winner logging. | **Confirmed correctness risk.** Keep impact and fix shape in [Deep-review findings](Deep-Review-Findings) DR-11/DR-36. |
| Supply mission cooldown casing | Supply cooldown state is tracked in [Supply mission architecture](Supply-Mission-Architecture). | **Confirmed first-use cooldown defect.** Align casing or read with a default. See [Deep-review findings](Deep-Review-Findings) DR-18. |
| Old map blink loop | `Client_BlinkMapIcons` and `AddUnitToTrack` compiles plus old exec are commented; newer singular `Client_BlinkMapIcon` and bookkeeping are active. | Legacy replacement. Avoid resurrecting old loop without perf review. |
| Server map blinking units | `Server_MapBlinkingUnits.sqf` exec is commented in `Init_Server.sqf`. | Disabled/legacy. |
| Old WASP init block | `initJIPCompatible.sqf` contains a commented WASP init block marked as old and resource-heavy. | Legacy/deferred removal. Individual WASP scripts still exist and may be called elsewhere. |
| Server FPS compile variable | `WFBE_CO_FNC_monitorServerFPS` compile lines are commented, but `Init_Server.sqf` later execVMs `Server/Module/serverFPS/monitorServerFPS.sqf`. | Not broken; document the direct exec path. |
| MASH marker duplicate compile | One MASH marker compile is active and a later duplicate is commented. | Likely cleanup artifact; do not re-enable both. |
| Volumetric clouds | Parameter exists but is forced disabled in constants and client init. | Intentional optimization. |
| Modded map generator path | `SqfFileGenerator.cs` has TODO to add modded maps back in one path. | Verify before assuming modded mission regeneration is complete. |
| Dangerous CRV7PG loadouts | LoadoutManager has `WARNING_GAME_CRASH_DO_NOT_USE_IN_LOADOUTS_*` weapon/ammunition classes, and `WILDCAT.cs` references one. | High-risk data. Keep these warnings visible when changing loadouts. |
| Gear menu cleanup | `GUI_BuyGearMenu.sqf` has a TODO about securing vanilla/removing unused code. | Low-priority cleanup unless touching gear UI. |
| Fast travel fee | `GUI_Menu_Tactical.sqf` TODO mentions travel fee/mod parameter work. | Missing/unfinished feature. |
| Base/town dynamic logic TODO | `Common/Init/Init_Common.sqf` has a TODO around dynamic logic presence. | Low-level init cleanup candidate. |
| CoIn border TODO | `Client/Module/CoIn/coin_interface.sqf` notes temporary border logic should move if logic position changes. | Construction UI risk. |
| AI attack radio/combat tuning | `Server_AI_SetTownAttackPath.sqf` TODOs mention combat mode, speed and radio on waypoint completion. | Enhancement backlog. |

## Broken Feature Candidate: AI Supply Logistics

This is the clearest broken/abandoned feature. `AI_UpdateSupplyTruck.sqf` is present and loops over `wfbe_ai_supplytrucks`, but it cannot run correctly because the compile is disabled and the referenced `supplytruck.fsm` is absent. PR #1 correctly defers autonomous supply helicopters because the AI logistics base is incomplete.

### Claude refinement (2026-06-01): it is *not* cleanly inert — it is config-gated

The original note above implied the feature is dormant because the compile is off. The call site is actually still **live**. In `Server/Init/Init_Server.sqf`:

- `:36` — `/* UpdateSupplyTruck = Compile preprocessFile "Server\AI\AI_UpdateSupplyTruck.sqf"; */` → the function `UpdateSupplyTruck` is **never defined**.
- `:381-384` — per-side init runs, *unconditionally compiled into the init*:
  ```sqf
  if ((missionNamespace getVariable "WFBE_C_ECONOMY_SUPPLY_SYSTEM") == 0
      && (missionNamespace getVariable "WFBE_C_AI_COMMANDER_ENABLED") > 0) then {
      _logik setVariable ["wfbe_ai_supplytrucks", []];
      [_side] Spawn UpdateSupplyTruck;   // UpdateSupplyTruck is nil here
  };
  ```

Consequences:

- **Default play is safe.** `WFBE_C_ECONOMY_SUPPLY_SYSTEM` defaults to `1` ("Automatic with time"; `Init_CommonConstants.sqf:161`), so the `:381` guard is false and `:383` never runs.
- **Selecting Supply System 0 ("Trucks") with an AI commander hits the landmine.** `Spawn UpdateSupplyTruck` spawns a `nil` code value → a runtime `Type Nothing, expected Code` error during per-side server init, and AI supply trucks silently never spawn. Even if `:36` were restored, `AI_UpdateSupplyTruck.sqf` immediately `ExecFSM "Server\FSM\supplytruck.fsm"`, which does not exist → a second runtime failure.

**Net:** the truck-based supply economy (`WFBE_C_ECONOMY_SUPPLY_SYSTEM = 0`) combined with AI commanders is broken on this fork, not merely deferred. Restoring it requires (a) re-enabling the `:36` compile **and** (b) authoring/restoring `Server/FSM/supplytruck.fsm`. Until then, document Supply System 0 as unsupported, or remove the dead `:383` call.

## Confirmed defect: stacked `Killed` handlers on supply vehicles (PR #1)

`Server/Module/supplyMission/supplyMissionStarted.sqf` (introduced/extended by PR #1) adds a `Killed` event handler to the loaded supply vehicle **every time a supply mission starts**, with no removal or guard. A vehicle reused across N missions accumulates N handlers. Interdiction cannot double-pay (the first handler zeroes `SupplyAmount`), so current impact is a bounded EH leak — but any future side-effect on that EH would multiply. Fix: guard with an object variable or `removeAllEventHandlers "Killed"` before adding. Full evidence in [Current work: supply helicopters PR #1](Current-Work-Supply-Helicopters-PR1).

## Missing Feature Candidates

- Autonomous AI supply trucks/helicopters.
- Formal generated docs from LoadoutManager data classes into mission docs.
- Automated validation that generated Takistan/modded missions match Chernarus source after docs/code changes.
- Automated SQF syntax or reference validation in CI.

