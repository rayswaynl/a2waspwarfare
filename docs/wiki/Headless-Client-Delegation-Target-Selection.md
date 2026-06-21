# Headless Client Delegation Target Selection (least-loaded picker)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`Server/Functions/Server_PickLeastLoadedHC.sqf` is the single source of truth for "which headless client receives this delegated AI." Every server-side delegation site that targets an HC routes through it. The function returns the **leader object** of the live HC that currently owns the fewest units (`Server_PickLeastLoadedHC.sqf:4-6`), so delegation spreads roughly evenly across all registered HCs instead of the old blind random coin-flip.

It is compiled and bound **unconditionally** at boot as `WFBE_CO_FNC_PickLeastLoadedHC` (`Server/Init/Init_Server.sqf:126`), deliberately ahead of the OA-version delegation gate because the commander/patrol/wildcard call sites are not gated by that check (`Init_Server.sqf:124-125`).

## The algorithm (step by step)

`Server_PickLeastLoadedHC.sqf` takes no parameters and reads everything from `allUnits` plus the HC registry at call time.

| Step | What happens | Source |
| --- | --- | --- |
| Read registry | `_hcs = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]` | `Server_PickLeastLoadedHC.sqf:31` |
| Filter to LIVE HCs | Keep group `_x` only if `!isNull _x && {!isNull leader _x} && {alive leader _x}` | `Server_PickLeastLoadedHC.sqf:36-38` |
| No live HC | `if (count _live == 0) exitWith {objNull}` | `Server_PickLeastLoadedHC.sqf:40` |
| Single-HC fast path | `if (count _live == 1) exitWith {leader (_live select 0)}` — skip the scan | `Server_PickLeastLoadedHC.sqf:41` |
| Build parallel arrays | `_owners[i] = owner (leader _live[i])`, `_counts[i] = 0` | `Server_PickLeastLoadedHC.sqf:45-50` |
| Tally `allUnits` by owner | one pass: `_o = owner _x`, `_idx = _owners find _o`, bump `_counts[_idx]` if found | `Server_PickLeastLoadedHC.sqf:52-56` |
| argmin (find min load) | walk `_counts`, track `_bestLoad` (seeded `1e10`) | `Server_PickLeastLoadedHC.sqf:59-62` |
| Collect ties | gather every index where `_counts[i] <= _bestLoad` into `_ties` | `Server_PickLeastLoadedHC.sqf:64-67` |
| RANDOM tie-break | `_pick = _ties select (floor (random (count _ties)))` | `Server_PickLeastLoadedHC.sqf:71` |
| Return | `leader (_live select _pick)` | `Server_PickLeastLoadedHC.sqf:72` |

The live-filter is load-bearing: a stale registry entry (an HC that dropped between prunes) would otherwise route the delegation to a null leader and the AI would silently never spawn (`Server_PickLeastLoadedHC.sqf:33-34`). The function returns `objNull` when there is no live HC, and **callers must check `isNull` and fall back or drop** (`Server_PickLeastLoadedHC.sqf:25-26`).

## Why least-loaded, not random

The function header (`Server_PickLeastLoadedHC.sqf:8-22`) documents the rationale, and it directly contrasts the current behavior against "the old blind `leader(_live select floor(random count _live))` coin-flip" (`Server_PickLeastLoadedHC.sqf:6`).

| Property | Old random pick | Least-loaded picker |
| --- | --- | --- |
| Load shape | small number of LARGE atomic batches (whole-town activations of merged groups, whole commander platoons) | same input |
| Variance over 2 HCs | high; blind random never self-corrects | reads current per-HC count every call |
| Sticky delegation | delegated units do not migrate (no `setGroupOwner` in OA), so early random luck **compounds into a permanent 70-90% pile-up** on one HC | once an HC gets heavy it stops being chosen until the other catches up — self-correcting by construction |
| Source | `Server_PickLeastLoadedHC.sqf:8-12` | `Server_PickLeastLoadedHC.sqf:13-14` |

The random tie-break exists so the picker **degrades gracefully to uniform-random when loads are genuinely equal** (e.g. both HCs empty at warm-up) and never lock-steps onto the first-registered HC (`Server_PickLeastLoadedHC.sqf:21-22`, `:69-70`).

## The routing key

Load is measured the same way work is routed. An HC "owns" exactly the units whose `owner` equals `owner (leader hcGroup)` — the identical key `Common_SendToClient` uses to dispatch the delegate message (`Server_PickLeastLoadedHC.sqf:16-19`).

| Concern | Key | Source |
| --- | --- | --- |
| Picker tallies units by | `owner _x` for each unit in `allUnits`, matched against `owner (leader _live[i])` | `Server_PickLeastLoadedHC.sqf:48`, `:53` |
| `SendToClient` dispatches by | `_id = owner (_pvf select 0)` where `_pvf select 0` is the HC leader | `Common/Functions/Common_SendToClient.sqf:11` |

Because both use `owner leader`, the count the picker minimizes is the same population that lands on the chosen HC. The tally is taken **once on the server** every call — no telemetry dependency, no 60s lag, accurate the instant a unit is created (`Server_PickLeastLoadedHC.sqf:16-19`). The same single-pass `allUnits`-by-owner bucketing is reused by the commander's per-HC load telemetry (`Server/AI/Commander/AI_Commander.sqf:418-426`, which cites `Server_PickLeastLoadedHC:45-56` as the model).

## Caller census

Every site below calls `WFBE_CO_FNC_PickLeastLoadedHC` and then checks `isNull` before sending (or falls back / drops). All citations confirmed via `grep -n PickLeastLoadedHC`.

| Caller | Line | What it delegates | No-live-HC behavior |
| --- | --- | --- | --- |
| `Server/Functions/Server_DelegateAITownHeadless.sqf` | `:29` | town AI groups (whole-town activation) | drop/log; see HC-pick hoist below |
| `Server/Functions/Server_DelegateAIStaticDefenceHeadless.sqf` | `:25` | static town-defence groups (per-group, in a `for` loop) | `if (!isNull _hcUnit)` then send, else skip (`:26-30`) |
| `Server/AI/Commander/AI_Commander_Teams.sqf` | `:319` | commander team — a whole platoon as one atomic lump | falls back to `leader (_live select 0)` rather than abort, to avoid leaking deducted funds / pending slot (`:321-324`) |
| `Server/FSM/server_side_patrols.sqf` | `:65` | side patrol (`delegate-sidepatrol`) | else `Spawn WFBE_CO_FNC_RunSidePatrol` locally (`:66-70`) |
| `Server/Functions/AI_Commander_Wildcard.sqf` | `:573` (W6 air-cav patrol) | side patrol | else local fallback (`:574+`) |
| `Server/Functions/AI_Commander_Wildcard.sqf` | `:712` (W6 air platoon) | commander air team | else local fallback `Spawn WFBE_CO_FNC_RunCommanderTeam` (`:716-720`) |
| `Server/Functions/AI_Commander_Wildcard.sqf` | `:1138` (W19 air lump) | commander air team (`delegate-aicom-team`) | else local fallback (`:1135-1141`) |
| binding | `Server/Init/Init_Server.sqf:126` | compiles the picker as `WFBE_CO_FNC_PickLeastLoadedHC` | n/a |

### Town delegation HC-pick hoist

`Server_DelegateAITownHeadless.sqf` calls the picker **once**, not once per group. The picker walks `allUnits` (O(allUnits)); calling it per group made the cost O(groups x allUnits) — the measured 614ms town-activation spike (`Server_DelegateAITownHeadless.sqf:22-25`). Instead it runs the expensive scan once to choose the lightest live HC (`:29`), then builds the live-HC leader list locally with the same liveness test (`:35-37`) and distributes the town's groups across all live HCs with a cheap **local round-robin seeded at that lightest HC** (`:30-34`). Same anti-pile-up goal, same `SendToClient` payload, same `owner (leader)` routing — `allUnits` is just walked once instead of once per group.

## IMPORTANT correction: two existing pages still say "random"

Two older wiki pages describe HC selection as random. That description **predates the least-loaded picker** and is superseded on current master `0139a346`. State the current behavior with the source line that proves it — `Server_PickLeastLoadedHC.sqf:6`, whose own header contrasts the new picker against "the old blind ... coin-flip."

| Stale page | What it currently says | Current truth |
| --- | --- | --- |
| [Headless Delegation and Failover Playbook](Headless-Delegation-And-Failover-Playbook) | `Server_DelegateAITownHeadless.sqf:22-30` "picks a random HC group for each delegation batch" (page line 46); static defence "also chooses a random HC group" (page line 65); "Random selection is load-spreading only" (page line 54) | town delegation calls the least-loaded picker once and round-robins from it (`Server_DelegateAITownHeadless.sqf:29`); static defence calls it per group (`Server_DelegateAIStaticDefenceHeadless.sqf:25`) |
| [Headless Client Scaling and Topology](Headless-Client-Scaling-And-Topology) | Mode 2 selection is "**random** HC per group" (page line 19); lists "Replace the per-call `random` pick" / "replace random HC selection with tracked least-loaded selection" as a **future improvement** (page lines 88, 129) | the source already implements least-loaded selection (`Server_PickLeastLoadedHC.sqf:4-72`); the "future TODO" is already done |

Do not re-derive or contradict-hunt: the picker simply landed after those pages were written. When updating them, point at `Server_PickLeastLoadedHC.sqf` and `Init_Server.sqf:126`.

## Continue Reading

- [Headless Delegation and Failover Playbook](Headless-Delegation-And-Failover-Playbook)
- [Headless Client Scaling and Topology](Headless-Client-Scaling-And-Topology)
- [AI Runtime And HC Loop Map](AI-Runtime-HC-Loop-Map)
- [AI Headless And Performance](AI-Headless-And-Performance)
- [Networking And Public Variables](Networking-And-Public-Variables)
