# Overnight autonomous loop — 2026-07-02 (claude-gaming)

## Directive (Ray, 2026-07-01 night)
> Keep heavily monitoring the server, my RPT and the HCs all night, every 15 minutes. If you don't
> find an issue, seek a fix or improvement for something instead (keep delivering all night). Make
> your own PR for this. Keep the loop going no matter what — if the server crashed, just start a new
> match and get back on track. Link the WASPSCALE panel.

## Loop policy
- **Cadence:** every ~15 min (ScheduleWakeup, 900s), all night, until Ray says stop.
- **Each tick:** pull the live server RPT + Ray's client RPT + both HC RPTs → scan for real script
  errors / crashes / AICOM pathology / perf regressions.
  - **Issue found** → diagnose + fix (commit to this branch).
  - **No issue** → pull the next item off the improvement backlog below and ship it.
  - **Server crashed / procs < 3** → restart the chain (deploy script / service restart) and resume.
- **Safety:** develop + commit fixes to THIS PR (ready for Ray's review). Do NOT hot-deploy new
  code to the live server unattended unless it directly resolves a live crash loop. The live build
  stays **cmdcon36**; match rotation stays box-side (WaspMatchEndRotate). No unattended risky deploys.
- **Live panel:** WASPSCALE scope-vs-FPS → https://miksuu.com/wasp (Performance tab).

## Shipped this session (folded into this branch)
- Grade-stamp A2-OA Bool `!=` fault fixed (`Common_RunCommanderTeam.sqf:858`) — was firing every road-march tick.
- Friendly map markers restored to the **`b_inf` class icon** (was `mil_arrow2` arrow) per Ray.
- **WASPSCALE v2 emitter** — `build=` + `hc_fps=` added to the telemetry (AI_Commander.sqf + HCStat.sqf).
- **HC lobby slot** relabelled `Headless Client` → **`HC`** on both maps (both sides). NOTE: the HC label
  was already on the id-lowest WEST/EAST slot (the one the HC grabs); do NOT renumber slots.

## Improvement backlog (loop pulls from here when no issue is found)
1. **Camps "afraid of" fix (Fix A)** — in AllCamps mode (`WFBE_C_TOWNS_CAPTURE_MODE=2`), the camp-first
   no-progress bail (`Common_RunCommanderTeam.sqf:1107`, `WFBE_C_AICOM_CAMP_STALL_PASSES`) abandons camps
   then falls through to a depot it can't drain → grinds a town forever. Gate the bail on capture mode
   (new `WFBE_C_AICOM_CAMP_GATE_MODE2`, default 1). Low risk.
2. **No-money JIP funds-heal harden** — B76 FUNDS-HEAL sometimes needs a second request; make it retry
   until funds land (or bump the request count) so joiners never spawn broke.
3. **WEST team-size >8** — one WEST team founded 11 units (>the size-8 cap); verify the founding roster
   path applies the cap for WEST.
4. **Team-tag click error** — Ray reported a popup on clicking team tags; no SQF error logs → likely a
   UI/config error. Needs the error text OR a reproduction dig into GUI_Menu_Command roster handlers.
5. **Camp-grab (Fix B, optional)** — commander peels 1 idle team to grab a lone front-line camp; default OFF.
6. **Pre-existing `_govSteep` cleanup + any new fault the loop surfaces.**

## Tick log
- **Tick 0** (setup): server healthy (3/3 procs, cmdcon36, 0 errors, AICOMHB v2, WEST 10-0). No issue →
  shipped the pending batch above (grade-stamp, marker b_inf, WASPSCALE v2 emitter, HC label). Loop armed.
- **Tick 1** (Ray-requested deploy): shipped **cmdcon37** = the patch + **camps Fix A** (`WFBE_C_AICOM_CAMP_GATE_MODE2`, hold+clear camps in AllCamps mode) + **stall-advance floor**
  (`WFBE_C_AICOM_STALL_ADVANCE_SECS=240`, re-route parked-not-flipping teams — the real fix for the live "0 town-captures / grind unflippable depot" root of standing+circling+afraid-of-camps).
  Boot-smoke found + fixed a WASPSCALE build-tag string-`find` A3 fault (aborted the emit → 0 lines) → re-deployed. **Live cmdcon37 clean: 0 errors, AICOMHB v2, WASPSCALE v2 emitting `build=cmdcon37aicom|hc_fps=46`.**
