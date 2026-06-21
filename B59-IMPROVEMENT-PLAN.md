# WASP B59 - Improvement Plan (all facets)

_Seed v1: 2026-06-20 overnight multi-facet adversarial debate (15 agents, deeply code-verified). LIVING doc: refined every ~2h overnight, **CONSOLIDATED 2026-06-21 06:00** against the full overnight live RPT. PROPOSE-ONLY — nothing here is deployed._

**Changelog**
- _2026-06-21 (06:00 CONSOLIDATION — final morning form): validated EVERY top recommendation against the whole night's live RPT (`arma2oaserver.RPT`, 22,193 lines, read-only over ssh). Resolved cycle-2's open Q0 — **the server IS running a live B59 round** (single continuous round, still going, deadlocked). Hard new ground truth reshuffled the ranking: the **retreat-and-reform death loop** is now measured at **6,397 orders, 100% alive=1, all 5.8–9.7 km out** → the bleed reclaim (old #2) is promoted to the single biggest lever. Corrected three cycle-2 beliefs: (a) the front is a **6v6 partition (contested=0)**, not 2-2 — the front DID advance 0→6 each side then froze, so the picker is a contributor, not the sole cause; (b) **ASSAULT_STRANDED is NOT silenced** — it fires 18× (17 WEST), terrain-wedged at fixed coords → road-independent teleport is strongly validated; (c) the RPT "wedge" lines are the **WEDGE-WATCHDOG working** (6 defense→offense releases), not a pathology — it just under-fires. B60 HOLD stands (0 MHQRELOC lines confirm B59, not B60, is live)._
- _2026-06-21 (cycle 2): went deep on economy/balance + B60 go/no-go. Found economy symmetric BY CONSTRUCTION (no per-side coefficient in `updateresources.sqf`); B60 BUILT code diverges from the guarded MHQ spec → escalated B60 to HOLD/re-build. Added #13 (maneuver-vs-garrison gate) and #14 (infPerTeam split diag)._
- _2026-06-21 (cycle 1): went deep on aicom-units. Surfaced the alive=1 retreat-and-reform churn and strike=5/distStart=0 wedged foot leaders; added #2 (disband alive≤1), #3 (road-independent teleport), redefined #6._

---

# WASP B59 → B60 Improvement Plan

## Headline

**State of B59 — stable, and broken in exactly one way.** The build is mechanically rock-solid: across the full overnight live round there were **0 script errors, 0 fatals, 0 crashes**, server FPS held **46→42** with no night-long decay (dips to 28–30 only at 548-unit / 10-active-town spikes, recovers every time), founding fires at the **15/side cap**, **jet-spam = 0** (every ORBATSTAT `jet=0`), **aiMax 190 is never hit** (per-side AI peaks well under it), and the **Mi-24 W6 air-gate held** (first `Mi24_P` production order ~t=232). The plumbing works.

What does NOT work is **the round progressing to a decision.** The front crawled out to **6 towns each side and froze into a static partition** — `AICOMSTAT FRONT contested=0` for the entire back half, both commanders sitting in DEFEND/HOLD at 6v6, 73 STALL markers (66 WEST). The two sides are not even fighting over the boundary.

**The single biggest lever** is the mechanism behind that freeze: a **retreat-and-reform death loop.** The RPT contains **6,397 `retreat-and-reform ordered` lines — 100% of them `alive=1`, every one at 5,800–9,690 m from target.** Squads get whittled to a single survivor far from the front, get ordered to walk kilometres back to reform, never re-pad to full, and the loop repeats forever. That one defect produces (a) the `unitsPerTeam` bleed (oscillates 5.5–7.4 all night, never reaches the 8–12 founding floor even though founding fires 99×), (b) the inability of either side to mass enough force to contest a boundary town, and (c) most of the log spam. **Fix the reclaim path and the front can move again.** Founding works; *sustainment* doesn't.

**The one risk to hold the line on:** never ship a standing-still or front-teleported AI. The B60 MHQ-relocation, **as currently built**, teleports the respawn anchor *forward* onto the hottest tile — it is the single item in this whole plan that can lose a round outright, and it is shipped default-ON. It must not deploy as built.

---

## Top 10 ranked actions (all facets)

| # | What | Why (overnight evidence) | Impact / Effort | Verdict | Facet | A2-OA-safe pointer |
|---|------|--------------------------|-----------------|---------|-------|--------------------|
| 1 | **Reclaim alive≤1 teams far from HQ instead of perpetual retreat** — when `alive<2 && dist(_ldr,_hqP)>800` at `AI_Commander_Produce.sqf:77-84`, set `wfbe_aicom_disband` (reuse the HC-side delete consumer `Common_RunCommanderTeam.sqf:400-416` with its no-player-300m + not-in-combat guard) so `AI_Commander_Teams.sqf:155` re-founds a full-size team. One-shot guard so the retreat order can't re-fire each cycle | **THE proven engine of the stall.** 6,397 retreat-and-reform orders, 100% alive=1, all 5.8–9.7 km out — teams never re-mass. Kills the bleed, the spam, and frees the front in one move | **highest** / low | **adopt** | aicom-units | flag-then-HC-delete (server `deleteVehicle` can't reach HC-local units — do NOT delete in Produce); re-found cooldown to avoid delete→refound thrash. All 1.64-safe |
| 2 | **Make the Tier-3 foot/dead-hull teleport road-independent** — at `Common_RunCommanderTeam.sqf:501` widen `nearRoads 150` → ~400 m; on miss fall back to nearest flat non-water empty pos (reuse `WFBE_CO_FNC_GetEmptyPosition`/`GetRandomPosition` already at `:31-32`), keep the 300 m no-witness guard `:498-500` | **Validated, not silenced.** 18 ASSAULT_STRANDED fired (17 WEST), `moved=0 stuck=true`, repeat offenders pinned at fixed coords (Khelm 1779 ×4, NEAF 1337 ×4, Msta 3060) — teams physically cannot path off terrain with no road in 150 m | high / med | **adopt** | aicom-units | `nearRoads`/`setPos`/`surfaceIsWater`/`doFollow` all 1.64-safe + in-file; teleported leader still gets the road-march MOVE so it re-wakes (never frozen) |
| 3 | **Re-pick the spearhead when progress stalls** — per-side `[primaryTown,approachDist,time]` memory; if approach-to-target hasn't shrunk ~150 m for N≥4 ticks, push the town to a side-level spearhead-blacklist (600 s) and force next-best | Front held=4 stuck **t=131→201 (~70 ticks, zero movement)** and 73 STALL markers. Contributor (front *did* reach 6v6, so demoted below the death-loop), but the mid-round freeze is real | high / med | **adopt** | aicom-strategy | selection-only; reuse blacklist idiom `AssignTowns.sqf:208-219` + empty-set guard `:290-295`. Use approach-to-target, not raw distFront |
| 4 | **Separate, non-reset strand/stuck counter + terminal escalation** — add `wfbe_aicom_strandcount` the abandon-blacklist does NOT zero (`AssignTowns.sqf:217` zeroes `wfbe_aicom_stuckstrikes`); when `>N` trigger a genuinely terminal action (fresh retarget / recycle via the slot lifecycle) + one-shot RECYCLE log. Stop `_dt0` resetting on blacklist target-churn | Same WEST teams **re-strand at identical coords** (Khelm ×4, NEAF ×4) — the strike counter resets every 5 so escalation never reaches "terminal". Note: distinct from the working WEDGE-WATCHDOG; do not collide names | high / med | **adopt** | aicom-units | pure setVariable + counter; recycling team holds its MOVE until the new slot spawns (never idle); slot release at `aicom-team-ended` |
| 5 | **Maneuver-vs-garrison strength gate** — compute `_maneuverStr` (alive in teams NOT in garrison/relief mode), gate PRESS/DEFEND on THAT, not total side strength, so a side that holds many towns keeps pressing | The **6v6 contested=0** freeze: both sides DEFEND/HOLD because the DEFEND gate (`Strategy.sqf:388-399`) counts garrisoned troops as available, so each leader reads itself as too weak to attack. This is the "passive partition" signature | high / med | **trial** | aicom-strategy | read mode via existing `wfbe_teammode`/garrison-grp checks (NO new scans/findIf); last-stand gate `Strategy.sqf:47` catches over-commit; sequence AFTER #1+#3 |
| 6 | **Add antistack_main/flush ms to the soak harness** — grep `[Performance Audit] NAME=antistack_main AVG_MS=`, emit peak + trailing-avg vs `allUnits` | Antistack is the dominant hitch and the deciding 15-team metric; today it's eyeballed. With FPS healthy this is instrumentation, not a fix | high / low | **adopt** | performance | harness-only; assert ≥1 sample/BIG-window or flag "audit line not found". Never touch the algorithm |
| 7 | **Fix the phantom capture counter** — drop the `CAPTURED` match (`wasp-b57-soak.ps1:51`), make the headline metric the real `CAPTURE`/`TOWN_FLIP` event count, relabel "flips" not "captures", repoint $cap consumers | **Confirmed false metric:** raw `CAPTURE` grep = 352, real capture **events = 12** (the rest are `town_capture_scan` Performance-Audit rows). The stall finding fires/clears on noise today | high / low | **adopt** | bugs-telemetry | harness-only; repoint ll.153/179/202 + capDelta in one pass |
| 8 | **Wire the HC-team live top-up consumer** — write the unwritten HC-side `createUnit`+`joinSilent` half of `AI_Commander_HCTopUp.DRAFT.sqf`; default-OFF, 1 team/call, in-contact + near-supply guards, armour-exempt | The second answer to the bleed: top up live veterans vs #1's reclaim-and-refound. `Produce.sqf:63` skips 100% of HC teams (`srvTeams=0` confirmed live), so without this the picker fix just freezes a thinner fist | high / high | **trial** | aicom-units | `createUnit` MUST run where `local(leader _team)`; verify join + funds/units conservation before enabling; sequence AFTER #1 |
| 9 | **infPerTeam / vehPerTeam split diagnostic** — emit `unitsPerTeam` split into inf (excl `_isMBT`/`_isAttackHeli`) vs blended, reuse `isKindOf "Tank"`/`transportSoldier==0` from `Produce.sqf:119-121` + `Teams.sqf:310-313` | Blended ~6 is ambiguous. Live `srvTeams=0` / `vehTeams≈0` means today's blended ≈ infPerTeam, but the split makes attrition-vs-composition unambiguous the moment vehicle teams appear. Free | med / low | **adopt** | bugs-telemetry | DIAGNOSTIC ONLY — never an asymmetric balance lever; reuse existing classification, no A3 primitives |
| 10 | **Off-server end-of-round LLM battle recap** — scrape the latest-MISSINIT structured ledger (`TOWN_FLIP`/`WASPSTAT|KILL`/`TEAM_FOUNDED`/`CMDRSTAT`) → Claude → Discord webhook | ~100% off-box, reuses the SSH-tail + Peach/Discord plumbing. An AI war nobody watches produces no narrative; the night gave a clean structured ledger to feed | high / low | **adopt** | spectacle | feed ONLY structured markers, never raw RPT; latch one recap per MISSINIT; Ray=834428635896610886 |

**Folded into by-facet (below the top 10, validated but lower priority):** TEAM_FOUNDED `class=` mislabel fix (bugs-telemetry, adopt); HQ-strike town-gate lower to a named constant (aicom-strategy, trial — *after* a lead can develop); PC_LOW=12 vs 15 A/B (performance, trial — run 15 to completion first); make the WEDGE-WATCHDOG more aggressive (aicom-strategy, NEW this morning); B60 MHQ re-build (see go/no-go).

---

## By facet

### aicom-units _(the decisive facet this round)_
- **Adopt #1, #2, #4; trial #8.** Live evidence is unambiguous: 6,397 alive=1 retreat-and-reform orders at 5.8–9.7 km are the bleed engine; 18 terrain-wedged ASSAULT_STRANDED (moved=0, repeat coords) are the second leak. The bleed has no recovery path (refill at `Produce.sqf:62-69` is skipped for HC teams; `_canProduce=false` at `:84`) AND no cleanup keyed on alive count (the only disband, `Teams.sqf:126-155`, keys on `foundedTeams>target`). #1 closes both.
- **#1 vs #8 are competing answers to the same hole** (see Open Q3): #1 reclaim-and-refound is the cheap safe default; #8 keeps veterans but adds units against the 190 cap → trial on top of #1, never instead.
- **Reject Tier-4 force-dismount** (the old B57 proposal) — #2's road-independent teleport covers the mounted/near-road gap without a new dismount path that risks a frozen vehicle crew.
- Every accepted item re-tasks or reclaims; none freezes an AI. #1 *deletes* (not idles), #2 re-issues a MOVE, #4 holds a MOVE until the new slot spawns.

### aicom-strategy
- **Adopt #3; trial #5.** The front reached 6v6 then froze with `contested=0` and both sides passive — that is the maneuver-mass mis-read (#5), compounded by the mid-round 70-tick spearhead stall (#3). POSTURE is largely dead telemetry (4 writers, 1 reader) — do NOT bolt behaviour onto it; fix selection (#3) and the real aggression gate (#5).
- **NEW this morning — make the WEDGE-WATCHDOG more aggressive.** The watchdog works (6 clean "released from defense, no move 0–111 m in 241 s → offense" events) but only fired 6× all night, far too rarely to break a 6v6 deadlock. Lower its no-move window / shorten its cadence (it already re-tasks to offense, so it stays A2-safe and never idles). Trial alongside #5.
- **Lower the HQ-strike town gate** (`Strategy.sqf:319-324` to a named `WFBE_C_AICOM_HQ_STRIKE_MIN_TOWNS` ~5-6): **trial, STRICTLY after #1+#3** let a real lead develop — today nothing reaches the >8-town threshold so rounds can't END, but lowering it before the bleed is fixed would just hand wins to noise.
- **Reject** "give POSTURE teeth" — fights #3, animates a dead system.

### economy & balance _(downstream, not a lever)_
- **Income is symmetric BY CONSTRUCTION** — re-confirmed against the night: boot shows `startFunds=202000` both sides; `updateresources.sqf` has no per-side coefficient; AICOMSTAT funds track evenly. The unitsPerTeam asymmetry (WEST holds ~7, EAST dips to ~5.6 in earlier snapshots) is 100% downstream of the death loop + HC-no-topup hole, NOT an economy term.
- **Chase the stall with NONE of the economy knobs.** Raising income/garrison masks the only greppable telemetry that proves the bug and inflates the war chest into *more thin teams* → worse FPS. Cash is not the 15-team limiter (HC cadence + TOTAL_AI_MAX 190 are).
- **Adopt #9 (diagnostic); trial #5** (it's a strategy gate, the only economy-adjacent survivor). **Reject** per-side reinforcement floors and attrition-aware founding throttles.

### performance / FPS _(healthy — keep it that way)_
- FPS 46→42 across the night, floor 28–30 at the 548-unit / 10-active-town spike, full recovery each time. No leak (gentle decline tracks unit count, not time). Antistack is the untouchable unit-bound ceiling.
- **Adopt #6** (instrument antistack). **Trial #10/PC_LOW** = run a full 15-team round to completion FIRST, then A/B PC_LOW=12 vs 15 measuring peak `antistack_main` ms + min SRVPERF — total AI is the only safe antistack lever (`Init_CommonConstants.sqf:139`). Needs #6 + (#1/#8) for steady-state validity.
- Keep `WFBE_C_GROUPAUDIT_EVERY=5`; keep the found-size pad (near-no-op until #1 lands, since teams found at 10 then immediately bleed).

### player spectacle & AI cinematics
- **Adopt #10** (off-server LLM recap). The night produced a clean structured ledger (12 real captures, TOWN_FLIP, WASPSTAT|KILL incl. 7 Mi-24 kill lines, last-stand × 6) — ideal recap fodder.
- **Trial after #10's scrape is proven:** a TOWN_FLIP war-map timelapse; a **contested-town director cam ranked by live combat density** (the frozen-front spearhead is boring — point the camera at the fight, not the stall); a stranded/last-stand "blooper" footer (keeps stranding visible until #2/#4 land). All default-OFF, admin/spectator-gated to avoid friendly-only intel leak.
- **Reject** a new KILLSTAT emitter — `WASPSTAT|KILL` is already live; the recap just parses it.

### bugs & telemetry
- **Adopt #7** (phantom capture counter — 352 grep vs 12 real events) and the **TEAM_FOUNDED `class=` mislabel fix** (`Teams.sqf:309-313` emit the content-true label from `_isBigVeh`, keep the upgrade value as `gate=`).
- **Adopt #9** (inf/veh split).
- **Engine-flood tripwire:** the night was clean (0 script errors), but B58 saw ~20.8k "Message not sent" floods the parser read as `err=0`. Widen the harness to count `Message not sent` / `Object…not found (message N)` as a tripwire (not an error). Also harmless-but-loud at this boot: 75× "Player without identity HC" (HC handshake retry) and INIT `Duplicated Element` config-merge warnings — both cosmetic, leave the engine alone.
- **Reject** an in-mission FOUNDSTAT ledger (redundant once the `class=` fix lands).

---

## B60 GO / NO-GO — **NO-GO (HOLD; do not deploy as built)**

Live RPT shows **0 `MHQRELOC` lines** — confirming B59, not B60, is the deployed build. Nothing in the night contradicts the HOLD; it is reaffirmed.

**Why HOLD (not just default-OFF):** the BUILT `AI_Commander_MHQReloc.sqf` (commit `85653acc`, default-ON "per Ray") diverges from this plan's guarded spec on four safety guards, any one of which can lose a round:
1. **Forward teleport on deadline = the forbidden action.** Trigger fires when the spearhead town is >`WFBE_C_AICOM_MHQ_FRONT_DIST` (2500 m) from HQ; destination ~800 m behind that front is always ~1700 m+ *forward*; the deadline fallback `_mhq setPos _destPos` drives the respawn anchor toward the front, gated only on no-player-900 m.
2. **No hop cap** (spec wanted ≤1500 m).
3. **No pre-factory gate** — relocates at any war stage, including a mid-war FOB with barracks/factory standing.
4. **Stale enemy re-check** — `_eNear` is checked only at trigger time vs the destination + old HQ, never freshly at the final deploy; the soft MHQ truck (driven CARELESS, `disableAI TARGET`) can deploy onto a hot tile and one contact kills the respawn anchor.

**If/when re-built — the exact tuning to set:**
- `WFBE_C_AICOM_MHQ_ENABLE = false` (absent ⇒ false; default-OFF, trial only).
- **Pre-factory gate only:** relocate solely in a 0-structure shut-out (no barracks/factory up). The mid-war forward-FOB case is a redesign, not a guard tweak — out of scope.
- **Hop cap ≤ 1500 m**, and **destination must be backward-or-in-place** relative to the current HQ — never forward of it.
- **Move all three deploy flags AT `setPos`** (not at pick time), with a **fresh enemy scan at the deploy position** at the moment of `setPos`.
- Mirror the 300 m no-player-witness guard.
- **`MHQRELOC|DEPLOYED` must log BOTH old- and new-HQ positions** so any net-forward move is detectable in the next soak.
- **Sequencing:** do NOT trial B60 until #1 (+#3) land and the soak shows a *moving* front — until then there is no scenario it helps.

**Heli cannon-nudge — REJECT as premised.** It rides `flyInHeight` (never fired in the RPT's lifetime); the *attack* Mi-24_P is on a different code path and already scores kills unaided (7 Mi-24 KILL lines this round); `doFire`+`selectWeapon` spam every 7 s fights the gunner FSM on a 30-FPS-floor build, and dropping to 35 m inside 700 m of enemy hands a gunship to MANPADS/AAA — plausibly negative EV. **Ship ONLY the decoupled air-telemetry line** from that change, not the nudge.

---

## Open questions for Ray

1. **B60 — confirm HOLD + re-build to spec + default-OFF** before any soak? (The build is wrong, not merely default-ON.)
2. **MHQ relocation purpose** — accept the safe pre-factory-only scope (near-useless, only helps a 0-town shut-out), or shelve MHQ entirely until #1/#3 give us a moving front and revisit the mid-war FOB as a proper redesign?
3. **Bleed fix preference** — reclaim-and-refound (#1, cheap, safe default) vs live top-up (#8, keeps veterans but adds units against the 190 cap)? Recommend #1 now, #8 as a trial layered on top.
4. **Run a full 15-team round to completion** before treating PC_LOW=12 as the recommendation (#10/perf)? The night never reached a round end to measure against.
5. **Win-condition policy** — once the bleed is fixed and a real lead can form, do we let a dominant-but-thin territorial leader launch an HQ strike (relaxing the never-rush-while-behind invariant via #5 + the town-gate), or keep it hard? This gates whether rounds can actually END.

---

## What NOT to touch

- **antistack — hands-off entirely.** The only safe lever is the input (total AI / PC_LOW), never the algorithm. FPS is healthy; do not pre-optimise it.
- **Blended `unitsPerTeam` — do NOT tune FOUND_SIZE/PC_LOW/templates off it.** With `vehTeams≈0` the blended value ≈ infPerTeam, but it stays a false-alarm trap; use the #9 split after a round with real vehicle teams.
- **Towns stay HARD.** The stall is a lifecycle bug + a strategy gate, not economy. Economy is healthy AND symmetric by construction — no per-side economy lever, no map re-balance, no hand-editing town ownership in mission.sqm.
- **No sim-gating, no frozen AI.** Every accepted item changes SELECTION or reclaims/teleports-then-re-tasks: #1 deletes (not idles), #2 re-issues a MOVE, #4 holds a MOVE until a new slot spawns, #5 only changes WHICH aggressive order issues.
- **Unstuck ladder — surgical only.** No Tier-4 force-dismount; fix the Tier-3 road dependency (#2) and the non-reset counter (#4). Do NOT collide the new counter with the working WEDGE-WATCHDOG.
- **`_strikeOn` win-condition gate** (`Strategy.sqf:321-323`) — Steff's never-rush-while-behind invariant. Lower the town threshold only after the front moves; do NOT relax the ratio/strength guards.
- **Do not deploy B60. Do not merge this branch.** Propose-only.
