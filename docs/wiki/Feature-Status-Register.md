# Feature Status Register

This register separates working systems from partial, deferred or risky systems found during indexing.

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
- MASH marker synchronization.
- ICBM/radiation module.
- EASA aircraft loadout module.
- Client marker blinking guarded by parameter.
- LoadoutManager mission copy/generation workflow.
- Discord bot status updates from exported game data.

## Partial / Deferred / Needs Review

| Area | Evidence | Status |
| --- | --- | --- |
| Autonomous AI supply trucks | `UpdateSupplyTruck` compile is commented at `Server/Init/Init_Server.sqf:36`, **but the call site `[_side] Spawn UpdateSupplyTruck;` at `:383` is live** — gated by `WFBE_C_ECONOMY_SUPPLY_SYSTEM == 0 && WFBE_C_AI_COMMANDER_ENABLED > 0` (`:381`). `AI_UpdateSupplyTruck.sqf` then `ExecFSM`s the missing `Server/FSM/supplytruck.fsm`. | **Config-gated latent breakage** (sharpened by Claude — see below). |
| Task system | `TaskSystem` compile and `TownAddComplete` spawn are commented in `Client/Init/Init_Client.sqf` though `Client_TaskSystem.sqf` still exists. | Disabled/partial. Re-enable only after checking task spam/JIP behavior. |
| MASH marker receiver | `WFBE_CL_FNC_ReceiverMASHmarker` compile is commented in `Client/Init/Init_Client.sqf` while server/client MASH marker event scripts still exist. | Needs verification. MASH respawn may work, but marker sync path appears partially disabled. |
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

