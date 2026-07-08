# WASP cmdcon29 TK Soak-Watch — Hypotheses Ledger

Live **Takistan cmdcon29** match (deployed 2026-06-30 ~13:30 via in-place build upgrade). Standing autonomous loop ([[wasp-permanent-loop]]): MONITOR→FIND→BUILD→DEPLOY→RUN→REPEAT. Telemetry is build-agnostic (`_box_watch_cmdcon28.ps1` / `_box_sidecheck_cc29.ps1` / `_box_closurecheck.ps1` + 4h reporter).

**cmdcon29 Tick 1 (min ~48 — HEALTHY, clean, reach UP; keystone not yet testable):**
- ✅ ZERO errors (standard watch + dedicated new-code scan for setDamage/nearEntities/canMove/heli_terrain/RunCommanderTeam both clean) — the self-repair + heli-guard NEW code runs without a single runtime error. HC seating healthy (WEST+EAST both founding, teams=10/10, WEST 18 / EAST 22 foundings).
- ✅ REACH JUMPED: ARRIVED 15/50 (~30%, vs cmdcon28's ~6% floor), STRANDED **0** (vs cmdcon28's 16-19), STUCKSTAT/UNSTUCK 1/1. Big — but partly an early-match effect (close front; cmdcon28 also started healthier then degraded as the front spread to 2-3km towns). MUST confirm it holds as the front spreads.
- ⚠️ VEHICLE_SELFREPAIR: **0 fires** at min 48. Not alarming yet (only fires for an immobilized vehicle that's also safe + crewed; pure-infantry teams have no vehicle to immobilize, and it may simply be rare/early) — but WATCH: if vehicles immobilize and it never fires, that's a bug in the trigger.
- Closure (THE KEYSTONE) NOT testable yet: balanced match (WEST 1 town/str 62, EAST 0 towns/str 68), no dominance → no HQ_STRIKE → can't yet test whether rounds close. Needs a side to pull ahead.
- No new issue to fix → soak continues (re-armed monitor).

**cmdcon29 Tick 0 (deployed, healthy):** cmdcon29 = AI vehicle self-repair + PR#122 (heli-terrain-guard + QoL). Booted clean (MISSINIT cmdcon29, 0 errors, 3/3 procs). The "EAST+CIV" HC scare was a telemetry misread — HCs are CIV BY DESIGN, drive WEST/EAST via owner-routing; verified healthy at min16 (WEST founded 4 / EAST 8, both managed sides building). Code `13c29b4e5`, Build 81 published. **NOW WATCHING:** (1) VEHICLE_SELFREPAIR events — does self-repair actually rescue stranded teams? (2) assault-reach % — does heli-guard + self-repair lift it off the cmdcon28 ~6% floor? (3) THE KEYSTONE carried from cmdcon28: do dominant rounds finally CLOSE (BASE_OVERRUN/ROUNDSTAT/rotation) now that immobilized vehicles un-stick? (4) errors flat.

---

## Earlier — cmdcon28 soak (the reach-ceiling stalemate that motivated cmdcon29)

Live **Takistan cmdcon28** match (restarted 2026-06-30 ~10:35, two-sided). Loop ~25min via ScheduleWakeup; box scripts `_box_watch_cmdcon28.ps1` / `_box_reachcheck.ps1` / 12h reporter DryRun.

**Tick 0 (min ~25, first boot — BROKEN):** WEST had NO HC (HCs seated EAST+CIV) → typed 14 teams, founded 0 (hc=0), str=0, laststand. EAST-vs-nobody. Cause = HC lobby-seat-magnet on the rotate2 restart → RESTARTED in place to re-roll HCs.

**Tick 5 (min ~149 — stalemate persists; cmdcon29 GREENLIT + deploying):**
- Still NO closure/rotation (0 BASE_OVERRUN, 149-min round; WaspMapRotate's 4h mark not yet hit). See-saw swung back to WEST (str 77 vs 54, eff 79 vs 56) but still 1 town each → no town-lead → HQ-strike gate can't re-fire. Classic see-saw deadlock.
- Reach STILL degrading: ARRIVED 10/214 (~5%), STRANDED 19 (↑ from 16), STUCKSTAT 57 / UNSTUCK 53.
- D1 stable (SIDE_BLACKLIST=1, TARGET_ABANDON=4). Funds PILING (WEST 1.16M, EAST 1.01M) — wealth-conversion not keeping up in a low-churn stalemate (secondary econ note).
- Errors flat (6). → cmdcon29 (AI vehicle self-repair + PR#122 heli-terrain-guard + QoL) packed & GREENLIT; deploying to replace this soak. The reach/lingering keystone fix is now live-bound.

**Tick 4 (min ~111 — STALEMATE DEEPENS, reach worsening; ghosts self-resolved):**
- Still NO closure (0 BASE_OVERRUN/ROUNDSTAT, no rotation, 111-min round). See-sawing (WEST 1/str 51, EAST 1/str 63 — EAST now ahead). No 2nd HQ_STRIKE (neither dominates enough to re-fire).
- ⚠️ REACH WORSENING: 10/176 (**6%**, ↓ from 8→12%). Stranded 16, frozen 10 (both growing). STUCKSTAT=48/UNSTUCK=44 (firing hard, teams still strand). CONFIRMED "sitting at base": ASSAULT_STRANDED to Feeruz Abad (2274m) with **moved=0** — assigned but never moved.
- D1: SIDE_BLACKLIST=1, TARGET_ABANDON=4 — working but limited (blacklists unpathable towns; doesn't fix the FAR-distance/movement driver dominating on TK).
- ✅ Ghosts SELF-RESOLVED: CMDRSTAT remnants=1 (WEST)/0 (EAST) — GC reaped the disband empties; the ALLOC teams=24 over-count was a transient bulk-disband lag. → disband-sanitize LOWER priority; founding-bootstrap + recent-movement + self-repair are the keystone.
- Funds piling (WEST 896k, net +37k/tick) — AICOM hoards in a low-churn stalemate. Secondary econ note.
- Errors flat (client 24, server 6). FPS 46, AI 217.

**Tick 3 (min ~83 — ROUND-ENDER STALLED, NOT closed; D1 CONFIRMED):**
- ❌ THE STRIKE DIDN'T CLOSE: WEST's HQ_STRIKE (min 60-63) → 0 BASE_OVERRUN / 0 ROUNDSTAT. Strikers never reached EAST's HQ (assault-reach ceiling). Meanwhile EAST RECOVERED (0→1 town, str 32→57) → relative gate relaxed + sticky-strike expired → WEST dropped to HOLD. Re-balanced (WEST 1/str 69, EAST 1/str 57), no rotation, 81-min round dragging. SAME cmdcon27 problem: round-ender FIRES but the reach ceiling prevents closure.
- ✅ D1 CONFIRMED IN THE WILD: SIDE_BLACKLIST=1 (TARGET_ABANDON=3 → side blacklisted a town). The per-side unreachable-town blacklist fires as designed.
- ⚠️ Assault-reach 10/125 (8%, ↓ from 12%) — front spread to FAR towns (Feeruz Abad 2532-3086m!), reach ceiling bites harder. STUCKSTAT=30/UNSTUCK=25, 9 stranded, 4 frozen. reissue=true now firing.
- 🔑 KEY INSIGHT: D2 makes the round-ender FIRE, but the REACH ceiling stops it CLOSING. The cmdcon29 lingering/reach fixes (recent-movement stuck-detect, founding-bootstrap, vehicle self-repair) are the KEYSTONE — they convert a fired strike into a closed round.
- Errors flat (client 24 init, server ~3-6 AntiStack). FPS 45, AI 227.

**Tick 2 (min ~60 — WEST WINNING, ROUND-ENDER FIRED):**
- ✅ Front opened: TOWN_FLIP=1 (WEST took its first town; Anar/Sakhee contest resolved). WEST myTowns=1/str 81/eff 83 **posture=HQ_STRIKE**; EAST 0 towns/str 32 (ground down from 80)/DEFEND.
- ✅ ROUND-ENDER FIRED via the NORMAL B754 relative gate (EAST 0 towns ≤ ENEMY_MAX[2]), NOT D2 (HQ_STRIKE_STALL_OVERRIDE=0). D2 is the parity-backstop; the normal gate caught the dominant side here. Watch for base-overrun + round close.
- D1 starting: TARGET_ABANDON=1 (first); SIDE_BLACKLIST=0 (needs 3 of one town).
- ⚠️ Assault-reach 9/78 (12%); stuck-detection NOW active (STUCKSTAT=14, UNSTUCK=10, 8 stranded, 3 frozen) — front opened to farther towns (Feeruz Abad 1696m, Kakaru 1319m) → teams strand/freeze = the lingering (Explore's recent-movement + founding-bootstrap fixes target this).
- Errors flat: client 24 (Init_TownMode init-transients), server ~3-6 (AntiStack getTeamScoreMonitor:39 `_totalskillblufor`, init-only). Reporter error-ranking fix live.
- No new disband uses (still the 1 from min 9). FPS 46, AI 178, cap-hits 0.

**Tick 1 (min ~28-32, post-restart — HEALTHY):**
- ✅ WEST FIXED: TEAMREG WEST+EAST 15/15; WEST 7 teams founding via HC + assaulting; EAST 10. Balanced (str 64 vs 80).
- ✅ allMapMarkers fix HOLDING (0). The 24 "client errors" = `Init_TownMode.sqf:3 waitUntil {WFBE_Parameters_Ready}` init-poll transients — pre-existing, harmless, not in server RPT.
- ✅ DISBAND failsafe confirmed in the wild: `aicom-team-disband|WEST|9|flagged=13|teams=14` (player-cmd Zwanon); WEST re-founded after.
- ⏳ D1 SIDE_BLACKLIST 0, D2 HQ_STRIKE_STALL_OVERRIDE 0 — no towns captured yet (0 flips) → no abandons/stalls. Pending real data.
- ⚠️ Assault-reach 1/48 ARRIVED — but a CONTEST (both sides + GUER on Anar ~760m, GUERCAP=32, 0 flips), not unreachability. Metric works.
- ⚠️ Server errLines ~9 init-only (flat) = AntiStack `monitorTeamToJoin _totalskillblufor` undefined; surfaces when WEST/BLUFOR active. AntiStack = don't touch.

---

# WASP cmdcon27 Soak-Watch — Hypotheses Ledger

Continuous heavy tracking of the live server **and** Ray's client RPT, with a multi-agent analysis +
adversarial hypothesis-test each tick. Started **2026-06-30** (cmdcon27 live, Chernarus).

**Rig**
- Server slice: `C:\WASP\_rpt_slice.ps1` (box) → scp → `scratchpad\slice-tickN.txt`
- Client slice: `scratchpad\_client_rpt_slice.ps1` (local, streams `wasp-rpt-reap\client-main.rpt`)
- Analysis: Workflow `wasp-soak-tick` (4 parse dims → synth → adversarial challenge)

⚠️ **The adversarial pass has overturned my first read TWICE (tick 0 and tick 1). Trust the post-challenge confidences, not the headline numbers.**

---

## Metric time-series
| Tick | When (box) | AICOM tick | Towns E/W/neut | Str E/W | Funds E/W | Players | GUER grp | SrvFPS | SrvErr | CliErr(cur) | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | ~14:32 | ~94 | 3/2/41 | 68/63 | 866k/816k | 1 (Zwanon=WEST) | 51/80 | 47 | 2* | 200 (allMapMarkers) | baseline; "stalemate" |
| 1 | ~15:28 | ~149 | 5/3/38 | 59/73 | 1.44M/1.36M | 1 (Zwanon=WEST) | 58/80 (73%) | 47 | 2* | 200 (allMapMarkers) | EAST 3→5 towns via concentrate-FIST grind (NOT expand); funds nearing cap. *(tick-1 "chronic trap" note retracted — that was cmdcon26 data)* |
| 2 | ~16:00 | ~194 | 6/4/36 | 74/75 | ~1.51M | 1 (Zwanon=WEST) | ~? | 47 | 2* | 200 (allMapMarkers) | both crept up (EAST 6/WEST 4); funds ~1.5M; unstuck **escalates** (strikes→5, tiers→4) but WEST teams chronically `distStart=0` |
| 3 | ~16:33 | ~219 | 6/5/35 | 72/71 | ~1.52M (no cap) | **0 (Zwanon LEFT)** | ~? | 47 | 2* | 200 | Zwanon disconnected → pure AI-vs-AI; funds run PAST 1.5M (no hard cap). **HC RPT RESOLVED the stuck Q: teleport FIRES (tier3=15, tier4=9 of 99) but teams stay stuck (strikes climb past teleport tier) → unstuck NOT recovering them. NOT guard (players=0), NOT tier-reset.** |
| 4 | ~17:10 | ~255 | 6/6/34 | 68/55 | ~1.51M | 0 (2 HCs) | ~? | 47@270AI | 2* | 200 | even grind, towns TIED 6-6; funds slow past 1.5M; server healthy; no rotation/end/new-error; approaching late-game (min 255) |
| 5 | ~17:51 | ~297 | 6/6/34 | 68/62 | ~1.52M | 0 (AI) | ~? | ~47 | 2* | 200 | **LOCKED 6-6** (no captures min 255→297, ~42 ticks); round-ender can't fire at town parity → match won't close, **rotation won't trigger**; funds slow-climb; otherwise healthy |
| 6 | ~18:43 | ~349 | 6/6/34 | 57/69 | ~1.51M | 0 (AI) | ~? | 48@278AI | 2* | 200 | 6-6 stalemate now **TERMINAL** (locked min 255→349, ~94 ticks no captures); server healthy; nothing changed — pure monitoring now |
| 7 | ~19:50 | ~411 | 7/6/33 | 41/41 | ~1.51M | 0 (AI) | ~? | **24@353AI** ⚠️ | 4 (=1 addon ×2) | 200 | **PERF DEGRADING**: fps 48→24; RPT flooding `Server: Network message NNN is pending` (~10k/25k lines) = replication backlog on the 7h grind. Stalemate cracked (WEST 7-6). **Restart would clear it + end the dead match + ship cmdcon28 — DM'd Ray, awaiting his OK.** |
| 8 | ~20:15 | ~436 | 7/6/33 | 72/59 | ~1.52M | 0 (AI) | ~? | 27@398AI | 4 (addon) | 200 | perf **STABILIZING** not runaway: fps 24→27, backlog burst SUBSIDED (575→50 lines/min); residual fps pressure = AI climbing 353→398 toward the ~450 knee (match never ends → teams keep founding). WEST holds 7-6. |
| 9 | ~20:43 | ~464 | 7/6/33 | 54/76 | ~1.51M | 0 (AI) | ~? | **48@280AI** ✅ | 4 (addon) | 200 | **PERF FULLY RECOVERED**: fps 27→48, AI 398→280 (the 398 spike was transient — a battle/founding surge, not degradation). Server healthy. Restart now purely optional. |
| 10 | ~21:46 | ~527 | **9**/6/31 | 43/58 | ~1.53M | 0 (AI) | ~? | 47@331AI | 4 (addon) | 200 | **STALEMATE BROKE** — WEST expanded 7→9 towns (1.5× EAST's 6) but is THIN (str 43 vs EAST 58, EAST could counter). Match may CLOSE if WEST hits 12 (round-ender) → triggers CH→TK rotation. Server healthy. |

## ✅ RESOLVED — server perf (tick 7 alarm → tick 9 full recovery)
Tick 7 (min 411): fps 48→24 + `Network message pending` flood. Tick 8: stabilizing. **Tick 9 (min 464): FULLY RECOVERED — fps back to 48, AI back to 280.** It was a transient AI-count spike (398, a battle/founding surge) + the network burst it caused — not real degradation. No perf problem. **Restart is now purely OPTIONAL** (end the dead 6-7 stalemate + ship cmdcon28 whenever convenient) — the only standing reason is the round-closure stall, not health. Lesson: don't over-read a single low-fps snapshot; fps tracks the live AI count, which spikes during battles.

\* the "2" SQF errors = **1 physical addon-origin error counted twice** (regex matches both lines). Tokens (`_shooter`,`_k`,`CAManBase` nearEntities) appear NOWHERE in the repo → third-party @mod kill handler, not WASP. Benign, non-accumulating.

---

## Hypotheses (confidence = AFTER adversarial challenge; updated through tick 1)
| ID | Cat | Statement (short) | Conf | Verdict | Forward test |
|---|---|---|---|---|---|
| **H1** | ai-behavior | Stalemate = AICOM under-commitment (assigned ~5/27) | **0.15** | **REFUTED.** `assigned/teams` denominator is contaminated (garrisons/dead/defensive). vs SNAP, the AI commits ~ALL its ~10 offensive teams every tick. Real lever = **~10-team offensive ceiling + funds-dead-currency**, not allocation. *(Reporter assault-reach is fine; drop the "under-commitment" framing.)* | assigned vs SNAP offensive-team count (≈1.0); does the ~10-team ceiling ever lift? |
| **H2** | cmdcon27-feature | cmdcon27 stuck-fix recovers stuck teams | **OPEN** | ⚠️ **ADVERSARY MISLABELED DATA — finding walked back.** The chronic-trap evidence (B 1-1-L stuck min 246→292) is from the PRIOR **cmdcon25/26** srv tails (verified: `srv.txt`=cmdcon25, `srv2.txt`=cmdcon26), NOT cmdcon27 — which only reached min 149 (deployed ~12:54, min 292 is hours away). cmdcon27 (min 94-194) shows the unstuck tier **escalating** (strikes 1→5, tiers 1→4), definitively NOT the "reset to 1" the adversary claimed — so that mislabeled mechanism is dead. **BUT tick-2 (min 194) found a REAL cmdcon27 issue:** WEST teams (USMC crew/SL/TL) chronically stuck `distStart=0` with strikes climbing to 5 — the escalation reaches the teleport tier yet teams DON'T recover. So cmdcon27 has a genuine assault-reach/chronic-stuck problem, via **escalation-without-recovery**, not tier-reset. **CONFIRMED (tick 3, HC RPT):** the recovery machinery FIRES correctly — teleport tier3=15/tier4=9 of 99 events, NOT guard-blocked (players=0 after Zwanon left), NOT tier-reset. `STUCK_ABANDON=4` so teams abandon + re-pick after 4 strikes. The real issue: **teams never ARRIVE** — they cycle targets without reaching them, almost certainly A2's pathfinder failing on specific legs (the reach-check is distance-based, not path-based — ONE more confirm owed). Match still progresses (slow captures) = partial inefficiency, not a freeze. **Fix is non-trivial (A2 pathing) → MORNING DESIGN TASK, not an overnight quick-fix.** *(Meta-lesson: verify the adversary's data provenance — it pulled stale cmdcon25/26 files.)* | confirm path-vs-distance reach-check; does a re-picked target also fail the same way? |
| **H3** | economy | Both AICOMs hoard funds toward 1.5M cap | **0.45** | **REFRAMED.** Funds runaway is real BUT funds are a **DEAD CURRENCY** — every spend (teams/structures/upgrades) is `paidBy=supply, fundsCost=0`; 0 funds-denominated purchases exist. The real consumed resource is SUPPLY. A funds sink needs a funds-priced AICOM purchase. | grep `paidBy=funds`/`fundsCost=[1-9]` (currently zero) |
| **H4** | match-balance | GUER garrisons are the wall stalling both fronts | **0.45** | PARTIAL. GUER is the universal opponent (occupies ~40 towns) but the **binding constraint is assault-REACH** — teams strand 1–2.6 km short (moved=0), never reaching the garrison. When they DID arrive (<220 m), GUER folded in 4–6 min. GUER count even GREW while losing towns (regen). | when a team arrives <220 m of a GUER town, does it capture? |
| **H5** | performance | Server green; client 19fps is the player-facing pain | **0.62** | SURVIVES (directional). Client pinned 19/19 (Zwanon runs VD=6000 maxed); server holds 47 but `delegate_townai_headless` hits 29–34 ms (>1 frame) at peaks. "Will hold" untested at the ~450–470u knee. | srvFps as AI→400+; client fps of a non-maxed-VD player |
| **H6** | cmdcon27-feature | War-room nudge plumbing works | **0.80** | CONFIRMED. The lone tick-76 MASS was **AICOM `src=auto`, not even a Zwanon nudge** — and a structural no-op (WEST <4 towns already concentrating). Plumbing bites on a ≥4-town side. | a nudge into a contrary posture → ALLOC delta |
| **H7** | health | WEST score-credit gap (`west=0` persists) | **0.50** | OPEN/real. `SCORE west=0 east=266` frozen; `west=0` recurs across matches → a genuine WEST `addScore` crediting gap (not just an artifact). | does WEST ever score across matches? |
| **H8** | cmdcon27-feature | Human (Zwanon) is an idle WEST observer | **0.78** | CONFIRMED. 0 combat (PLAYERSTAT 0|0|0|0 t79→149), no live nudge; AI delegation carries WEST. The 250k client "WARROOM" hits are **render-error spam** (historical line-83, fixed in cmdcon27; current = only allMapMarkers). | FIELDORDER count; Zwanon combat stats |
| **C1** | client-bug | HQ-heal `allMapMarkers` → 200 throws/join | **~1.0** | CONFIRMED both ticks (200×/join, `Init_Client.sqf:650`). **cmdcon28 fix STAGED, NOT deployed.** | client cur-session err → ~0 after cmdcon28 |

---

## Tick 1 narrative
Server still HEALTHY (47 fps, 1 addon error). EAST crept 3→5 towns, WEST 2→3 — but the adversarial pass killed my "EAST broke out via EXPAND" story: it's **reverse causation** (EAST already led at t124, before the t132 expand flip), and the in-window flips were each side **recapturing its own concentrate-fist primary from GUER** (symmetric; net town delta flat across t132–149). EAST simply won its fist battles as the stronger side. The real picture: **a ~10-team offensive force that mostly can't REACH its target** because the unstuck escalation is broken (tier resets to 1, never teleports) → chronic 40-min in-place freezes. Funds pile to the cap but are unspendable (supply-paid economy). Client 19 fps is the only player-facing pain, and it's a maxed-VD render load, not the server.

## Action queue → cmdcon28 (RE-AIMED after tick 1)
- **[STAGED]** **C1** — HQ-heal `allMapMarkers` → named-marker check (Ray-approved). Ready to pack.
- **[MORNING DESIGN TASK — confirmed, non-trivial]** **assault-reach / teams-never-arrive** — CONFIRMED (tick 3): the unstuck recovery (incl tier-3/4 teleport) fires correctly, but teams cycle targets without reaching certain towns — an A2 pathfinding limitation, not a code bug. Fix needs design (path-aware target selection / teleport-toward-target / global blacklist), NOT a one-liner. Defer to Ray's morning. **cmdcon28 = the confirmed C1 allMapMarkers fix ONLY.** *(The tier-reset and concentrate-stall ideas are both shelved — based on refuted/mislabeled data.)*
- **[PROPOSE]** **H3 funds sink** — make one AICOM purchase funds-denominated so the 1.4M hoard has an outlet (vs the dead-currency status quo). Separate econ pass.
- **[NOTE]** **H7** WEST `addScore` credit gap · reporter: relabel "under-commitment", keep assault-reach.
- **[MORNING — operational]** **round-closure stall** — the AI-vs-AI match locked at 6-6 (min 297+); the round-ender needs out-town dominance which never comes at parity, so the match grinds forever AND the match-end-driven CH→TK rotation never fires (server stuck on one Chernarus match). Related to the assault-reach pathing issue (neither side can break through). Ray's call: force a rotation, OR tune the round-ender's parity/stall-override gate. Server stays healthy meanwhile (no urgency).
