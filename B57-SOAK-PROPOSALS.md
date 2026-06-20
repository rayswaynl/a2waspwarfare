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

### Broken
- 2026-06-20 11:55 [idea] — **HC *unit-load* imbalance (watch, not yet confirmed-bug).** `HCDELEG ...
  perHC=7:196,7:0`, `imbalance=-1`: even team count (7:7) but one HC holds ~196 units while the other
  holds ~0; `HCSTAT HC-2:58 units=1 groups=0` (near-idle). Most likely **warm-up** (HC-2 registered late,
  hasn't accumulated), but if it persists it points at delegations routed to HC-2 whose units never
  materialise. The least-loaded picker is *team-agnostic and unit-accurate* by design, so it should
  self-correct — **re-check next report**; if `196:0` persists, investigate HC-2 spawn path.
- 2026-06-20 11:55 [idea] — **`unitsPerTeam` below the 8–12 floor** (4.2–5.1). Root-caused (no refill);
  draft + fix proposals filed under *AI Commander improvements*.

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
