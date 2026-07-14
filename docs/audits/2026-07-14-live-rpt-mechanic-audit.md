# Live RPT Per-Mechanic Audit — Chernarus V48 (`ccmaster0714`), 2026-07-14

> **Status:** findings report for fleet pickup. No mission code is changed by this PR (docs only).
> Every finding is RPT-observed with quoted telemetry; suggested fixes are **unverified proposals**
> for a fleet lane to own and validate. GUIDE-REV `GR-2026-07-08a`.

## Scope & method

- **Source:** one round of the live Chernarus mission, build `[55-2hc]warfarev2_073v48co_ccmaster0714`,
  read from the server RPT **windowed to the last `MISSINIT`** (24,823 lines, ~3h, to `t≈186 min`).
- **Round composition (matters for reading the findings):** an HC-only AI-vs-AI soak for ~180 of 186 min;
  one human player joined only at `t≈181`. Both headless clients healthy and evenly balanced the whole
  round (`HCDELEG liveHC=2`, per-HC group counts within 1). EAST dominant (7 towns / >1M funds, doctrine HF)
  vs WEST (5 towns / ~522k, LF). Server FPS 40–48 typical, dipping to `fps=22 / fpsmin=32` at peak load
  (`AI_TOT≈350`, `groups=103`).
- **Method:** 12 parallel per-cluster audits over the RPT, then an **adversarial verify pass** on every
  flagged anomaly, then a source cross-check on the top items. ~40 mechanics + ~45 AICOM event types covered.
- **Caution baked in:** several first-pass "anomalies" were **refuted** on verify (benign engine chatter,
  0-player soak artifacts, or a mislabeled field). Those are listed in §4 so lanes don't chase them.

## 1. Health at a glance

| Cluster | Mechanics | Healthy | Idle (by design) | Flagged |
|---|---|---|---|---|
| AI Cmd — strategy / assault | 18 | 13 | 2 | 3 (2 real, 1 refuted) |
| AI Cmd — economy / research | 12 | 9 | 1 | 2 (soak artifact) |
| AI Cmd — teams / lifecycle | 8 | 5 | 2 | 1 real + 1 informational |
| AI Cmd — base / structures | 9 | 6 | 1 | 2 (1 real, 1 refuted) |
| Wildcards + GUER CP | 7 | 7 | 0 | 1 (1 real, 1 refuted) |
| Town control / capture / defenses | 13 | 11 | 1 | 1 (designed fallback) |
| HC delegation / recon | 7 | 6 | 0 | 1 real + 1 refuted |
| Patrols / movement / anti-stuck | 9 | 6 | 2 | 1 real + 1 refuted |
| Combat / units / cleanup / air-def | 8 | 6 | 1 | **1 high** |
| Group cap / GC | 6 | 4 | 1 | 1 low |
| Performance / scaling | 9 | 4 | 1 | 4 (perf, incl. 1 real logic) |
| Stats / DB / HVT / infra | 16 | 11 | 3 | 2 real + 3 refuted |

Overall: the core AI-commander economy, team production, town capture, wildcards, HC delegation,
group-cap/GC and patrols are **functioning**. The items below are the exceptions.

## 2. Action items (ranked, claimable)

Format: **ID · severity · mechanic · file** — symptom → suspected root cause → suggested direction.

### HIGH

- **A1 · Paratrooper support is 100% broken · `Server/Support/Support_Paratroopers.sqf:37-40`**
  Every paradrop request this round errored `Paratrooping vehicle or units are not defined` (4/4, both sides).
  The script reads per-side globals `WFBE_<side>PARACHUTELEVEL<n>` (unit list) and `WFBE_<side>PARACARGO`
  (transport model); one or both is `nil` on the AI (`ai:true`) path, so it `exitWith`s before dropping.
  → **Root cause:** those per-side paradrop globals are never populated for the AI request path (init that
  defines them not running / dropped in a refactor / only set on a human upgrade unlock).
  → **Direction:** find where `WFBE_<side>PARACARGO` / `WFBE_<side>PARACHUTELEVEL*` are (should be) defined,
  ensure they exist before an AI paradrop fires. Correctness fix, unflagged.

### MEDIUM

- **A2 · Town mop-up squad silently never spawns · `Server/FSM/server_town.sqf:~630-655` + guard `Common/Functions/Common_CreateTeam.sqf:111`**
  12× `mop-up squad for <town> (<side>) failed to create - template Squad_1/Squad_2 unavailable`, once per
  capture on that path, both sides. The `Common_CreateTeam` guard (added 2026-06-14) correctly skips any
  roster token that is not a `CfgVehicles` class to avoid a `createVehicle` crash — but the mop-up path is
  handing it a **`CfgGroups` group-template key** (`Squad_1`/`Squad_2`) where member classnames are expected.
  → **Root cause:** mop-up template resolution passes a group key instead of expanding it to member unit
  classnames. → **Direction:** expand the group template to its member `CfgVehicles` classes before dispatch
  (or point the mop-up builder at the correct roster). Correctness fix.

- **A3 · EAST builds a duplicate CommandCenter · `Server/AI/Commander/AI_Commander_Base.sqf`**
  EAST built `CommandCenter` twice (`min 6` and `min 12`), each paying 1200 supply (`branchOut=false` both),
  ~120m apart — 2400 supply for a one-time structure. WEST never duplicates.
  → **Root cause:** the CC build step lacks an "already built / pending-construction" idempotency guard (the
  arty path at `:892` deliberately rebuilds destroyed pieces — the CC step should **not** re-fire).
  → **Direction:** add a built/pending guard so the CC is founded once per base. Correctness fix.

- **A4 · `HCRECON_AICOM_AUDIT` never audits a live roster**
  Fires 28× **only in the connect handshake window** (first ~1000 lines), every value zero
  (`teams=0 live=0 headingFresh/Stale/Unknown=0`), then **never again** for the rest of the round even though
  each HC ends up carrying 150–180 delegated groups. The recon-audit is effectively dead telemetry.
  → **Direction:** make it re-fire on a live cadence (or fix its trigger) so it snapshots a populated roster.

- **A5 · Anti-stuck can't free a chronically wedged team**
  One WEST team took **16** `UNSTUCK_STRIKE`s — a full tier 1→4 escalation cycle **three times** in 42 min —
  while every other team resolved in 1–2. The team then disappears from telemetry ~min 52 (freed, died, or
  dropped). Tier-4 escalation isn't a terminal resolution for a genuinely wedged squad.
  → **Direction:** confirm the tier-4 unstuck action (teleport/recycle) actually executes and terminates the
  loop; add a hard recycle after N full cycles on the same team.

- **A6 · `WASPSCALE` scaling tier never escalates**
  `tier=0` on **every** sample including the round's worst point (`fps=22`, `AI_TOT=350`, `groups=103`).
  The dynamic AI-scaling safety valve never engaged despite real FPS pressure the same line reports.
  → **Direction:** verify tier-escalation thresholds vs. observed load, or the escalation branch not firing.

- **A7 · DB `RETRIEVE` returns empty every call · `Server/Module/AntiStack/callDatabaseRetrieve.sqf`**
  188/188 `RETRIEVE` calls returned `RESPONSE (REQUEST ID) IS: []` all round (both HC UIDs and the late human).
  Could be a real backend/extension issue **or** benign "no record yet for unseen UIDs."
  → **Direction:** confirm the server-side `A2WaspDatabase` extension is enqueuing requests; determine whether
  `[]` is expected for first-seen UIDs. ⚠️ This file sits under `Server/Module/AntiStack/` — confirm it's the
  DB persistence layer, **not** the owner-gated anti-stack dedupe, before editing (see §6).

- **A8 · `GetTeamScoreMonitor.sqf` runs once, never recurs**
  The team-score monitor fires a single time at init (`t≈242s`) and never again across the active combat
  round (continuous kills the whole time). A "Monitor" that checks once looks like a missing loop.
  → **Direction:** verify whether it is meant to re-poll; restore the loop cadence if so.

### LOW / telemetry

- **A9 · `ASSAULT_STRANDED` logs a stale snapshot** — one team's `dist=1283 elapsed=484 moved=0` was
  re-logged **byte-identical 15 min apart**. The stranded logger emits a stale snapshot rather than a live
  timer/position, which can also mask real stuck detection. Telemetry-correctness fix.
- **A10 · `DOMPRESS_V2 ratio=` is a mislabeled field (NOT a bug)** — first pass flagged "ratio frozen at 1.15";
  `AI_Commander_Allocate.sqf:51` shows `ratio=` logs the **config threshold** `WFBE_C_AICOM2_PRESS_DOM_RATIO`
  (default 1.15), which is *supposed* to be constant. **No fix needed**; optional: rename the log field to
  `domThreshold=` so future readers don't misread it.
- **A11 · One unmatched wildcard `REQDRAW`** — a WEST `REQDRAW_ARM` at round 87 has no matching `SPEND` and
  the `−75000` never reconciles in funds (a second flagged instance at round 147 was **refuted** — it matched
  in the same round). Single occurrence; possible dropped consume. Repro/watch.
- **A12 · `GCSTAT untE=1` persistent** — one untagged EAST group appears at `t=178` and isn't reaped through
  the truncation at `t=186` (9 cycles). May have cleared after the window. Watch.
- **A13 · USV flotilla never roams · `Server/USV/Server_USVFlotilla.sqf`** — exits cleanly because 0
  `WFBE_USV_WP_CH_*` coastal Game-Logic waypoints are placed (needs ≥2). **Mission-authoring gap**, not code
  (owner places markers).

## 3. Performance observations (not correctness)

- **P1 · `antistack_main` / `antistack_flush` ~300–530 ms/cycle** — a sustained per-cycle cost **floor** (already
  ~300 ms at AI=38, early), by far the heaviest sustained op (next heaviest, `aicom_strategy`, ~60–130 ms).
  ⚠️ **OWNER-GATED: antistack is off-limits (§6).** Recorded as an observation only — **no change proposed.**
- **P2 · `guer_airdef_cycle` spikes to 800–1491 ms** on its active path (markers/drops present), ~2 ms idle.
  A perf **optimization** may be proposed **only if it does not reduce GUER output** (GUER nerfs are owner-forbidden, §6).
- **P3 · `cleaner_droppeditems` 6.5 s one-off boot hitch** on its first call (right after WASP-SELFTEST); every
  later call is 44–140 ms. Consider deferring/chunking the first sweep. Minor.
- **P4 · Client FPS** — the one human reported 17–19 fps while server FPS stayed 43–48. Client-local, not
  mission code; noted for completeness.

## 4. Verified & dismissed — do NOT chase

These were flagged on first pass and **refuted** on adversarial verify:

- **`AIRRESP` EAST "idle"** — geometry-gated (`inRange/sensed`), not economy-gated; WEST showed the identical
  idle shape for 179/186 ticks before one lane-proximity trigger. Working as intended.
- **`SCAFFOLD_BUILD` fires only twice** — edge-triggered on an `experital scaffold ACTIVE` state transition,
  not a per-cycle heartbeat. Correct.
- **`ARRIVAL_BANDS` med/slow ≈ 0** — async `dispatched` (at order) vs band (at completion) counters on
  different clocks + short Warfare hops; not a classification failure.
- **`Init_Towns` HANGGUARD depot skip** — INIT-level, self-documenting 30 s watchdog against editor-placed
  `LocationLogicDepot`; benign.
- **0-player soak artifacts** (all benign given ~180 min with no humans): research-upgrade stalls (WEST id 6,
  EAST id 2) driven by `StagnateSupplyIncomeNoPlayers` zeroing supply income; `server_playerstat_loop` idle
  until the late joiner; `CallDatabaseStore` score-diff 0. Not defects — expected for an empty soak.

## 5. Idle-by-design this round (no action)

`DECAP` (enemy HQs never in range), `HighClimb`/`AutoFlip` heartbeats (no stuck-climb / flipped vehicles
occurred), Naval HVT combat (carriers spawned, no engagement), ICBM TEL (SCUD evaluator correctly skipped on
Chernarus), KOTH (Zargabad-only, exits on Chernarus).

## 6. Owner-gated / off-limits (per repo constraints — do not "fix" these)

- **antistack changes** — forbidden. P1 is an observation, not a proposal. Confirm A7's file is the DB layer,
  not the dedupe, before touching it.
- **GUER caps / nerfs** — forbidden. P2 must preserve GUER output.
- USV / ICBM / naval markers are **config/mapping** owner tasks, not code lanes.

## Provenance

Generated 2026-07-14 from a live Chernarus RPT window (build `ccmaster0714`). Method: multi-agent per-mechanic
audit + adversarial verify + mission-source cross-check. **Static analysis of a runtime log** — the suggested
directions are unverified and must be validated by the owning lane (RPT-token evidence from a fresh box smoke
stays an OPEN item per each fix). No mission SQF touched by this PR; no mirror required.
