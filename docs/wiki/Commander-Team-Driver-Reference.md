# Commander-Team Driver Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Two functions sit at the centre of the AI-commander combat system. `WFBE_CO_FNC_GetCommanderTeam` is the tiny getter every consumer calls to find a side's *human* commander group, and `WFBE_CO_FNC_RunCommanderTeam` is the 889-line runtime driver that creates and executes one *AI*-commander combat team on a headless client. They are unrelated in code but share the "commander team" vocabulary, so this page documents both and draws the line between them clearly: `GetCommanderTeam` returns the elected player commander's group; `RunCommanderTeam` spawns and runs an autonomous AI fire-team the brain orders around the map.

Both are registered in `Common/Init/Init_Common.sqf`: `WFBE_CO_FNC_GetCommanderTeam` at `Common/Init/Init_Common.sqf:124` (and the bare alias `GetCommanderTeam` at `Common/Init/Init_Common.sqf:28`), `WFBE_CO_FNC_RunCommanderTeam` at `Common/Init/Init_Common.sqf:108`.

## WFBE_CO_FNC_GetCommanderTeam

A three-line side switch that reads the `wfbe_commander` variable off the side's logic object. It does NOT create or run anything — it only answers "which group is this side's elected commander?".

| Aspect | Detail | Citation |
|---|---|---|
| Param | `_this` = a Side (`west` / `east` / `resistance`) | `Common/Functions/Common_GetCommanderTeam.sqf:3-4` |
| Returns | the side-logic's `wfbe_commander` group, else `objNull` | `Common/Functions/Common_GetCommanderTeam.sqf:8-11` |
| west branch | `WFBE_L_BLU getVariable ["wfbe_commander", objNull]` | `Common/Functions/Common_GetCommanderTeam.sqf:8` |
| east branch | `WFBE_L_OPF getVariable ["wfbe_commander", objNull]` | `Common/Functions/Common_GetCommanderTeam.sqf:9` |
| resistance branch | `WFBE_L_GUE getVariable ["wfbe_commander", objNull]` | `Common/Functions/Common_GetCommanderTeam.sqf:10` |
| default | `objNull` (any other side) | `Common/Functions/Common_GetCommanderTeam.sqf:11` |

The `WFBE_L_BLU` / `WFBE_L_OPF` / `WFBE_L_GUE` side-logic objects it reads are bound in `Common/Init/Init_Common.sqf:290`. The `wfbe_commander` value it returns is written elsewhere — by the vote/disconnect/init path (`Server/Functions/Server_VoteForCommander.sqf`, `Server/PVFunctions/RequestNewCommander.sqf`, `Server/Functions/Server_OnPlayerDisconnected.sqf`, `Server/Init/Init_Server.sqf`, `Client/Functions/Client_FNC_Special.sqf`). The header comment calling it "Return a side's HQ" is stale; the body returns the commander group, not the HQ object (`Common/Functions/Common_GetCommanderTeam.sqf:2`).

Representative call sites confirm it is a commander-authority gate: ICBM authority checks `(_side Call WFBE_CO_FNC_GetCommanderTeam) != _team` before firing, and the upgrade-queue loop requires a non-null human commander team to proceed.

## WFBE_CO_FNC_RunCommanderTeam — overview

This is the per-team driver. The header states the contract precisely: it runs on a HEADLESS CLIENT (dispatched as `delegate-aicom-team`) or on the server as fallback, and the whole team lifecycle stays on the creating machine so waypoints, `doMove`, `assignAsCargo`, and `orderGetIn` all execute with correct locality (`Common/Functions/Common_RunCommanderTeam.sqf:1-5`, `:112-115`).

| Aspect | Detail | Citation |
|---|---|---|
| Params | `[ sideID, template (unit-class array), spawnPos ]`, optional 4th `veteranSkill` | `Common/Functions/Common_RunCommanderTeam.sqf:7`, `:54-55` |
| Spawned as | `_args spawn WFBE_CO_FNC_RunCommanderTeam` on case `delegate-aicom-team` | `Client/PVFunctions/HandleSpecial.sqf:51` |
| Dispatched by | `[_hcUnit,"HandleSpecial",['delegate-aicom-team',_sideID,_template,getPos _facObj,_w7SkillSend]] Call WFBE_CO_FNC_SendToClient` | `Server/AI/Commander/AI_Commander_Teams.sqf:328` |
| Brain contract | ONE public group var `wfbe_aicom_order = [seq, mode, pos]`, mode `"towns-target"` \| `"defense"` | `Common/Functions/Common_RunCommanderTeam.sqf:9-13` |
| Returns | nothing; runs the team's full lifecycle then releases the slot and `deleteGroup`s | `Common/Functions/Common_RunCommanderTeam.sqf:882-889` |

### Creation and founding stance (runs once)

| Step | Behavior | Citation |
|---|---|---|
| Resolve side | `_side = _sideID Call WFBE_CO_FNC_GetSideFromID` | `Common/Functions/Common_RunCommanderTeam.sqf:28` |
| Jitter spawn | `GetRandomPosition` (30–120m) then `GetEmptyPosition` (40m) | `Common/Functions/Common_RunCommanderTeam.sqf:30-31` |
| Build team | `CreateGroup "aicom"` then `CreateTeam` (skill 90) | `Common/Functions/Common_RunCommanderTeam.sqf:33-37` |
| Fail-safe | empty/null team → log WARNING and emit `aicom-team-ended` to release the slot | `Common/Functions/Common_RunCommanderTeam.sqf:39-46` |
| No fleeing | `_team allowFleeing 0` | `Common/Functions/Common_RunCommanderTeam.sqf:48` |
| W7 veteran skill | optional 4th arg: if a positive SCALAR, `setSkill` it on every unit (typeName guard, not A3 `isEqualType`) | `Common/Functions/Common_RunCommanderTeam.sqf:54-59` |
| Founding stance | `setCombatMode "RED"; setBehaviour "AWARE"; setSpeedMode "FULL"` — once | `Common/Functions/Common_RunCommanderTeam.sqf:64` |
| Brain tags | `wfbe_aicom_hc = true` (broadcast, "do not Produce/waypoint directly"); `wfbe_queue = []` (local) | `Common/Functions/Common_RunCommanderTeam.sqf:65-66` |
| Register | emit `aicom-team-created` to the server | `Common/Functions/Common_RunCommanderTeam.sqf:68-72` |

### Heading feed (self-contained ~8s loop)

The order loop below sleeps 20s and blocks during capture, far too coarse to drive a responsive direction arrow, so the heading feed runs on its own Spawn at an ~8s cadence (`Common/Functions/Common_RunCommanderTeam.sqf:76-83`).

| Aspect | Detail | Citation |
|---|---|---|
| Cadence | `sleep 8` per pass; exits on game-over / null / wiped team | `Common/Functions/Common_RunCommanderTeam.sqf:88`, `:108` |
| Bearing | default `getDir leader`; prefer leader→order-dest (slot 2) bearing via A2-safe `atan2` (binary `getDir` is A3-only) | `Common/Functions/Common_RunCommanderTeam.sqf:92-100` |
| Emit | `aicom-team-heading` `[team, dir]` via `HandleSpecial`/`SendToServer` | `Common/Functions/Common_RunCommanderTeam.sqf:102-106` |
| Server gate | server re-broadcasts `WFBE_ACTIVE_AICOM_TEAMS` only when the arrow moved >7° (`abs` smallest-signed-angle) | `Server/Functions/Server_HandleSpecial.sqf:277-303` |

### Air-insertion — own-heli architecture (runs once)

Fires only for teams whose OWN template already spawned a troop-capable AIR transport; it reuses that heli — no second transport is created. Foot infantry load into its cargo seats, overflow walks (`Common/Functions/Common_RunCommanderTeam.sqf:124-130`). Ground vehicles + crews are NOT blocked on the air flag — they get an immediate concurrent MOVE so no crewed hull sits idle (`Common/Functions/Common_RunCommanderTeam.sqf:132-135`, `:149-152`).

| Phase | Behavior | Citation |
|---|---|---|
| Classify vehicles | first `isKindOf "Air"` with `transportSoldier>0` = `_airVeh`; rest = `_grndVehs` | `Common/Functions/Common_RunCommanderTeam.sqf:138-146` |
| Load | `assignAsCargo` + `orderGetIn true` up to `emptyPositions "cargo"`; overflow `doMove _pos` | `Common/Functions/Common_RunCommanderTeam.sqf:160-174` |
| Mark + cost | tag heli `wfbe_aicom_transport=true`; pre-compute build cost via `missionNamespace getVariable (typeOf) select QUERYUNITPRICE` | `Common/Functions/Common_RunCommanderTeam.sqf:187-192` |
| Fly + land | `doMove` LZ, `flyInHeight 60`; flat LZ → `land "GET OUT"` + disembark; no flat LZ → para-eject pattern | `Common/Functions/Common_RunCommanderTeam.sqf:214-239` |
| Drop guard | every dropped pax always gets an unconditional `doMove _obj` | `Common/Functions/Common_RunCommanderTeam.sqf:242` |
| Fly-off | empty transport flies to the NEAREST of the four map edges (`worldSize` hard-coded 15360 — `worldSize` is A3-only in A2 OA) | `Common/Functions/Common_RunCommanderTeam.sqf:249-274` |
| Refund | if it crosses the edge ALIVE, `deleteVehicle` crew+heli and emit `aicom-heli-refunded` `[sideID, cost]`; destroyed en-route = no refund | `Common/Functions/Common_RunCommanderTeam.sqf:276-290` |

The server refund handler validates `_rSide in [east,west,resistance]` (a Side, so `isNull` would throw) and `_rCost > 0`, then `[_rSide,_rCost] Call ChangeAICommanderFunds` (`Server/Functions/Server_HandleSpecial.sqf:334-343`).

### Ground mount-up (runs once, no-air teams only)

When `isNull _airVeh`, the team's own ground IFV/truck/light cargo seats are filled with on-foot template infantry so a mech/motor team RIDES rather than walking from an empty hull (`Common/Functions/Common_RunCommanderTeam.sqf:298-307`).

| Aspect | Detail | Citation |
|---|---|---|
| Ride pool | alive, non-Air, `canMove`, `emptyPositions "cargo" > 0` | `Common/Functions/Common_RunCommanderTeam.sqf:317-321` |
| Seat fill | single-frame, monotonic rider index so no body is double-assigned across hulls; `assignAsCargo`+`orderGetIn true` | `Common/Functions/Common_RunCommanderTeam.sqf:331-345` |
| No-freeze guard | non-blocking, no `waitUntil`/`sleep`; overflow infantry stay on foot and road-march | `Common/Functions/Common_RunCommanderTeam.sqf:308-313`, `:346` |

## RunCommanderTeam — order-execution loop

The main `while {!WFBE_GameOver && _alive}` loop polls every 20s (`Common/Functions/Common_RunCommanderTeam.sqf:352`, `:879`), re-reading `wfbe_aicom_order` each pass. Because A2 groups do not support the `[name, default]` `getVariable` form, every group read here uses plain get + `isNil` (`Common/Functions/Common_RunCommanderTeam.sqf:381-383`).

### PC-scale retirement (B36.1)

When the server flags a rear team via `wfbe_aicom_disband` (rising human player count → fewer HQ squads for relief), the units — being HC-local — must be deleted here. A hard guardrail re-checks on THIS machine that no player is within the safe radius and the leader is not in COMBAT before deleting; otherwise it STANDS DOWN and clears the flag (`Common/Functions/Common_RunCommanderTeam.sqf:355-377`).

| Aspect | Detail | Citation |
|---|---|---|
| Safe radius | `WFBE_C_AICOM_DISBAND_SAFE_DIST` default 900m | `Common/Functions/Common_RunCommanderTeam.sqf:367` |
| Delete | `{if (local _x) then {deleteVehicle _x}} forEach units _team`; sets `_alive=false` | `Common/Functions/Common_RunCommanderTeam.sqf:371-372` |
| Telemetry | `diag_log AICOMSTAT|v1|EVENT|<sideID>|<min>|TEAM_RETIRE_HC|deleted-local-units` | `Common/Functions/Common_RunCommanderTeam.sqf:373` |
| Stand-down | player near OR in combat → `wfbe_aicom_disband=false`, keep fighting | `Common/Functions/Common_RunCommanderTeam.sqf:374-376` |

### Fresh-order branch (seq bump)

The loop acts only when `_seq != _lastSeq`, making each order idempotent (`Common/Functions/Common_RunCommanderTeam.sqf:389-393`).

| Step | Behavior | Citation |
|---|---|---|
| Unstuck tier | read from order slot 3 (`_order select 3`), NOT the out-of-band `wfbe_aicom_unstuck` flag (a later cycle reset it before this block ran, so `UNSTUCK_FIRED` was ~never hit) | `Common/Functions/Common_RunCommanderTeam.sqf:406` |
| Tier 1 | break a physical wedge: lead hull `setVelocity [0,0,0]` + short reverse `modelToWorld [0,-14,0]` | `Common/Functions/Common_RunCommanderTeam.sqf:425-430` |
| Tier 3 (≥3) | last-resort teleport to nearest clear non-water road node — ONLY if no player within 300m | `Common/Functions/Common_RunCommanderTeam.sqf:433-447` |
| Re-mount | members on foot with a live drivable assigned vehicle get `orderGetIn true` | `Common/Functions/Common_RunCommanderTeam.sqf:423` |
| Telemetry | `AICOMSTAT|v2|EVENT|<side>|<min>|UNSTUCK_FIRED|team=…|tier=…` | `Common/Functions/Common_RunCommanderTeam.sqf:419` |
| Road-march | team with a ground vehicle AND `dest>700m`: AWARE/RED/COLUMN/FULL, road-node chain from `wfbe_aicom_route` as MOVE WPs + final MOVE on dest | `Common/Functions/Common_RunCommanderTeam.sqf:459-485` |
| Short/foot | else direct cross-country `MOVE` via `WaypointSimple` | `Common/Functions/Common_RunCommanderTeam.sqf:486-491` |

A2-FIX NOTE: the A3-only `forceFollowRoad` was removed (it throws "Unknown operation" on OA); road-bias now comes from road-snapped MOVE nodes + COLUMN formation (`Common/Functions/Common_RunCommanderTeam.sqf:463-466`).

### Same-seq branch (gear governor + arrival)

| Step | Behavior | Citation |
|---|---|---|
| Careful-gear governor | downshift to LIMITED only on a steep slope (`surfaceNormal` z < `WFBE_C_AICOM_SLOPE_Z` 0.93) OR active stuck-strike; back to FULL when both clear; hysteresis flag `wfbe_aicom_gearslow` fires `setSpeedMode` once per transition | `Common/Functions/Common_RunCommanderTeam.sqf:494-526` |
| Arrival latch | leader within 200m of dest, once: faction smoke, `setSpeedMode "NORMAL"`, then a COMBAT/RED/WEDGE SAD (radius 100 defense / 250 towns) | `Common/Functions/Common_RunCommanderTeam.sqf:529-545` |

### Dismount-capture phase (towns-target)

Runs once per order (`!_captureDone`) when arrived in `"towns-target"` mode. It fixes the old `_hasCargo` branch bug (infantry are already on foot by arrival) by always driving the actual on-foot infantry (`Common/Functions/Common_RunCommanderTeam.sqf:548-574`).

| Step | Behavior | Citation |
|---|---|---|
| Resolve town | `wfbe_aicom_townorder` (HC reads nil — set 2-arg server-side) → fall back to nearest of global `towns` to `_dest`; depot scan = `getPos _townObj` | `Common/Functions/Common_RunCommanderTeam.sqf:582-596` |
| Ranges | `WFBE_C_TOWNS_CAPTURE_RANGE` 40m, `WFBE_C_CAMPS_RANGE` 10m | `Common/Functions/Common_RunCommanderTeam.sqf:596-597` |
| Dismount | every alive non-crew unit → foot; crew (driver/gunner) stay mounted to keep the hull parked + ready | `Common/Functions/Common_RunCommanderTeam.sqf:601-624` |
| Per-camp sweep | close to ≤10m on each camp, `reveal` nearby enemy (2-operand reveal — array form is A3-only), dwell so the `server_town_camp.sqf` "Man" scan ticks | `Common/Functions/Common_RunCommanderTeam.sqf:634-653` |
| Camp-first gate | BOTH camps before the center: tight MOVE inside ~8m, `doStop`+`setUnitPos "UP"` anti-orbit hold; time-boxed 150s, then `setUnitPos "AUTO"` and fall through | `Common/Functions/Common_RunCommanderTeam.sqf:655-728` |
| Depot hold | push foot infantry onto the depot center, lay a SAD, re-reveal; hold until resistance-near-center = 0 OR ~150s | `Common/Functions/Common_RunCommanderTeam.sqf:730-761` |
| Capture latch + re-task | only if `townObj sideID == _sideID`: latch `_captureDone`, drop `wfbe_teamgoto`/townorder/strike/relief so AssignTowns retargets next tick | `Common/Functions/Common_RunCommanderTeam.sqf:765-781` |
| Pure-armour | no infantry: park the hull dead-center (hull counts for the town scan) + SAD; latch | `Common/Functions/Common_RunCommanderTeam.sqf:787-796` |

### Per-tick housekeeping (every same-seq pass)

| Step | Behavior | Citation |
|---|---|---|
| Truck-abandon | once per seq (`wfbe_aicom_trucksabandoned`): dismount crew of ground troop-trucks (not Air/Tank/APC, `transportSoldier>0`), re-task on foot, enroll husk via `aicom-vehicle-abandoned` | `Common/Functions/Common_RunCommanderTeam.sqf:805-838` |
| Immobile-abandon | any non-Air hull that `!canMove` with live crew: dismount, unconditional `doMove`, per-hull husk enroll flag `wfbe_aicom_abandoned` | `Common/Functions/Common_RunCommanderTeam.sqf:840-874` |

### Teardown

On team wipe the loop exits and emits `aicom-team-ended` (`HandleSpecial` on server, else `SendToServer`), then `deleteGroup _team` (`Common/Functions/Common_RunCommanderTeam.sqf:882-889`).

## HandleSpecial message contract

`RunCommanderTeam` is wholly event-driven against the server through these messages; the bodies live in `Server/Functions/Server_HandleSpecial.sqf`.

| Message | Sent from | Server effect | Citation |
|---|---|---|---|
| `aicom-team-created` | `:69`/`:71` | decrement `wfbe_aicom_pending`, append to side `wfbe_teams`, register `[leader,sideID,dir,team]` in `WFBE_ACTIVE_AICOM_TEAMS` + publicVariable | `Server/Functions/Server_HandleSpecial.sqf:215-238` |
| `aicom-team-heading` | `:103`/`:105` | patch the arrow entry's dir only if delta >7°, re-broadcast | `Server/Functions/Server_HandleSpecial.sqf:277-303` |
| `aicom-team-ended` | `:42`/`:44`, `:884`/`:886` | drop the arrow entry, remove from `wfbe_teams` (or release pending if null) | `Server/Functions/Server_HandleSpecial.sqf:239-275` |
| `aicom-vehicle-abandoned` | `:830`/`:832`, `:868`/`:870` | enroll the hull into `WF_Logic "emptyVehicles"` producer list for the empty-collector | `Server/Functions/Server_HandleSpecial.sqf:310-330` |
| `aicom-heli-refunded` | `:284`/`:286` | `[side,cost] Call ChangeAICommanderFunds` (treasury) | `Server/Functions/Server_HandleSpecial.sqf:334-343` |

## A2 OA idioms used (not A3)

The file is deliberately A2-safe. Note the patterns that stand in for A3 equivalents: `atan2` for a leader→dest bearing (binary `getDir` is A3-only, `Common/Functions/Common_RunCommanderTeam.sqf:99`); 2-operand `reveal` only (`:646`, `:699`, `:753`); plain `getVariable` + `isNil` for group vars (the `[name,default]` form is unsupported on groups, `:95`, `:382`); `typeName` rather than `isEqualType` for the skill guard (`:56`); a hard-coded 15360 because `worldSize` is A3-only (`:251`); and the removal of `forceFollowRoad` (`:463-466`, `:489`).

## Continue Reading

- [Quad AI Commander](Quad-AI-Commander)
- [AI Commander Autonomy Audit](AI-Commander-Autonomy-Audit)
- [AI Runtime HC Loop Map](AI-Runtime-HC-Loop-Map)
- [Side Patrol Runtime And Convoy Mechanics](Side-Patrol-Runtime-And-Convoy-Mechanics)
- [Headless Delegation And Failover Playbook](Headless-Delegation-And-Failover-Playbook)
