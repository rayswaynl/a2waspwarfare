# AICOM V2 — Commander Town Ledger (CTL): virtual per-town strength for WEST/EAST

Guide rev: GUIDE-REV GR-2026-07-03a. Owner approval: Ray, 2026-07-07 (option 3 of the
town-upgrades discussion). Status: DESIGN SPEC ONLY — no mission code ships with this document.
Lane sequencing: **post-V2-cutover**, same tier as Lane 800 (GUER Director) — per
`AICOM-V2-CUTOVER-AND-RECONCILIATION.md`, this lane builds only after the cutover set folds and
the unified telemetry grammar decision lands in `AICOM-V2-MIGRATION-MAP.md`, unless the owner
pulls it earlier. Sibling documents: `aicom-v2-800-guer-director.md` (the GUER Director this
design deliberately mirrors), draft PR #805 (War-Chest Requisition — the spend-arm pattern the
investment action reuses).

Rev: initial draft 2026-07-07, anchored to `origin/claude/build84-cmdcon36` @ 92fb0b58c.
All file:line anchors below verified at that commit; re-grep by constant name before building.

---

## Purpose And Doctrine Fit

Two owner goals, one mechanism:

1. **Perf-cheap defense-in-depth for owned towns.** Today a WEST/EAST captured town is defended
   by exactly one mop-up squad for its first 10 minutes (`server_town.sqf:454-543`,
   `WFBE_C_TOWNS_MOPUP_TTL = 600`) and afterwards only by the reactive occupation spawn when an
   enemy enters the 600 m bubble (`server_town_ai.sqf:13,188`). On deactivation every unit is
   deleted and nothing is remembered (`server_town_ai.sqf:462-527`) — the next activation
   respawns the full `Server_GetTownGroups` table as if the last fight never happened. The CTL
   gives each W/E-owned town a **virtual strength value** that persists between activation
   episodes: fights deplete it, time regenerates it, and the existing reactive spawn scales by
   it. Zero standing groups; the strength is invisible A-Life exactly like the GUER Director's
   ledger (`Server/AI/Server_GuerDirector.sqf:39-67`).

2. **A per-town PAID investment action.** The V2 AI commander (and later human commanders) can
   sink funds into a specific town's defense, pushing its virtual strength above baseline up to
   a paid cap — the same free-1.0 / paid-1.5 split the GUER Director already enforces
   (`AICOMV2_GDIR_SURGE_MAX = 1.0`, `AICOMV2_GDIR_PAID_SURGE_MAX = 1.5`,
   `Init_CommonConstants.sqf:1918-1919`). This is a true economy sink in the same family as
   ECON SINK (`AI_Commander.sqf:608-745`, cmdcon41/42) and War-Chest Requisition (draft PR
   #805): funds convert into battlefield consequences without permanent spawned garrisons.

Doctrine fit (V2 commandments): locality-first (the ledger only ever changes what the town's
own activation event spawns), pure testable planning core (strength arithmetic is
engine-free — T1-testable), master-flag fallback, perf self-watchdog (group-budget clamp at
materialization), defensive map reads.

What this lane is NOT:

- Not a GUER change. The CTL covers towns whose `sideID` is `WFBE_C_WEST_ID` (0) or
  `WFBE_C_EAST_ID` (1) only. The defender path (`_side == WFBE_DEFENDER`,
  `server_town_ai.sqf:113`, `Server_GetTownGroupsDefender.sqf`) and the GUER Director ledger
  are untouched. No caps, no nerfs, no interaction — GUER volume stays the point.
- Not a maneuver system. The GUER Director moves strength between towns with virtual cells;
  the CTL deliberately does not. W/E already have a maneuver arm (commander teams). CTL
  strength is town-local: it enters via regen or payment and leaves via combat attrition only.
- Not a replacement for the occupation system. The CTL is an **overlay**: `server_town_ai.sqf`
  keeps its bubble, its episode latch, its active-town budget, and its cleanup. The overlay
  multiplies one number (the group table) at spawn time and reads one ratio at cleanup time.

---

## Relationship To Existing Systems

| System | Anchor | CTL interaction |
|---|---|---|
| Reactive occupation spawn | `server_town_ai.sqf:188,280-356`; `Server_GetTownGroups.sqf:141` | Overlay: effective groups = table × strength (Behaviour 2) |
| Mop-up squad on capture | `server_town.sqf:454-543` | Untouched — runs flag-independent, as today |
| Deactivation cleanup | `server_town_ai.sqf:462-527` | Read-back hook: survivor ratio written to ledger during the existing delete iteration |
| GUER Director | `Server_GuerDirector.sqf`, lane flag `AICOMV2_LANE_GUER_DIRECTOR` | Sibling, no shared state; CTL copies its invariants (conservation, surge caps, budget deny) |
| ECON SINK spend arm | `AI_Commander.sqf:608-745`; flags `Init_CommonConstants.sqf:1003-1006` | In-tree pattern for the invest arm: `_humanSeated` raw-seat pause, floor gating, inline `_canBuild` block |
| War-Chest Requisition | draft PR #805, `WFBE_C_AICOM2_REQDRAW_*` (ENABLE 1, FLOOR 250000, COST 75000, COOLDOWN 480) | In-flight sibling sink: the invest arm reuses its floor+cost+cooldown shape and its wallet reserve value; both arms coexist (independent cooldowns, shared floor semantics) |
| Wallet primitives | `Server_GetAICommanderFunds.sqf`, `Server_ChangeAICommanderFunds.sqf` | All debits via `[_side, -_cost] Call ChangeAICommanderFunds`; balance via `(_side) Call GetAICommanderFunds` |
| groupsGC / budget telemetry | `server_groupsGC.sqf` (`wfbe_grpcnt_west/east` cache, `GRPBUDGET\|v1`, warn 120) | Budget clamp reads the cached per-side count; no new `allGroups` scans |
| Active-town budget | `WFBE_C_TOWNS_ACTIVE_MAX_BY_TIER = [12,12,10,8]` | Unchanged; bounds worst-case concurrent CTL spawn cost |

Note on REQDRAW: `WFBE_C_AICOM2_REQDRAW_*` does not exist at the base anchor — it is in-flight
on PR #805. If #805 merges first (expected), the invest arm slots directly after it in the
supervisor loop; if not, the invest arm anchors after the ECON SINK block. Either way this is
a spec-level dependency note only — this document ships no code.

---

## Data Model

One record per W/E-owned town, held in a per-side array on the side logic object (the same
object that already carries `wfbe_aicom_funds`). Runtime record, GUER-Director-shaped
(`Server_GuerDirector.sqf:39-47` is the 6-field precedent):

| Index | Field | Type | Meaning |
|---|---|---|---|
| 0 | town | object | The `LocationLogicTown` reference |
| 1 | baselineGroups | number | Snapshot of the V1 table output for this town at record creation: `Server_GetTownGroups` result × `WFBE_C_TOWNS_UNITS_COEF` (`Server_GetTownGroups.sqf:141`). Re-snapshotted if `supplyValue` changes tier. |
| 2 | strength | number | Virtual strength, 0.0 .. `AICOMV2_CTL_PAID_MAX`. 1.0 = baseline. The only mutable core field. |
| 3 | lastSpawnUnits | number | Unit count actually materialized at the current/last activation episode; 0 when dormant. Read-back denominator. |
| 4 | investT0 | number | `time` stamp of the last paid investment on this town (per-town cooldown). |
| 5 | seedT0 | number | `time` stamp of record creation (capture), for telemetry age and the capture-grace check. |

Record lifecycle:

- **Created** when a town's `sideID` flips to this side (`server_town.sqf:295` capture path)
  or at ledger init for towns already owned. Initial strength = `AICOMV2_CTL_CAPTURE_SEED`
  (0.25): a freshly conquered town starts weak and earns its garrison through regen — this IS
  the defense-in-depth curve.
- **Dropped** when the town is lost (sideID flips away). No strength transfers to the new
  owner; the enemy's own ledger (or GUER's systems) starts fresh on their side.
- **Never persisted**: pure runtime state. Server restart = re-init at seed values. No
  extension writes, no profileNamespace.

Conservation rule (GUER Director parity, `aicom-v2-800-guer-director.md` Behaviour 4):
strength may only increase via (a) timed regen up to 1.0 or (b) a funded investment carrying
`fundedBy` and `pricePaid` provenance, up to `AICOMV2_CTL_PAID_MAX`. Any other mint is a
`conservationViolation` and a T1 FAIL fixture.

---

## Behaviour

**B1 — Ledger brain tick.** One scheduled loop, both sides in one pass, every
`AICOMV2_CTL_TICK_SEC` (30 s). Pure array walk: regen, telemetry, nothing else. No
`nearEntities`, no position math, no group scans — the loop never looks at the world, only at
its own records plus variables other systems already publish. Lane gate at the top of the
brain file, GUER Director form (`Server_GuerDirector.sqf:10`):
`if (!((missionNamespace getVariable ["AICOMV2_LANE_CMD_TOWN_LEDGER", 0]) > 0)) exitWith {};`

**B2 — Strength scales the reactive spawn (materialization).** When `server_town_ai.sqf`
activates a W/E-owned town (existing 600 m bubble, existing episode latch, existing
active-town budget — none of which change), the overlay computes:

```
effectiveGroups = round (baselineGroups * (strength max AICOMV2_CTL_SPAWN_MIN_STR))
effectiveGroups = 1 max effectiveGroups                  // a held town never activates empty
```

then hands `effectiveGroups` to the existing spawn machinery in place of the raw table value.
Placement, unit selection (`WFBE_%1_GROUPS_%2` pools for the owning side), vehicles, statics —
all unchanged. At strength 1.0 the result equals the V1 table exactly (baseline-parity
fixture). Below 1.0 the town fields fewer defenders; above 1.0 (invested) more, up to the
paid cap and the group budget (B5). `lastSpawnUnits` records the unit count actually spawned.

**B3 — Survivor read-back.** On deactivation, the existing cleanup pass
(`server_town_ai.sqf:462-527`) already iterates every unit in `wfbe_town_teams` to delete it.
The overlay counts the still-alive units during that same iteration (zero extra scans) and
writes `strength = strength * (surviving / lastSpawnUnits)` (clamped 0..current). A garrison
that fought and lost half its men leaves the town at half strength; a wiped garrison leaves it
near zero. Unit-count ratio is chosen over the GUER Director's group-count ratio
(`Server_GuerDirector.sqf:119-138`) because W/E occupation groups vary widely in size; the
denominator is free either way. This asymmetry with GDIR is deliberate and noted here so
reviewers do not "fix" it.

**B4 — Regen.** Each brain tick, every record below 1.0 gains
`AICOMV2_CTL_TICK_SEC / AICOMV2_CTL_REGEN_FULL_SEC` (30/1800 = 0.0167/tick, full recovery in
30 min — identical curve to `AICOMV2_GDIR_REGEN_FULL_SEC`). Regen never crosses 1.0: invested
strength above baseline neither regenerates nor decays — it persists until combat attrition
consumes it. A dormant town regens; an ACTIVE town does not (its strength is materialized as
live units — regenerating the ledger under a live fight would mint units for free at the next
episode).

**B5 — Group-budget clamp.** Before materializing, the overlay reads the cached per-side group
count (`wfbe_grpcnt_west` / `wfbe_grpcnt_east`, published every 60 s by
`server_groupsGC.sqf:345-348`; live-scan fallback if -1). If `cached + effectiveGroups >
AICOMV2_CTL_GROUP_BUDGET_MAX` (120, aligned with `WFBE_C_GROUP_BUDGET_WARN`), the spawn is
clamped to fit and the shortfall is denied with `denyReason=groupBudgetExceeded` telemetry —
GUER Director materializer parity. Clamped strength is NOT lost from the ledger: the town
keeps its virtual value and simply under-materializes this episode.

**B6 — AI commander investment arm.** A new inline block in the supervisor's `_canBuild` zone
(after ECON SINK; after REQDRAW if #805 lands first). This is the paid action. All conditions
must pass, REQDRAW/ECON SINK grammar:

- `AICOMV2_CTL_INVEST_ENABLE > 0` (sub-flag: the ledger can run without the AI spending)
- NOT (`_humanSeated` && `AICOMV2_CTL_INVEST_HUMAN_OFF > 0`) — the cmdcon42 raw-seat pause,
  same capture point as `AI_Commander.sqf:622-635` (pre-`AICOM_LOCK`, so a locked-out but
  seated human still pauses the arm)
- funds `>= cost + AICOMV2_CTL_INVEST_FLOOR` (250000 — the identical operating reserve as
  REQDRAW: the sink never drains the TOPUP/refit budget)
- global cooldown elapsed (`AICOMV2_CTL_INVEST_COOLDOWN`, 480 s, stamped on the side logic)
- per-town cooldown elapsed (`AICOMV2_CTL_INVEST_TOWN_COOLDOWN`, 1200 s, record field 4)
- a valid target exists (below)

Effect: `strength = (strength + AICOMV2_CTL_INVEST_GAIN) min AICOMV2_CTL_PAID_MAX`
(+0.25 per purchase, cap 1.5), debit `[_side, -_cost] Call ChangeAICommanderFunds`, stamp both
cooldowns, emit telemetry with `fundedBy=aicom` provenance. Debit and strength write happen in
the same block — no arm/consume split needed here because the effect is pure ledger arithmetic
(REQDRAW splits arm/consume only because its effect lives in the wildcard worker's timing).

**B7 — Investment policy (when to invest vs requisition vs bank).** Two tiers:

- **Repair tier** (strength < 1.0): allowed whenever the floor passes. Restoring a mauled
  frontline town to baseline is the cheap, always-sensible spend. Cost =
  `AICOMV2_CTL_INVEST_COST` (50000).
- **Surge tier** (1.0 ≤ strength < 1.5): allowed only when rich — funds
  `>= AICOMV2_CTL_INVEST_SURGE_FLOOR` (600000). Pushing above baseline is a luxury the
  commander buys only while hoarding. Cost = `AICOMV2_CTL_INVEST_COST ×
  AICOMV2_CTL_INVEST_SURGE_MULT` (×2 = 100000).

Target selection, cheapest-possible heuristic over data that already exists: among owned
towns with a live record, eligible tier, and per-town cooldown clear, pick the highest
`wfbe_town_value` (the same editor-weighted priority the commander's spearhead ranking already
uses, `Init_Town.sqf:49`) breaking ties toward lowest strength. No distance math, no threat
scans — town value is the standing proxy for "worth defending". Deliberately no coordination
with REQDRAW: both arms self-gate on the same floor and their own cooldowns, matching the
existing no-central-priority-queue structure of `_canBuild` (independent inline blocks). Worst
combined drain with both arms firing at minimum cooldown stays comfortably under observed
rich-state accrual (REQDRAW analysis, PR #805 body: ~9.4k/min drain vs ~5.5k/min accrual —
CTL adds at most 100k/480s ≈ 12.5k/min, and only above the 600k surge floor; below it, at
most 6.25k/min repair spend, and only while a damaged town exists).

**B8 — Sovereignty constraints.** The CTL never writes `sideID`, `supplyValue`, side
relations, economy constants, faction pools, or any `WFBE_C_TOWNS_*` value; never touches the
defender path, the GUER Director, camps, or capture logic; never spawns units outside the
existing `server_town_ai.sqf` activation machinery; adds no PVF surface and no client code in
v1. Any violation is a review FAIL (GUER Director sovereignty-fixture parity).

**B9 — HC neutrality.** The CTL changes a group-count integer before the existing spawn call
and reads a survivor count during the existing cleanup. Locality transfer, HC unit deletion
(`cleanup-townai` broadcast), and group ownership are untouched. No new HC messages, no HC
architecture change (owner hard constraint).

---

## Human-Commander Interaction

v1 ships AI-only spend with the pause rule:

- `_humanSeated` + `AICOMV2_CTL_INVEST_HUMAN_OFF = 1` freezes the invest arm while a human
  occupies the commander seat, mirroring `WFBE_C_AICOM_ECON_SINK_HUMAN_OFF`
  (`AI_Commander.sqf:628-635`). The commander's money is the human's money while seated.
- The ledger itself (regen, materialization scaling, read-back) keeps running under a human
  commander — it is simulation, not spend, and switching it off on seat changes would create
  strength discontinuities.
- A human invest UI is explicitly out of scope for v1 and pre-approved as the natural v1.1:
  the Commissar Panel (merged PR #803: `RequestGDirPanel.sqf` PVF + `GUI_Menu_GuerCommissar.sqf`
  dialog + pending-orders swap-and-clear handshake) is the established pattern, including the
  two-click confirm rule (never reset `MenuAction` before the second click). The v1 data model
  already carries the provenance fields (`fundedBy`, `pricePaid` in telemetry) so the panel
  bolts on without a ledger change.

---

## Flags

All registered in `Common/Init/Init_CommonConstants.sqf` ONLY, appended after the current tail
(`WFBE_C_EAST_C130`, before the INITIALIZATION line), isNil-guarded, tab-indented, inline
`//---` comments — the exact cmdcon-wave format. Lane gate default 0; with the lane flag at 0
the mission is byte-identical to HEAD in behaviour (single short-circuited `exitWith` in the
brain, single lazy `&& {}` guard at each overlay read site). Numeric tunables register live
values but are inert while the lane flag is 0 (GUER Director precedent,
`Init_CommonConstants.sqf:1913-1944`).

| Constant | Default | Role |
|---|---|---|
| `AICOMV2_LANE_CMD_TOWN_LEDGER` | **0** | Lane master switch (documented default-0 exception) |
| `AICOMV2_CTL_TICK_SEC` | 30 | Brain tick (GDIR parity) |
| `AICOMV2_CTL_REGEN_FULL_SEC` | 1800 | Zero-to-baseline regen duration (GDIR parity) |
| `AICOMV2_CTL_CAPTURE_SEED` | 0.25 | Strength at record creation (fresh capture) |
| `AICOMV2_CTL_SPAWN_MIN_STR` | 0.25 | Materialization floor — a held town never activates empty |
| `AICOMV2_CTL_PAID_MAX` | 1.5 | Funded strength cap (GDIR `PAID_SURGE_MAX` parity) |
| `AICOMV2_CTL_GROUP_BUDGET_MAX` | 120 | Per-side group ceiling at materialization (aligned with `WFBE_C_GROUP_BUDGET_WARN`) |
| `AICOMV2_CTL_INVEST_ENABLE` | **0** | AI invest arm sub-flag |
| `AICOMV2_CTL_INVEST_GAIN` | 0.25 | Strength per purchase |
| `AICOMV2_CTL_INVEST_COST` | 50000 | Repair-tier price |
| `AICOMV2_CTL_INVEST_SURGE_MULT` | 2 | Surge-tier price multiplier |
| `AICOMV2_CTL_INVEST_FLOOR` | 250000 | Operating reserve (REQDRAW parity) |
| `AICOMV2_CTL_INVEST_SURGE_FLOOR` | 600000 | Rich threshold for above-baseline buys |
| `AICOMV2_CTL_INVEST_COOLDOWN` | 480 | Global seconds between buys per side (REQDRAW parity) |
| `AICOMV2_CTL_INVEST_TOWN_COOLDOWN` | 1200 | Per-town seconds between buys |
| `AICOMV2_CTL_INVEST_HUMAN_OFF` | 1 | Pause AI spend while a human is seated (cmdcon42 parity; inert while lane = 0) |

No existing default changes. No `Rsc/Parameters.hpp` lobby param in v1 (add one only at the
flip-live PR, REQDRAW-style, keeping `default=` in sync with the constant — Parameters.hpp
defaults override script constants).

---

## Telemetry Contract

Grammar note (binding): this lane builds post-cutover, so its emitters land on whichever
unified grammar the migration map selects (`AICOM2|` vs `AICOMSTAT|v3`). The lines below are
written in the in-tree `AICOMSTAT|v2|EVENT` commander-event grammar (`AI_Commander.sqf:632,
647,742,819`) as the naming contract; the builder transposes prefix/version mechanically at
build time and records the transposition in the migration map.

Spend events (invest arm):

```
AICOMSTAT|v2|EVENT|<side>|<min>|CTL_INVEST|town=<name>|tier=<repair|surge>|cost=<n>|str=<new>|funds=<after>|fundedBy=aicom
AICOMSTAT|v2|EVENT|<side>|<min>|CTL_INVEST_SKIP|reason=<floor|cooldown|townCooldown|noTarget|human>|funds=<n>
```

(`CTL_INVEST_SKIP` emits at most once per stat interval, not per tick — no log spam.)

Ledger events (brain + overlay):

```
CTLSTAT|v1|<side>|towns=<n>|totalStr=<x>|totalBase=<x>|invested=<x>|denied=<n>
CTLSTAT|v1|<side>|SPAWN|town=<name>|str=<x>|groups=<eff>/<table>|deny=<none|groupBudgetExceeded>
CTLSTAT|v1|<side>|READBACK|town=<name>|ratio=<x>|str=<new>
CTLSTAT|v1|<side>|SEED|town=<name>|str=<seed>
```

`CTLSTAT|` is a new town-diagnostics family in the mold of `TOWNSTAT|`/`GRPBUDGET|`
(`server_groupsGC.sqf`) — those families are explicitly outside the cutover removal scope
(cutover brief, "Telemetry consumers"), and CTLSTAT declares itself into the same
survives-cutover class since it diagnoses the town system, not the V1 commander. The audit
line emits every 300 s; SPAWN/READBACK/SEED emit per event (bounded by activation frequency).
One always-on `INFORMATION` line via `WFBE_CO_FNC_AICOMLog` on invest and on lane start;
verbose per-tick dumps gated behind `WF_LOG_CONTENT`.

Consumers to update at build time: `Tools/PrTestHarness/Ops/aicom-watch.ps1` (add CTL_INVEST),
`Tools/PrTestHarness/Rpt` pattern lists (whitelist `CTLSTAT|`), soak scorer only if CTL KPIs
join the gate.

---

## Performance Budget

The design is net-negative-to-neutral on load versus HEAD in every state except a deliberately
invested town:

- **Dormant cost**: one array pass over owned-town records per 30 s tick, arithmetic only. No
  world queries ever — strictly cheaper than one town-activation event (GDIR budget language),
  and cheaper than the GDIR brain itself (no cell movement phase, no assessment scans).
- **Materialization delta**: below baseline the town spawns FEWER groups than V1 — the common
  post-fight state is a perf improvement. At baseline, identical to V1. Invested worst case:
  Medium occupation table is 3–10 groups (`Server_GetTownGroups` 2–7 × coef 1.5); ×1.5 paid
  cap = 5–15 groups for ONE town's episode, +50% over V1 for that town only.
- **Concurrency bound**: the untouched active-town budget (`WFBE_C_TOWNS_ACTIVE_MAX_BY_TIER =
  [12,12,10,8]`) caps simultaneous episodes; W/E occupation episodes are enemy-triggered and
  historically far fewer than the cap. The surge case cannot stack map-wide: per-town cooldown
  1200 s + global cooldown 480 s + funds floor mean a rich commander can hold at most a handful
  of towns above baseline at once (0.25 gain/purchase: reaching 1.5 on ONE town from baseline
  costs 2 purchases and 16+ minutes of cooldowns).
- **Hard stop**: B5 clamps any materialization that would push the side's cached group count
  past 120, well under the 144 engine cap and at the existing GRPBUDGET WARN line — the CTL
  can never be the thing that saturates the group table. Deny telemetry makes any clamp
  observable in soak.
- **No new scans**: activation detection, bubbles, and scan-dice behaviour are untouched;
  the CTL adds zero `nearEntities`/`allGroups` calls on any hot path (budget reads use the
  groupsGC 60 s cache).

---

## Migration And Rollback

- **Flag-off inertness**: lane flag 0 short-circuits the brain at line 1 and every overlay
  read site via lazy `&& {}` guards; behaviour is byte-identical to HEAD. Correctness proof at
  build time per repo checklist (flag-off diff + lint gate + bracket delta).
- **Rollback**: set `AICOMV2_LANE_CMD_TOWN_LEDGER = 0` (or the lobby param at flip-live).
  Ledger records are orphaned runtime state on the side logic — harmless, gone at restart. No
  persistence, no schema, no migration.
- **Cutover dependency**: the invest arm anchors in the supervisor loop that survives cutover
  reconciliation. If it builds against the V1 `AI_Commander.sqf` supervisor during the
  transition window, the migration map must list `CTL_INVEST` as an emitter+arm that relocates
  to the V2 planner home before V1 removal (same rule as GRPBUDGET relocation). Building after
  the cutover set folds avoids the double move — hence the lane sequencing.
- **Interaction ordering with #805**: if REQDRAW is live, both sinks share the 250k floor by
  value; neither can starve the other below the reserve. No code coupling.

---

## Test Plan (T1 / T2 / T3)

T1 pure-core (engine-free fixtures, GDIR harness style):

- Conservation: any order sequence keeps totalStrength = seeds + regen − attrition +
  fundedTotal; an unfunded above-1.0 write rejects as `conservationViolation`; a funded write
  requires `fundedBy` + `pricePaid` and never exceeds `AICOMV2_CTL_PAID_MAX`.
- Baseline parity: strength 1.0 → effectiveGroups equals the V1 table output exactly, for
  every table tier (2–7 raw × coef).
- Regen: zero-to-baseline in exactly `REGEN_FULL_SEC / TICK_SEC` ticks; no regen above 1.0;
  no regen while the town is active.
- Read-back: ratio math clamps 0..1; wiped garrison → ~0; untouched garrison → unchanged
  strength; `lastSpawnUnits = 0` (never spawned) is a no-op, not a divide-by-zero.
- Invest policy: floor, global cooldown, per-town cooldown, surge floor, human pause each
  individually deny with the right skip reason; target selection picks highest
  `wfbe_town_value` then lowest strength; no eligible target → clean no-op.
- Budget: planned groups above `GROUP_BUDGET_MAX` clamp and emit `groupBudgetExceeded`;
  ledger strength unchanged by a clamp.
- Sovereignty: FAIL if any output writes `sideID`, `supplyValue`, `WFBE_C_TOWNS_*`, GUER
  Director records, or defender-path state.
- Flag-off: zero records, zero CTL/CTLSTAT lines, base behaviour proofs unchanged.

T2 local micro-soak (editor/local dedi, PR-test-harness scripts):

- Capture a town as WEST with the lane on: SEED line at 0.25; attack it with OPFOR within 30
  min: activation spawns ~25% of table (min-str floor respected); RPT shows SPAWN with
  `groups=<eff>/<table>`.
- Fight-deplete-regen cycle: wipe half the garrison, leave the bubble, verify READBACK ratio
  ≈ survivors/spawned, then verify regen ticks restore toward 1.0 while dormant.
- Invest end-to-end: force-rich the AI wallet, verify CTL_INVEST debits via
  `ChangeAICommanderFunds` (funds delta in ECONFLOW), strength rises, next activation spawns
  the larger garrison; verify the `_humanSeated` pause by taking the seat.
- Flag-off smoke on both maps: RPT byte-parity for town activation lines vs HEAD.

T3 box soak (Hetzner ladder, deploy only on Steff's go per standing consent policy):

- KPI gates: capture-rate parity with baseline nights (the ledger must not flip round
  outcomes at defaults), FPS parity, zero filtered RPT script errors, CTLSTAT conservation
  trend closed (totalStr accounted every audit line).
- `GRPBUDGET|` west/east never crosses WARN attributable to CTL (correlate SPAWN deny lines).
- Funds: with invest on, AICOM funds trend shows the sink engaging above the surge floor and
  never breaching the 250k reserve (REQDRAW-style wallet plateau check).
- A/B: one night lane-on at defaults vs one lane-off night; town-fight duration and defender
  counts at re-attacked towns are the observed deltas (defense-in-depth working = re-attacks
  inside 30 min meet weaker garrisons; invested towns meet stronger ones).

---

## Owner Decisions Required

1. **Below-baseline scaling from day one?** B2 as specced makes recently-fought towns
   genuinely weaker than V1 until regen completes (that is the depth mechanic, and the
   perf win). If that reads as a defense nerf in play, the fallback is a one-line clamp
   (`strength max 1.0` at spawn: surplus-only mode — never below V1, keeps only the paid
   upside). Recommend shipping full scaling; the T3 A/B night decides.
2. **Prices and gains** (50k/+0.25 repair, ×2 surge, 600k surge floor) are first-cut numbers
   scaled against REQDRAW's validated drain math — tune at flip-live like REQDRAW's
   owner-approved defaults.
3. **Capture seed 0.25 vs mop-up overlap**: seed 0.25 + the untouched mop-up squad means a
   fresh capture has the squad AND a quarter-strength reactive pool. Alternative: seed 0.5
   and let the mop-up TTL shorten. Recommend 0.25 + unchanged mop-up (no interaction risk).
4. **Human commander invest UI (v1.1)**: green-light now for planning, or wait for v1 soak?
   Panel pattern is proven (PR #803); ledger needs no changes either way.
5. **Lobby params at flip-live**: which of lane flag / invest flag / prices get
   `Rsc/Parameters.hpp` exposure (REQDRAW exposed exactly one toggle).

---

## Report Requirements For The Build

The build report must cite `GUIDE-REV GR-2026-07-03a`, name `AICOMV2_LANE_CMD_TOWN_LEDGER`
default 0 (and `AICOMV2_CTL_INVEST_ENABLE` default 0) as the lane switches, include the
conservation and baseline-parity T1 fixtures, prove the CTL never writes
`sideID`/`supplyValue`/`WFBE_C_TOWNS_*`/GUER state, show RPT examples of one full
SEED → SPAWN → READBACK → regen cycle and one CTL_INVEST with its funds debit, prove flag-off
byte-parity, confirm the telemetry grammar transposition is recorded in the migration map, and
confirm Chernarus/Takistan/Zargabad mirrors with restored version templates.
