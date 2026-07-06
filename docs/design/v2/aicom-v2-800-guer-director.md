# AICOM V2 Behaviour Spec 800: GUER Director (Virtual Resistance Ledger + Lightweight Brain)

Guide rev: GUIDE-REV GR-2026-07-03a.
Status: **APPROVED FOR IMPLEMENTATION** (Ray 2026-07-05; concept approved 2026-07-04 as option B). Relief waves are in scope (see Behaviour 2 and the wave rules below). Owner decisions D1 and D2 are both resolved (D2: implementation ruling 2026-07-05; D1: decision menu 2026-07-06 — retake defaults 0 on Chernarus, low on Takistan). **Amendment A1 (Player Commissar Panel, owner decisions 2026-07-06) is part of this lane** — see the amendment section at the end of this document. Sequencing: after the V2 cutover stabilises, per `AICOM-V2-CUTOVER-AND-RECONCILIATION.md`. Markdown only; no gameplay code in this worktree.
Scope: an invisible, in-theme "A-Life" layer for the resistance side — a persistent virtual population (per-town strength ledger + virtual cells moving between towns) with a small Assessment/Planning brain (reinforce, regroup, ambush, retake) on top. It replaces the memoryless respawn behaviour of V1 town garrisons and gives the third side agency, while staying invisible as a system: players only ever see resistance units doing plausible resistance things.

This lane is deliberately different from every other V2 lane in one way: it is the **single authorized writer of GUER volume**, and therefore defaults **OFF** (all other lane switches default 1). Lane 424 (Third-side) remains fully volume-protected and unchanged; see "Relationship To Lane 424".

## Doctrine Fit

The V2 doctrine says punish and remember, refuse fair fights, keep tempo, and never go psychic. V1 resistance does none of this: garrisons respawn at full strength 90 seconds after being wiped, never reinforce a neighbour, never regroup, and never punish an overextended attacker. The Director gives the third side exactly those doctrine behaviours — at the population level, not the commander level:

- **Punish + remember (inverted):** the world remembers what players did to it. A garrison bled at dawn is still bled at noon unless reinforcements physically (virtually) arrived from a neighbouring resistance town.
- **Refuse fair fights:** resistance cells ambush supply routes and lightly-held towns; they do not march into prepared defences.
- **No dead air:** quiet fronts still have virtual patrol/reinforcement movement, so returning players find a world that moved while they were gone.
- **Never psychic:** the Director plays on the same public town state the commanders read; it gets no hidden knowledge of W/E units beyond what materialized resistance units legitimately observe.
- **Be legible:** every ledger mutation and materialization is telemetry-visible and explainable, even though nothing is visible in-game beyond ordinary resistance units.

In-theme constraint (owner, hard): **no civilian ambience.** No ALICE, no civilian-side groups, no animals, no ambient-life modules. Every entity the Director materializes comes from the existing GUER faction pools and existing V1 creation paths. "A-Life" here means the resistance behaves like a living insurgency, not that the map gets decorative life.

## Behaviour

1. Persistent town garrisons:
   - Each resistance-relevant town carries a virtual strength record that persists across activation cycles.
   - Materialization (existing proximity bubble) spawns groups proportional to current ledger strength, not the fixed V1 table.
   - Dematerialization (existing 90 s inactivity path) writes surviving strength back to the ledger instead of deleting knowledge with the groups.
   - Depleted garrisons regenerate toward the V1 baseline on a profile-controlled clock, and faster when a virtual reinforcement cell arrives from a connected resistance town.

2. Virtual movement between towns (the invisible layer):
   - Reinforcement cells: strength transfers from safe resistance towns toward threatened or depleted ones, travelling as data along road-graph routes with realistic ETAs.
   - **Relief waves (approved 2026-07-05):** a reinforcement cell whose arrival falls during an ACTIVE fight materializes at the town edge along its approach route (outside `AICOMV2_GDIR_MIN_SPAWN_M`) — a defender wave with a direction, not respawn magic. Multiple inbound cells arrive as successive waves on their own ETAs. Waves refill toward baseline; sustained beyond-baseline wave defense is the `AICOMV2_GDIR_SURGE_MAX` owner dial. Conservation still binds: every wave is strength drained from the sending towns' ledgers.
   - Patrol cells: low-strength cells drift between resistance towns; they exist only as ledger entries until a player/enemy bubble intersects their route position, then materialize through the existing patrol machinery.
   - Ambush cells: after resistance losses in a bucket, the Director may post an ambush cell on a route the attacker used; it materializes only when the bubble rule is satisfied.
   - Retake cells (owner-gated, default off): when enabled, cells may move on lightly-held enemy towns. Ownership change happens ONLY through real materialized units fighting through the existing `server_town.sqf` capture loop — the Director never writes `sideID` or `supplyValue`.

3. Lightweight brain, board-game only:
   - Assessment scores towns/routes from the ledger plus public town state (threatened, depleted, safe, opportunity).
   - Planning emits cell orders (reinforce, regroup, ambush, patrol, retake, hold) against the ledger — pure primitive data, T1-testable with no engine.
   - Execution is exactly two verbs against the world: materialize and dematerialize, both through existing V1 creation/deletion paths. There are no direct unit orders beyond what those paths already do.

4. Conservation — no free volume:
   - Total virtual strength changes only by: profile regen (toward baseline), observed attrition of materialized units, and transfers between ledger entries. No spawn-from-nothing.
   - Per-town materialized output is capped at the V1 baseline for that town (`GetTownGroups`/`GetTownGroupsDefender` × existing coefficients) times `AICOMV2_GDIR_SURGE_MAX` (default 1.0 = never above V1).

5. Group-budget stewardship:
   - The materializer is GRPBUDGET-aware: it tracks the GUER side count against the 144/side hard cap and denies materialization above `AICOMV2_GDIR_GROUP_BUDGET_MAX` with `denyReason=groupBudgetExceeded`, instead of letting `createGroup` silently fail.
   - Virtual cells cost zero groups. Under budget pressure the Director prefers dematerializing quiet buckets over refusing active ones.

6. Invisibility rules (in-theme, never seen as a system):
   - No materialization within `AICOMV2_GDIR_MIN_SPAWN_M` of any player (no pop-in).
   - No markers, no side chat, no HQ messages, no UI. The only player-visible surface is resistance units existing where the ledger says they are.
   - Cell movement rates are bounded by plausible ground speeds for the cell's composition; no teleporting strength across the map.

7. Playable GUER synergy (optional, default off):
   - With `AICOMV2_GDIR_PLAYER_SUPPORT` enabled, cell missions bias toward supporting human GUER players (reinforce the town they defend, ambush the route pressuring them). The insurgent side starts feeling like a movement, not four lone players.

## Layer Inputs And Outputs

| Layer | Inputs | Outputs | Director responsibility |
|---|---|---|---|
| Perception | Public town records (`sideID`, `supplyValue`, `wfbe_active_sideIDs`, `wfbe_attacker_sideIDs`), existing activation/deactivation events, survivor counts at dematerialization, kill events on materialized Director units, road-graph/route constants from the map profile | `AICOMV2_GDIR_LEDGER`: primitive per-town strength records and cell records | Maintain the ledger from public state and events on the Director's OWN units only. No scans of hidden W/E objects; no new `nearEntities` beyond what V1 town activation already performs. |
| Assessment | `AICOMV2_GDIR_LEDGER`, profile thresholds, GUER group-budget bucket | Town/route scores: `threatened`, `depleted`, `safe`, `opportunity`, `forbidden`; budget headroom | Score the board. Decay stale scores. Deny hidden-source claims exactly as lane 423/424 do. |
| Planning | Assessment scores, cell inventory, owner dials (retake, player-support), `AICOMV2_GDIR_SURGE_MAX` | `AICOMV2_GDIR_ORDER` rows: reinforce, regroup, ambush, patrol, retake, hold, noop, deny | Emit cell orders against the ledger only. Conservation invariant enforced here: every order balances (transfers move strength; nothing mints it). |
| Execution | Accepted `AICOMV2_GDIR_ORDER` rows, bubble events from V1 town activation, verbose-log gate, V3 telemetry contract | Materialize/dematerialize calls through existing V1 paths (`Common_CreateTownUnits`, patrol spawner, `Server_OperateTownDefensesUnits`); ledger write-backs; DIRECTOR telemetry | The only layer that touches the engine, and only through the two verbs. HC delegation of the resulting units is unchanged V1 behaviour. |

`AICOMV2_GDIR_LEDGER` record shape:

`AICOMV2_GDIR_LEDGER = ["AICOMV2_GDIR_LEDGER_V1", timeSec, profileKey, townRecords, cellRecords, metrics]`

`townRecords` entry shape:

`[townId, strength, strengthBaseline, regenRatePerMin, lastFoughtSec, materialized01, groupsMaterialized, staticsManned, suppressedUntilSec]`

`cellRecords` entry shape:

`[cellId, kind, strength, fromTownId, toTownId, routeKey, departSec, etaSec, mission, materialized01]`

`AICOMV2_GDIR_ORDER` record shape:

`AICOMV2_GDIR_ORDER = ["AICOMV2_GDIR_ORDER_V1", timeSec, profileKey, orderKind, townId, routeKey, cellId, strengthDelta, groupBudgetBucket, denyReason, whyToken]`

Field rules:

- `strength` / `strengthBaseline`: abstract strength points; `strengthBaseline` equals the V1 table output for that town (groups_max × coefficient) so parity is provable.
- `kind` / `mission`: one of `garrison`, `reinforce`, `patrol`, `ambush`, `retake`.
- `orderKind`: one of `materialize`, `dematerialize`, `moveCell`, `foundCell`, `disbandCell`, `reinforce`, `regen`, `hold`, `noop`, `deny`.
- `denyReason`: one of `none`, `groupBudgetExceeded`, `minSpawnDistance`, `conservationViolation`, `retakeDisabled`, `laneOff`, `noEvidence`.
- `suppressedUntilSec`: optional post-wipe suppression window during which a town regens but does not found offensive cells.
- Records contain only arrays, strings, numbers, and `0`/`1` booleans. No object, group, code, classname, or exact hidden position crosses a layer boundary. Same schema discipline as every other V2 lane.
- The Director never emits `AICOMV2_PLAN_DECISION`, never appears as a normalized-plan `sourceRecordKind`, and never issues advice to W/E lanes. Its public town-state side effects are simply legal evidence for lane 424 like any other resistance activity.

## V1 Evidence

Verified local anchors (current tree unless marked V2-worktree):

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/server_town_ai.sqf:11` (600 m base detection), `:85` (nearEntities scan, Air excluded), `:93-95` (`WFBE_IsTownDefenderAI` filter), `:157` (`createGroup resistance` per activation), `:208-214` (deactivation deletes all town groups — the knowledge loss this lane fixes), `:235` (patrol start), `:246,256` (0.05 s/town + 5 s cycle sleeps): the existing bubble machinery this lane reuses as its materialization surface.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:341`: `WFBE_C_TOWNS_UNITS_INACTIVE = 90` — the despawn window; V1 respawns at FULL strength after it, which is the memoryless behaviour being replaced.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_GetTownGroups.sqf:141` and `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_GetTownGroupsDefender.sqf:134-140`: the supply-value and town-type group tables × `WFBE_C_TOWNS_UNITS_COEF` / `WFBE_C_TOWNS_UNITS_DEFENDER_COEF` — these become `strengthBaseline`, not rewrite targets.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_CreateTownUnits.sqf:44` (existing `CreateTeam` call) and `:75` (0.5 s spread between groups): the only unit-creation path the Director's materializer may call for garrisons.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_SpawnTownDefense.sqf:18` and `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/Server_OperateTownDefensesUnits.sqf:24`: static town defenses are GUER-only; `:47-49` (single `WFBE_resistance_DefenseTeam` group reuse) and `:81` (0.5 s manning spread) — statics manning stays this path, ledger only decides whether a depleted town mans them.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Init/Init_Towns.sqf:8-156`: town starting-mode ownership init — untouched; the ledger seeds from whatever ownership this produces.
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/AI_Resistance.sqf`: the current 3-case patrol/defend dispatcher — the entirety of today's resistance "brain"; superseded behaviourally by this lane but not deleted (flag-off keeps it authoritative).
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_Common.sqf:286`: `WFBE_DEFENDER = resistance` — resistance as canonical defender side.
- V2-worktree `Server/Init/Init_Server.sqf:843-850`: GUER is excluded from VoteForCommander / AI_Commander / Wildcard spawns (three separate exclusions). The Director does NOT reverse these — it is not a commander instance and consumes none of the commander's HQ/base/economy machinery.
- V2-worktree `Server/AI/Commander/AI_Commander.sqf:407-416`: GRPBUDGET telemetry against the 144/side hard cap with warn at 125, including the `guer=` bucket — the budget surface the materializer must respect.
- `docs/design/v2/aicom-v2-424-third-side.md`: the volume-protection constraint (`volumeMutationForbidden`) binding lane 424; this lane is the scoped exception, see below.
- `docs/design/v2/AICOM-V2-LAYER-ARCH.md:29-48`: one mission-global rollback flag `WFBE_C_AICOM_V2_ENABLE = 0` and the internal lane-switch model this lane extends with a default-0 switch.

Keep V1 strengths:

- The proximity-bubble activation/despawn model is GOOD and stays — it is already the expensive half of a virtualization system. This lane adds the missing ledger, movement, and brain; it does not build a parallel spawner.
- Existing creation paths (`CreateTeam`, town units, patrols, statics manning), HC delegation, `WFBE_IsTownDefenderAI` marking, and the group-GC/telemetry stack remain the only engine surfaces.
- Town ownership transfer logic in `server_town.sqf` remains the sole authority on capture — for the Director's retake cells exactly as for players.
- GUER playable-faction systems (stipend, kill tiers, deny-cap, buy pools) are untouched.

## V1 Behaviour To Fix

- Garrisons resurrect at full strength 90 seconds after being wiped — player effort against the resistance is erased, and the full spawn cost is paid again every activation cycle.
- Resistance towns are islands: no reinforcement, no regrouping, no reaction to a neighbour falling.
- Resistance never punishes: no ambushes on routes attackers repeatedly use, no pressure on towns left lightly held.
- The third side generates no events for lane 424 to classify on quiet fronts — W/E commanders are being taught to react to a side that does nothing.
- Group-cap failures are silent: multi-town activations can push the GUER side toward 144 groups and `grpNull` with no managing authority.
- Fixes that add civilian ambience or decorative life, which are prohibited (owner: in theme only).

## Relationship To Lane 424 (Third-Side)

- Lane 424 stays exactly as specified: advisory-only, `volumeMutationForbidden` binding, `THIRD_VOLUME|changed=1` an immediate FAIL for lane-424 outputs.
- The GUER Director is the single authorized GUER-volume writer in the entire V2 program, and only while `AICOMV2_LANE_GUER_DIRECTOR = 1`. The acceptance harness's volume-protection scanner must therefore attribute volume changes by source: a change originating from an accepted `AICOMV2_GDIR_ORDER` with matching DIRECTOR telemetry is legal; any GUER-volume change without a Director order remains a program-wide FAIL (this actually strengthens the harness: today "no change" is the only provable state; with the Director every change must carry a signed order).
- The two lanes feed each other for free: Director-driven activity writes ordinary public town state (`wfbe_active_sideIDs` etc.), which is already lane 424's legal evidence. No new coupling, no shared records, no direct interface. W/E commanders finally have a live opponent to classify.
- With the Director lane OFF, the combined system is byte-identical to lane 424's world: V1 resistance volume, V1 respawn behaviour, harness unchanged.

## Builder Requirements

Use the shared AICOM V2 flag model from `AICOM-V2-LAYER-ARCH.md`:

- Mission-global rollback flag: `WFBE_C_AICOM_V2_ENABLE = 0` (unchanged, shared).
- V2-internal lane switch: `AICOMV2_LANE_GUER_DIRECTOR`, **default 0** — the documented exception to the lanes-default-1 rule, because this lane mutates gameplay balance. Enabling it is a per-profile owner decision.
- Do not add a separate mission-global `WFBE_C_AICOM_V2_GUER_DIRECTOR` flag.

Profile-owned V2 parameters:

- `AICOMV2_GDIR_REGEN_FULL_SEC`: seconds for a wiped garrison to regen to baseline with no reinforcement (default 1800). This is the volume-reconciliation dial: volume is delayed, never removed — long-run resistance output equals V1.
- `AICOMV2_GDIR_SURGE_MAX`: cap on materialized strength relative to V1 baseline per town (default 1.0 = never above V1).
- `AICOMV2_GDIR_GROUP_BUDGET_MAX`: GUER-side group ceiling for the materializer (default 110 of 144).
- `AICOMV2_GDIR_MIN_SPAWN_M`: minimum distance from any player for materialization (default 400).
- `AICOMV2_GDIR_AMBUSH_BUBBLE_M`: route-point bubble radius for ambush-cell materialization (default 700).
- `AICOMV2_GDIR_CELL_SPEED_MS`: virtual ground speed for cell movement (default 8).
- `AICOMV2_GDIR_SUPPRESS_SEC`: post-wipe offensive-suppression window (default 600).
- `AICOMV2_GDIR_RETAKE`: retake-cell aggression, 0 = off (default 0; owner decision D1).
- `AICOMV2_GDIR_PLAYER_SUPPORT`: bias toward supporting human GUER players, 0 = off (default 0).
- `AICOMV2_GDIR_TICK_SEC`: brain tick (default 30; the brain is a single scheduled pass over arrays — target cost well under one town-activation event).

Do not introduce:

- Civilian-side or ALICE/ambient modules, animals, new classnames, faction names, or templates not verified in the local tree. Materialization uses only existing GUER pools `['GUE','PMC','TKGUE']` through existing creation functions.
- Any write to town `sideID`, `supplyValue`, side relations (`setFriend`), side-id conversion, GUER economy constants, faction pools, or `WFBE_C_TOWNS_*` coefficients. The Director changes WHERE and WHEN existing volume appears, bounded by baseline — it does not re-tune V1 constants.
- A parallel spawner or a second proximity scan. Materialization rides the existing town-activation and patrol machinery; the Director adds at most route-point bubble checks against positions it already owns (its own cells), never scans for hidden enemy objects.
- Direct unit orders, waypoint micromanagement, or commander-style team objects. Cells are ledger entries until the moment V1 paths make them real.
- A3-only commands, public third-arg `missionNamespace setVariable`, or new group `getVariable [name, default]` patterns.

## Decision Rules

Reinforce:

- A town scores `depleted` when strength is below a profile fraction of baseline; `threatened` when public attacker state names it. Reinforcement cells prefer the nearest `safe` resistance town with surplus strength; transfers are conserving.
- Arrival during an active fight IS the relief-wave case and is allowed when the cell is not clearly outmatched; a clearly outmatched cell (attacker strength dominant per assessment) stages at the nearest safe neighbour instead of feeding the grinder (refuse fair fights).

Regroup:

- Survivors written back at dematerialization become garrison strength. Below a threshold, a rump garrison folds into a neighbouring town (cell moves out) rather than dying in place next activation.

Ambush:

- Only after real resistance losses in a bucket, on a route the ledger has seen used (its own loss events, public attacker state) — never from hidden knowledge. Ambush cells expire on a profile TTL if never triggered.

Retake (owner-gated):

- Only with `AICOMV2_GDIR_RETAKE > 0`, only against towns whose public state shows no recent defender activity, only with strength superiority, and only through real materialized combat. The suppression window blocks retakes after the cell's source town was itself wiped.

Hold / noop:

- With no evidence and no depletion, do nothing. Quiet is a valid state; the Director must not generate busywork movement that saturates the group budget or telemetry.

## Telemetry Contract

The Director introduces one new V3 family, `DIRECTOR`, with side token `GUER` — a deliberate, fixture-covered amendment to the V3 grammar (today `GUER` appears only in tail fields; the Director is the first system acting AS the resistance).

Ledger/order line (each accepted order):

`AICOMSTAT|v3|DIRECTOR|GUER|<ELMIN>|GDIR_ORDER|order=<orderKind>|town=<townId>|route=<routeKey|none>|cell=<cellId|none>|kind=<garrison|reinforce|patrol|ambush|retake>|delta=<strengthDelta>|budget=<groupBudgetBucket>|deny=<denyReason>`

Required volume-audit line whenever materialized output for a town differs from the V1 baseline:

`AICOMSTAT|v3|DIRECTOR|GUER|<ELMIN>|GDIR_VOLUME|town=<townId>|baseline=<strengthBaseline>|actual=<strength>|changed=1|order=<orderKind>|regenEta=<sec>|lane=guerDirector`

Conservation audit once per brain tick:

`AICOMSTAT|v3|DIRECTOR|GUER|<ELMIN>|GDIR_LEDGER|towns=<n>|cells=<n>|totalStrength=<n>|baselineTotal=<n>|regenDebt=<n>|budget=<groupBudgetBucket>|materialized=<n>`

Rules:

- `GDIR_VOLUME|changed=1` is legal ONLY in the `DIRECTOR` family with `lane=guerDirector` and a matching accepted order. The lane-424 rule is untouched: `THIRD_VOLUME|changed=1` without `deny=volumeMutationForbidden` remains an immediate FAIL. The harness scanner distinguishes the families.
- Every ledger mutation is attributable: scorer must reconstruct total strength over time from `GDIR_ORDER` deltas + regen and match `GDIR_LEDGER` totals (conservation proof).
- `regenDebt` = sum of (baseline − strength) across towns: the volume the world currently owes back. Long-run soak average must trend to ~0 (volume delayed, not removed).
- No pipes/objects/handles in tokens; verbose ledger dumps only behind `WF_LOG_CONTENT` and the V2 verbose gate, per house rules.

## Soak Acceptance Checks

T1 pure-core:

- Ledger conservation fixtures: any sequence of orders keeps totalStrength = initial + regen − attrition; a minting order is rejected as `conservationViolation`.
- Baseline-parity fixture: with no combat and full regen, materialization requests per town equal the V1 table output exactly (baseline reproduction).
- Surge fixture: no order sequence can push a town's materialized strength above baseline × `AICOMV2_GDIR_SURGE_MAX`.
- Budget fixtures: materialization above `AICOMV2_GDIR_GROUP_BUDGET_MAX` denies with `groupBudgetExceeded`; under pressure the planner dematerializes quiet buckets first.
- Movement fixtures: cell ETAs respect `AICOMV2_GDIR_CELL_SPEED_MS`; no instant transfers.
- Retake fixtures: with `AICOMV2_GDIR_RETAKE = 0` every retake order denies as `retakeDisabled`; with it on, retakes require superiority + no-recent-defender evidence + suppression clear.
- Sovereignty fixtures: FAIL if any Director output writes `sideID`, `supplyValue`, `setFriend`, economy constants, faction pools, or `WFBE_C_TOWNS_*` values, or emits `AICOMV2_PLAN_DECISION` / lane-424 record kinds.
- Schema fixtures: reject objects, code, classnames, hidden positions, invalid enums in `AICOMV2_GDIR_LEDGER` and `AICOMV2_GDIR_ORDER`.
- Lane-off fixture: `AICOMV2_LANE_GUER_DIRECTOR = 0` produces zero Director records, zero DIRECTOR telemetry, and leaves V1 resistance paths untouched.

T2 local micro-soak:

- With `WFBE_C_AICOM_V2_ENABLE = 0` (or the lane switch 0): town activation counts, group counts, statics manning, patrol behaviour, and RPT output are byte-equivalent to V1 baseline.
- Lane on: wipe a garrison, retreat past the 90 s despawn, return before `AICOMV2_GDIR_REGEN_FULL_SEC` — the re-activated garrison is measurably depleted, and a `GDIR_VOLUME|changed=1|lane=guerDirector` line with matching order exists.
- Reinforcement path: a depleted town adjacent to a safe resistance town receives a cell (ledger ETA telemetry) and re-activates stronger after arrival.
- Relief-wave path: a town under SUSTAINED attack receives an arriving cell materialized at the route-edge entry point, at or beyond `AICOMV2_GDIR_MIN_SPAWN_M` from every player, with a matching `GDIR_ORDER|order=materialize|kind=reinforce` line; a second inbound cell produces a second, later wave.
- No materialization occurs within `AICOMV2_GDIR_MIN_SPAWN_M` of the test client (no pop-in), verified via RPT positions.
- GUER group count never exceeds `AICOMV2_GDIR_GROUP_BUDGET_MAX` during multi-town activation; no `grpNull` in RPT.

T3 box soak:

- `regenDebt` trends to ~0 across a full soak (volume delayed, not removed) — the owner volume rule holds in the long-run average.
- GRPBUDGET `guer=` bucket stays below warn threshold in representative soaks; compare activation spawn-churn (groups created per hour) against paired V1 baseline — expect equal or lower.
- Lane 424 harness rows remain green: no `THIRD_VOLUME|changed=1` from lane 424; every GUER-volume delta is attributable to a Director order.
- Server FPS parity gate per house rules; no RPT script errors; no A3-only lint failures; Chernarus/Takistan mirrors confirmed.
- Fun-proof sample: at least one organic ambush or reinforcement event per soak hour in contested phases, zero Director activity in fully quiet phases (no busywork).

## Owner Decisions Required

- **D1 — Retake dial per map: RESOLVED (Ray 2026-07-06, decision menu).** Defaults accepted as recommended: 0 on Chernarus, low (1) on an insurgency-flavoured Takistan profile; revisit for Utes after Invasion lands.
- **D2 — Volume-rule scoping: RESOLVED (Ray 2026-07-05, implementation ruling).** The program constraint "GUER volume is intentional, do not reduce" is amended to "…except via accepted GUER Director orders while `AICOMV2_LANE_GUER_DIRECTOR = 1`, with regen guaranteeing long-run parity (`regenDebt` → 0)". Lane 424's own prohibition is unchanged; the harness attributes volume changes by source.

## Amendment A1: Player Commissar Panel (owner decisions 2026-07-06)

Status: owner-ruled via decision board 2026-07-06 (14 decisions). Packaging per owner ruling: this amendment lives INSIDE lane 800 — no companion lane. Build with the lane, post-cutover.

A GUER-team WF-menu panel: a clickable town map with coarse ledger intel plus three paid interventions (direct buy, QRF contract, counter-attack contract). It introduces player-funded strength as a second legal volume source alongside regen, with full payment provenance, and is the one intentional, scoped exception to invisibility rule 6.

### Panel rules (locked)

- The panel NEVER spawns units and NEVER writes the ledger. It submits player-request records to Planning; Planning validates and emits ordinary `AICOMV2_GDIR_ORDER` rows. The Director remains the single authorized GUER-volume writer.
- Switch: `AICOMV2_GDIR_PANEL`, default 0; requires `AICOMV2_LANE_GUER_DIRECTOR = 1`. Panel-off = zero panel records, zero panel telemetry, and every base-spec proof holds unchanged.
- Operator: any GUER player. Anti-spam: per-town action cooldown `AICOMV2_GDIR_PANEL_COOLDOWN_SEC` (default 600) and max active contracts per town `AICOMV2_GDIR_PANEL_CONTRACTS_MAX` (default 2). New `denyReason` values: `cooldownActive`, `contractLimitReached`, `paidSurgeCapReached`, `panelOff`.
- Invisibility rule 6 amendment: the no-UI rule is scoped to W/E eyes. A GUER-side-only panel UI is legal; W/E clients never receive panel data, and no W/E-visible surface changes in any way.
- Intel shown: coarse strength bands (weak/battered/strong) plus inbound-cell ETA only — never exact strength numbers. Per-click request-response between client and server; never a whole-ledger broadcast.
- Rollout: both Chernarus and Takistan at once (mirrors), with the rest of the lane.

### Conservation amendment (supersedes "no minting" in base Behaviour 4)

The invariant becomes **no UNPAID minting**. Legal strength sources are now: profile regen (toward baseline), transfers between ledger entries, and player-funded orders. Every funded order carries `fundedBy` (player UID) and `pricePaid`; any volume increase without payment provenance remains `conservationViolation`. Director-autonomous behaviour is unchanged and stays provably V1-parity: with the panel unused or off, the base conservation proof holds exactly as written.

### Action 1 — Direct buy

Pay to add strength to a chosen resistance town. Delivery mode is chosen at purchase:

- Convoy (base price): strength departs the nearest safe resistance town (or map-edge origin when none qualifies) as a normal cell with a real ETA — interceptable like any other cell.
- Instant (premium): immediate ledger add, materializing on the next bubble activation. Price multiplier `AICOMV2_GDIR_PANEL_INSTANT_MULT` (default 1.5).

Funded strength may push a town above V1 baseline up to `AICOMV2_GDIR_PAID_SURGE_MAX` (default 1.5). Director-autonomous output remains bounded by `AICOMV2_GDIR_SURGE_MAX` (default 1.0) — the paid cap applies only to funded strength, and the group budget still hard-binds at materialization.

### Action 2 — QRF contract

Pay upfront to arm a dormant contract on a resistance town (a zero-cost ledger row). It auto-fires when the town's public attacker state becomes active. Three products:

- Insert (cheap): a helicopter delivers an infantry cell at a route-edge LZ beyond `AICOMV2_GDIR_MIN_SPAWN_M`, then departs.
- Gunship (expensive): an armed helicopter on station for `AICOMV2_GDIR_QRF_CAS_SEC` (default 180), then departs.
- Combo: both, priced at the sum of the two minus a small bundle discount.

Lifetime: armed until fired, one shot, expires at end of round, no refund.

Builder verification item (blocking for this action only): identify the existing V1 GUER air spawn path in the local tree. If none exists, the air materializer is the single, explicitly-scoped new execution path this amendment authorizes — gated behind the panel switch, using ONLY helicopter classnames verified in the existing GUER pools `['GUE','PMC','TKGUE']` in the local tree; no new classnames (base do-not-introduce rules stand).

### Action 3 — Counter-attack contract

Pay to arm a contract on a resistance-held town. If the town falls, after a randomized 2-5 minute delay the nearest resistance neighbour founds a retake cell whose strength is a drain from that neighbour's ledger plus a paid top-up funded by the contract price. One attempt per contract; the cell fights through the existing `server_town.sqf` capture loop like any other retake.

Permission principle (locked, generalizes to the whole panel): `AICOMV2_GDIR_RETAKE` gates AUTONOMOUS Director initiative only. An explicit player-funded counter-attack contract fires even at `AICOMV2_GDIR_RETAKE = 0`. Dials gate autonomy, never player agency.

### Pricing and funds

Dynamic scarcity with a floor, doubling as a load-shedding valve:

- `price = basePrice x scarcity x loadFactor`, floored at `basePrice`. `scarcity` rises with recent panel use on that town and decays back to 1.0 over time.
- `loadFactor` derives from server health: it rises when server FPS is low or GUER group-budget headroom is thin, and falls toward its profile minimum when the server is healthy. The panel gets expensive exactly when the server can least afford more units (owner note, D9).
- Payment: personal wallet. Additionally a "donate to town fund" verb: any GUER player can deposit money into a per-town fund; the fund auto-applies to that town's panel actions before personal money. Funds are per-round and non-refundable.
- Dials: the `AICOMV2_GDIR_PANEL_PRICE_*` family (base price per action/product, scarcity step and decay, loadFactor bounds). Exact defaults are builder-tuned against GUER income (stipend + kill tiers) with the acceptance target that a typical round supports roughly 2-4 meaningful interventions per player.

### Record and telemetry extensions

- The ledger gains `contractRecords`: `[contractId, kind, townId, fundedBy, pricePaid, armedSinceSec, firedSec, state]` with `kind` one of `qrfInsert|qrfGunship|qrfCombo|counterAttack` and `state` one of `armed|fired|expired`.
- `AICOMV2_GDIR_ORDER` bumps to `AICOMV2_GDIR_ORDER_V2` with two appended fields: `fundedBy` (player UID string or `none`) and `pricePaid` (number; 0 for unfunded orders).
- New telemetry line per player request, accepted or denied:
  `AICOMSTAT|v3|DIRECTOR|GUER|<ELMIN>|GDIR_PANEL|verb=<buy|qrf|counter|donate>|town=<townId>|product=<none|instant|convoy|qrfInsert|qrfGunship|qrfCombo>|price=<n>|fundedBy=<uid>|deny=<denyReason>`
- The `GDIR_VOLUME` line gains `funded=<0|1>|fundedBy=<uid|none>`; a `changed=1` with `funded=1` requires a matching `GDIR_PANEL` accept line.
- The `GDIR_LEDGER` conservation audit gains `fundedTotal=<n>`; the scorer's conservation proof becomes: totalStrength = initial + regen - attrition + fundedTotal.

### Additional acceptance fixtures

T1 pure-core: unpaid mint still rejects as `conservationViolation`; funded mint accepted only with `fundedBy` and `pricePaid`; funded strength never exceeds baseline x `AICOMV2_GDIR_PAID_SURGE_MAX`; cooldown and contract-limit denies; a QRF contract fires exactly once; a counter-attack fires at `AICOMV2_GDIR_RETAKE = 0` ONLY with payment provenance; panel-off fixture (zero panel records and telemetry; base-spec proofs unchanged).

T2 local micro-soak: one purchase visible end-to-end (request, `GDIR_PANEL` accept, order, materialization); no panel data reaches a W/E client (public-variable audit); QRF helicopter path smoke on both maps.

T3 box soak: `fundedTotal` accounted in the conservation trend; `loadFactor` observably rises during low-FPS soak segments; the GUER group cap is never exceeded with maximum contracts armed.

## Report Requirements For One-shot Build

The one-shot build report must cite `GUIDE-REV GR-2026-07-03a`, name `WFBE_C_AICOM_V2_ENABLE` default `0` and `AICOMV2_LANE_GUER_DIRECTOR` default `0` as the Director lane switch (the documented default-0 exception), include ledger-conservation and baseline-parity fixtures, prove the Director never writes `sideID`/`supplyValue`/side relations and never emits `AICOMV2_PLAN_DECISION`, show `GDIR_VOLUME`/`GDIR_LEDGER`/`GDIR_ORDER` RPT examples including one attributable `changed=1`, prove lane-424 volume protection remains green, confirm no civilian/ambient content was introduced, and confirm Chernarus/Takistan mirrors. If the build includes Amendment A1 (Commissar Panel), the report must additionally name `AICOMV2_GDIR_PANEL` default `0`, include the unpaid-mint rejection and funded-provenance fixtures, show one `GDIR_PANEL` accept line with its matching `GDIR_VOLUME|changed=1|funded=1`, and prove panel-off byte-parity with the unamended lane.
