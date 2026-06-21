# WASP Improvement Plan (all facets) — LIVE BUILD: B61

_Seed v1: 2026-06-20 overnight multi-facet adversarial debate (15 agents, deeply code-verified). LIVING doc: refined every ~2h overnight. **RECONCILED TO B61 2026-06-21 (cycle 4)** — the live server has moved past B59/B60 to B61. PROPOSE-ONLY — nothing here is deployed by me; B61 was deployed by Ray._

**Changelog**
- _2026-06-21 (cycle 4 — RECONCILE TO B61 + economy & spectacle deep-dive): live is now **B61** (`missionName=...b61`), NOT B59/B60. Fresh live pull: **FPS 47–48** (healthy, up from B59's 42), ~260 units / 3 players, **HCs absorbing 86%** of AI (DELEGSTAT 213/248 remote), **0 script errors**. **Front is MOVING, not frozen** — EAST=PRESS (myStr=99 enStr=79, holds Vybor, took NWAF, 25 fwd teams), WEST=DEFEND/BOOTSTRAP (0 towns, biasing to Solnichniy). TOWNSTAT west=0 east=1 guer=42 (early land-grab off neutral towns). **The B59 "frozen 7v7 partition" headline NO LONGER HOLDS for B61.** **unitsPerTeam=8 at warmup** (vs B59's chronic 5.5–7.7 below-floor bleed) — B61's refill-at-base appears to be MITIGATING the bleed. Only ONE `distStart=0` spawn-wedge (self-corrected via reissue); **zero ASSAULT_STRANDED**. **TWO deep debates this cycle (most-implicated + most-overdue): (3) economy/supply-tempo and (5) spectacle.** **Economy verdict: CHANGE NOTHING + measure** — the "both sides on FUNDS-FALLBACK" signal is a MISREAD; FUNDS-FALLBACK is Ray's deliberate funds→tech converter (`Server_AI_Com_Upgrade.sqf:90-95`, rate=1, set 2026-06-17), the bootstrap floor (120 sup + 100 funds/min for 2h, town-independent) already prevents a 0-town death spiral, town-scaling already exists (×0.35), and founding is paid in FUNDS not supply. Only adopt a new SUPPLYSTAT diagnostic. **Spectacle verdict: the Discord bot already runs + posts every 60s but ignores the RPT firehose** — build the off-server Front-Status embed FIRST (zero server risk, reuses already-emitted AICOMSTAT|FRONT), then the LLM recap, then a war-map timelapse; REJECT all in-mission cams/markers. **NEW TOP RISK: B61 ships the MHQ-reloc default-ON — the forbidden FORWARD-teleport — it simply hasn't FIRED yet because the front is still <2500 m from HQ (land-grab phase). When the front pushes out it WILL trigger and can drive the respawn anchor onto a hot tile.** This is now the #1 watch item._
- _2026-06-21 (cycle 3 — was the final B59 pull): sharpened the strand root cause to a terrain-blind SPAWN wedge (`distStart=0` = leader hasn't moved since order issue, `Common_RunCommanderTeam.sqf:517-519` self-documents "distStart=0 at base"). Reaffirmed asymmetry is downstream of stranding-geometry (stronger side SWAPS between soaks), not economy. NOTE: this reasoned against B59; B61 evidence (front moving, bleed mitigated, zero stranding so far) supersedes much of it — re-validate the strand items against B61 before committing._
- _2026-06-21 (06:00 CONSOLIDATION, B59): measured the retreat-and-reform death loop at 6,397 orders, 100% alive=1, all 5.8–9.7 km out. B59-specific; B61's refill-at-base may have closed this — confirm._
- _2026-06-21 (cycle 2): economy symmetric BY CONSTRUCTION; B60 MHQ build diverges from spec → HOLD/re-build._
- _2026-06-21 (cycle 1): surfaced alive=1 retreat-and-reform churn; added #1 (disband alive≤1), strand teleport._

---

## Headline

**State of B61 — healthy, moving, and one armed landmine.** The live B61 round is mechanically the strongest build yet: **FPS 47–48** (up from B59's 42), **0 script errors**, HCs absorbing **86%** of ~260 units, founding firing every ~1–2 min at **unitsPerTeam=8** — i.e. the chronic B59 below-floor bleed (5.5–7.7) appears **mitigated by B61's refill-at-base**. The front is **MOVING, not frozen**: EAST is pressing (str 99 vs 79, holds Vybor + took NWAF), WEST is bootstrapping a first town. Only **one** spawn-wedge event (self-corrected) and **zero ASSAULT_STRANDED** this session. The two B59 headline pathologies — the death-loop bleed and the frozen partition — are **not visible in B61 so far** (caveat: it's early, land-grab phase; re-confirm over a full round).

**The one armed landmine: B61 ships the MHQ-relocation default-ON, and it is the version that can teleport the respawn anchor FORWARD onto the hottest tile.** It has not fired yet only because the spearhead town is still <`WFBE_C_AICOM_MHQ_FRONT_DIST` (2500 m) from HQ in this land-grab phase (live RPT: **0 MHQRELOC lines**). The moment EAST's front pushes past that distance — which PRESS posture is actively driving toward — the deadline fallback `_mhq setPos _destPos` can drive the anchor ~1700 m forward, gated only on no-player-900 m, with a stale enemy re-check. **This is the single item in the whole plan that can lose a round outright, and it is now live and default-ON.** Either disable the reloc (set `WFBE_C_AICOM_MHQ_ENABLE=false`) until re-built to spec, or accept the risk knowingly — but it must be a conscious decision before the front travels.

**This cycle's two debates both converged on "don't touch the live mechanic; instrument or build off-server instead":**
- **Economy (most-implicated by fresh data):** the "both sides supply-starved on FUNDS-FALLBACK" reading is **wrong**. FUNDS-FALLBACK is a deliberate, 4-day-old funds→tech converter doing its job (every fallback line = a tech tier that DID unlock). The bootstrap stipend already prevents a 0-town death spiral. Town-scaling already exists. Founding spends FUNDS, not supply. **Change nothing; add one SUPPLYSTAT telemetry line to measure tempo before any future tuning.**
- **Spectacle (most-overdue facet):** there is a **Discord bot already running and posting every 60s** that reads only a 4-field `database.json` and ignores the rich RPT telemetry it could consume. The highest reach-per-effort move is to connect the firehose we already emit to the bot we already run — a **live Front-Status embed**, zero server risk, reaching the whole Discord instead of the ~3 humans in-game.

---

## Top actions (all facets, ranked) — cycle-4

| # | What | Why (B61 evidence) | Impact / Effort | Verdict | Facet | A2-OA-safe pointer |
|---|------|--------------------|-----------------|---------|-------|--------------------|
| 1 | **Decide the MHQ-reloc-live risk BEFORE the front travels** — either set `WFBE_C_AICOM_MHQ_ENABLE=false` until re-built to the guarded spec, OR knowingly accept the forward-teleport. It is default-ON in B61 and has not fired only because the front is still <2500 m from HQ | **The one round-losing item, now LIVE.** PRESS posture is actively pushing the front toward the 2500 m trigger; the deadline `_mhq setPos _destPos` drives the anchor forward, gated only on no-player-900 m + a stale enemy scan | **highest** / low (a constant flip) | **adopt (decide now)** | aicom-strategy / B60 | flag/const flip only; the safe interim is `ENABLE=false`. Full re-build spec in the B60 section below |
| 2 | **CONFIRM the B59 bleed is actually fixed in B61** — re-validate over a full B61 round that unitsPerTeam holds ≥8 and retreat-and-reform / ASSAULT_STRANDED stay near-zero, before spending effort on #6/#7/#8 (the B59 reclaim/top-up/strand fixes) | B61 warmup shows unitsPerTeam=8, 1 self-corrected wedge, 0 stranding — the B59 death-loop & spawn-wedge may already be closed by refill-at-base. **Don't fix what B61 fixed.** This gates whether the entire aicom-units block is still needed | high / low (read-only soak watch) | **adopt** | bugs-telemetry | observation-only; the #6/#7/#8 items below stay PARKED pending this confirmation |
| 3 | **SUPPLYSTAT diagnostic line** — emit one periodic per-side aggregate `SUPPLYSTAT|v1|<side>|<min>|reserve=..|income=..|fallbackCount=..|towns=..`, gated to the income tick (~60s), reusing the existing `AICOMSTAT`/`TOWNSTAT` `diag_log` idiom | The economy debate's honest path: the "supply-starved" worry is a misread, but there is **no periodic per-side aggregate** to PROVE tempo is healthy. One cheap line turns the next economy debate from anecdote into data | high / low | **adopt (trial)** | economy / bugs-telemetry | `diag_log`+`str`+`+` only (no banned cmds); counter via `setVariable` at the fallback site `Server_AI_Com_Upgrade.sqf:134`; emit at income interval, NEVER per-unit/per-frame |
| 4 | **Live "Front-Status" Discord embed (spectacle keystone) — BUILD FIRST** — off-box RPT-tailer writes `front.json` next to the existing `database.json`; add a second embed to the bot's existing 60s loop showing town score, contested town, who's pushing where, last flip | **Highest reach-per-effort, zero server risk.** Reuses the already-running Discord bot + already-emitted `AICOMSTAT|FRONT` + `WASPSTAT|CAPTURE`. Turns an invisible AI-vs-AI war into a public scoreboard for the whole Discord, not 3 in-game humans. **No new in-mission emission needed** | high / low-med | **adopt** | spectacle | 100% off-server; lowest-touch = sidecar JSON the bot already `LoadFromFile`s. Show a "last updated" age to catch a stalled tail |
| 5 | **Off-server end-of-round LLM battle recap — BUILD SECOND** — on `ROUNDEND`, pre-aggregate the round's CAPTURE/FRONT/STALL/HQ_STRIKE/KILL/PLAYERSTATS into a compact structured summary → Claude → Discord. Fold hero/blooper beats in as a section | Shareable artifact, off-box, zero risk; shares the RPT-ingest plumbing stood up for #4. Feed the model a pre-aggregated summary (towns flipped, net front delta, biggest fight, top human), NOT raw RPT — anti-hallucination | high / med | **adopt** | spectacle | off-server; latch one recap per round/MISSINIT; Ray=834428635896610886. Optional later: one gated `WASPSTAT|ROUNDSTART` line to make round-slicing unambiguous |
| 6 | **[PARKED, B59-era] Reclaim alive≤1 teams far from HQ instead of perpetual retreat** — flag-then-HC-delete so a full-size team re-founds | Was the B59 #1 (6,397 alive=1 retreat orders). **Gated behind #2** — if B61's refill-at-base already sustains unitsPerTeam, this may be unnecessary; do not build until #2 confirms the bleed persists in B61 | high / low | **hold (re-validate)** | aicom-units | flag-then-HC-delete (server `deleteVehicle` can't reach HC-local units); re-found cooldown to avoid thrash |
| 7 | **[PARKED, B59-era] STUCKSTAT spawn-wedge diagnostics + 3-part strand fix** (#2a/#2 from B59) | B61 shows only 1 self-corrected wedge, 0 stranding. **Gated behind #2.** Keep the diagnostics ready; defer the spawn-relocation fix unless B61 re-exhibits the wedge over a full round | high / low (diag) | **hold (re-validate)** | aicom-units / bugs | read-only `diag_log` additions are still safe to land anytime; the spawn road-snap (#2-A) carries conga-line risk — gate it |
| 8 | **[PARKED, B59-era] Re-pick spearhead on stall + maneuver-vs-garrison gate + non-reset strand counter** (B59 #3/#4/#5) | The B59 frozen-partition fixes. **B61's front is moving**, so these are no longer urgent — keep as insurance if B61 re-freezes over a full round | high / med | **hold (re-validate)** | aicom-strategy | selection-only; reuse blacklist idiom `AssignTowns.sqf:208-219` |
| 9 | **Fix the phantom capture counter** — drop the `CAPTURED` match (`wasp-b57-soak.ps1:51`), count real `CAPTURE` events, relabel "flips" | Confirmed false metric (raw grep 352 vs ~12 real events). Harness-only, build-independent — still valid for B61 | high / low | **adopt** | bugs-telemetry | harness-only; repoint $cap consumers in one pass |
| 10 | **War-map timelapse (spectacle, BUILD THIRD/opportunistic)** — replay CAPTURE lines into PNG frames → GIF/MP4 off-box, reusing the bot's CHERNARUS map data | Shareable, off-box, zero risk; shares #4/#5's CAPTURE parser. Needs a town-name→coordinate table + ffmpeg step | med / med-high | **trial** | spectacle | off-server; build after #4/#5 prove the ingest pipeline |

**Below the top 10 (valid, lower priority):** antistack_main/flush ms in the soak harness (performance, adopt — instrumentation only); infPerTeam/vehPerTeam split diagnostic (bugs, adopt); TEAM_FOUNDED `class=` mislabel fix (bugs, adopt); engine-flood ("Message not sent") tripwire in the harness (bugs, adopt); HC-team live top-up (aicom-units, trial — only if #2 shows the bleed persists).

---

## By facet

### economy & balance _(most-implicated by fresh data this cycle — verdict: change nothing, measure)_
- **The "both sides supply-starved" reading is a MISREAD — debated code-deep this cycle.** FUNDS-FALLBACK is **not** a famine alarm; it is Ray's deliberate funds→tech converter (`Server_AI_Com_Upgrade.sqf:90-95`, `WFBE_C_AICOM_UPGRADE_FUNDS_RATE=1`, set 2026-06-17). It fires only when a side wants a vehicle-tier upgrade, has dry supply, and pays the supply price as a funds surcharge. **Every fallback line in the RPT = a tech tier that DID unlock**, not a denied purchase. The feature working IS the telemetry.
- **No 0-town death spiral exists.** The bootstrap stipend (`AI_Commander.sqf:207-247`, constants `Init_CommonConstants.sqf:248-250`) gives a 0-town side **120 supply/min + 100 funds/min for up to 2 h, town-count-independent**, plus a BOOTSTRAP_BIAS picker aiming it at the nearest cheap town. WEST at 0 towns is on the floor BY DESIGN (land-grab phase), not spiralling — which is why it still affords its id6→L1 upgrade via fallback.
- **Town-scaling already exists** (`updateresources.sqf:76` income = `round(townSupplyValue × 0.35)`; `Common_GetTownsSupply.sqf` sums owned towns). Adding MORE town-scaling would double-count and STEEPEN the rich-get-richer snowball — the opposite of anti-snowball. **Reject.**
- **Founding spends FUNDS, not supply** (no `ChangeSideSupply` on any founding path; spend lives in `ChangeAICommanderFunds`/`ChangeTeamFunds`). So "cap founding to match supply rate" is a category error — and capping founding risks idle/deferred AI (antistack hazard). **Reject.**
- **Raising `SUPPLY_INCOME_MULT` (0.35→higher): REJECT.** It reverts a 1-cycle-old intentional throttle ("so the AI earns progression from towns+convoys instead of drowning in supply", `Init_CommonConstants.sqf:416`), funds more base structures (not units), and BLINDS the fallback diagnostic. Low effort, negative impact.
- **Adopt: #3 SUPPLYSTAT diagnostic only.** Measure tempo for a cycle, then revisit with data instead of anecdote. The honest bottom line: **change nothing in the economy yet.**
- **DO-NOT-TOUCH-BALANCE stands** (re-verified across prior cycles: flat 200000 both sides, symmetric coefficients, stronger side swaps between soaks).

### player spectacle & AI cinematics _(most-overdue facet — verdict: consume the firehose off-server)_
- **Key infra fact (verified): a Discord bot already runs and posts a status embed every 60s** (`DiscordBot/GameStatusUpdater.cs`) — but it reads only a 4-field `database.json` (scores/world/uptime/playercount) and **ignores the rich RPT telemetry** (WASPSTAT KILL/CAPTURE/ROUNDEND; AICOMSTAT FRONT/POSTURE/STALL/HQ_STRIKE/MHQRELOC/TEAM_FOUNDED — all timestamped + side-tagged). The WASPSTAT doc itself flags "DiscordBot tails the RPT" as aspirational.
- **Build order (all OFF-SERVER, zero live-risk, all buildable from telemetry ALREADY emitted):**
  1. **#4 Front-Status embed (FIRST)** — the keystone. Reuses the running bot + `AICOMSTAT|FRONT` + `CAPTURE`. Lowest-touch path: an off-box tailer writes `front.json`; the bot adds a second embed in its existing loop. Converts an invisible war into a public scoreboard. **Highest reach-per-effort in the whole plan.**
  2. **#5 End-of-round LLM recap (SECOND)** — triggered by `ROUNDEND`, pre-aggregate then narrate. Fold hero/blooper (KILL lines) in as a section.
  3. **#10 War-map timelapse (THIRD/trial)** — replay CAPTURE lines off-box.
- **REJECT all in-mission spectacle:** front-line map markers (strictly dominated by #4 — same data, more reach, zero risk); auto director-cam (highest risk: spectator SQF + distance/sim reasoning to find the hot fight collides with no-sim-gating + never-idle-AI + antistack constraints, ~0 reach for 3 humans — a human capturing a stream can free-cam manually); stalemate-breaker scripted event (that's a war-balance mechanic, and the breakers already exist — STALL/SPEARHEAD_REPICK/WEDGE_RELEASE; it's good *input* to the recap, not a spectacle build).

### aicom-strategy & front-stall _(B61: front is MOVING — B59 freeze fixes demoted to insurance)_
- **B61 reality:** EAST=PRESS, WEST=DEFEND/BOOTSTRAP, front advancing off neutral towns — the B59 `contested=0` 7v7 partition is NOT present. The B59 strategy fixes (#8: spearhead re-pick, maneuver-vs-garrison gate, non-reset strand counter) are **demoted to insurance** — keep ready, build only if B61 re-freezes over a full round.
- **The one urgent strategy item is #1: the MHQ-reloc-live risk** (see B60 section). PRESS posture is the thing driving the front toward the reloc trigger.
- POSTURE remains largely dead telemetry (many writers, ~1 reader) — do NOT bolt behaviour onto it.

### aicom-units & the bleed/wedge _(B61: appears mitigated — re-validate before building)_
- **B61 warmup unitsPerTeam=8** (vs B59's chronic 5.5–7.7), **1 self-corrected spawn-wedge, 0 ASSAULT_STRANDED.** B61's refill-at-base looks to have closed the B59 death-loop and spawn-wedge. **#2 (confirm over a full round) gates the entire block.**
- The B59 reclaim (#6), STUCKSTAT diag + 3-part strand fix (#7) stay PARKED pending #2. The read-only STUCKSTAT diagnostics are safe to land anytime if you want the signature captured cheaply; the spawn road-snap (#2-A) keeps its conga-line risk and stays gated.
- Every parked item still re-tasks/reclaims — none freezes an AI. Sequencing rule preserved: HC-local units must be flagged-then-HC-deleted (server `deleteVehicle` can't reach them).

### performance / FPS _(healthy at B61 — keep it that way)_
- **FPS 47–48 at ~260 units / 3 players, HCs at 86% offload.** Best of any build. B59's overnight dips to 24–30 were at 450–548-unit / 10-active-town spikes — B61 hasn't reached that scale yet this session.
- **Adopt: instrument antistack_main/flush ms in the soak harness** (instrumentation, not a fix). **PC_LOW=12 vs 15 A/B stays deferred** until a full B61 round completes at the high-unit-count spike (the old Open-Q4). Total AI is the only safe antistack lever.
- **antistack itself: hands-off entirely.**

### bugs & telemetry
- **Adopt #3 (SUPPLYSTAT), #9 (phantom capture counter), infPerTeam/vehPerTeam split, TEAM_FOUNDED `class=` mislabel fix, engine-flood ("Message not sent") tripwire in the harness.** All harness/diag-only, build-independent.
- B61 live: 0 script errors; benign noise only (HC identity spam, ACR-DLC-absent class skips, JIP netsync "Object not found"). Leave the engine alone.

---

## B60 / MHQ-RELOCATION — **NOW LIVE IN B61, DEFAULT-ON, UNRESOLVED RISK**

**Status change:** the MHQ relocation that was HOLD in the B59 plan is **shipped in B61, default-ON** ("MHQ relocation + heli cannon-nudge default-ON" per the build notes). Live RPT shows **0 MHQRELOC lines — it has not FIRED yet**, only because the spearhead town is still <`WFBE_C_AICOM_MHQ_FRONT_DIST` (2500 m) from HQ in the land-grab phase. **This is latent, not safe.**

**Why it's the top risk (4 unguarded failure modes in the built `AI_Commander_MHQReloc.sqf`, commit `85653acc`):**
1. **Forward teleport on deadline = the forbidden action.** Destination ~800 m behind a front that's >2500 m out is always ~1700 m+ *forward* of HQ; the deadline fallback `_mhq setPos _destPos` drives the respawn anchor toward the front, gated only on no-player-900 m.
2. **No hop cap** (spec wanted ≤1500 m).
3. **No pre-factory gate** — relocates at any war stage.
4. **Stale enemy re-check** — `_eNear` checked only at trigger time, never freshly at the final deploy; the soft MHQ truck can deploy onto a hot tile and one contact kills the respawn anchor.

**Recommended action this cycle (#1 in the table):** set **`WFBE_C_AICOM_MHQ_ENABLE = false`** as the safe interim until re-built to spec — OR have Ray knowingly accept the forward-teleport risk before the front travels. Do not leave it unaddressed.

**Exact re-build tuning (unchanged from B59 plan):** default-OFF; pre-factory gate only (mid-war forward-FOB is a redesign, out of scope); hop cap ≤1500 m and destination backward-or-in-place (never forward); move all three deploy flags AT `setPos` with a fresh enemy scan at the deploy position; mirror the 300 m no-player guard; `MHQRELOC|DEPLOYED` must log BOTH old + new HQ positions to make any net-forward move detectable.

**Heli cannon-nudge — REJECT as premised** (also default-ON in B61). It rides `flyInHeight`; the attack Mi-24_P is a different code path that already scores kills unaided; `doFire`+`selectWeapon` spam fights the gunner FSM and dropping to 35 m near enemy hands a gunship to MANPADS — plausibly negative EV. Ship only the decoupled air-telemetry line. **Watch the B61 RPT for any sign the nudge is degrading Mi-24 survivability.**

---

## Open questions for Ray

1. **MHQ-reloc is LIVE in B61 default-ON (the forward-teleport version).** Disable it (`WFBE_C_AICOM_MHQ_ENABLE=false`) until re-built to spec, or knowingly accept the risk? **Recommend disable now** — PRESS posture is pushing the front toward the 2500 m trigger and this is the one round-losing item.
2. **Did B61's refill-at-base actually close the B59 bleed?** Warmup says yes (unitsPerTeam=8, 0 stranding) — OK to PARK the reclaim/strand fixes (#6/#7/#8) pending a full-round confirmation?
3. **Economy:** agree to change NOTHING and just land the SUPPLYSTAT diagnostic (#3) to measure tempo for a cycle? (The "supply-starved" reading was a misread of intended FUNDS-FALLBACK telemetry.)
4. **Spectacle:** green-light building the off-server Front-Status Discord embed (#4) first — reusing the bot that already runs — then the LLM recap (#5)? All off-server, zero live-server risk.
5. **Heli cannon-nudge is also live default-ON in B61** — ship only the air-telemetry line and disable the nudge?
6. **Run a full B61 round to completion** before the PC_LOW=12-vs-15 perf A/B (need the high-unit-count spike to measure against).

---

## What NOT to touch

- **The live economy — change nothing.** FUNDS-FALLBACK is intended (funds→tech converter); the bootstrap floor prevents a death spiral; town-scaling already exists; founding spends funds not supply. Raising `SUPPLY_INCOME_MULT`, adding town-scaling, or gating founding on supply all revert intentional tunes, risk snowball, or hit antistack. Measure (#3) first.
- **No live-server spectacle.** All adopted spectacle is OFF-SERVER (Discord embed/recap/timelapse from telemetry already emitted). No in-mission cams, markers, or scripted events — they cost FPS we must not break and reach ~3 people.
- **antistack — hands-off entirely.** Only safe lever is the input (total AI / PC_LOW), never the algorithm. FPS is healthy.
- **Towns / per-side balance stay HARD.** Symmetric by construction (flat income, symmetric templates, stronger side swaps between soaks). No per-side coefficient, no mission.sqm ownership edits.
- **No sim-gating, no frozen AI.** Every code-shaped item re-tasks/reclaims/measures; none idles an AI.
- **Do not deploy. Do not merge this branch. Propose-only.** (B61 was deployed by Ray, not by me.)
