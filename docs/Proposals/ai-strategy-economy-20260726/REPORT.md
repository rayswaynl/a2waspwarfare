# AI commander strategy and economy deep dive — 2026-07-26

## Verdict

The supplied `dbg0726g` claims cannot be confirmed or refuted from the live
logs currently on the box.  The latest `MISSINIT` is a fresh **Chernarus**
run, whereas the brief identifies a 20–25 minute **Zargabad** run.  It has
only about one minute of post-boundary evidence.  This report therefore
separates observed facts from code-path analysis and does not treat a missing
log line as proof that a decision never happened.

The code does establish two important points:

1. Base construction spends **side supply**, not commander funds.  Thus WEST
   holding 221,950 funds does not demonstrate that it could build a structure;
   a low supply balance, a base-placement failure, or a scheduler gate would
   each prevent construction independently of funds.
2. `CTL_INVEST_SKIP reason=floor` is exactly consistent with 221,950 funds:
   the arm needs `cost 50,000 + floor 250,000 = 300,000` before it can spend.
   It cannot explain unbuilt base structures, because that arm spends funds
   while base construction spends supply.

No small code fix is included.  Changing the floor or the road buffer without
the intended run's trace would be tuning by anecdote and could hide the actual
gate.

## Evidence quality and live-run boundary

Read-only SSH inspection used the last `MISSINIT` boundary on the server and
all four HCs; it made no server, process, or deployment change.

| Evidence | Observation | Interpretation |
| --- | --- | --- |
| `arma2oaserver.RPT:29779` | `worldName=chernarus`; approximately 1,056 server lines follow the boundary. | Not the brief's Zargabad 20–25 minute window. |
| `:29793-29795` | Start/economy setup is logged. | A fresh bootstrap, not a mature economy sample. |
| `:30467-30468`, `:30509-30510` | Bootstrap stipend supply is explicitly suppressed (`supplyEnable=0`). | Current-run supply growth cannot be used to generalize about the intended soak. |
| `:30627`, `:30651`, `:30767`, `:30820` | WEST and EAST both show supply 128,000; funds rise together from 212,200 to 218,300. | The reported 33x imbalance is absent in this different run. |
| post-boundary server and HC scans | No `BUILD_ROAD_REJECT`, `CTL_INVEST(_SKIP)`, structure-build, or capture-event line. | Not observed in a short, mismatched window; not evidence of absence in dbg0726g. |

The four HC boundaries are HC1 `ArmA2OA.RPT:22830`, HC2 `:24315`, HC3
`:24402`, and HC4 `:25927`.  The server's current bootstrap selected east
Myshkino and west Gvozdno target/dispatch sets (`:30736-30765`,
`:30791-30819`); this is only an initial allocation, not a capture-thrash
result.

## What the commander actually does

### Base structures and placement

`Server/AI/Commander/AI_Commander_Base.sqf` is the builder.  It deploys the
HQ and then walks the doctrine order, building at most one missing structure
per invocation.  In dual-currency mode it reads side supply at line 24 and
requires supply to cover each build; the later debit is `ChangeSideSupply`,
not `ChangeAICommanderFunds` (lines 24, 41, 99 and the normal construction
path below the builder's selection block).

Placement is deliberately restrictive:

- It performs 64 tries for road-adjacent factories and 40 off-road tries
  (`AI_Commander_Base.sqf:274-289`).
- A candidate must survive water, road, friendly-structure spacing,
  world-building clearance, optional slope/tree gates, and a hard no-overlap
  floor (the finder beginning at `:274`).
- `WFBE_C_AICOM_BUILD_ROADCLEAR` defaults on with a 14 m buffer (`:206-221`),
  and the first road rejection is emitted as `BUILD_ROAD_REJECT` (`:341`
  and `:407`).
- Exhaustion does **not** silently cancel a construction: it prefers clear
  fallback tiers, then tries stepping up to 150 m off-road; only then it logs
  `BUILD_ROAD_LASTRESORT` and places (`:460-477`).

So a stream of `BUILD_ROAD_REJECT` by itself is expected search telemetry, not
proof that the builder gave up.  A root-cause trace needs the corresponding
`BUILD_ROAD_LASTRESORT`, build-start/paid event, and the side-supply value in
the same commander cycle.  The present Chernarus window has none of those.

### Spending and research

The systems are intentionally split:

| Consumer | Currency / gate | Consequence |
| --- | --- | --- |
| Base builder | side supply | Funds hoarding cannot fund structures. |
| Research | funds **and**, in dual-currency, supply plus a 500 supply reserve | A research event spends both pools. |
| Town-ledger investment | funds only | Its floor does not reserve construction supply. |

`Server/Functions/Server_AI_Com_Upgrade.sqf:30-113` scans the upgrade
program in order, skips an unaffordable head to seek the first affordable
unmet item, prevents a dual-currency purchase that would leave less than 500
supply, and emits `UPGRADE_RESEARCHED` with both prices.  Patrol research is
held until the side owns one town (`:610-616`).

The fresh Chernarus run emits equivalent WEST/EAST program orders
(`arma2oaserver.RPT:29843-29845`) and doctrine/research program setup
(`:30460-30461`, `:30503-30504`).  It is not long enough to assess the brief's
eleven events or determine whether `WF_DEBUG` was expected to seed clearance
seven; it explicitly reports `WF_Debug=false`, clearance zero at `:29795`.
That debug-seed premise belongs to the already-listed upgrade-grant-clobber
investigation and is not duplicated here.

### Town targets and side asymmetry

The strategy picker scores towns, supports town-weight modifiers (including
oilfield pull), and records stalled spearheads for blacklist/repick rather
than blindly preserving a target.  The relevant selection and stall logic is
in `Server/AI/Commander/AI_Commander_Strategy.sqf`, including the committed
team guard before it accrues a stall.  The current bootstrap selected different
opening towns and issued each side's initial assault groups; no capture event
exists after this run's boundary, so it cannot show either forward progress or
oscillation.

There is no source rule that makes WEST receive 33 times EAST's supply.  Side
income and expenditure are data-driven by towns, construction, upgrades and
other consumers.  The observed equal starting balances in the fresh run make
start position or doctrine an insufficient explanation for the intended
asymmetry.  The next valid trace must attribute every `ChangeSideSupply` delta
or at minimum sample side supply together with town ownership and the spending
events below.

## Ranked actions

### P0 — reacquire the correct dbg0726g Zargabad window before changing policy

Recover the last `MISSINIT` window that has `worldName=zargabad`, 20+ minutes
of commander cycles, and the claimed two-player conditions.  Preserve server
and HC line ranges for:

- `AICOMSTAT` tick/event rows, `BUILD_ROAD_REJECT`, `BUILD_ROAD_LASTRESORT`,
  base build/pay messages and side supply;
- every `ChangeSideSupply`-visible economic event, upgrade event and
  `CTL_INVEST(_SKIP)` row;
- capture ownership transitions and the strategy target/spearhead records.

Acceptance: a single timestamped table can explain WEST and EAST supply
change, every structure decision, research sequence, and repeated town owner
changes.  Until then, neither a supply-route bug nor town thrash is proven.

### P1 — add an atomic base-decision trace if the correct window still lacks it

If valid data shows high supply and no construction, add a rate-limited,
always-on `AICOMSTAT` base-decision record around the builder call: side,
missing next structure, supply, cost, HQ deployed state, scheduler/relocation
gate, finder result tier, and final action (`build`, `wait-supply`, `defer`, or
`last-resort`).  This is safer than lowering placement guards: it distinguishes
currency starvation from a scheduling fault and a road-dense placement search.

### P2 — do not lower the CTL investment floor merely to spend funds

At 221,950 funds the observed `reason=floor` behavior is correct for the
configured 300,000 threshold.  Consider a lower floor only after a valid
trace shows persistent surplus *after* intended commander consumers and after
owner approval of the risk: more early town-strength spending can reduce the
reserve used by other funds consumers.  It cannot repair supply-funded base
construction.

### P3 — assess targeting from ownership transitions, not target changes

Initial target changes and multiple capture events are not automatically
thrash.  Calculate per-town ownership sequences, dwell time, and whether a
side's committed offense actually improved approach before a repick.  Flag a
candidate only when it repeatedly changes owner with short dwell and no net
frontline advance; then inspect the strategy score/blacklist trace for that
town.

## Scope, dedupe, and validation

This is documentation-only.  No SQF, mirrors, live-game configuration,
process, or deployment was modified.  The report does not duplicate the
debug-upgrade-grant clobber hunt, nor propose the separately queued RPT sweep,
real-player, air-defense, player-tier, Balota, RM70, or fast-travel work.

Recommended validation for any follow-up code PR: run the required SQF lint
selector, delimiter checks, `LoadoutManager` mirror/check, per-map template
restore/verification, and reproduce the trace on a Zargabad run before tuning
defaults.

GUIDE-REV: GR-2026-07-08a
