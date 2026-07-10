# WASP overnight soak — definitive report (cmdcon27, Chernarus)

**Match:** one continuous AI-vs-AI match, SID `chernarus_168_888618`, AICOM min ~60→527 (~7.8h). Human: Zwanon (idle WEST observer) until ~min196, then pure AI. 11 evidence ticks (t0=min94 → t10=min527).

---

## 1. Executive summary

The cmdcon27 build is **healthy and the headline freeze fix held perfectly** — across ~430 AICOM ticks the stuck-team edge-reset "lost-their-brain" freeze **never recurred**; the unstuck system escalated 1→5 and abandoned→re-picked cleanly all night. The match itself was a **perfectly balanced, slow-burn carve-up of neutral GUER towns** (GUER 42→31) that ended 9-6 WEST but **could not actually resolve** — neither AICOM ever took a town from the other (zero E↔W flips, 6 GUER-only flips all night). The one real pathology is **assault-reach**: ~11% of dispatched assault teams ever arrive; the rest strand 1–2.6 km short because A2's pathfinder can't route to a handful of specific GUER towns (Stary Sobor hit 105× by EAST, abandoned 6×). Server health is green (one transient AI surge to ~532 caused a ~30s fps trough to 14–24, fully recovered to 48fps@280). **Honest caveat: this analysis loop refuted its own headline conclusions on nearly every hypothesis** — the value was in attacking interpretation, not data.

---

## 2. The match arc

A symmetric carve-up of neutral GUER towns. Early EAST edge → hard 6-6 deadlock → late WEST breakout, driven entirely by GUER attrition, never by either AICOM beating the other.

| AICOM min | EAST | WEST | GUER-neut | Phase |
|---|---|---|---|---|
| 60 (t0 start) | 3 | 1 | 42 | EAST early lead |
| 94 (t0 end) | 3 | 2 | 41 | |
| 149 (t1) | 5 | 3 | 38 | EAST peaks +2 |
| 194 (t2) | 6 | 4 | 36 | both creeping |
| 219 (t3) | 6 | 5 | 35 | WEST closing |
| **247 (t4)** | **6** | **6** | 34 | **6-6 tie first locks** |
| 297 (t5) | 6 | 6 | 34 | locked |
| 349 (t6) | 6 | 6 | 34 | locked (terminal-looking) |
| 376 (t7) | 6 | **7** | 33 | **WEST breaks deadlock (~min360)** |
| 436 (t8) | 6 | 7 | 33 | WEST holds |
| 464 (t9) | 6 | 7 | 33 | WEST holds |
| 492 (t10) | 6 | **8** | 32 | WEST +1 |
| **514–527 (t10 end)** | 6 | **9** | 31 | WEST 1.5× EAST |

- **Net:** EAST captured 5 GUER towns and stalled; WEST captured 8 and kept going. **Every capture was from GUER** — exactly **6 TOWN_FLIP events all night** (Solnichniy→W, Pulkovo→E, Rogovo→E, Polana→W, Msta→W, Shakhovka→W), **zero E↔W flips**.
- **The "stalemate" was both armies stalled against GUER garrisons simultaneously** — not two armies grinding each other (consistent with assault-reach below).
- **GUER is a renewable wall:** despite losing 11 towns it kept firing wildcards/roadblocks every tick and its count even *grew* 51→58 mid-match. It never collapses — which is precisely why neither AICOM could snowball.
- **Human:** Zwanon was a WEST observer with **0 combat** (`PLAYERSTAT 1|0|0|0`), last heartbeat t=179, `myPlayers` 1→0 at min196. Pure AI-vs-AI for the final ~331 min.

---

## 3. AI-commander — the definitive finding (assault-reach / pathing)

**Verdict: assaults don't convert because A2's pathfinder can't route foot/crew teams to specific towns. Confidence 0.9 that this is an engine limitation, not a WASP code bug.** The brain, allocation, dispatch, and unstuck machinery all work correctly; the failure is at the engine mover layer.

Quantitative backbone (DE-DUPLICATED — the rolling-tail slices OVERLAP, so per-tick event counts **cannot be summed** across ticks; figures are unique-event totals for the whole match):

| Metric | Value |
|---|---|
| DISPATCH (whole match, deduped) | **~321** |
| STRANDED (whole match, deduped) | **47** |
| UNSTUCK strikes (whole match, deduped) | **~113** |
| ARRIVED vs DISPATCH (net arrival rate) | 43 / ~321 = **~12–13% arrive** |
| STRANDED teams that barely moved (<100 m) | **37 / 47 = 79%** (mean moved 190 m) |
| ARRIVED proximity when they do arrive | mean **126 m**, max 244 m |

*(Earlier draft inflated these to 897/105/258 by summing overlapping slices — the exact "over-reading" trap this loop warns about; corrected. The conclusions never depended on the totals — the load-bearing signal is the 79% strand-in-place, the binary arrive/strand split, and Stary Sobor 105×.)*

- **Binary arrive/strand signature** = fingerprint of *no valid path*, not slow movement or combat attrition. A team either reaches <250 m (ARRIVED → capture in 4–6 min) or sits essentially in place (78% moved <100 m of a 1.5–3 km leg).
- **The unstuck system fires correctly and still can't recover them.** Strikes escalate cleanly 1→5 with `distStart` pinned at 0–5 m; tier-3/tier-4 teleports fire (HC RPT: t3=15, t4=9 of 99 events); `TARGET_ABANDON cooldown=600` re-picks work. Every recovery lever works — the destination is just unreachable.
- **Same ~5 towns dominate strands all game:** Stary Sobor (17/47), Mogilevka (7), Dolina (4), Pulkovo (3), Msta (3). EAST issued **105 dispatches to Stary Sobor** and abandoned it 6× — a textbook re-pick-fails-the-same-way loop.

**Correction that strengthens the conclusion:** the cmdcon28 fix-design frames the WEST stall as a `concentrate=true` trap. That was true **only at t0–1**. By **t3 onward both sides read `concentrate=false | expand=3`** (the AICOM *was* expanding to nearest neutrals) — and Stary Sobor/Mogilevka *still* couldn't be taken. So fix-candidate #1 (concentrate-stall escape) would **not** have fixed the persistent night-long failure.

**Fix direction (ranked):**
1. **Per-side unreachable-town blacklist (highest leverage, lowest risk).** After ~3 consecutive side-wide STRANDED-with-moved<100m on a town, blacklist it for the side and exclude from fist/expand pools. A2-safe (scalar map keyed by town, reuse TARGET_ABANDON plumbing), flag-gated, reversible. Drains the 105×-Stary-Sobor churn into productive targets.
2. **Distance→path-cost reach pre-check at target-pick** (fix-design candidate #2, done globally) — or proxy: treat a town with N accumulated side strands as unreachable.
3. **Bundle the concentrate-stall escape (candidate #1)** as a complementary *early-game* patch — ship it, but not as the headline; it does not resolve the persistent stalls.
- **Do NOT ship a teleport-onto-objective hack** — violates the no-frozen/no-warp-in-player's-face guardrail, and the teleport tier already fires without curing the problem.

Files: allocation `Server/AI/Commander/AI_Commander_Allocate.sqf` (L69–88 target pool, L179–180 concentrate gate); unstuck `Common_RunCommanderTeam.sqf:~588`.

---

## 4. Server / client health + the fps-reading lesson

**Server health: GREEN. No degradation, no leak, no creep.** The tick-7 "crash" was a real but transient compute spike, fully recovered.

fps arc (from the authoritative `NAME=snapshot EXTRA=periodic` row only):

| Tick | In-game DT | Live AI (P=2) | Srv FPS |
|---|---|---|---|
| 6 | 13.82 | 278 | 48 |
| 7 | 14.85 | 353 | 24 |
| 8 | 15.27 | 398 | 27 |
| 9 | 15.74 | 280 | **48 (full recovery to t6 operating point)** |

- **The true live-AI peak was ~532, not 398** (ledger correction). The slices are overlapping tail reads; within the DT14.1–14.6 band the live delegate rows show the real trough: **DT14.60 → 14 fps @ AI=532**, DT14.10 → 33 fps @ AI=452. The "280→398→280" surge story is directionally right but understates it — it was **280 → ~532 → 280**.
- **Smoking gun:** at DT14.60 a single `delegate_townai_headless` call ran **AVG 114ms / MAX 156ms** — ~7–8 server frames (budget at 48fps ≈ 21ms) in one synchronous AI-delegation tick. **Compute-bound on live AI count**, exactly as the no-sim-gating mandate guarantees. The `Network message pending` flood was a *symptom* (replication backlog), not the cause. *(Caveat: delegate is the AI-count-TRACKING cost but NOT the single worst frame — `antistack_main`/`antistack_flush` hit MAX **334–342ms** and fire even at 48fps@280AI, i.e. AI-independent + periodic. They're a known flush, non-accumulating, and off-limits per the no-antistack mandate, so they don't change the green verdict — but the worst frame is antistack, not delegate.)*

**The fps-reading lesson (load-bearing for Ray):**
1. fps tracks **instantaneous live-AI count**, which spikes during founding/battle surges. A single low snapshot ≠ degradation.
2. **Only trust the `NAME=snapshot ... EXTRA=periodic` row.** Slices carry stale lines — a `FPS=23 PLAYERS=3 AI=413` ghost (PLAYERS=3 = hours-old, pre-Zwanon-leave) re-appears in ticks 2,3,7,8,9,10. Filter on PLAYERS=2 + DAYTIME ordering.
3. **The leading indicator is `delegate_townai_headless` MAX_MS, not fps.** 156ms there preceded the fps dip; fps is the lagging consequence. Watch per-subsystem frame budget.

**SQF errors — benign, non-WASP, non-accumulating.** One identical third-party kill-handler token (`nearEntities [["CAManBase","StaticWeapon..."`, `_shooter`/`_k` — absent from the repo), fired once in t0–6 and twice in t7–10 across 7 hours. The "2 vs 4" is the regex matching 2 log lines per firing. Not a perf contributor.

**Client:** from the live reaped client RPT current-session checks (every tick). **Reconciled:** it's **200 throws/join = 600 error lines** — each allMapMarkers throw emits 3 lines (expression + position + undefined-variable), so 200 × 3 = 600. Same bug, `Init_Client.sqf:650`, every join all night. cmdcon28 fixes it.

---

## 5. cmdcon27 feature status

| Feature | Status | Notes |
|---|---|---|
| **Stuck-team edge-reset freeze fix** | ✅ **HELD (headline win)** | No recurrence over ~430 ticks. Tier ceiling reached every tick (max tier per tick = 3,4,4,4,3,4,4,4,1,4,4 — the t8 "1" is a short slice window, t9 back to 4). Clean escalate→abandon→re-pick. UNSTUCK total grew smoothly 25→258. |
| **AI-strategy-default (delegate true)** | ✅ **HELD** | Ran the match solo unattended; DELEGATE count 22→138, captures produced with zero humans. No follow-up. |
| **HQ-heal (allMapMarkers)** | ❌ **BROKEN — fix staged** | A3-only command throws on every client at `Init_Client.sqf:650`. cmdcon28 named-marker fix staged & ready. **The one definite code ship owed.** |
| **War-room nudges (MASS/SPLIT/HARASS/FALLBACK)** | ⚠️ **Plumbing intact, untested + inert all night** | Exactly **1 FIELDORDER all night**, byte-identical t0=t10: `ORDER\|aicom-fieldorder\|WEST\|76\|order=MASS` — an **AICOM auto-order, not a human nudge**, and a structural no-op (WEST was <4 towns, already concentrating). 3 of 4 verbs got zero exercise. Needs a deliberate human-nudge-into-contrary-posture test on a ≥4-town side. |
| **Player-icon (own-arrow)** | ⚠️ **No regressions, but unexercised** | ~Zero engaged player-time (Zwanon idle then gone). "No regressions observed," not "validated." |

**Ledger correction:** `client-slice.txt` is a **stale pre-cmdcon27 client RPT** (MISSINIT tops out cmdcon13–20; the 250k WARROOM spam is the historical `GUI_Menu_Command.sqf:83` error cmdcon27 already fixed). Do **not** cite its marker/WARROOM counts as cmdcon27-current — the allMapMarkers finding rests on the separate cmdcon27 client RPT.

---

## 6. Confirmed BUGS vs DESIGN tasks vs known-issues

### Confirmed BUGS (fix owed)
- **B1 — allMapMarkers HQ-heal throw** (`Init_Client.sqf:650`, A3-only command, **200 throws/join = 600 error lines**). **Fix STAGED** (named-marker check) → cmdcon28. **The one definite ship.**

### DESIGN tasks (non-trivial, deferred)
- **D1 — Assault-reach / path-aware targeting.** The night's biggest functional gap. Recommended first move: **per-side unreachable-town blacklist** (§3 fix #1), with the path-cost reach pre-check (#2) and concentrate-stall escape (#3, early-game-only) bundled. Design note exists (`cmdcon28-assault-reach-fix-design.md`) — its candidate #2/#3 are right; **candidate #1 is mislabeled as primary cause and is early-game-only**.
- **D2 — Round-ender parity/stall override.** The match *cannot end*: round-ender needs ~12 out-towns or a dead HQ; both sides are reach-capped at ~6–9 against regenerating GUER, zero E↔W flips, so the match-end CH→TK rotation never fires. Server would sit on this Chernarus match indefinitely. Needs a deadlock/stall-triggered rotation override. **This — not perf — is the real standing reason to restart.**

### Known-issues / non-bugs (no action)
- **A2 pathfinder cannot route to certain GUER town sites** — engine limitation (conf 0.9), root cause of D1; not a WASP code bug.
- **Benign third-party SQF kill-handler error** — non-WASP, non-accumulating (§4).
- **~~Funds are a dead currency~~ — RETRACTED (post-report code check, 2026-06-30).** AI team foundings DO cost CASH — verified at `AI_Commander_Teams.sqf:701-732`: funds gate (`if (_funds < _price) exitWith {}`) + debit (`[_side,-_price] Call ChangeAICommanderFunds`). The `paidBy=supply` log lines were UPGRADES + STRUCTURES (correctly supply-paid); `TEAM_FOUNDED` logs only `cost N` with NO `paidBy` field, so the tick-1 `grep paidBy=funds` saw zero and wrongly called funds dead. Funds accumulate because **income exceeds unit-spend** (the ~10-team founding cap throttles the cash drain), not because cash is unspendable. **No economy fix needed** — units already cost cash, per the B74.2 directive. If Ray wants funds to drain harder, the lever is the team-founding cap / income, not the cost currency.
- **H7 — WEST `west=0` score-credit gap** — a real addScore-routing gap, reproduced across builds/SIDs; the one open sub-claim that *strengthened* under challenge. Low priority, real.

---

## 7. Meta-lessons / epistemics (honest: this loop refuted itself repeatedly)

The defining feature of the night's analysis is that **the loop refuted its own headline conclusions on nearly every hypothesis**, and the adversary refuted itself once. In nearly every challenge the *cited numbers were correct* — what failed was the causal story layered on them.

1. **Denominator hygiene.** H1 "AICOM under-commitment" survived two ticks on a contaminated ratio `assigned/teams ≈ 0.3`. Re-derived: **SNAP teams = 8–11** (live offensive force) vs **ALLOC teams = 26–28** (full roster incl. garrisons/dead/player groups). The commander commits ~all ~10 offensive teams every tick. The real lever is a **~10-team offensive ceiling + dead economy**, not allocation. *Verify both terms of a ratio against source before it becomes a headline.*
2. **Window-bounded causation.** H2 "EAST pulling ahead via EXPAND" was reverse causation — the +2 lead existed 8 ticks *before* the claimed expand-flip, and the window opened after the effect. *A truncated window that opens after the effect cannot establish the cause.*
3. **Verify the skeptic's provenance.** The tick1 adversary's "smoking gun" (B 1-1-L stuck with tier resetting to 1) cited **srv6/srv7 = SID chernarus_177_843790, a different match**, and srv.txt/2/3 carry **cmdcon25/26** headers. The mislabeled tier-reset is the *pre-fix* behavior; cmdcon27 tiers demonstrably escalate to 4. *Check SID + build header on every cross-file citation — the ledger caught this and walked it back (the loop's saving grace).*
4. **Verify against the CODE, not just the logs — even the "skeptical" reframe needs it.** The "dead-currency" reframe (0 `paidBy=funds` in 11 slices) *felt* like a sharp correction but was itself WRONG: `TEAM_FOUNDED` debits cash via `ChangeAICommanderFunds` without a `paidBy` label, so the grep couldn't see it. A log-only analysis cannot detect a debit the log doesn't tag — confirm at the source line. (Caught 2026-06-30 by reading `AI_Commander_Teams.sqf`.)
5. **Pair every fps with its AI count.** The tick7 "fps 48→24" scare evaporated once indexed to live AI (the trough was actually ~14fps@AI=532, a clean ~450u-knee curve). The "24@AI=353" is a legitimate `NAME=snapshot PLAYERS=2` row — both the conclusion and the figure hold.
6. **Separate measurement from interpretation.** The loop's value was almost entirely in attacking interpretation, not data. Treat confidence accordingly: the assault-reach finding (conf 0.9, multi-signal across 11 ticks/both sides) is the firmest; the war-room/player-icon validations are genuinely *open*, not confirmed.

**Ledger accuracy:** mostly accurate; H2-row fix-pointer overstates concentrate-stall, tick7 "24" is a non-server-audit figure, and `client-slice.txt` provenance is stale. Core findings (assault-reach, dead currency, freeze-fix-held, B 1-1-L provenance) all reproduce from raw.

---

## 8. Prioritized next actions for Ray

1. **Ship cmdcon28 = allMapMarkers HQ-heal fix (B1).** STAGED and ready — pack, TK-mirror, bump pbo filename + repoint cfg (client-script change → must bump filename per the cache-trap gotcha), deploy. The one definite code ship owed.
2. **Restart / rotate the server — for round-closure, not health.** The match cannot end (D2); it will sit on this Chernarus match indefinitely. Health is green, so this is purely to unstick rotation and land cmdcon28.
3. **Schedule the assault-reach design work (D1).** First move = **per-side unreachable-town blacklist** (lowest risk, highest leverage, A2-safe, reversible, flag-gated). Bundle path-cost reach pre-check + concentrate-stall escape. This is the only thing that makes captures stop being reach-gated.
4. **Add a round-ender parity/stall override (D2)** so a deadlocked AI-vs-AI match still triggers CH→TK rotation. Pair with #3 — even with better reach, two balanced AICOMs against regenerating GUER may still asymptote.
5. **Deliberately test war-room nudges next time a human is on** a ≥4-town side, driving a contrary posture (e.g. HARASS/SPLIT) and confirming an ALLOC-delta. End-to-end human-nudge path is unvalidated.
6. *(Resolved)* Client allMapMarkers count reconciled — **200 throws/join = 600 error lines** (3 lines/throw); #1 fixes it.
7. **(Optional, design)** Decide whether funds should matter — currently a dead currency; if yes, wire a funds-denominated purchase rather than tuning caps.

---

*Sources: ledger `C:\Users\Game\WASP-SOAK-HYPOTHESES.md`; raw slices `…\scratchpad\slice-tick0.txt`–`slice-tick10.txt` (cmdcon27, SID chernarus_168_888618); fix design `…\scratchpad\cmdcon28-assault-reach-fix-design.md`; prior deep-analysis `…\tasks\wrm7sv8d3.output`, `wz1s3hebh.output`. Stale/not-cmdcon27: `srv.txt`=cmdcon25, `srv2/3.txt`=cmdcon26, `srv4-7.txt`=SID chernarus_177_843790, `client-slice.txt`=pre-cmdcon27.*
