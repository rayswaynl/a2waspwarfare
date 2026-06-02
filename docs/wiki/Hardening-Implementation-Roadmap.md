# Hardening Implementation Roadmap

This page turns the source-reviewed risk register into implementation-ready work packages. It is for code owners and future agents who are ready to patch gameplay/security behavior, not just document it.

Scope: Chernarus source mission first, then LoadoutManager propagation. All paths below are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

Machine-readable backlog for agents and code owners: [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl). Validation workflow and test evidence schema: [Testing workflow](Testing-Debugging-And-Release-Workflow) and [`agent-test-plan.schema.json`](agent-test-plan.schema.json).

## Patch Order

| Priority | Work package | Why first |
| --- | --- | --- |
| P0 | PVF dispatcher lookup hardening | Smallest behavior-preserving change that closes DR-1 arbitrary code execution and DR-38 per-message recompilation. |
| P0 | ICBM `RequestSpecial` server validation | Highest blast radius: forged PV can trigger server-applied map-wide damage. |
| P1 | Victory/endgame correctness (DR-11 / DR-36) | Small source change with large match-outcome/stat impact. |
| P1 | Server-side economy authority design | Covers the confirmed class: build, buy, sell, supply, upgrade, ICBM and gear/service spend paths. |
| P1 | Direct attack-wave authority | Claude DR-41 confirmed `ATTACK_WAVE_INIT` is a forgeable direct-PV channel that can drive side-wide unit prices to zero or negative values. |
| P1 | Supply mission authority and cooldown cleanup | Needed before PR #1 supply helicopters/cash/interdiction become baseline. |
| P2 | Factory queue, HC/static-defense and support-loop cleanups | Player-facing soft-lock/perf/partial-feature fixes once core authority is moving. |

## P0: PVF Dispatcher Lookup

Evidence:

| File | Current behavior |
| --- | --- |
| `Server/Functions/Server_HandlePVF.sqf` | Reads sender-provided `_script = _publicVar select 0`, then `_parameters Spawn (Call Compile _script)`. |
| `Client/Functions/Client_HandlePVF.sqf` | After destination filtering, reads `_script = _publicVar select 1`, then `_parameters Spawn (Call Compile _script)`. |
| `Common/Init/Init_PublicVariables.sqf` | Already precompiles registered command handlers into `SRVFNC*` and `CLTFNC*` globals. |

Implementation shape:

1. Replace dispatch-time `Call Compile _script` with a validated namespace lookup.
2. Default missing/unregistered command names to a no-op plus a small `WARNING` log.
3. Keep `Spawn` unless a handler audit proves every target is non-sleeping. Several handlers rely on scheduled execution.
4. Do this in both server and client dispatchers in the same patch.

Patch sketch:

```sqf
_handler = missionNamespace getVariable [_script, {}];
if (typeName _handler != "CODE") exitWith {
    ["WARNING", Format ["HandlePVF: rejected unregistered PVF handler [%1].", _script]] Call WFBE_CO_FNC_LogContent;
};
_parameters Spawn _handler;
```

Validation:

- Verify all entries in `_serverCommandPV` and `_clientCommandPV` still resolve to CODE after `Init_PublicVariables.sqf`.
- Test one server request (`RequestJoin` or `RequestVehicleLock`) and one client message (`LocalizeMessage` or `HandleSpecial`) on a hosted/local mission if possible.
- Re-run docs/update notes: this fixes dispatch execution risk only; it does not validate legitimate-command payload forgery.

## P0: ICBM Server Validation

Evidence:

| File | Current behavior |
| --- | --- |
| `Server/PVFunctions/RequestSpecial.sqf` | `_this Spawn HandleSpecial;` with no local validation. |
| `Server/Functions/Server_HandleSpecial.sqf` | `"ICBM"` case trusts `_side`, `_base`, `_target` and `_playerTeam` from payload, waits for `_target` to die, then `[_base] Spawn NukeDammage`. |
| `Client/Module/Nuke/nukeincoming.sqf` | Client sends `["RequestSpecial", ["ICBM", sideJoined, _target, _cruise, clientTeam]]`. |

Implementation shape:

1. Keep presentation and marker behavior client-side, but re-derive authority on the server.
2. In the `"ICBM"` branch, validate side, commander/team ownership, module enabled, required upgrade, funds/cost and target/base object shape.
3. Do not trust a client-supplied team or side without matching it to server-known group state.
4. Debit cost server-side or reject the request; do not rely on the Tactical menu's local `ChangePlayerFunds`.
5. Log rejected attempts with side, UID/team if available and reason.

Validation:

- Valid commander with required ICBM state can still launch.
- Non-commander and wrong-side requests are rejected.
- Bad `_target`, dead `_target`, wrong `_base` and out-of-range/invalid objects do not spawn `NukeDammage`.
- BattlEye filter design still treats `RequestSpecial` as high-risk defense-in-depth, not as the main authority layer.

## P1: Victory And Endgame

Canonical finding: [Deep-review findings](Deep-Review-Findings) DR-11 covers the winner inversion / persisted win-tally bug. DR-36 explains the exact guard/precedence mechanism and confirms the loop is otherwise clean for Perf/JIP.

Evidence:

| File | Current behavior |
| --- | --- |
| `Server/FSM/server_victory_threeway.sqf` | Condition parses as `((!alive _hq) && _factories == 0) || (_towns == _total && !WFBE_GameOver)`, so `!WFBE_GameOver` guards only the all-towns branch. |
| Same file | Side `forEach` does not break after winner is set; same-tick eliminations can double-fire endgame/logging. |

Implementation shape:

1. Split or parenthesize the HQ-elimination and all-towns clauses.
2. Guard the combined result with `!WFBE_GameOver`.
3. Exit the side loop immediately after first winner is recorded.
4. Decide whether threeway victory modes should be implemented or disabled/hidden until implemented.
5. Delete or clearly retire the duplicate buggy `Server/PVFunctions/LogGameEnd.sqf` path if still unused.

Validation:

- One-side elimination logs exactly one winner.
- Same-tick double elimination cannot broadcast/log twice.
- All-towns victory records the intended winner.
- Default victory mode still ends the mission; non-default victory mode behavior is explicitly tested or explicitly disabled.

## P1: Economy Authority Class

Confirmed class: every spend/effect path is client-authoritative or payload-authoritative today.

| Path | Finding | Implementation direction |
| --- | --- | --- |
| Construction | `RequestStructure` / `RequestDefense` trust side/class/pos/dir/manned from payload. | Include requester object in payload; server validates side, commander/repair authority, funds, base area and placement before construction. |
| Player purchases | Buy menu spawns `Client_BuildUnit` locally; no `RequestBuyUnit` PVF exists. | Introduce server-validated buy request for new high-value purchases, or make the owner decision that public-server hardening depends on BattlEye `scripts.txt`. |
| Upgrades | `RequestUpgrade.sqf` forwards raw payload to `Server_ProcessUpgrade.sqf`. | Server validates commander, side, upgrade id/level, dependency and cost; server debits funds/supply. |
| Side supply | `Server_ChangeSideSupply.sqf` trusts direct temp PV deltas and has the negative-delta windfall bug. | Clamp negative overspend to zero change; restrict callers or move supply mutations behind server-owned functions. |
| Gear/EASA/service | Gear/EASA/service effects and debits are client-local. | Add server ledger/effect validation for public-server hardening; add local affordability guards for rearm/refuel as a quick UX bug fix only. |
| Attack waves | `ATTACK_WAVE_INIT` trusts client `_supply` and `_side`; DR-41 shows forged supply can set side-wide unit prices to zero or negative. | Treat direct attack-wave PV as a request; server re-derives side supply, validates permission, deducts cost and clamps modifier/duration. |
| WASP HQ recovery | `WASP/actions/Action_RepairMHQDepot.sqf` applies funds/HQ/town-SV effects mostly client-side. | Move authority checks and town-SV reset to server before expanding HQ recovery. |

Implementation strategy:

1. Pick one ledger model before patching individual spend paths. Mixing partial server authority with old client authority can create new desync.
2. Prefer server recomputation over trusting client-provided price, side, position, upgrade level or reward amounts.
3. Keep client menus as affordance only; server owns final acceptance and debit.
4. Add small `INFORMATION` logs for accepted high-value transactions and `WARNING` logs for rejected malformed/unauthorized requests.

Validation:

- Test legitimate commander/player flows first, then forged/wrong-side payloads.
- Validate both dedicated and hosted/listen paths where locality differs.
- Run LoadoutManager after mission code changes; Chernarus source changes should propagate to vanilla Takistan except skip-list files.

## P1: Direct Attack-Wave Authority

Evidence:

| File | Current behavior |
| --- | --- |
| `Common/Functions/Common_AttackWaveActivate.sqf` | Client/common side writes `ATTACK_WAVE_INIT = [_supply, _side]` and broadcasts it to the server. |
| `Server/Functions/Server_AttackWave.sqf` | Server uses payload `_supply` to compute attack-wave discount and duration/length. |
| `Client/FSM/updateclient.sqf` | The 25,000 supply gate is only the action condition on the client. |
| `Common/Init/Init_CommonConstants.sqf` | `WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT = 50000`; DR-41 shows forged `_supply >= 70000` can make the price modifier zero or negative. |
| `Server/PVFunctions/AttackWave.sqf` | Direct PVEH coordination path; this is outside `_serverCommandPV` and is not fixed by PVF dispatcher lookup alone. |
| `BattlEyeFilter/publicvariable.txt` | Does not filter `ATTACK_WAVE_INIT`; only the AFK feature rule is present in the repo. |

Implementation shape:

Dedicated playbook: [Attack-wave authority](Attack-Wave-Authority-Playbook). Use it before implementation; it records that current source treats 25,000 supply as the minimum action gate while spending all current side supply when the wave starts.

1. Treat `ATTACK_WAVE_INIT` as a request, not as authoritative state.
2. Re-derive side supply and discount inputs server-side from trusted side/town state; never use client `_supply` for price math.
3. Validate requester side and any intended commander/support permission before starting an attack wave.
4. Deduct the intended side-supply cost server-side or reject the request.
5. Clamp the resulting price modifier/duration to sane ranges even after server recomputation.
6. Keep `ATTACK_WAVE_DETAILS` broadcast behavior unless a JIP/replay audit proves a change is needed.

Validation:

- Legitimate attack wave still starts and publishes expected details.
- Forged exaggerated `_supply` cannot change discount, duration, length or cost; `_supply >= 70000` cannot create free or negative-price units.
- Wrong-side or non-authorized requester cannot activate the wave for the other side.
- Late-join behavior remains unchanged or is explicitly documented.

## P1: Supply Missions And PR #1

Evidence:

| File | Current behavior |
| --- | --- |
| `Client/Module/supplyMission/supplyMissionStart.sqf` | Client stamps `SupplyFromTown` and `SupplyAmount` on vehicle object before notifying server. |
| `Server/Module/supplyMission/supplyMissionStarted.sqf` | Server tracks vehicle, scans command-center proximity every 3 seconds, then emits completion. |
| `Server/Module/supplyMission/supplyMissionCompleted.sqf` | Completion reads trusted vehicle object vars for reward/state. |
| `Server/Module/supplyMission/supplyMissionActive.sqf` | Dead twin compiled but not called; live path is `supplyMissionStarted.sqf`. |

Implementation shape:

1. Remove or retire `supplyMissionActive.sqf` compile path.
2. Standardize cooldown casing: `lastSupplyMissionRun` vs `LastSupplyMissionRun`.
3. Recompute reward and source town server-side from trusted truck/town state where possible.
4. Add explicit loaded/unloaded state to prevent duplicate tracking loops and PR #1 stacked `Killed` handlers.
5. Narrow `nearestObjects [(getPos _associatedSupplyTruck), [], 80]` to the specific command-center terminal type.
6. Keep the pull-based cooldown request/response pattern; it is the good JIP model here.

Validation:

- Truck mission works once, twice and after vehicle reuse.
- Destroyed supply vehicle pays interdiction once in PR #1.
- JIP player querying cooldown gets current state.
- Starter disconnect does not orphan completion tracking.

## P2: Smaller Confirmed Fixes

| Fix | Source | Validation |
| --- | --- | --- |
| Factory empty-vehicle queue leak | `Client_BuildUnit.sqf` early empty-vehicle `exitWith` skips normal `WFBE_C_QUEUE` decrement. | Buy repeated crewless vehicles; queue cap returns to normal after each build attempt. |
| Factory FIFO token/broadcast churn | `Client_BuildUnit.sqf` uses random token and broadcasts `queu` mutations. | Multiple simultaneous buyers cannot collide; queue UI remains correct. |
| [Town AI occupied-vehicle despawn](Town-AI-Vehicle-Despawn-Safety) | `server_town_ai.sqf:211-216` deletes inactive town-AI vehicles based on `!(isPlayer leader group _x)` without checking crew/cargo/turret occupants. | Vehicles with any player occupant survive despawn while empty AI-only vehicles are still cleaned. |
| WASP marker monitor busy-spin | `WASP/global_marking_monitor.sqf:62` polls display without sleep for up to 2 seconds. | Replace with throttled wait style like sibling `:80`; verify map double-click prefix still works. |
| MASH markers | Client receiver commented and trigger never sent. | Either remove dead code or revive with server-held marker list, unique names and JIP replay. |
| Paratrooper markers | `HandleParatrooperMarkerCreation` not registered in client PVF list. | Register receiver or remove marker callback; paratroop drop itself remains server-owned. |
| [HC delegation/failover](Headless-Delegation-And-Failover-Playbook) | DR-42: `Client_DelegateAIStaticDefence.sqf:28` has update-back send commented; town-AI delegation still reports through `update-town-delegation`; DR-21 covers missing HC disconnect re-delegation. | Decide whether static-defense delegation is intentionally one-way, then restore update-back/handler or retire stale code; add HC work records before implementing disconnect failover. |
| Hosted FPS monitor loop | DR-19 duplicate: `Server/GUI/serverFpsGUI.sqf` and `Server/Module/serverFPS/monitorServerFPS.sqf` sleep inside `isDedicated`, so hosted/listen paths can loop without sleep. | Track as DR-19, not a separate finding; move sleep outside branches or exit early when not dedicated. |
| Generated `version.sqf` source gap | DR-43: `description.ext` and `initJIPCompatible.sqf` include `version.sqf`, but it is generated/ignored and absent from the committed source tree. | Decide whether to commit a safe placeholder or keep generated-only with explicit pre-pack/pre-test checks. |
| `Init_Server.sqf` duplicate binds | DR-43 corrected re-check: live duplicates for `LogGameEnd`, `PlayerObjectsList` and `AwardScorePlayer`; commented duplicate remnants for AFK kick, server FPS and MASH marker. | De-duplicate live binds and annotate/remove remnants; coordinate `LogGameEnd` cleanup with DR-13/DR-36. |

## Branching And Review Discipline

- One patch branch per work package is preferred: `hardening/pvf-dispatch`, `hardening/icbm-authority`, `hardening/victory-endgame`, `hardening/supply-missions`.
- Do not combine mission hardening with docs-only navigation work.
- For every gameplay patch, update [Feature status](Feature-Status-Register), [Codebase coverage ledger](Codebase-Coverage-Ledger), [Agent worklog](Agent-Worklog) and `agent-context.json`.
- If Claude is active, leave a claim/handoff in `agent-collaboration.json` and `agent-events.jsonl` before touching shared authority code.

## Continue Reading

Previous: [Feature status](Feature-Status-Register) | Next: [Server authority migration map](Server-Authority-Migration-Map)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
