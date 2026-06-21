# Side-Patrol Runtime and Convoy Mechanics (Patrols v2)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Patrols v2 is the side-upgrade-driven roaming patrol system that replaced the old fixed-random-town patrol path (`Server/FSM/server_side_patrols.sqf:9`). A single server FSM (`server_side_patrols.sqf`) is the **driver**: every ~20 s it walks each present side, checks whether that side has researched the Patrols upgrade and is below its concurrent cap, resolves a tier-appropriate unit template from the faction Root pools, and dispatches one patrol — onto a live headless client when one is registered, otherwise on the server. The patrol itself runs `Common_RunSidePatrol.sqf`, which creates the team, drives it toward the frontline, sweeps camps on arrival, and (at Patrols level 4) escorts a convoy supply truck that pays the owning side cash at each town it reaches.

The [Towns-Camps-And-Capture-Atlas](Towns-Camps-And-Capture-Atlas) documents *where* Patrols v2 hooks into the town system and the branch-matrix across roots; this page is the runtime/tuning deep-dive that atlas single-sources and defers. All constant values below are the live defaults read from `Common/Init/Init_CommonConstants.sqf` (and `Server/Init/Init_Server.sqf` for the spawn delay).

## Driver loop (`Server/FSM/server_side_patrols.sqf`)

The driver waits for `townInitServer`, sleeps 30 s, initializes the public marker arrays, then loops on a 20 s cadence over `WFBE_PRESENTSIDES` until `WFBE_GameOver`.

| Stage | Behavior | Source |
| --- | --- | --- |
| Boot gate | `waitUntil {townInitServer}; sleep 30` before the first pass | `Server/FSM/server_side_patrols.sqf:16-17` |
| Marker arrays | `WFBE_ACTIVE_PATROLS` (patrol leaders) and `WFBE_ACTIVE_AICOM_TEAMS` initialized + `publicVariable`'d once so JIP clients see defined arrays | `Server/FSM/server_side_patrols.sqf:19,23` |
| Tunables read | `_delay = WFBE_C_PATROLS_DELAY_SPAWN`, `_max = WFBE_C_SIDE_PATROLS_MAX` | `Server/FSM/server_side_patrols.sqf:25-26` |
| Per-side iteration | `{ ... } forEach WFBE_PRESENTSIDES` | `Server/FSM/server_side_patrols.sqf:29,83` |
| Loop cadence | `sleep 20` at the bottom of each pass | `Server/FSM/server_side_patrols.sqf:85` |

### Per-side gating chain

For each present side the driver resolves the side logic and only proceeds if Patrols is researched and the spawn slot/cooldown allows it.

| Check | Condition | Source |
| --- | --- | --- |
| Side logic exists | `_logik = side Call WFBE_CO_FNC_GetSideLogic; if (!isNull _logik)` | `Server/FSM/server_side_patrols.sqf:34-35` |
| Upgrade level | `_lvl = _upgrades select WFBE_UP_PATROLS` (index `WFBE_UP_PATROLS = 23`), guarded to 0 if the array is short; must be `> 0` | `Server/FSM/server_side_patrols.sqf:36-38`, `Common/Init/Init_CommonConstants.sqf:60` |
| Active count | `_active = _logik getVariable ["wfbe_side_patrols", 0]` | `Server/FSM/server_side_patrols.sqf:39` |
| Cooldown | `_last = _logik getVariable ["wfbe_side_patrol_last", -(_delay)]`; requires `time - _last > _delay` | `Server/FSM/server_side_patrols.sqf:40-41` |
| Effective cap | `_active < (_maxSide min _lvl)` — the cap is **level-aware** | `Server/FSM/server_side_patrols.sqf:41` |
| HQ + towns | needs `!isNull _hq && count _owned > 0` (owned = towns whose `sideID` matches) | `Server/FSM/server_side_patrols.sqf:42-50` |

The effective concurrent cap is the keystone formula: **`min(side cap, researched patrol level)`** (`Server/FSM/server_side_patrols.sqf:41`). At Patrols level 1 a side may have only 1 patrol; at level 2+ the side cap dominates (2 for WEST/EAST). The author comment B36.1 documents the intent: patrols stay low even as the HQ-team curve scales up.

### Spawn point and home town

The patrol spawns at the side's owned town **nearest its HQ** (`_home = [_hq, _owned] Call WFBE_CO_FNC_GetClosestEntity`, `Server/FSM/server_side_patrols.sqf:51`). If a side has researched Patrols but holds no towns yet, the driver logs a one-shot observability line and waits (`wfbe_patrol_waitlog` latch, `Server/FSM/server_side_patrols.sqf:46-49`).

## Tier selection and faction pools

The tier follows the upgrade level. The driver resolves the template **server-side** (the pools are server-only) and ships the chosen unit-class array to the runner.

| Patrols level | Tier | Pool variable | Source |
| --- | --- | --- | --- |
| 1 | `LIGHT` | `WFBE_%1_PATROL_LIGHT` | `Server/FSM/server_side_patrols.sqf:52,57` |
| 2 | `MEDIUM` | `WFBE_%1_PATROL_MEDIUM` | `Server/FSM/server_side_patrols.sqf:52,57` |
| 3+ | `HEAVY` | `WFBE_%1_PATROL_HEAVY` | `Server/FSM/server_side_patrols.sqf:52,57` |

The template is a uniform random pick: `_template = _pool select floor(random count _pool)` (`Server/FSM/server_side_patrols.sqf:59`). The pools are defined per faction in the `Core_Root` configs as arrays of unit-class arrays; for example the GUE pools at `Common/Config/Core_Root/Root_GUE.sqf:43,56,67` range from recon-foot / technical raiders (LIGHT) through SPG-9 and ZU-23 technicals (MEDIUM) to BRDM-2 / T-72 mechanized columns (HEAVY). Each template array carries at least one `Man`-class soldier because the runner rejects crew-only teams (`Common/Config/Core_Root/Root_GUE.sqf:41`).

### GUER "comeback force" scaling

The defender/resistance side (`WFBE_DEFENDER = resistance`, `Common/Init/Init_Common.sqf:296`) gets two special overrides that make it field **fewer but deadlier** patrols, scaled by how few towns it holds.

| Override | Rule | Source |
| --- | --- | --- |
| Cap | `_maxSide` = 3 when GUER holds `< 20` towns, else `WFBE_C_SIDE_PATROLS_MAX_DEFENDER` (default 1) | `Server/FSM/server_side_patrols.sqf:33` |
| Tier | forced `HEAVY` when GUER owns `< 20` towns, else `MEDIUM` (always min MEDIUM — never LIGHT/foot) | `Server/FSM/server_side_patrols.sqf:56` |

The intent (author comment B36, `Server/FSM/server_side_patrols.sqf:53-55`): GUER patrols are a mechanized insurgent comeback force — always mounted, and the fewer towns GUER holds the heavier the patrol. The `< 20`-town threshold gives a struggling resistance side a higher cap *and* the HEAVY pool simultaneously. The runner adds a matching combat-skill boost (below).

## Dispatch: headless client vs. server

The driver books the slot synchronously **before** dispatch (so a slow spawn cannot double-book), then runs the patrol on the least-loaded live HC if one exists, else locally on the server.

| Step | Action | Source |
| --- | --- | --- |
| Book slot | `_logik setVariable ["wfbe_side_patrols", _active + 1]`; `setVariable ["wfbe_side_patrol_last", time]` | `Server/FSM/server_side_patrols.sqf:62-63` |
| Pick HC | `_hcUnit = Call WFBE_CO_FNC_PickLeastLoadedHC` | `Server/FSM/server_side_patrols.sqf:65` |
| HC path | `[_hcUnit, "HandleSpecial", ['delegate-sidepatrol', _sideID, _template, _home]] Call WFBE_CO_FNC_SendToClient` | `Server/FSM/server_side_patrols.sqf:67` |
| Server path | `[_sideID, _template, _home] Spawn WFBE_CO_FNC_RunSidePatrol` | `Server/FSM/server_side_patrols.sqf:69` |
| HC receiver | `case "delegate-sidepatrol": {_args spawn WFBE_CO_FNC_RunSidePatrol}` | `Client/PVFunctions/HandleSpecial.sqf:50` |

`WFBE_CO_FNC_RunSidePatrol` compiles from `Common/Functions/Common_RunSidePatrol.sqf` (`Common/Init/Init_Common.sqf:107`). The whole patrol lifecycle stays on the machine that created the group so waypoints keep locality; slot bookkeeping (the `wfbe_side_patrols` counter + `WFBE_ACTIVE_PATROLS` marker list) always lives on the server, reached by direct `Call HandleSpecial` when local or `RequestSpecial` when on an HC (`Common/Functions/Common_RunSidePatrol.sqf:5-8`). After a successful dispatch the driver clears the wait-log latch, writes an AICOM log line, and records a `side_patrol_spawn` `PerformanceAudit` sample when auditing is enabled (`Server/FSM/server_side_patrols.sqf:71-77`).

## Runner: team creation and crewless guard (`Common/Functions/Common_RunSidePatrol.sqf`)

The runner receives `[sideID, template, homeTown]`, picks a random empty position 100–400 m from the home town, creates the group, and builds the team.

| Step | Detail | Source |
| --- | --- | --- |
| Spawn position | `[getPos _homeTown, 100, 400] Call WFBE_CO_FNC_GetRandomPosition`, then `[_position, 50] Call WFBE_CO_FNC_GetEmptyPosition` | `Common/Functions/Common_RunSidePatrol.sqf:35-36` |
| Group | `[_side, "patrol"] Call WFBE_CO_FNC_CreateGroup` | `Common/Functions/Common_RunSidePatrol.sqf:38` |
| Team | `[_template, _position, _side, true, _team, true, 90] call WFBE_CO_FNC_CreateTeam` → `[_units, _vehicles, _team]` | `Common/Functions/Common_RunSidePatrol.sqf:39-42` |
| Crewless guard | `if (isNull _team \|\| {count _units == 0}) exitWith { ... }` — deletes leaked vehicles + units, deletes the group, releases the slot via `sidepatrol-ended` | `Common/Functions/Common_RunSidePatrol.sqf:44-58` |

The crewless guard is a load-bearing fix (2026-06-11, `Common/Functions/Common_RunSidePatrol.sqf:45-48`): a spawn that produced 0 units but N vehicles previously passed the total-only guard, instantly failed the alive-check, and leaked empty vehicles at the spawn town forever (observed piling up at Mogilevka) while re-dispatching in a loop. "No infantry = no patrol": the team is wiped and the slot released. On creation the team gets `allowFleeing 0` and `setVariable ["WFBE_SidePatrol", true]` (`Common/Functions/Common_RunSidePatrol.sqf:60-61`).

### Resistance skill boost

For `resistance` patrols only, every live unit's combat skill is maxed and scaled by owned-town scarcity, so a lone GUER patrol is a genuine threat.

| Skill | Value | Source |
| --- | --- | --- |
| Base skill | `_pskill = ((WFBE_C_SIDE_PATROL_GUER_SKILL default 0.85) + 0.03 * (6 - (_gt min 6))) min 1`, where `_gt` = GUER-owned town count | `Common/Functions/Common_RunSidePatrol.sqf:68,71` |
| `aimingAccuracy` | `(0.78 + 0.03 * (6 - (_gt min 6))) min 0.95` | `Common/Functions/Common_RunSidePatrol.sqf:72` |
| `spotDistance` | `1` | `Common/Functions/Common_RunSidePatrol.sqf:73` |
| `spotTime` | `1` | `Common/Functions/Common_RunSidePatrol.sqf:74` |
| `courage` | `1` | `Common/Functions/Common_RunSidePatrol.sqf:75` |

The fewer towns GUER owns (lower `_gt`), the higher both the overall skill and aiming accuracy. The boost is gated to `_side == resistance` so WEST/EAST patrols are unchanged (`Common/Functions/Common_RunSidePatrol.sqf:67`). Note: the in-source comment at `Common/Functions/Common_RunSidePatrol.sqf:66` says "default 0.92", but the actual code default and the constant fallback are **0.85** (`Common/Functions/Common_RunSidePatrol.sqf:68`) — `WFBE_C_SIDE_PATROL_GUER_SKILL` is not set in `Init_CommonConstants.sqf`, so the inline `0.85` fallback is what runs. After the boost the runner fires `sidepatrol-started` with the leader so the public marker list and Commander arrow-feed pick it up (`Common/Functions/Common_RunSidePatrol.sqf:80-85`).

## Level-4 convoy supply truck (Task 41)

At Patrols **level 4** the runner spawns a side-appropriate supply truck, joins it to the patrol group (no new group), and pays the owning side cash each time the patrol reaches a town with the truck still alive nearby.

| Element | Detail | Source |
| --- | --- | --- |
| Level gate | `_upgLvl = _ups select WFBE_UP_PATROLS; if (_upgLvl >= 4)` | `Common/Functions/Common_RunSidePatrol.sqf:92-95` |
| Truck class | prefer `T810_CZ_EP1` when its config class exists (ACR DLC), else `WFBE_%1SUPPLYTRUCKS` first entry | `Common/Functions/Common_RunSidePatrol.sqf:96-101` |
| Driver | created from `WFBE_%1SOLDIER` (crew soldier class), `moveInDriver _truckVeh` | `Common/Functions/Common_RunSidePatrol.sqf:106-107` |
| Pay constant | `_convoyPay = WFBE_C_PATROL_CONVOY_PAY` (default 750) | `Common/Functions/Common_RunSidePatrol.sqf:91`, `Common/Init/Init_CommonConstants.sqf:600` |
| Payout trigger | on town arrival: `!_paidThisVisit && !isNull _truckVeh && alive _truckVeh && (leader _team) distance _truckVeh < 150` | `Common/Functions/Common_RunSidePatrol.sqf:241-242` |
| Once-per-visit guard | `_paidThisVisit` set true on payout, reset to false when a new target town is chosen | `Common/Functions/Common_RunSidePatrol.sqf:124,243` |
| Payout signal | `["sidepatrol-convoy-stop", _sideID, _target] Call HandleSpecial` (server) / `RequestSpecial` (HC) | `Common/Functions/Common_RunSidePatrol.sqf:244-248` |

A second 2026-06-11 fix (`Common/Functions/Common_RunSidePatrol.sqf:103-105`) corrected the driver previously being created from the *truck* classname (a vehicle class as a soldier = no driver, truck never moves, convoy pay never fires); it now uses the side crew-soldier class, the same source `HandleDefense` uses.

### Convoy payout handler (`Server/Functions/Server_HandleSpecial.sqf`)

The `sidepatrol-convoy-stop` case divides a fixed pool **equally among living players** on the owning side and routes each share through the `BankPayout` client channel.

| Step | Detail | Source |
| --- | --- | --- |
| Pool | `_cPool = WFBE_C_PATROL_CONVOY_PAY` (default 750) | `Server/Functions/Server_HandleSpecial.sqf:380` |
| Eligible players | `isPlayer _x && alive _x && side _x == _cSide` over `playableUnits` | `Server/Functions/Server_HandleSpecial.sqf:383` |
| Per-player share | `_cShare = round (_cPool / (_cCount max 1))` | `Server/Functions/Server_HandleSpecial.sqf:384` |
| Delivery | `[_cSide, "BankPayout", [_cShare]] Call WFBE_CO_FNC_SendToClients` (side-addressed) | `Server/Functions/Server_HandleSpecial.sqf:386` |

The client `BankPayout.sqf` handler applies the share via `WFBE_CL_FNC_ChangeClientFunds` and shows a quiet `BankDividend` group-chat line; it guards `!alive player` so a player dead at the tick does not apply a share (`Client/PVFunctions/BankPayout.sqf:14-19`). The convoy reuses the Bank dividend channel — same PVF, different funding source.

## Frontline gravitation and the camp-sweep state machine

Once running, the patrol enters a 30 s-cadence loop (`while {!WFBE_GameOver && _alive}`, `Common/Functions/Common_RunSidePatrol.sqf:119,259`) that keeps it moving toward the frontline and sweeping camps on arrival.

| Phase | Behavior | Source |
| --- | --- | --- |
| Alive check | `_alive = false` when live-unit count is 0 or the team is null | `Common/Functions/Common_RunSidePatrol.sqf:120` |
| Target pick | nearest town the side does **not** own (`sideID != _sideID`); if it owns everything, roam own towns | `Common/Functions/Common_RunSidePatrol.sqf:123-128` |
| Move order | `[_team, getPos _target, 'MOVE', 25] Spawn WFBE_CO_FNC_WaypointSimple` | `Common/Functions/Common_RunSidePatrol.sqf:130` |
| Arrival | when `(leader _team) distance _target < 200` | `Common/Functions/Common_RunSidePatrol.sqf:133` |
| Town flip | when target's `sideID` becomes `_sideID`, clear `_target` and gravitate to the next frontline town | `Common/Functions/Common_RunSidePatrol.sqf:251-253` |

### Camp sweep (Task 40)

On first arrival at a target town the patrol sweeps the town's camps **sequentially** to let presence-based capture tick, guarded once-per-visit by the `wfbe_patrol_sweep_town` group variable.

| Step | Behavior | Source |
| --- | --- | --- |
| Sweep guard | `_sweepDone = _team getVariable "wfbe_patrol_sweep_town"`; sweep only if `isNil` or `!= _target` (1-arg + isNil to dodge the A2 group-getVariable nil quirk) | `Common/Functions/Common_RunSidePatrol.sqf:139-141` |
| Camp list | `_townCamps = _target getVariable ["camps", []]`; range fallback `WFBE_C_CAMPS_RANGE` (constant value 10) defaulting to 30 inline | `Common/Functions/Common_RunSidePatrol.sqf:143-145`, `Common/Init/Init_CommonConstants.sqf:270` |
| Per-camp move | `(leader _team) doMove (getPos _campObj)` then settle wait ≤ 20 s or leader within `_campRange` | `Common/Functions/Common_RunSidePatrol.sqf:159-166` |
| Dismount | unassign every live non-driver inside a vehicle (keep one driver per vehicle), `doMove` them to the camp | `Common/Functions/Common_RunSidePatrol.sqf:170-192` |
| Dwell | `sleep 75` at the camp (settle + dwell ≈ 75 s so capture ticks) | `Common/Functions/Common_RunSidePatrol.sqf:194-195` |
| Remount | re-`assignAsCargo` dismounts to `_vehicles select 0`, `orderGetIn true`, 25 s grace | `Common/Functions/Common_RunSidePatrol.sqf:197-207` |
| Center push | if all camps are ours OR `time - _sweepStart > 480` (8 min): dismount all non-drivers, send to town center, **no** remount (hold/fight) | `Common/Functions/Common_RunSidePatrol.sqf:210-236` |

The 8-minute total-sweep timeout (`Common/Functions/Common_RunSidePatrol.sqf:218`) and the all-camps-ours check (`Common/Functions/Common_RunSidePatrol.sqf:212-216`) both trigger the final town-center push; the `_allOurs` test treats any null/dead camp or any camp whose `sideID != _sideID` as not-ours.

## Slot lifecycle and cooldown

A patrol slot is booked at dispatch and released on death. The release re-arms the per-side spawn cooldown.

| Event | When | Effect | Source |
| --- | --- | --- | --- |
| `sidepatrol-started` | runner after team build | appends `[leader, sideID]` to `WFBE_ACTIVE_PATROLS`, broadcasts | `Server/Functions/Server_HandleSpecial.sqf:345-353` |
| `sidepatrol-ended` | runner on wipe/crewless | `wfbe_side_patrols` decremented (`max 0`), `wfbe_side_patrol_last = time` (re-arms cooldown), entry pruned from the public list | `Server/Functions/Server_HandleSpecial.sqf:355-372`, `Common/Functions/Common_RunSidePatrol.sqf:53-57,262-269` |
| Driver re-book | next 20 s pass | new spawn only after `time - _last > WFBE_C_PATROLS_DELAY_SPAWN` | `Server/FSM/server_side_patrols.sqf:40-41` |

Because `wfbe_side_patrol_last` is set both at dispatch (`Server/FSM/server_side_patrols.sqf:63`) and again on end (`Server/Functions/Server_HandleSpecial.sqf:363`), a side must wait the full spawn delay after a patrol dies before the next one can be dispatched, independent of the concurrent-cap check. The final `deleteGroup _team` happens after the `sidepatrol-ended` signal (`Common/Functions/Common_RunSidePatrol.sqf:269`).

## Tunables reference

| Constant | Value | Meaning | Source |
| --- | --- | --- | --- |
| `WFBE_UP_PATROLS` | `23` | upgrade index read from a side's upgrade array | `Common/Init/Init_CommonConstants.sqf:60` |
| `WFBE_C_SIDE_PATROLS_MAX` | `2` | WEST/EAST concurrent patrol cap (effective cap is `min` of this and patrol level) | `Common/Init/Init_CommonConstants.sqf:63` |
| `WFBE_C_SIDE_PATROLS_MAX_DEFENDER` | `1` | GUER cap when it holds ≥ 20 towns (3 below that) | `Common/Init/Init_CommonConstants.sqf:683` |
| `WFBE_C_PATROLS_DELAY_SPAWN` | `360` | seconds before a side may re-spawn a patrol (set in Init_Server) | `Server/Init/Init_Server.sqf:170` |
| `WFBE_C_SIDE_PATROL_GUER_SKILL` | `0.85` (inline fallback; not set in constants) | resistance patrol base skill before town-scarcity scaling | `Common/Functions/Common_RunSidePatrol.sqf:68` |
| `WFBE_C_PATROL_CONVOY_PAY` | `750` | level-4 convoy cash pool, split among living owning-side players per town stop | `Common/Init/Init_CommonConstants.sqf:600` |
| `WFBE_C_CAMPS_RANGE` | `10` | leader-to-camp settle distance (runner inline fallback 30 if unset) | `Common/Init/Init_CommonConstants.sqf:270` |

## Continue Reading

- [Towns, Camps, and Capture Atlas](Towns-Camps-And-Capture-Atlas) — where Patrols v2 hooks into the town/camp system and the cross-root branch matrix
- [AI Squad and Team Templates Catalog](AI-Squad-Team-Templates-Catalog) — the Commander-deployable squad templates (distinct from the `WFBE_%1_PATROL_*` Root pools)
- [Faction Root Variables Reference](Faction-Root-Variables-Reference) — the `WFBE_%side%_PATROL_LIGHT/MEDIUM/HEAVY` and `WFBE_%1SUPPLYTRUCKS` variable families
- [Headless Delegation and Failover Playbook](Headless-Delegation-And-Failover-Playbook) — how `delegate-sidepatrol` and `PickLeastLoadedHC` fit the wider HC dispatch model
- [Upgrades and Research Atlas](Upgrades-And-Research-Atlas) — the Patrols upgrade levels (1–4) that gate tier, cap, and the convoy truck
