# B57 Soak — Proposals & Improvements (review with Ray in the AM)

**This is the LIVE proposal log for the B57 24h Chernarus soak.**
It is a running accumulator written by the automated soak-report agents
(`WaspB57Expansive`, every 4h; `WaspB57Full`, daily 06:00) plus any manual notes.
It is **propose-only**: nothing here is deployed. Review it with Ray in the morning
and promote the agreed items into real work.

**Build under soak:** `[55-2hc]warfarev2_073v48co_b57.chernarus` — a just-shipped AI-commander
overhaul: larger groups via founding-pad, 10 teams/side, take-towns / push-front behaviour,
slot reorder, marker fix, and a paced economy.

**Conventions**
- Every entry is **dated** (`YYYY-MM-DD HH:MM`) and **tagged** `[idea]` (concept only) or
  `[draft-coded]` (draft code committed on `claude/b57-soak-proposals`).
- English only. A2-OA 1.64 constraints apply to all draft code: no A3-only commands
  (no `isEqualType`/`isEqualTo`), no sim/distance-gating of AI, never a frozen/standing-still
  AI, do not touch antistack.
- New entries are **appended** under the relevant section (newest at the bottom of each section).

---

## AI Commander improvements
<!-- spearhead/target selection, team founding & sizing, posture, economy pacing, push-front logic.
     Each entry: YYYY-MM-DD HH:MM [idea]|[draft-coded] — finding -> proposed change. -->

- 2026-06-20 11:55 [draft-coded] — **Found-size decoupled from the live MIN floor.** RPT/impressions
  show founding works (`B57 padded infantry team to floor (8 units)`) yet measured `unitsPerTeam` sits
  at **4.2–5.1**, below the 8–12 target band. Root cause (confirmed in `AI_Commander_Teams.sqf:278-298`
  comment): HC-founded teams are **never refilled after founding** (`AI_Commander_Produce` skips
  `wfbe_aicom_hc` teams = 100% of live teams). So founding *at* the floor (8) guarantees the live
  average dribbles *below* the band the instant attrition starts. Draft: new constant
  `WFBE_C_AICOM_TEAM_FOUND_SIZE = 10` (`Init_CommonConstants.sqf:229-237`), and pad to it (clamped to
  [MIN,MAX]) in `AI_Commander_Teams.sqf:283-303`. Identical behaviour when FOUND_SIZE==MIN.
  **Economy caveat:** ~25% bigger founds cost ~25% more supply under `SUPPLY_INCOME_MULT=0.35`; may
  slow team count slightly — review with Ray before deploy.
- 2026-06-20 11:55 [idea] — **Reinforcement / top-up pass is the *real* fix** for the dribble; found-size
  is only a stopgop. A founding pad can never hold a high live average without refill. Proposal: a slow,
  cheap commander pass that, for each HC team below e.g. `0.6 * WFBE_C_AICOM_TEAM_SIZE_MIN` that is NOT
  in active contact and is near a friendly supply source, dispatches a top-up of `Man` class units to
  the HC owning that team (reuse the `delegate-aicom-team` / CreateTeam path with an "append units" verb,
  charged from commander funds). A2-OA-safe: no sim/distance-gating of the team itself, no antistack
  touch, `isKindOf`/`getNumber` type checks only. Must throttle (1 team/tick) to avoid a town-activation
  spike like the old per-group HC pick (`Server_DelegateAITownHeadless.sqf:22-28`).
- 2026-06-20 11:55 [idea] — **Posture read at warm-up looked good but is coarse.** Impressions: WEST=DEFEND
  / EAST=PRESS then both HOLD after each held 1 town; EAST strength climbed 82→101 while WEST stayed 64.
  Strength asymmetry persisted without WEST switching to a strike/reactive posture. Proposal: when own
  strength trails enemy by > X% for N consecutive ticks AND a reachable enemy spearhead exists, bias WEST
  toward `PRESS`/reactive-defense earlier rather than camping DEFEND (`AI_Commander_Strategy.sqf` posture
  block). Watch over a longer window before tuning — only ~2 min of posture data so far.
- 2026-06-20 15:50 [draft-coded] — **HC-team top-up pass (the real dribble fix), drafted.** With ~4h of B58
  data the dribble is CONFIRMED, not warm-up: `unitsPerTeam` ran 4.9–9.6 (mostly 6–7) all round while
  founding kept firing (founded 5→49, HC registered 4–11-unit teams). Root cause stands at
  `AI_Commander_Produce.sqf:63` — refill is gated `!(team getVariable "wfbe_aicom_hc")`, so 100% of live
  teams never refill. Produce *can't* fix it: `AIBuyUnit` spawns the refill at a SERVER factory, but HC
  teams are local on the HC, so the top-up must be created HC-side and `join`ed there (the locality rule
  `Common_RunCommanderTeam.sqf`/`Common_CreateTeam.sqf` rely on). Draft committed:
  `Server/AI/Commander/AI_Commander_HCTopUp.DRAFT.sqf` — a server-side detector that picks ONE
  under-strength HC team (below `0.6*SIZE_MIN`, NOT in contact, near a friendly supply town), charges
  funds, and routes an `aicom-team-topup` request over the existing RequestSpecial/HandleSpecial bus.
  **NOT WIRED / default-OFF** behind `WFBE_C_AICOM_HC_TOPUP_ENABLE` (absent ⇒ false ⇒ early exit), referenced
  by no loader ⇒ zero live impact. A2-OA-safe (typeName guard, no sim/distance-gating of the team — it only
  ADDS units, never stops one; no antistack touch). The file's footer specifies the HC-side consumer to
  write next (createUnit near leader + joinSilent). Throttled 1 team/call to avoid a town-activation spike.
- 2026-06-20 15:50 [idea] — **EAST spearhead is frozen on a far town the whole B58 round.** Impressions
  show EAST spearhead locked on **Berezino, distFront=1752**, onFront=true, for the entire round — EAST
  stayed DEFEND and barely captured, while WEST cycled `Myshkino→Pustoshka→Vybor` (distFront ~1200–1440)
  and pressed to 3 towns. The spearhead selector ranks by distance-to-own-front (dominant) yet EAST never
  re-picks the nearer reachable town. Proposal: in `AI_Commander_Strategy.sqf` spearhead block, when a
  side's chosen spearhead `distFront` does not shrink for N consecutive ticks, force a re-pick of the
  **nearest reachable** enemy/neutral town (the contiguity/reach fallback already exists in
  `AI_Commander_AssignTowns.sqf:254-345` — lift the same nearest-reachable rule into the spearhead picker).
  A2-OA-safe (selection logic only, no gating).

## AI unit improvements
<!-- per-unit/per-group behaviour: pathing, unstuck, garrison, engagement, rearm/heal detours. -->

- 2026-06-20 11:55 [idea] — **Founded teams attrit with no in-field healing/rearm detour.** Since teams
  are never refilled, keeping the units they *have* alive matters more. Proposal: a lightweight per-team
  "self-preserve" — when a team is below strength, not in active contact, and a medic/ammo source (own
  vehicle/depot) is in range, allow a brief heal/rearm detour before resuming the assault. Must
  re-wake/return to offense on enemy proximity (never a standing-still AI) and not gate on simulation.
- 2026-06-20 11:55 [idea] — **Town-capture grind guard already exists** (STUCK_ABANDON blacklist,
  `Init_CommonConstants.sqf:236-239`) — confirm over the soak it actually fires and teams re-pick rather
  than grinding an unflippable town. RPT showed healthy re-pick at warm-up (`town:Dubrovka;detected:12`),
  but verify on a contested stalemate town later in the run.
- 2026-06-20 15:50 [idea] — **Stalemate-town blacklist: live test case now exists.** EAST sat on Berezino
  the entire B58 round without flipping it. Confirm `STUCK_ABANDON`/`TARGET_ABANDON`
  (`AI_Commander_AssignTowns.sqf:163-231`) actually fires on this town and EAST re-picks a flippable one,
  rather than grinding it indefinitely. If it never abandoned Berezino over hours, the abandon threshold
  is too lax for the spearhead path — tighten it or feed the abandon back into the spearhead selector.
- 2026-06-20 15:50 [idea] — **In-field heal/rearm matters MORE now that the dribble is confirmed.** Until
  the top-up pass lands, keeping the units a team already has alive is the only lever on live `unitsPerTeam`.
  Lightweight per-team self-preserve (heal/rearm detour when below strength, not in contact, near own
  vehicle/depot) — must re-wake to offense on enemy proximity (never a standing-still AI) and not sim-gate.
  Pairs with the top-up pass (top-up replaces the dead; heal/rearm slows the dying).

## Functions: working / broken
<!-- which mission functions / features are confirmed WORKING vs BROKEN this soak, with evidence. -->

### Working
- 2026-06-20 11:55 [idea] — **Server FPS: rock-solid.** SRVPERF held **46–49** across the whole young
  round, min 41 (one momentary warm-up dip), max 49, even as AI climbed to **349 units / 58 vehicles /
  5 active towns**. No degradation under load. Client-side Zwanon reported srvFps 45–48 (client fps 19 is
  a client number, not server).
- 2026-06-20 11:55 [idea] — **Larger-groups founding feature: confirmed operational.** Both sides reach
  `foundedTeams=10`; `CMDRSTAT` shows EAST `unitsPerTeam` 6.4–7.0, WEST 4.2–5.1; registered teams of
  7–10 units seen (`HC commander team ... registered (10 units)`); `remnants=0` both sides (clean
  wipe→refound lifecycle, no orphans). Founding pipeline healthy (dispatch→TEAM_FOUNDED→register, refills
  to target 10).
- 2026-06-20 11:55 [idea] — **HC delegation healthy at the *team* level.** 2 HCs live, no drops this
  round, `delegated:7` each, `remnants=0`. Least-loaded picker (`Server_PickLeastLoadedHC.sqf`) +
  round-robin town spread (`Server_DelegateAITownHeadless.sqf`) working as designed.
- 2026-06-20 11:55 [idea] — **War progresses.** First flip `TOWN_FLIP town=Khelm GUER→EAST` (tick 31)
  ended EAST's bootstrap stipend; captures 0→2 in ~2 min; all three sides (WEST/EAST/GUER) actively
  engaging (kills logged WEST→GUER, EAST→GUER armor).
- 2026-06-20 11:55 [idea] — **Clean run, zero script errors** in the current round (see Bugs).
- 2026-06-20 15:50 [idea] — **Server FPS held over the full ~4h window (B57→B58).** SRVPERF run:
  B57 `47→49→47`, B58 `45→46→48→43→42→38→43`; RPT scope (181 samples, B58 round) avg ≈44, min 23, max 49,
  **zero sub-20** even as live AI climbed 34→375 units / 68 veh / up to 8 active towns. Gentle decline
  tracks unit count, not a leak. No degradation = green.
- 2026-06-20 15:50 [idea] — **Unstuck ladder confirmed working at scale.** 39 `UNSTUCK_STRIKE` events,
  tiers escalating 1→3, every team recovered — no team left permanently stuck. The B37/WAVE-1 foot/dead-hull
  unstuck (`Common_RunCommanderTeam.sqf:449-475`) is doing its job over hours, not just at warm-up.
- 2026-06-20 15:50 [idea] — **Clean error budget over ~4h:** zero `Error in expression`, zero script
  errors, zero `Warning Message`. 10 teams/side both sides (`hcTeams=10 foundedTeams=10 remnants=0`).
  Founding pad fires (founded 5→49, registered 4–11 units). AICOM busy: ASSAULT 243, UPGRADE 110, TEAM 81,
  ECONOMY 72, WEDGE 15; AI peaked 446 units.

### Broken
- 2026-06-20 11:55 [idea] — **HC *unit-load* imbalance (watch, not yet confirmed-bug).** `HCDELEG ...
  perHC=7:196,7:0`, `imbalance=-1`: even team count (7:7) but one HC holds ~196 units while the other
  holds ~0; `HCSTAT HC-2:58 units=1 groups=0` (near-idle). Most likely **warm-up** (HC-2 registered late,
  hasn't accumulated), but if it persists it points at delegations routed to HC-2 whose units never
  materialise. The least-loaded picker is *team-agnostic and unit-accurate* by design, so it should
  self-correct — **re-check next report**; if `196:0` persists, investigate HC-2 spawn path.
- 2026-06-20 11:55 [idea] — **`unitsPerTeam` below the 8–12 floor** (4.2–5.1). Root-caused (no refill);
  draft + fix proposals filed under *AI Commander improvements*.
- 2026-06-20 15:50 [idea] — **`unitsPerTeam` < floor — CONFIRMED across the full B58 window** (4.9–9.6,
  mostly 6–7), not warm-up. Top-up draft now filed (`AI_Commander_HCTopUp.DRAFT.sqf`, default-OFF). Promote
  the wire-up + HC consumer in the AM.
- 2026-06-20 15:50 [idea] — **EAST spearhead frozen on Berezino** (distFront=1752 all round) — front never
  advanced on the EAST side; behavioural bug, fix filed under *AI Commander improvements*.
- 2026-06-20 15:50 [idea] — **HC-2 fps dips into the teens (min 14, 34 samples <25)** while server FPS
  holds. One HC (nodes :948/:979) carries the whole war; load looks concentrated (echoes the 4h-report
  `perHC=196:0`). Server never followed it down and there was NO HC drop, but the dips are the leading
  candidate for late-soak instability. Proposal: spread teams across HC nodes / add a second HC. Re-check
  whether the dips correlate with the highest unit-count ticks (impressions tick 10 showed HC fps 16 at
  units=375). **Re-confirm next report.**
- 2026-06-20 15:50 [idea] — **Soak telemetry gap (visibility, not behaviour):** impressions logs
  `B58 founding: padded=0 / sample=empty` even though founding clearly fires (founded 5→49, 4–11-unit
  registrations). The soak parser's "padded" counter + sample string match the B57 log wording, not B58's.
  Fix the parser's match string so the larger-group feature stays visible in the next round's impressions.

## Balance
<!-- economy, team comps, vehicle mix, town garrison strength, side parity, capture pacing. -->

- 2026-06-20 11:55 [idea] — **EAST out-strengthening WEST at warm-up** (str 101 vs 64; EAST `unitsPerTeam`
  6.4–7.0 vs WEST 4.2–5.1). EAST consistently drove the spearhead (Krasnostav→Berezino). Could be
  doctrine/template cost asymmetry (EAST founds bigger/cheaper) or just early variance. Track side-parity
  over the full run before tuning; if EAST persistently founds larger teams per supply, review per-side
  template costs / `WFBE_C_AICOM_TEAMS_PC_LOW` curve.
- 2026-06-20 11:55 [idea] — **Found-size vs paced-economy interaction.** `SUPPLY_INCOME_MULT=0.35`
  throttles ongoing town income; bumping FOUND_SIZE 8→10 raises per-team cost ~25%. Net effect on team
  *count* vs team *size* is the balance lever to watch — decide with Ray whether bigger-fewer or
  smaller-more reads better in play.
- 2026-06-20 15:50 [idea] — **Capture pacing reads slow + side-asymmetric.** Only ~4 WASPSTAT flips in
  ~2.5h of B58; WEST pressed to 3 towns while EAST defended near-parity strength (~85 vs ~79). Part of the
  slow EAST side is the frozen-spearhead bug (above), but with the dribble dragging team strength below the
  band, neither side musters the mass to flip a defended town quickly. Expect the top-up pass + the EAST
  spearhead fix to both raise capture cadence — re-measure flips/hour after those land before touching
  garrison strength or drain rates.
- 2026-06-20 15:50 [idea] — **WEST consistently founds smaller teams than EAST** (WEST `unitsPerTeam`
  4.9–7.2 vs EAST 5.3–6.6, and WEST was the lower side at every B57 tick too). Persistent across two builds
  now — points at a per-side template cost/composition asymmetry rather than variance. Review WEST vs EAST
  template prices / the `PC_LOW` curve when tuning the founding economy.

## Player spectacle & cinematics (incl. AI-generated cinematics)
<!-- things that make the war feel alive for players to watch/join; ideas for AI-generated
     cinematics / highlight reels / camera work. -->

- 2026-06-20 11:55 [idea] — **Town-flip "money shot" cam.** We already emit `TOWN_FLIP` events. On a flip,
  spin up a short auto-director camera over the captured town (orbit the flag/depot, cut to the nearest
  firefight) for spectators/JIP loading screen. A2-OA-safe with `camCreate`/`camSetTarget`/`cameraEffect`;
  trigger off the existing event so no polling.
- 2026-06-20 11:55 [idea] — **Spearhead "front-line" spectator marker feed.** `CMDRSTAT`/spearhead logs
  already carry `onFront`, `distFront`, target town. Surface a live "current front: WEST→Pustoshka /
  EAST→Berezino" banner + map ping for spectators so the war reads at a glance. The B57 marker-dir fix
  (`updateteamsmarkers.sqf:202-218`) means leader arrows now point correctly — good base for a clean
  spectator map.
- 2026-06-20 11:55 [idea] — **AI-generated narrated recaps (out-of-game pipeline).** The RPT is a
  structured event stream (`AICOMSTAT|...|TOWN_FLIP`, `TEAM_FOUNDED`, `WASPSTAT KILL`, `CMDRSTAT` strength
  curves). Pipe each round's events to an LLM to auto-write a "battle report" recap (who pushed where, the
  turning-point flip, MVP kill streaks) and post it to Discord at round end. Zero in-game/server cost
  (pure log parse), and it makes the soak legible to people who weren't watching. Could later drive a
  highlight-reel cut-list (timestamps of the biggest flips/kills) for an automated camera pass.
- 2026-06-20 11:55 [idea] — **Kill-streak / armor-duel highlight triggers.** `WASPSTAT KILL` lines already
  tag killer/victim/weapon/vehicle (e.g. `EAST→GUER ... T72_Gue`). Flag multi-kills and tank-vs-tank
  trades as candidate highlight timestamps for the recap/reel pipeline above.
- 2026-06-20 15:50 [idea] — **Auto-director spectator cam following the live front.** The spearhead/CMDRSTAT
  feed already names the current target town + `onFront`/`distFront` per side. A spectator/JIP-loading
  director cam could auto-cut to the live spearhead town, or to the highest unit-concentration firefight
  (pick the densest `nearEntities ["Man"]` cluster near the front), so anyone watching always sees the
  decisive action without manual camera work. A2-safe camCreate/camSetTarget/cameraEffect; data already
  emitted, so no new server polling.
- 2026-06-20 15:50 [idea] — **End-of-round AI battle-recap, concrete pipeline.** This round alone produced a
  clean structured stream (ASSAULT 243, TOWN flips, UPGRADE 110, CMDRSTAT strength curves, UNSTUCK ladder).
  Feed the per-round RPT slice to an LLM to auto-write a narrated recap — "WEST drove Myshkino→Vybor while
  EAST stalled at Berezino; turning point was flip #N; MVP duel was the T72 trade at HH:MM" — plus a
  highlight-reel cut-list (timestamps of the biggest flips/armor trades) for an automated camera pass.
  Zero in-game cost (pure log parse), and it makes a 24h soak legible to anyone who wasn't watching.

## Bugs found
<!-- script errors (Error in expression), broken markers, stuck teams, dropped HCs, etc.
     Include RPT evidence / file+line where known. -->

- 2026-06-20 11:55 [idea] — **No script errors in the current round.** RPT scan from the latest MISSINIT
  (line 64 of 2957) onward: **zero** `Error in expression`, zero `Error position`, zero `#0 file ... line`,
  zero `Undefined variable`, zero `Warning Message`. Top error file+line: **N/A — clean run.**
- 2026-06-20 11:55 [idea] — **38× `Server error: Player without identity HC (id 464279660)` are
  PRE-MISSINIT residue** (all appear *above* line 64), i.e. leftover from the *previous* round's HC
  reconnect/shutdown churn — **not** the current round. No occurrences after MISSINIT. Not a current bug,
  but worth confirming HC identity is clean on the next restart.
- 2026-06-20 11:55 [idea] — **Soak-coverage caveat (process note).** This RPT only covers a freshly
  started round (≈tick 38, daytime 9.50→9.65 — tens of minutes, not 24h). impressions.md has only 2 ticks
  (~2 min). The server appears to have **restarted recently**; long-duration soak data (FPS drift over
  hours, late-game economy, HC stability over time) is **not yet present**. Treat all FPS/parity/imbalance
  reads above as warm-up snapshots; re-confirm trends in the next 4h report.
- 2026-06-20 11:55 [idea] — **HC unit-load imbalance (`perHC=7:196,7:0`)** logged here too for bug-triage
  visibility — see *Functions → Broken* for detail. Re-check next report; warm-up vs real-bug undecided.
- 2026-06-20 15:50 [idea] — **Still ZERO script errors over ~4h.** RPT scope from the latest MISSINIT
  (B58, line 168) onward: 0 `Error in expression`, 0 `Error position`, 0 `#file line` offenders, 0
  `Undefined variable`, 0 `Warning Message`. **Top error file+line: N/A — clean run.**
- 2026-06-20 15:50 [idea] — **One rerun fired ~12:17** (`RERUN via WaspCleanRestart — reason: server down,
  procs=1/3`) during the B57 round; B58 then shipped 13:08 at 3/3. Rerun-on-restart handled it cleanly and
  the soak continued, but a server/HC proc dropped once — worth confirming *why* (the prior 38× pre-MISSINIT
  `Player without identity HC` residue suggests HC reconnect churn around restarts). Not a current-round bug.
- 2026-06-20 15:50 [idea] — **Cosmetic-only RPT noise (not bugs):** missing RU voice file ×2
  (`Cannot load sound ...havethetargetinmysights.wss`), 168 benign engine `Object NN not found (message)`
  net-syncs (objects deleted while a remote message was in flight — normal), and a one-shot
  `cleaner_droppeditems 5517ms` cold-start hitch at round init (fired once, server FPS held). No action
  needed beyond optionally shipping the RU .wss.
