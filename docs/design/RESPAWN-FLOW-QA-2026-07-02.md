# Respawn Flow QA - 2026-07-02

Lane: 24, general mission QA sweep / respawn flows
Branch: `codex/lane24-respawn-flow-qa`
Base checked: `origin/claude/build84-cmdcon36@b2dbab5f3`
Scope: maintained Chernarus (`Missions/[55-2hc]warfarev2_073v48co.chernarus`) and maintained Vanilla Takistan (`Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`)

This was a source-only QA pass. No live Arma 2/OA runtime smoke was run, and no mission SQF source was changed.

## Result

No P1/P2 respawn-flow source defect was found on the current target. The current branch already carries the important recent hardening around player death location, respawn timer defaults, spawn-list type checks, null-spawn fallback, spawn-marker cleanup, and custom-gear penalty mode 5.

The main actionable outcome is to treat several older wiki respawn findings as branch-sensitive or already resolved on this target, rather than rediscovering them as fresh bugs.

## Maintained Root Parity

The audited Chernarus and Takistan copies are byte-identical for the core respawn files checked in this lane:

| File family | Hash in both maintained roots |
| --- | --- |
| `Client/Functions/Client_GetRespawnAvailable.sqf` | `eed801d10eed4c583e60582068b82e427c7a6273` |
| `Client/Functions/Client_OnRespawnHandler.sqf` | `88ca2ec310f73ff7e4b1225bb4ed1984bc17ff62` |
| `Client/GUI/GUI_RespawnMenu.sqf` | `ee5c2b31259b32f25d8f6f910ef92e70eb28df7b` |
| `Server/AI/AI_AdvancedRespawn.sqf` | `3ffaca9c1b56221bce74d17ff163615c30a7d0b1` |
| `Server/AI/AI_SquadRespawn.sqf` | `499984e3d56e93e496983917cf90eb9f13b9c1d9` |

## Current Flow Evidence

Respawn bootstrap:

- `Rsc/Header.hpp:4-6` sets engine respawn mode `3`, uses `WF_RESPAWNDELAY`, and disables the engine respawn dialog.
- `Client/Init/Init_Client.sqf:139,146-147,213,229` compiles respawn availability, pre-respawn, on-respawn, killed-handler, and selector functions.
- `Client/Init/Init_Client.sqf:503,533-534` initializes `WFBE_Client_IsRespawning`, `WFBE_RespawnDefaultGear`, and `WFBE_LastSelectedSpawn`.
- `Client/Init/Init_Client.sqf:1311` binds the player `Killed` handler.
- `Server/Init/Init_Server.sqf:23-24` compiles `AISquadRespawn` for A2 Vanilla and `AIAdvancedRespawn` otherwise.

Respawn parameters and defaults:

- `Common/Init/Init_CommonConstants.sqf:1384-1393` defines camp, delay, leader, mobile, penalty, and range defaults.
- `Common/Init/Init_CommonConstants.sqf:1789,1794,1798` defaults the v2 respawn UI, map zoom, and contested-radius color threshold.
- `Rsc/Parameters.hpp:443-481` exposes camp mode, camp rule, delay, leader respawn, mobile respawn, penalty, and town respawn range parameters.

Player death and menu hardening:

- `Client/Functions/Client_OnKilled.sqf:45,83,125,162-202` marks the client as respawning, records death location, reapplies pre-respawn hooks, guards death-camera creation, and opens `WFBE_RespawnMenu`.
- `Client/Functions/Client_PreRespawnHandler.sqf:5-14,33` reapplies skill effects, action FSM/menu actions, fired hooks, and damage handling to the new player object.
- `Client/GUI/GUI_RespawnMenu.sqf:15-17` guards missing or malformed `WFBE_DeathLocation`.
- `Client/GUI/GUI_RespawnMenu.sqf:48-54` guards missing or non-scalar `WFBE_RespawnTime`.
- `Client/GUI/GUI_RespawnMenu.sqf:107-109` guards non-array or invalid spawn-list entries.
- `Client/GUI/GUI_RespawnMenu.sqf:342-343` clears marker tracking and deletes local spawn markers when the menu exits.

Respawn placement and gear:

- `Client/Functions/Client_OnRespawnHandler.sqf:32-48` falls back to a live side HQ or start position when the selected WEST/EAST spawn object is null, avoiding a `[0,0,0]` strand.
- `Client/Functions/Client_OnRespawnHandler.sqf:55-65,135-174` handles mobile/leader/default-gear gating and custom gear restoration.
- `Client/Functions/Client_OnRespawnHandler.sqf:168` gates the affordability skip on `_charge`, so penalty mode 5 base respawns no longer lose custom gear merely because the player cannot afford the theoretical price.
- `Client/Functions/Client_OnRespawnHandler.sqf:208-210` falls back to side/class default gear when custom gear is not restored.

Spawn sources:

- `Client/Functions/Client_GetRespawnAvailable.sqf:33-82` handles ambulances and redeploy trucks, including free-cargo, stationary, engine-off, and enemy-town proximity filters for redeploy trucks.
- `Client/Functions/Client_GetRespawnAvailable.sqf:107-119` adds resistance-friendly town and GUER FOB options.
- `Client/Functions/Client_GetRespawnAvailable.sqf:124-134` adds captured naval HVT respawn objects for WEST/EAST.
- `Common/Functions/Common_GetRespawnCamps.sqf:7,18-25,40-48,67-77` handles camp modes and enemy safe-radius filtering.
- `Common/Functions/Common_GetRespawnThreeway.sqf:7` adds fully held defender towns.

AI respawn:

- `Server/AI/AI_AdvancedRespawn.sqf:24-30,39-53,55-63,67-80,116-120` rebinds killed handling, collects camp/mobile candidates, waits the respawn delay, equips AI gear, logs, and places the respawned unit.
- `Server/AI/AI_SquadRespawn.sqf:26-30,38-51,53-64,102-105` covers the A2 Vanilla squad-leader loop on the same general contract.

## Findings And Follow-Ups

### RFQA-01: Penalty Mode 5 Base Gear Strip Is Resolved On This Target

Older wiki text still describes a patch-ready edge where respawn penalty mode 5 could strip custom gear at base/HQ if the player could not afford the theoretical price. Current source already gates that skip on `_charge` in `Client_OnRespawnHandler.sqf:168`.

Status: resolved in current source. Follow-up is wiki cleanup, not a gameplay patch.

### RFQA-02: MASH Respawn Claims Must Stay Branch-Sensitive

The current maintained roots do not contain maintained-root `Client/Module/MASH` or `Server/Module/MASH` files. `Client/Module/Skill/Skill_Apply.sqf:44` states that the MASH deploy ability was removed and that officers keep the near-camp repair action.

Status: no current-target MASH respawn source bug found. Do not port older MASH deploy/relay statements into this branch without first choosing revive-vs-remove semantics.

### RFQA-03: AI Squad Respawn Has Two Low-Risk Cleanup Items

`Server/AI/AI_SquadRespawn.sqf:1` declares `"_rcm'"` in the `Private` array while the script assigns `_rcm` later. The same file also logs `AI_AdvancedRespawn.sqf` at `:19` and `:102`.

Status: P3 cleanup candidate. This pass did not change it because no runtime defect was proven, and it is better bundled with a focused AI respawn cleanup/smoke lane.

### RFQA-04: AI Gear Tier Lookup Still Uses A Literal Index

`AI_AdvancedRespawn.sqf:70` and `AI_SquadRespawn.sqf:58` use `_upgrades select 13`, which currently matches `WFBE_UP_GEAR = 13`. A future cleanup should use the named constant and consider clamping/guarding the selected AI loadout tier before random selection.

Status: P3 maintainability follow-up. No current behavior failure was proven in this source-only pass.

### RFQA-05: Threeway Zero-Camp Town Eligibility Remains An Owner Decision

`Common_GetTotalCamps.sqf:10` and `Common_GetTotalCampsOnSide.sqf:16` both return `1` for zero-camp towns. `Common_GetRespawnThreeway.sqf:7` compares those totals, so a side-owned zero-camp town can qualify as fully held for defender respawn.

Status: P3 design/owner decision. Leave as-is unless someone confirms zero-camp towns should not be threeway respawn sources.

### RFQA-06: Mobile/Redeploy Needs Runtime Smoke Rather Than Static Patch

The menu refresh checks vehicle eligibility every tick, but final placement only has time-of-respawn state available. Vehicles can move, lock, fill, die, or become enemy-contested during the countdown window. The current code has defensive fallbacks, but this is still worth a runtime smoke matrix for ambulance cargo, redeploy-truck stopped/engine-off state, enemy-town proximity, and vehicle destruction during countdown.

Status: smoke-test target, not a source bug from this pass.

## Suggested Smoke Matrix

- Player dies with no valid base spawn and verifies fallback does not land at `[0,0,0]`.
- Base/HQ respawn with penalty mode 5, custom gear selected, and insufficient funds; expected: no charge and no affordability-only gear strip.
- Ambulance candidate appears with free cargo, then fills before countdown completes; expected: no script error and sane fallback placement.
- Redeploy truck appears while stationary/engine-off, then moves or turns engine on before countdown completes; expected: candidate disappears on refresh or final placement remains safe.
- Resistance player respawns at friendly/neutral town, GUER FOB truck, and naval HVT where applicable.
- A2 Vanilla AI leader respawns through `AI_SquadRespawn`; non-Vanilla AI respawns through `AI_AdvancedRespawn`; expected: no RPT private/log/loadout errors.

## Validation Performed

- Reviewed current prompt lane 24 scope and active fleet claims before claim.
- Confirmed source branch `codex/lane24-respawn-flow-qa` was based on `origin/claude/build84-cmdcon36`.
- Checked Chernarus/Takistan parity hashes for the five audited core respawn scripts.
- Searched maintained roots for MASH module files; none were present in current Chernarus/Takistan maintained roots.
- Confirmed respawn marker cleanup exists in both maintained roots.
